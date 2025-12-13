// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'adherence_analysis_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MedicationHistoryResponse _$MedicationHistoryResponseFromJson(
        Map<String, dynamic> json) =>
    MedicationHistoryResponse(
      period: json['period'] as String,
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
      summary: MedicationHistorySummary.fromJson(
          json['summary'] as Map<String, dynamic>),
      byMedication: (json['by_medication'] as List<dynamic>)
          .map((e) => MedicationStats.fromJson(e as Map<String, dynamic>))
          .toList(),
      problematicMedications: (json['problematic_medications'] as List<dynamic>)
          .map((e) => MedicationStats.fromJson(e as Map<String, dynamic>))
          .toList(),
      events: (json['events'] as List<dynamic>)
          .map((e) => DoseEventDetail.fromJson(e as Map<String, dynamic>))
          .toList(),
      relatedSymptoms: (json['related_symptoms'] as List<dynamic>)
          .map((e) => RelatedSymptom.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$MedicationHistoryResponseToJson(
        MedicationHistoryResponse instance) =>
    <String, dynamic>{
      'period': instance.period,
      'start_date': instance.startDate,
      'end_date': instance.endDate,
      'summary': instance.summary,
      'by_medication': instance.byMedication,
      'problematic_medications': instance.problematicMedications,
      'events': instance.events,
      'related_symptoms': instance.relatedSymptoms,
    };

MedicationHistorySummary _$MedicationHistorySummaryFromJson(
        Map<String, dynamic> json) =>
    MedicationHistorySummary(
      totalEvents: (json['total_events'] as num).toInt(),
      taken: (json['taken'] as num).toInt(),
      late: (json['late'] as num).toInt(),
      missed: (json['missed'] as num).toInt(),
      skipped: (json['skipped'] as num).toInt(),
      overallAdherence: (json['overall_adherence'] as num).toDouble(),
    );

Map<String, dynamic> _$MedicationHistorySummaryToJson(
        MedicationHistorySummary instance) =>
    <String, dynamic>{
      'total_events': instance.totalEvents,
      'taken': instance.taken,
      'late': instance.late,
      'missed': instance.missed,
      'skipped': instance.skipped,
      'overall_adherence': instance.overallAdherence,
    };

MedicationStats _$MedicationStatsFromJson(Map<String, dynamic> json) =>
    MedicationStats(
      medicationId: (json['medication_id'] as num).toInt(),
      medicationName: json['medication_name'] as String,
      total: (json['total'] as num).toInt(),
      taken: (json['taken'] as num).toInt(),
      late: (json['late'] as num).toInt(),
      missed: (json['missed'] as num).toInt(),
      skipped: (json['skipped'] as num).toInt(),
      avgDelayMinutes: (json['avg_delay_minutes'] as num).toDouble(),
      adherencePercentage: (json['adherence_percentage'] as num).toDouble(),
    );

Map<String, dynamic> _$MedicationStatsToJson(MedicationStats instance) =>
    <String, dynamic>{
      'medication_id': instance.medicationId,
      'medication_name': instance.medicationName,
      'total': instance.total,
      'taken': instance.taken,
      'late': instance.late,
      'missed': instance.missed,
      'skipped': instance.skipped,
      'avg_delay_minutes': instance.avgDelayMinutes,
      'adherence_percentage': instance.adherencePercentage,
    };

DoseEventDetail _$DoseEventDetailFromJson(Map<String, dynamic> json) =>
    DoseEventDetail(
      id: (json['id'] as num).toInt(),
      medicationId: (json['medication_id'] as num).toInt(),
      medicationName: json['medication_name'] as String,
      strength: json['strength'] as String,
      scheduledAt: json['scheduled_at'] as String,
      takenAt: json['taken_at'] as String?,
      status: json['status'] as String,
      delayMinutes: (json['delay_minutes'] as num?)?.toInt(),
      sideEffectNote: json['side_effect_note'] as String?,
      source: json['source'] as String?,
    );

Map<String, dynamic> _$DoseEventDetailToJson(DoseEventDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'medication_id': instance.medicationId,
      'medication_name': instance.medicationName,
      'strength': instance.strength,
      'scheduled_at': instance.scheduledAt,
      'taken_at': instance.takenAt,
      'status': instance.status,
      'delay_minutes': instance.delayMinutes,
      'side_effect_note': instance.sideEffectNote,
      'source': instance.source,
    };

RelatedSymptom _$RelatedSymptomFromJson(Map<String, dynamic> json) =>
    RelatedSymptom(
      id: (json['id'] as num).toInt(),
      type: json['type'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      severity: json['severity'] as String,
      reportedAt: json['reported_at'] as String,
      medicationId: (json['medication_id'] as num?)?.toInt(),
    );

Map<String, dynamic> _$RelatedSymptomToJson(RelatedSymptom instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'title': instance.title,
      'description': instance.description,
      'severity': instance.severity,
      'reported_at': instance.reportedAt,
      'medication_id': instance.medicationId,
    };

AIAdherenceInsight _$AIAdherenceInsightFromJson(Map<String, dynamic> json) =>
    AIAdherenceInsight(
      analysisId: json['analysisId'] as String,
      analysisDate: json['analysisDate'] as String,
      period: json['period'] as String,
      overallAssessment: json['overallAssessment'] as String,
      sections: (json['sections'] as List<dynamic>)
          .map((e) => InsightSection.fromJson(e as Map<String, dynamic>))
          .toList(),
      recommendations: (json['recommendations'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      warnings:
          (json['warnings'] as List<dynamic>).map((e) => e as String).toList(),
      parkinsonsSpecificNotes: json['parkinsonsSpecificNotes'] as String?,
      confidenceScore: (json['confidenceScore'] as num).toDouble(),
    );

Map<String, dynamic> _$AIAdherenceInsightToJson(AIAdherenceInsight instance) =>
    <String, dynamic>{
      'analysisId': instance.analysisId,
      'analysisDate': instance.analysisDate,
      'period': instance.period,
      'overallAssessment': instance.overallAssessment,
      'sections': instance.sections,
      'recommendations': instance.recommendations,
      'warnings': instance.warnings,
      'parkinsonsSpecificNotes': instance.parkinsonsSpecificNotes,
      'confidenceScore': instance.confidenceScore,
    };

InsightSection _$InsightSectionFromJson(Map<String, dynamic> json) =>
    InsightSection(
      title: json['title'] as String,
      content: json['content'] as String,
      severity: json['severity'] as String?,
      bulletPoints: (json['bulletPoints'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$InsightSectionToJson(InsightSection instance) =>
    <String, dynamic>{
      'title': instance.title,
      'content': instance.content,
      'severity': instance.severity,
      'bulletPoints': instance.bulletPoints,
    };

MedicationScheduleChange _$MedicationScheduleChangeFromJson(
        Map<String, dynamic> json) =>
    MedicationScheduleChange(
      id: json['id'] as String,
      medicationId: json['medication_id'] as String,
      medicationName: json['medication_name'] as String,
      changeType: json['change_type'] as String,
      description: json['description'] as String?,
      previousValue: json['previous_value'] as String?,
      newValue: json['new_value'] as String?,
      changedAt: json['changed_at'] as String,
      changedBy: json['changed_by'] as String?,
    );

Map<String, dynamic> _$MedicationScheduleChangeToJson(
        MedicationScheduleChange instance) =>
    <String, dynamic>{
      'id': instance.id,
      'medication_id': instance.medicationId,
      'medication_name': instance.medicationName,
      'change_type': instance.changeType,
      'description': instance.description,
      'previous_value': instance.previousValue,
      'new_value': instance.newValue,
      'changed_at': instance.changedAt,
      'changed_by': instance.changedBy,
    };
