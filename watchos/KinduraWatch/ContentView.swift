import SwiftUI
import HealthKit

struct ContentView: View {
    @EnvironmentObject var healthManager: HealthManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Vitals Tab
            VitalsView()
                .tag(0)

            // Sleep Tab
            SleepView()
                .tag(1)

            // Fall Detection Tab
            FallDetectionView()
                .tag(2)

            // Settings Tab
            SettingsView()
                .tag(3)
        }
        .tabViewStyle(.page)
        .onAppear {
            healthManager.requestAuthorization()
        }
    }
}

// MARK: - Vitals View
struct VitalsView: View {
    @EnvironmentObject var healthManager: HealthManager

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    Text("Vitals")
                        .font(.headline)
                }
                .padding(.bottom, 8)

                // Heart Rate
                VitalCard(
                    icon: "heart.fill",
                    iconColor: .red,
                    title: "Heart Rate",
                    value: healthManager.heartRate > 0 ? "\(Int(healthManager.heartRate))" : "--",
                    unit: "BPM"
                )

                // Blood Oxygen
                VitalCard(
                    icon: "lungs.fill",
                    iconColor: .blue,
                    title: "Blood Oxygen",
                    value: healthManager.bloodOxygen > 0 ? "\(Int(healthManager.bloodOxygen))" : "--",
                    unit: "%"
                )

                // HRV
                VitalCard(
                    icon: "waveform.path.ecg",
                    iconColor: .green,
                    title: "HRV",
                    value: healthManager.hrv > 0 ? "\(Int(healthManager.hrv))" : "--",
                    unit: "ms"
                )

                // Respiratory Rate
                VitalCard(
                    icon: "wind",
                    iconColor: .cyan,
                    title: "Resp. Rate",
                    value: healthManager.respiratoryRate > 0 ? "\(Int(healthManager.respiratoryRate))" : "--",
                    unit: "/min"
                )
            }
            .padding()
        }
    }
}

// MARK: - Sleep View
struct SleepView: View {
    @EnvironmentObject var healthManager: HealthManager

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "moon.fill")
                        .foregroundColor(.purple)
                    Text("Sleep")
                        .font(.headline)
                }
                .padding(.bottom, 8)

                // Total Sleep
                VStack(spacing: 4) {
                    Text("Last Night")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if healthManager.totalSleepHours > 0 {
                        Text(String(format: "%.1fh", healthManager.totalSleepHours))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.purple)
                    } else {
                        Text("--")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.purple.opacity(0.2))
                .cornerRadius(12)

                // Sleep Stages
                if healthManager.sleepStages.count > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(healthManager.sleepStages, id: \.stage) { stage in
                            HStack {
                                Circle()
                                    .fill(stage.color)
                                    .frame(width: 8, height: 8)
                                Text(stage.stage)
                                    .font(.caption)
                                Spacer()
                                Text(String(format: "%.1fh", stage.hours))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
                }

                // Monitoring Status
                HStack {
                    Image(systemName: healthManager.isSleepMonitoringActive ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(healthManager.isSleepMonitoringActive ? .green : .red)
                    Text(healthManager.isSleepMonitoringActive ? "Monitoring" : "Not Active")
                        .font(.caption)
                }
                .padding(.top, 8)
            }
            .padding()
        }
    }
}

// MARK: - Fall Detection View
struct FallDetectionView: View {
    @EnvironmentObject var healthManager: HealthManager

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "figure.fall")
                        .foregroundColor(.orange)
                    Text("Fall Detection")
                        .font(.headline)
                }
                .padding(.bottom, 4)

                // Real-time G-Force Display
                VStack(spacing: 4) {
                    Text("Current G-Force")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f G", healthManager.lastImpactG))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(gForceColor(healthManager.lastImpactG))
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.3))
                .cornerRadius(10)

                // Status
                VStack(spacing: 6) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 30))
                        .foregroundColor(statusColor)

                    Text(healthManager.fallDetectionStatus)
                        .font(.caption)
                        .foregroundColor(statusColor)
                        .multilineTextAlignment(.center)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(statusColor.opacity(0.2))
                .cornerRadius(12)

                // Recent Falls
                if healthManager.recentFalls.count > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Recent Events (\(healthManager.recentFalls.count))")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ForEach(healthManager.recentFalls.prefix(5), id: \.date) { fall in
                            HStack {
                                Image(systemName: severityIcon(fall.severity))
                                    .foregroundColor(severityColor(fall.severity))
                                    .font(.caption)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fall.dateString)
                                        .font(.caption2)
                                    HStack(spacing: 4) {
                                        Text(String(format: "%.1fG", fall.impactG))
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                        Text("•")
                                            .foregroundColor(.gray)
                                        Text(fall.severity.capitalized)
                                            .font(.caption2)
                                            .foregroundColor(severityColor(fall.severity))
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
                } else {
                    Text("No falls detected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(8)
                }

                // Emergency Contact
                Button(action: {
                    healthManager.sendEmergencyAlert()
                }) {
                    HStack {
                        Image(systemName: "sos")
                        Text("Send SOS")
                    }
                    .font(.caption)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            .padding()
        }
    }

    // MARK: - Helper Properties

    private var statusIcon: String {
        if healthManager.fallDetectionStatus.contains("Fall detected") || healthManager.fallDetectionStatus.contains("Emergency") {
            return "exclamationmark.triangle.fill"
        } else if healthManager.fallDetectionStatus.contains("Active") || healthManager.fallDetectionStatus.contains("Monitoring") {
            return "checkmark.shield.fill"
        } else {
            return "shield.slash.fill"
        }
    }

    private var statusColor: Color {
        if healthManager.fallDetectionStatus.contains("Fall detected") || healthManager.fallDetectionStatus.contains("Emergency") {
            return .red
        } else if healthManager.fallDetectionStatus.contains("Active") || healthManager.fallDetectionStatus.contains("Monitoring") {
            return .green
        } else {
            return .gray
        }
    }

    private func gForceColor(_ g: Double) -> Color {
        if g < 1.0 {
            return .green
        } else if g < 2.0 {
            return .yellow
        } else if g < 3.0 {
            return .orange
        } else {
            return .red
        }
    }

    private func severityIcon(_ severity: String) -> String {
        switch severity {
        case "high": return "exclamationmark.octagon.fill"
        case "medium": return "exclamationmark.triangle.fill"
        default: return "exclamationmark.circle.fill"
        }
    }

    private func severityColor(_ severity: String) -> Color {
        switch severity {
        case "high": return .red
        case "medium": return .orange
        default: return .yellow
        }
    }
}

// MARK: - Vital Card Component
struct VitalCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let unit: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 18, weight: .bold))
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(8)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
}

#Preview {
    ContentView()
        .environmentObject(HealthManager())
}
