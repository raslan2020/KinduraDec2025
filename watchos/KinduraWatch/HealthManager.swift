import Foundation
import HealthKit
import SwiftUI
import Combine
import WatchConnectivity
import WatchKit
import CoreMotion

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
    let severity: String  // "low", "medium", "high"
    let impactG: Double   // Impact force in G

    init(date: Date, resolved: Bool, severity: String = "medium", impactG: Double = 0) {
        self.date = date
        self.resolved = resolved
        self.severity = severity
        self.impactG = impactG
    }

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Health Manager
class HealthManager: NSObject, ObservableObject, WCSessionDelegate, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
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
    @Published var fallDetectionStatus: String = "Monitoring..."
    @Published var lastImpactG: Double = 0

    // CoreMotion for real-time fall detection
    private let motionManager = CMMotionManager()
    private var fallDetectionTimer: Timer?
    private var lastHighImpactTime: Date?
    private var isInFreeFall: Bool = false
    private var freeFallStartTime: Date?

    // Fall detection thresholds
    private let freeFallThreshold: Double = 0.3      // Below 0.3G indicates free fall
    private let impactThreshold: Double = 3.0        // Above 3G indicates hard impact
    private let fallConfirmationWindow: TimeInterval = 2.0  // Time window to confirm fall

    // Authorization & Monitoring State
    @Published var isHealthKitAuthorized: Bool = false
    @Published var isRealTimeMonitoring: Bool = false
    @Published var isWorkoutActive: Bool = false
    @Published var workoutStatus: String = "Not Active"

    private var heartRateQuery: HKObserverQuery?
    private var sleepQuery: HKObserverQuery?
    private var realTimeHeartRateQuery: HKAnchoredObjectQuery?
    private var realTimeBloodOxygenQuery: HKAnchoredObjectQuery?
    private var realTimeHRVQuery: HKAnchoredObjectQuery?
    private var refreshTimer: Timer?

    // Workout Session for real-time heart rate
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    // Throttling for API calls (30 second interval)
    private var lastVitalsSentTime: Date?
    private let vitalsThrottleInterval: TimeInterval = 30.0  // Send vitals every 30 seconds

    override init() {
        super.init()
        setupWatchConnectivity()
    }

    // MARK: - WatchConnectivity Setup
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            print("[HealthManager] WatchConnectivity not supported")
            return
        }

        wcSession = WCSession.default
        wcSession?.delegate = self
        wcSession?.activate()
        print("[HealthManager] WatchConnectivity activation requested")
    }

    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("[HealthManager] WCSession activation failed: \(error.localizedDescription)")
                return
            }

            switch activationState {
            case .activated:
                print("[HealthManager] WCSession activated successfully")
                // Request configuration from iPhone if not already configured
                if !ConfigurationManager.shared.isConfigured {
                    self.requestConfigurationFromiPhone()
                }
            case .inactive:
                print("[HealthManager] WCSession inactive")
            case .notActivated:
                print("[HealthManager] WCSession not activated")
            @unknown default:
                break
            }
        }
    }

    // MARK: - Receive Configuration from iPhone
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            print("[HealthManager] Received application context from iPhone: \(applicationContext.keys)")

            // Check if this is configuration data
            if let baseURL = applicationContext["api_base_url"] as? String,
               let token = applicationContext["auth_token"] as? String {
                ConfigurationManager.shared.updateConfiguration(baseURL: baseURL, token: token)
                print("[HealthManager] Configuration received from iPhone via context")

                // Sync any pending vitals now that we have configuration
                self.syncPendingVitals()
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            print("[HealthManager] Received message from iPhone: \(message.keys)")

            // Check if this is configuration data
            if let baseURL = message["api_base_url"] as? String,
               let token = message["auth_token"] as? String {
                ConfigurationManager.shared.updateConfiguration(baseURL: baseURL, token: token)
                print("[HealthManager] Configuration received from iPhone via message")

                // Sync any pending vitals
                self.syncPendingVitals()

                replyHandler(["status": "config_received"])
                return
            }

            // Handle remote workout control from iPhone
            if let command = message["command"] as? String {
                switch command {
                case "start_workout":
                    print("[HealthManager] 📲 Received start_workout command from iPhone")
                    if !self.isWorkoutActive {
                        self.startWorkoutSession()
                        self.startRealTimeMonitoring()
                        self.startFallDetection()
                        replyHandler(["status": "workout_started", "isWorkoutActive": true])
                    } else {
                        replyHandler(["status": "workout_already_active", "isWorkoutActive": true])
                    }
                    return

                case "stop_workout":
                    print("[HealthManager] 📲 Received stop_workout command from iPhone")
                    if self.isWorkoutActive {
                        self.stopWorkoutSession()
                        replyHandler(["status": "workout_stopped", "isWorkoutActive": false])
                    } else {
                        replyHandler(["status": "workout_not_active", "isWorkoutActive": false])
                    }
                    return

                case "get_status":
                    replyHandler([
                        "status": "ok",
                        "isWorkoutActive": self.isWorkoutActive,
                        "isRealTimeMonitoring": self.isRealTimeMonitoring,
                        "heartRate": self.heartRate,
                        "bloodOxygen": self.bloodOxygen,
                        "hrv": self.hrv,
                        "respiratoryRate": self.respiratoryRate
                    ])
                    return

                default:
                    print("[HealthManager] Unknown command: \(command)")
                }
            }

            replyHandler(["status": "received"])
        }
    }

    // Note: sessionDidBecomeInactive and sessionDidDeactivate are iOS-only
    // On watchOS, only session(_:activationDidCompleteWith:error:) is required

    // MARK: - Request Configuration from iPhone
    func requestConfigurationFromiPhone() {
        guard let session = wcSession, session.activationState == .activated else {
            print("[HealthManager] Cannot request config - session not activated")
            return
        }

        if session.isReachable {
            session.sendMessage(["type": "request_config"], replyHandler: { response in
                if let baseURL = response["api_base_url"] as? String,
                   let token = response["auth_token"] as? String {
                    DispatchQueue.main.async {
                        ConfigurationManager.shared.updateConfiguration(baseURL: baseURL, token: token)
                        print("[HealthManager] Configuration received via request")
                        self.syncPendingVitals()
                    }
                } else if let error = response["error"] as? String {
                    print("[HealthManager] Config request error: \(error)")
                }
            }, errorHandler: { error in
                print("[HealthManager] Failed to request configuration: \(error.localizedDescription)")
            })
        } else {
            print("[HealthManager] iPhone not reachable - will wait for configuration sync")
        }
    }

    // MARK: - Sync Pending Vitals (when iPhone becomes reachable)
    private func syncPendingVitals() {
        // Send any locally buffered vitals
        sendBufferedVitals()
    }

    // MARK: - Pending Vitals Buffer (for when iPhone is unreachable)
    private var pendingVitals: [[String: Any]] = []
    private let maxPendingVitals = 100  // Limit to prevent memory issues

    // MARK: - Send Vitals to iPhone (via WatchConnectivity ONLY)
    func sendVitalsToiPhone() {
        let vitalsData = createVitalsPayload()

        guard let session = wcSession, session.activationState == .activated else {
            print("[HealthManager] WCSession not activated - buffering vitals")
            bufferVitals(vitalsData)
            return
        }

        guard session.isReachable else {
            print("[HealthManager] iPhone not reachable - buffering vitals")
            bufferVitals(vitalsData)
            return
        }

        // Send current vitals to iPhone
        session.sendMessage(vitalsData, replyHandler: { [weak self] response in
            print("[HealthManager] ✅ Vitals sent to iPhone: \(response)")
            // After successful send, try to send any buffered vitals
            self?.sendBufferedVitals()
        }, errorHandler: { [weak self] error in
            print("[HealthManager] ❌ Failed to send to iPhone: \(error.localizedDescription)")
            self?.bufferVitals(vitalsData)
        })
    }

    // MARK: - Buffer Management
    private func bufferVitals(_ vitals: [String: Any]) {
        // Add to pending queue
        pendingVitals.append(vitals)

        // Trim old entries if over limit
        if pendingVitals.count > maxPendingVitals {
            pendingVitals.removeFirst(pendingVitals.count - maxPendingVitals)
            print("[HealthManager] ⚠️ Trimmed pending vitals to \(maxPendingVitals)")
        }

        print("[HealthManager] Buffered vitals (total pending: \(pendingVitals.count))")
    }

    private func sendBufferedVitals() {
        guard !pendingVitals.isEmpty else { return }
        guard let session = wcSession, session.isReachable else {
            print("[HealthManager] Cannot send buffered vitals - iPhone not reachable")
            return
        }

        print("[HealthManager] 📤 Sending \(pendingVitals.count) buffered vitals")

        // Send each buffered vital
        let vitalsToSend = pendingVitals
        pendingVitals.removeAll()

        for vitals in vitalsToSend {
            session.sendMessage(vitals, replyHandler: { response in
                print("[HealthManager] ✅ Buffered vital sent: \(response)")
            }, errorHandler: { [weak self] error in
                print("[HealthManager] ❌ Failed to send buffered vital: \(error)")
                // Re-buffer on failure
                self?.pendingVitals.append(vitals)
            })

            // Small delay between sends to avoid overwhelming
            Thread.sleep(forTimeInterval: 0.1)
        }
    }

    // MARK: - Send via Application Context (fallback for background)
    private func sendVitalsViaApplicationContext() {
        guard let session = wcSession else { return }

        let vitalsData = createVitalsPayload()

        do {
            try session.updateApplicationContext(vitalsData)
            print("[HealthManager] Vitals sent via application context")
        } catch {
            print("[HealthManager] Failed to update application context: \(error.localizedDescription)")
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
        requestAuthorization { _ in }
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[HealthManager] HealthKit not available on this device")
            DispatchQueue.main.async {
                self.isHealthKitAuthorized = false
                completion(false)
            }
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
            DispatchQueue.main.async {
                self.isHealthKitAuthorized = success

                if success {
                    print("[HealthManager] ✅ HealthKit authorization granted")
                    self.startObservingHealth()
                    self.fetchLatestVitals()
                    self.fetchSleepData()
                    self.fetchFallData()
                    self.startRealTimeMonitoring()
                    self.startFallDetection()  // Start CoreMotion fall detection
                } else if let error = error {
                    print("[HealthManager] ❌ Authorization failed: \(error.localizedDescription)")
                }

                completion(success)
            }
        }
    }

    // MARK: - Real-Time Monitoring
    func startRealTimeMonitoring() {
        guard !isRealTimeMonitoring else { return }

        print("[HealthManager] Starting real-time monitoring...")
        isRealTimeMonitoring = true

        // Start anchored queries for real-time updates
        startRealTimeHeartRateQuery()
        startRealTimeBloodOxygenQuery()
        startRealTimeHRVQuery()

        // Use a timer to periodically refresh data AND send to iPhone
        // This ensures iPhone always gets latest data even if values haven't changed
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.fetchLatestVitals()
            // Always send current vitals to iPhone every 5 seconds for real-time sync
            self?.sendVitalsToiPhone()
        }

        // Send initial vitals immediately
        sendVitalsToiPhone()

        print("[HealthManager] ✅ Real-time monitoring started (5-second sync enabled)")
    }

    func stopRealTimeMonitoring() {
        print("[HealthManager] Stopping real-time monitoring...")
        isRealTimeMonitoring = false

        // Stop anchored queries
        if let query = realTimeHeartRateQuery {
            healthStore.stop(query)
            realTimeHeartRateQuery = nil
        }
        if let query = realTimeBloodOxygenQuery {
            healthStore.stop(query)
            realTimeBloodOxygenQuery = nil
        }
        if let query = realTimeHRVQuery {
            healthStore.stop(query)
            realTimeHRVQuery = nil
        }

        // Stop timer
        refreshTimer?.invalidate()
        refreshTimer = nil

        print("[HealthManager] ⏹️ Real-time monitoring stopped")
    }

    private func startRealTimeHeartRateQuery() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, error in
            self?.processHeartRateSamples(samples)
        }

        query.updateHandler = { [weak self] _, samples, _, _, error in
            self?.processHeartRateSamples(samples)
        }

        realTimeHeartRateQuery = query
        healthStore.execute(query)
    }

    private func startRealTimeBloodOxygenQuery() {
        guard let bloodOxygenType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else { return }

        let query = HKAnchoredObjectQuery(
            type: bloodOxygenType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, error in
            self?.processBloodOxygenSamples(samples)
        }

        query.updateHandler = { [weak self] _, samples, _, _, error in
            self?.processBloodOxygenSamples(samples)
        }

        realTimeBloodOxygenQuery = query
        healthStore.execute(query)
    }

    private func startRealTimeHRVQuery() {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }

        let query = HKAnchoredObjectQuery(
            type: hrvType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, error in
            self?.processHRVSamples(samples)
        }

        query.updateHandler = { [weak self] _, samples, _, _, error in
            self?.processHRVSamples(samples)
        }

        realTimeHRVQuery = query
        healthStore.execute(query)
    }

    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let latest = samples.last else { return }

        let value = latest.quantity.doubleValue(for: HKUnit(from: "count/min"))
        DispatchQueue.main.async {
            self.heartRate = value
            print("[HealthManager] 💓 Real-time heart rate: \(Int(value)) BPM")
        }
    }

    private func processBloodOxygenSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let latest = samples.last else { return }

        let value = latest.quantity.doubleValue(for: HKUnit.percent()) * 100
        DispatchQueue.main.async {
            self.bloodOxygen = value
            print("[HealthManager] 🫁 Real-time blood oxygen: \(Int(value))%")
        }
    }

    private func processHRVSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let latest = samples.last else { return }

        let value = latest.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
        DispatchQueue.main.async {
            self.hrv = value
            print("[HealthManager] 📈 Real-time HRV: \(Int(value)) ms")
        }
    }

    // MARK: - Workout Session (Required for Real-time Heart Rate)
    /// Start a workout session to enable continuous heart rate monitoring
    /// Apple Watch ONLY streams heart rate during active workout sessions
    func startWorkoutSession() {
        guard !isWorkoutActive else {
            print("[HealthManager] Workout already active")
            return
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .indoor

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()

            workoutSession?.delegate = self
            workoutBuilder?.delegate = self

            // Set the workout builder's data source
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            // Start the workout session
            let startDate = Date()
            workoutSession?.startActivity(with: startDate)
            workoutBuilder?.beginCollection(withStart: startDate) { success, error in
                DispatchQueue.main.async {
                    if success {
                        self.isWorkoutActive = true
                        self.workoutStatus = "Active - Streaming Vitals"
                        print("[HealthManager] ✅ Workout session started - real-time heart rate enabled")
                    } else if let error = error {
                        self.workoutStatus = "Failed: \(error.localizedDescription)"
                        print("[HealthManager] ❌ Failed to start workout: \(error)")
                    }
                }
            }
        } catch {
            print("[HealthManager] ❌ Failed to create workout session: \(error)")
            DispatchQueue.main.async {
                self.workoutStatus = "Error: \(error.localizedDescription)"
            }
        }
    }

    /// Stop the workout session
    func stopWorkoutSession() {
        guard isWorkoutActive, let session = workoutSession else {
            print("[HealthManager] No active workout to stop")
            return
        }

        session.end()

        workoutBuilder?.endCollection(withEnd: Date()) { success, error in
            self.workoutBuilder?.finishWorkout { workout, error in
                DispatchQueue.main.async {
                    self.isWorkoutActive = false
                    self.workoutStatus = "Not Active"
                    self.workoutSession = nil
                    self.workoutBuilder = nil
                    print("[HealthManager] ⏹️ Workout session ended")
                }
            }
        }
    }

    // MARK: - HKWorkoutSessionDelegate
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            switch toState {
            case .running:
                self.isWorkoutActive = true
                self.workoutStatus = "Running"
                print("[HealthManager] Workout session running")
            case .ended:
                self.isWorkoutActive = false
                self.workoutStatus = "Ended"
                print("[HealthManager] Workout session ended")
            case .paused:
                self.workoutStatus = "Paused"
                print("[HealthManager] Workout session paused")
            default:
                break
            }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("[HealthManager] ❌ Workout session error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isWorkoutActive = false
            self.workoutStatus = "Error: \(error.localizedDescription)"
        }
    }

    // MARK: - HKLiveWorkoutBuilderDelegate
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }

            // Get the most recent statistics
            if let statistics = workoutBuilder.statistics(for: quantityType) {
                DispatchQueue.main.async {
                    self.processWorkoutStatistics(statistics, for: quantityType)
                }
            }
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }

    private func processWorkoutStatistics(_ statistics: HKStatistics, for quantityType: HKQuantityType) {
        switch quantityType.identifier {
        case HKQuantityTypeIdentifier.heartRate.rawValue:
            if let value = statistics.mostRecentQuantity()?.doubleValue(for: HKUnit(from: "count/min")) {
                heartRate = value
                print("[HealthManager] 💓 Workout HR: \(Int(value)) BPM")
                // Throttled API call - only send every 30 seconds
                throttledSendVitals()
            }

        case HKQuantityTypeIdentifier.oxygenSaturation.rawValue:
            if let value = statistics.mostRecentQuantity()?.doubleValue(for: HKUnit.percent()) {
                bloodOxygen = value * 100
                print("[HealthManager] 🫁 Workout SpO2: \(Int(bloodOxygen))%")
            }

        case HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue:
            if let value = statistics.mostRecentQuantity()?.doubleValue(for: HKUnit.secondUnit(with: .milli)) {
                hrv = value
                print("[HealthManager] 📈 Workout HRV: \(Int(value)) ms")
            }

        default:
            break
        }
    }

    /// Throttled vitals sending - only sends if 30 seconds have passed since last send
    private func throttledSendVitals() {
        let now = Date()

        if let lastSent = lastVitalsSentTime {
            let timeSinceLastSend = now.timeIntervalSince(lastSent)
            if timeSinceLastSend < vitalsThrottleInterval {
                // Skip - sent too recently
                return
            }
        }

        // Update timestamp and send to iPhone (iPhone forwards to Django)
        lastVitalsSentTime = now
        print("[HealthManager] 📤 Sending vitals to iPhone (throttled - every \(Int(vitalsThrottleInterval))s)")
        sendVitalsToiPhone()
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
                let oldValue = self?.heartRate ?? 0
                self?.heartRate = value
                // Send to iPhone if value changed significantly (more than 2 BPM)
                if abs(value - oldValue) >= 2 {
                    print("[HealthManager] ❤️ Heart rate changed: \(Int(oldValue)) → \(Int(value))")
                    self?.sendVitalsToiPhone()
                }
            }
        }
    }

    private func fetchLatestBloodOxygen() {
        fetchLatestSample(for: .oxygenSaturation, unit: HKUnit.percent()) { [weak self] value in
            DispatchQueue.main.async {
                let newValue = value * 100 // Convert to percentage
                let oldValue = self?.bloodOxygen ?? 0
                self?.bloodOxygen = newValue
                // Send to iPhone if value changed
                if abs(newValue - oldValue) >= 1 {
                    print("[HealthManager] 🫁 Blood oxygen changed: \(Int(oldValue))% → \(Int(newValue))%")
                    self?.sendVitalsToiPhone()
                }
            }
        }
    }

    private func fetchLatestHRV() {
        fetchLatestSample(for: .heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli)) { [weak self] value in
            DispatchQueue.main.async {
                let oldValue = self?.hrv ?? 0
                self?.hrv = value
                // Send to iPhone if value changed
                if abs(value - oldValue) >= 2 {
                    print("[HealthManager] 📊 HRV changed: \(Int(oldValue)) → \(Int(value))")
                    self?.sendVitalsToiPhone()
                }
            }
        }
    }

    private func fetchLatestRespiratoryRate() {
        fetchLatestSample(for: .respiratoryRate, unit: HKUnit(from: "count/min")) { [weak self] value in
            DispatchQueue.main.async {
                let oldValue = self?.respiratoryRate ?? 0
                self?.respiratoryRate = value
                // Send to iPhone if value changed
                if abs(value - oldValue) >= 0.5 {
                    print("[HealthManager] 🌬️ Respiratory rate changed: \(oldValue) → \(value)")
                    self?.sendVitalsToiPhone()
                }
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

    // MARK: - Real-Time Fall Detection (CoreMotion)

    /// Start real-time fall detection using accelerometer
    func startFallDetection() {
        guard motionManager.isAccelerometerAvailable else {
            print("[HealthManager] ❌ Accelerometer not available")
            DispatchQueue.main.async {
                self.fallDetectionStatus = "Sensor unavailable"
            }
            return
        }

        guard isFallDetectionEnabled else {
            print("[HealthManager] Fall detection is disabled")
            return
        }

        // Set update interval (100Hz for accurate fall detection)
        motionManager.accelerometerUpdateInterval = 0.01  // 100 Hz

        print("[HealthManager] 🛡️ Starting real-time fall detection...")

        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else {
                if let error = error {
                    print("[HealthManager] Accelerometer error: \(error.localizedDescription)")
                }
                return
            }

            self.processAccelerometerData(data)
        }

        DispatchQueue.main.async {
            self.fallDetectionStatus = "Active - Monitoring"
        }

        print("[HealthManager] ✅ Fall detection started")
    }

    /// Stop fall detection
    func stopFallDetection() {
        motionManager.stopAccelerometerUpdates()
        fallDetectionTimer?.invalidate()
        fallDetectionTimer = nil

        DispatchQueue.main.async {
            self.fallDetectionStatus = "Stopped"
        }

        print("[HealthManager] ⏹️ Fall detection stopped")
    }

    /// Process accelerometer data for fall detection
    private func processAccelerometerData(_ data: CMAccelerometerData) {
        // Calculate total acceleration magnitude (in G)
        let x = data.acceleration.x
        let y = data.acceleration.y
        let z = data.acceleration.z
        let totalG = sqrt(x*x + y*y + z*z)

        // Update last impact G for UI display
        DispatchQueue.main.async {
            self.lastImpactG = totalG
        }

        // Phase 1: Detect free fall (low G)
        if totalG < freeFallThreshold {
            if !isInFreeFall {
                isInFreeFall = true
                freeFallStartTime = Date()
                print("[HealthManager] 🔻 Free fall detected! G=\(String(format: "%.2f", totalG))")
            }
        } else {
            // Phase 2: Detect impact after free fall
            if isInFreeFall, let fallStart = freeFallStartTime {
                let fallDuration = Date().timeIntervalSince(fallStart)

                // If we had a free fall phase and now see high impact
                if totalG > impactThreshold && fallDuration < fallConfirmationWindow {
                    // FALL DETECTED!
                    print("[HealthManager] ⚠️ FALL DETECTED! Impact=\(String(format: "%.2f", totalG))G, Duration=\(String(format: "%.2f", fallDuration))s")

                    // Determine severity based on impact force
                    let severity: String
                    if totalG > 8.0 {
                        severity = "high"
                    } else if totalG > 5.0 {
                        severity = "medium"
                    } else {
                        severity = "low"
                    }

                    // Record the fall
                    handleFallDetected(impactG: totalG, severity: severity)
                }

                // Reset free fall state
                isInFreeFall = false
                freeFallStartTime = nil
            }

            // Also detect sudden high impacts without free fall (slip and fall)
            if totalG > impactThreshold * 1.5 {  // Higher threshold for impact-only detection
                let now = Date()
                if let lastImpact = lastHighImpactTime {
                    // Avoid duplicate detections within 5 seconds
                    if now.timeIntervalSince(lastImpact) > 5.0 {
                        print("[HealthManager] ⚠️ HIGH IMPACT DETECTED! G=\(String(format: "%.2f", totalG))")
                        handleFallDetected(impactG: totalG, severity: totalG > 8.0 ? "high" : "medium")
                        lastHighImpactTime = now
                    }
                } else {
                    print("[HealthManager] ⚠️ HIGH IMPACT DETECTED! G=\(String(format: "%.2f", totalG))")
                    handleFallDetected(impactG: totalG, severity: totalG > 8.0 ? "high" : "medium")
                    lastHighImpactTime = now
                }
            }
        }
    }

    /// Handle a detected fall
    private func handleFallDetected(impactG: Double, severity: String) {
        let fallEvent = FallEvent(
            date: Date(),
            resolved: false,
            severity: severity,
            impactG: impactG
        )

        DispatchQueue.main.async {
            // Add to recent falls
            self.recentFalls.insert(fallEvent, at: 0)

            // Keep only last 20 falls
            if self.recentFalls.count > 20 {
                self.recentFalls = Array(self.recentFalls.prefix(20))
            }

            // Update status
            self.fallDetectionStatus = "⚠️ Fall detected!"

            // Play haptic alert
            WKInterfaceDevice.current().play(.notification)
        }

        // Send fall alert to iPhone immediately
        sendFallAlertToiPhone(fallEvent: fallEvent)

        // Also send vitals update with fall info
        sendVitalsToiPhone()

        // Reset status after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.fallDetectionStatus = "Active - Monitoring"
        }
    }

    /// Send fall alert to iPhone via WatchConnectivity
    private func sendFallAlertToiPhone(fallEvent: FallEvent) {
        guard let session = wcSession, session.activationState == .activated else {
            print("[HealthManager] Cannot send fall alert - WCSession not activated")
            return
        }

        let fallData: [String: Any] = [
            "type": "fall_alert",
            "timestamp": ISO8601DateFormatter().string(from: fallEvent.date),
            "severity": fallEvent.severity,
            "impact_g": fallEvent.impactG,
            "heart_rate": heartRate,
            "blood_oxygen": bloodOxygen,
            "requires_response": true
        ]

        if session.isReachable {
            session.sendMessage(fallData, replyHandler: { response in
                print("[HealthManager] ✅ Fall alert sent to iPhone: \(response)")
            }, errorHandler: { error in
                print("[HealthManager] ❌ Failed to send fall alert: \(error.localizedDescription)")
                // Try application context as backup
                try? session.updateApplicationContext(fallData)
            })
        } else {
            // Use application context for when iPhone isn't reachable
            do {
                try session.updateApplicationContext(fallData)
                print("[HealthManager] Fall alert sent via application context")
            } catch {
                print("[HealthManager] Failed to send fall alert via context: \(error)")
            }
        }
    }

    // MARK: - Emergency Alert
    func sendEmergencyAlert() {
        print("[HealthManager] 🚨 Emergency alert triggered!")

        // Create emergency fall event
        let emergencyEvent = FallEvent(
            date: Date(),
            resolved: false,
            severity: "high",
            impactG: 0
        )

        // Play emergency haptic
        WKInterfaceDevice.current().play(.failure)

        // Send to iPhone
        sendFallAlertToiPhone(fallEvent: emergencyEvent)

        // Update UI
        DispatchQueue.main.async {
            self.fallDetectionStatus = "🚨 Emergency sent!"
            self.recentFalls.insert(emergencyEvent, at: 0)
        }
    }

    deinit {
        // Stop observer queries
        if let query = heartRateQuery {
            healthStore.stop(query)
        }
        if let query = sleepQuery {
            healthStore.stop(query)
        }

        // Stop real-time queries
        stopRealTimeMonitoring()

        // Stop fall detection
        stopFallDetection()
    }
}
