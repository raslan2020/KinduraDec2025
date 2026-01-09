import 'dart:async';
import 'package:get/get.dart';
import '../data/network/network_api_services.dart';
import '../res/app_url/app_url.dart';

/// Service for managing background report generation with progress tracking.
/// This service persists across navigation and notifies when reports complete.
class ReportGenerationService extends GetxService {
  final NetworkApiServices _apiService = NetworkApiServices();

  // Observable state
  final RxBool isGenerating = false.obs;
  final RxInt progress = 0.obs;
  final RxString currentReportType = ''.obs;
  final Rxn<int> activeReportId = Rxn<int>();
  final RxString status = ''.obs;
  final RxString errorMessage = ''.obs;

  // Polling timer
  Timer? _statusPollingTimer;

  // Callbacks
  Function(int reportId, String reportType)? onReportCompleted;
  Function(String error)? onReportFailed;

  @override
  void onClose() {
    _statusPollingTimer?.cancel();
    super.onClose();
  }

  /// Start generating a report in the background
  /// Returns the report ID immediately
  Future<int?> generateReport(String reportType) async {
    // Don't start if already generating
    if (isGenerating.value) {
      return activeReportId.value;
    }

    try {
      isGenerating.value = true;
      currentReportType.value = reportType;
      progress.value = 0;
      status.value = 'processing';
      errorMessage.value = '';

      final response = await _apiService.postApi(
        {'report_type': reportType},
        AppUrl.generateReportAsyncUrl,
      );

      if (response != null && response['status'] == true) {
        final result = response['result'] ?? response;
        final reportId = result['report_id'] as int?;

        if (reportId != null) {
          activeReportId.value = reportId;
          progress.value = result['progress'] ?? 0;

          // Start polling for status
          _startStatusPolling(reportId);

          return reportId;
        }
      }

      // Failed to start
      isGenerating.value = false;
      status.value = 'failed';
      errorMessage.value = response?['message'] ?? 'Failed to start report generation';
      return null;
    } catch (e) {
      isGenerating.value = false;
      status.value = 'failed';
      errorMessage.value = e.toString();
      return null;
    }
  }

  /// Start polling for report status
  void _startStatusPolling(int reportId) {
    _statusPollingTimer?.cancel();

    _statusPollingTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkStatus(reportId),
    );
  }

  /// Check the status of the report
  Future<void> _checkStatus(int reportId) async {
    try {
      final response = await _apiService.getApi(
        AppUrl.reportStatusUrl(reportId),
      );

      if (response != null && response['status'] == true) {
        final result = response['result'] ?? response;
        final reportStatus = result['status'] as String? ?? 'processing';
        final reportProgress = result['progress'] as int? ?? 0;

        status.value = reportStatus;
        progress.value = reportProgress;

        if (reportStatus == 'completed') {
          _onComplete(reportId);
        } else if (reportStatus == 'failed') {
          errorMessage.value = result['error_message'] ?? 'Report generation failed';
          _onFailed();
        }
      }
    } catch (e) {
      // Continue polling on error - might be temporary
      print('Error checking report status: $e');
    }
  }

  /// Handle report completion
  void _onComplete(int reportId) {
    _statusPollingTimer?.cancel();
    isGenerating.value = false;

    // Call completion callback
    onReportCompleted?.call(reportId, currentReportType.value);

    // Show success notification
    Get.snackbar(
      '${_formatReportType(currentReportType.value)} Report Ready',
      'Your report has been generated successfully',
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 5),
    );
  }

  /// Handle report failure
  void _onFailed() {
    _statusPollingTimer?.cancel();
    isGenerating.value = false;

    // Call failure callback
    onReportFailed?.call(errorMessage.value);

    // Show error notification
    Get.snackbar(
      'Report Generation Failed',
      errorMessage.value,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 5),
    );
  }

  /// Cancel ongoing generation (stops polling, doesn't cancel backend)
  void cancelPolling() {
    _statusPollingTimer?.cancel();
    isGenerating.value = false;
    activeReportId.value = null;
    status.value = '';
    progress.value = 0;
  }

  /// Format report type for display
  String _formatReportType(String type) {
    switch (type.toLowerCase()) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      default:
        return type;
    }
  }

  /// Get display text for current progress
  String get progressText {
    if (!isGenerating.value) return '';

    final type = _formatReportType(currentReportType.value);
    return 'Generating $type Report... ${progress.value}%';
  }

  /// Check if a specific report type is currently generating
  bool isGeneratingType(String type) {
    return isGenerating.value && currentReportType.value == type;
  }
}
