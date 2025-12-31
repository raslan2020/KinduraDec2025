import SwiftUI

@main
struct KinduraWatchApp: App {
    @StateObject private var healthManager = HealthManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthManager)
                .onAppear {
                    // Auto-start continuous health monitoring when app launches
                    // This enables real-time HR sync without manual workout activation
                    healthManager.requestAuthorization { success in
                        if success {
                            print("[KinduraWatchApp] ✅ HealthKit authorized - starting continuous monitoring")
                            // Start background workout session for continuous HR
                            healthManager.startWorkoutSession()
                            // Also start real-time monitoring queries
                            healthManager.startRealTimeMonitoring()
                            // Start fall detection
                            healthManager.startFallDetection()
                        } else {
                            print("[KinduraWatchApp] ❌ HealthKit authorization failed")
                        }
                    }
                }
        }
    }
}
