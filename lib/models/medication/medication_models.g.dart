// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medication_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Medication _$MedicationFromJson(Map<String, dynamic> json) => Medication(
      id: const StringOrIntConverter().fromJson(json['id'] as Object),
      profileId:
          const NullableStringOrIntConverter().fromJson(json['profileId']),
      drugName: json['drugName'] as String,
      brandName: json['brandName'] as String?,
      form: json['form'] as String,
      strength: (json['strength'] as num).toDouble(),
      strengthUnit: json['strengthUnit'] as String,
      route: json['route'] as String,
      instructionsText: json['instructionsText'] as String,
      takeWithFood: json['takeWithFood'] as bool?,
      asNeeded: json['asNeeded'] as bool,
      missedDoseAction: json['missedDoseAction'] as String? ?? 'no_policy',
      schedule:
          MedicationSchedule.fromJson(json['schedule'] as Map<String, dynamic>),
      startDate: json['startDate'] == null
          ? null
          : DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] == null
          ? null
          : DateTime.parse(json['endDate'] as String),
      prescribedBy: json['prescribedBy'] as String?,
      pharmacy: json['pharmacy'] as String?,
      rxNumber: json['rxNumber'] as String?,
      refillsRemaining: (json['refillsRemaining'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      isActive: json['isActive'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      createdBy: json['createdBy'] as String?,
    );

Map<String, dynamic> _$MedicationToJson(Medication instance) =>
    <String, dynamic>{
      'id': const StringOrIntConverter().toJson(instance.id),
      'profileId':
          const NullableStringOrIntConverter().toJson(instance.profileId),
      'drugName': instance.drugName,
      'brandName': instance.brandName,
      'form': instance.form,
      'strength': instance.strength,
      'strengthUnit': instance.strengthUnit,
      'route': instance.route,
      'instructionsText': instance.instructionsText,
      'takeWithFood': instance.takeWithFood,
      'asNeeded': instance.asNeeded,
      'missedDoseAction': instance.missedDoseAction,
      'schedule': instance.schedule,
      'startDate': instance.startDate?.toIso8601String(),
      'endDate': instance.endDate?.toIso8601String(),
      'prescribedBy': instance.prescribedBy,
      'pharmacy': instance.pharmacy,
      'rxNumber': instance.rxNumber,
      'refillsRemaining': instance.refillsRemaining,
      'notes': instance.notes,
      'isActive': instance.isActive,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'createdBy': instance.createdBy,
    };

MedicationSchedule _$MedicationScheduleFromJson(Map<String, dynamic> json) =>
    MedicationSchedule(
      times: (json['times'] as List<dynamic>).map((e) => e as String).toList(),
      days: (json['days'] as List<dynamic>?)?.map((e) => e as String).toList(),
      frequency: $enumDecodeNullable(
              _$MedicationFrequencyEnumMap, json['frequency']) ??
          MedicationFrequency.daily,
      intervalHours: (json['intervalHours'] as num?)?.toInt(),
      dosesPerDay: (json['dosesPerDay'] as num?)?.toInt(),
      timezone: json['timezone'] as String?,
      reminderEnabled: json['reminderEnabled'] as bool? ?? false,
      reminderMinutesBefore:
          (json['reminderMinutesBefore'] as num?)?.toInt() ?? 15,
      caregiverEscalationEnabled:
          json['caregiverEscalationEnabled'] as bool? ?? false,
      caregiverContactId: json['caregiverContactId'] as String?,
    );

Map<String, dynamic> _$MedicationScheduleToJson(MedicationSchedule instance) =>
    <String, dynamic>{
      'times': instance.times,
      'days': instance.days,
      'frequency': _$MedicationFrequencyEnumMap[instance.frequency]!,
      'intervalHours': instance.intervalHours,
      'dosesPerDay': instance.dosesPerDay,
      'timezone': instance.timezone,
      'reminderEnabled': instance.reminderEnabled,
      'reminderMinutesBefore': instance.reminderMinutesBefore,
      'caregiverEscalationEnabled': instance.caregiverEscalationEnabled,
      'caregiverContactId': instance.caregiverContactId,
    };

const _$MedicationFrequencyEnumMap = {
  MedicationFrequency.daily: 'daily',
  MedicationFrequency.weekly: 'weekly',
  MedicationFrequency.interval: 'interval',
  MedicationFrequency.asNeeded: 'as_needed',
};

DoseEvent _$DoseEventFromJson(Map<String, dynamic> json) => DoseEvent(
      id: const StringOrIntConverter().fromJson(json['id'] as Object),
      medicationId:
          const StringOrIntConverter().fromJson(json['medicationId'] as Object),
      profileId:
          const NullableStringOrIntConverter().fromJson(json['profileId']),
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      takenAt: json['takenAt'] == null
          ? null
          : DateTime.parse(json['takenAt'] as String),
      status: $enumDecode(_$DoseStatusEnumMap, json['status']),
      delayMinutes: (json['delayMinutes'] as num?)?.toInt(),
      sideEffectNote: json['sideEffectNote'] as String?,
      notes: json['notes'] as String?,
      actualDose: (json['actualDose'] as num?)?.toDouble(),
      actualUnit: json['actualUnit'] as String?,
      method: json['method'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$DoseEventToJson(DoseEvent instance) => <String, dynamic>{
      'id': const StringOrIntConverter().toJson(instance.id),
      'medicationId':
          const StringOrIntConverter().toJson(instance.medicationId),
      'profileId':
          const NullableStringOrIntConverter().toJson(instance.profileId),
      'scheduledAt': instance.scheduledAt.toIso8601String(),
      'takenAt': instance.takenAt?.toIso8601String(),
      'status': _$DoseStatusEnumMap[instance.status]!,
      'delayMinutes': instance.delayMinutes,
      'sideEffectNote': instance.sideEffectNote,
      'notes': instance.notes,
      'actualDose': instance.actualDose,
      'actualUnit': instance.actualUnit,
      'method': instance.method,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

const _$DoseStatusEnumMap = {
  DoseStatus.scheduled: 'scheduled',
  DoseStatus.taken: 'taken',
  DoseStatus.late: 'late',
  DoseStatus.missed: 'missed',
  DoseStatus.skipped: 'skipped',
  DoseStatus.snoozed: 'snoozed',
};

MedicationReminder _$MedicationReminderFromJson(Map<String, dynamic> json) =>
    MedicationReminder(
      id: const StringOrIntConverter().fromJson(json['id'] as Object),
      medicationId:
          const StringOrIntConverter().fromJson(json['medicationId'] as Object),
      profileId:
          const StringOrIntConverter().fromJson(json['profileId'] as Object),
      scheduledTime: DateTime.parse(json['scheduledTime'] as String),
      status: $enumDecode(_$ReminderStatusEnumMap, json['status']),
      notificationId: (json['notificationId'] as num).toInt(),
      acknowledgedAt: json['acknowledgedAt'] == null
          ? null
          : DateTime.parse(json['acknowledgedAt'] as String),
      snoozedUntil: json['snoozedUntil'] == null
          ? null
          : DateTime.parse(json['snoozedUntil'] as String),
      snoozeCount: (json['snoozeCount'] as num).toInt(),
      caregiverNotified: json['caregiverNotified'] as bool,
      caregiverNotifiedAt: json['caregiverNotifiedAt'] == null
          ? null
          : DateTime.parse(json['caregiverNotifiedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$MedicationReminderToJson(MedicationReminder instance) =>
    <String, dynamic>{
      'id': const StringOrIntConverter().toJson(instance.id),
      'medicationId':
          const StringOrIntConverter().toJson(instance.medicationId),
      'profileId': const StringOrIntConverter().toJson(instance.profileId),
      'scheduledTime': instance.scheduledTime.toIso8601String(),
      'status': _$ReminderStatusEnumMap[instance.status]!,
      'notificationId': instance.notificationId,
      'acknowledgedAt': instance.acknowledgedAt?.toIso8601String(),
      'snoozedUntil': instance.snoozedUntil?.toIso8601String(),
      'snoozeCount': instance.snoozeCount,
      'caregiverNotified': instance.caregiverNotified,
      'caregiverNotifiedAt': instance.caregiverNotifiedAt?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$ReminderStatusEnumMap = {
  ReminderStatus.pending: 'pending',
  ReminderStatus.acknowledged: 'acknowledged',
  ReminderStatus.snoozed: 'snoozed',
  ReminderStatus.expired: 'expired',
  ReminderStatus.taken: 'taken',
  ReminderStatus.skipped: 'skipped',
};

AdherenceAnalytics _$AdherenceAnalyticsFromJson(Map<String, dynamic> json) =>
    AdherenceAnalytics(
      medicationId:
          const StringOrIntConverter().fromJson(json['medicationId'] as Object),
      profileId:
          const StringOrIntConverter().fromJson(json['profileId'] as Object),
      period: $enumDecode(_$AdherencePeriodEnumMap, json['period']),
      adherencePercentage: (json['adherencePercentage'] as num).toDouble(),
      totalDoses: (json['totalDoses'] as num).toInt(),
      takenDoses: (json['takenDoses'] as num).toInt(),
      lateDoses: (json['lateDoses'] as num).toInt(),
      missedDoses: (json['missedDoses'] as num).toInt(),
      skippedDoses: (json['skippedDoses'] as num).toInt(),
      adherenceByDay: Map<String, int>.from(json['adherenceByDay'] as Map),
      adherenceByHour: (json['adherenceByHour'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(int.parse(k), (e as num).toInt()),
      ),
      patterns: (json['patterns'] as List<dynamic>)
          .map((e) => AdherencePattern.fromJson(e as Map<String, dynamic>))
          .toList(),
      calculatedAt: DateTime.parse(json['calculatedAt'] as String),
    );

Map<String, dynamic> _$AdherenceAnalyticsToJson(AdherenceAnalytics instance) =>
    <String, dynamic>{
      'medicationId':
          const StringOrIntConverter().toJson(instance.medicationId),
      'profileId': const StringOrIntConverter().toJson(instance.profileId),
      'period': _$AdherencePeriodEnumMap[instance.period]!,
      'adherencePercentage': instance.adherencePercentage,
      'totalDoses': instance.totalDoses,
      'takenDoses': instance.takenDoses,
      'lateDoses': instance.lateDoses,
      'missedDoses': instance.missedDoses,
      'skippedDoses': instance.skippedDoses,
      'adherenceByDay': instance.adherenceByDay,
      'adherenceByHour':
          instance.adherenceByHour.map((k, e) => MapEntry(k.toString(), e)),
      'patterns': instance.patterns,
      'calculatedAt': instance.calculatedAt.toIso8601String(),
    };

const _$AdherencePeriodEnumMap = {
  AdherencePeriod.sevenDays: '7_days',
  AdherencePeriod.thirtyDays: '30_days',
  AdherencePeriod.ninetyDays: '90_days',
};

AdherencePattern _$AdherencePatternFromJson(Map<String, dynamic> json) =>
    AdherencePattern(
      type: $enumDecode(_$PatternTypeEnumMap, json['type']),
      description: json['description'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      metadata: json['metadata'] as Map<String, dynamic>,
    );

Map<String, dynamic> _$AdherencePatternToJson(AdherencePattern instance) =>
    <String, dynamic>{
      'type': _$PatternTypeEnumMap[instance.type]!,
      'description': instance.description,
      'confidence': instance.confidence,
      'metadata': instance.metadata,
    };

const _$PatternTypeEnumMap = {
  PatternType.morningMissed: 'morning_missed',
  PatternType.weekendMissed: 'weekend_missed',
  PatternType.consistentlyLate: 'consistently_late',
  PatternType.frequentSnooze: 'frequent_snooze',
  PatternType.sideEffectCorrelation: 'side_effect_correlation',
};

SideEffectReport _$SideEffectReportFromJson(Map<String, dynamic> json) =>
    SideEffectReport(
      id: const StringOrIntConverter().fromJson(json['id'] as Object),
      medicationId:
          const StringOrIntConverter().fromJson(json['medicationId'] as Object),
      profileId:
          const StringOrIntConverter().fromJson(json['profileId'] as Object),
      doseEventId: _$JsonConverterFromJson<Object, String>(
          json['doseEventId'], const StringOrIntConverter().fromJson),
      severity: $enumDecode(_$SideEffectSeverityEnumMap, json['severity']),
      description: json['description'] as String,
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      timeSinceDose: json['timeSinceDose'] == null
          ? null
          : Duration(microseconds: (json['timeSinceDose'] as num).toInt()),
      symptoms:
          (json['symptoms'] as List<dynamic>).map((e) => e as String).toList(),
      notes: json['notes'] as String?,
      actionTaken: json['actionTaken'] as String?,
      reportedToProvider: json['reportedToProvider'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$SideEffectReportToJson(SideEffectReport instance) =>
    <String, dynamic>{
      'id': const StringOrIntConverter().toJson(instance.id),
      'medicationId':
          const StringOrIntConverter().toJson(instance.medicationId),
      'profileId': const StringOrIntConverter().toJson(instance.profileId),
      'doseEventId': _$JsonConverterToJson<Object, String>(
          instance.doseEventId, const StringOrIntConverter().toJson),
      'severity': _$SideEffectSeverityEnumMap[instance.severity]!,
      'description': instance.description,
      'occurredAt': instance.occurredAt.toIso8601String(),
      'timeSinceDose': instance.timeSinceDose?.inMicroseconds,
      'symptoms': instance.symptoms,
      'notes': instance.notes,
      'actionTaken': instance.actionTaken,
      'reportedToProvider': instance.reportedToProvider,
      'createdAt': instance.createdAt.toIso8601String(),
    };

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) =>
    json == null ? null : fromJson(json as Json);

const _$SideEffectSeverityEnumMap = {
  SideEffectSeverity.mild: 'mild',
  SideEffectSeverity.moderate: 'moderate',
  SideEffectSeverity.severe: 'severe',
};

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) =>
    value == null ? null : toJson(value);

MedicationInteraction _$MedicationInteractionFromJson(
        Map<String, dynamic> json) =>
    MedicationInteraction(
      id: const StringOrIntConverter().fromJson(json['id'] as Object),
      medicationIds: (json['medicationIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      severity: $enumDecode(_$InteractionSeverityEnumMap, json['severity']),
      description: json['description'] as String,
      recommendation: json['recommendation'] as String,
      symptoms:
          (json['symptoms'] as List<dynamic>).map((e) => e as String).toList(),
      source: json['source'] as String,
      isActive: json['isActive'] as bool,
      detectedAt: DateTime.parse(json['detectedAt'] as String),
    );

Map<String, dynamic> _$MedicationInteractionToJson(
        MedicationInteraction instance) =>
    <String, dynamic>{
      'id': const StringOrIntConverter().toJson(instance.id),
      'medicationIds': instance.medicationIds,
      'severity': _$InteractionSeverityEnumMap[instance.severity]!,
      'description': instance.description,
      'recommendation': instance.recommendation,
      'symptoms': instance.symptoms,
      'source': instance.source,
      'isActive': instance.isActive,
      'detectedAt': instance.detectedAt.toIso8601String(),
    };

const _$InteractionSeverityEnumMap = {
  InteractionSeverity.minor: 'minor',
  InteractionSeverity.moderate: 'moderate',
  InteractionSeverity.major: 'major',
};

CaregiverContact _$CaregiverContactFromJson(Map<String, dynamic> json) =>
    CaregiverContact(
      id: const StringOrIntConverter().fromJson(json['id'] as Object),
      profileId:
          const StringOrIntConverter().fromJson(json['profileId'] as Object),
      name: json['name'] as String,
      relationship: json['relationship'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      canReceiveReminders: json['canReceiveReminders'] as bool,
      canViewAdherence: json['canViewAdherence'] as bool,
      canEditMedications: json['canEditMedications'] as bool,
      preferredContactMethods:
          (json['preferredContactMethods'] as List<dynamic>)
              .map((e) => e as String)
              .toList(),
      isEmergencyContact: json['isEmergencyContact'] as bool,
      isActive: json['isActive'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$CaregiverContactToJson(CaregiverContact instance) =>
    <String, dynamic>{
      'id': const StringOrIntConverter().toJson(instance.id),
      'profileId': const StringOrIntConverter().toJson(instance.profileId),
      'name': instance.name,
      'relationship': instance.relationship,
      'phone': instance.phone,
      'email': instance.email,
      'canReceiveReminders': instance.canReceiveReminders,
      'canViewAdherence': instance.canViewAdherence,
      'canEditMedications': instance.canEditMedications,
      'preferredContactMethods': instance.preferredContactMethods,
      'isEmergencyContact': instance.isEmergencyContact,
      'isActive': instance.isActive,
      'createdAt': instance.createdAt.toIso8601String(),
    };

MedicationAuditLog _$MedicationAuditLogFromJson(Map<String, dynamic> json) =>
    MedicationAuditLog(
      id: const StringOrIntConverter().fromJson(json['id'] as Object),
      medicationId:
          const StringOrIntConverter().fromJson(json['medicationId'] as Object),
      profileId:
          const StringOrIntConverter().fromJson(json['profileId'] as Object),
      action: json['action'] as String,
      oldValues: json['oldValues'] as Map<String, dynamic>?,
      newValues: json['newValues'] as Map<String, dynamic>?,
      reason: json['reason'] as String?,
      performedBy: json['performedBy'] as String,
      ipAddress: json['ipAddress'] as String?,
      userAgent: json['userAgent'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$MedicationAuditLogToJson(MedicationAuditLog instance) =>
    <String, dynamic>{
      'id': const StringOrIntConverter().toJson(instance.id),
      'medicationId':
          const StringOrIntConverter().toJson(instance.medicationId),
      'profileId': const StringOrIntConverter().toJson(instance.profileId),
      'action': instance.action,
      'oldValues': instance.oldValues,
      'newValues': instance.newValues,
      'reason': instance.reason,
      'performedBy': instance.performedBy,
      'ipAddress': instance.ipAddress,
      'userAgent': instance.userAgent,
      'timestamp': instance.timestamp.toIso8601String(),
    };

MedicationVoiceIntent _$MedicationVoiceIntentFromJson(
        Map<String, dynamic> json) =>
    MedicationVoiceIntent(
      intent: json['intent'] as String,
      medicationName: json['medicationName'] as String?,
      timeExpression: json['timeExpression'] as String?,
      action: json['action'] as String?,
      parameters: json['parameters'] as Map<String, dynamic>,
      confidence: (json['confidence'] as num).toDouble(),
      rawText: json['rawText'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$MedicationVoiceIntentToJson(
        MedicationVoiceIntent instance) =>
    <String, dynamic>{
      'intent': instance.intent,
      'medicationName': instance.medicationName,
      'timeExpression': instance.timeExpression,
      'action': instance.action,
      'parameters': instance.parameters,
      'confidence': instance.confidence,
      'rawText': instance.rawText,
      'timestamp': instance.timestamp.toIso8601String(),
    };
