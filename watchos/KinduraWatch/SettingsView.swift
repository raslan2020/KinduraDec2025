import SwiftUI
import HealthKit

struct SettingsView: View {
    @EnvironmentObject var healthManager: HealthManager
    @State private var isAuthorizing = false
    @State private var authorizationStatus: String = "Not Checked"
    @State private var showingAuthResult = false
    @State private var authResultMessage = ""
    @State private var configStatus: String = "Checking..."

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.gray)
                    Text("Settings")
                        .font(.headline)
                }
                .padding(.bottom, 8)

                // API Configuration Status
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: ConfigurationManager.shared.isConfigured ? "checkmark.icloud.fill" : "xmark.icloud.fill")
                            .foregroundColor(ConfigurationManager.shared.isConfigured ? .green : .red)
                        Text("Backend Connection")
                            .font(.caption)
                        Spacer()
                    }

                    if ConfigurationManager.shared.isConfigured {
                        Text("✅ Connected to server")
                            .font(.caption2)
                            .foregroundColor(.green)
                    } else {
                        Text("❌ Not configured - open iPhone app")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }

                    Button(action: {
                        healthManager.requestConfigurationFromiPhone()
                        configStatus = "Requesting..."
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            configStatus = ConfigurationManager.shared.isConfigured ? "Connected" : "Not configured"
                        }
                    }) {
                        Text("Request Config from iPhone")
                            .font(.caption2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.3))
                            .foregroundColor(.blue)
                            .cornerRadius(6)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)

                // HealthKit Authorization Section
                VStack(spacing: 12) {
                    Text("Health Data Access")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Authorization Button
                    Button(action: {
                        requestHealthKitAccess()
                    }) {
                        HStack {
                            if isAuthorizing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "heart.text.square.fill")
                            }
                            Text(isAuthorizing ? "Requesting..." : "Allow Health Data")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isAuthorizing)

                    // Status
                    HStack {
                        Circle()
                            .fill(healthManager.isHealthKitAuthorized ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(healthManager.isHealthKitAuthorized ? "Access Granted" : "Tap to Enable")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)

                // Health Data Types Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Data Types")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HealthDataRow(icon: "heart.fill", color: .red, name: "Heart Rate", enabled: healthManager.heartRate > 0)
                    HealthDataRow(icon: "lungs.fill", color: .blue, name: "Blood Oxygen", enabled: healthManager.bloodOxygen > 0)
                    HealthDataRow(icon: "waveform.path.ecg", color: .green, name: "HRV", enabled: healthManager.hrv > 0)
                    HealthDataRow(icon: "wind", color: .cyan, name: "Respiratory", enabled: healthManager.respiratoryRate > 0)
                    HealthDataRow(icon: "moon.fill", color: .purple, name: "Sleep", enabled: healthManager.totalSleepHours > 0)
                    HealthDataRow(icon: "figure.fall", color: .orange, name: "Fall Detection", enabled: healthManager.isFallDetectionEnabled)
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)

                // Workout Session Section (For Real-time Heart Rate)
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: healthManager.isWorkoutActive ? "heart.circle.fill" : "heart.circle")
                            .foregroundColor(healthManager.isWorkoutActive ? .red : .gray)
                        Text("Live Vitals Session")
                            .font(.caption)
                        Spacer()
                    }

                    Text(healthManager.workoutStatus)
                        .font(.caption2)
                        .foregroundColor(healthManager.isWorkoutActive ? .green : .secondary)

                    Button(action: {
                        if healthManager.isWorkoutActive {
                            healthManager.stopWorkoutSession()
                        } else {
                            healthManager.startWorkoutSession()
                        }
                    }) {
                        HStack {
                            Image(systemName: healthManager.isWorkoutActive ? "stop.circle.fill" : "play.circle.fill")
                            Text(healthManager.isWorkoutActive ? "Stop Session" : "Start Session")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(healthManager.isWorkoutActive ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }

                    Text("⚠️ Required for real-time heart rate")
                        .font(.system(size: 9))
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)

                // Background Monitoring Section
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: healthManager.isRealTimeMonitoring ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                            .foregroundColor(healthManager.isRealTimeMonitoring ? .green : .gray)
                        Text("Background Queries")
                            .font(.caption)
                        Spacer()
                        Text(healthManager.isRealTimeMonitoring ? "ON" : "OFF")
                            .font(.caption2)
                            .foregroundColor(healthManager.isRealTimeMonitoring ? .green : .secondary)
                    }

                    Button(action: {
                        if healthManager.isRealTimeMonitoring {
                            healthManager.stopRealTimeMonitoring()
                        } else {
                            healthManager.startRealTimeMonitoring()
                        }
                    }) {
                        Text(healthManager.isRealTimeMonitoring ? "Stop Queries" : "Start Queries")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(healthManager.isRealTimeMonitoring ? Color.red.opacity(0.8) : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)

                // Refresh Button
                Button(action: {
                    healthManager.fetchLatestVitals()
                    healthManager.fetchSleepData()
                    healthManager.fetchFallData()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh Data")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.3))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }

                // Version info
                Text("Kindura Watch v1.0")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
            .padding()
        }
        .alert("Health Access", isPresented: $showingAuthResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(authResultMessage)
        }
    }

    private func requestHealthKitAccess() {
        isAuthorizing = true
        healthManager.requestAuthorization { success in
            DispatchQueue.main.async {
                isAuthorizing = false
                if success {
                    authResultMessage = "Health data access granted! Your vitals will now be displayed."
                } else {
                    authResultMessage = "Please enable health access in Settings > Health > Apps > Kindura"
                }
                showingAuthResult = true
            }
        }
    }
}

struct HealthDataRow: View {
    let icon: String
    let color: Color
    let name: String
    let enabled: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            Text(name)
                .font(.caption2)
            Spacer()
            Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(enabled ? .green : .gray)
                .font(.caption)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(HealthManager())
}
