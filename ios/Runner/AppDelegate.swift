import UIKit
import Flutter
import WatchConnectivity
import AVFoundation
import HealthKit

@main
@objc class AppDelegate: FlutterAppDelegate, WCSessionDelegate {
    private var watchVitalsChannel: FlutterMethodChannel?
    private var latestWatchVitals: [String: Any]?
    private let appGroupIdentifier = "group.com.kindura.ai"
    private let healthStore = HKHealthStore()

    // Pending vitals queue for when API is unreachable
    private var pendingVitalsQueue: [[String: Any]] = []
    private let maxPendingVitals = 50

    // HealthKit observer queries for real-time updates
    private var heartRateObserver: HKObserverQuery?
    private var bloodOxygenObserver: HKObserverQuery?
    private var stepsObserver: HKObserverQuery?
    private var sleepObserver: HKObserverQuery?
    private var healthKitObserversActive = false

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Configure audio session for LiveKit voice calls
        configureAudioSession()

        // Setup WatchConnectivity
        setupWatchConnectivity()

        // Setup Flutter method channel for Watch vitals
        setupFlutterMethodChannel()

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - WatchConnectivity Setup

    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            print("[AppDelegate] WatchConnectivity not supported on this device")
            return
        }

        let session = WCSession.default
        session.delegate = self
        session.activate()
        print("[AppDelegate] WatchConnectivity activation requested")
    }

    // MARK: - Flutter Method Channel Setup

    private func setupFlutterMethodChannel() {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            print("[AppDelegate] Failed to get FlutterViewController")
            return
        }

        watchVitalsChannel = FlutterMethodChannel(
            name: "com.kindura.ai/watch_vitals",
            binaryMessenger: controller.binaryMessenger
        )

        watchVitalsChannel?.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "getLatestVitals":
                result(self?.latestWatchVitals)

            case "updateWatchConfiguration":
                if let args = call.arguments as? [String: Any],
                   let baseURL = args["baseURL"] as? String,
                   let token = args["token"] as? String {
                    self?.sendConfigurationToWatch(baseURL: baseURL, token: token)
                    result(true)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing baseURL or token", details: nil))
                }

            case "isWatchPaired":
                let session = WCSession.default
                result(session.isPaired && session.isWatchAppInstalled)

            case "isWatchReachable":
                result(WCSession.default.isReachable)

            case "requestHealthKitAuthorization":
                self?.requestHealthKitAuthorization(result: result)

            case "isHealthKitAuthorized":
                self?.checkHealthKitAuthorization(result: result)

            case "getHealthSummary":
                self?.getHealthSummary(result: result)

            case "getSleepData":
                self?.getSleepData(result: result)

            case "getActivityData":
                self?.getActivityData(result: result)

            case "getWeeklySummary":
                self?.getWeeklyHealthSummary(result: result)

            case "getMonthlySummary":
                self?.getMonthlyHealthSummary(result: result)

            case "getComprehensiveHealth":
                self?.getHealthSummary(result: result)

            case "getHealthHistory":
                if let args = call.arguments as? [String: Any],
                   let days = args["days"] as? Int {
                    self?.getHealthHistory(days: days, result: result)
                } else {
                    self?.getHealthHistory(days: 7, result: result)
                }

            case "startHealthKitObservers":
                self?.startHealthKitObservers()
                result(true)

            case "stopHealthKitObservers":
                self?.stopHealthKitObservers()
                result(true)

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // Auto-start observers if already authorized
        if UserDefaults.standard.bool(forKey: "healthkit_authorized") {
            print("[AppDelegate] HealthKit previously authorized - starting observers")
            startHealthKitObservers()
        }
    }

    // MARK: - HealthKit Data Fetching

    /// Get comprehensive health summary for the home widget
    private func getHealthSummary(result: @escaping FlutterResult) {
        print("[AppDelegate] ========== getHealthSummary CALLED ==========")
        print("[AppDelegate] HealthKit available: \(HKHealthStore.isHealthDataAvailable())")

        // Check authorization status for key types
        if let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) {
            let status = healthStore.authorizationStatus(for: hrType)
            print("[AppDelegate] Heart rate auth status: \(status.rawValue) (0=notDetermined, 1=sharingDenied, 2=sharingAuthorized)")
        }

        let group = DispatchGroup()
        var healthData: [String: Any] = [:]

        // ===== VITALS =====

        // Fetch latest heart rate
        group.enter()
        fetchLatestQuantity(type: .heartRate) { value in
            print("[AppDelegate] Heart rate fetched: \(value ?? 0)")
            healthData["heart_rate"] = Int(value ?? 0)
            group.leave()
        }

        // Fetch latest blood oxygen
        group.enter()
        fetchLatestQuantity(type: .oxygenSaturation) { value in
            let bloodOxygen = Int((value ?? 0) * 100)
            print("[AppDelegate] Blood oxygen fetched: \(bloodOxygen)")
            healthData["blood_oxygen"] = bloodOxygen
            group.leave()
        }

        // Fetch latest HRV
        group.enter()
        fetchLatestQuantity(type: .heartRateVariabilitySDNN) { value in
            print("[AppDelegate] HRV fetched: \(value ?? 0)")
            healthData["hrv"] = Int(value ?? 0)
            group.leave()
        }

        // Fetch latest respiratory rate
        group.enter()
        fetchLatestQuantity(type: .respiratoryRate) { value in
            print("[AppDelegate] Respiratory rate fetched: \(value ?? 0)")
            healthData["respiratory_rate"] = value ?? 0
            group.leave()
        }

        // Fetch resting heart rate
        group.enter()
        fetchLatestQuantity(type: .restingHeartRate) { value in
            healthData["resting_heart_rate"] = Int(value ?? 0)
            group.leave()
        }

        // Fetch walking heart rate average
        group.enter()
        fetchLatestQuantity(type: .walkingHeartRateAverage) { value in
            healthData["walking_heart_rate"] = Int(value ?? 0)
            group.leave()
        }

        // ===== ACTIVITY =====

        // Fetch today's steps
        group.enter()
        fetchTodayQuantity(type: .stepCount) { value in
            healthData["steps"] = Int(value ?? 0)
            group.leave()
        }

        // Fetch today's active calories
        group.enter()
        fetchTodayQuantity(type: .activeEnergyBurned) { value in
            healthData["calories"] = Int(value ?? 0)
            group.leave()
        }

        // Fetch today's distance
        group.enter()
        fetchTodayQuantity(type: .distanceWalkingRunning) { value in
            healthData["distance_km"] = (value ?? 0) / 1000  // Convert meters to km
            group.leave()
        }

        // Fetch floors climbed
        group.enter()
        fetchTodayQuantity(type: .flightsClimbed) { value in
            healthData["floors_climbed"] = Int(value ?? 0)
            group.leave()
        }

        // Fetch exercise minutes
        group.enter()
        fetchTodayQuantity(type: .appleExerciseTime) { value in
            healthData["exercise_minutes"] = Int(value ?? 0)
            group.leave()
        }

        // Fetch stand time
        group.enter()
        fetchTodayQuantity(type: .appleStandTime) { value in
            healthData["stand_minutes"] = Int(value ?? 0)
            group.leave()
        }

        // ===== SLEEP =====

        // Fetch last night's sleep
        group.enter()
        fetchLastNightSleep { total, stages in
            print("[AppDelegate] 😴 Sleep data - Total: \(total)h, Stages: \(stages)")
            healthData["sleep_hours"] = total
            healthData["sleep_stages"] = stages

            // Calculate sleep score (simplified algorithm)
            var sleepScore = 0
            var deepHours = 0.0
            var remHours = 0.0
            var coreHours = 0.0
            var awakeHours = 0.0

            for stage in stages {
                if let stageType = stage["stage"] as? String, let hours = stage["hours"] as? Double {
                    switch stageType {
                    case "Deep": deepHours = hours
                    case "REM": remHours = hours
                    case "Core": coreHours = hours
                    case "Awake": awakeHours = hours
                    default: break
                    }
                }
            }

            healthData["deep_sleep_hours"] = deepHours
            healthData["rem_sleep_hours"] = remHours
            healthData["core_sleep_hours"] = coreHours
            healthData["awake_hours"] = awakeHours

            // Simple sleep score: max 100
            if total > 0 {
                let qualityScore = min(50, ((deepHours + remHours) / total) * 100)
                let durationScore = min(50, (total / 8.0) * 50)
                sleepScore = Int(qualityScore + durationScore)
            }
            healthData["sleep_score"] = sleepScore

            group.leave()
        }

        // ===== BLOOD PRESSURE =====

        group.enter()
        fetchBloodPressure { systolic, diastolic, timestamp in
            if systolic > 0 && diastolic > 0 {
                healthData["blood_pressure_systolic"] = Int(systolic)
                healthData["blood_pressure_diastolic"] = Int(diastolic)
                healthData["blood_pressure_timestamp"] = timestamp
            }
            group.leave()
        }

        // ===== AUDIO EXPOSURE =====

        group.enter()
        fetchAudioExposure { headphone, environmental in
            if headphone > 0 {
                healthData["headphone_audio_db"] = headphone
            }
            if environmental > 0 {
                healthData["environmental_audio_db"] = environmental
            }
            group.leave()
        }

        // ===== WORKOUTS =====

        group.enter()
        fetchTodayWorkouts { workouts in
            healthData["workouts_today"] = workouts
            healthData["workouts_count"] = workouts.count
            group.leave()
        }

        // ===== AFIB HISTORY =====

        group.enter()
        fetchAFibHistory { afibEvents in
            healthData["afib_history"] = afibEvents
            healthData["afib_detected"] = !afibEvents.isEmpty
            group.leave()
        }

        group.notify(queue: .main) {
            healthData["source"] = "apple_health"
            healthData["fetched_at"] = ISO8601DateFormatter().string(from: Date())
            print("[AppDelegate] Health data complete - HR: \(healthData["heart_rate"] ?? "nil"), O2: \(healthData["blood_oxygen"] ?? "nil"), Steps: \(healthData["steps"] ?? "nil"), Sleep: \(healthData["sleep_hours"] ?? "nil")")
            result(healthData)
        }
    }

    /// Get health history for specified number of days (for Vitals History screen)
    private func getHealthHistory(days: Int, result: @escaping FlutterResult) {
        print("[AppDelegate] getHealthHistory called for \(days) days")
        let group = DispatchGroup()
        var historyData: [[String: Any]] = []

        let now = Date()
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: now) else {
            result([])
            return
        }

        // Fetch heart rate samples
        group.enter()
        fetchQuantitySamples(type: .heartRate, startDate: startDate, endDate: now) { samples in
            for sample in samples {
                historyData.append([
                    "type": "heart_rate",
                    "value": sample["value"] as Any,
                    "timestamp": sample["timestamp"] as Any,
                ])
            }
            print("[AppDelegate] Heart rate samples: \(samples.count)")
            group.leave()
        }

        // Fetch blood oxygen samples
        group.enter()
        fetchQuantitySamples(type: .oxygenSaturation, startDate: startDate, endDate: now) { samples in
            for sample in samples {
                let value = (sample["value"] as? Double ?? 0) * 100
                historyData.append([
                    "type": "blood_oxygen",
                    "value": Int(value),
                    "timestamp": sample["timestamp"] as Any,
                ])
            }
            print("[AppDelegate] Blood oxygen samples: \(samples.count)")
            group.leave()
        }

        // Fetch HRV samples
        group.enter()
        fetchQuantitySamples(type: .heartRateVariabilitySDNN, startDate: startDate, endDate: now) { samples in
            for sample in samples {
                historyData.append([
                    "type": "hrv",
                    "value": sample["value"] as Any,
                    "timestamp": sample["timestamp"] as Any,
                ])
            }
            print("[AppDelegate] HRV samples: \(samples.count)")
            group.leave()
        }

        // Fetch sleep analysis
        group.enter()
        fetchSleepHistory(startDate: startDate, endDate: now) { sleepRecords in
            for record in sleepRecords {
                historyData.append([
                    "type": "sleep",
                    "value": record["hours"] as Any,
                    "timestamp": record["date"] as Any,
                    "stages": record["stages"] as Any,
                ])
            }
            print("[AppDelegate] Sleep records: \(sleepRecords.count)")
            group.leave()
        }

        group.notify(queue: .main) {
            print("[AppDelegate] Health history complete - \(historyData.count) total records")
            result(historyData)
        }
    }

    /// Fetch quantity samples for a date range
    private func fetchQuantitySamples(type: HKQuantityTypeIdentifier, startDate: Date, endDate: Date, completion: @escaping ([[String: Any]]) -> Void) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: type) else {
            completion([])
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: quantityType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
            if let error = error {
                print("[AppDelegate] Error fetching samples for \(type): \(error)")
                completion([])
                return
            }

            guard let quantitySamples = samples as? [HKQuantitySample] else {
                completion([])
                return
            }

            let unit: HKUnit
            switch type {
            case .heartRate:
                unit = HKUnit.count().unitDivided(by: .minute())
            case .oxygenSaturation:
                unit = .percent()
            case .heartRateVariabilitySDNN:
                unit = .secondUnit(with: .milli)
            case .respiratoryRate:
                unit = HKUnit.count().unitDivided(by: .minute())
            default:
                unit = .count()
            }

            let results = quantitySamples.map { sample -> [String: Any] in
                return [
                    "value": sample.quantity.doubleValue(for: unit),
                    "timestamp": ISO8601DateFormatter().string(from: sample.startDate),
                ]
            }

            completion(results)
        }

        self.healthStore.execute(query)
    }

    /// Fetch sleep history by date
    private func fetchSleepHistory(startDate: Date, endDate: Date, completion: @escaping ([[String: Any]]) -> Void) {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion([])
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
            if let error = error {
                print("[AppDelegate] Error fetching sleep history: \(error)")
                completion([])
                return
            }

            guard let sleepSamples = samples as? [HKCategorySample] else {
                completion([])
                return
            }

            // Group sleep by date
            var sleepByDate: [String: [HKCategorySample]] = [:]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            for sample in sleepSamples {
                let dateKey = dateFormatter.string(from: sample.startDate)
                if sleepByDate[dateKey] == nil {
                    sleepByDate[dateKey] = []
                }
                sleepByDate[dateKey]?.append(sample)
            }

            // Calculate totals per day
            var results: [[String: Any]] = []
            for (dateKey, daySamples) in sleepByDate {
                var totalSleep: TimeInterval = 0
                var deepSleep: TimeInterval = 0
                var remSleep: TimeInterval = 0
                var coreSleep: TimeInterval = 0
                var awakeSleep: TimeInterval = 0

                for sample in daySamples {
                    let duration = sample.endDate.timeIntervalSince(sample.startDate)

                    if #available(iOS 16.0, *) {
                        switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
                        case .asleepCore:
                            coreSleep += duration
                            totalSleep += duration
                        case .asleepDeep:
                            deepSleep += duration
                            totalSleep += duration
                        case .asleepREM:
                            remSleep += duration
                            totalSleep += duration
                        case .awake:
                            awakeSleep += duration
                        case .asleepUnspecified, .asleep:
                            coreSleep += duration
                            totalSleep += duration
                        default:
                            break
                        }
                    } else {
                        if sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue {
                            totalSleep += duration
                            coreSleep += duration
                        } else if sample.value == HKCategoryValueSleepAnalysis.awake.rawValue {
                            awakeSleep += duration
                        }
                    }
                }

                results.append([
                    "date": dateKey,
                    "hours": totalSleep / 3600,
                    "stages": [
                        "deep": deepSleep / 3600,
                        "rem": remSleep / 3600,
                        "core": coreSleep / 3600,
                        "awake": awakeSleep / 3600,
                    ]
                ])
            }

            completion(results)
        }

        self.healthStore.execute(query)
    }

    /// Get detailed sleep data
    private func getSleepData(result: @escaping FlutterResult) {
        fetchLastNightSleep { total, stages in
            DispatchQueue.main.async {
                result([
                    "total_hours": total,
                    "stages": stages,
                    "source": "apple_health"
                ])
            }
        }
    }

    /// Get today's activity data
    private func getActivityData(result: @escaping FlutterResult) {
        let group = DispatchGroup()
        var activityData: [String: Any] = [:]

        group.enter()
        fetchTodayQuantity(type: .stepCount) { value in
            activityData["steps"] = Int(value ?? 0)
            group.leave()
        }

        group.enter()
        fetchTodayQuantity(type: .activeEnergyBurned) { value in
            activityData["active_calories"] = Int(value ?? 0)
            group.leave()
        }

        group.enter()
        fetchTodayQuantity(type: .distanceWalkingRunning) { value in
            activityData["distance_km"] = (value ?? 0) / 1000
            group.leave()
        }

        group.enter()
        fetchTodayQuantity(type: .flightsClimbed) { value in
            activityData["floors_climbed"] = Int(value ?? 0)
            group.leave()
        }

        group.notify(queue: .main) {
            activityData["date"] = ISO8601DateFormatter().string(from: Date())
            result(activityData)
        }
    }

    // MARK: - HealthKit Helpers

    private func fetchTodayQuantity(type: HKQuantityTypeIdentifier, completion: @escaping (Double?) -> Void) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: type) else {
            completion(nil)
            return
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, _ in
            let unit: HKUnit
            switch type {
            case .stepCount, .flightsClimbed:
                unit = .count()
            case .activeEnergyBurned:
                unit = .kilocalorie()
            case .distanceWalkingRunning:
                unit = .meter()
            case .appleExerciseTime, .appleStandTime:
                unit = .minute()
            default:
                unit = .count()
            }

            let value = statistics?.sumQuantity()?.doubleValue(for: unit)
            completion(value)
        }

        healthStore.execute(query)
    }

    /// Fetch the most recent sample for a given quantity type from HealthKit
    /// This gets the latest sample without time restrictions to ensure data availability
    private func fetchLatestQuantity(type: HKQuantityTypeIdentifier, completion: @escaping (Double?) -> Void) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: type) else {
            print("[AppDelegate] ❌ Invalid quantity type: \(type)")
            completion(nil)
            return
        }

        // Get the most recent sample (no time restriction)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: quantityType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            if let error = error {
                print("[AppDelegate] ❌ Error fetching \(type.rawValue): \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let sample = samples?.first as? HKQuantitySample else {
                print("[AppDelegate] ⚠️ No samples found for \(type.rawValue)")
                completion(nil)
                return
            }

            let unit: HKUnit
            switch type {
            case .heartRate:
                unit = HKUnit.count().unitDivided(by: .minute())
            case .oxygenSaturation:
                unit = .percent()
            case .heartRateVariabilitySDNN:
                unit = .secondUnit(with: .milli)
            case .respiratoryRate:
                unit = HKUnit.count().unitDivided(by: .minute())
            case .restingHeartRate:
                unit = HKUnit.count().unitDivided(by: .minute())
            case .walkingHeartRateAverage:
                unit = HKUnit.count().unitDivided(by: .minute())
            default:
                unit = .count()
            }

            let value = sample.quantity.doubleValue(for: unit)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "HH:mm:ss"
            print("[AppDelegate] ✅ \(type.rawValue): \(value) @ \(dateFormatter.string(from: sample.startDate))")
            completion(value)
        }

        healthStore.execute(query)
    }

    private func fetchLastNightSleep(completion: @escaping (Double, [[String: Any]]) -> Void) {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            print("[AppDelegate] ❌ Sleep type not available")
            completion(0, [])
            return
        }

        // Check authorization status
        let authStatus = healthStore.authorizationStatus(for: sleepType)
        print("[AppDelegate] 😴 Sleep authorization status: \(authStatus.rawValue) (0=notDetermined, 1=sharingDenied, 2=sharingAuthorized)")

        // Get sleep from last 36 hours (covers yesterday evening sleep)
        let now = Date()
        let calendar = Calendar.current

        // Start from 6 PM yesterday to capture typical sleep window
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 18 // 6 PM
        components.minute = 0
        let todayEvening = calendar.date(from: components) ?? now
        let startDate = calendar.date(byAdding: .day, value: -1, to: todayEvening) ?? now

        print("[AppDelegate] 😴 Querying sleep from \(startDate) to \(now)")
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictEndDate)

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
            if let error = error {
                print("[AppDelegate] ❌ Sleep query error: \(error.localizedDescription)")
                completion(0, [])
                return
            }

            guard let sleepSamples = samples as? [HKCategorySample] else {
                print("[AppDelegate] ⚠️ No sleep samples found")
                completion(0, [])
                return
            }

            print("[AppDelegate] 😴 Found \(sleepSamples.count) sleep samples")

            var totalSleep: TimeInterval = 0
            var stages: [[String: Any]] = []
            var deepSleep: TimeInterval = 0
            var remSleep: TimeInterval = 0
            var coreSleep: TimeInterval = 0
            var awakeSleep: TimeInterval = 0

            for sample in sleepSamples {
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                print("[AppDelegate] Sleep sample: value=\(sample.value), duration=\(duration/3600)h")

                // Categorize by sleep stage - iOS 16+ has specific stages
                if #available(iOS 16.0, *) {
                    let sleepValue = HKCategoryValueSleepAnalysis(rawValue: sample.value)
                    switch sleepValue {
                    case .asleepCore:
                        coreSleep += duration
                        totalSleep += duration
                        print("[AppDelegate] → Core sleep: \(duration/3600)h")
                    case .asleepDeep:
                        deepSleep += duration
                        totalSleep += duration
                        print("[AppDelegate] → Deep sleep: \(duration/3600)h")
                    case .asleepREM:
                        remSleep += duration
                        totalSleep += duration
                        print("[AppDelegate] → REM sleep: \(duration/3600)h")
                    case .awake:
                        awakeSleep += duration
                        print("[AppDelegate] → Awake: \(duration/3600)h")
                    case .asleepUnspecified:
                        coreSleep += duration
                        totalSleep += duration
                        print("[AppDelegate] → Unspecified sleep (counted as Core): \(duration/3600)h")
                    case .asleep:
                        coreSleep += duration
                        totalSleep += duration
                        print("[AppDelegate] → Asleep (counted as Core): \(duration/3600)h")
                    case .inBed:
                        print("[AppDelegate] → In bed (not counted): \(duration/3600)h")
                    default:
                        print("[AppDelegate] → Unknown sleep value \(sample.value): \(duration/3600)h")
                        break
                    }
                } else {
                    // iOS 15 and earlier
                    if sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue {
                        totalSleep += duration
                        coreSleep += duration
                    } else if sample.value == HKCategoryValueSleepAnalysis.awake.rawValue {
                        awakeSleep += duration
                    }
                }
            }

            // Build stages array
            print("[AppDelegate] 😴 Sleep totals - Deep: \(deepSleep/3600)h, REM: \(remSleep/3600)h, Core: \(coreSleep/3600)h, Awake: \(awakeSleep/3600)h, Total: \(totalSleep/3600)h")

            if deepSleep > 0 {
                stages.append(["stage": "Deep", "hours": deepSleep / 3600])
            }
            if remSleep > 0 {
                stages.append(["stage": "REM", "hours": remSleep / 3600])
            }
            if coreSleep > 0 {
                stages.append(["stage": "Core", "hours": coreSleep / 3600])
            }
            if awakeSleep > 0 {
                stages.append(["stage": "Awake", "hours": awakeSleep / 3600])
            }

            print("[AppDelegate] 😴 Final stages array: \(stages)")
            completion(totalSleep / 3600, stages)
        }

        healthStore.execute(query)
    }

    /// Fetch blood pressure (systolic/diastolic)
    private func fetchBloodPressure(completion: @escaping (Double, Double, String?) -> Void) {
        guard let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) else {
            completion(0, 0, nil)
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        // Fetch systolic
        let systolicQuery = HKSampleQuery(sampleType: systolicType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else {
                completion(0, 0, nil)
                return
            }

            let systolic = sample.quantity.doubleValue(for: HKUnit.millimeterOfMercury())
            let timestamp = ISO8601DateFormatter().string(from: sample.startDate)

            // Now fetch diastolic
            let diastolicQuery = HKSampleQuery(sampleType: diastolicType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, diastolicSamples, _ in
                if let diastolicSample = diastolicSamples?.first as? HKQuantitySample {
                    let diastolic = diastolicSample.quantity.doubleValue(for: HKUnit.millimeterOfMercury())
                    completion(systolic, diastolic, timestamp)
                } else {
                    completion(systolic, 0, timestamp)
                }
            }
            self?.healthStore.execute(diastolicQuery)
        }

        healthStore.execute(systolicQuery)
    }

    /// Fetch audio exposure (headphone and environmental)
    private func fetchAudioExposure(completion: @escaping (Double, Double) -> Void) {
        let group = DispatchGroup()
        var headphoneDb: Double = 0
        var environmentalDb: Double = 0

        // Headphone audio
        if let headphoneType = HKQuantityType.quantityType(forIdentifier: .headphoneAudioExposure) {
            group.enter()
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: headphoneType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                if let sample = samples?.first as? HKQuantitySample {
                    headphoneDb = sample.quantity.doubleValue(for: HKUnit.decibelAWeightedSoundPressureLevel())
                }
                group.leave()
            }
            healthStore.execute(query)
        }

        // Environmental audio
        if let envType = HKQuantityType.quantityType(forIdentifier: .environmentalAudioExposure) {
            group.enter()
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: envType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                if let sample = samples?.first as? HKQuantitySample {
                    environmentalDb = sample.quantity.doubleValue(for: HKUnit.decibelAWeightedSoundPressureLevel())
                }
                group.leave()
            }
            healthStore.execute(query)
        }

        group.notify(queue: .main) {
            completion(headphoneDb, environmentalDb)
        }
    }

    /// Fetch today's workouts
    private func fetchTodayWorkouts(completion: @escaping ([[String: Any]]) -> Void) {
        let workoutType = HKObjectType.workoutType()
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: 10, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            var workouts: [[String: Any]] = []

            if let workoutSamples = samples as? [HKWorkout] {
                for workout in workoutSamples {
                    var workoutData: [String: Any] = [:]
                    workoutData["type"] = self.workoutTypeName(workout.workoutActivityType)
                    workoutData["duration_minutes"] = Int(workout.duration / 60)
                    workoutData["calories"] = Int(workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0)
                    workoutData["distance_km"] = (workout.totalDistance?.doubleValue(for: .meter()) ?? 0) / 1000
                    workoutData["start_time"] = ISO8601DateFormatter().string(from: workout.startDate)
                    workouts.append(workoutData)
                }
            }

            completion(workouts)
        }

        healthStore.execute(query)
    }

    private func workoutTypeName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .walking: return "Walking"
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Strength Training"
        case .traditionalStrengthTraining: return "Strength Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .stairClimbing: return "Stair Climbing"
        case .hiking: return "Hiking"
        case .dance: return "Dance"
        case .pilates: return "Pilates"
        default: return "Workout"
        }
    }

    /// Fetch AFib history from ECG recordings
    private func fetchAFibHistory(completion: @escaping ([[String: Any]]) -> Void) {
        if #available(iOS 14.3, *) {
            let ecgType = HKObjectType.electrocardiogramType()

            // Get ECGs from last 30 days
            let now = Date()
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now)!
            let predicate = HKQuery.predicateForSamples(withStart: thirtyDaysAgo, end: now, options: .strictEndDate)

            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: ecgType, predicate: predicate, limit: 20, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                var afibEvents: [[String: Any]] = []

                if let ecgSamples = samples as? [HKElectrocardiogram] {
                    for ecg in ecgSamples {
                        if ecg.classification == .atrialFibrillation {
                            var event: [String: Any] = [:]
                            event["date"] = ISO8601DateFormatter().string(from: ecg.startDate)
                            event["classification"] = "Atrial Fibrillation"
                            if let avgHR = ecg.averageHeartRate?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) {
                                event["average_heart_rate"] = Int(avgHR)
                            }
                            afibEvents.append(event)
                        }
                    }
                }

                completion(afibEvents)
            }

            healthStore.execute(query)
        } else {
            completion([])
        }
    }

    /// Get weekly health summary
    private func getWeeklyHealthSummary(result: @escaping FlutterResult) {
        let group = DispatchGroup()
        var weeklyData: [String: Any] = [:]
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!

        // Weekly steps
        group.enter()
        fetchRangeQuantity(type: .stepCount, start: weekAgo, end: now) { value in
            weeklyData["total_steps"] = Int(value ?? 0)
            weeklyData["avg_daily_steps"] = Int((value ?? 0) / 7)
            group.leave()
        }

        // Weekly calories
        group.enter()
        fetchRangeQuantity(type: .activeEnergyBurned, start: weekAgo, end: now) { value in
            weeklyData["total_calories"] = Int(value ?? 0)
            weeklyData["avg_daily_calories"] = Int((value ?? 0) / 7)
            group.leave()
        }

        // Weekly distance
        group.enter()
        fetchRangeQuantity(type: .distanceWalkingRunning, start: weekAgo, end: now) { value in
            weeklyData["total_distance_km"] = (value ?? 0) / 1000
            group.leave()
        }

        // Weekly exercise minutes
        group.enter()
        fetchRangeQuantity(type: .appleExerciseTime, start: weekAgo, end: now) { value in
            weeklyData["total_exercise_minutes"] = Int(value ?? 0)
            group.leave()
        }

        group.notify(queue: .main) {
            weeklyData["period"] = "weekly"
            weeklyData["start_date"] = ISO8601DateFormatter().string(from: weekAgo)
            weeklyData["end_date"] = ISO8601DateFormatter().string(from: now)
            result(weeklyData)
        }
    }

    /// Get monthly health summary
    private func getMonthlyHealthSummary(result: @escaping FlutterResult) {
        let group = DispatchGroup()
        var monthlyData: [String: Any] = [:]
        let calendar = Calendar.current
        let now = Date()
        let monthAgo = calendar.date(byAdding: .day, value: -30, to: now)!

        // Monthly steps
        group.enter()
        fetchRangeQuantity(type: .stepCount, start: monthAgo, end: now) { value in
            monthlyData["total_steps"] = Int(value ?? 0)
            monthlyData["avg_daily_steps"] = Int((value ?? 0) / 30)
            group.leave()
        }

        // Monthly calories
        group.enter()
        fetchRangeQuantity(type: .activeEnergyBurned, start: monthAgo, end: now) { value in
            monthlyData["total_calories"] = Int(value ?? 0)
            monthlyData["avg_daily_calories"] = Int((value ?? 0) / 30)
            group.leave()
        }

        // Monthly distance
        group.enter()
        fetchRangeQuantity(type: .distanceWalkingRunning, start: monthAgo, end: now) { value in
            monthlyData["total_distance_km"] = (value ?? 0) / 1000
            group.leave()
        }

        // Monthly exercise minutes
        group.enter()
        fetchRangeQuantity(type: .appleExerciseTime, start: monthAgo, end: now) { value in
            monthlyData["total_exercise_minutes"] = Int(value ?? 0)
            group.leave()
        }

        group.notify(queue: .main) {
            monthlyData["period"] = "monthly"
            monthlyData["start_date"] = ISO8601DateFormatter().string(from: monthAgo)
            monthlyData["end_date"] = ISO8601DateFormatter().string(from: now)
            result(monthlyData)
        }
    }

    /// Fetch quantity over a date range
    private func fetchRangeQuantity(type: HKQuantityTypeIdentifier, start: Date, end: Date, completion: @escaping (Double?) -> Void) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: type) else {
            completion(nil)
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, _ in
            let unit: HKUnit
            switch type {
            case .stepCount, .flightsClimbed:
                unit = .count()
            case .activeEnergyBurned:
                unit = .kilocalorie()
            case .distanceWalkingRunning:
                unit = .meter()
            case .appleExerciseTime, .appleStandTime:
                unit = .minute()
            default:
                unit = .count()
            }

            let value = statistics?.sumQuantity()?.doubleValue(for: unit)
            completion(value)
        }

        healthStore.execute(query)
    }

    // MARK: - HealthKit Authorization

    private func requestHealthKitAuthorization(result: @escaping FlutterResult) {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[AppDelegate] HealthKit not available on this device")
            result(false)
            return
        }

        // Define ALL health data types we want to read
        var typesToRead: Set<HKObjectType> = [
            // Vitals
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .walkingHeartRateAverage)!,

            // Activity
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .flightsClimbed)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.quantityType(forIdentifier: .appleStandTime)!,

            // Sleep
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,

            // Audio
            HKObjectType.quantityType(forIdentifier: .headphoneAudioExposure)!,
            HKObjectType.quantityType(forIdentifier: .environmentalAudioExposure)!,

            // Blood Pressure (if setup)
            HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,

            // Workouts
            HKObjectType.workoutType(),
        ]

        // Add iOS 14.3+ types
        if #available(iOS 14.3, *) {
            // AFib History (ECG)
            let afibType = HKObjectType.electrocardiogramType()
            typesToRead.insert(afibType)
        }

        // Add iOS 17+ types (State of Mind)
        if #available(iOS 17.0, *) {
            if let stateOfMindType = HKObjectType.categoryType(forIdentifier: .mindfulSession) {
                typesToRead.insert(stateOfMindType)
            }
        }

        // Request authorization
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("[AppDelegate] HealthKit authorization error: \(error.localizedDescription)")
                    result(false)
                    return
                }

                if success {
                    print("[AppDelegate] ✅ HealthKit authorization granted for \(typesToRead.count) types")
                    // Store authorization status
                    UserDefaults.standard.set(true, forKey: "healthkit_authorized")

                    // Start HealthKit observers for real-time updates
                    self.startHealthKitObservers()

                    result(true)
                } else {
                    print("[AppDelegate] ⚠️ HealthKit authorization denied")
                    result(false)
                }
            }
        }
    }

    private func checkHealthKitAuthorization(result: @escaping FlutterResult) {
        guard HKHealthStore.isHealthDataAvailable() else {
            result(false)
            return
        }

        // Check if we have authorization for heart rate (representative check)
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            result(false)
            return
        }

        let status = healthStore.authorizationStatus(for: heartRateType)
        let isAuthorized = status == .sharingAuthorized

        // For read-only access, we can't definitively know if authorized
        // So we also check our stored preference
        let storedAuth = UserDefaults.standard.bool(forKey: "healthkit_authorized")

        result(isAuthorized || storedAuth)
    }

    // MARK: - Send Configuration to Watch

    private func sendConfigurationToWatch(baseURL: String, token: String) {
        // Store in App Groups for Watch to access directly
        if let defaults = UserDefaults(suiteName: appGroupIdentifier) {
            defaults.set(baseURL, forKey: "api_base_url")
            defaults.set(token, forKey: "auth_token")
            defaults.synchronize()
            print("[AppDelegate] Configuration stored in App Groups")
        }

        guard WCSession.default.activationState == .activated else {
            print("[AppDelegate] WCSession not activated, cannot send configuration")
            return
        }

        let config: [String: Any] = [
            "api_base_url": baseURL,
            "auth_token": token
        ]

        // Send via application context (persists even when Watch app isn't running)
        do {
            try WCSession.default.updateApplicationContext(config)
            print("[AppDelegate] Configuration sent to Watch via application context")
        } catch {
            print("[AppDelegate] Failed to update application context: \(error.localizedDescription)")
        }

        // Also send via message if Watch is reachable (immediate delivery)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(config, replyHandler: { response in
                print("[AppDelegate] Watch acknowledged configuration: \(response)")
            }, errorHandler: { error in
                print("[AppDelegate] Failed to send message to Watch: \(error.localizedDescription)")
            })
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("[AppDelegate] WCSession activation failed: \(error.localizedDescription)")
                return
            }

            print("[AppDelegate] WCSession activated with state: \(activationState.rawValue)")
            print("[AppDelegate] Is Watch paired: \(session.isPaired)")
            print("[AppDelegate] Is Watch app installed: \(session.isWatchAppInstalled)")

            // If we have stored credentials, send them to Watch
            if activationState == .activated {
                self.resendStoredConfiguration()
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("[AppDelegate] WCSession became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("[AppDelegate] WCSession deactivated, reactivating...")
        // Reactivate session for multiple Watch support
        WCSession.default.activate()
    }

    // Handle messages from Watch (including config requests)
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("[AppDelegate] Received message from Watch: \(message.keys)")

        // Handle configuration request from Watch
        if message["type"] as? String == "request_config" {
            if let defaults = UserDefaults(suiteName: appGroupIdentifier),
               let baseURL = defaults.string(forKey: "api_base_url"),
               let token = defaults.string(forKey: "auth_token") {
                print("[AppDelegate] Sending stored configuration to Watch")
                replyHandler([
                    "api_base_url": baseURL,
                    "auth_token": token
                ])
            } else {
                print("[AppDelegate] No configuration available to send to Watch")
                replyHandler(["error": "No configuration available"])
            }
            return
        }

        // Handle watch vitals data
        if message["type"] as? String == "watch_vitals" {
            latestWatchVitals = message

            // Forward to Django API immediately (background-safe)
            forwardVitalsToDjango(vitals: message)

            // Notify Flutter about new vitals (if active)
            DispatchQueue.main.async {
                self.watchVitalsChannel?.invokeMethod("onWatchVitalsReceived", arguments: message)
            }

            replyHandler(["status": "received"])
            return
        }

        replyHandler(["status": "unknown_type"])
    }

    // MARK: - Forward Vitals to Django API (Native Layer)

    private func forwardVitalsToDjango(vitals: [String: Any]) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let baseURL = defaults.string(forKey: "api_base_url"),
              let token = defaults.string(forKey: "auth_token"),
              !baseURL.isEmpty, !token.isEmpty else {
            print("[AppDelegate] ⚠️ No API configuration - cannot forward vitals")
            bufferVitals(vitals)
            return
        }

        // Build API URL
        let urlString = "\(baseURL)/api/watch-vitals/dev/"
        guard let url = URL(string: urlString) else {
            print("[AppDelegate] ❌ Invalid URL: \(urlString)")
            return
        }

        // Prepare request body
        var apiData: [String: Any] = [:]
        apiData["heart_rate"] = vitals["heart_rate"] ?? 0
        apiData["blood_oxygen"] = vitals["blood_oxygen"] ?? 0
        apiData["hrv"] = vitals["hrv"]
        apiData["respiratory_rate"] = vitals["respiratory_rate"]
        apiData["total_sleep_hours"] = vitals["total_sleep_hours"]
        apiData["deep_sleep_hours"] = vitals["deep_sleep_hours"]
        apiData["rem_sleep_hours"] = vitals["rem_sleep_hours"]
        apiData["core_sleep_hours"] = vitals["core_sleep_hours"]
        apiData["awake_time_hours"] = vitals["awake_time_hours"]
        apiData["awakenings_count"] = vitals["awakenings_count"]
        apiData["sleep_quality"] = vitals["sleep_quality"]
        apiData["fall_detected"] = vitals["fall_detected"] ?? false
        apiData["recorded_at"] = vitals["timestamp"] ?? ISO8601DateFormatter().string(from: Date())

        guard let jsonData = try? JSONSerialization.data(withJSONObject: apiData) else {
            print("[AppDelegate] ❌ Failed to serialize vitals")
            return
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        // Send request (background-safe)
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("[AppDelegate] ❌ Failed to send vitals to API: \(error.localizedDescription)")
                self?.bufferVitals(vitals)
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    print("[AppDelegate] ✅ Vitals forwarded to Django (HR=\(vitals["heart_rate"] ?? 0))")
                    // Try to send any buffered vitals
                    self?.sendBufferedVitals()
                } else {
                    print("[AppDelegate] ❌ API error: \(httpResponse.statusCode)")
                    self?.bufferVitals(vitals)
                }
            }
        }
        task.resume()
    }

    private func bufferVitals(_ vitals: [String: Any]) {
        pendingVitalsQueue.append(vitals)
        if pendingVitalsQueue.count > maxPendingVitals {
            pendingVitalsQueue.removeFirst()
        }
        print("[AppDelegate] Buffered vitals (pending: \(pendingVitalsQueue.count))")
    }

    private func sendBufferedVitals() {
        guard !pendingVitalsQueue.isEmpty else { return }

        let vitalsToSend = pendingVitalsQueue
        pendingVitalsQueue.removeAll()

        print("[AppDelegate] 📤 Sending \(vitalsToSend.count) buffered vitals")

        for vitals in vitalsToSend {
            forwardVitalsToDjango(vitals: vitals)
        }
    }

    // Receive application context updates from Watch (background delivery)
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("[AppDelegate] Received application context from Watch: \(applicationContext.keys)")

        if applicationContext["type"] as? String == "watch_vitals" {
            latestWatchVitals = applicationContext

            // Forward to Django API immediately (background-safe)
            forwardVitalsToDjango(vitals: applicationContext)

            // Notify Flutter about new vitals (if active)
            DispatchQueue.main.async {
                self.watchVitalsChannel?.invokeMethod("onWatchVitalsReceived", arguments: applicationContext)
            }
        }
    }

    // MARK: - Resend Stored Configuration

    private func resendStoredConfiguration() {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let baseURL = defaults.string(forKey: "api_base_url"),
              let token = defaults.string(forKey: "auth_token"),
              !baseURL.isEmpty, !token.isEmpty else {
            print("[AppDelegate] No stored configuration to resend")
            return
        }

        print("[AppDelegate] Resending stored configuration to Watch")
        sendConfigurationToWatch(baseURL: baseURL, token: token)
    }

    // MARK: - HealthKit Observers for Event-Driven Updates

    /// Start HealthKit observers to detect real-time health data changes
    private func startHealthKitObservers() {
        guard !healthKitObserversActive else {
            print("[AppDelegate] HealthKit observers already active")
            return
        }

        print("[AppDelegate] 🔔 Starting HealthKit observers for real-time updates")

        // Heart Rate Observer
        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            heartRateObserver = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] query, completionHandler, error in
                if let error = error {
                    print("[AppDelegate] ❌ Heart rate observer error: \(error.localizedDescription)")
                    completionHandler()
                    return
                }

                print("[AppDelegate] ❤️ Heart rate changed in HealthKit")
                self?.notifyFlutterHealthUpdate(type: "heart_rate")
                completionHandler()
            }

            if let observer = heartRateObserver {
                healthStore.execute(observer)
                // Enable background delivery for heart rate
                healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { success, error in
                    if success {
                        print("[AppDelegate] ✅ Background delivery enabled for heart rate")
                    } else if let error = error {
                        print("[AppDelegate] ⚠️ Background delivery failed for heart rate: \(error.localizedDescription)")
                    }
                }
            }
        }

        // Blood Oxygen Observer
        if let oxygenType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) {
            bloodOxygenObserver = HKObserverQuery(sampleType: oxygenType, predicate: nil) { [weak self] query, completionHandler, error in
                if let error = error {
                    print("[AppDelegate] ❌ Blood oxygen observer error: \(error.localizedDescription)")
                    completionHandler()
                    return
                }

                print("[AppDelegate] 🫁 Blood oxygen changed in HealthKit")
                self?.notifyFlutterHealthUpdate(type: "blood_oxygen")
                completionHandler()
            }

            if let observer = bloodOxygenObserver {
                healthStore.execute(observer)
                healthStore.enableBackgroundDelivery(for: oxygenType, frequency: .immediate) { success, error in
                    if success {
                        print("[AppDelegate] ✅ Background delivery enabled for blood oxygen")
                    }
                }
            }
        }

        // Steps Observer
        if let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            stepsObserver = HKObserverQuery(sampleType: stepsType, predicate: nil) { [weak self] query, completionHandler, error in
                if let error = error {
                    print("[AppDelegate] ❌ Steps observer error: \(error.localizedDescription)")
                    completionHandler()
                    return
                }

                print("[AppDelegate] 👟 Steps changed in HealthKit")
                self?.notifyFlutterHealthUpdate(type: "steps")
                completionHandler()
            }

            if let observer = stepsObserver {
                healthStore.execute(observer)
                // Steps update less frequently - hourly background delivery
                healthStore.enableBackgroundDelivery(for: stepsType, frequency: .hourly) { success, error in
                    if success {
                        print("[AppDelegate] ✅ Background delivery enabled for steps")
                    }
                }
            }
        }

        // Sleep Observer
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            sleepObserver = HKObserverQuery(sampleType: sleepType, predicate: nil) { [weak self] query, completionHandler, error in
                if let error = error {
                    print("[AppDelegate] ❌ Sleep observer error: \(error.localizedDescription)")
                    completionHandler()
                    return
                }

                print("[AppDelegate] 😴 Sleep data changed in HealthKit")
                self?.notifyFlutterHealthUpdate(type: "sleep")
                completionHandler()
            }

            if let observer = sleepObserver {
                healthStore.execute(observer)
                healthStore.enableBackgroundDelivery(for: sleepType, frequency: .immediate) { success, error in
                    if success {
                        print("[AppDelegate] ✅ Background delivery enabled for sleep")
                    }
                }
            }
        }

        healthKitObserversActive = true
        print("[AppDelegate] 🔔 HealthKit observers started successfully")
    }

    /// Stop all HealthKit observers
    private func stopHealthKitObservers() {
        if let observer = heartRateObserver {
            healthStore.stop(observer)
            heartRateObserver = nil
        }
        if let observer = bloodOxygenObserver {
            healthStore.stop(observer)
            bloodOxygenObserver = nil
        }
        if let observer = stepsObserver {
            healthStore.stop(observer)
            stepsObserver = nil
        }
        if let observer = sleepObserver {
            healthStore.stop(observer)
            sleepObserver = nil
        }

        healthKitObserversActive = false
        print("[AppDelegate] 🔕 HealthKit observers stopped")
    }

    /// Notify Flutter about health data updates
    private func notifyFlutterHealthUpdate(type: String) {
        // Debounce rapid updates - don't spam Flutter
        let now = Date()
        let debounceKey = "lastHealthUpdate_\(type)"

        if let lastUpdate = UserDefaults.standard.object(forKey: debounceKey) as? Date {
            let elapsed = now.timeIntervalSince(lastUpdate)
            // Debounce: ignore updates within 5 seconds for the same type
            if elapsed < 5 {
                print("[AppDelegate] Debouncing \(type) update (last: \(elapsed)s ago)")
                return
            }
        }

        UserDefaults.standard.set(now, forKey: debounceKey)

        // Fetch fresh data and send to Flutter
        DispatchQueue.main.async { [weak self] in
            // Notify Flutter that health data has changed
            self?.watchVitalsChannel?.invokeMethod("onHealthKitDataChanged", arguments: [
                "type": type,
                "timestamp": ISO8601DateFormatter().string(from: now)
            ])

            print("[AppDelegate] 📱 Notified Flutter of \(type) change")
        }
    }

    // MARK: - Audio Session Configuration for LiveKit

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()

            // Use playAndRecord category for voice calls with speaker output
            try audioSession.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .mixWithOthers]
            )

            // Activate the audio session
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            // Force output to speaker
            try audioSession.overrideOutputAudioPort(.speaker)

            print("[AppDelegate] ✅ Audio session configured for LiveKit voice calls")
        } catch {
            print("[AppDelegate] ❌ Failed to configure audio session: \(error.localizedDescription)")
        }
    }
}
