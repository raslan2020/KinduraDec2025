import 'package:kindura_ai/data/network/network_api_services.dart';
import 'package:kindura_ai/res/app_url/app_url.dart';
import 'package:kindura_ai/models/medication/adherence_analysis_model.dart';

class AdherenceRepository {
  final _apiService = NetworkApiServices();

  /// Get medication history for a given period
  /// [period] can be 'day', 'week', 'month', or 'all'
  Future<MedicationHistoryResponse?> getMedicationHistory({
    String period = 'week',
    String? medicationId,
  }) async {
    try {
      String url = '${AppUrl.medicationHistoryUrl}?period=$period';
      if (medicationId != null) {
        url += '&medication_id=$medicationId';
      }

      final response = await _apiService.getApi(url);

      if (response['status'] == true && response['result'] != null) {
        return MedicationHistoryResponse.fromJson(response['result']);
      }
      return null;
    } catch (e) {
      print('Error fetching medication history: $e');
      rethrow;
    }
  }

  /// Get AI-powered adherence analysis
  /// Analyzes medication adherence along with vitals, labs, and other health data
  Future<AIAdherenceInsight?> getAIAdherenceAnalysis({
    String period = 'week',
  }) async {
    try {
      final url = '${AppUrl.adherenceAnalysisUrl}?period=$period';
      final response = await _apiService.getApi(url);

      if (response['status'] == true && response['result'] != null) {
        return AIAdherenceInsight.fromJson(response['result']);
      }
      return null;
    } catch (e) {
      print('Error fetching AI adherence analysis: $e');
      rethrow;
    }
  }

  /// Get medication schedule changes over time
  Future<List<MedicationScheduleChange>> getScheduleChanges({
    String period = 'month',
    String? medicationId,
  }) async {
    try {
      String url = '${AppUrl.scheduleChangesUrl}?period=$period';
      if (medicationId != null) {
        url += '&medication_id=$medicationId';
      }

      final response = await _apiService.getApi(url);

      if (response['status'] == true && response['result'] != null) {
        final List<dynamic> changesJson = response['result'];
        return changesJson
            .map((json) => MedicationScheduleChange.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching schedule changes: $e');
      rethrow;
    }
  }

  /// Request a new AI analysis (triggers OpenAI analysis)
  Future<AIAdherenceInsight?> requestNewAnalysis({
    String period = 'week',
    bool includeVitals = true,
    bool includeLabs = true,
    bool includeSymptoms = true,
  }) async {
    try {
      final response = await _apiService.postApi(
        {
          'period': period,
          'include_vitals': includeVitals,
          'include_labs': includeLabs,
          'include_symptoms': includeSymptoms,
        },
        AppUrl.adherenceAnalysisUrl,
      );

      if (response['status'] == true && response['result'] != null) {
        return AIAdherenceInsight.fromJson(response['result']);
      }
      return null;
    } catch (e) {
      print('Error requesting new analysis: $e');
      rethrow;
    }
  }
}
