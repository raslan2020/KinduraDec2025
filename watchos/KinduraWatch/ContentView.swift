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
                .padding(.bottom, 8)

                // Status
                VStack(spacing: 8) {
                    Image(systemName: healthManager.isFallDetectionEnabled ? "checkmark.shield.fill" : "shield.slash.fill")
                        .font(.system(size: 40))
                        .foregroundColor(healthManager.isFallDetectionEnabled ? .green : .gray)

                    Text(healthManager.isFallDetectionEnabled ? "Active" : "Disabled")
                        .font(.headline)

                    Text("Continuous monitoring")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(12)

                // Recent Falls
                if healthManager.recentFalls.count > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Events")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ForEach(healthManager.recentFalls, id: \.date) { fall in
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                VStack(alignment: .leading) {
                                    Text(fall.dateString)
                                        .font(.caption2)
                                    Text(fall.resolved ? "Resolved" : "Pending")
                                        .font(.caption2)
                                        .foregroundColor(fall.resolved ? .green : .orange)
                                }
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
                } else {
                    Text("No falls detected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                }

                // Emergency Contact
                Button(action: {
                    // TODO: Send emergency alert to caregiver
                }) {
                    HStack {
                        Image(systemName: "phone.fill")
                        Text("Alert Caregiver")
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            .padding()
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
