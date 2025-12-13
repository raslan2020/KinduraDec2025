import 'package:json_annotation/json_annotation.dart';

part 'adherence_analysis_model.g.dart';

/// Model for medication history response from API
@JsonSerializable(fieldRename: FieldRename.snake)
class MedicationHistoryResponse {
  final String period;
  final String startDate;
  final String endDate;
  final MedicationHistorySummary summary;
  final List<MedicationStats> byMedication;
  final List<MedicationStats> problematicMedications;
  final List<DoseEventDetail> events;
  final List<RelatedSymptom> relatedSymptoms;

  const MedicationHistoryResponse({
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.summary,
    required this.byMedication,
    required this.problematicMedications,
    required this.events,
    required this.relatedSymptoms,
  });

  factory MedicationHistoryResponse.fromJson(Map<String, dynamic> json) =>
      _$MedicationHistoryResponseFromJson(json);
  Map<String, dynamic> toJson() => _$MedicationHistoryResponseToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class MedicationHistorySummary {
  final int totalEvents;
  final int taken;
  final int late;
  final int missed;
  final int skipped;
  final double overallAdherence;

  const MedicationHistorySummary({
    required this.totalEvents,
    required this.taken,
    required this.late,
    required this.missed,
    required this.skipped,
    required this.overallAdherence,
  });

  /// Get adherence grade based on percentage
  String get adherenceGrade {
    if (overallAdherence >= 95) return 'Excellent';
    if (overallAdherence >= 85) return 'Good';
    if (overallAdherence >= 70) return 'Fair';
    return 'Needs Improvement';
  }

  factory MedicationHistorySummary.fromJson(Map<String, dynamic> json) =>
      _$MedicationHistorySummaryFromJson(json);
  Map<String, dynamic> toJson() => _$MedicationHistorySummaryToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class MedicationStats {
  final int medicationId;
  final String medicationName;
  final int total;
  final int taken;
  final int late;
  final int missed;
  final int skipped;
  final double avgDelayMinutes;
  final double adherencePercentage;

  const MedicationStats({
    required this.medicationId,
    required this.medicationName,
    required this.total,
    required this.taken,
    required this.late,
    required this.missed,
    required this.skipped,
    required this.avgDelayMinutes,
    required this.adherencePercentage,
  });

  bool get isProblematic => missed > 0 || late > 2;

  factory MedicationStats.fromJson(Map<String, dynamic> json) =>
      _$MedicationStatsFromJson(json);
  Map<String, dynamic> toJson() => _$MedicationStatsToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class DoseEventDetail {
  final int id;
  final int medicationId;
  final String medicationName;
  final String strength;
  final String scheduledAt;
  final String? takenAt;
  final String status;
  final int? delayMinutes;
  final String? sideEffectNote;
  final String? source;

  const DoseEventDetail({
    required this.id,
    required this.medicationId,
    required this.medicationName,
    required this.strength,
    required this.scheduledAt,
    this.takenAt,
    required this.status,
    this.delayMinutes,
    this.sideEffectNote,
    this.source,
  });

  DateTime get scheduledDateTime => DateTime.parse(scheduledAt);
  DateTime? get takenDateTime => takenAt != null ? DateTime.parse(takenAt!) : null;

  bool get wasTaken => status == 'taken' || status == 'late';
  bool get wasLate => status == 'late';
  bool get wasMissed => status == 'missed';

  factory DoseEventDetail.fromJson(Map<String, dynamic> json) =>
      _$DoseEventDetailFromJson(json);
  Map<String, dynamic> toJson() => _$DoseEventDetailToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class RelatedSymptom {
  final int id;
  final String type;
  final String title;
  final String description;
  final String severity;
  final String reportedAt;
  final int? medicationId;

  const RelatedSymptom({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.severity,
    required this.reportedAt,
    this.medicationId,
  });

  DateTime get reportedDateTime => DateTime.parse(reportedAt);

  factory RelatedSymptom.fromJson(Map<String, dynamic> json) =>
      _$RelatedSymptomFromJson(json);
  Map<String, dynamic> toJson() => _$RelatedSymptomToJson(this);
}

/// Model for AI-powered adherence analysis
@JsonSerializable()
class AIAdherenceInsight {
  final String analysisId;
  final String analysisDate;
  final String period;
  final String overallAssessment;
  final List<InsightSection> sections;
  final List<String> recommendations;
  final List<String> warnings;
  final String? parkinsonsSpecificNotes;
  final double confidenceScore;

  const AIAdherenceInsight({
    required this.analysisId,
    required this.analysisDate,
    required this.period,
    required this.overallAssessment,
    required this.sections,
    required this.recommendations,
    required this.warnings,
    this.parkinsonsSpecificNotes,
    required this.confidenceScore,
  });

  factory AIAdherenceInsight.fromJson(Map<String, dynamic> json) =>
      _$AIAdherenceInsightFromJson(json);
  Map<String, dynamic> toJson() => _$AIAdherenceInsightToJson(this);
}

@JsonSerializable()
class InsightSection {
  final String title;
  final String content;
  final String? severity; // info, warning, critical
  final List<String>? bulletPoints;

  const InsightSection({
    required this.title,
    required this.content,
    this.severity,
    this.bulletPoints,
  });

  factory InsightSection.fromJson(Map<String, dynamic> json) =>
      _$InsightSectionFromJson(json);
  Map<String, dynamic> toJson() => _$InsightSectionToJson(this);
}

/// Model for schedule changes over time
@JsonSerializable(fieldRename: FieldRename.snake)
class MedicationScheduleChange {
  final String id;
  final String medicationId;
  final String medicationName;
  final String changeType; // medication_added, medication_deactivated, dose_changed, time_changed, frequency_changed
  final String? description;
  final String? previousValue;
  final String? newValue;
  final String changedAt;
  final String? changedBy;

  const MedicationScheduleChange({
    required this.id,
    required this.medicationId,
    required this.medicationName,
    required this.changeType,
    this.description,
    this.previousValue,
    this.newValue,
    required this.changedAt,
    this.changedBy,
  });

  DateTime get changeDatetime => DateTime.parse(changedAt);

  String get changeDescription {
    if (description != null) return description!;
    switch (changeType) {
      case 'medication_added':
        return 'Medication added';
      case 'medication_deactivated':
        return 'Medication discontinued';
      case 'dose_changed':
        return 'Dosage changed';
      case 'time_changed':
        return 'Schedule time changed';
      case 'frequency_changed':
        return 'Frequency changed';
      default:
        return 'Medication updated';
    }
  }

  factory MedicationScheduleChange.fromJson(Map<String, dynamic> json) =>
      _$MedicationScheduleChangeFromJson(json);
  Map<String, dynamic> toJson() => _$MedicationScheduleChangeToJson(this);
}
