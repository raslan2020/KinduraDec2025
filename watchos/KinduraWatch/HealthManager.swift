import Foundation
import HealthKit
import SwiftUI
import Combine
import WatchConnectivity

// MARK: - Sleep Stage Model
struct SleepStage {
    let stage: String
    let hours: Double
    let color: Color
}

// MARK: - Fall Event Model
struct FallEvent {
    let date: Date
    let resolved: Bool

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Health Manager
class HealthManager: NSObject, ObservableObject, WCSessionDelegate {
    private let healthStore = HKHealthStore()
    private var wcSession: WCSession?

    // Vitals
    @Published var heartRate: Double = 0
    @Published var bloodOxygen: Double = 0
    @Published var hrv: Double = 0
    @Published var respiratoryRate: Double = 0

    // Sleep
    @Published var totalSleepHours: Double = 0
    @Published var sleepStages: [SleepStage] = []
    @Published var isSleepMonitoringActive: Bool = false
    @Published var awakeningsCount: Int = 0

    // Fall Detection
    @Published var isFallDetectionEnabled: Bool = true
    @Published var recentFalls: [FallEvent] = []

    private var heartRateQuery: HKObserverQuery?
    private var sleepQuery: HKObserverQuery?

    override init() {
        super.init()
        setupWatchConnectivity()
    }

    // MARK: - WatchConnectivity Setup
    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            wcSession = WCSession.default
            wcSession?.delegate = self
            wcSession?.activate()
            print("WatchConnectivity activated")
        }
    }

    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("WCSession activated with state: \(activationState.rawValue)")
        }
    }

    // MARK: - Send Vitals to iPhone
    func sendVitalsToiPhone() {
        // Always send directly to API for simulator compatibility
        sendVitalsToAPI()

        // Also try WatchConnectivity for real devices
        guard let session = wcSession, session.isReachable else {
            print("iPhone not reachable via WatchConnectivity, sent to API directly")
            return
        }

        let vitalsData = createVitalsPayload()

        session.sendMessage(vitalsData, replyHandler: { response in
            print("Vitals sent via WatchConnectivity: \(response)")
        }, errorHandler: { error in
            print("WatchConnectivity failed: \(error.localizedDescription)")
        })
    }

    // MARK: - Send Vitals Directly to API
    private func sendVitalsToAPI() {
        let vitalsData = createVitalsPayload()

        // Convert to JSON for API
        var apiData: [String: Any] = [:]
        apiData["heart_rate"] = vitalsData["heart_rate"]
        apiData["blood_oxygen"] = vitalsData["blood_oxygen"]
        apiData["hrv"] = vitalsData["hrv"]
        apiData["respiratory_rate"] = vitalsData["respiratory_rate"]
        apiData["total_sleep_hours"] = vitalsData["total_sleep_hours"]
        apiData["deep_sleep_hours"] = vitalsData["deep_sleep_hours"]
        apiData["rem_sleep_hours"] = vitalsData["rem_sleep_hours"]
        apiData["core_sleep_hours"] = vitalsData["core_sleep_hours"]
        apiData["awake_time_hours"] = vitalsData["awake_time_hours"]
        apiData["awakenings_count"] = vitalsData["awakenings_count"]
        apiData["sleep_quality"] = vitalsData["sleep_quality"]
        apiData["fall_detected"] = vitalsData["fall_detected"]
        apiData["recorded_at"] = ISO8601DateFormatter().string(from: Date())

        guard let jsonData = try? JSONSerialization.data(withJSONObject: apiData) else {
            print("Failed to serialize vitals data")
            return
        }

        // Use localhost for local development
        guard let url = URL(string: "http://127.0.0.1:8000/api/watch-vitals/dev/") else {
            print("Invalid API URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // TODO: Add authentication token here
        // For now, using a placeholder - you'll need to pass the token from the iPhone app
        // request.setValue("Token YOUR_TOKEN", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("API error: \(error.localizedDescription)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    print("✅ Vitals sent to API successfully")
                } else {
                    print("❌ API returned status: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }

    private func sendVitalsViaApplicationContext() {
        guard let session = wcSession else { return }

        let vitalsData = createVitalsPayload()

        do {
            try session.updateApplicationContext(vitalsData)
            print("Vitals sent via application context")
        } catch {
            print("Failed to update application context: \(error.localizedDescription)")
        }
    }

    private func createVitalsPayload() -> [String: Any] {
        let awakeTime = sleepStages.first(where: { $0.stage == "Awake" })?.hours ?? 0
        let deepSleep = sleepStages.first(where: { $0.stage == "Deep" })?.hours ?? 0
        let remSleep = sleepStages.first(where: { $0.stage == "REM" })?.hours ?? 0
        let coreSleep = sleepStages.first(where: { $0.stage == "Core" })?.hours ?? 0

        return [
            "type": "watch_vitals",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "heart_rate": heartRate,
            "blood_oxygen": bloodOxygen,
            "hrv": hrv,
            "respiratory_rate": respiratoryRate,
            "total_sleep_hours": totalSleepHours,
            "deep_sleep_hours": deepSleep,
            "rem_sleep_hours": remSleep,
            "core_sleep_hours": coreSleep,
            "awake_time_hours": awakeTime,
            "awakenings_count": awakeningsCount,
            "sleep_quality": calculateSleepQuality(),
            "falls_count": recentFalls.count,
            "fall_detected": !recentFalls.isEmpty
        ]
    }

    private func calculateSleepQuality() -> String {
        if totalSleepHours >= 7 && awakeningsCount <= 2 {
            return "excellent"
        } else if totalSleepHours >= 6 && awakeningsCount <= 4 {
            return "good"
        } else if totalSleepHours >= 5 {
            return "fair"
        }
        return "poor"
    }

    // MARK: - Authorization
    func requestAuthorization() {
        // Load demo data for simulator testing
        loadDemoData()

        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit not available on this device")
            return
        }

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .numberOfTimesFallen)!,
        ]

        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if success {
                DispatchQueue.main.async {
                    self.startObservingHealth()
                    self.fetchLatestVitals()
                    self.fetchSleepData()
                    self.fetchFallData()
                }
            } else if let error = error {
                print("Authorization failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Demo Data for Simulator
    private func loadDemoData() {
        DispatchQueue.main.async {
            // Vitals with occasional abnormalities
            self.heartRate = self.generateHeartRate()
            self.bloodOxygen = Double.random(in: 94...99)
            self.hrv = Double.random(in: 25...55)
            self.respiratoryRate = Double.random(in: 14...20)

            // Poor sleep data - showing sleep issues
            let deep = Double.random(in: 0.5...1.2)  // Low deep sleep
            let rem = Double.random(in: 0.8...1.5)   // Low REM
            let core = Double.random(in: 2.0...3.0)
            let awake = Double.random(in: 1.0...2.0) // High awake time - fragmented sleep
            self.totalSleepHours = deep + rem + core + awake  // Total around 4-7 hours (insufficient)
            self.sleepStages = [
                SleepStage(stage: "Deep", hours: deep, color: .indigo),
                SleepStage(stage: "REM", hours: rem, color: .cyan),
                SleepStage(stage: "Core", hours: core, color: .blue),
                SleepStage(stage: "Awake", hours: awake, color: .yellow)
            ]
            self.isSleepMonitoringActive = true

            // Fall detection - show 2 recent falls
            self.isFallDetectionEnabled = true
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
            let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
            self.recentFalls = [
                FallEvent(date: yesterday, resolved: true),
                FallEvent(date: twoDaysAgo, resolved: true)
            ]
        }

        // Update vitals every 5 seconds with occasional abnormalities
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.heartRate = self.generateHeartRate()
                self.bloodOxygen = Double.random(in: 93...99)
                self.hrv = Double.random(in: 20...55)
                self.respiratoryRate = Double.random(in: 14...22)

                // Send updated vitals to iPhone
                self.sendVitalsToiPhone()
            }
        }

        // Calculate awakenings from sleep data
        self.awakeningsCount = Int.random(in: 2...5)

        // Send initial vitals to iPhone
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.sendVitalsToiPhone()
        }
    }

    // Generate heart rate with occasional abnormalities
    private func generateHeartRate() -> Double {
        let chance = Int.random(in: 1...10)
        switch chance {
        case 1:
            return Double.random(in: 100...120)  // Tachycardia (high)
        case 2:
            return Double.random(in: 45...55)    // Bradycardia (low)
        case 3:
            return Double.random(in: 90...105)   // Elevated
        default:
            return Double.random(in: 65...85)    // Normal
        }
    }

    // MARK: - Start Observers
    private func startObservingHealth() {
        // Heart Rate Observer
        if let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) {
            heartRateQuery = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, _, error in
                if error == nil {
                    self?.fetchLatestHeartRate()
                }
            }

            if let query = heartRateQuery {
                healthStore.execute(query)
            }
        }

        // Sleep Observer
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            sleepQuery = HKObserverQuery(sampleType: sleepType, predicate: nil) { [weak self] _, _, error in
                if error == nil {
                    self?.fetchSleepData()
                }
            }

            if let query = sleepQuery {
                healthStore.execute(query)
            }
        }

        // Enable background delivery
        healthStore.enableBackgroundDelivery(for: HKObjectType.quantityType(forIdentifier: .heartRate)!, frequency: .immediate) { _, _ in }
        healthStore.enableBackgroundDelivery(for: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!, frequency: .hourly) { _, _ in }

        isSleepMonitoringActive = true
    }

    // MARK: - Fetch Latest Vitals
    func fetchLatestVitals() {
        fetchLatestHeartRate()
        fetchLatestBloodOxygen()
        fetchLatestHRV()
        fetchLatestRespiratoryRate()
    }

    private func fetchLatestHeartRate() {
        fetchLatestSample(for: .heartRate, unit: HKUnit(from: "count/min")) { [weak self] value in
            DispatchQueue.main.async {
                self?.heartRate = value
            }
        }
    }

    private func fetchLatestBloodOxygen() {
        fetchLatestSample(for: .oxygenSaturation, unit: HKUnit.percent()) { [weak self] value in
            DispatchQueue.main.async {
                self?.bloodOxygen = value * 100 // Convert to percentage
            }
        }
    }

    private func fetchLatestHRV() {
        fetchLatestSample(for: .heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli)) { [weak self] value in
            DispatchQueue.main.async {
                self?.hrv = value
            }
        }
    }

    private func fetchLatestRespiratoryRate() {
        fetchLatestSample(for: .respiratoryRate, unit: HKUnit(from: "count/min")) { [weak self] value in
            DispatchQueue.main.async {
                self?.respiratoryRate = value
            }
        }
    }

    private func fetchLatestSample(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping (Double) -> Void) {
        guard let sampleType = HKQuantityType.quantityType(forIdentifier: identifier) else { return }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: sampleType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else {
                completion(0)
                return
            }
            completion(sample.quantity.doubleValue(for: unit))
        }

        healthStore.execute(query)
    }

    // MARK: - Sleep Data
    func fetchSleepData() {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        // Get sleep from last 24 hours
        let now = Date()
        let startOfYesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfYesterday, end: now, options: .strictEndDate)

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
            guard let samples = samples as? [HKCategorySample] else { return }

            var totalSleep: Double = 0
            var deepSleep: Double = 0
            var remSleep: Double = 0
            var coreSleep: Double = 0
            var awakeSleep: Double = 0

            for sample in samples {
                let duration = sample.endDate.timeIntervalSince(sample.startDate) / 3600 // Hours

                switch sample.value {
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    deepSleep += duration
                    totalSleep += duration
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    remSleep += duration
                    totalSleep += duration
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                    coreSleep += duration
                    totalSleep += duration
                case HKCategoryValueSleepAnalysis.awake.rawValue:
                    awakeSleep += duration
                case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                    totalSleep += duration
                    coreSleep += duration
                default:
                    break
                }
            }

            DispatchQueue.main.async {
                self?.totalSleepHours = totalSleep

                var stages: [SleepStage] = []
                if deepSleep > 0 {
                    stages.append(SleepStage(stage: "Deep", hours: deepSleep, color: .indigo))
                }
                if remSleep > 0 {
                    stages.append(SleepStage(stage: "REM", hours: remSleep, color: .cyan))
                }
                if coreSleep > 0 {
                    stages.append(SleepStage(stage: "Core", hours: coreSleep, color: .blue))
                }
                if awakeSleep > 0 {
                    stages.append(SleepStage(stage: "Awake", hours: awakeSleep, color: .yellow))
                }
                self?.sleepStages = stages
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Fall Detection
    func fetchFallData() {
        guard let fallType = HKQuantityType.quantityType(forIdentifier: .numberOfTimesFallen) else { return }

        // Get falls from last 30 days
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: thirtyDaysAgo, end: now, options: .strictEndDate)

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: fallType, predicate: predicate, limit: 10, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
            guard let samples = samples as? [HKQuantitySample] else { return }

            let falls = samples.map { sample in
                FallEvent(date: sample.startDate, resolved: true)
            }

            DispatchQueue.main.async {
                self?.recentFalls = falls
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Emergency Alert
    func sendEmergencyAlert() {
        // TODO: Implement WatchConnectivity to send alert to iPhone app
        // which will then notify caregiver via SMS/Email
        print("Emergency alert triggered - sending to iPhone app")
    }

    deinit {
        if let query = heartRateQuery {
            healthStore.stop(query)
        }
        if let query = sleepQuery {
            healthStore.stop(query)
        }
    }
}
