/// ============================================================================
/// MEDICATION MODELS
/// ============================================================================
/// Comprehensive data models for medication tracking and adherence monitoring.
///
/// This file contains all medication-related models:
/// - Medication: Core medication information (drug, dosage, schedule)
/// - MedicationSchedule: Timing configuration for doses
/// - DoseEvent: Individual dose tracking (taken, missed, skipped)
/// - MedicationReminder: Notification scheduling
/// - AdherenceAnalytics: Pattern analysis for reports
/// - SideEffectReport: Side effect tracking
/// - MedicationInteraction: Drug interaction alerts
///
/// JSON Serialization:
/// - Uses json_annotation package
/// - Run `flutter pub run build_runner build` to regenerate .g.dart files
///
/// Database Mapping:
/// - These models map to Django models in KinduraAPIs-0.0.1/medicines/models.py
/// - API endpoints: /api/medicines/, /api/dose-events/
///
/// @see /docs/DEVELOPER_GUIDE.md for full architecture documentation
/// ============================================================================

import 'package:json_annotation/json_annotation.dart';

part 'medication_models.g.dart';

// =============================================================================
// JSON CONVERTERS
// =============================================================================
// The API returns IDs as either int or String depending on context.
// These converters ensure consistent String handling in the app.

/// Converts API responses where ID can be int or String to always be String.
/// Required because Django REST framework sometimes returns int, sometimes String.
class StringOrIntConverter implements JsonConverter<String, Object> {
  const StringOrIntConverter();

  @override
  String fromJson(Object json) {
    if (json is String) return json;
    if (json is int) return json.toString();
    return json.toString();
  }

  @override
  Object toJson(String object) => object;
}

/// Nullable version for optional ID fields.
class NullableStringOrIntConverter implements JsonConverter<String?, Object?> {
  const NullableStringOrIntConverter();

  @override
  String? fromJson(Object? json) {
    if (json == null) return null;
    if (json is String) return json;
    if (json is int) return json.toString();
    return json.toString();
  }

  @override
  Object? toJson(String? object) => object;
}

// =============================================================================
// MEDICATION MODEL
// =============================================================================
// Core model representing a patient's medication.
// Maps to Django model: KinduraAPIs-0.0.1/medicines/models.py::Medicine

/// Represents a patient's medication with all tracking details.
///
/// Key features:
/// - Stores drug info (name, strength, form, route)
/// - Contains schedule configuration via [MedicationSchedule]
/// - Tracks missed dose policies for voice agent guidance
/// - Supports both prescription and OTC medications
///
/// Example usage:
/// ```dart
/// final medication = Medication.fromJson(apiResponse['result']);
/// print(medication.fullDescription); // "Metformin 500 mg (tablet)"
/// ```
@JsonSerializable()
class Medication {
  /// Unique identifier (from database)
  @StringOrIntConverter()
  final String id;

  /// Associated health profile ID (for multi-profile support)
  @NullableStringOrIntConverter()
  final String? profileId;

  /// Generic drug name (e.g., "Metformin", "Lisinopril")
  final String drugName;

  /// Brand name if available (e.g., "Glucophage")
  final String? brandName;

  /// Dosage form: tablet, capsule, liquid, injection, patch, inhaler, cream, drops
  final String form;

  /// Strength value (e.g., 500 for "500 mg")
  final double strength;

  /// Strength unit: mg, mcg, g, ml, units, percentage
  final String strengthUnit;

  /// Administration route: oral, sublingual, injection, topical, inhalation, etc.
  final String route;

  /// Detailed instructions for taking the medication
  final String instructionsText;

  /// Food requirement: true=with food, false=empty stomach, null=doesn't matter
  final bool? takeWithFood;

  /// PRN (as needed) medication flag
  final bool asNeeded;

  /// Policy when dose is missed - used by voice agent for guidance
  /// Values: skip_dose, take_asap, take_and_shift, contact_doctor, no_policy
  @JsonKey(defaultValue: 'no_policy')
  final String missedDoseAction;

  /// Schedule configuration (times, days, frequency)
  final MedicationSchedule schedule;

  /// When medication regimen starts
  final DateTime? startDate;

  /// When medication regimen ends (null = indefinite)
  final DateTime? endDate;

  /// Prescribing physician name
  final String? prescribedBy;

  /// Pharmacy name for refills
  final String? pharmacy;

  /// Prescription/RX number
  final String? rxNumber;

  /// Remaining refills count
  final int? refillsRemaining;

  /// Additional notes
  final String? notes;

  /// Active status - false means discontinued
  final bool isActive;

  /// Record creation timestamp
  final DateTime createdAt;

  /// Last update timestamp
  final DateTime updatedAt;

  /// Who created the record (patient, caregiver, doctor)
  final String? createdBy;

  const Medication({
    required this.id,
    this.profileId,
    required this.drugName,
    this.brandName,
    required this.form,
    required this.strength,
    required this.strengthUnit,
    required this.route,
    required this.instructionsText,
    this.takeWithFood,
    required this.asNeeded,
    this.missedDoseAction = 'no_policy',
    required this.schedule,
    this.startDate,
    this.endDate,
    this.prescribedBy,
    this.pharmacy,
    this.rxNumber,
    this.refillsRemaining,
    this.notes,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  String get displayName => brandName ?? drugName;

  String get strengthDisplay => '$strength $strengthUnit';

  String get fullDescription => '$displayName $strengthDisplay ($form)';

  bool get hasEndDate => endDate != null;

  Medication copyWith({
    String? id,
    String? profileId,
    String? drugName,
    String? brandName,
    String? form,
    double? strength,
    String? strengthUnit,
    String? route,
    String? instructionsText,
    bool? takeWithFood,
    bool? asNeeded,
    String? missedDoseAction,
    MedicationSchedule? schedule,
    DateTime? startDate,
    DateTime? endDate,
    String? prescribedBy,
    String? pharmacy,
    String? rxNumber,
    int? refillsRemaining,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return Medication(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      drugName: drugName ?? this.drugName,
      brandName: brandName ?? this.brandName,
      form: form ?? this.form,
      strength: strength ?? this.strength,
      strengthUnit: strengthUnit ?? this.strengthUnit,
      route: route ?? this.route,
      instructionsText: instructionsText ?? this.instructionsText,
      takeWithFood: takeWithFood ?? this.takeWithFood,
      asNeeded: asNeeded ?? this.asNeeded,
      missedDoseAction: missedDoseAction ?? this.missedDoseAction,
      schedule: schedule ?? this.schedule,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      prescribedBy: prescribedBy ?? this.prescribedBy,
      pharmacy: pharmacy ?? this.pharmacy,
      rxNumber: rxNumber ?? this.rxNumber,
      refillsRemaining: refillsRemaining ?? this.refillsRemaining,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      createdBy: createdBy ?? this.createdBy,
    );
  }
  
  bool get isExpired => endDate != null && DateTime.now().isAfter(endDate!);
  
  bool get needsRefill => refillsRemaining != null && refillsRemaining! <= 1;

  factory Medication.fromJson(Map<String, dynamic> json) => _$MedicationFromJson(json);
  Map<String, dynamic> toJson() => _$MedicationToJson(this);
}

// Medication schedule configuration
@JsonSerializable()
class MedicationSchedule {
  final List<String> times; // ["06:00", "12:00", "18:00"]
  final List<String>? days; // ["Mon", "Tue", "Wed"] - null means daily
  @JsonKey(defaultValue: MedicationFrequency.daily)
  final MedicationFrequency frequency;
  final int? intervalHours; // for "every X hours" scheduling
  final int? dosesPerDay;
  final String? timezone; // defaults to device timezone
  @JsonKey(defaultValue: false)
  final bool reminderEnabled;
  @JsonKey(defaultValue: 15)
  final int reminderMinutesBefore;
  @JsonKey(defaultValue: false)
  final bool caregiverEscalationEnabled;
  final String? caregiverContactId;

  const MedicationSchedule({
    required this.times,
    this.days,
    this.frequency = MedicationFrequency.daily,
    this.intervalHours,
    this.dosesPerDay,
    this.timezone,
    this.reminderEnabled = false,
    this.reminderMinutesBefore = 15,
    this.caregiverEscalationEnabled = false,
    this.caregiverContactId,
  });

  bool get isDailySchedule => days == null || days!.length == 7;
  
  List<String> get activeDays => days ?? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  
  int get totalDosesPerWeek {
    final daysCount = activeDays.length;
    return times.length * daysCount;
  }

  factory MedicationSchedule.fromJson(Map<String, dynamic> json) => _$MedicationScheduleFromJson(json);
  Map<String, dynamic> toJson() => _$MedicationScheduleToJson(this);
}

enum MedicationFrequency {
  @JsonValue('daily')
  daily,
  @JsonValue('weekly')
  weekly,
  @JsonValue('interval')
  interval, // every X hours
  @JsonValue('as_needed')
  asNeeded
}

// =============================================================================
// DOSE EVENT MODEL
// =============================================================================
// Tracks individual dose events (taken, missed, skipped, etc.)
// Maps to Django model: KinduraAPIs-0.0.1/medicines/models.py::MedicationEvent
//
// IMPORTANT: When comparing status, ALWAYS use enum values, not strings:
//   CORRECT:   event.status == DoseStatus.taken
//   INCORRECT: event.status == 'taken'  // This will ALWAYS be false!

/// Represents a single dose event for medication tracking.
///
/// Each scheduled dose creates a DoseEvent. The status is updated when:
/// - Patient marks dose as taken (via app or voice)
/// - System marks dose as missed (when time passes)
/// - Patient skips or snoozes the dose
///
/// Example usage:
/// ```dart
/// // Check if dose was taken (CORRECT way)
/// if (event.status == DoseStatus.taken || event.status == DoseStatus.late) {
///   print("Dose was taken");
/// }
///
/// // WRONG - don't compare with strings!
/// if (event.status == 'taken') { } // Always false!
/// ```
@JsonSerializable()
class DoseEvent {
  /// Unique identifier
  @StringOrIntConverter()
  final String id;

  /// Reference to the medication this dose is for
  @StringOrIntConverter()
  final String medicationId;

  /// Associated health profile
  @NullableStringOrIntConverter()
  final String? profileId;

  /// When the dose was scheduled to be taken
  final DateTime scheduledAt;

  /// When the dose was actually taken (null if not taken)
  final DateTime? takenAt;

  /// Current status of this dose - COMPARE WITH ENUM VALUES, NOT STRINGS!
  final DoseStatus status;

  /// Minutes late if taken after scheduled time
  final int? delayMinutes;

  /// Any side effects reported with this dose
  final String? sideEffectNote;

  /// Additional notes
  final String? notes;

  /// Actual dose taken if different from prescribed
  final double? actualDose;

  /// Unit for actual dose
  final String? actualUnit;

  /// How the dose was recorded: tap, voice, caregiver, auto
  final String? method;

  /// When this record was created
  final DateTime createdAt;

  /// When this record was last updated
  final DateTime? updatedAt;

  const DoseEvent({
    required this.id,
    required this.medicationId,
    this.profileId,
    required this.scheduledAt,
    this.takenAt,
    required this.status,
    this.delayMinutes,
    this.sideEffectNote,
    this.notes,
    this.actualDose,
    this.actualUnit,
    this.method,
    required this.createdAt,
    this.updatedAt,
  });

  bool get wasOnTime => delayMinutes == null || delayMinutes! <= 15;
  
  bool get wasLate => delayMinutes != null && delayMinutes! > 15;
  
  bool get wasTaken => [DoseStatus.taken, DoseStatus.late].contains(status);
  
  Duration? get delay => delayMinutes != null ? Duration(minutes: delayMinutes!) : null;

  factory DoseEvent.fromJson(Map<String, dynamic> json) => _$DoseEventFromJson(json);
  Map<String, dynamic> toJson() => _$DoseEventToJson(this);
}

// =============================================================================
// DOSE STATUS ENUM
// =============================================================================
// CRITICAL: Always compare using enum values, never strings!
//
// CORRECT:   if (event.status == DoseStatus.taken) { ... }
// INCORRECT: if (event.status == 'taken') { ... }  // NEVER WORKS!
//
// The @JsonValue annotation maps API string values to enum values.
// json_annotation handles the conversion automatically.

/// Status of a medication dose.
///
/// Lifecycle:
/// 1. scheduled → Initial state when dose is created
/// 2. snoozed → Patient postponed the reminder
/// 3. taken → Patient confirmed taking the dose on time
/// 4. late → Patient took the dose but after the grace period
/// 5. missed → Time passed and dose was never taken
/// 6. skipped → Patient intentionally skipped (with reason)
enum DoseStatus {
  /// Dose is scheduled but not yet due or confirmed
  @JsonValue('scheduled')
  scheduled,

  /// Dose was taken within the grace period (±15 minutes)
  @JsonValue('taken')
  taken,

  /// Dose was taken but after the grace period
  @JsonValue('late')
  late,

  /// Dose was not taken and grace period expired
  @JsonValue('missed')
  missed,

  /// Patient intentionally skipped this dose
  @JsonValue('skipped')
  skipped,

  /// Patient snoozed the reminder (will be asked again)
  @JsonValue('snoozed')
  snoozed
}

// Medication reminder
@JsonSerializable()
class MedicationReminder {
  @StringOrIntConverter()
  final String id;
  @StringOrIntConverter()
  final String medicationId;
  @StringOrIntConverter()
  final String profileId;
  final DateTime scheduledTime;
  final ReminderStatus status;
  final int notificationId;
  final DateTime? acknowledgedAt;
  final DateTime? snoozedUntil;
  final int snoozeCount;
  final bool caregiverNotified;
  final DateTime? caregiverNotifiedAt;
  final DateTime createdAt;

  const MedicationReminder({
    required this.id,
    required this.medicationId,
    required this.profileId,
    required this.scheduledTime,
    required this.status,
    required this.notificationId,
    this.acknowledgedAt,
    this.snoozedUntil,
    required this.snoozeCount,
    required this.caregiverNotified,
    this.caregiverNotifiedAt,
    required this.createdAt,
  });

  bool get isActive => [ReminderStatus.pending, ReminderStatus.snoozed].contains(status);
  
  bool get isOverdue => DateTime.now().isAfter(scheduledTime.add(Duration(minutes: 30)));
  
  Duration get timeSinceScheduled => DateTime.now().difference(scheduledTime);

  factory MedicationReminder.fromJson(Map<String, dynamic> json) => _$MedicationReminderFromJson(json);
  Map<String, dynamic> toJson() => _$MedicationReminderToJson(this);
}

enum ReminderStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('acknowledged')
  acknowledged,
  @JsonValue('snoozed')
  snoozed,
  @JsonValue('expired')
  expired,
  @JsonValue('taken')
  taken,
  @JsonValue('skipped')
  skipped
}

// Adherence analytics
@JsonSerializable()
class AdherenceAnalytics {
  @StringOrIntConverter()
  final String medicationId;
  @StringOrIntConverter()
  final String profileId;
  final AdherencePeriod period;
  final double adherencePercentage;
  final int totalDoses;
  final int takenDoses;
  final int lateDoses;
  final int missedDoses;
  final int skippedDoses;
  final Map<String, int> adherenceByDay; // day -> percentage
  final Map<int, int> adherenceByHour; // hour -> count
  final List<AdherencePattern> patterns;
  final DateTime calculatedAt;

  const AdherenceAnalytics({
    required this.medicationId,
    required this.profileId,
    required this.period,
    required this.adherencePercentage,
    required this.totalDoses,
    required this.takenDoses,
    required this.lateDoses,
    required this.missedDoses,
    required this.skippedDoses,
    required this.adherenceByDay,
    required this.adherenceByHour,
    required this.patterns,
    required this.calculatedAt,
  });

  bool get hasGoodAdherence => adherencePercentage >= 80.0;
  
  bool get needsImprovement => adherencePercentage < 70.0;
  
  String get adherenceGrade {
    if (adherencePercentage >= 95) return 'Excellent';
    if (adherencePercentage >= 85) return 'Good';
    if (adherencePercentage >= 70) return 'Fair';
    return 'Poor';
  }

  factory AdherenceAnalytics.fromJson(Map<String, dynamic> json) => _$AdherenceAnalyticsFromJson(json);
  Map<String, dynamic> toJson() => _$AdherenceAnalyticsToJson(this);
}

enum AdherencePeriod {
  @JsonValue('7_days')
  sevenDays,
  @JsonValue('30_days')
  thirtyDays,
  @JsonValue('90_days')
  ninetyDays
}

@JsonSerializable()
class AdherencePattern {
  final PatternType type;
  final String description;
  final double confidence;
  final Map<String, dynamic> metadata;

  const AdherencePattern({
    required this.type,
    required this.description,
    required this.confidence,
    required this.metadata,
  });

  factory AdherencePattern.fromJson(Map<String, dynamic> json) => _$AdherencePatternFromJson(json);
  Map<String, dynamic> toJson() => _$AdherencePatternToJson(this);
}

enum PatternType {
  @JsonValue('morning_missed')
  morningMissed,
  @JsonValue('weekend_missed')
  weekendMissed,
  @JsonValue('consistently_late')
  consistentlyLate,
  @JsonValue('frequent_snooze')
  frequentSnooze,
  @JsonValue('side_effect_correlation')
  sideEffectCorrelation
}

// Side effect tracking
@JsonSerializable()
class SideEffectReport {
  @StringOrIntConverter()
  final String id;
  @StringOrIntConverter()
  final String medicationId;
  @StringOrIntConverter()
  final String profileId;
  @StringOrIntConverter()
  final String? doseEventId;
  final SideEffectSeverity severity;
  final String description;
  final DateTime occurredAt;
  final Duration? timeSinceDose;
  final List<String> symptoms;
  final String? notes;
  final String? actionTaken;
  final bool reportedToProvider;
  final DateTime createdAt;

  const SideEffectReport({
    required this.id,
    required this.medicationId,
    required this.profileId,
    this.doseEventId,
    required this.severity,
    required this.description,
    required this.occurredAt,
    this.timeSinceDose,
    required this.symptoms,
    this.notes,
    this.actionTaken,
    required this.reportedToProvider,
    required this.createdAt,
  });

  bool get isSevere => severity == SideEffectSeverity.severe;
  
  bool get needsProviderAttention => isSevere || !reportedToProvider;

  factory SideEffectReport.fromJson(Map<String, dynamic> json) => _$SideEffectReportFromJson(json);
  Map<String, dynamic> toJson() => _$SideEffectReportToJson(this);
}

enum SideEffectSeverity {
  @JsonValue('mild')
  mild,
  @JsonValue('moderate')
  moderate,
  @JsonValue('severe')
  severe
}

// Medication interaction alert
@JsonSerializable()
class MedicationInteraction {
  @StringOrIntConverter()
  final String id;
  final List<String> medicationIds;
  final InteractionSeverity severity;
  final String description;
  final String recommendation;
  final List<String> symptoms;
  final String source; // drug database, clinical rules, etc.
  final bool isActive;
  final DateTime detectedAt;

  const MedicationInteraction({
    required this.id,
    required this.medicationIds,
    required this.severity,
    required this.description,
    required this.recommendation,
    required this.symptoms,
    required this.source,
    required this.isActive,
    required this.detectedAt,
  });

  bool get isCritical => severity == InteractionSeverity.major;
  
  bool get requiresProviderConsult => [InteractionSeverity.major, InteractionSeverity.moderate].contains(severity);

  factory MedicationInteraction.fromJson(Map<String, dynamic> json) => _$MedicationInteractionFromJson(json);
  Map<String, dynamic> toJson() => _$MedicationInteractionToJson(this);
}

enum InteractionSeverity {
  @JsonValue('minor')
  minor,
  @JsonValue('moderate')
  moderate,
  @JsonValue('major')
  major
}

// Caregiver contact
@JsonSerializable()
class CaregiverContact {
  @StringOrIntConverter()
  final String id;
  @StringOrIntConverter()
  final String profileId;
  final String name;
  final String? relationship;
  final String? phone;
  final String? email;
  final bool canReceiveReminders;
  final bool canViewAdherence;
  final bool canEditMedications;
  final List<String> preferredContactMethods;
  final bool isEmergencyContact;
  final bool isActive;
  final DateTime createdAt;

  const CaregiverContact({
    required this.id,
    required this.profileId,
    required this.name,
    this.relationship,
    this.phone,
    this.email,
    required this.canReceiveReminders,
    required this.canViewAdherence,
    required this.canEditMedications,
    required this.preferredContactMethods,
    required this.isEmergencyContact,
    required this.isActive,
    required this.createdAt,
  });

  bool get hasContactInfo => phone != null || email != null;
  
  String get displayName => relationship != null ? '$name ($relationship)' : name;

  factory CaregiverContact.fromJson(Map<String, dynamic> json) => _$CaregiverContactFromJson(json);
  Map<String, dynamic> toJson() => _$CaregiverContactToJson(this);
}

// Medication audit log
@JsonSerializable()
class MedicationAuditLog {
  @StringOrIntConverter()
  final String id;
  @StringOrIntConverter()
  final String medicationId;
  @StringOrIntConverter()
  final String profileId;
  final String action; // created, updated, deleted, dose_taken, etc.
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final String? reason;
  final String performedBy;
  final String? ipAddress;
  final String? userAgent;
  final DateTime timestamp;

  const MedicationAuditLog({
    required this.id,
    required this.medicationId,
    required this.profileId,
    required this.action,
    this.oldValues,
    this.newValues,
    this.reason,
    required this.performedBy,
    this.ipAddress,
    this.userAgent,
    required this.timestamp,
  });

  factory MedicationAuditLog.fromJson(Map<String, dynamic> json) => _$MedicationAuditLogFromJson(json);
  Map<String, dynamic> toJson() => _$MedicationAuditLogToJson(this);
}

// Voice command integration
@JsonSerializable()
class MedicationVoiceIntent {
  final String intent; // take_medication, snooze_reminder, skip_dose, etc.
  final String? medicationName;
  final String? timeExpression;
  final String? action;
  final Map<String, dynamic> parameters;
  final double confidence;
  final String rawText;
  final DateTime timestamp;

  const MedicationVoiceIntent({
    required this.intent,
    this.medicationName,
    this.timeExpression,
    this.action,
    required this.parameters,
    required this.confidence,
    required this.rawText,
    required this.timestamp,
  });

  bool get isHighConfidence => confidence >= 0.8;
  
  bool get needsConfirmation => confidence < 0.7;

  factory MedicationVoiceIntent.fromJson(Map<String, dynamic> json) => _$MedicationVoiceIntentFromJson(json);
  Map<String, dynamic> toJson() => _$MedicationVoiceIntentToJson(this);
}