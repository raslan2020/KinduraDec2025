import Foundation
import WatchConnectivity

/// Manages API configuration received from iPhone app via App Groups
/// Stores API base URL and authentication token for Watch-to-backend communication
class ConfigurationManager: ObservableObject {
    static let shared = ConfigurationManager()

    private let appGroupIdentifier = "group.com.kindura.ai"
    private var sharedDefaults: UserDefaults?

    // MARK: - Published Properties
    @Published var apiBaseURL: String = ""
    @Published var authToken: String = ""
    @Published var isConfigured: Bool = false

    // MARK: - Keys
    private let apiBaseURLKey = "api_base_url"
    private let authTokenKey = "auth_token"
    private let pendingVitalsKey = "pending_vitals"

    // MARK: - Initialization
    private init() {
        // Try App Groups first, fall back to standard UserDefaults
        if let groupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            sharedDefaults = groupDefaults
            print("[ConfigurationManager] Using App Groups storage")
        } else {
            sharedDefaults = UserDefaults.standard
            print("[ConfigurationManager] App Groups not available, using standard UserDefaults")
        }
        loadConfiguration()
    }

    // MARK: - Configuration Management

    /// Load configuration from App Groups shared storage
    func loadConfiguration() {
        guard let defaults = sharedDefaults else {
            print("[ConfigurationManager] Failed to access App Group defaults")
            return
        }

        apiBaseURL = defaults.string(forKey: apiBaseURLKey) ?? ""
        authToken = defaults.string(forKey: authTokenKey) ?? ""
        isConfigured = !apiBaseURL.isEmpty && !authToken.isEmpty

        if isConfigured {
            print("[ConfigurationManager] Configuration loaded - Base URL: \(apiBaseURL)")
        } else {
            print("[ConfigurationManager] No configuration found - waiting for iPhone sync")
        }
    }

    /// Update configuration with values received from iPhone
    func updateConfiguration(baseURL: String, token: String) {
        guard let defaults = sharedDefaults else {
            print("[ConfigurationManager] Failed to access App Group defaults")
            return
        }

        defaults.set(baseURL, forKey: apiBaseURLKey)
        defaults.set(token, forKey: authTokenKey)
        defaults.synchronize()

        apiBaseURL = baseURL
        authToken = token
        isConfigured = !baseURL.isEmpty && !token.isEmpty

        print("[ConfigurationManager] Configuration updated - Base URL: \(baseURL)")
    }

    /// Clear stored configuration (for logout/reset)
    func clearConfiguration() {
        guard let defaults = sharedDefaults else { return }

        defaults.removeObject(forKey: apiBaseURLKey)
        defaults.removeObject(forKey: authTokenKey)
        defaults.synchronize()

        apiBaseURL = ""
        authToken = ""
        isConfigured = false

        print("[ConfigurationManager] Configuration cleared")
    }

    // MARK: - API Endpoint Helpers

    /// Get the full URL for watch vitals endpoint
    func getVitalsEndpoint() -> URL? {
        guard isConfigured else {
            print("[ConfigurationManager] Cannot get vitals endpoint - not configured")
            return nil
        }

        let urlString = "\(apiBaseURL)/watch-vitals/"
        return URL(string: urlString)
    }

    /// Get authorization header value
    func getAuthorizationHeader() -> String {
        return "Token \(authToken)"
    }

    // MARK: - Offline Vitals Storage

    /// Store vitals locally when offline or not configured
    func storePendingVitals(_ vitals: [String: Any]) {
        guard let defaults = sharedDefaults else { return }

        var pending = defaults.array(forKey: pendingVitalsKey) as? [[String: Any]] ?? []
        pending.append(vitals)

        // Keep only last 100 entries to prevent memory issues
        if pending.count > 100 {
            pending = Array(pending.suffix(100))
        }

        defaults.set(pending, forKey: pendingVitalsKey)
        defaults.synchronize()

        print("[ConfigurationManager] Stored pending vitals - total: \(pending.count)")
    }

    /// Retrieve and clear pending vitals for sync
    func retrievePendingVitals() -> [[String: Any]] {
        guard let defaults = sharedDefaults else { return [] }

        let pending = defaults.array(forKey: pendingVitalsKey) as? [[String: Any]] ?? []

        if !pending.isEmpty {
            defaults.removeObject(forKey: pendingVitalsKey)
            defaults.synchronize()
            print("[ConfigurationManager] Retrieved \(pending.count) pending vitals for sync")
        }

        return pending
    }

    /// Check if there are pending vitals to sync
    var hasPendingVitals: Bool {
        guard let defaults = sharedDefaults else { return false }
        let pending = defaults.array(forKey: pendingVitalsKey) as? [[String: Any]] ?? []
        return !pending.isEmpty
    }

    /// Count of pending vitals
    var pendingVitalsCount: Int {
        guard let defaults = sharedDefaults else { return 0 }
        let pending = defaults.array(forKey: pendingVitalsKey) as? [[String: Any]] ?? []
        return pending.count
    }
}
