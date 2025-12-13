// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'biomarker_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LabDocument _$LabDocumentFromJson(Map<String, dynamic> json) => LabDocument(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      storagePath: json['storagePath'] as String,
      type: $enumDecode(_$DocumentTypeEnumMap, json['type']),
      status: $enumDecode(_$ProcessingStatusEnumMap, json['status']),
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
      processedAt: json['processedAt'] == null
          ? null
          : DateTime.parse(json['processedAt'] as String),
      summaryJson: json['summaryJson'] as Map<String, dynamic>?,
      originalFileName: json['originalFileName'] as String?,
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt(),
      mimeType: json['mimeType'] as String?,
    );

Map<String, dynamic> _$LabDocumentToJson(LabDocument instance) =>
    <String, dynamic>{
      'id': instance.id,
      'patientId': instance.patientId,
      'storagePath': instance.storagePath,
      'type': _$DocumentTypeEnumMap[instance.type]!,
      'status': _$ProcessingStatusEnumMap[instance.status]!,
      'uploadedAt': instance.uploadedAt.toIso8601String(),
      'processedAt': instance.processedAt?.toIso8601String(),
      'summaryJson': instance.summaryJson,
      'originalFileName': instance.originalFileName,
      'fileSizeBytes': instance.fileSizeBytes,
      'mimeType': instance.mimeType,
    };

const _$DocumentTypeEnumMap = {
  DocumentType.lab: 'lab',
  DocumentType.imaging: 'imaging',
  DocumentType.pathology: 'pathology',
  DocumentType.genetics: 'genetics',
  DocumentType.other: 'other',
};

const _$ProcessingStatusEnumMap = {
  ProcessingStatus.uploaded: 'uploaded',
  ProcessingStatus.processing: 'processing',
  ProcessingStatus.parsed: 'parsed',
  ProcessingStatus.failed: 'failed',
  ProcessingStatus.manualEntry: 'manual_entry',
};

Observation _$ObservationFromJson(Map<String, dynamic> json) => Observation(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      documentId: json['documentId'] as String?,
      analyteName: json['analyteName'] as String,
      loincCode: json['loincCode'] as String?,
      valueNum: (json['valueNum'] as num?)?.toDouble(),
      valueText: json['valueText'] as String?,
      unitOriginal: json['unitOriginal'] as String?,
      unitUcum: json['unitUcum'] as String?,
      refLow: (json['refLow'] as num?)?.toDouble(),
      refHigh: (json['refHigh'] as num?)?.toDouble(),
      refRange: json['refRange'] as String?,
      status: $enumDecode(_$ResultStatusEnumMap, json['status']),
      collectedAt: DateTime.parse(json['collectedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      notes: json['notes'] as String?,
      laboratoryName: json['laboratoryName'] as String?,
    );

Map<String, dynamic> _$ObservationToJson(Observation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'patientId': instance.patientId,
      'documentId': instance.documentId,
      'analyteName': instance.analyteName,
      'loincCode': instance.loincCode,
      'valueNum': instance.valueNum,
      'valueText': instance.valueText,
      'unitOriginal': instance.unitOriginal,
      'unitUcum': instance.unitUcum,
      'refLow': instance.refLow,
      'refHigh': instance.refHigh,
      'refRange': instance.refRange,
      'status': _$ResultStatusEnumMap[instance.status]!,
      'collectedAt': instance.collectedAt.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'notes': instance.notes,
      'laboratoryName': instance.laboratoryName,
    };

const _$ResultStatusEnumMap = {
  ResultStatus.low: 'low',
  ResultStatus.normal: 'normal',
  ResultStatus.high: 'high',
  ResultStatus.criticalLow: 'critical_low',
  ResultStatus.criticalHigh: 'critical_high',
  ResultStatus.unknown: 'unknown',
};

BiomarkerDefinition _$BiomarkerDefinitionFromJson(Map<String, dynamic> json) =>
    BiomarkerDefinition(
      id: json['id'] as String,
      name: json['name'] as String,
      loincCode: json['loincCode'] as String?,
      category: json['category'] as String,
      description: json['description'] as String?,
      clinicalSignificance: json['clinicalSignificance'] as String?,
      referenceRanges: (json['referenceRanges'] as List<dynamic>?)
              ?.map((e) => ReferenceRange.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      preferredUnit: json['preferredUnit'] as String?,
      alternativeNames: (json['alternativeNames'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      criticalThresholds: json['criticalThresholds'] == null
          ? null
          : CriticalThresholds.fromJson(
              json['criticalThresholds'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BiomarkerDefinitionToJson(
        BiomarkerDefinition instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'loincCode': instance.loincCode,
      'category': instance.category,
      'description': instance.description,
      'clinicalSignificance': instance.clinicalSignificance,
      'referenceRanges': instance.referenceRanges,
      'preferredUnit': instance.preferredUnit,
      'alternativeNames': instance.alternativeNames,
      'criticalThresholds': instance.criticalThresholds,
    };

ReferenceRange _$ReferenceRangeFromJson(Map<String, dynamic> json) =>
    ReferenceRange(
      ageGroup: json['ageGroup'] as String?,
      gender: json['gender'] as String?,
      low: (json['low'] as num?)?.toDouble(),
      high: (json['high'] as num?)?.toDouble(),
      unit: json['unit'] as String,
      population: json['population'] as String?,
    );

Map<String, dynamic> _$ReferenceRangeToJson(ReferenceRange instance) =>
    <String, dynamic>{
      'ageGroup': instance.ageGroup,
      'gender': instance.gender,
      'low': instance.low,
      'high': instance.high,
      'unit': instance.unit,
      'population': instance.population,
    };

CriticalThresholds _$CriticalThresholdsFromJson(Map<String, dynamic> json) =>
    CriticalThresholds(
      criticalLow: (json['criticalLow'] as num?)?.toDouble(),
      criticalHigh: (json['criticalHigh'] as num?)?.toDouble(),
      urgentActionRequired: json['urgentActionRequired'] as String?,
    );

Map<String, dynamic> _$CriticalThresholdsToJson(CriticalThresholds instance) =>
    <String, dynamic>{
      'criticalLow': instance.criticalLow,
      'criticalHigh': instance.criticalHigh,
      'urgentActionRequired': instance.urgentActionRequired,
    };

BiomarkerWithTrend _$BiomarkerWithTrendFromJson(Map<String, dynamic> json) =>
    BiomarkerWithTrend(
      definition: BiomarkerDefinition.fromJson(
          json['definition'] as Map<String, dynamic>),
      latestObservation: json['latestObservation'] == null
          ? null
          : Observation.fromJson(
              json['latestObservation'] as Map<String, dynamic>),
      recentObservations: (json['recentObservations'] as List<dynamic>?)
              ?.map((e) => Observation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      trendDirection:
          $enumDecode(_$TrendDirectionEnumMap, json['trendDirection']),
      trendPercentage: (json['trendPercentage'] as num?)?.toDouble(),
      totalObservations: (json['totalObservations'] as num).toInt(),
    );

Map<String, dynamic> _$BiomarkerWithTrendToJson(BiomarkerWithTrend instance) =>
    <String, dynamic>{
      'definition': instance.definition,
      'latestObservation': instance.latestObservation,
      'recentObservations': instance.recentObservations,
      'trendDirection': _$TrendDirectionEnumMap[instance.trendDirection]!,
      'trendPercentage': instance.trendPercentage,
      'totalObservations': instance.totalObservations,
    };

const _$TrendDirectionEnumMap = {
  TrendDirection.improving: 'improving',
  TrendDirection.declining: 'declining',
  TrendDirection.stable: 'stable',
  TrendDirection.insufficientData: 'insufficient_data',
};

HealthInsight _$HealthInsightFromJson(Map<String, dynamic> json) =>
    HealthInsight(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      type: json['type'] as String,
      severity: $enumDecode(_$InsightSeverityEnumMap, json['severity']),
      title: json['title'] as String,
      description: json['description'] as String,
      actionRecommendation: json['actionRecommendation'] as String,
      relatedBiomarkers: (json['relatedBiomarkers'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      dismissedAt: json['dismissedAt'] == null
          ? null
          : DateTime.parse(json['dismissedAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$HealthInsightToJson(HealthInsight instance) =>
    <String, dynamic>{
      'id': instance.id,
      'patientId': instance.patientId,
      'type': instance.type,
      'severity': _$InsightSeverityEnumMap[instance.severity]!,
      'title': instance.title,
      'description': instance.description,
      'actionRecommendation': instance.actionRecommendation,
      'relatedBiomarkers': instance.relatedBiomarkers,
      'createdAt': instance.createdAt.toIso8601String(),
      'dismissedAt': instance.dismissedAt?.toIso8601String(),
      'metadata': instance.metadata,
    };

const _$InsightSeverityEnumMap = {
  InsightSeverity.info: 'info',
  InsightSeverity.warning: 'warning',
  InsightSeverity.urgent: 'urgent',
  InsightSeverity.critical: 'critical',
};

LabProcessingResult _$LabProcessingResultFromJson(Map<String, dynamic> json) =>
    LabProcessingResult(
      documentId: json['documentId'] as String,
      status: $enumDecode(_$ProcessingStatusEnumMap, json['status']),
      extractedAnalytes: (json['extractedAnalytes'] as List<dynamic>)
          .map((e) => ParsedAnalyte.fromJson(e as Map<String, dynamic>))
          .toList(),
      errorMessage: json['errorMessage'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      confidenceScore: (json['confidenceScore'] as num).toDouble(),
    );

Map<String, dynamic> _$LabProcessingResultToJson(
        LabProcessingResult instance) =>
    <String, dynamic>{
      'documentId': instance.documentId,
      'status': _$ProcessingStatusEnumMap[instance.status]!,
      'extractedAnalytes': instance.extractedAnalytes,
      'errorMessage': instance.errorMessage,
      'metadata': instance.metadata,
      'confidenceScore': instance.confidenceScore,
    };

ParsedAnalyte _$ParsedAnalyteFromJson(Map<String, dynamic> json) =>
    ParsedAnalyte(
      name: json['name'] as String,
      value: json['value'] as String?,
      unit: json['unit'] as String?,
      referenceRange: json['referenceRange'] as String?,
      collectedDate: json['collectedDate'] == null
          ? null
          : DateTime.parse(json['collectedDate'] as String),
      mappingConfidence: (json['mappingConfidence'] as num?)?.toDouble(),
      suggestedLoincCode: json['suggestedLoincCode'] as String?,
    );

Map<String, dynamic> _$ParsedAnalyteToJson(ParsedAnalyte instance) =>
    <String, dynamic>{
      'name': instance.name,
      'value': instance.value,
      'unit': instance.unit,
      'referenceRange': instance.referenceRange,
      'collectedDate': instance.collectedDate?.toIso8601String(),
      'mappingConfidence': instance.mappingConfidence,
      'suggestedLoincCode': instance.suggestedLoincCode,
    };

LabsSummary _$LabsSummaryFromJson(Map<String, dynamic> json) => LabsSummary(
      totalBiomarkers: (json['totalBiomarkers'] as num).toInt(),
      abnormalCount: (json['abnormalCount'] as num).toInt(),
      criticalCount: (json['criticalCount'] as num).toInt(),
      recentTestsCount: (json['recentTestsCount'] as num).toInt(),
      featuredBiomarkers: (json['featuredBiomarkers'] as List<dynamic>)
          .map((e) => BiomarkerWithTrend.fromJson(e as Map<String, dynamic>))
          .toList(),
      activeInsights: (json['activeInsights'] as List<dynamic>)
          .map((e) => HealthInsight.fromJson(e as Map<String, dynamic>))
          .toList(),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );

Map<String, dynamic> _$LabsSummaryToJson(LabsSummary instance) =>
    <String, dynamic>{
      'totalBiomarkers': instance.totalBiomarkers,
      'abnormalCount': instance.abnormalCount,
      'criticalCount': instance.criticalCount,
      'recentTestsCount': instance.recentTestsCount,
      'featuredBiomarkers': instance.featuredBiomarkers,
      'activeInsights': instance.activeInsights,
      'lastUpdated': instance.lastUpdated.toIso8601String(),
    };

BiomarkerAiInsights _$BiomarkerAiInsightsFromJson(Map<String, dynamic> json) =>
    BiomarkerAiInsights(
      clinicalSignificance: ClinicalSignificanceInsight.fromJson(
          json['clinical_significance'] as Map<String, dynamic>),
      relatedInsights: (json['related_insights'] as List<dynamic>?)
              ?.map((e) => RelatedInsight.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      learnMore:
          LearnMoreInsight.fromJson(json['learn_more'] as Map<String, dynamic>),
      recommendations: (json['recommendations'] as List<dynamic>?)
              ?.map((e) => AiRecommendation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$BiomarkerAiInsightsToJson(
        BiomarkerAiInsights instance) =>
    <String, dynamic>{
      'clinical_significance': instance.clinicalSignificance,
      'related_insights': instance.relatedInsights,
      'learn_more': instance.learnMore,
      'recommendations': instance.recommendations,
    };

ClinicalSignificanceInsight _$ClinicalSignificanceInsightFromJson(
        Map<String, dynamic> json) =>
    ClinicalSignificanceInsight(
      summary: json['summary'] as String,
      interpretation: json['interpretation'] as String,
      severity: json['severity'] as String,
      trendAnalysis: json['trend_analysis'] as String?,
    );

Map<String, dynamic> _$ClinicalSignificanceInsightToJson(
        ClinicalSignificanceInsight instance) =>
    <String, dynamic>{
      'summary': instance.summary,
      'interpretation': instance.interpretation,
      'severity': instance.severity,
      'trend_analysis': instance.trendAnalysis,
    };

RelatedInsight _$RelatedInsightFromJson(Map<String, dynamic> json) =>
    RelatedInsight(
      title: json['title'] as String,
      description: json['description'] as String,
      type: json['type'] as String,
      priority: json['priority'] as String,
    );

Map<String, dynamic> _$RelatedInsightToJson(RelatedInsight instance) =>
    <String, dynamic>{
      'title': instance.title,
      'description': instance.description,
      'type': instance.type,
      'priority': instance.priority,
    };

LearnMoreInsight _$LearnMoreInsightFromJson(Map<String, dynamic> json) =>
    LearnMoreInsight(
      whatItMeasures: json['what_it_measures'] as String,
      whyItMatters: json['why_it_matters'] as String,
      factorsAffecting: (json['factors_affecting'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      lifestyleTips: (json['lifestyle_tips'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      whenToSeekHelp: json['when_to_seek_help'] as String?,
    );

Map<String, dynamic> _$LearnMoreInsightToJson(LearnMoreInsight instance) =>
    <String, dynamic>{
      'what_it_measures': instance.whatItMeasures,
      'why_it_matters': instance.whyItMatters,
      'factors_affecting': instance.factorsAffecting,
      'lifestyle_tips': instance.lifestyleTips,
      'when_to_seek_help': instance.whenToSeekHelp,
    };

AiRecommendation _$AiRecommendationFromJson(Map<String, dynamic> json) =>
    AiRecommendation(
      action: json['action'] as String,
      urgency: json['urgency'] as String,
      reason: json['reason'] as String,
    );

Map<String, dynamic> _$AiRecommendationToJson(AiRecommendation instance) =>
    <String, dynamic>{
      'action': instance.action,
      'urgency': instance.urgency,
      'reason': instance.reason,
    };

StoredHealthInsight _$StoredHealthInsightFromJson(Map<String, dynamic> json) =>
    StoredHealthInsight(
      id: json['id'] as String,
      biomarkerName: json['biomarkerName'] as String,
      insightType: json['insightType'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      detailedAnalysis: json['detailedAnalysis'] as String,
      researchReferences: (json['researchReferences'] as List<dynamic>?)
              ?.map(
                  (e) => ResearchReference.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      researchSummary: json['researchSummary'] as String?,
      biomarkerValue: (json['biomarkerValue'] as num?)?.toDouble(),
      biomarkerUnit: json['biomarkerUnit'] as String?,
      referenceMin: (json['referenceMin'] as num?)?.toDouble(),
      referenceMax: (json['referenceMax'] as num?)?.toDouble(),
      status: json['status'] as String?,
      deviationPercent: (json['deviationPercent'] as num?)?.toDouble(),
      trendDirection: json['trendDirection'] as String?,
      trendPercentage: (json['trendPercentage'] as num?)?.toDouble(),
      previousValue: (json['previousValue'] as num?)?.toDouble(),
      severity: json['severity'] as String,
      urgency: json['urgency'] as String,
      recommendations: (json['recommendations'] as List<dynamic>?)
              ?.map((e) =>
                  InsightRecommendation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      doctorDiscussionPoints: (json['doctorDiscussionPoints'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      lifestyleTips: (json['lifestyleTips'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      relatedBiomarkers: (json['relatedBiomarkers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      relatedMedications: (json['relatedMedications'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      requiresDoctorVisit: json['requiresDoctorVisit'] as bool,
      isRead: json['isRead'] as bool,
      isDismissed: json['isDismissed'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      reportId: json['reportId'] as String?,
    );

Map<String, dynamic> _$StoredHealthInsightToJson(
        StoredHealthInsight instance) =>
    <String, dynamic>{
      'id': instance.id,
      'biomarkerName': instance.biomarkerName,
      'insightType': instance.insightType,
      'title': instance.title,
      'summary': instance.summary,
      'detailedAnalysis': instance.detailedAnalysis,
      'researchReferences': instance.researchReferences,
      'researchSummary': instance.researchSummary,
      'biomarkerValue': instance.biomarkerValue,
      'biomarkerUnit': instance.biomarkerUnit,
      'referenceMin': instance.referenceMin,
      'referenceMax': instance.referenceMax,
      'status': instance.status,
      'deviationPercent': instance.deviationPercent,
      'trendDirection': instance.trendDirection,
      'trendPercentage': instance.trendPercentage,
      'previousValue': instance.previousValue,
      'severity': instance.severity,
      'urgency': instance.urgency,
      'recommendations': instance.recommendations,
      'doctorDiscussionPoints': instance.doctorDiscussionPoints,
      'lifestyleTips': instance.lifestyleTips,
      'relatedBiomarkers': instance.relatedBiomarkers,
      'relatedMedications': instance.relatedMedications,
      'requiresDoctorVisit': instance.requiresDoctorVisit,
      'isRead': instance.isRead,
      'isDismissed': instance.isDismissed,
      'createdAt': instance.createdAt.toIso8601String(),
      'reportId': instance.reportId,
    };

ResearchReference _$ResearchReferenceFromJson(Map<String, dynamic> json) =>
    ResearchReference(
      source: json['source'] as String,
      year: json['year'] as String?,
      finding: json['finding'] as String,
      relevance: json['relevance'] as String?,
    );

Map<String, dynamic> _$ResearchReferenceToJson(ResearchReference instance) =>
    <String, dynamic>{
      'source': instance.source,
      'year': instance.year,
      'finding': instance.finding,
      'relevance': instance.relevance,
    };

InsightRecommendation _$InsightRecommendationFromJson(
        Map<String, dynamic> json) =>
    InsightRecommendation(
      action: json['action'] as String,
      priority: json['priority'] as String,
      timeframe: json['timeframe'] as String?,
      rationale: json['rationale'] as String?,
    );

Map<String, dynamic> _$InsightRecommendationToJson(
        InsightRecommendation instance) =>
    <String, dynamic>{
      'action': instance.action,
      'priority': instance.priority,
      'timeframe': instance.timeframe,
      'rationale': instance.rationale,
    };

StoredInsightsSummary _$StoredInsightsSummaryFromJson(
        Map<String, dynamic> json) =>
    StoredInsightsSummary(
      criticalCount: (json['criticalCount'] as num).toInt(),
      warningCount: (json['warningCount'] as num).toInt(),
      unreadCount: (json['unreadCount'] as num).toInt(),
      requiresDoctorVisit: (json['requiresDoctorVisit'] as num).toInt(),
      hasCriticalItems: json['hasCriticalItems'] as bool,
      hasWarningItems: json['hasWarningItems'] as bool,
    );

Map<String, dynamic> _$StoredInsightsSummaryToJson(
        StoredInsightsSummary instance) =>
    <String, dynamic>{
      'criticalCount': instance.criticalCount,
      'warningCount': instance.warningCount,
      'unreadCount': instance.unreadCount,
      'requiresDoctorVisit': instance.requiresDoctorVisit,
      'hasCriticalItems': instance.hasCriticalItems,
      'hasWarningItems': instance.hasWarningItems,
    };
