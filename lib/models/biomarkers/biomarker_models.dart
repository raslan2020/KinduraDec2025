import 'package:json_annotation/json_annotation.dart';

part 'biomarker_models.g.dart';

// Document table model for uploaded lab reports
@JsonSerializable()
class LabDocument {
  final String id;
  final String patientId;
  final String storagePath;
  final DocumentType type;
  final ProcessingStatus status;
  final DateTime uploadedAt;
  final DateTime? processedAt;
  final Map<String, dynamic>? summaryJson;
  final String? originalFileName;
  final int? fileSizeBytes;
  final String? mimeType;

  const LabDocument({
    required this.id,
    required this.patientId,
    required this.storagePath,
    required this.type,
    required this.status,
    required this.uploadedAt,
    this.processedAt,
    this.summaryJson,
    this.originalFileName,
    this.fileSizeBytes,
    this.mimeType,
  });

  factory LabDocument.fromJson(Map<String, dynamic> json) => _$LabDocumentFromJson(json);
  Map<String, dynamic> toJson() => _$LabDocumentToJson(this);
}

enum DocumentType {
  @JsonValue('lab')
  lab,
  @JsonValue('imaging')
  imaging,
  @JsonValue('pathology')
  pathology,
  @JsonValue('genetics')
  genetics,
  @JsonValue('other')
  other
}

enum ProcessingStatus {
  @JsonValue('uploaded')
  uploaded,
  @JsonValue('processing')
  processing,
  @JsonValue('parsed')
  parsed,
  @JsonValue('failed')
  failed,
  @JsonValue('manual_entry')
  manualEntry
}

// Observation/biomarker model
@JsonSerializable()
class Observation {
  final String id;
  final String patientId;
  final String? documentId;
  final String analyteName;
  final String? loincCode;
  final double? valueNum;
  final String? valueText;
  final String? unitOriginal;
  final String? unitUcum;
  final double? refLow;
  final double? refHigh;
  final String? refRange;
  final ResultStatus status;
  final DateTime collectedAt;
  final DateTime createdAt;
  final String? notes;
  final String? laboratoryName;

  const Observation({
    required this.id,
    required this.patientId,
    this.documentId,
    required this.analyteName,
    this.loincCode,
    this.valueNum,
    this.valueText,
    this.unitOriginal,
    this.unitUcum,
    this.refLow,
    this.refHigh,
    this.refRange,
    required this.status,
    required this.collectedAt,
    required this.createdAt,
    this.notes,
    this.laboratoryName,
  });

  String get displayValue {
    if (valueNum != null) {
      return '${valueNum!.toStringAsFixed(valueNum! % 1 == 0 ? 0 : 1)} ${unitOriginal ?? ''}';
    }
    return valueText ?? 'N/A';
  }

  factory Observation.fromJson(Map<String, dynamic> json) => _$ObservationFromJson(json);
  Map<String, dynamic> toJson() => _$ObservationToJson(this);
}

enum ResultStatus {
  @JsonValue('low')
  low,
  @JsonValue('normal')
  normal,
  @JsonValue('high')
  high,
  @JsonValue('critical_low')
  criticalLow,
  @JsonValue('critical_high')
  criticalHigh,
  @JsonValue('unknown')
  unknown
}

// Biomarker definition with LOINC mapping
@JsonSerializable()
class BiomarkerDefinition {
  final String id;
  final String name;
  final String? loincCode;
  final String category;
  final String? description;
  final String? clinicalSignificance;
  @JsonKey(defaultValue: [])
  final List<ReferenceRange> referenceRanges;
  final String? preferredUnit;
  @JsonKey(defaultValue: [])
  final List<String> alternativeNames;
  final CriticalThresholds? criticalThresholds;

  const BiomarkerDefinition({
    required this.id,
    required this.name,
    this.loincCode,
    required this.category,
    this.description,
    this.clinicalSignificance,
    this.referenceRanges = const [],
    this.preferredUnit,
    this.alternativeNames = const [],
    this.criticalThresholds,
  });

  factory BiomarkerDefinition.fromJson(Map<String, dynamic> json) => _$BiomarkerDefinitionFromJson(json);
  Map<String, dynamic> toJson() => _$BiomarkerDefinitionToJson(this);
}

@JsonSerializable()
class ReferenceRange {
  final String? ageGroup;
  final String? gender;
  final double? low;
  final double? high;
  final String unit;
  final String? population;

  const ReferenceRange({
    this.ageGroup,
    this.gender,
    this.low,
    this.high,
    required this.unit,
    this.population,
  });

  factory ReferenceRange.fromJson(Map<String, dynamic> json) => _$ReferenceRangeFromJson(json);
  Map<String, dynamic> toJson() => _$ReferenceRangeToJson(this);
}

@JsonSerializable()
class CriticalThresholds {
  final double? criticalLow;
  final double? criticalHigh;
  final String? urgentActionRequired;

  const CriticalThresholds({
    this.criticalLow,
    this.criticalHigh,
    this.urgentActionRequired,
  });

  factory CriticalThresholds.fromJson(Map<String, dynamic> json) => _$CriticalThresholdsFromJson(json);
  Map<String, dynamic> toJson() => _$CriticalThresholdsToJson(this);
}

// Biomarker with latest value and trend
@JsonSerializable()
class BiomarkerWithTrend {
  final BiomarkerDefinition definition;
  final Observation? latestObservation;
  @JsonKey(defaultValue: [])
  final List<Observation> recentObservations;
  final TrendDirection trendDirection;
  final double? trendPercentage;
  final int totalObservations;

  const BiomarkerWithTrend({
    required this.definition,
    this.latestObservation,
    this.recentObservations = const [],
    required this.trendDirection,
    this.trendPercentage,
    required this.totalObservations,
  });

  bool get hasData => latestObservation != null;
  
  String get categoryDisplayName {
    switch (definition.category.toLowerCase()) {
      case 'cardiovascular':
        return 'Heart Health';
      case 'metabolic':
        return 'Metabolism';
      case 'liver':
        return 'Liver Function';
      case 'kidney':
        return 'Kidney Function';
      case 'lipids':
        return 'Cholesterol & Lipids';
      case 'diabetes':
        return 'Blood Sugar';
      case 'thyroid':
        return 'Thyroid';
      case 'inflammation':
        return 'Inflammation';
      case 'nutrition':
        return 'Vitamins & Minerals';
      default:
        return definition.category;
    }
  }

  factory BiomarkerWithTrend.fromJson(Map<String, dynamic> json) => _$BiomarkerWithTrendFromJson(json);
  Map<String, dynamic> toJson() => _$BiomarkerWithTrendToJson(this);
}

enum TrendDirection {
  @JsonValue('improving')
  improving,
  @JsonValue('declining')
  declining,
  @JsonValue('stable')
  stable,
  @JsonValue('insufficient_data')
  insufficientData
}

// Health insight model
@JsonSerializable()
class HealthInsight {
  final String id;
  final String patientId;
  final String type;
  final InsightSeverity severity;
  final String title;
  final String description;
  final String actionRecommendation;
  final List<String> relatedBiomarkers;
  final DateTime createdAt;
  final DateTime? dismissedAt;
  final Map<String, dynamic>? metadata;

  const HealthInsight({
    required this.id,
    required this.patientId,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    required this.actionRecommendation,
    required this.relatedBiomarkers,
    required this.createdAt,
    this.dismissedAt,
    this.metadata,
  });

  bool get isActive => dismissedAt == null;

  factory HealthInsight.fromJson(Map<String, dynamic> json) => _$HealthInsightFromJson(json);
  Map<String, dynamic> toJson() => _$HealthInsightToJson(this);
}

enum InsightSeverity {
  @JsonValue('info')
  info,
  @JsonValue('warning')
  warning,
  @JsonValue('urgent')
  urgent,
  @JsonValue('critical')
  critical
}

// Lab processing result
@JsonSerializable()
class LabProcessingResult {
  final String documentId;
  final ProcessingStatus status;
  final List<ParsedAnalyte> extractedAnalytes;
  final String? errorMessage;
  final Map<String, dynamic>? metadata;
  final double confidenceScore;

  const LabProcessingResult({
    required this.documentId,
    required this.status,
    required this.extractedAnalytes,
    this.errorMessage,
    this.metadata,
    required this.confidenceScore,
  });

  factory LabProcessingResult.fromJson(Map<String, dynamic> json) => _$LabProcessingResultFromJson(json);
  Map<String, dynamic> toJson() => _$LabProcessingResultToJson(this);
}

@JsonSerializable()
class ParsedAnalyte {
  final String name;
  final String? value;
  final String? unit;
  final String? referenceRange;
  final DateTime? collectedDate;
  final double? mappingConfidence;
  final String? suggestedLoincCode;

  const ParsedAnalyte({
    required this.name,
    this.value,
    this.unit,
    this.referenceRange,
    this.collectedDate,
    this.mappingConfidence,
    this.suggestedLoincCode,
  });

  factory ParsedAnalyte.fromJson(Map<String, dynamic> json) => _$ParsedAnalyteFromJson(json);
  Map<String, dynamic> toJson() => _$ParsedAnalyteToJson(this);
}

// Lab summary for dashboard
@JsonSerializable()
class LabsSummary {
  final int totalBiomarkers;
  final int abnormalCount;
  final int criticalCount;
  final int recentTestsCount;
  final List<BiomarkerWithTrend> featuredBiomarkers;
  final List<HealthInsight> activeInsights;
  final DateTime lastUpdated;

  const LabsSummary({
    required this.totalBiomarkers,
    required this.abnormalCount,
    required this.criticalCount,
    required this.recentTestsCount,
    required this.featuredBiomarkers,
    required this.activeInsights,
    required this.lastUpdated,
  });

  factory LabsSummary.fromJson(Map<String, dynamic> json) => _$LabsSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$LabsSummaryToJson(this);
}

// AI-generated insights for a biomarker
@JsonSerializable()
class BiomarkerAiInsights {
  @JsonKey(name: 'clinical_significance')
  final ClinicalSignificanceInsight clinicalSignificance;

  @JsonKey(name: 'related_insights', defaultValue: [])
  final List<RelatedInsight> relatedInsights;

  @JsonKey(name: 'learn_more')
  final LearnMoreInsight learnMore;

  @JsonKey(defaultValue: [])
  final List<AiRecommendation> recommendations;

  const BiomarkerAiInsights({
    required this.clinicalSignificance,
    this.relatedInsights = const [],
    required this.learnMore,
    this.recommendations = const [],
  });

  factory BiomarkerAiInsights.fromJson(Map<String, dynamic> json) => _$BiomarkerAiInsightsFromJson(json);
  Map<String, dynamic> toJson() => _$BiomarkerAiInsightsToJson(this);
}

@JsonSerializable()
class ClinicalSignificanceInsight {
  final String summary;
  final String interpretation;
  final String severity;
  @JsonKey(name: 'trend_analysis')
  final String? trendAnalysis;

  const ClinicalSignificanceInsight({
    required this.summary,
    required this.interpretation,
    required this.severity,
    this.trendAnalysis,
  });

  factory ClinicalSignificanceInsight.fromJson(Map<String, dynamic> json) => _$ClinicalSignificanceInsightFromJson(json);
  Map<String, dynamic> toJson() => _$ClinicalSignificanceInsightToJson(this);
}

@JsonSerializable()
class RelatedInsight {
  final String title;
  final String description;
  final String type;
  final String priority;

  const RelatedInsight({
    required this.title,
    required this.description,
    required this.type,
    required this.priority,
  });

  factory RelatedInsight.fromJson(Map<String, dynamic> json) => _$RelatedInsightFromJson(json);
  Map<String, dynamic> toJson() => _$RelatedInsightToJson(this);
}

@JsonSerializable()
class LearnMoreInsight {
  @JsonKey(name: 'what_it_measures')
  final String whatItMeasures;

  @JsonKey(name: 'why_it_matters')
  final String whyItMatters;

  @JsonKey(name: 'factors_affecting', defaultValue: [])
  final List<String> factorsAffecting;

  @JsonKey(name: 'lifestyle_tips', defaultValue: [])
  final List<String> lifestyleTips;

  @JsonKey(name: 'when_to_seek_help')
  final String? whenToSeekHelp;

  const LearnMoreInsight({
    required this.whatItMeasures,
    required this.whyItMatters,
    this.factorsAffecting = const [],
    this.lifestyleTips = const [],
    this.whenToSeekHelp,
  });

  factory LearnMoreInsight.fromJson(Map<String, dynamic> json) => _$LearnMoreInsightFromJson(json);
  Map<String, dynamic> toJson() => _$LearnMoreInsightToJson(this);
}

@JsonSerializable()
class AiRecommendation {
  final String action;
  final String urgency;
  final String reason;

  const AiRecommendation({
    required this.action,
    required this.urgency,
    required this.reason,
  });

  factory AiRecommendation.fromJson(Map<String, dynamic> json) => _$AiRecommendationFromJson(json);
  Map<String, dynamic> toJson() => _$AiRecommendationToJson(this);
}

// Stored AI-generated health insight with research references
@JsonSerializable()
class StoredHealthInsight {
  final String id;
  final String biomarkerName;
  final String insightType;
  final String title;
  final String summary;
  final String detailedAnalysis;

  @JsonKey(defaultValue: [])
  final List<ResearchReference> researchReferences;
  final String? researchSummary;

  final double? biomarkerValue;
  final String? biomarkerUnit;
  final double? referenceMin;
  final double? referenceMax;
  final String? status;
  final double? deviationPercent;

  final String? trendDirection;
  final double? trendPercentage;
  final double? previousValue;

  final String severity;
  final String urgency;

  @JsonKey(defaultValue: [])
  final List<InsightRecommendation> recommendations;
  @JsonKey(defaultValue: [])
  final List<String> doctorDiscussionPoints;
  @JsonKey(defaultValue: [])
  final List<String> lifestyleTips;
  @JsonKey(defaultValue: [])
  final List<String> relatedBiomarkers;
  @JsonKey(defaultValue: [])
  final List<String> relatedMedications;

  final bool requiresDoctorVisit;
  final bool isRead;
  final bool isDismissed;
  final DateTime createdAt;
  final String? reportId;

  const StoredHealthInsight({
    required this.id,
    required this.biomarkerName,
    required this.insightType,
    required this.title,
    required this.summary,
    required this.detailedAnalysis,
    this.researchReferences = const [],
    this.researchSummary,
    this.biomarkerValue,
    this.biomarkerUnit,
    this.referenceMin,
    this.referenceMax,
    this.status,
    this.deviationPercent,
    this.trendDirection,
    this.trendPercentage,
    this.previousValue,
    required this.severity,
    required this.urgency,
    this.recommendations = const [],
    this.doctorDiscussionPoints = const [],
    this.lifestyleTips = const [],
    this.relatedBiomarkers = const [],
    this.relatedMedications = const [],
    required this.requiresDoctorVisit,
    required this.isRead,
    required this.isDismissed,
    required this.createdAt,
    this.reportId,
  });

  bool get isCritical => severity == 'critical';
  bool get isWarning => severity == 'warning';
  bool get isUrgent => urgency == 'immediate' || urgency == 'soon';

  factory StoredHealthInsight.fromJson(Map<String, dynamic> json) => _$StoredHealthInsightFromJson(json);
  Map<String, dynamic> toJson() => _$StoredHealthInsightToJson(this);
}

@JsonSerializable()
class ResearchReference {
  final String source;
  final String? year;
  final String finding;
  final String? relevance;

  const ResearchReference({
    required this.source,
    this.year,
    required this.finding,
    this.relevance,
  });

  factory ResearchReference.fromJson(Map<String, dynamic> json) => _$ResearchReferenceFromJson(json);
  Map<String, dynamic> toJson() => _$ResearchReferenceToJson(this);
}

@JsonSerializable()
class InsightRecommendation {
  final String action;
  final String priority;
  final String? timeframe;
  final String? rationale;

  const InsightRecommendation({
    required this.action,
    required this.priority,
    this.timeframe,
    this.rationale,
  });

  factory InsightRecommendation.fromJson(Map<String, dynamic> json) => _$InsightRecommendationFromJson(json);
  Map<String, dynamic> toJson() => _$InsightRecommendationToJson(this);
}

@JsonSerializable()
class StoredInsightsSummary {
  final int criticalCount;
  final int warningCount;
  final int unreadCount;
  final int requiresDoctorVisit;
  final bool hasCriticalItems;
  final bool hasWarningItems;

  const StoredInsightsSummary({
    required this.criticalCount,
    required this.warningCount,
    required this.unreadCount,
    required this.requiresDoctorVisit,
    required this.hasCriticalItems,
    required this.hasWarningItems,
  });

  factory StoredInsightsSummary.fromJson(Map<String, dynamic> json) => _$StoredInsightsSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$StoredInsightsSummaryToJson(this);
}

// Response wrapper for stored health insights API
class StoredHealthInsightsResponse {
  final List<StoredHealthInsight> insights;
  final StoredInsightsSummary summary;

  const StoredHealthInsightsResponse({
    required this.insights,
    required this.summary,
  });
}