import UIKit
import Flutter
import WatchConnectivity
import AVFoundation
import HealthKit
import Contacts
import MessageUI

@main
@objc class AppDelegate: FlutterAppDelegate, WCSessionDelegate {
    private var watchVitalsChannel: FlutterMethodChannel?
    private var contactsChannel: FlutterMethodChannel?
    private var latestWatchVitals: [String: Any]?
    private let contactStore = CNContactStore()
    private let appGroupIdentifier = "group.com.kindura.ai"
    private let healthStore = HKHealthStore()

    // DEBUG MODE - Set to true for verbose logging
    private let DEBUG_MODE = true

    // Pending vitals queue for when API is unreachable
    private var pendingVitalsQueue: [[String: Any]] = []
    private let maxPendingVitals = 50

    // HealthKit observer queries for real-time updates
    private var heartRateObserver: HKObserverQuery?
    private var bloodOxygenObserver: HKObserverQuery?
    private var hrvObserver: HKObserverQuery?
    private var respiratoryRateObserver: HKObserverQuery?
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

    // MARK: - App Lifecycle - Proactive Watch Sync

    override func applicationDidBecomeActive(_ application: UIApplication) {
        super.applicationDidBecomeActive(application)
        print("[AppDelegate] 📱 App became active - triggering Watch sync")

        // Proactively sync with Watch when app becomes active
        syncWithWatch()
    }

    /// Proactive sync with Watch - called when iPhone app becomes active
    private func syncWithWatch() {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        guard session.activationState == .activated else {
            print("[AppDelegate] WCSession not activated yet - will sync when ready")
            return
        }

        // 1. Send configuration to Watch (so it can start sending vitals)
        resendStoredConfiguration()

        // 2. Request current vitals from Watch
        if session.isReachable {
            print("[AppDelegate] 📤 Requesting current vitals from Watch")
            session.sendMessage(["type": "request_vitals"], replyHandler: { response in
                print("[AppDelegate] ✅ Received vitals response from Watch: \(response.keys)")

                // Store as latest vitals
                if response["type"] as? String == "watch_vitals" {
                    self.latestWatchVitals = response

                    // Forward to Django API
                    self.forwardVitalsToDjango(vitals: response)

                    // Notify Flutter
                    DispatchQueue.main.async {
                        self.watchVitalsChannel?.invokeMethod("onWatchVitalsReceived", arguments: response)
                    }
                }
            }, errorHandler: { error in
                print("[AppDelegate] ⚠️ Failed to request vitals from Watch: \(error.localizedDescription)")
            })
        } else {
            print("[AppDelegate] Watch not reachable - vitals will sync via transferUserInfo")
        }
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
                // Return true if Watch is paired (app installation is checked separately)
                // This allows HealthKit-based updates even if Watch app isn't installed
                let isPaired = session.isPaired
                let isAppInstalled = session.isWatchAppInstalled
                print("[AppDelegate] isWatchPaired check: paired=\(isPaired), appInstalled=\(isAppInstalled)")
                result(isPaired)  // Use isPaired only - Watch can send HealthKit data even without our app

            case "isWatchReachable":
                result(WCSession.default.isReachable)

            case "requestHealthKitAuthorization":
                self?.requestHealthKitAuthorization(result: result)

            case "isHealthKitAuthorized":
                self?.checkHealthKitAuthorization(result: result)

            case "getHealthSummary":
                self?.getHealthSummary(result: result)

            case "getExtendedVitals":
                self?.fetchExtendedVitals(result: result)

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

            case "startWatchWorkout":
                self?.sendWatchCommand(command: "start_workout", result: result)

            case "stopWatchWorkout":
                self?.sendWatchCommand(command: "stop_workout", result: result)

            case "getWatchStatus":
                self?.sendWatchCommand(command: "get_status", result: result)

            case "sendMedicationReminder":
                if let args = call.arguments as? [String: Any] {
                    self?.sendMedicationReminderToWatch(medicationData: args, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing medication reminder data", details: nil))
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // Auto-start observers if already authorized
        if UserDefaults.standard.bool(forKey: "healthkit_authorized") {
            print("[AppDelegate] HealthKit previously authorized - starting observers")
            startHealthKitObservers()
        }

        // Setup contacts method channel
        setupContactsMethodChannel(controller: controller)
    }

    // MARK: - Contacts Method Channel Setup

    private func setupContactsMethodChannel(controller: FlutterViewController) {
        contactsChannel = FlutterMethodChannel(
            name: "com.kindura.ai/contacts",
            binaryMessenger: controller.binaryMessenger
        )

        contactsChannel?.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "requestContactsPermission":
                self?.requestContactsPermission(result: result)

            case "getDeviceContacts":
                self?.getDeviceContacts(result: result)

            case "searchContacts":
                if let args = call.arguments as? [String: Any],
                   let query = args["query"] as? String {
                    self?.searchContacts(query: query, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing query parameter", details: nil))
                }

            case "sendMessage":
                if let args = call.arguments as? [String: Any],
                   let phoneNumber = args["phoneNumber"] as? String,
                   let message = args["message"] as? String {
                    self?.openMessagesApp(phoneNumber: phoneNumber, message: message, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing phoneNumber or message", details: nil))
                }

            case "makeCall":
                if let args = call.arguments as? [String: Any],
                   let phoneNumber = args["phoneNumber"] as? String {
                    let callType = args["callType"] as? String ?? "phone"
                    self?.makeCall(phoneNumber: phoneNumber, callType: callType, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing phoneNumber", details: nil))
                }

            case "startFaceTimeCall":
                if let args = call.arguments as? [String: Any],
                   let contact = args["contact"] as? String {
                    let isVideo = args["isVideo"] as? Bool ?? true
                    self?.startFaceTimeCall(contact: contact, isVideo: isVideo, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing contact", details: nil))
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        print("[AppDelegate] Contacts method channel setup complete")
    }

    // MARK: - Contacts Permission

    private func requestContactsPermission(result: @escaping FlutterResult) {
        let status = CNContactStore.authorizationStatus(for: .contacts)

        switch status {
        case .authorized:
            result(true)
        case .notDetermined:
            contactStore.requestAccess(for: .contacts) { granted, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("[AppDelegate] Contacts permission error: \(error.localizedDescription)")
                        result(false)
                    } else {
                        result(granted)
                    }
                }
            }
        case .denied, .restricted:
            result(false)
        @unknown default:
            result(false)
        }
    }

    // MARK: - Get Device Contacts

    private func getDeviceContacts(result: @escaping FlutterResult) {
        let status = CNContactStore.authorizationStatus(for: .contacts)

        guard status == .authorized else {
            print("[AppDelegate] Contacts not authorized")
            result(FlutterError(code: "NOT_AUTHORIZED", message: "Contacts access not authorized", details: nil))
            return
        }

        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactImageDataAvailableKey as CNKeyDescriptor,
            CNContactRelationsKey as CNKeyDescriptor,  // Related names (spouse, parent, etc)
            CNContactOrganizationNameKey as CNKeyDescriptor,
        ]

        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        request.sortOrder = .givenName

        var contacts: [[String: Any]] = []

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try self?.contactStore.enumerateContacts(with: request) { contact, _ in
                    var contactDict: [String: Any] = [:]

                    // Name
                    let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                    contactDict["id"] = contact.identifier
                    contactDict["givenName"] = contact.givenName
                    contactDict["familyName"] = contact.familyName
                    contactDict["fullName"] = fullName.isEmpty ? contact.organizationName : fullName
                    contactDict["nickname"] = contact.nickname
                    contactDict["organization"] = contact.organizationName

                    // Phone numbers
                    var phones: [[String: String]] = []
                    for phone in contact.phoneNumbers {
                        let label = CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: phone.label ?? "")
                        phones.append([
                            "label": label,
                            "number": phone.value.stringValue
                        ])
                    }
                    contactDict["phoneNumbers"] = phones

                    // Emails
                    var emails: [[String: String]] = []
                    for email in contact.emailAddresses {
                        let label = CNLabeledValue<NSString>.localizedString(forLabel: email.label ?? "")
                        emails.append([
                            "label": label,
                            "email": email.value as String
                        ])
                    }
                    contactDict["emails"] = emails

                    // Has image
                    contactDict["hasImage"] = contact.imageDataAvailable

                    // Only include contacts with phone numbers or emails
                    if !phones.isEmpty || !emails.isEmpty {
                        contacts.append(contactDict)
                    }
                }

                DispatchQueue.main.async {
                    print("[AppDelegate] ✅ Fetched \(contacts.count) contacts")
                    result(contacts)
                }
            } catch {
                DispatchQueue.main.async {
                    print("[AppDelegate] ❌ Error fetching contacts: \(error.localizedDescription)")
                    result(FlutterError(code: "FETCH_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    // MARK: - Search Contacts

    private func searchContacts(query: String, result: @escaping FlutterResult) {
        let status = CNContactStore.authorizationStatus(for: .contacts)

        guard status == .authorized else {
            result(FlutterError(code: "NOT_AUTHORIZED", message: "Contacts access not authorized", details: nil))
            return
        }

        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
        ]

        // Search by name
        let predicate = CNContact.predicateForContacts(matchingName: query)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let contacts = try self?.contactStore.unifiedContacts(matching: predicate, keysToFetch: keysToFetch) ?? []

                var results: [[String: Any]] = []
                for contact in contacts {
                    var contactDict: [String: Any] = [:]
                    let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                    contactDict["id"] = contact.identifier
                    contactDict["fullName"] = fullName

                    // Primary phone
                    if let phone = contact.phoneNumbers.first {
                        contactDict["phoneNumber"] = phone.value.stringValue
                    }

                    // Primary email
                    if let email = contact.emailAddresses.first {
                        contactDict["email"] = email.value as String
                    }

                    results.append(contactDict)
                }

                DispatchQueue.main.async {
                    print("[AppDelegate] ✅ Found \(results.count) contacts matching '\(query)'")
                    result(results)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "SEARCH_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    // MARK: - Send Message (Opens Messages App)

    private func openMessagesApp(phoneNumber: String, message: String, result: @escaping FlutterResult) {
        // Clean phone number
        let cleanNumber = phoneNumber.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")

        // Use sms: URL scheme with body parameter
        // Note: User must tap send - iOS doesn't allow programmatic sending
        let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? message

        if let url = URL(string: "sms:\(cleanNumber)&body=\(encodedMessage)") {
            DispatchQueue.main.async {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:]) { success in
                        if success {
                            print("[AppDelegate] ✅ Opened Messages app for \(cleanNumber)")
                            result(["status": "opened", "message": "Messages app opened. Please tap send."])
                        } else {
                            result(FlutterError(code: "OPEN_FAILED", message: "Failed to open Messages app", details: nil))
                        }
                    }
                } else {
                    result(FlutterError(code: "NOT_AVAILABLE", message: "Messages app not available", details: nil))
                }
            }
        } else {
            result(FlutterError(code: "INVALID_URL", message: "Could not create message URL", details: nil))
        }
    }

    // MARK: - Make Call (Phone or FaceTime)

    private func makeCall(phoneNumber: String, callType: String, result: @escaping FlutterResult) {
        let cleanNumber = phoneNumber.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")

        var urlString: String

        switch callType.lowercased() {
        case "facetime", "facetime-video":
            urlString = "facetime://\(cleanNumber)"
        case "facetime-audio":
            urlString = "facetime-audio://\(cleanNumber)"
        default:
            urlString = "tel://\(cleanNumber)"
        }

        if let url = URL(string: urlString) {
            DispatchQueue.main.async {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:]) { success in
                        if success {
                            print("[AppDelegate] ✅ Initiated \(callType) call to \(cleanNumber)")
                            result(["status": "calling", "callType": callType])
                        } else {
                            result(FlutterError(code: "CALL_FAILED", message: "Failed to initiate call", details: nil))
                        }
                    }
                } else {
                    result(FlutterError(code: "NOT_AVAILABLE", message: "\(callType) not available on this device", details: nil))
                }
            }
        } else {
            result(FlutterError(code: "INVALID_URL", message: "Could not create call URL", details: nil))
        }
    }

    // MARK: - FaceTime Call

    private func startFaceTimeCall(contact: String, isVideo: Bool, result: @escaping FlutterResult) {
        let scheme = isVideo ? "facetime" : "facetime-audio"

        // Contact can be phone number or email
        let encodedContact = contact.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? contact

        if let url = URL(string: "\(scheme)://\(encodedContact)") {
            DispatchQueue.main.async {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:]) { success in
                        if success {
                            print("[AppDelegate] ✅ Initiated FaceTime \(isVideo ? "video" : "audio") call to \(contact)")
                            result(["status": "calling", "isVideo": isVideo])
                        } else {
                            result(FlutterError(code: "CALL_FAILED", message: "Failed to initiate FaceTime", details: nil))
                        }
                    }
                } else {
                    result(FlutterError(code: "NOT_AVAILABLE", message: "FaceTime not available", details: nil))
                }
            }
        } else {
            result(FlutterError(code: "INVALID_URL", message: "Could not create FaceTime URL", details: nil))
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

        // ===== FALLS FROM HEALTHKIT =====

        group.enter()
        fetchTodayFalls { fallsCount in
            healthData["healthkit_falls_count"] = fallsCount
            print("[AppDelegate] 🩺 HealthKit falls today: \(fallsCount)")
            group.leave()
        }

        group.notify(queue: .main) {
            healthData["source"] = "apple_health"
            healthData["fetched_at"] = ISO8601DateFormatter().string(from: Date())

            // Get falls from multiple sources and use the maximum
            var totalFalls = 0
            var fallDetected = false

            // Source 1: HealthKit (Watch writes falls here)
            if let healthKitFalls = healthData["healthkit_falls_count"] as? Int {
                totalFalls = max(totalFalls, healthKitFalls)
                if healthKitFalls > 0 {
                    fallDetected = true
                }
            }

            // Source 2: WatchConnectivity (real-time from Watch)
            if let watchVitals = self.latestWatchVitals {
                if let watchFalls = watchVitals["falls_count"] as? Int {
                    totalFalls = max(totalFalls, watchFalls)
                    if watchFalls > 0 {
                        fallDetected = true
                    }
                }
                if let watchFallDetected = watchVitals["fall_detected"] as? Bool, watchFallDetected {
                    fallDetected = true
                    totalFalls = max(totalFalls, 1)  // At least 1 if fall detected
                }
            }

            healthData["falls_count"] = totalFalls
            healthData["fall_detected"] = fallDetected
            print("[AppDelegate] 🩺 Final falls_count: \(totalFalls), fall_detected: \(fallDetected)")

            print("[AppDelegate] Health data complete - HR: \(healthData["heart_rate"] ?? "nil"), O2: \(healthData["blood_oxygen"] ?? "nil"), Steps: \(healthData["steps"] ?? "nil"), Sleep: \(healthData["sleep_hours"] ?? "nil"), Falls: \(healthData["falls_count"] ?? 0)")
            result(healthData)
        }
    }

    /// Fetch today's falls from HealthKit
    private func fetchTodayFalls(completion: @escaping (Int) -> Void) {
        guard let fallType = HKQuantityType.quantityType(forIdentifier: .numberOfTimesFallen) else {
            completion(0)
            return
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: fallType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                print("[AppDelegate] ❌ Error fetching falls: \(error.localizedDescription)")
                completion(0)
                return
            }

            let count = Int(result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0)
            completion(count)
        }

        healthStore.execute(query)
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

    /// Fetch sleep history by date - prioritizes Apple Watch/HealthKit data
    private func fetchSleepHistory(startDate: Date, endDate: Date, completion: @escaping ([[String: Any]]) -> Void) {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion([])
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
            if let error = error {
                print("[AppDelegate] Error fetching sleep history: \(error)")
                completion([])
                return
            }

            guard let sleepSamples = samples as? [HKCategorySample] else {
                completion([])
                return
            }

            // Filter to prioritize Apple Watch/HealthKit samples
            var watchSamples: [HKCategorySample] = []
            var otherSamples: [HKCategorySample] = []

            for sample in sleepSamples {
                let sourceName = sample.sourceRevision.source.name.lowercased()
                let bundleId = sample.sourceRevision.source.bundleIdentifier.lowercased()

                let isAppleWatch = sourceName.contains("watch") ||
                                   bundleId.contains("com.apple.health") ||
                                   bundleId.contains("com.apple.nano") ||
                                   sample.device?.name?.lowercased().contains("watch") == true

                if isAppleWatch {
                    watchSamples.append(sample)
                } else {
                    otherSamples.append(sample)
                }
            }

            let samplesToUse = !watchSamples.isEmpty ? watchSamples : otherSamples

            // Group sleep by date
            var sleepByDate: [String: [HKCategorySample]] = [:]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            for sample in samplesToUse {
                let dateKey = dateFormatter.string(from: sample.startDate)
                if sleepByDate[dateKey] == nil {
                    sleepByDate[dateKey] = []
                }
                sleepByDate[dateKey]?.append(sample)
            }

            // Calculate totals per day with deduplication
            var results: [[String: Any]] = []
            for (dateKey, daySamples) in sleepByDate {
                // Deduplicate samples for this day
                let deduplicatedSamples = self?.deduplicateSleepSamples(daySamples) ?? daySamples

                var totalSleep: TimeInterval = 0
                var deepSleep: TimeInterval = 0
                var remSleep: TimeInterval = 0
                var coreSleep: TimeInterval = 0
                var awakeSleep: TimeInterval = 0

                for sample in deduplicatedSamples {
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

            print("[AppDelegate] 😴 Found \(sleepSamples.count) total sleep samples from all sources")

            // Group samples by source to prioritize Apple Watch data
            var watchSamples: [HKCategorySample] = []
            var otherSamples: [HKCategorySample] = []

            for sample in sleepSamples {
                let sourceName = sample.sourceRevision.source.name.lowercased()
                let bundleId = sample.sourceRevision.source.bundleIdentifier.lowercased()

                // Check if sample is from Apple Watch or Apple's native sleep tracking
                let isAppleWatch = sourceName.contains("watch") ||
                                   bundleId.contains("com.apple.health") ||
                                   bundleId.contains("com.apple.nano") ||  // watchOS
                                   sample.device?.name?.lowercased().contains("watch") == true

                if isAppleWatch {
                    watchSamples.append(sample)
                } else {
                    otherSamples.append(sample)
                }
            }

            // Prioritize Apple Watch samples, fall back to other sources
            let samplesToUse: [HKCategorySample]
            if !watchSamples.isEmpty {
                samplesToUse = watchSamples
                print("[AppDelegate] 😴 Using \(watchSamples.count) Apple Watch/HealthKit samples (prioritized)")
                print("[AppDelegate] 😴 Ignoring \(otherSamples.count) samples from other sources")
            } else {
                samplesToUse = otherSamples
                print("[AppDelegate] 😴 No Apple Watch data, using \(otherSamples.count) samples from other sources")
            }

            // Deduplicate overlapping time intervals
            let deduplicatedSamples = self.deduplicateSleepSamples(samplesToUse)
            print("[AppDelegate] 😴 After deduplication: \(deduplicatedSamples.count) unique sleep intervals")

            var totalSleep: TimeInterval = 0
            var stages: [[String: Any]] = []
            var deepSleep: TimeInterval = 0
            var remSleep: TimeInterval = 0
            var coreSleep: TimeInterval = 0
            var awakeSleep: TimeInterval = 0

            for sample in deduplicatedSamples {
                let duration = sample.endDate.timeIntervalSince(sample.startDate)

                // Categorize by sleep stage - iOS 16+ has specific stages
                if #available(iOS 16.0, *) {
                    let sleepValue = HKCategoryValueSleepAnalysis(rawValue: sample.value)
                    switch sleepValue {
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
                    case .inBed:
                        // In bed is not counted as sleep
                        break
                    default:
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
            print("[AppDelegate] 😴 Sleep totals - Deep: \(String(format: "%.2f", deepSleep/3600))h, REM: \(String(format: "%.2f", remSleep/3600))h, Core: \(String(format: "%.2f", coreSleep/3600))h, Awake: \(String(format: "%.2f", awakeSleep/3600))h, Total: \(String(format: "%.2f", totalSleep/3600))h")

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

            print("[AppDelegate] 😴 Final sleep: \(String(format: "%.2f", totalSleep/3600)) hours")
            completion(totalSleep / 3600, stages)
        }

        healthStore.execute(query)
    }

    /// Deduplicate overlapping sleep samples to avoid double-counting
    private func deduplicateSleepSamples(_ samples: [HKCategorySample]) -> [HKCategorySample] {
        guard !samples.isEmpty else { return [] }

        // Sort by start date
        let sorted = samples.sorted { $0.startDate < $1.startDate }

        var result: [HKCategorySample] = []
        var processedIntervals: [(start: Date, end: Date)] = []

        for sample in sorted {
            let sampleStart = sample.startDate
            let sampleEnd = sample.endDate

            // Check if this sample overlaps with any already processed interval
            var isOverlapping = false
            for interval in processedIntervals {
                // Check for overlap: two intervals overlap if one starts before the other ends
                if sampleStart < interval.end && sampleEnd > interval.start {
                    isOverlapping = true
                    break
                }
            }

            if !isOverlapping {
                result.append(sample)
                processedIntervals.append((start: sampleStart, end: sampleEnd))
            }
        }

        return result
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

    // MARK: - Extended Vitals Fetch Functions

    /// Fetch extended vitals data from HealthKit
    /// Returns a dictionary with all extended vitals for display and storage
    private func fetchExtendedVitals(result: @escaping FlutterResult) {
        let group = DispatchGroup()
        var extendedData: [String: Any] = [:]

        // Walking Steadiness (iOS 15+)
        group.enter()
        fetchWalkingSteadiness { percent, classification in
            extendedData["walking_steadiness_percent"] = percent
            extendedData["walking_steadiness_classification"] = classification
            group.leave()
        }

        // Blood Pressure
        group.enter()
        fetchBloodPressure { systolic, diastolic in
            extendedData["blood_pressure_systolic"] = systolic
            extendedData["blood_pressure_diastolic"] = diastolic
            group.leave()
        }

        // Blood Glucose
        group.enter()
        fetchBloodGlucose { value in
            extendedData["blood_glucose"] = value
            group.leave()
        }

        // Body Temperature
        group.enter()
        fetchBodyTemperature { value in
            extendedData["body_temperature"] = value
            group.leave()
        }

        // Wrist Temperature (iOS 16+)
        group.enter()
        fetchWristTemperature { delta in
            extendedData["wrist_temperature_delta"] = delta
            group.leave()
        }

        // Six-Minute Walk Distance
        group.enter()
        fetchSixMinuteWalkDistance { value in
            extendedData["six_minute_walk_distance"] = value
            group.leave()
        }

        // VO2 Max
        group.enter()
        fetchVO2Max { value in
            extendedData["vo2_max"] = value
            group.leave()
        }

        // Mobility Metrics
        group.enter()
        fetchMobilityMetrics { metrics in
            extendedData.merge(metrics) { (_, new) in new }
            group.leave()
        }

        // Peripheral Perfusion Index
        group.enter()
        fetchPeripheralPerfusionIndex { value in
            extendedData["peripheral_perfusion_index"] = value
            group.leave()
        }

        // AFib Detection (from ECG)
        group.enter()
        fetchAFibStatus { detected, burden in
            extendedData["afib_detected"] = detected
            extendedData["afib_burden_percent"] = burden
            group.leave()
        }

        group.notify(queue: .main) {
            extendedData["timestamp"] = ISO8601DateFormatter().string(from: Date())
            print("[AppDelegate] 📊 Extended vitals fetched: \(extendedData.keys.count) metrics")
            result(extendedData)
        }
    }

    /// Fetch Walking Steadiness (iOS 15+)
    private func fetchWalkingSteadiness(completion: @escaping (Double?, String?) -> Void) {
        if #available(iOS 15.0, *) {
            guard let steadinessType = HKQuantityType.quantityType(forIdentifier: .appleWalkingSteadiness) else {
                completion(nil, nil)
                return
            }

            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: steadinessType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    completion(nil, nil)
                    return
                }

                let value = sample.quantity.doubleValue(for: .percent()) * 100
                let classification: String
                if value >= 75 {
                    classification = "OK"
                } else if value >= 50 {
                    classification = "Low"
                } else {
                    classification = "Very Low"
                }

                print("[AppDelegate] 🚶 Walking Steadiness: \(value)% (\(classification))")
                completion(value, classification)
            }

            self.healthStore.execute(query)
        } else {
            completion(nil, nil)
        }
    }

    /// Fetch Blood Pressure
    private func fetchBloodPressure(completion: @escaping (Double?, Double?) -> Void) {
        guard let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) else {
            completion(nil, nil)
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        // Fetch systolic
        let systolicQuery = HKSampleQuery(sampleType: systolicType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            let systolic = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: .millimeterOfMercury())

            // Fetch diastolic
            let diastolicQuery = HKSampleQuery(sampleType: diastolicType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                let diastolic = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: .millimeterOfMercury())

                if let sys = systolic, let dia = diastolic {
                    print("[AppDelegate] 💓 Blood Pressure: \(Int(sys))/\(Int(dia)) mmHg")
                }
                completion(systolic, diastolic)
            }

            self.healthStore.execute(diastolicQuery)
        }

        healthStore.execute(systolicQuery)
    }

    /// Fetch Blood Glucose
    private func fetchBloodGlucose(completion: @escaping (Double?) -> Void) {
        guard let glucoseType = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else {
            completion(nil)
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: glucoseType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else {
                completion(nil)
                return
            }

            // Return in mg/dL
            let value = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci)))
            print("[AppDelegate] 🩸 Blood Glucose: \(value) mg/dL")
            completion(value)
        }

        healthStore.execute(query)
    }

    /// Fetch Body Temperature
    private func fetchBodyTemperature(completion: @escaping (Double?) -> Void) {
        guard let tempType = HKQuantityType.quantityType(forIdentifier: .bodyTemperature) else {
            completion(nil)
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: tempType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else {
                completion(nil)
                return
            }

            let value = sample.quantity.doubleValue(for: .degreeCelsius())
            print("[AppDelegate] 🌡️ Body Temperature: \(value)°C")
            completion(value)
        }

        healthStore.execute(query)
    }

    /// Fetch Wrist Temperature (iOS 16+)
    private func fetchWristTemperature(completion: @escaping (Double?) -> Void) {
        if #available(iOS 16.0, *) {
            guard let wristTempType = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) else {
                completion(nil)
                return
            }

            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: wristTempType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    completion(nil)
                    return
                }

                let delta = sample.quantity.doubleValue(for: .degreeCelsius())
                print("[AppDelegate] 🌡️ Wrist Temp Delta: \(delta)°C")
                completion(delta)
            }

            self.healthStore.execute(query)
        } else {
            completion(nil)
        }
    }

    /// Fetch Six-Minute Walk Test Distance (iOS 14+)
    private func fetchSixMinuteWalkDistance(completion: @escaping (Double?) -> Void) {
        if #available(iOS 14.0, *) {
            guard let walkType = HKQuantityType.quantityType(forIdentifier: .sixMinuteWalkTestDistance) else {
                completion(nil)
                return
            }

            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: walkType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    completion(nil)
                    return
                }

                let value = sample.quantity.doubleValue(for: .meter())
                print("[AppDelegate] 🏃 Six-Minute Walk: \(value) meters")
                completion(value)
            }

            self.healthStore.execute(query)
        } else {
            completion(nil)
        }
    }

    /// Fetch VO2 Max (iOS 11+)
    private func fetchVO2Max(completion: @escaping (Double?) -> Void) {
        if #available(iOS 11.0, *) {
            guard let vo2Type = HKQuantityType.quantityType(forIdentifier: .vo2Max) else {
                completion(nil)
                return
            }

            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: vo2Type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    completion(nil)
                    return
                }

                // mL/kg/min
                let unit = HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))
                let value = sample.quantity.doubleValue(for: unit)
                print("[AppDelegate] 💪 VO2 Max: \(value) mL/kg/min")
                completion(value)
            }

            self.healthStore.execute(query)
        } else {
            completion(nil)
        }
    }

    /// Fetch Mobility Metrics (iOS 14+)
    private func fetchMobilityMetrics(completion: @escaping ([String: Any]) -> Void) {
        if #available(iOS 14.0, *) {
            var metrics: [String: Any] = [:]
            let group = DispatchGroup()

            // Walking Asymmetry
            if let asymmetryType = HKQuantityType.quantityType(forIdentifier: .walkingAsymmetryPercentage) {
                group.enter()
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
                let query = HKSampleQuery(sampleType: asymmetryType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                    if let sample = samples?.first as? HKQuantitySample {
                        metrics["walking_asymmetry_percent"] = sample.quantity.doubleValue(for: .percent()) * 100
                    }
                    group.leave()
                }
                self.healthStore.execute(query)
            }

            // Walking Speed
            if let speedType = HKQuantityType.quantityType(forIdentifier: .walkingSpeed) {
                group.enter()
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
                let query = HKSampleQuery(sampleType: speedType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                    if let sample = samples?.first as? HKQuantitySample {
                        metrics["walking_speed"] = sample.quantity.doubleValue(for: HKUnit.meter().unitDivided(by: .second()))
                    }
                    group.leave()
                }
                self.healthStore.execute(query)
            }

            // Double Support Time
            if let doubleSupportType = HKQuantityType.quantityType(forIdentifier: .walkingDoubleSupportPercentage) {
                group.enter()
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
                let query = HKSampleQuery(sampleType: doubleSupportType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                    if let sample = samples?.first as? HKQuantitySample {
                        metrics["double_support_time_percent"] = sample.quantity.doubleValue(for: .percent()) * 100
                    }
                    group.leave()
                }
                self.healthStore.execute(query)
            }

            // Stair Ascent Speed
            if let ascentType = HKQuantityType.quantityType(forIdentifier: .stairAscentSpeed) {
                group.enter()
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
                let query = HKSampleQuery(sampleType: ascentType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                    if let sample = samples?.first as? HKQuantitySample {
                        metrics["stair_ascent_speed"] = sample.quantity.doubleValue(for: HKUnit.meter().unitDivided(by: .second()))
                    }
                    group.leave()
                }
                self.healthStore.execute(query)
            }

            // Stair Descent Speed
            if let descentType = HKQuantityType.quantityType(forIdentifier: .stairDescentSpeed) {
                group.enter()
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
                let query = HKSampleQuery(sampleType: descentType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                    if let sample = samples?.first as? HKQuantitySample {
                        metrics["stair_descent_speed"] = sample.quantity.doubleValue(for: HKUnit.meter().unitDivided(by: .second()))
                    }
                    group.leave()
                }
                self.healthStore.execute(query)
            }

            group.notify(queue: .main) {
                print("[AppDelegate] 🚶 Mobility Metrics: \(metrics)")
                completion(metrics)
            }
        } else {
            completion([:])
        }
    }

    /// Fetch Peripheral Perfusion Index (iOS 11+)
    private func fetchPeripheralPerfusionIndex(completion: @escaping (Double?) -> Void) {
        if #available(iOS 11.0, *) {
            guard let perfusionType = HKQuantityType.quantityType(forIdentifier: .peripheralPerfusionIndex) else {
                completion(nil)
                return
            }

            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: perfusionType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    completion(nil)
                    return
                }

                let value = sample.quantity.doubleValue(for: .percent()) * 100
                print("[AppDelegate] 🩺 Peripheral Perfusion Index: \(value)%")
                completion(value)
            }

            self.healthStore.execute(query)
        } else {
            completion(nil)
        }
    }

    /// Fetch AFib Status from ECG (iOS 14.3+)
    private func fetchAFibStatus(completion: @escaping (Bool, Double?) -> Void) {
        if #available(iOS 14.3, *) {
            let ecgType = HKObjectType.electrocardiogramType()
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

            // Query for recent ECGs (last 30 days)
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            let predicate = HKQuery.predicateForSamples(withStart: thirtyDaysAgo, end: Date(), options: .strictStartDate)

            let query = HKSampleQuery(sampleType: ecgType, predicate: predicate, limit: 10, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                guard let ecgSamples = samples as? [HKElectrocardiogram] else {
                    completion(false, nil)
                    return
                }

                var afibCount = 0
                for ecg in ecgSamples {
                    if ecg.classification == .atrialFibrillation {
                        afibCount += 1
                    }
                }

                let afibDetected = afibCount > 0
                let afibBurden = ecgSamples.count > 0 ? Double(afibCount) / Double(ecgSamples.count) * 100 : nil

                if afibDetected {
                    print("[AppDelegate] ⚠️ AFib Detected! Burden: \(afibBurden ?? 0)%")
                }
                completion(afibDetected, afibBurden)
            }

            self.healthStore.execute(query)
        } else {
            completion(false, nil)
        }
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

            // Blood Glucose
            HKObjectType.quantityType(forIdentifier: .bloodGlucose)!,

            // Body Temperature
            HKObjectType.quantityType(forIdentifier: .bodyTemperature)!,

            // Falls
            HKObjectType.quantityType(forIdentifier: .numberOfTimesFallen)!,

            // Workouts
            HKObjectType.workoutType(),
        ]

        // Add iOS 11+ types
        if #available(iOS 11.0, *) {
            // VO2 Max - Cardiovascular fitness
            if let vo2MaxType = HKObjectType.quantityType(forIdentifier: .vo2Max) {
                typesToRead.insert(vo2MaxType)
            }
            // Peripheral Perfusion Index
            if let perfusionType = HKObjectType.quantityType(forIdentifier: .peripheralPerfusionIndex) {
                typesToRead.insert(perfusionType)
            }
        }

        // Add iOS 14+ types - Mobility metrics
        if #available(iOS 14.0, *) {
            // Six-Minute Walk Distance
            if let sixMinWalkType = HKObjectType.quantityType(forIdentifier: .sixMinuteWalkTestDistance) {
                typesToRead.insert(sixMinWalkType)
            }
            // Walking Speed
            if let walkingSpeedType = HKObjectType.quantityType(forIdentifier: .walkingSpeed) {
                typesToRead.insert(walkingSpeedType)
            }
            // Walking Asymmetry
            if let asymmetryType = HKObjectType.quantityType(forIdentifier: .walkingAsymmetryPercentage) {
                typesToRead.insert(asymmetryType)
            }
            // Double Support Time
            if let doubleSupportType = HKObjectType.quantityType(forIdentifier: .walkingDoubleSupportPercentage) {
                typesToRead.insert(doubleSupportType)
            }
            // Stair Ascent Speed
            if let stairAscentType = HKObjectType.quantityType(forIdentifier: .stairAscentSpeed) {
                typesToRead.insert(stairAscentType)
            }
            // Stair Descent Speed
            if let stairDescentType = HKObjectType.quantityType(forIdentifier: .stairDescentSpeed) {
                typesToRead.insert(stairDescentType)
            }
        }

        // Add iOS 14.3+ types
        if #available(iOS 14.3, *) {
            // AFib History (ECG)
            let afibType = HKObjectType.electrocardiogramType()
            typesToRead.insert(afibType)
        }

        // Add iOS 15+ types
        if #available(iOS 15.0, *) {
            // Walking Steadiness
            if let steadinessType = HKObjectType.quantityType(forIdentifier: .appleWalkingSteadiness) {
                typesToRead.insert(steadinessType)
            }
        }

        // Add iOS 16+ types
        if #available(iOS 16.0, *) {
            // Sleeping Wrist Temperature
            if let wristTempType = HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
                typesToRead.insert(wristTempType)
            }
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

    // MARK: - Send Commands to Watch

    /// Send a command to the Watch via WatchConnectivity
    private func sendWatchCommand(command: String, result: @escaping FlutterResult) {
        let session = WCSession.default

        guard session.activationState == .activated else {
            print("[AppDelegate] WCSession not activated")
            result(FlutterError(code: "NOT_ACTIVATED", message: "WatchConnectivity not activated", details: nil))
            return
        }

        guard session.isPaired else {
            print("[AppDelegate] No Watch paired")
            result(FlutterError(code: "NOT_PAIRED", message: "No Apple Watch paired", details: nil))
            return
        }

        guard session.isReachable else {
            print("[AppDelegate] Watch not reachable - make sure KinduraWatch app is running")
            result(FlutterError(code: "NOT_REACHABLE", message: "Watch not reachable. Open the KinduraWatch app on your Watch.", details: nil))
            return
        }

        print("[AppDelegate] 📲 Sending command to Watch: \(command)")

        session.sendMessage(["command": command], replyHandler: { response in
            print("[AppDelegate] ✅ Watch response: \(response)")
            DispatchQueue.main.async {
                result(response)
            }
        }, errorHandler: { error in
            print("[AppDelegate] ❌ Failed to send command to Watch: \(error.localizedDescription)")
            DispatchQueue.main.async {
                result(FlutterError(code: "SEND_FAILED", message: error.localizedDescription, details: nil))
            }
        })
    }

    // MARK: - Send Medication Reminder to Watch

    /// Send a medication reminder to the Watch
    /// Uses sendMessage for real-time delivery with transferUserInfo fallback for guaranteed delivery
    private func sendMedicationReminderToWatch(medicationData: [String: Any], result: @escaping FlutterResult) {
        let session = WCSession.default

        guard session.activationState == .activated else {
            print("[AppDelegate] 💊 WCSession not activated for medication reminder")
            result(false)
            return
        }

        guard session.isPaired else {
            print("[AppDelegate] 💊 No Watch paired - cannot send medication reminder")
            result(false)
            return
        }

        // Build reminder payload
        var reminderData = medicationData
        reminderData["type"] = "medication_reminder"
        reminderData["timestamp"] = ISO8601DateFormatter().string(from: Date())
        reminderData["reminder_id"] = UUID().uuidString

        print("[AppDelegate] 💊 Sending medication reminder to Watch: \(reminderData["medication_name"] ?? "unknown")")

        // Try real-time delivery first if Watch is reachable
        if session.isReachable {
            session.sendMessage(reminderData, replyHandler: { response in
                print("[AppDelegate] 💊 ✅ Watch received medication reminder: \(response)")
                DispatchQueue.main.async {
                    result(true)
                }
            }, errorHandler: { error in
                print("[AppDelegate] 💊 ⚠️ Real-time delivery failed: \(error.localizedDescription)")
                // Fallback to guaranteed delivery
                self.queueMedicationReminderForDelivery(reminderData)
                DispatchQueue.main.async {
                    result(true) // Still return true as it's queued
                }
            })
        } else {
            // Watch not immediately reachable - queue for guaranteed delivery
            print("[AppDelegate] 💊 Watch not reachable - queuing via transferUserInfo")
            queueMedicationReminderForDelivery(reminderData)
            result(true)
        }
    }

    /// Queue medication reminder for guaranteed delivery via transferUserInfo
    private func queueMedicationReminderForDelivery(_ reminderData: [String: Any]) {
        var data = reminderData
        data["transfer_id"] = UUID().uuidString
        data["queued_at"] = ISO8601DateFormatter().string(from: Date())

        WCSession.default.transferUserInfo(data)
        print("[AppDelegate] 💊 Medication reminder queued via transferUserInfo")
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

        // Handle fall alert (high priority) - from Watch fall detection
        if message["type"] as? String == "fall_alert" {
            print("[AppDelegate] ⚠️ FALL ALERT received from Watch!")
            print("[AppDelegate] Fall data: severity=\(message["severity"] ?? "unknown"), impact=\(message["impact_g"] ?? 0)G")

            // Fall-specific deduplication using timestamp
            let fallTimestamp = message["timestamp"] as? String ?? ""
            let severity = message["severity"] as? String ?? ""
            let fallEventKey = "processedFall_\(fallTimestamp)_\(severity)"

            if UserDefaults.standard.bool(forKey: fallEventKey) {
                print("[AppDelegate] ⚠️ Skipping duplicate fall event (real-time): \(fallTimestamp)")
                replyHandler(["status": "fall_alert_duplicate"])
                return
            }

            // Mark this fall event as processed
            UserDefaults.standard.set(true, forKey: fallEventKey)

            // Store as latest vitals with fall flag
            var fallVitals = message
            fallVitals["fall_detected"] = true
            latestWatchVitals = fallVitals

            // Forward to Django API immediately (high priority)
            forwardFallAlertToDjango(fallData: message)

            // Notify Flutter about fall detection (if active)
            DispatchQueue.main.async {
                self.watchVitalsChannel?.invokeMethod("onWatchVitalsReceived", arguments: fallVitals)
            }

            replyHandler(["status": "fall_alert_received"])
            return
        }

        // Handle medication reminder response from Watch
        if message["type"] as? String == "medication_reminder_response" {
            print("[AppDelegate] 💊 Medication reminder response from Watch: \(message)")

            // Forward to Flutter via method channel
            DispatchQueue.main.async {
                self.watchVitalsChannel?.invokeMethod("onMedicationReminderResponse", arguments: message)
            }

            replyHandler(["status": "medication_response_received"])
            return
        }

        replyHandler(["status": "unknown_type"])
    }

    // MARK: - Forward Vitals to Django API (Native Layer)

    private func forwardVitalsToDjango(vitals: [String: Any]) {
        if DEBUG_MODE {
            print("[AppDelegate] 🌐 DEBUG: Forwarding vitals to Django...")
            print("  HR: \(vitals["heart_rate"] ?? 0) | O2: \(vitals["blood_oxygen"] ?? 0)")
            print("  Steps: \(vitals["steps"] ?? 0) | Delivery: \(vitals["delivery_method"] ?? "sendMessage")")
        }

        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let baseURL = defaults.string(forKey: "api_base_url"),
              let token = defaults.string(forKey: "auth_token"),
              !baseURL.isEmpty, !token.isEmpty else {
            print("[AppDelegate] ⚠️ No API configuration - cannot forward vitals")
            if DEBUG_MODE { print("[AppDelegate] 📊 Buffering vitals for later...") }
            bufferVitals(vitals)
            return
        }

        if DEBUG_MODE { print("[AppDelegate] 📊 API URL: \(baseURL)/api/watch-vitals/dev/") }

        // Build API URL
        let urlString = "\(baseURL)/api/watch-vitals/dev/"
        guard let url = URL(string: urlString) else {
            print("[AppDelegate] ❌ Invalid URL: \(urlString)")
            return
        }

        // Prepare request body
        var apiData: [String: Any] = [:]
        // Vitals
        apiData["heart_rate"] = vitals["heart_rate"] ?? 0
        apiData["blood_oxygen"] = vitals["blood_oxygen"] ?? 0
        apiData["hrv"] = vitals["hrv"]
        apiData["respiratory_rate"] = vitals["respiratory_rate"]
        // Sleep
        apiData["total_sleep_hours"] = vitals["total_sleep_hours"]
        apiData["deep_sleep_hours"] = vitals["deep_sleep_hours"]
        apiData["rem_sleep_hours"] = vitals["rem_sleep_hours"]
        apiData["core_sleep_hours"] = vitals["core_sleep_hours"]
        apiData["awake_time_hours"] = vitals["awake_time_hours"]
        apiData["awakenings_count"] = vitals["awakenings_count"]
        apiData["sleep_quality"] = vitals["sleep_quality"]
        // Falls
        apiData["fall_detected"] = vitals["fall_detected"] ?? false
        // Activity
        apiData["steps"] = vitals["steps"] ?? 0
        apiData["calories"] = vitals["calories"] ?? 0
        apiData["distance_km"] = vitals["distance_km"] ?? 0
        apiData["floors_climbed"] = vitals["floors_climbed"] ?? 0
        apiData["exercise_minutes"] = vitals["exercise_minutes"] ?? 0
        apiData["stand_minutes"] = vitals["stand_minutes"] ?? 0
        // Timestamp
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
                if self?.DEBUG_MODE == true { print("[AppDelegate] 📊 Buffering vitals due to network error") }
                self?.bufferVitals(vitals)
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    print("[AppDelegate] ✅ Vitals forwarded to Django (HR=\(vitals["heart_rate"] ?? 0))")

                    // Debug: Log response details
                    if self?.DEBUG_MODE == true, let data = data {
                        if let responseStr = String(data: data, encoding: .utf8) {
                            let preview = String(responseStr.prefix(100))
                            print("[AppDelegate] 📊 API Response: \(preview)...")
                        }
                    }

                    // Try to send any buffered vitals
                    self?.sendBufferedVitals()
                } else {
                    print("[AppDelegate] ❌ API error: \(httpResponse.statusCode)")
                    if self?.DEBUG_MODE == true, let data = data {
                        let errorStr = String(data: data, encoding: .utf8) ?? "no body"
                        print("[AppDelegate] 📊 Error body: \(errorStr)")
                    }
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

    // MARK: - Forward Fall Alert to Django API (High Priority)

    private func forwardFallAlertToDjango(fallData: [String: Any]) {
        print("[AppDelegate] 🚨 Forwarding fall alert to Django API")

        // Convert fall alert to vitals format for API
        var vitals: [String: Any] = [:]
        vitals["fall_detected"] = true
        vitals["heart_rate"] = fallData["heart_rate"] ?? 0
        vitals["blood_oxygen"] = fallData["blood_oxygen"] ?? 0
        vitals["timestamp"] = fallData["timestamp"] ?? ISO8601DateFormatter().string(from: Date())

        // Include fall-specific data as extra fields
        // The API should handle these additional fields
        vitals["fall_severity"] = fallData["severity"] ?? "unknown"
        vitals["fall_impact_g"] = fallData["impact_g"] ?? 0
        vitals["fall_requires_response"] = fallData["requires_response"] ?? true

        // Use the same forwarding mechanism
        forwardVitalsToDjango(vitals: vitals)
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

        // Handle fall alert via application context (background delivery)
        if applicationContext["type"] as? String == "fall_alert" {
            print("[AppDelegate] ⚠️ FALL ALERT received via application context!")
            print("[AppDelegate] Fall data: severity=\(applicationContext["severity"] ?? "unknown"), impact=\(applicationContext["impact_g"] ?? 0)G")

            // Fall-specific deduplication using timestamp
            let fallTimestamp = applicationContext["timestamp"] as? String ?? ""
            let severity = applicationContext["severity"] as? String ?? ""
            let fallEventKey = "processedFall_\(fallTimestamp)_\(severity)"

            if UserDefaults.standard.bool(forKey: fallEventKey) {
                print("[AppDelegate] ⚠️ Skipping duplicate fall event (context): \(fallTimestamp)")
                return
            }

            // Mark this fall event as processed
            UserDefaults.standard.set(true, forKey: fallEventKey)

            var fallVitals = applicationContext
            fallVitals["fall_detected"] = true
            latestWatchVitals = fallVitals

            // Forward to Django API
            forwardFallAlertToDjango(fallData: applicationContext)

            // Notify Flutter
            DispatchQueue.main.async {
                self.watchVitalsChannel?.invokeMethod("onWatchVitalsReceived", arguments: fallVitals)
            }
        }
    }

    // MARK: - Receive Queued Transfers via transferUserInfo (Guaranteed Delivery)

    /// Handle queued transfers from Watch via transferUserInfo
    /// This method receives data sent with guaranteed delivery - queued on Watch until delivery succeeds
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        print("[AppDelegate] 📬 Received userInfo from Watch: \(userInfo.keys)")

        // Debug: Print full payload details
        if DEBUG_MODE {
            print("[AppDelegate] 📊 DEBUG transferUserInfo Payload:")
            if let type = userInfo["type"] as? String { print("  Type: \(type)") }
            if let hr = userInfo["heart_rate"] as? Double { print("  HR: \(Int(hr)) BPM") }
            if let o2 = userInfo["blood_oxygen"] as? Double { print("  O2: \(Int(o2))%") }
            if let steps = userInfo["steps"] as? Int { print("  Steps: \(steps)") }
            if let calories = userInfo["calories"] as? Int { print("  Calories: \(calories)") }
            if let transferId = userInfo["transfer_id"] as? String { print("  Transfer ID: \(transferId.prefix(8))...") }
            if let timestamp = userInfo["transfer_timestamp"] as? Double {
                let date = Date(timeIntervalSince1970: timestamp)
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                print("  Queued at: \(formatter.string(from: date))")
            }
        }

        // Check for transfer_id to deduplicate
        let transferId = userInfo["transfer_id"] as? String ?? UUID().uuidString
        let processedKey = "processedTransfer_\(transferId)"

        // Skip if we've already processed this transfer
        if UserDefaults.standard.bool(forKey: processedKey) {
            print("[AppDelegate] ⚠️ Skipping duplicate transfer: \(transferId)")
            return
        }

        // Mark as processed
        UserDefaults.standard.set(true, forKey: processedKey)

        // Clean up old processed keys (keep only last 24 hours)
        cleanupOldTransferKeys()

        // Handle fall alert (high priority)
        if userInfo["type"] as? String == "fall_alert" {
            let priority = userInfo["priority"] as? String ?? "normal"
            print("[AppDelegate] 🚨📬 FALL ALERT via transferUserInfo (priority: \(priority))")
            print("[AppDelegate] Fall: severity=\(userInfo["severity"] ?? "unknown"), impact=\(userInfo["impact_g"] ?? 0)G")

            // Fall-specific deduplication using timestamp (not transfer_id)
            // Buffered falls may have different transfer_ids but same timestamp
            let fallTimestamp = userInfo["timestamp"] as? String ?? ""
            let severity = userInfo["severity"] as? String ?? ""
            let fallEventKey = "processedFall_\(fallTimestamp)_\(severity)"

            if UserDefaults.standard.bool(forKey: fallEventKey) {
                print("[AppDelegate] ⚠️ Skipping duplicate fall event: \(fallTimestamp)")
                return
            }

            // Mark this fall event as processed
            UserDefaults.standard.set(true, forKey: fallEventKey)

            var fallVitals = userInfo
            fallVitals["fall_detected"] = true
            fallVitals["delivery_method"] = "transferUserInfo"
            latestWatchVitals = fallVitals

            // Forward to Django API immediately
            forwardFallAlertToDjango(fallData: userInfo)

            // Notify Flutter
            DispatchQueue.main.async {
                self.watchVitalsChannel?.invokeMethod("onWatchVitalsReceived", arguments: fallVitals)
            }
            return
        }

        // Handle watch vitals
        if userInfo["type"] as? String == "watch_vitals" {
            print("[AppDelegate] 📬 Vitals via transferUserInfo (guaranteed delivery)")

            var vitals = userInfo
            vitals["delivery_method"] = "transferUserInfo"
            latestWatchVitals = vitals

            // Forward to Django API
            forwardVitalsToDjango(vitals: userInfo)

            // Notify Flutter
            DispatchQueue.main.async {
                self.watchVitalsChannel?.invokeMethod("onWatchVitalsReceived", arguments: vitals)
            }
            return
        }

        print("[AppDelegate] ⚠️ Unknown userInfo type: \(userInfo["type"] ?? "nil")")
    }

    /// Clean up old transfer and fall event keys to prevent UserDefaults bloat
    private func cleanupOldTransferKeys() {
        let defaults = UserDefaults.standard
        let dictionary = defaults.dictionaryRepresentation()

        // We use a simple counter-based cleanup to avoid expensive operations
        let cleanupKey = "lastTransferCleanup"
        let cleanupCount = defaults.integer(forKey: cleanupKey)

        // Only cleanup every 100 transfers
        if cleanupCount > 100 {
            defaults.set(0, forKey: cleanupKey)

            // Clean up old transfer keys
            var transferKeysToRemove: [String] = []
            for key in dictionary.keys where key.hasPrefix("processedTransfer_") {
                transferKeysToRemove.append(key)
            }

            // Keep only the last 50 transfer IDs
            if transferKeysToRemove.count > 50 {
                let keysToDelete = Array(transferKeysToRemove.prefix(transferKeysToRemove.count - 50))
                for key in keysToDelete {
                    defaults.removeObject(forKey: key)
                }
                print("[AppDelegate] 🧹 Cleaned up \(keysToDelete.count) old transfer keys")
            }

            // Clean up old fall event keys
            var fallKeysToRemove: [String] = []
            for key in dictionary.keys where key.hasPrefix("processedFall_") {
                fallKeysToRemove.append(key)
            }

            // Keep only the last 100 fall events (falls are more important to track)
            if fallKeysToRemove.count > 100 {
                let keysToDelete = Array(fallKeysToRemove.prefix(fallKeysToRemove.count - 100))
                for key in keysToDelete {
                    defaults.removeObject(forKey: key)
                }
                print("[AppDelegate] 🧹 Cleaned up \(keysToDelete.count) old fall event keys")
            }
        } else {
            defaults.set(cleanupCount + 1, forKey: cleanupKey)
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

        // HRV Observer
        if let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            hrvObserver = HKObserverQuery(sampleType: hrvType, predicate: nil) { [weak self] query, completionHandler, error in
                if let error = error {
                    print("[AppDelegate] ❌ HRV observer error: \(error.localizedDescription)")
                    completionHandler()
                    return
                }

                print("[AppDelegate] 💓 HRV changed in HealthKit")
                self?.notifyFlutterHealthUpdate(type: "hrv")
                completionHandler()
            }

            if let observer = hrvObserver {
                healthStore.execute(observer)
                healthStore.enableBackgroundDelivery(for: hrvType, frequency: .immediate) { success, error in
                    if success {
                        print("[AppDelegate] ✅ Background delivery enabled for HRV")
                    }
                }
            }
        }

        // Respiratory Rate Observer
        if let respiratoryType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) {
            respiratoryRateObserver = HKObserverQuery(sampleType: respiratoryType, predicate: nil) { [weak self] query, completionHandler, error in
                if let error = error {
                    print("[AppDelegate] ❌ Respiratory rate observer error: \(error.localizedDescription)")
                    completionHandler()
                    return
                }

                print("[AppDelegate] 🌬️ Respiratory rate changed in HealthKit")
                self?.notifyFlutterHealthUpdate(type: "respiratory_rate")
                completionHandler()
            }

            if let observer = respiratoryRateObserver {
                healthStore.execute(observer)
                healthStore.enableBackgroundDelivery(for: respiratoryType, frequency: .immediate) { success, error in
                    if success {
                        print("[AppDelegate] ✅ Background delivery enabled for respiratory rate")
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
        print("[AppDelegate] 🔔 HealthKit observers started successfully (6 types: HR, O2, HRV, RespRate, Steps, Sleep)")
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
        if let observer = hrvObserver {
            healthStore.stop(observer)
            hrvObserver = nil
        }
        if let observer = respiratoryRateObserver {
            healthStore.stop(observer)
            respiratoryRateObserver = nil
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
