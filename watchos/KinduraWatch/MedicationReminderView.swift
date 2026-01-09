import SwiftUI
import WatchKit

struct MedicationReminderView: View {
    @EnvironmentObject var healthManager: HealthManager
    let reminder: MedicationReminder

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header with icon
                HStack {
                    Image(systemName: "pills.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                    Text(reminder.isFollowUp ? "Reminder" : "Medication Time")
                        .font(.headline)
                }
                .padding(.top, 8)

                // Medication info
                VStack(spacing: 6) {
                    Text(reminder.medicationName)
                        .font(.system(size: 18, weight: .bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(reminder.dosage)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: formIcon(reminder.form))
                            .font(.caption2)
                        Text(reminder.form)
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)

                    // Scheduled time
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(reminder.timeString)
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                }
                .padding(.vertical, 8)

                // Instructions (if any)
                if !reminder.instructions.isEmpty {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text(reminder.instructions)
                            .font(.caption2)
                            .foregroundColor(.yellow)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(8)
                }

                // Urgency indicator for follow-ups
                if reminder.isFollowUp && reminder.followUpNumber >= 2 {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Please take now")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding(.vertical, 4)
                }

                // Action buttons
                VStack(spacing: 10) {
                    // Take Now button (primary)
                    Button(action: { handleTakeNow() }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Take Now")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())

                    HStack(spacing: 10) {
                        // Snooze button
                        Button(action: { handleSnooze() }) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption)
                                Text("15m")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.3))
                            .foregroundColor(.orange)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Skip button
                        Button(action: { handleSkip() }) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                    .font(.caption)
                                Text("Skip")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.3))
                            .foregroundColor(.gray)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.top, 8)
            }
            .padding()
        }
    }

    private func handleTakeNow() {
        WKInterfaceDevice.current().play(.success)
        healthManager.sendMedicationReminderResponse(
            reminderId: reminder.id,
            medicationId: reminder.medicationId,
            action: "taken",
            scheduledTime: reminder.scheduledTime,
            takenAt: Date()
        )
    }

    private func handleSnooze() {
        WKInterfaceDevice.current().play(.click)
        healthManager.sendMedicationReminderResponse(
            reminderId: reminder.id,
            medicationId: reminder.medicationId,
            action: "snoozed",
            scheduledTime: reminder.scheduledTime
        )
    }

    private func handleSkip() {
        WKInterfaceDevice.current().play(.click)
        healthManager.sendMedicationReminderResponse(
            reminderId: reminder.id,
            medicationId: reminder.medicationId,
            action: "skipped",
            scheduledTime: reminder.scheduledTime
        )
    }

    /// Get icon for medication form
    private func formIcon(_ form: String) -> String {
        switch form.lowercased() {
        case "tablet", "pill":
            return "pills"
        case "capsule":
            return "capsule"
        case "liquid", "syrup":
            return "drop.fill"
        case "injection":
            return "syringe"
        case "inhaler":
            return "wind"
        case "cream", "ointment", "gel":
            return "bandage"
        case "patch":
            return "square.fill"
        case "drops":
            return "drop"
        default:
            return "pills"
        }
    }
}

#Preview {
    let previewReminder = MedicationReminder(from: [
        "reminder_id": "test-123",
        "medication_id": "med-456",
        "medication_name": "Metformin",
        "dosage": "500 mg",
        "form": "tablet",
        "scheduled_time": ISO8601DateFormatter().string(from: Date()),
        "instructions": "Take with food",
        "is_follow_up": false,
        "follow_up_number": 0,
        "requires_escalation": false
    ])

    return MedicationReminderView(reminder: previewReminder)
        .environmentObject(HealthManager())
}
