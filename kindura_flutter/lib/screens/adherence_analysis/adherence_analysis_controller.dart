import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/repository/adherence_repository/adherence_repository.dart';
import 'package:kindura_ai/models/medication/adherence_analysis_model.dart';
import 'package:kindura_ai/data/response/api_response.dart';

class AdherenceAnalysisController extends GetxController {
  final _repository = AdherenceRepository();

  // Period selection
  final selectedPeriod = 'week'.obs;
  final periods = ['day', 'week', 'month'];

  // Data states
  final Rx<ApiResponse<MedicationHistoryResponse>> historyResponse =
      ApiResponse<MedicationHistoryResponse>.loading().obs;

  final Rx<ApiResponse<AIAdherenceInsight>> aiInsightResponse =
      ApiResponse<AIAdherenceInsight>.loading().obs;

  final Rx<ApiResponse<List<MedicationScheduleChange>>> scheduleChangesResponse =
      ApiResponse<List<MedicationScheduleChange>>.loading().obs;

  // UI state
  final isLoadingAnalysis = false.obs;
  final selectedTabIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
    fetchAllData();
  }

  void fetchAllData() {
    fetchMedicationHistory();
    fetchAIAnalysis();
    fetchScheduleChanges();
  }

  void onPeriodChanged(String period) {
    selectedPeriod.value = period;
    fetchAllData();
  }

  Future<void> fetchMedicationHistory() async {
    try {
      historyResponse.value = ApiResponse.loading();
      final result = await _repository.getMedicationHistory(
        period: selectedPeriod.value,
      );

      if (result != null) {
        historyResponse.value = ApiResponse.completed(result);
      } else {
        historyResponse.value = ApiResponse.error('No data available');
      }
    } catch (e) {
      historyResponse.value = ApiResponse.error(e.toString());
    }
  }

  Future<void> fetchAIAnalysis() async {
    try {
      aiInsightResponse.value = ApiResponse.loading();
      final result = await _repository.getAIAdherenceAnalysis(
        period: selectedPeriod.value,
      );

      if (result != null) {
        aiInsightResponse.value = ApiResponse.completed(result);
      } else {
        aiInsightResponse.value = ApiResponse.error('No AI analysis available');
      }
    } catch (e) {
      aiInsightResponse.value = ApiResponse.error(e.toString());
    }
  }

  Future<void> fetchScheduleChanges() async {
    try {
      scheduleChangesResponse.value = ApiResponse.loading();
      final result = await _repository.getScheduleChanges(
        period: selectedPeriod.value,
      );

      scheduleChangesResponse.value = ApiResponse.completed(result);
    } catch (e) {
      scheduleChangesResponse.value = ApiResponse.error(e.toString());
    }
  }

  Future<void> requestNewAnalysis() async {
    try {
      isLoadingAnalysis.value = true;
      final result = await _repository.requestNewAnalysis(
        period: selectedPeriod.value,
        includeVitals: true,
        includeLabs: true,
        includeSymptoms: true,
      );

      if (result != null) {
        aiInsightResponse.value = ApiResponse.completed(result);
        Get.snackbar(
          'Analysis Complete',
          'New AI analysis has been generated',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to generate analysis: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    } finally {
      isLoadingAnalysis.value = false;
    }
  }

  void setTabIndex(int index) {
    selectedTabIndex.value = index;
  }

  // Helper methods for UI
  Color getAdherenceColor(double percentage) {
    if (percentage >= 90) return Colors.green;
    if (percentage >= 70) return Colors.orange;
    return Colors.red;
  }

  String getAdherenceEmoji(double percentage) {
    if (percentage >= 95) return '🌟';
    if (percentage >= 85) return '✅';
    if (percentage >= 70) return '⚠️';
    return '❌';
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'taken':
        return Colors.green;
      case 'late':
        return Colors.orange;
      case 'missed':
        return Colors.red;
      case 'skipped':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'taken':
        return Icons.check_circle;
      case 'late':
        return Icons.access_time;
      case 'missed':
        return Icons.cancel;
      case 'skipped':
        return Icons.skip_next;
      default:
        return Icons.help;
    }
  }

  String formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hours hr';
    return '$hours hr $mins min';
  }
}
