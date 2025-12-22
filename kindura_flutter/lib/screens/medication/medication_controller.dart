import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:kindura_ai/repository/medication_repository/medication_repository.dart';
import 'package:kindura_ai/models/medication/medication_models.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/utils/app_toast.dart';
import 'package:kindura_ai/services/notification_service.dart';
import 'package:kindura_ai/services/voice_service.dart';
import 'dart:async';

class MedicationController extends GetxController {
  final MedicationRepository _repository = MedicationRepository();
  final NotificationService _notificationService = Get.find<NotificationService>();
  final VoiceService _voiceService = Get.find<VoiceService>();

  // Observable states
  var requestStatus = Status.COMPLETED.obs;
  var uploadStatus = Status.COMPLETED.obs;

  // Data observables
  var medications = <Medication>[].obs;
  var activeReminders = <MedicationReminder>[].obs;
  var recentDoseEvents = <DoseEvent>[].obs;
  var adherenceSummary = Rxn<Map<String, dynamic>>();
  var interactions = <MedicationInteraction>[].obs;
  var caregivers = <CaregiverContact>[].obs;

  // UI state
  var selectedMedication = Rxn<Medication>();
  var showInactiveOnly = false.obs;
  var searchQuery = ''.obs;
  var currentAdherencePeriod = AdherencePeriod.sevenDays.obs;

  // Voice integration
  var isListeningForVoiceCommand = false.obs;
  var lastVoiceCommand = ''.obs;

  // Form controllers and state for add/edit medication
  late TextEditingController drugNameController;
  late TextEditingController brandNameController;
  late TextEditingController strengthController;
  late TextEditingController instructionsController;
  late FocusNode drugNameFocusNode;
  late FocusNode brandNameFocusNode;
  late FocusNode strengthFocusNode;
  late FocusNode instructionsFocusNode;
  
  var strengthUnit = ''.obs;
  var medicationForm = ''.obs;
  var medicationRoute = ''.obs;
  var takeWithFood = Rxn<bool>();
  var asNeeded = false.obs;
  var scheduleTimes = <String>[].obs;
  var selectedDays = <String>[].obs;
  var isDailySchedule = true.obs;
  var remindersEnabled = true.obs;
  var caregiverEscalationEnabled = false.obs;
  var missedDoseAction = 'no_policy'.obs;
  var dosesPerDay = 1.obs;

  // Timer for periodic reminder checks
  Timer? _reminderCheckTimer;
  Timer? _adherenceUpdateTimer;

  @override
  void onInit() {
    super.onInit();
    _initializeControllers();
    _initializeMedicationSystem();
  }

  @override
  void onClose() {
    _reminderCheckTimer?.cancel();
    _adherenceUpdateTimer?.cancel();
    super.onClose();
  }

  // Initialization
  void _initializeControllers() {
    drugNameController = TextEditingController();
    brandNameController = TextEditingController();
    strengthController = TextEditingController();
    instructionsController = TextEditingController();
    drugNameFocusNode = FocusNode();
    brandNameFocusNode = FocusNode();
    strengthFocusNode = FocusNode();
    instructionsFocusNode = FocusNode();
  }

  Future<void> _initializeMedicationSystem() async {
    // Initialize analytics with default values
    medicationAnalytics.value = {
      'todayTaken': 0,
      'todayMissed': 0,
      'todaySkipped': 0,
      'todayPending': 0,
      'adherenceRate': 0.0,
    };

    // Load medications without blocking
    loadMedications().catchError((e) {
      print("Error loading medications: $e");
    });

    // Load other data in background without blocking
    loadActiveReminders().catchError((e) {
      print("Error loading reminders: $e");
    });

    loadAdherenceSummary().catchError((e) {
      print("Error loading adherence: $e");
    });

    loadCaregiverContacts().catchError((e) {
      print("Error loading caregivers: $e");
    });

    checkMedicationInteractions().catchError((e) {
      print("Error checking interactions: $e");
    });

    _startPeriodicUpdates();
    _setupVoiceListening();
  }

  void _startPeriodicUpdates() {
    // Check for reminders every minute
    _reminderCheckTimer = Timer.periodic(Duration(minutes: 1), (_) {
      _checkForDueReminders();
    });

    // Update adherence data every 30 minutes
    _adherenceUpdateTimer = Timer.periodic(Duration(minutes: 30), (_) {
      loadAdherenceSummary();
    });
  }

  void _setupVoiceListening() {
    _voiceService.addMedicationVoiceHandler(_handleVoiceCommand);
  }

  // Core Data Loading Methods

  Future<void> loadMedications({bool forceRefresh = false}) async {
    if (!forceRefresh && medications.isNotEmpty) return;

    requestStatus.value = Status.LOADING;
    
    try {
      final response = await _repository.getMedications(
        activeOnly: !showInactiveOnly.value,
        search: searchQuery.value.isNotEmpty ? searchQuery.value : null,
      );

      response.when(
        success: (medicationsList) {
          medications.value = medicationsList;
          requestStatus.value = Status.COMPLETED;
        },
        error: (error) {
          requestStatus.value = Status.ERROR;
          // Don't show error toast if it's just an empty list
          if (!error.toString().contains('404')) {
            AppToast.showError('Failed to load medications: $error');
          }
          // Initialize with empty list on 404
          medications.value = [];
        },
        loading: () {
          requestStatus.value = Status.LOADING;
        },
      );
    } catch (e) {
      requestStatus.value = Status.ERROR;
      AppToast.showError('Error loading medications');
    }
  }

  Future<void> loadActiveReminders() async {
    try {
      final response = await _repository.getActiveReminders();
      response.when(
        success: (reminders) => activeReminders.value = reminders,
        error: (error) => print('Failed to load reminders: $error'),
        loading: () => print('Loading reminders...'),
      );
    } catch (e) {
      print('Error loading reminders: $e');
    }
  }

  Future<void> loadAdherenceSummary() async {
    try {
      final response = await _repository.getAdherenceSummary(currentAdherencePeriod.value);
      response.when(
        success: (summary) {
          adherenceSummary.value = summary;
          // Also update medicationAnalytics for home screen display
          medicationAnalytics.value = {
            'todayTaken': summary['todayTaken'] ?? 0,
            'todayMissed': summary['todayMissed'] ?? summary['missed_doses'] ?? 0,
            'todaySkipped': 0,
            'todayPending': summary['todayPending'] ?? 0,
            'adherenceRate': summary['adherence_percentage'] ?? 0.0,
          };
          print('📊 Adherence updated: taken=${summary['todayTaken']}, pending=${summary['todayPending']}, missed=${summary['todayMissed']}');
        },
        error: (error) => print('Failed to load adherence summary: $error'),
        loading: () => print('Loading adherence summary...'),
      );
    } catch (e) {
      print('Error loading adherence summary: $e');
    }
  }

  Future<void> loadCaregiverContacts() async {
    try {
      final response = await _repository.getCaregiverContacts();
      response.when(
        success: (contacts) => caregivers.value = contacts,
        error: (error) => print('Failed to load caregivers: $error'),
        loading: () => print('Loading caregivers...'),
      );
    } catch (e) {
      print('Error loading caregivers: $e');
    }
  }

  Future<void> checkMedicationInteractions() async {
    try {
      final response = await _repository.checkInteractions();
      response.when(
        success: (interactionsList) {
          interactions.value = interactionsList;
          
          // Show critical interactions immediately
          final criticalInteractions = interactionsList
              .where((i) => i.isCritical)
              .toList();
          
          if (criticalInteractions.isNotEmpty) {
            _showCriticalInteractionAlert(criticalInteractions);
          }
        },
        error: (error) => print('Failed to check interactions: $error'),
        loading: () => print('Checking medication interactions...'),
      );
    } catch (e) {
      print('Error checking interactions: $e');
    }
  }

  // Medication CRUD Operations

  Future<void> createMedication(Medication medication) async {
    uploadStatus.value = Status.LOADING;
    
    try {
      final response = await _repository.createMedication(medication);
      
      response.when(
        success: (createdMedication) {
          medications.add(createdMedication);
          uploadStatus.value = Status.COMPLETED;
          AppToast.showSuccess('Medication added successfully');
          
          // Schedule reminders for the new medication
          _scheduleRemindersForMedication(createdMedication);
          
          // Check for new interactions
          checkMedicationInteractions();
        },
        error: (error) {
          uploadStatus.value = Status.ERROR;
          AppToast.showError('Failed to add medication: $error');
        },
        loading: () {
          uploadStatus.value = Status.LOADING;
        },
      );
    } catch (e) {
      uploadStatus.value = Status.ERROR;
      AppToast.showError('Error adding medication');
    }
  }

  Future<void> updateMedication(String medicationId, Medication medication) async {
    uploadStatus.value = Status.LOADING;
    
    try {
      final response = await _repository.updateMedication(medicationId, medication);
      
      response.when(
        success: (updatedMedication) {
          final index = medications.indexWhere((m) => m.id == medicationId);
          if (index != -1) {
            medications[index] = updatedMedication;
          }
          
          uploadStatus.value = Status.COMPLETED;
          AppToast.showSuccess('Medication updated successfully');
          
          // Reschedule reminders
          _rescheduleRemindersForMedication(updatedMedication);
          
          // Recheck interactions
          checkMedicationInteractions();
        },
        error: (error) {
          uploadStatus.value = Status.ERROR;
          AppToast.showError('Failed to update medication: $error');
        },
        loading: () {
          uploadStatus.value = Status.LOADING;
        },
      );
    } catch (e) {
      uploadStatus.value = Status.ERROR;
      AppToast.showError('Error updating medication');
    }
  }

  Future<void> deleteMedication(String medicationId, String reason) async {
    try {
      final response = await _repository.deleteMedication(medicationId, reason);

      response.when(
        success: (_) {
          print('🗑️ Removing medication $medicationId from list of ${medications.length} items');
          final beforeCount = medications.length;
          // Compare as strings to handle both int and string IDs
          medications.removeWhere((m) => m.id.toString() == medicationId.toString());
          final afterCount = medications.length;
          print('🗑️ Removed ${beforeCount - afterCount} items, now ${afterCount} items');

          AppToast.showSuccess('Medication removed');

          // Cancel reminders for this medication
          _cancelRemindersForMedication(medicationId);

          // Update today's counts
          loadAdherenceSummary();
        },
        error: (error) {
          AppToast.showError('Failed to remove medication: $error');
        },
        loading: () => print('Deleting medication...'),
      );
    } catch (e) {
      AppToast.showError('Error removing medication');
    }
  }

  // Dose Event Management

  Future<void> recordDoseTaken({
    required String medicationId,
    required DateTime scheduledAt,
    DateTime? takenAt,
    String? notes,
    String? sideEffectNote,
    String method = 'tap',
  }) async {
    try {
      final response = await _repository.recordDoseTaken(
        medicationId: medicationId,
        scheduledAt: scheduledAt,
        takenAt: takenAt ?? DateTime.now(),
        notes: notes,
        sideEffectNote: sideEffectNote,
        method: method,
      );

      response.when(
        success: (doseEvent) {
          recentDoseEvents.insert(0, doseEvent);
          AppToast.showSuccess('Dose recorded');
          
          // Update adherence immediately
          loadAdherenceSummary();
          
          // Acknowledge related reminder
          _acknowledgeRelatedReminder(medicationId, scheduledAt);
          
          // Check for side effects
          if (sideEffectNote != null && sideEffectNote.isNotEmpty) {
            _promptForDetailedSideEffectReport(medicationId, doseEvent.id);
          }
        },
        error: (error) {
          AppToast.showError('Failed to record dose: $error');
        },
        loading: () => print('Recording dose...'),
      );
    } catch (e) {
      AppToast.showError('Error recording dose');
    }
  }

  Future<void> recordDoseMissed({
    required String medicationId,
    required DateTime scheduledAt,
    String? reason,
  }) async {
    try {
      final response = await _repository.recordDoseMissed(
        medicationId: medicationId,
        scheduledAt: scheduledAt,
        reason: reason,
      );

      response.when(
        success: (doseEvent) {
          recentDoseEvents.insert(0, doseEvent);
          AppToast.showWarning('Dose marked as missed');
          loadAdherenceSummary();
        },
        error: (error) {
          AppToast.showError('Failed to record missed dose: $error');
        },
        loading: () => print('Recording missed dose...'),
      );
    } catch (e) {
      AppToast.showError('Error recording missed dose');
    }
  }

  Future<void> recordDoseSkipped({
    required String medicationId,
    required DateTime scheduledAt,
    String? reason,
  }) async {
    try {
      final response = await _repository.recordDoseSkipped(
        medicationId: medicationId,
        scheduledAt: scheduledAt,
        reason: reason,
      );

      response.when(
        success: (doseEvent) {
          recentDoseEvents.insert(0, doseEvent);
          AppToast.showInfo('Dose skipped');
          loadAdherenceSummary();
        },
        error: (error) {
          AppToast.showError('Failed to record skipped dose: $error');
        },
        loading: () => print('Recording skipped dose...'),
      );
    } catch (e) {
      AppToast.showError('Error recording skipped dose');
    }
  }

  // Reminder Management

  Future<void> snoozeReminder(String reminderId, int minutes) async {
    try {
      final response = await _repository.snoozeReminder(reminderId, minutes);
      
      response.when(
        success: (reminder) {
          final index = activeReminders.indexWhere((r) => r.id == reminderId);
          if (index != -1) {
            activeReminders[index] = reminder;
          }
          
          AppToast.showInfo('Reminder snoozed for $minutes minutes');
          
          // Schedule local notification for snoozed reminder
          _scheduleSnoozeNotification(reminder, minutes);
        },
        error: (error) {
          AppToast.showError('Failed to snooze reminder: $error');
        },
        loading: () => print('Snoozing reminder...'),
      );
    } catch (e) {
      AppToast.showError('Error snoozing reminder');
    }
  }

  Future<void> acknowledgeReminder(String reminderId) async {
    try {
      final response = await _repository.acknowledgeReminder(reminderId);
      
      response.when(
        success: (_) {
          activeReminders.removeWhere((r) => r.id == reminderId);
        },
        error: (error) {
          AppToast.showError('Failed to acknowledge reminder: $error');
        },
        loading: () => print('Acknowledging reminder...'),
      );
    } catch (e) {
      AppToast.showError('Error acknowledging reminder');
    }
  }

  // Voice Integration

  void startVoiceListening() {
    isListeningForVoiceCommand.value = true;
    _voiceService.startListeningForMedicationCommands();
  }

  void stopVoiceListening() {
    isListeningForVoiceCommand.value = false;
    _voiceService.stopListening();
  }

  Future<void> _handleVoiceCommand(String command, double confidence) async {
    lastVoiceCommand.value = command;
    
    if (confidence < 0.6) {
      AppToast.showWarning('Voice command unclear, please try again');
      return;
    }

    try {
      final response = await _repository.processVoiceCommand(
        audioText: command,
        confidence: confidence,
      );

      response.when(
        success: (result) {
          _executeVoiceCommandResult(result);
        },
        error: (error) {
          AppToast.showError('Could not process voice command');
        },
        loading: () => print('Processing voice command...'),
      );
    } catch (e) {
      AppToast.showError('Error processing voice command');
    }
  }

  void _executeVoiceCommandResult(Map<String, dynamic> result) {
    final intent = result['intent'] as String?;
    final parameters = result['parameters'] as Map<String, dynamic>? ?? {};

    switch (intent) {
      case 'take_medication':
        _handleTakeMedicationVoiceCommand(parameters);
        break;
      case 'skip_medication':
        _handleSkipMedicationVoiceCommand(parameters);
        break;
      case 'snooze_reminder':
        _handleSnoozeReminderVoiceCommand(parameters);
        break;
      case 'next_dose':
        _handleNextDoseVoiceCommand();
        break;
      default:
        AppToast.showInfo('Voice command not recognized');
    }
  }

  Future<void> _handleTakeMedicationVoiceCommand(Map<String, dynamic> params) async {
    final medicationName = params['medication_name'] as String?;
    final timeStr = params['time'] as String?;
    
    if (medicationName == null) {
      AppToast.showError('Could not identify medication name');
      return;
    }

    // Find medication by name
    final medication = medications.firstWhereOrNull((m) => 
        m.displayName.toLowerCase().contains(medicationName.toLowerCase()));
    
    if (medication == null) {
      AppToast.showError('Medication "$medicationName" not found');
      return;
    }

    // Determine scheduled time
    DateTime scheduledTime;
    if (timeStr != null) {
      // Parse time from voice command
      scheduledTime = _parseTimeFromVoice(timeStr);
    } else {
      // Use current time
      scheduledTime = DateTime.now();
    }

    await recordDoseTaken(
      medicationId: medication.id,
      scheduledAt: scheduledTime,
      method: 'voice',
    );
  }

  // Utility Methods

  List<Medication> get filteredMedications {
    var filtered = medications.where((medication) {
      if (showInactiveOnly.value && medication.isActive) return false;
      if (!showInactiveOnly.value && !medication.isActive) return false;
      
      if (searchQuery.value.isNotEmpty) {
        final query = searchQuery.value.toLowerCase();
        return medication.displayName.toLowerCase().contains(query) ||
               medication.drugName.toLowerCase().contains(query);
      }
      
      return true;
    }).toList();

    // Sort by next dose time, then by name
    filtered.sort((a, b) {
      final aNextDose = _getNextDoseTime(a);
      final bNextDose = _getNextDoseTime(b);
      
      if (aNextDose != null && bNextDose != null) {
        return aNextDose.compareTo(bNextDose);
      } else if (aNextDose != null) {
        return -1;
      } else if (bNextDose != null) {
        return 1;
      } else {
        return a.displayName.compareTo(b.displayName);
      }
    });

    return filtered;
  }

  DateTime? _getNextDoseTime(Medication medication) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    for (final timeStr in medication.schedule.times) {
      final timeParts = timeStr.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      var doseTime = DateTime(today.year, today.month, today.day, hour, minute);
      
      if (doseTime.isAfter(now)) {
        return doseTime;
      }
    }
    
    // If no doses today, check tomorrow
    final tomorrow = today.add(Duration(days: 1));
    final firstTimeStr = medication.schedule.times.first;
    final timeParts = firstTimeStr.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour, minute);
  }

  // Filter and search methods
  void toggleInactiveFilter() {
    showInactiveOnly.value = !showInactiveOnly.value;
    loadMedications(forceRefresh: true);
  }

  void updateSearchQuery(String query) {
    searchQuery.value = query;
  }

  void setAdherencePeriod(AdherencePeriod period) {
    currentAdherencePeriod.value = period;
    loadAdherenceSummary();
  }

  // Navigation helpers
  void selectMedication(Medication medication) {
    selectedMedication.value = medication;
  }

  void clearSelectedMedication() {
    selectedMedication.value = null;
  }

  // Private helper methods

  void _checkForDueReminders() {
    // This would typically be handled by the system notification service
    // but we can also check programmatically for in-app notifications
  }

  Future<void> _scheduleRemindersForMedication(Medication medication) async {
    // Integration with local notification service
    await _notificationService.scheduleRemindersForMedication(medication);
  }

  Future<void> _rescheduleRemindersForMedication(Medication medication) async {
    await _notificationService.cancelRemindersForMedication(medication.id);
    await _notificationService.scheduleRemindersForMedication(medication);
  }

  Future<void> _cancelRemindersForMedication(String medicationId) async {
    await _notificationService.cancelRemindersForMedication(medicationId);
  }

  void _acknowledgeRelatedReminder(String medicationId, DateTime scheduledAt) {
    final reminder = activeReminders.firstWhereOrNull((r) => 
        r.medicationId == medicationId && 
        r.scheduledTime.isAtSameMomentAs(scheduledAt));
    
    if (reminder != null) {
      acknowledgeReminder(reminder.id);
    }
  }

  void _promptForDetailedSideEffectReport(String medicationId, String doseEventId) {
    // This would show a dialog for detailed side effect reporting
    Get.dialog(
      AlertDialog(
        title: Text('Side Effect Details'),
        content: Text('Would you like to provide more details about the side effect?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.toNamed('/side-effect-report', arguments: {
                'medication_id': medicationId,
                'dose_event_id': doseEventId,
              });
            },
            child: Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _showCriticalInteractionAlert(List<MedicationInteraction> interactions) {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Critical Drug Interaction'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Critical interactions detected:'),
            SizedBox(height: 8),
            ...interactions.map((interaction) => 
              Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('• ${interaction.description}'),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Please consult your healthcare provider immediately.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Get.back(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _scheduleSnoozeNotification(MedicationReminder reminder, int minutes) {
    _notificationService.scheduleSnoozeNotification(reminder, minutes);
  }

  DateTime _parseTimeFromVoice(String timeStr) {
    // Simple time parsing - could be enhanced with NLP
    final now = DateTime.now();
    
    // Handle common phrases
    if (timeStr.contains('6') || timeStr.contains('six')) {
      return DateTime(now.year, now.month, now.day, 6, 0);
    }
    if (timeStr.contains('morning')) {
      return DateTime(now.year, now.month, now.day, 8, 0);
    }
    if (timeStr.contains('noon')) {
      return DateTime(now.year, now.month, now.day, 12, 0);
    }
    if (timeStr.contains('evening')) {
      return DateTime(now.year, now.month, now.day, 18, 0);
    }
    
    // Default to current time
    return now;
  }

  void _handleSkipMedicationVoiceCommand(Map<String, dynamic> params) {
    // Similar to take medication but marks as skipped
  }

  void _handleSnoozeReminderVoiceCommand(Map<String, dynamic> params) {
    // Handle snooze commands
  }

  void _handleNextDoseVoiceCommand() {
    // Get and announce next dose
    _repository.getNextDose().then((response) {
      response.when(
        success: (result) {
          final nextDose = result['next_dose'];
          if (nextDose != null) {
            AppToast.showInfo('Next dose: ${nextDose['medication']} at ${nextDose['time']}');
          } else {
            AppToast.showInfo('No upcoming doses');
          }
        },
        error: (error) {
          AppToast.showError('Could not get next dose info');
        },
        loading: () => print('Getting next dose info...'),
      );
    });
  }

  // Form management methods
  void clearForm() {
    drugNameController.clear();
    brandNameController.clear();
    strengthController.clear();
    instructionsController.clear();
    
    strengthUnit.value = '';
    medicationForm.value = '';
    medicationRoute.value = '';
    takeWithFood.value = null;
    asNeeded.value = false;
    scheduleTimes.clear();
    selectedDays.clear();
    isDailySchedule.value = true;
    remindersEnabled.value = true;
    caregiverEscalationEnabled.value = false;
    missedDoseAction.value = 'no_policy';
    dosesPerDay.value = 1;
  }

  void populateFormFromMedication(Medication medication) {
    drugNameController.text = medication.drugName;
    brandNameController.text = medication.brandName ?? '';
    strengthController.text = medication.strength.toString();
    instructionsController.text = medication.instructionsText;
    
    strengthUnit.value = medication.strengthUnit;
    medicationForm.value = medication.form;
    medicationRoute.value = medication.route;
    takeWithFood.value = medication.takeWithFood;
    asNeeded.value = medication.asNeeded;
    
    scheduleTimes.assignAll(medication.schedule.times);
    dosesPerDay.value = medication.schedule.times.isEmpty ? 1 : medication.schedule.times.length;

    if (medication.schedule.days != null) {
      selectedDays.assignAll(medication.schedule.days!);
      isDailySchedule.value = medication.schedule.isDailySchedule;
    } else {
      selectedDays.assignAll(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']);
      isDailySchedule.value = true;
    }

    remindersEnabled.value = medication.schedule.reminderEnabled;
    caregiverEscalationEnabled.value = medication.schedule.caregiverEscalationEnabled;
    missedDoseAction.value = medication.missedDoseAction;
  }

  // Process voice command method for external access
  void processVoiceCommand(String command) {
    _handleVoiceCommand(command, 0.9);
  }

  void addTime() async {
    // Show time picker dialog
    final TimeOfDay? picked = await showTimePicker(
      context: Get.context!,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final timeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      if (!scheduleTimes.contains(timeStr)) {
        scheduleTimes.add(timeStr);
        // Sort times to maintain chronological order
        scheduleTimes.sort();
      } else {
        AppToast.showWarning('This time is already added');
      }
    }
  }

  void removeTime(int index) {
    if (index >= 0 && index < scheduleTimes.length) {
      scheduleTimes.removeAt(index);
      // Update dosesPerDay to match actual count
      dosesPerDay.value = scheduleTimes.length;
    }
  }

  /// Edit a specific time slot
  void editTime(int index) async {
    if (index < 0 || index >= scheduleTimes.length) return;

    // Parse existing time
    final existingTime = scheduleTimes[index];
    final parts = existingTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );

    final TimeOfDay? picked = await showTimePicker(
      context: Get.context!,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final timeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      if (!scheduleTimes.contains(timeStr) || scheduleTimes[index] == timeStr) {
        scheduleTimes[index] = timeStr;
        scheduleTimes.sort();
      } else {
        AppToast.showWarning('This time is already added');
      }
    }
  }

  /// Generate evenly spaced times based on first time and number of doses
  void generateAutoTimes(String firstTime, int doses) {
    if (doses <= 0 || doses > 12) return;

    scheduleTimes.clear();

    // Parse first time
    final parts = firstTime.split(':');
    int startHour = int.tryParse(parts[0]) ?? 8;
    int startMinute = int.tryParse(parts[1]) ?? 0;

    // Calculate interval between doses (distribute across waking hours ~16h)
    // For typical medication schedules:
    // 1x = as specified
    // 2x = 12 hours apart
    // 3x = 8 hours apart
    // 4x = 6 hours apart
    int intervalMinutes;
    if (doses == 1) {
      intervalMinutes = 0;
    } else if (doses == 2) {
      intervalMinutes = 12 * 60; // 12 hours
    } else if (doses == 3) {
      intervalMinutes = 8 * 60; // 8 hours
    } else if (doses == 4) {
      intervalMinutes = 6 * 60; // 6 hours
    } else {
      // For more doses, distribute across 16 waking hours
      intervalMinutes = (16 * 60) ~/ (doses - 1);
    }

    for (int i = 0; i < doses; i++) {
      int totalMinutes = (startHour * 60) + startMinute + (i * intervalMinutes);
      // Wrap around midnight if needed
      totalMinutes = totalMinutes % (24 * 60);

      int hour = totalMinutes ~/ 60;
      int minute = totalMinutes % 60;

      final timeStr = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      if (!scheduleTimes.contains(timeStr)) {
        scheduleTimes.add(timeStr);
      }
    }

    scheduleTimes.sort();
    dosesPerDay.value = doses;
  }

  /// Handle doses per day change - prompts for first time if not set
  void onDosesPerDayChanged(int newDoses) async {
    if (newDoses <= 0 || newDoses > 12) return;

    dosesPerDay.value = newDoses;

    // Get the first time - use existing or prompt
    String firstTime;
    if (scheduleTimes.isNotEmpty) {
      firstTime = scheduleTimes.first;
    } else {
      // Prompt for first dose time
      final TimeOfDay? picked = await showTimePicker(
        context: Get.context!,
        initialTime: TimeOfDay(hour: 8, minute: 0),
        helpText: 'Select first dose time',
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
            child: child!,
          );
        },
      );

      if (picked == null) {
        dosesPerDay.value = scheduleTimes.length;
        return;
      }
      firstTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    }

    generateAutoTimes(firstTime, newDoses);
  }

  /// Set first dose time and regenerate schedule
  void setFirstDoseTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: Get.context!,
      initialTime: scheduleTimes.isNotEmpty
          ? TimeOfDay(
              hour: int.tryParse(scheduleTimes.first.split(':')[0]) ?? 8,
              minute: int.tryParse(scheduleTimes.first.split(':')[1]) ?? 0,
            )
          : TimeOfDay(hour: 8, minute: 0),
      helpText: 'Select first dose time',
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final firstTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      if (dosesPerDay.value > 0) {
        generateAutoTimes(firstTime, dosesPerDay.value);
      }
    }
  }

  // Agent Tool Functions
  /// Tool function for the agent to modify daily medication status
  /// This allows the AI agent to mark medications as taken, missed, or skipped
  Future<Map<String, dynamic>> updateMedicationDailyStatus({
    required String medicationId,
    required String status, // 'taken', 'missed', 'skipped'
    String? notes,
    DateTime? takenAt,
  }) async {
    try {
      final medication = medications.firstWhereOrNull((m) => m.id == medicationId);
      if (medication == null) {
        return {
          'success': false,
          'error': 'Medication not found with ID: $medicationId',
          'medication_name': 'Unknown'
        };
      }

      final scheduledTime = takenAt ?? DateTime.now();
      
      switch (status.toLowerCase()) {
        case 'taken':
          await recordDoseTaken(
            medicationId: medicationId,
            scheduledAt: scheduledTime,
            method: 'agent_tool',
            notes: notes,
          );
          break;
        case 'missed':
          await recordDoseMissed(
            medicationId: medicationId,
            scheduledAt: scheduledTime,
            reason: notes ?? 'Marked as missed by AI agent',
          );
          break;
        case 'skipped':
          await recordDoseSkipped(
            medicationId: medicationId,
            scheduledAt: scheduledTime,
            reason: notes ?? 'Skipped via AI agent',
          );
          break;
        default:
          return {
            'success': false,
            'error': 'Invalid status. Use: taken, missed, or skipped',
            'medication_name': medication.displayName
          };
      }

      return {
        'success': true,
        'medication_name': medication.displayName,
        'status': status,
        'scheduled_time': scheduledTime.toIso8601String(),
        'notes': notes,
      };

    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to update medication status: ${e.toString()}',
        'medication_name': 'Unknown'
      };
    }
  }

  /// Get today's schedule
  List<Map<String, dynamic>> getTodaySchedule() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return activeReminders.where((reminder) {
      final reminderDate = DateTime(
        reminder.scheduledTime.year,
        reminder.scheduledTime.month,
        reminder.scheduledTime.day,
      );
      return reminderDate.isAtSameMomentAs(today);
    }).map((reminder) {
      final medication = medications.firstWhere(
        (med) => med.id == reminder.medicationId,
        orElse: () => medications.first,
      );
      final isOverdue = reminder.scheduledTime.isBefore(now) && reminder.status != ReminderStatus.taken;
      
      return {
        'medication': medication,
        'scheduled_time': reminder.scheduledTime,
        'is_overdue': isOverdue,
        'is_taken': reminder.status == ReminderStatus.taken,
      };
    }).toList();
  }

  /// Get today's medication schedule for the agent
  Map<String, dynamic> getTodayMedicationScheduleForAgent() {
    final todaySchedule = getTodaySchedule();
    
    return {
      'date': DateTime.now().toIso8601String().split('T')[0],
      'total_medications': todaySchedule.length,
      'medications': todaySchedule.map((item) {
        final medication = item['medication'] as Medication;
        final scheduledTime = item['scheduled_time'] as DateTime;
        final isOverdue = item['is_overdue'] as bool;
        
        return {
          'id': medication.id,
          'name': medication.displayName,
          'strength': medication.strengthDisplay,
          'scheduled_time': scheduledTime.toIso8601String(),
          'is_overdue': isOverdue,
          'take_with_food': medication.takeWithFood,
          'instructions': medication.instructionsText,
        };
      }).toList(),
    };
  }

  /// Get medication adherence summary for the agent
  Map<String, dynamic> getMedicationAdherenceSummaryForAgent() {
    return {
      'summary': adherenceSummary.value ?? {},
      'active_medications': medications.where((m) => m.isActive).length,
      'total_medications': medications.length,
      'reminder_count': activeReminders.length,
      'last_updated': DateTime.now().toIso8601String(),
    };
  }

  bool get isLoading => requestStatus.value == Status.LOADING;

  // Getter for upcoming reminders (alias for activeReminders)
  List<MedicationReminder> get upcomingReminders => activeReminders;

  // Medication analytics observable
  var medicationAnalytics = Rxn<Map<String, dynamic>>();

  // Form submission methods
  Future<void> addMedication() async {
    try {
      requestStatus.value = Status.LOADING;

      // Validate strength field - make it optional for certain medications
      double strengthValue = 0.0;
      if (strengthController.text.trim().isNotEmpty) {
        final parsedValue = double.tryParse(strengthController.text.trim());
        if (parsedValue == null) {
          AppToast.showError('Please enter a valid numeric strength value');
          requestStatus.value = Status.ERROR;
          return;
        }
        strengthValue = parsedValue;
      }

      final medication = Medication(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        profileId: 'current_profile', // Would get from auth service
        drugName: drugNameController.text.trim(),
        brandName: brandNameController.text.trim().isEmpty ? null : brandNameController.text.trim(),
        form: medicationForm.value,
        strength: strengthValue,
        strengthUnit: strengthUnit.value,
        route: medicationRoute.value,
        instructionsText: instructionsController.text.trim(),
        takeWithFood: takeWithFood.value,
        asNeeded: asNeeded.value,
        missedDoseAction: missedDoseAction.value,
        schedule: MedicationSchedule(
          times: scheduleTimes.toList(),
          days: isDailySchedule.value ? null : selectedDays.toList(),
          frequency: asNeeded.value ? MedicationFrequency.asNeeded : MedicationFrequency.daily,
          reminderEnabled: remindersEnabled.value,
          reminderMinutesBefore: 15,
          caregiverEscalationEnabled: caregiverEscalationEnabled.value,
        ),
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final response = await _repository.createMedication(medication);
      response.when(
        success: (createdMedication) {
          medications.add(createdMedication);
          _scheduleRemindersForMedication(createdMedication);
          loadAdherenceSummary(); // Update today's counts
          clearForm();
          Get.back();
          AppToast.showSuccess('Medication added successfully');
          requestStatus.value = Status.COMPLETED;
        },
        error: (error) {
          AppToast.showError('Failed to add medication: $error');
          requestStatus.value = Status.ERROR;
        },
        loading: () {
          requestStatus.value = Status.LOADING;
        },
      );
    } catch (e) {
      AppToast.showError('Error adding medication: ${e.toString()}');
      requestStatus.value = Status.ERROR;
    }
  }

  Future<void> updateMedicationFromForm(String medicationId) async {
    try {
      requestStatus.value = Status.LOADING;

      final existingMedication = medications.firstWhereOrNull((m) => m.id == medicationId);
      if (existingMedication == null) {
        AppToast.showError('Medication not found');
        requestStatus.value = Status.ERROR;
        return;
      }

      // Validate strength field - make it optional for certain medications
      double strengthValue = 0.0;
      if (strengthController.text.trim().isNotEmpty) {
        final parsedValue = double.tryParse(strengthController.text.trim());
        if (parsedValue == null) {
          AppToast.showError('Please enter a valid numeric strength value');
          requestStatus.value = Status.ERROR;
          return;
        }
        strengthValue = parsedValue;
      }

      final updatedMedication = Medication(
        id: medicationId,
        profileId: existingMedication.profileId,
        drugName: drugNameController.text.trim(),
        brandName: brandNameController.text.trim().isEmpty ? null : brandNameController.text.trim(),
        form: medicationForm.value,
        strength: strengthValue,
        strengthUnit: strengthUnit.value,
        route: medicationRoute.value,
        instructionsText: instructionsController.text.trim(),
        takeWithFood: takeWithFood.value,
        asNeeded: asNeeded.value,
        missedDoseAction: missedDoseAction.value,
        schedule: MedicationSchedule(
          times: scheduleTimes.toList(),
          days: isDailySchedule.value ? null : selectedDays.toList(),
          frequency: asNeeded.value ? MedicationFrequency.asNeeded : MedicationFrequency.daily,
          reminderEnabled: remindersEnabled.value,
          reminderMinutesBefore: 15,
          caregiverEscalationEnabled: caregiverEscalationEnabled.value,
        ),
        startDate: existingMedication.startDate,
        endDate: existingMedication.endDate,
        prescribedBy: existingMedication.prescribedBy,
        pharmacy: existingMedication.pharmacy,
        rxNumber: existingMedication.rxNumber,
        refillsRemaining: existingMedication.refillsRemaining,
        notes: existingMedication.notes,
        isActive: existingMedication.isActive,
        createdAt: existingMedication.createdAt,
        updatedAt: DateTime.now(),
        createdBy: existingMedication.createdBy,
      );

      final response = await _repository.updateMedication(medicationId, updatedMedication);
      response.when(
        success: (updated) {
          final index = medications.indexWhere((m) => m.id == medicationId);
          if (index != -1) {
            medications[index] = updated;
          }
          _rescheduleRemindersForMedication(updated);
          loadAdherenceSummary(); // Update today's counts
          clearForm();
          Get.back();
          AppToast.showSuccess('Medication updated successfully');
          requestStatus.value = Status.COMPLETED;
        },
        error: (error) {
          AppToast.showError('Failed to update medication: $error');
          requestStatus.value = Status.ERROR;
        },
        loading: () {
          requestStatus.value = Status.LOADING;
        },
      );
    } catch (e) {
      AppToast.showError('Error updating medication: ${e.toString()}');
      requestStatus.value = Status.ERROR;
    }
  }
}