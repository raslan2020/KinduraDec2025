import 'package:flutter/material.dart';
import 'package:kindura_ai/models/medication/medication_models.dart';
import 'package:kindura_ai/screens/medication/medication_controller.dart';
import 'package:get/get.dart';
import 'dart:async';

class NotificationService extends GetxService {
  // In-memory storage for scheduled reminders (would be replaced with local notifications)
  final Map<String, Timer> _scheduledTimers = {};
  final Map<String, List<DateTime>> _medicationSchedules = {};

  @override
  Future<void> onInit() async {
    super.onInit();
    print('🔔 Notification Service initialized');
  }

  @override
  void onClose() {
    // Cancel all timers
    for (final timer in _scheduledTimers.values) {
      timer.cancel();
    }
    _scheduledTimers.clear();
    super.onClose();
  }

  // Schedule reminders for a medication
  Future<void> scheduleRemindersForMedication(Medication medication) async {
    if (!medication.schedule.reminderEnabled || !medication.isActive) {
      return;
    }

    print('📅 Scheduling reminders for ${medication.displayName}');

    // Cancel existing reminders first
    await cancelRemindersForMedication(medication.id);

    final scheduledTimes = <DateTime>[];

    // Schedule for next 7 days
    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final date = DateTime.now().add(Duration(days: dayOffset));
      
      // Check if medication should be taken on this day
      if (!_shouldTakeOnDay(medication, date)) {
        continue;
      }

      for (final timeStr in medication.schedule.times) {
        final timeParts = timeStr.split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);

        final scheduledDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          hour,
          minute,
        );

        // Skip if time has already passed
        if (scheduledDateTime.isBefore(DateTime.now())) {
          continue;
        }

        scheduledTimes.add(scheduledDateTime);

        // Schedule primary reminder
        _scheduleReminder(
          medication,
          scheduledDateTime,
          isFollowUp: false,
        );

        // Schedule first follow-up (+10 minutes)
        _scheduleReminder(
          medication,
          scheduledDateTime.add(Duration(minutes: 10)),
          isFollowUp: true,
          followUpNumber: 1,
        );

        // Schedule second follow-up (+20 minutes) with caregiver escalation
        _scheduleReminder(
          medication,
          scheduledDateTime.add(Duration(minutes: 20)),
          isFollowUp: true,
          followUpNumber: 2,
          escalateToCaregiver: medication.schedule.caregiverEscalationEnabled,
        );
      }
    }

    _medicationSchedules[medication.id] = scheduledTimes;
    print('✅ Scheduled ${scheduledTimes.length} reminders for ${medication.displayName}');
  }

  void _scheduleReminder(
    Medication medication,
    DateTime scheduledTime, {
    required bool isFollowUp,
    int? followUpNumber,
    bool escalateToCaregiver = false,
  }) {
    final now = DateTime.now();
    final difference = scheduledTime.difference(now);

    if (difference.isNegative) {
      return; // Don't schedule past reminders
    }

    final timerId = '${medication.id}_${scheduledTime.millisecondsSinceEpoch}_${followUpNumber ?? 0}';

    final timer = Timer(difference, () {
      _showMedicationReminder(
        medication,
        scheduledTime,
        isFollowUp: isFollowUp,
        followUpNumber: followUpNumber,
        escalateToCaregiver: escalateToCaregiver,
      );
    });

    _scheduledTimers[timerId] = timer;
  }

  void _showMedicationReminder(
    Medication medication,
    DateTime scheduledTime, {
    required bool isFollowUp,
    int? followUpNumber,
    bool escalateToCaregiver = false,
  }) {
    String title;
    String message;

    if (isFollowUp) {
      if (followUpNumber == 1) {
        title = 'Gentle Reminder';
        message = 'Don\'t forget your ${medication.displayName} (${medication.strengthDisplay})';
      } else {
        title = 'Important Reminder';
        message = 'Please take your ${medication.displayName} now';
        if (escalateToCaregiver) {
          message += '\nCaregiver will be notified if not taken soon.';
        }
      }
    } else {
      title = 'Medication Time';
      message = 'Time to take ${medication.displayName} (${medication.strengthDisplay})';
      if (medication.takeWithFood == true) {
        message += '\nTake with food';
      } else if (medication.takeWithFood == false) {
        message += '\nTake on empty stomach';
      }
    }

    // Show in-app notification dialog
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.medication,
              color: isFollowUp && followUpNumber == 2 ? Colors.red : Colors.blue,
            ),
            SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (medication.instructionsText.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(
                'Instructions: ${medication.instructionsText}',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              _handleSkipDose(medication, scheduledTime);
            },
            child: Text('Skip'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              _handleSnoozeDose(medication, scheduledTime);
            },
            child: Text('Snooze 15m'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _handleTakeDose(medication, scheduledTime);
            },
            child: Text('Take Now'),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    // Play notification sound (would be replaced with actual notification sound)
    print('🔔 Medication reminder: ${medication.displayName} at ${scheduledTime.toIso8601String()}');

    // Schedule caregiver notification if needed
    if (escalateToCaregiver && medication.schedule.caregiverContactId != null) {
      Timer(Duration(minutes: 2), () {
        _showCaregiverNotification(medication, scheduledTime);
      });
    }
  }

  void _showCaregiverNotification(Medication medication, DateTime scheduledTime) {
    print('👨‍⚕️ Caregiver alert: Patient may have missed ${medication.displayName}');
    
    // In a real implementation, this would send notifications to caregiver's device
    // For now, just log it
  }

  void _handleTakeDose(Medication medication, DateTime scheduledTime) {
    final medicationController = Get.find<MedicationController>();
    medicationController.recordDoseTaken(
      medicationId: medication.id,
      scheduledAt: scheduledTime,
      method: 'notification',
    );
  }

  void _handleSkipDose(Medication medication, DateTime scheduledTime) {
    final medicationController = Get.find<MedicationController>();
    medicationController.recordDoseSkipped(
      medicationId: medication.id,
      scheduledAt: scheduledTime,
      reason: 'Skipped from notification',
    );
  }

  void _handleSnoozeDose(Medication medication, DateTime scheduledTime) {
    // Schedule a snooze reminder in 15 minutes
    final snoozeTime = DateTime.now().add(Duration(minutes: 15));
    
    _scheduleReminder(
      medication,
      snoozeTime,
      isFollowUp: true,
      followUpNumber: 0,
    );

    Get.snackbar(
      'Reminder Snoozed',
      'You\'ll be reminded again in 15 minutes',
      snackPosition: SnackPosition.BOTTOM,
      duration: Duration(seconds: 3),
    );
  }

  Future<void> scheduleSnoozeNotification(
    MedicationReminder reminder,
    int snoozeMinutes,
  ) async {
    final medicationController = Get.find<MedicationController>();
    final medication = medicationController.medications
        .firstWhereOrNull((m) => m.id == reminder.medicationId);

    if (medication == null) return;

    final snoozeTime = DateTime.now().add(Duration(minutes: snoozeMinutes));

    _scheduleReminder(
      medication,
      snoozeTime,
      isFollowUp: true,
      followUpNumber: 0,
    );

    print('⏰ Snoozed reminder for ${medication.displayName} by $snoozeMinutes minutes');
  }

  Future<void> cancelRemindersForMedication(String medicationId) async {
    // Cancel all timers related to this medication
    final timersToCancel = _scheduledTimers.keys
        .where((key) => key.startsWith('${medicationId}_'))
        .toList();

    for (final timerId in timersToCancel) {
      _scheduledTimers[timerId]?.cancel();
      _scheduledTimers.remove(timerId);
    }

    _medicationSchedules.remove(medicationId);
    print('🚫 Cancelled reminders for medication: $medicationId');
  }

  Future<void> cancelAllReminders() async {
    for (final timer in _scheduledTimers.values) {
      timer.cancel();
    }
    _scheduledTimers.clear();
    _medicationSchedules.clear();
    print('🚫 Cancelled all medication reminders');
  }

  bool _shouldTakeOnDay(Medication medication, DateTime date) {
    if (medication.schedule.days == null) {
      return true; // Daily medication
    }

    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = dayNames[date.weekday - 1];
    
    return medication.schedule.days!.contains(dayName);
  }

  // Get next scheduled reminder for a medication
  DateTime? getNextReminderTime(String medicationId) {
    final scheduledTimes = _medicationSchedules[medicationId];
    if (scheduledTimes == null || scheduledTimes.isEmpty) {
      return null;
    }

    final now = DateTime.now();
    final futureTimes = scheduledTimes.where((time) => time.isAfter(now)).toList();
    
    if (futureTimes.isEmpty) {
      return null;
    }

    futureTimes.sort();
    return futureTimes.first;
  }

  // Get count of active reminders
  int getActiveReminderCount() {
    return _scheduledTimers.length;
  }

  // Get list of all scheduled medication times for today
  List<Map<String, dynamic>> getTodaySchedule() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(Duration(days: 1));

    final todaySchedule = <Map<String, dynamic>>[];

    for (final entry in _medicationSchedules.entries) {
      final medicationId = entry.key;
      final times = entry.value;

      final medicationController = Get.find<MedicationController>();
      final medication = medicationController.medications
          .firstWhereOrNull((m) => m.id == medicationId);

      if (medication == null) continue;

      final todayTimes = times
          .where((time) => time.isAfter(todayStart) && time.isBefore(todayEnd))
          .toList();

      for (final time in todayTimes) {
        todaySchedule.add({
          'medication': medication,
          'scheduled_time': time,
          'is_overdue': time.isBefore(DateTime.now()),
        });
      }
    }

    // Sort by time
    todaySchedule.sort((a, b) => 
        (a['scheduled_time'] as DateTime).compareTo(b['scheduled_time'] as DateTime));

    return todaySchedule;
  }
}