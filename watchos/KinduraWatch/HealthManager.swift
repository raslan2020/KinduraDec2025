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

// MARK: - Medication Reminder Model
struct MedicationReminder: Identifiable {
    let id: String
    let medicationId: String
    let medicationName: String
    let dosage: String
    let form: String
    let scheduledTime: Date
    let instructions: String
    let isFollowUp: Bool
    let followUpNumber: Int
    let requiresEscalation: Bool

    init(from message: [String: Any]) {
        self.id = message["reminder_id"] as? String ?? UUID().uuidString
        self.medicationId = message["medication_id"] as? String ?? ""
        self.medicationName = message["medication_name"] as? String ?? "Medication"
        self.dosage = message["dosage"] as? String ?? ""
        self.form = message["form"] as? String ?? ""

        if let timeStr = message["scheduled_time"] as? String {
            self.scheduledTime = ISO8601DateFormatter().date(from: timeStr) ?? Date()
        } else {
            self.scheduledTime = Date()
        }

        self.instructions = message["instructions"] as? String ?? ""
        self.isFollowUp = message["is_follow_up"] as? Bool ?? false
        self.followUpNumber = message["follow_up_number"] as? Int ?? 0
        self.requiresEscalation = message["requires_escalation"] as? Bool ?? false
    }

    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: scheduledTime)
    }
}

// MARK: - Health Manager
class HealthManager: NSObject, ObservableObject, WCSessionDelegate, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    private let healthStore = HKHealthStore()
    private var wcSession: WCSession?

    // DEBUG MODE - Set to true for verbose logging
    private let DEBUG_MODE = true

    // WCSession reachability check timer
    private var reachabilityCheckTimer: Timer?
    private let reachabilityCheckInterval: TimeInterval = 30 // Check every 30 seconds

    // Vitals
    @Published var heartRate: Double = 0
    @Published var bloodOxygen: Double = 0
    @Published var hrv: Double = 0
    @Published var respiratoryRate: Double = 0
    @Published var bodyTemperature: Double = 0  // In Celsius
    @Published var bloodPressureSystolic: Double = 0
    @Published var bloodPressureDiastolic: Double = 0
    @Published var bloodGlucose: Double = 0  // In mg/dL

    // Heart Rhythm & Sleep Abnormalities
    @Published var hasAFibDetected: Bool = false
    @Published var afibBurdenPercent: Double = 0  // Percentage of time in AFib
    @Published var lastAFibDate: Date?
    @Published var hasSleepApneaDetected: Bool = false
    @Published var apneaHypopneaIndex: Double = 0  // AHI score (events per hour)

    // Abnormality Alerts
    @Published var hasAbnormalVitals: Bool = false
    @Published var abnormalityAlerts: [String] = []

    // Sleep
    @Published var totalSleepHours: Double = 0
    @Published var sleepStages: [SleepStage] = []
    @Published var isSleepMonitoringActive: Bool = false
    @Published var awakeningsCount: Int = 0

    // Activity Data
    @Published var steps: Int = 0
    @Published var calories: Double = 0
    @Published var distanceKm: Double = 0
    @Published var floorsClimbed: Int = 0
    @Published var exerciseMinutes: Int = 0
    @Published var standMinutes: Int = 0

    // Fall Detection
    @Published var isFallDetectionEnabled: Bool = true
    @Published var recentFalls: [FallEvent] = []
    @Published var fallDetectionStatus: String = "Monitoring..."
    @Published var lastImpactG: Double = 0

    // Medication Reminders
    @Published var currentMedicationReminder: MedicationReminder?
    @Published var showMedicationReminderAlert: Bool = false
    @Published var pendingMedicationReminders: [MedicationReminder] = []

    // CoreMotion for real-time fall detection
    private let motionManager = CMMotionManager()
    private var fallDetectionTimer: Timer?
    private var lastHighImpactTime: Date?
    private var isInFreeFall: Bool = false
    private var freeFallStartTime: Date?

    // Fall detection thresholds
    // TESTING MODE: Lower thresholds for easier testing (set to higher values for production)
    private let freeFallThreshold: Double = 0.3      // Below 0.3G indicates free fall
    private let impactThreshold: Double = 3.0        // Above 3G indicates hard impact (after free-fall)
    private let impactOnlyThreshold: Double = 6.0    // Above 6G for impact-only detection (fast arm movements)
    private let minFreeFallDuration: TimeInterval = 0.08  // Minimum 80ms free-fall (shorter for testing)
    private let fallConfirmationWindow: TimeInterval = 2.0  // Time window to confirm fall
    // NOTE: For production, use: impactThreshold=4.0, impactOnlyThreshold=10.0, minFreeFallDuration=0.15

    // Authorization & Monitoring State
    @Published var isHealthKitAuthorized: Bool = false
    @Published var isRealTimeMonitoring: Bool = false
    @Published var isWorkoutActive: Bool = false
    @Published var workoutStatus: String = "Not Active"

    private var heartRateQuery: HKObserverQuery?
    private var sleepQuery: HKObserverQuery?
    private var fallObserverQuery: HKObserverQuery?  // Observer for HealthKit falls (Apple native + ours)
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
        loadPendingVitals()  // Load any buffered vitals from previous session
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

                // Load any pending data from persistent storage
                self.loadPendingVitals()
                self.loadPendingFallAlerts()

                // Send any buffered CRITICAL fall alerts first
                self.sendBufferedFallAlerts()

                // Send any buffered vitals
                self.sendBufferedVitals()

                // Request configuration from iPhone if not already configured
                if !ConfigurationManager.shared.isConfigured {
                    self.requestConfigurationFromiPhone()
                }

                // Start reachability check timer
                self.startReachabilityCheckTimer()
            case .inactive:
                print("[HealthManager] WCSession inactive")
                self.stopReachabilityCheckTimer()
            case .notActivated:
                print("[HealthManager] WCSession not activated")
                self.stopReachabilityCheckTimer()
            @unknown default:
                break
            }
        }
    }

    // MARK: - WCSession Reachability Check Timer

    private func startReachabilityCheckTimer() {
        // Stop any existing timer
        stopReachabilityCheckTimer()

        // Start a new timer on the main run loop
        DispatchQueue.main.async {
            self.reachabilityCheckTimer = Timer.scheduledTimer(withTimeInterval: self.reachabilityCheckInterval, repeats: true) { [weak self] _ in
                self?.checkReachabilityAndSync()
            }
            print("[HealthManager] ⏰ Started reachability check timer (every \(self.reachabilityCheckInterval)s)")
        }
    }

    private func stopReachabilityCheckTimer() {
        reachabilityCheckTimer?.invalidate()
        reachabilityCheckTimer = nil
    }

    private func checkReachabilityAndSync() {
        guard let session = wcSession, session.activationState == .activated else {
            print("[HealthManager] ⏰ Reachability check: Session not activated")
            return
        }

        let hasPendingData = !pendingVitals.isEmpty || !pendingFallAlerts.isEmpty

        if session.isReachable {
            print("[HealthManager] ⏰ Reachability check: iPhone reachable")

            // Send any pending data
            if hasPendingData {
                print("[HealthManager] ⏰ Sending \(pendingFallAlerts.count) pending falls, \(pendingVitals.count) pending vitals")
                sendBufferedFallAlerts()
                sendBufferedVitals()
            }
        } else {
            print("[HealthManager] ⏰ Reachability check: iPhone NOT reachable (pending: \(pendingVitals.count) vitals, \(pendingFallAlerts.count) falls)")
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

            // Handle vitals request from iPhone
            if message["type"] as? String == "request_vitals" {
                print("[HealthManager] 📲 iPhone requested current vitals")
                let vitals = self.createVitalsPayload()
                replyHandler(vitals)
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

            // Handle medication reminder from iPhone
            if message["type"] as? String == "medication_reminder" {
                print("[HealthManager] 💊 Received medication reminder from iPhone")
                self.handleMedicationReminder(message: message, replyHandler: replyHandler)
                return
            }

            replyHandler(["status": "received"])
        }
    }

    // Note: sessionDidBecomeInactive and sessionDidDeactivate are iOS-only
    // On watchOS, only session(_:activationDidCompleteWith:error:) is required

    // MARK: - Medication Reminder Handling

    /// Handle incoming medication reminder from iPhone
    private func handleMedicationReminder(message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        let reminder = MedicationReminder(from: message)

        print("[HealthManager] 💊 Medication: \(reminder.medicationName) (\(reminder.dosage))")
        print("[HealthManager] 💊 Scheduled: \(reminder.timeString), Follow-up: \(reminder.isFollowUp)")

        DispatchQueue.main.async {
            // Add to pending queue if already showing a reminder
            if self.showMedicationReminderAlert {
                self.pendingMedicationReminders.append(reminder)
                print("[HealthManager] 💊 Queued reminder (already showing one)")
            } else {
                // Show immediately
                self.currentMedicationReminder = reminder
                self.showMedicationReminderAlert = true
            }

            // Play haptic notification
            WKInterfaceDevice.current().play(.notification)

            // Play more urgent haptic for follow-ups
            if reminder.isFollowUp && reminder.followUpNumber >= 2 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    WKInterfaceDevice.current().play(.retry)
                }
            }
        }

        replyHandler(["status": "reminder_displayed", "reminder_id": reminder.id])
    }

    /// Send medication reminder response to iPhone
    /// action: "taken", "skipped", "snoozed"
    func sendMedicationReminderResponse(
        reminderId: String,
        medicationId: String,
        action: String,
        scheduledTime: Date,
        takenAt: Date? = nil
    ) {
        guard let session = wcSession, session.activationState == .activated else {
            print("[HealthManager] 💊 Cannot send response - session not activated")
            bufferMedicationResponse(reminderId: reminderId, medicationId: medicationId, action: action, scheduledTime: scheduledTime, takenAt: takenAt)
            return
        }

        var response: [String: Any] = [
            "type": "medication_reminder_response",
            "reminder_id": reminderId,
            "medication_id": medicationId,
            "action": action,
            "scheduled_time": ISO8601DateFormatter().string(from: scheduledTime),
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "source": "apple_watch"
        ]

        if let takenAt = takenAt {
            response["taken_at"] = ISO8601DateFormatter().string(from: takenAt)
        }

        print("[HealthManager] 💊 Sending medication response: \(action) for \(medicationId)")

        if session.isReachable {
            session.sendMessage(response, replyHandler: { reply in
                print("[HealthManager] 💊 ✅ iPhone received medication response: \(reply)")
                DispatchQueue.main.async {
                    self.dismissCurrentReminder()
                }
            }, errorHandler: { error in
                print("[HealthManager] 💊 ⚠️ Failed to send response: \(error.localizedDescription)")
                // Queue for later delivery
                self.bufferMedicationResponse(reminderId: reminderId, medicationId: medicationId, action: action, scheduledTime: scheduledTime, takenAt: takenAt)
                DispatchQueue.main.async {
                    self.dismissCurrentReminder()
                }
            })
        } else {
            print("[HealthManager] 💊 iPhone not reachable - buffering response")
            bufferMedicationResponse(reminderId: reminderId, medicationId: medicationId, action: action, scheduledTime: scheduledTime, takenAt: takenAt)
            dismissCurrentReminder()
        }
    }

    /// Buffer medication response for later delivery
    private func bufferMedicationResponse(reminderId: String, medicationId: String, action: String, scheduledTime: Date, takenAt: Date?) {
        var response: [String: Any] = [
            "type": "medication_reminder_response",
            "reminder_id": reminderId,
            "medication_id": medicationId,
            "action": action,
            "scheduled_time": ISO8601DateFormatter().string(from: scheduledTime),
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "source": "apple_watch",
            "transfer_id": UUID().uuidString
        ]

        if let takenAt = takenAt {
            response["taken_at"] = ISO8601DateFormatter().string(from: takenAt)
        }

        wcSession?.transferUserInfo(response)
        print("[HealthManager] 💊 Medication response queued via transferUserInfo")
    }

    /// Dismiss current reminder and show next queued one
    private func dismissCurrentReminder() {
        DispatchQueue.main.async {
            self.showMedicationReminderAlert = false
            self.currentMedicationReminder = nil

            // Show next queued reminder if any
            if !self.pendingMedicationReminders.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let nextReminder = self.pendingMedicationReminders.removeFirst()
                    self.currentMedicationReminder = nextReminder
                    self.showMedicationReminderAlert = true
                    WKInterfaceDevice.current().play(.notification)
                }
            }
        }
    }

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
    private let pendingVitalsKey = "com.kindura.pendingVitals"  // UserDefaults key

    // MARK: - Pending Fall Alerts Buffer (CRITICAL - must never lose fall alerts)
    private var pendingFallAlerts: [[String: Any]] = []
    private let maxPendingFallAlerts = 50  // Keep all recent falls
    private let pendingFallAlertsKey = "com.kindura.pendingFallAlerts"

    // MARK: - Send Vitals to iPhone (via WatchConnectivity ONLY)
    func sendVitalsToiPhone() {
        let vitalsData = createVitalsPayload()

        // Debug: Print vital values summary
        if DEBUG_MODE {
            print("[HealthManager] 📊 DEBUG Vitals Summary:")
            print("  HR: \(Int(heartRate)) BPM | O2: \(Int(bloodOxygen))% | HRV: \(Int(hrv)) ms | RR: \(Int(respiratoryRate)) br/m")
            print("  Steps: \(steps) | Cal: \(Int(calories)) | Dist: \(String(format: "%.1f", distanceKm)) km | Floors: \(floorsClimbed)")
            print("  Exercise: \(exerciseMinutes) min | Stand: \(standMinutes) min | Sleep: \(String(format: "%.1f", totalSleepHours)) h")
            print("  Pending Buffer: \(pendingVitals.count) | Outstanding Transfers: \(outstandingTransfers.count)")
        }

        guard let session = wcSession, session.activationState == .activated else {
            print("[HealthManager] ⚠️ WCSession not activated - buffering vitals")
            if DEBUG_MODE { print("[HealthManager] 📊 Session state: \(wcSession?.activationState.rawValue ?? -1)") }
            bufferVitals(vitalsData)
            return
        }

        guard session.isReachable else {
            print("[HealthManager] 📵 iPhone not reachable - buffering vitals")
            if DEBUG_MODE { print("[HealthManager] 📊 Will use transferUserInfo for guaranteed delivery") }
            bufferVitals(vitalsData)
            return
        }

        // Send current vitals to iPhone
        if DEBUG_MODE { print("[HealthManager] 📤 Sending vitals via sendMessage (real-time)...") }
        session.sendMessage(vitalsData, replyHandler: { [weak self] response in
            print("[HealthManager] ✅ Vitals sent to iPhone: \(response["status"] ?? "ok")")
            // After successful send, try to send any buffered vitals
            self?.sendBufferedVitals()
        }, errorHandler: { [weak self] error in
            print("[HealthManager] ❌ Failed to send to iPhone: \(error.localizedDescription)")
            if self?.DEBUG_MODE == true { print("[HealthManager] 📊 Falling back to buffer + transferUserInfo") }
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

        // Persist to UserDefaults
        savePendingVitals()

        // Also queue via transferUserInfo for guaranteed delivery
        sendVitalsViaTransferUserInfo(vitals)

        print("[HealthManager] Buffered vitals (total pending: \(pendingVitals.count))")
    }

    // MARK: - Persistent Buffer Storage
    private func savePendingVitals() {
        do {
            let data = try JSONSerialization.data(withJSONObject: pendingVitals, options: [])
            UserDefaults.standard.set(data, forKey: pendingVitalsKey)
            print("[HealthManager] 💾 Saved \(pendingVitals.count) pending vitals to storage")
        } catch {
            print("[HealthManager] ❌ Failed to save pending vitals: \(error)")
        }
    }

    private func loadPendingVitals() {
        guard let data = UserDefaults.standard.data(forKey: pendingVitalsKey) else {
            print("[HealthManager] No pending vitals in storage")
            return
        }

        do {
            if let vitals = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                pendingVitals = vitals
                print("[HealthManager] 📂 Loaded \(pendingVitals.count) pending vitals from storage")
            }
        } catch {
            print("[HealthManager] ❌ Failed to load pending vitals: \(error)")
        }
    }

    private func clearPendingVitalsStorage() {
        UserDefaults.standard.removeObject(forKey: pendingVitalsKey)
        print("[HealthManager] 🗑️ Cleared pending vitals storage")
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

        // Track success/failure for storage cleanup
        let dispatchGroup = DispatchGroup()
        var failedVitals: [[String: Any]] = []
        let failedVitalsLock = NSLock()

        for vitals in vitalsToSend {
            dispatchGroup.enter()
            session.sendMessage(vitals, replyHandler: { response in
                print("[HealthManager] ✅ Buffered vital sent: \(response)")
                dispatchGroup.leave()
            }, errorHandler: { error in
                print("[HealthManager] ❌ Failed to send buffered vital: \(error)")
                // Track failed vitals for re-buffering
                failedVitalsLock.lock()
                failedVitals.append(vitals)
                failedVitalsLock.unlock()
                dispatchGroup.leave()
            })

            // Small delay between sends to avoid overwhelming
            Thread.sleep(forTimeInterval: 0.1)
        }

        // Handle completion - update storage based on results
        dispatchGroup.notify(queue: .main) { [weak self] in
            if failedVitals.isEmpty {
                // All sends succeeded - clear persistent storage
                self?.clearPendingVitalsStorage()
                print("[HealthManager] ✅ All buffered vitals sent, storage cleared")
            } else {
                // Some failed - re-buffer and save to storage
                self?.pendingVitals = failedVitals
                self?.savePendingVitals()
                print("[HealthManager] ⚠️ \(failedVitals.count) vitals re-buffered and saved")
            }
        }
    }

    // MARK: - Fall Alert Buffer Management (CRITICAL)
    private func bufferFallAlert(_ fallData: [String: Any]) {
        pendingFallAlerts.append(fallData)

        // Trim old entries if over limit (keep most recent)
        if pendingFallAlerts.count > maxPendingFallAlerts {
            pendingFallAlerts.removeFirst(pendingFallAlerts.count - maxPendingFallAlerts)
        }

        // Persist to storage - fall alerts are critical
        savePendingFallAlerts()
        print("[HealthManager] 🚨 Buffered fall alert (total pending: \(pendingFallAlerts.count))")
    }

    private func savePendingFallAlerts() {
        do {
            let data = try JSONSerialization.data(withJSONObject: pendingFallAlerts, options: [])
            UserDefaults.standard.set(data, forKey: pendingFallAlertsKey)
            print("[HealthManager] 💾 Saved \(pendingFallAlerts.count) pending fall alerts to storage")
        } catch {
            print("[HealthManager] ❌ Failed to save pending fall alerts: \(error)")
        }
    }

    private func loadPendingFallAlerts() {
        guard let data = UserDefaults.standard.data(forKey: pendingFallAlertsKey) else {
            print("[HealthManager] No pending fall alerts in storage")
            return
        }

        do {
            if let alerts = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                pendingFallAlerts = alerts
                print("[HealthManager] 📂 Loaded \(pendingFallAlerts.count) pending fall alerts from storage")
            }
        } catch {
            print("[HealthManager] ❌ Failed to load pending fall alerts: \(error)")
        }
    }

    private func clearPendingFallAlertsStorage() {
        UserDefaults.standard.removeObject(forKey: pendingFallAlertsKey)
        print("[HealthManager] 🗑️ Cleared pending fall alerts storage")
    }

    private func sendBufferedFallAlerts() {
        guard !pendingFallAlerts.isEmpty else { return }
        guard let session = wcSession, session.activationState == .activated else {
            print("[HealthManager] Cannot send buffered fall alerts - session not activated")
            return
        }

        print("[HealthManager] 🚨📤 Sending \(pendingFallAlerts.count) buffered fall alerts")

        let alertsToSend = pendingFallAlerts
        pendingFallAlerts.removeAll()

        for alert in alertsToSend {
            var transferData = alert
            transferData["transfer_id"] = UUID().uuidString
            transferData["transfer_timestamp"] = Date().timeIntervalSince1970
            transferData["priority"] = "high"
            transferData["was_buffered"] = true

            let transfer = session.transferUserInfo(transferData)
            outstandingTransfers.append(transfer)
            print("[HealthManager] 🚨📬 Sent buffered fall alert via transferUserInfo")
        }

        clearPendingFallAlertsStorage()
        cleanupCompletedTransfers()
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

    // MARK: - Guaranteed Delivery via transferUserInfo
    /// Use transferUserInfo for guaranteed delivery of important data
    /// Data is queued and delivered when iPhone becomes available
    private func sendVitalsViaTransferUserInfo(_ vitals: [String: Any]? = nil) {
        guard let session = wcSession, session.activationState == .activated else {
            print("[HealthManager] Cannot use transferUserInfo - session not activated")
            return
        }

        let vitalsData = vitals ?? createVitalsPayload()

        // Add unique transfer ID to prevent duplicates
        var transferData = vitalsData
        transferData["transfer_id"] = UUID().uuidString
        transferData["transfer_timestamp"] = Date().timeIntervalSince1970

        let transfer = session.transferUserInfo(transferData)
        print("[HealthManager] 📬 Queued vitals via transferUserInfo (ID: \(transferData["transfer_id"] ?? "unknown"))")

        // Track outstanding transfers
        outstandingTransfers.append(transfer)
        cleanupCompletedTransfers()
    }

    /// Send fall alert with guaranteed delivery - NEVER drop fall alerts
    private func sendFallAlertViaTransferUserInfo(fallData: [String: Any]) {
        guard let session = wcSession, session.activationState == .activated else {
            // CRITICAL: Don't lose fall alerts - buffer for later
            print("[HealthManager] 🚨 Session not activated - buffering fall alert for later delivery")
            bufferFallAlert(fallData)
            return
        }

        var transferData = fallData
        transferData["transfer_id"] = UUID().uuidString
        transferData["transfer_timestamp"] = Date().timeIntervalSince1970
        transferData["priority"] = "high"

        let transfer = session.transferUserInfo(transferData)
        print("[HealthManager] 🚨📬 Queued FALL ALERT via transferUserInfo (guaranteed delivery)")

        outstandingTransfers.append(transfer)
        cleanupCompletedTransfers()
    }

    // Track outstanding transfers
    private var outstandingTransfers: [WCSessionUserInfoTransfer] = []

    private func cleanupCompletedTransfers() {
        outstandingTransfers.removeAll { $0.isTransferring == false }
        if !outstandingTransfers.isEmpty {
            print("[HealthManager] 📊 Outstanding transfers: \(outstandingTransfers.count)")
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
            // Vitals
            "heart_rate": heartRate,
            "blood_oxygen": bloodOxygen,
            "hrv": hrv,
            "respiratory_rate": respiratoryRate,
            // Sleep
            "total_sleep_hours": totalSleepHours,
            "deep_sleep_hours": deepSleep,
            "rem_sleep_hours": remSleep,
            "core_sleep_hours": coreSleep,
            "awake_time_hours": awakeTime,
            "awakenings_count": awakeningsCount,
            "sleep_quality": calculateSleepQuality(),
            // Falls
            "falls_count": recentFalls.count,
            "fall_detected": !recentFalls.isEmpty,
            // Activity
            "steps": steps,
            "calories": Int(calories),
            "distance_km": distanceKm,
            "floors_climbed": floorsClimbed,
            "exercise_minutes": exerciseMinutes,
            "stand_minutes": standMinutes
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
            // Vitals
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
            // Sleep
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            // Falls
            HKObjectType.quantityType(forIdentifier: .numberOfTimesFallen)!,
            // Activity
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .flightsClimbed)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.quantityType(forIdentifier: .appleStandTime)!,
        ]

        // Types to write - falls detected by CoreMotion need to be saved to HealthKit
        let typesToShare: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .numberOfTimesFallen)!,
        ]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                self.isHealthKitAuthorized = success

                if success {
                    print("[HealthManager] ✅ HealthKit authorization granted")
                    self.startObservingHealth()
                    self.fetchLatestVitals()
                    self.fetchSleepData()
                    self.fetchFallData()
                    self.fetchActivityData()  // Fetch activity data
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
        var activityRefreshCounter = 0
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.fetchLatestVitals()

            // Refresh activity data every 60 seconds (12 cycles)
            activityRefreshCounter += 1
            if activityRefreshCounter >= 12 {
                self?.fetchActivityData()
                activityRefreshCounter = 0
            }

            // Always send current vitals to iPhone every 5 seconds for real-time sync
            self?.sendVitalsToiPhone()
        }

        // Send initial vitals immediately
        fetchActivityData()
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

        // Fall Observer - catches Apple's native fall detection AND our own falls written to HealthKit
        if let fallType = HKObjectType.quantityType(forIdentifier: .numberOfTimesFallen) {
            fallObserverQuery = HKObserverQuery(sampleType: fallType, predicate: nil) { [weak self] _, completionHandler, error in
                if let error = error {
                    print("[HealthManager] ❌ Fall observer error: \(error.localizedDescription)")
                    completionHandler()
                    return
                }

                print("[HealthManager] 🚨 HealthKit fall observer triggered - fetching new fall data")
                self?.fetchFallData()

                // Also notify iPhone about the new fall
                DispatchQueue.main.async {
                    self?.handleHealthKitFallDetected()
                }

                completionHandler()
            }

            if let query = fallObserverQuery {
                healthStore.execute(query)
                print("[HealthManager] ✅ Fall observer query started - monitoring for Apple native + Kindura falls")
            }
        }

        // Enable background delivery
        healthStore.enableBackgroundDelivery(for: HKObjectType.quantityType(forIdentifier: .heartRate)!, frequency: .immediate) { _, _ in }
        healthStore.enableBackgroundDelivery(for: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!, frequency: .hourly) { _, _ in }

        // Enable background delivery for falls - immediate notification when Apple detects a fall
        if let fallType = HKObjectType.quantityType(forIdentifier: .numberOfTimesFallen) {
            healthStore.enableBackgroundDelivery(for: fallType, frequency: .immediate) { success, error in
                if success {
                    print("[HealthManager] ✅ Background delivery enabled for falls")
                } else if let error = error {
                    print("[HealthManager] ❌ Failed to enable background delivery for falls: \(error.localizedDescription)")
                }
            }
        }

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

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
            guard let samples = samples as? [HKCategorySample] else { return }

            // Filter to prioritize Apple Watch/HealthKit native data
            var watchSamples: [HKCategorySample] = []
            var otherSamples: [HKCategorySample] = []

            for sample in samples {
                let sourceName = sample.sourceRevision.source.name.lowercased()
                let bundleId = sample.sourceRevision.source.bundleIdentifier.lowercased()

                // Check if sample is from Apple Watch or Apple's native sleep tracking
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

            // Use Apple Watch samples if available, otherwise fall back to other sources
            let samplesToUse = !watchSamples.isEmpty ? watchSamples : otherSamples
            print("[HealthManager] 😴 Using \(samplesToUse.count) samples (Watch: \(watchSamples.count), Other: \(otherSamples.count))")

            // Deduplicate overlapping samples
            let deduplicatedSamples = self?.deduplicateSleepSamples(samplesToUse) ?? samplesToUse
            print("[HealthManager] 😴 After deduplication: \(deduplicatedSamples.count) samples")

            var totalSleep: Double = 0
            var deepSleep: Double = 0
            var remSleep: Double = 0
            var coreSleep: Double = 0
            var awakeSleep: Double = 0

            for sample in deduplicatedSamples {
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

            print("[HealthManager] 😴 Final sleep: \(String(format: "%.2f", totalSleep))h (Deep: \(String(format: "%.2f", deepSleep))h, REM: \(String(format: "%.2f", remSleep))h, Core: \(String(format: "%.2f", coreSleep))h)")

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

    // MARK: - Fall Detection (HealthKit Sync)

    /// Fetches fall data from HealthKit - includes BOTH Apple's native fall detection AND our CoreMotion detections
    func fetchFallData() {
        guard let fallType = HKQuantityType.quantityType(forIdentifier: .numberOfTimesFallen) else {
            print("[HealthManager] ❌ numberOfTimesFallen type not available")
            return
        }

        print("[HealthManager] 🔍 Fetching fall data from HealthKit...")

        // Get falls from last 30 days
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: thirtyDaysAgo, end: now, options: .strictEndDate)

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: fallType, predicate: predicate, limit: 50, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
            if let error = error {
                print("[HealthManager] ❌ Error fetching falls from HealthKit: \(error.localizedDescription)")
                return
            }

            guard let samples = samples as? [HKQuantitySample] else {
                print("[HealthManager] ⚠️ No fall samples found in HealthKit (last 30 days)")
                return
            }

            print("[HealthManager] 📊 Found \(samples.count) fall(s) in HealthKit")

            // Log details of each fall sample
            for (index, sample) in samples.enumerated() {
                let source = sample.sourceRevision.source.name
                let bundleId = sample.sourceRevision.source.bundleIdentifier
                let metadata = sample.metadata ?? [:]
                let fallSource = metadata["com.kindura.fallSource"] as? String ?? "Apple/Unknown"

                print("[HealthManager] 🚨 Fall \(index + 1): date=\(sample.startDate), source=\(source), bundleId=\(bundleId), fallSource=\(fallSource)")
            }

            // Convert samples to FallEvents
            let falls = samples.map { sample -> FallEvent in
                // Try to extract severity from metadata (if we wrote it)
                let metadata = sample.metadata ?? [:]
                let severityFromMeta = metadata["com.kindura.severity"] as? String
                let impactGFromMeta = metadata["com.kindura.impactG"] as? Double

                // Determine if this is an Apple native fall or our detection
                let source = sample.sourceRevision.source.bundleIdentifier
                let isAppleNative = !source.contains("kindura")

                return FallEvent(
                    date: sample.startDate,
                    resolved: true,
                    severity: severityFromMeta ?? (isAppleNative ? "apple_native" : "unknown"),
                    impactG: impactGFromMeta ?? 0.0
                )
            }

            DispatchQueue.main.async {
                let previousCount = self?.recentFalls.count ?? 0
                self?.recentFalls = falls
                print("[HealthManager] ✅ Updated recentFalls: \(previousCount) → \(falls.count) falls")
            }
        }

        healthStore.execute(query)
    }

    /// Called when HealthKit observer detects a new fall - could be Apple native or our CoreMotion detection
    private func handleHealthKitFallDetected() {
        print("[HealthManager] 🚨 HealthKit fall detected - querying for latest fall...")

        guard let fallType = HKQuantityType.quantityType(forIdentifier: .numberOfTimesFallen) else { return }

        // Get only the most recent fall
        let now = Date()
        let fiveMinutesAgo = now.addingTimeInterval(-300)  // Last 5 minutes
        let predicate = HKQuery.predicateForSamples(withStart: fiveMinutesAgo, end: now, options: .strictEndDate)

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: fallType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
            guard let sample = (samples as? [HKQuantitySample])?.first else {
                print("[HealthManager] ⚠️ No recent fall found in HealthKit")
                return
            }

            let source = sample.sourceRevision.source.bundleIdentifier
            let isAppleNative = !source.contains("kindura")

            print("[HealthManager] 🚨 Latest fall: date=\(sample.startDate), isAppleNative=\(isAppleNative), source=\(source)")

            // If this is an Apple native fall detection (not from our app), send alert to iPhone
            if isAppleNative {
                print("[HealthManager] 📱 Apple native fall detected - sending alert to iPhone")

                // Create a FallEvent and send alert
                let fallEvent = FallEvent(
                    date: sample.startDate,
                    resolved: false,  // Needs user response
                    severity: "apple_native",
                    impactG: 0.0  // Apple doesn't expose impact force
                )

                DispatchQueue.main.async {
                    // Add to recent falls if not already present
                    if !(self?.recentFalls.contains(where: { abs($0.date.timeIntervalSince(fallEvent.date)) < 1 }) ?? false) {
                        self?.recentFalls.insert(fallEvent, at: 0)
                    }

                    // Send fall alert to iPhone
                    self?.sendFallAlertToiPhone(fallEvent: fallEvent)
                }
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Activity Data
    func fetchActivityData() {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        if DEBUG_MODE { print("[HealthManager] 🏃 DEBUG: Fetching activity data for today...") }

        // Track completion for debug logging
        var completedFetches = 0
        let totalFetches = 6

        // Fetch Steps
        fetchTodaySum(for: .stepCount, unit: HKUnit.count(), predicate: predicate) { [weak self] value in
            DispatchQueue.main.async {
                self?.steps = Int(value)
                completedFetches += 1
                if self?.DEBUG_MODE == true && completedFetches == totalFetches {
                    self?.logActivitySummary()
                }
            }
        }

        // Fetch Active Calories
        fetchTodaySum(for: .activeEnergyBurned, unit: HKUnit.kilocalorie(), predicate: predicate) { [weak self] value in
            DispatchQueue.main.async {
                self?.calories = value
                completedFetches += 1
            }
        }

        // Fetch Distance (walking + running)
        fetchTodaySum(for: .distanceWalkingRunning, unit: HKUnit.meterUnit(with: .kilo), predicate: predicate) { [weak self] value in
            DispatchQueue.main.async {
                self?.distanceKm = value
                completedFetches += 1
            }
        }

        // Fetch Floors Climbed
        fetchTodaySum(for: .flightsClimbed, unit: HKUnit.count(), predicate: predicate) { [weak self] value in
            DispatchQueue.main.async {
                self?.floorsClimbed = Int(value)
                completedFetches += 1
            }
        }

        // Fetch Exercise Minutes
        fetchTodaySum(for: .appleExerciseTime, unit: HKUnit.minute(), predicate: predicate) { [weak self] value in
            DispatchQueue.main.async {
                self?.exerciseMinutes = Int(value)
                completedFetches += 1
            }
        }

        // Fetch Stand Minutes
        fetchTodaySum(for: .appleStandTime, unit: HKUnit.minute(), predicate: predicate) { [weak self] value in
            DispatchQueue.main.async {
                self?.standMinutes = Int(value)
                completedFetches += 1
                if self?.DEBUG_MODE == true && completedFetches == totalFetches {
                    self?.logActivitySummary()
                }
            }
        }

        print("[HealthManager] 🏃 Activity data fetch initiated")
    }

    /// Log activity summary for debugging
    private func logActivitySummary() {
        print("[HealthManager] 🏃 DEBUG Activity Summary:")
        print("  Steps: \(steps) | Calories: \(Int(calories)) kcal")
        print("  Distance: \(String(format: "%.2f", distanceKm)) km | Floors: \(floorsClimbed)")
        print("  Exercise: \(exerciseMinutes) min | Stand: \(standMinutes) min")
    }

    private func fetchTodaySum(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, predicate: NSPredicate, completion: @escaping (Double) -> Void) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            completion(0)
            return
        }

        let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                print("[HealthManager] Error fetching \(identifier): \(error.localizedDescription)")
                completion(0)
                return
            }

            let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
            completion(value)
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
                if DEBUG_MODE { print("[HealthManager] 🔻 Free fall phase started G=\(String(format: "%.2f", totalG))") }
            }
        } else {
            // Phase 2: Detect impact after free fall
            if isInFreeFall, let fallStart = freeFallStartTime {
                let fallDuration = Date().timeIntervalSince(fallStart)

                // Only consider it a real fall if free-fall duration was significant
                // This filters out micro-dips from quick arm movements
                if fallDuration >= minFreeFallDuration && fallDuration < fallConfirmationWindow {
                    // If we had a real free fall phase and now see high impact
                    if totalG > impactThreshold {
                        // FALL DETECTED!
                        print("[HealthManager] ⚠️ FALL DETECTED! Impact=\(String(format: "%.2f", totalG))G, FreeFall=\(String(format: "%.2f", fallDuration))s")

                        // Determine severity based on impact force
                        let severity: String
                        if totalG > 10.0 {
                            severity = "high"
                        } else if totalG > 6.0 {
                            severity = "medium"
                        } else {
                            severity = "low"
                        }

                        // Record the fall
                        handleFallDetected(impactG: totalG, severity: severity)
                    }
                } else if DEBUG_MODE && fallDuration < minFreeFallDuration {
                    print("[HealthManager] 📊 Ignored micro-dip: duration=\(String(format: "%.3f", fallDuration))s < \(minFreeFallDuration)s")
                }

                // Reset free fall state
                isInFreeFall = false
                freeFallStartTime = nil
            }

            // Impact-only detection (slip and fall without free-fall phase)
            // Using much higher threshold to avoid false positives from arm movements
            if totalG > impactOnlyThreshold {
                let now = Date()
                if let lastImpact = lastHighImpactTime {
                    // Avoid duplicate detections within 5 seconds
                    if now.timeIntervalSince(lastImpact) > 5.0 {
                        print("[HealthManager] ⚠️ SEVERE IMPACT DETECTED! G=\(String(format: "%.2f", totalG)) (threshold: \(impactOnlyThreshold))")
                        handleFallDetected(impactG: totalG, severity: totalG > 15.0 ? "high" : "medium")
                        lastHighImpactTime = now
                    }
                } else {
                    print("[HealthManager] ⚠️ SEVERE IMPACT DETECTED! G=\(String(format: "%.2f", totalG)) (threshold: \(impactOnlyThreshold))")
                    handleFallDetected(impactG: totalG, severity: totalG > 15.0 ? "high" : "medium")
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

        // IMPORTANT: Write fall to HealthKit so iPhone can read it
        saveFallToHealthKit(date: fallEvent.date)

        // Send fall alert to iPhone immediately
        sendFallAlertToiPhone(fallEvent: fallEvent)

        // Also send vitals update with fall info
        sendVitalsToiPhone()

        // Reset status after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.fallDetectionStatus = "Active - Monitoring"
        }
    }

    /// Save detected fall to HealthKit so iPhone can read it via HealthKit queries
    private func saveFallToHealthKit(date: Date) {
        guard let fallType = HKQuantityType.quantityType(forIdentifier: .numberOfTimesFallen) else {
            print("[HealthManager] ❌ Fall quantity type not available")
            return
        }

        // Check if we have write authorization
        let authStatus = healthStore.authorizationStatus(for: fallType)
        guard authStatus == .sharingAuthorized else {
            print("[HealthManager] ⚠️ Not authorized to write falls to HealthKit (status: \(authStatus.rawValue))")
            return
        }

        // Create a fall sample (1 fall event)
        let fallQuantity = HKQuantity(unit: HKUnit.count(), doubleValue: 1.0)
        let fallSample = HKQuantitySample(
            type: fallType,
            quantity: fallQuantity,
            start: date,
            end: date,
            metadata: [
                HKMetadataKeyWasUserEntered: false,
                "com.kindura.fallSource": "CoreMotion"
            ]
        )

        // Save to HealthKit
        healthStore.save(fallSample) { success, error in
            if success {
                print("[HealthManager] ✅ Fall saved to HealthKit successfully")
            } else if let error = error {
                print("[HealthManager] ❌ Failed to save fall to HealthKit: \(error.localizedDescription)")
            }
        }
    }

    /// Send fall alert to iPhone via WatchConnectivity - NEVER lose fall alerts
    private func sendFallAlertToiPhone(fallEvent: FallEvent) {
        // Create fallData FIRST - before any guards that might return
        // Include falls_count so iPhone can display cumulative count immediately
        let fallData: [String: Any] = [
            "type": "fall_alert",
            "timestamp": ISO8601DateFormatter().string(from: fallEvent.date),
            "severity": fallEvent.severity,
            "impact_g": fallEvent.impactG,
            "heart_rate": heartRate,
            "blood_oxygen": bloodOxygen,
            "requires_response": true,
            "falls_count": recentFalls.count,  // Cumulative falls count for iPhone display
            "fall_detected": true               // Explicit fall detected flag
        ]

        // ALWAYS queue via transferUserInfo for guaranteed delivery
        // Fall alerts are CRITICAL and must NEVER be lost
        // sendFallAlertViaTransferUserInfo will buffer if session not activated
        sendFallAlertViaTransferUserInfo(fallData: fallData)

        // Try real-time delivery if session is available
        guard let session = wcSession, session.activationState == .activated else {
            print("[HealthManager] 🚨 Fall alert buffered - WCSession not activated")
            return
        }

        if session.isReachable {
            // Also try real-time delivery for immediate response
            session.sendMessage(fallData, replyHandler: { response in
                print("[HealthManager] ✅ Fall alert sent to iPhone (real-time): \(response)")
            }, errorHandler: { error in
                print("[HealthManager] ⚠️ Real-time fall alert failed (queued via transferUserInfo): \(error.localizedDescription)")
                // Also update application context for latest state
                try? session.updateApplicationContext(fallData)
            })
        } else {
            // iPhone not reachable - transferUserInfo already queued above
            // Also update application context so iPhone gets it when app opens
            do {
                try session.updateApplicationContext(fallData)
                print("[HealthManager] Fall alert context updated (transferUserInfo queued)")
            } catch {
                print("[HealthManager] Context update failed, but transferUserInfo is queued: \(error)")
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
