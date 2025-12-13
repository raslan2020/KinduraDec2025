import 'package:kindura_ai/data/network/network_api_services.dart';
import 'package:kindura_ai/models/medication/medication_models.dart';
import 'package:kindura_ai/data/response/api_response.dart';
import 'package:kindura_ai/res/app_url/app_url.dart';

class MedicationRepository {
  final _apiService = NetworkApiServices();

  // CRUD Operations for Medications

  /// Get all medications for current user
  Future<ApiResponse<List<Medication>>> getMedications({
    bool? activeOnly,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (activeOnly != null) queryParams['active_only'] = activeOnly.toString();
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      print('📦 Loading medications from: ${AppUrl.baseUrl}/medications/');
      final response = await _apiService.getApi(
        '${AppUrl.baseUrl}/medications/',
        queryParameters: queryParams,
      );

      if (response['status'] == true) {
        final List<dynamic> medicationsJson = response['result'] ?? [];
        print('📦 Received ${medicationsJson.length} medications');
        final medications = <Medication>[];
        for (var i = 0; i < medicationsJson.length; i++) {
          try {
            medications.add(Medication.fromJson(medicationsJson[i]));
          } catch (e) {
            print('❌ Error parsing medication $i: $e');
            print('   JSON: ${medicationsJson[i]}');
          }
        }
        return ApiResponse.completed(medications);
      } else {
        print('❌ Medications API error: ${response['message']}');
        return ApiResponse.error(response['message'] ?? 'Failed to load medications');
      }
    } catch (e) {
      print('❌ Medications exception: $e');
      return ApiResponse.error(e.toString());
    }
  }

  /// Get specific medication by ID
  Future<ApiResponse<Medication>> getMedication(String medicationId) async {
    try {
      final response = await _apiService.getApi('${AppUrl.baseUrl}/medications/$medicationId/');

      if (response['status'] == true) {
        final medication = Medication.fromJson(response['result']);
        return ApiResponse.completed(medication);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to load medication');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Create new medication with safety validation
  Future<ApiResponse<Medication>> createMedication(Medication medication) async {
    try {
      // Client-side safety validation
      final validationError = _validateMedicationSafety(medication);
      if (validationError != null) {
        return ApiResponse.error(validationError);
      }

      final data = medication.toJson();
      final response = await _apiService.postApi(data, '${AppUrl.baseUrl}/medications/');

      if (response['status'] == true) {
        final createdMedication = Medication.fromJson(response['result']);
        return ApiResponse.completed(createdMedication);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to create medication');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Update existing medication with safety checks
  Future<ApiResponse<Medication>> updateMedication(
    String medicationId, 
    Medication medication
  ) async {
    try {
      // Safety validation for updates
      final validationError = _validateMedicationSafety(medication);
      if (validationError != null) {
        return ApiResponse.error(validationError);
      }

      final data = medication.toJson();
      final response = await _apiService.putApi(data, '${AppUrl.baseUrl}/medications/$medicationId/');

      if (response['status'] == true) {
        final updatedMedication = Medication.fromJson(response['result']);
        return ApiResponse.completed(updatedMedication);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to update medication');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Delete medication
  Future<ApiResponse<void>> deleteMedication(String medicationId, String reason) async {
    try {
      final response = await _apiService.deleteApi(
        '${AppUrl.baseUrl}/medications/$medicationId/'
      );

      print('🗑️ Delete response: $response');

      if (response['status'] == true) {
        return ApiResponse.completed(null);
      } else {
        return ApiResponse.error(response['message'] ?? response['result']?['error'] ?? 'Failed to delete medication');
      }
    } catch (e) {
      print('❌ Delete error: $e');
      return ApiResponse.error(e.toString());
    }
  }

  // Dose Event Management

  /// Get dose events for a medication
  Future<ApiResponse<List<DoseEvent>>> getDoseEvents(
    String medicationId, {
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (fromDate != null) queryParams['from_date'] = fromDate.toIso8601String();
      if (toDate != null) queryParams['to_date'] = toDate.toIso8601String();
      if (limit != null) queryParams['limit'] = limit.toString();

      final response = await _apiService.getApi(
        '${AppUrl.baseUrl}/medications/$medicationId/dose-events/',
        queryParameters: queryParams,
      );

      if (response['status'] == true) {
        final List<dynamic> eventsJson = response['result'];
        final events = eventsJson
            .map((json) => DoseEvent.fromJson(json))
            .toList();
        return ApiResponse.completed(events);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to load dose events');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Record dose taken
  Future<ApiResponse<DoseEvent>> recordDoseTaken({
    required String medicationId,
    required DateTime scheduledAt,
    DateTime? takenAt,
    double? actualDose,
    String? actualUnit,
    String? notes,
    String? sideEffectNote,
    String method = 'tap',
  }) async {
    try {
      final data = {
        'medication_id': medicationId,
        'scheduled_at': scheduledAt.toIso8601String(),
        'taken_at': (takenAt ?? DateTime.now()).toIso8601String(),
        'status': 'taken',
        'method': method,
        if (actualDose != null) 'actual_dose': actualDose,
        if (actualUnit != null) 'actual_unit': actualUnit,
        if (notes != null) 'notes': notes,
        if (sideEffectNote != null) 'side_effect_note': sideEffectNote,
      };

      final response = await _apiService.postApi(data, '${AppUrl.baseUrl}/dose-events/');

      if (response['status'] == true) {
        final result = response['result'] as Map<String, dynamic>;
        // Map API response to DoseEvent model format
        final mappedResult = {
          'id': result['id']?.toString() ?? '',
          'medicationId': result['medication_id']?.toString() ?? result['mid']?.toString() ?? medicationId,
          'scheduledAt': result['scheduled_at'] ?? result['sa'] ?? scheduledAt.toIso8601String(),
          'takenAt': result['taken_at'] ?? result['ta'],
          'status': result['status'] ?? result['st'] ?? 'taken',
          'delayMinutes': result['delay_minutes'] ?? result['dm'],
          'notes': notes,
          'sideEffectNote': sideEffectNote,
          'method': method,
          'createdAt': result['created_at'] ?? DateTime.now().toIso8601String(),
        };
        final doseEvent = DoseEvent.fromJson(mappedResult);
        return ApiResponse.completed(doseEvent);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to record dose');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Record dose missed
  Future<ApiResponse<DoseEvent>> recordDoseMissed({
    required String medicationId,
    required DateTime scheduledAt,
    String? reason,
  }) async {
    try {
      final data = {
        'medication_id': medicationId,
        'scheduled_at': scheduledAt.toIso8601String(),
        'status': 'missed',
        if (reason != null) 'notes': reason,
      };

      final response = await _apiService.postApi(data, '${AppUrl.baseUrl}/dose-events/');

      if (response['status'] == true) {
        final result = response['result'] as Map<String, dynamic>;
        final mappedResult = {
          'id': result['id']?.toString() ?? '',
          'medicationId': result['medication_id']?.toString() ?? result['mid']?.toString() ?? medicationId,
          'scheduledAt': result['scheduled_at'] ?? result['sa'] ?? scheduledAt.toIso8601String(),
          'takenAt': result['taken_at'] ?? result['ta'],
          'status': result['status'] ?? result['st'] ?? 'missed',
          'delayMinutes': result['delay_minutes'] ?? result['dm'],
          'notes': reason,
          'createdAt': result['created_at'] ?? DateTime.now().toIso8601String(),
        };
        final doseEvent = DoseEvent.fromJson(mappedResult);
        return ApiResponse.completed(doseEvent);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to record missed dose');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Record dose skipped
  Future<ApiResponse<DoseEvent>> recordDoseSkipped({
    required String medicationId,
    required DateTime scheduledAt,
    String? reason,
  }) async {
    try {
      final data = {
        'medication_id': medicationId,
        'scheduled_at': scheduledAt.toIso8601String(),
        'status': 'skipped',
        if (reason != null) 'notes': reason,
      };

      final response = await _apiService.postApi(data, '${AppUrl.baseUrl}/dose-events/');

      if (response['status'] == true) {
        final result = response['result'] as Map<String, dynamic>;
        final mappedResult = {
          'id': result['id']?.toString() ?? '',
          'medicationId': result['medication_id']?.toString() ?? result['mid']?.toString() ?? medicationId,
          'scheduledAt': result['scheduled_at'] ?? result['sa'] ?? scheduledAt.toIso8601String(),
          'takenAt': result['taken_at'] ?? result['ta'],
          'status': result['status'] ?? result['st'] ?? 'skipped',
          'delayMinutes': result['delay_minutes'] ?? result['dm'],
          'notes': reason,
          'createdAt': result['created_at'] ?? DateTime.now().toIso8601String(),
        };
        final doseEvent = DoseEvent.fromJson(mappedResult);
        return ApiResponse.completed(doseEvent);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to record skipped dose');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // Reminder Management

  /// Get active reminders
  Future<ApiResponse<List<MedicationReminder>>> getActiveReminders() async {
    try {
      final response = await _apiService.getApi('${AppUrl.baseUrl}/medication-reminders/active/');

      if (response['status'] == true) {
        final List<dynamic> remindersJson = response['result'];
        final reminders = remindersJson
            .map((json) => MedicationReminder.fromJson(json))
            .toList();
        return ApiResponse.completed(reminders);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to load reminders');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Snooze reminder
  Future<ApiResponse<MedicationReminder>> snoozeReminder(
    String reminderId,
    int snoozeMinutes,
  ) async {
    try {
      final data = {
        'snooze_minutes': snoozeMinutes,
      };

      final response = await _apiService.postApi(
        data,
        '${AppUrl.baseUrl}/medication-reminders/$reminderId/snooze/'
      );

      if (response['status'] == true) {
        final reminder = MedicationReminder.fromJson(response['result']);
        return ApiResponse.completed(reminder);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to snooze reminder');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Acknowledge reminder
  Future<ApiResponse<void>> acknowledgeReminder(String reminderId) async {
    try {
      final response = await _apiService.postApi(
        {},
        '${AppUrl.baseUrl}/medication-reminders/$reminderId/acknowledge/'
      );

      if (response['status'] == true) {
        return ApiResponse.completed(null);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to acknowledge reminder');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // Adherence Analytics

  /// Get adherence analytics
  Future<ApiResponse<AdherenceAnalytics>> getAdherenceAnalytics(
    String medicationId,
    AdherencePeriod period,
  ) async {
    try {
      final response = await _apiService.getApi(
        '/medications/$medicationId/adherence/',
        queryParameters: {'period': period.name},
      );

      if (response['status'] == true) {
        final analytics = AdherenceAnalytics.fromJson(response['result']);
        return ApiResponse.completed(analytics);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to load adherence data');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Get overall adherence summary
  Future<ApiResponse<Map<String, dynamic>>> getAdherenceSummary(
    AdherencePeriod period,
  ) async {
    try {
      final response = await _apiService.getApi(
        '${AppUrl.baseUrl}/adherence/summary/',
        queryParameters: {'period': period.name},
      );

      if (response['status'] == true) {
        return ApiResponse.completed(response['result']);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to load adherence summary');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // Side Effects

  /// Report side effect
  Future<ApiResponse<SideEffectReport>> reportSideEffect({
    required String medicationId,
    String? doseEventId,
    required SideEffectSeverity severity,
    required String description,
    required List<String> symptoms,
    String? notes,
    String? actionTaken,
  }) async {
    try {
      final data = {
        'medication_id': medicationId,
        if (doseEventId != null) 'dose_event_id': doseEventId,
        'severity': severity.name,
        'description': description,
        'symptoms': symptoms,
        'occurred_at': DateTime.now().toIso8601String(),
        if (notes != null) 'notes': notes,
        if (actionTaken != null) 'action_taken': actionTaken,
      };

      final response = await _apiService.postApi(data, '${AppUrl.baseUrl}/side-effect-reports/');

      if (response['status'] == true) {
        final report = SideEffectReport.fromJson(response['result']);
        return ApiResponse.completed(report);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to report side effect');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Get side effect reports
  Future<ApiResponse<List<SideEffectReport>>> getSideEffectReports(
    String medicationId,
  ) async {
    try {
      final response = await _apiService.getApi(
        '/medications/$medicationId/side-effect-reports/',
      );

      if (response['status'] == true) {
        final List<dynamic> reportsJson = response['result'];
        final reports = reportsJson
            .map((json) => SideEffectReport.fromJson(json))
            .toList();
        return ApiResponse.completed(reports);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to load side effect reports');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // Drug Interactions

  /// Check for medication interactions
  Future<ApiResponse<List<MedicationInteraction>>> checkInteractions() async {
    try {
      final response = await _apiService.getApi('${AppUrl.baseUrl}/medications/interactions/check/');

      if (response['status'] == true) {
        final List<dynamic> interactionsJson = response['result'];
        final interactions = interactionsJson
            .map((json) => MedicationInteraction.fromJson(json))
            .toList();
        return ApiResponse.completed(interactions);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to check interactions');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // Caregiver Management

  /// Get caregiver contacts
  Future<ApiResponse<List<CaregiverContact>>> getCaregiverContacts() async {
    try {
      final response = await _apiService.getApi('${AppUrl.baseUrl}/caregiver-contacts/');

      if (response['status'] == true) {
        final List<dynamic> contactsJson = response['result'];
        final contacts = contactsJson
            .map((json) => CaregiverContact.fromJson(json))
            .toList();
        return ApiResponse.completed(contacts);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to load caregivers');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Add caregiver contact
  Future<ApiResponse<CaregiverContact>> addCaregiverContact(
    CaregiverContact contact,
  ) async {
    try {
      final data = contact.toJson();
      final response = await _apiService.postApi(data, '${AppUrl.baseUrl}/caregiver-contacts/');

      if (response['status'] == true) {
        final createdContact = CaregiverContact.fromJson(response['result']);
        return ApiResponse.completed(createdContact);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to add caregiver');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // Voice Integration

  /// Process voice command
  Future<ApiResponse<Map<String, dynamic>>> processVoiceCommand({
    required String audioText,
    required double confidence,
    Map<String, dynamic>? context,
  }) async {
    try {
      final data = {
        'audio_text': audioText,
        'confidence': confidence,
        'timestamp': DateTime.now().toIso8601String(),
        if (context != null) 'context': context,
      };

      final response = await _apiService.postApi(data, '${AppUrl.baseUrl}/medications/voice-command/');

      if (response['status'] == true) {
        return ApiResponse.completed(response['result']);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to process voice command');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Get next scheduled dose
  Future<ApiResponse<Map<String, dynamic>>> getNextDose() async {
    try {
      final response = await _apiService.getApi('${AppUrl.baseUrl}/medications/next-dose/');

      if (response['status'] == true) {
        return ApiResponse.completed(response['result']);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to get next dose');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // Utility Methods

  /// Validate medication safety before creation/update
  String? _validateMedicationSafety(Medication medication) {
    // Basic safety validations
    if (medication.drugName.isEmpty) {
      return 'Drug name is required';
    }

    // Strength is optional for some medications
    if (medication.strength < 0) {
      return 'Strength cannot be negative';
    }

    // Schedule validation - only if not as-needed
    if (!medication.asNeeded && medication.schedule.times.isEmpty) {
      return 'At least one dose time is required for scheduled medications';
    }

    // Validate dose times format
    for (final time in medication.schedule.times) {
      if (!RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$').hasMatch(time)) {
        return 'Invalid time format: $time. Use HH:MM format';
      }
    }

    // Validate end date is after start date
    if (medication.startDate != null && medication.endDate != null) {
      if (medication.endDate!.isBefore(medication.startDate!)) {
        return 'End date cannot be before start date';
      }
    }

    // Validate reasonable dosing frequency
    if (medication.schedule.times.length > 24) {
      return 'Cannot schedule more than 24 doses per day';
    }

    return null; // No validation errors
  }

  /// Generate medication audit log entry
  Future<void> _logMedicationChange({
    required String medicationId,
    required String action,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    String? reason,
  }) async {
    try {
      final data = {
        'medication_id': medicationId,
        'action': action,
        'timestamp': DateTime.now().toIso8601String(),
        if (oldValues != null) 'old_values': oldValues,
        if (newValues != null) 'new_values': newValues,
        if (reason != null) 'reason': reason,
      };

      await _apiService.postApi(data, '${AppUrl.baseUrl}/medication-audit-logs/');
    } catch (e) {
      // Log audit failures but don't block the main operation
      print('Failed to create audit log: $e');
    }
  }
}