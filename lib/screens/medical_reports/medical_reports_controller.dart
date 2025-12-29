import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/models/medical_reports/medical_report.dart';
import 'package:kindura_ai/models/medical_reports/medical_report_models.dart';
import 'package:kindura_ai/repository/medical_reports_repository/medical_reports_repository.dart';
import 'package:kindura_ai/utils/utils.dart';

class MedicalReportsController extends GetxController {
  final MedicalReportsRepository _medicalReportsRepository = MedicalReportsRepository();

  // Loading states
  final requestStatus = Status.COMPLETED.obs;
  final uploadStatus = Status.COMPLETED.obs;
  final parseStatus = Status.COMPLETED.obs;

  // Data - OLD SYSTEM
  final medicalReport = MedicalReport().obs;
  final vitalSigns = <VitalSigns>[].obs;
  final bloodTests = <BloodTest>[].obs;
  final medicalDocuments = <MedicalDocument>[].obs;

  // Data - NEW AI-POWERED SYSTEM
  final uploadedReports = <UploadedMedicalReport>[].obs;
  final pendingRecommendations = <MedicationRecommendation>[].obs;
  
  // Error handling
  RxString errors = ''.obs;
  
  // Selected tab
  final RxInt selectedTab = 0.obs;
  
  // Date filtering
  final RxString dateFilter = 'all'.obs; // 'all', 'week', 'month', 'year'

  @override
  void onInit() {
    super.onInit();
    loadMedicalReports();
    loadUploadedReports(); // Load NEW AI-powered reports
  }

  Future<void> loadMedicalReports() async {
    requestStatus.value = Status.LOADING;
    try {
      var response = await _medicalReportsRepository.getMedicalReports();

      if (response['status'] == true) {
        medicalReport.value = MedicalReport.fromJson(response);

        // Update individual lists with null safety
        final result = medicalReport.value.result;
        vitalSigns.value = result?.vitalSigns ?? [];
        bloodTests.value = result?.bloodTests ?? [];
        medicalDocuments.value = result?.documents ?? [];

        print('📊 [MEDICAL_REPORTS] Loaded successfully');
      } else {
        Util.Snack_Bar("Warning", "Failed to load medical reports");
      }
    } catch (error) {
      errors.value = error.toString();
      print('❌ [MEDICAL_REPORTS] Error loading reports: $error');
      Util.Snack_Bar("Error", "Failed to load medical reports");
    } finally {
      requestStatus.value = Status.COMPLETED;
    }
  }

  /// Load NEW AI-powered uploaded reports
  Future<void> loadUploadedReports() async {
    try {
      print("📋 Loading NEW uploaded medical reports...");
      var response = await _medicalReportsRepository.getUserReports();

      print("Uploaded reports response: $response");

      if (response != null && response['status'] == true) {
        final List<dynamic> resultList = response['result'] ?? [];
        uploadedReports.value = resultList
            .map((json) => UploadedMedicalReport.fromJson(json))
            .toList();

        print('✅ [UPLOADED_REPORTS] Loaded ${uploadedReports.length} reports');
      } else {
        print('⚠️ [UPLOADED_REPORTS] No reports found or error');
      }
    } catch (error) {
      print('❌ [UPLOADED_REPORTS] Error loading: $error');
    }
  }

  /// Load pending medication recommendations
  Future<void> loadPendingRecommendations() async {
    try {
      print("📋 Loading pending recommendations...");
      var response = await _medicalReportsRepository.getPendingRecommendations();

      if (response != null && response['status'] == true) {
        final List<dynamic> resultList = response['result'] ?? [];
        pendingRecommendations.value = resultList
            .map((json) => MedicationRecommendation.fromJson(json))
            .toList();

        print('✅ [RECOMMENDATIONS] Loaded ${pendingRecommendations.length} recommendations');
      }
    } catch (error) {
      print('❌ [RECOMMENDATIONS] Error loading: $error');
    }
  }

  /// Delete an uploaded report
  Future<void> deleteUploadedReport(String reportId) async {
    try {
      print("🗑️ Deleting report: $reportId");
      var response = await _medicalReportsRepository.deleteUploadedReport(reportId);

      if (response != null && response['status'] == true) {
        uploadedReports.removeWhere((report) => report.id == reportId);
        Util.Snack_Bar("Success", "Report deleted successfully");
        print("✅ Report deleted");
      } else {
        Util.Snack_Bar("Error", "Failed to delete report");
      }
    } catch (error) {
      print('❌ [DELETE_REPORT] Error: $error');
      Util.Snack_Bar("Error", "Failed to delete report");
    }
  }

  /// Apply medication recommendation
  Future<void> applyRecommendation(String recommendationId, {String? medicineId}) async {
    try {
      var response = await _medicalReportsRepository.applyRecommendation(
        recommendationId,
        medicineId: medicineId,
      );

      if (response != null && response['status'] == true) {
        Util.Snack_Bar("Success", "Medication recommendation applied");
        await loadPendingRecommendations(); // Refresh
      } else {
        Util.Snack_Bar("Error", "Failed to apply recommendation");
      }
    } catch (error) {
      print('❌ [APPLY_RECOMMENDATION] Error: $error');
      Util.Snack_Bar("Error", "Failed to apply recommendation");
    }
  }

  /// Dismiss medication recommendation
  Future<void> dismissRecommendation(String recommendationId, {String? reason}) async {
    try {
      var response = await _medicalReportsRepository.dismissRecommendation(
        recommendationId,
        reason: reason,
      );

      if (response != null && response['status'] == true) {
        Util.Snack_Bar("Success", "Recommendation dismissed");
        await loadPendingRecommendations(); // Refresh
      } else {
        Util.Snack_Bar("Error", "Failed to dismiss recommendation");
      }
    } catch (error) {
      print('❌ [DISMISS_RECOMMENDATION] Error: $error');
      Util.Snack_Bar("Error", "Failed to dismiss recommendation");
    }
  }

  Future<void> loadVitalSigns({String? dateFrom, String? dateTo}) async {
    try {
      var response = await _medicalReportsRepository.getVitalSigns(
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      
      if (response['status'] == true) {
        if (response['result']['vital_signs'] != null) {
          vitalSigns.value = (response['result']['vital_signs'] as List)
              .map((v) => VitalSigns.fromJson(v))
              .toList();
        }
      }
    } catch (error) {
      print('❌ [VITAL_SIGNS] Error loading: $error');
    }
  }

  Future<void> addVitalSigns({
    required String type,
    double? value,
    double? systolic,
    double? diastolic,
    String? unit,
    String? notes,
  }) async {
    try {
      Map<String, dynamic> data = {
        'type': type,
        'value': value,
        'systolic': systolic,
        'diastolic': diastolic,
        'unit': unit,
        'notes': notes,
        'recorded_at': DateTime.now().toIso8601String(),
      };

      var response = await _medicalReportsRepository.addVitalSigns(data);
      
      if (response['status'] == true) {
        Util.Snack_Bar("Success", "Vital signs added successfully");
        loadVitalSigns(); // Refresh the list
      } else {
        Util.Snack_Bar("Error", "Failed to add vital signs");
      }
    } catch (error) {
      print('❌ [VITAL_SIGNS] Error adding: $error');
      Util.Snack_Bar("Error", "Failed to add vital signs");
    }
  }

  Future<void> uploadMedicalDocument() async {
    // Show source picker dialog
    final source = await Get.dialog<String>(
      AlertDialog(
        title: const Text('Upload Medical Report'),
        content: const Text('Choose where to upload from:'),
        actions: [
          TextButton.icon(
            onPressed: () => Get.back(result: 'photos'),
            icon: const Icon(Icons.photo_library),
            label: const Text('Photo Library'),
          ),
          TextButton.icon(
            onPressed: () => Get.back(result: 'files'),
            icon: const Icon(Icons.folder),
            label: const Text('Files (PDF)'),
          ),
          TextButton(
            onPressed: () => Get.back(result: null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (source == null) return;

    uploadStatus.value = Status.LOADING;

    try {
      FilePickerResult? result;

      if (source == 'photos') {
        // Pick images from Photo Library
        result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: true,
        );
      } else {
        // Pick files from Files app (PDFs and images)
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic'],
          allowMultiple: true,
        );
      }

      if (result != null && result.files.isNotEmpty) {
        // Process each file (for multiple uploads)
        for (final file in result.files) {
          await _uploadReportWithAI(file);
        }
      }
    } catch (error) {
      print('❌ [DOCUMENT_UPLOAD] Error: $error');
      Util.Snack_Bar("Error", "Failed to pick file");
    } finally {
      uploadStatus.value = Status.COMPLETED;
    }
  }

  Future<void> _uploadReportWithAI(PlatformFile platformFile) async {
    if (platformFile.path == null) {
      Util.Snack_Bar("Error", "File path is not available");
      return;
    }

    try {
      Util.Snack_Bar("Uploading", "Processing medical document with AI...");

      File file = File(platformFile.path!);

      // Use NEW upload system with AI processing
      var response = await _medicalReportsRepository.uploadReport(file);

      if (response != null && response['status'] == true) {
        Util.Snack_Bar("Success", "Document uploaded and processed successfully");

        // Refresh both old and new reports
        await loadMedicalReports();
        await loadUploadedReports();
      } else {
        String errorMsg = response?['error'] ?? 'Failed to upload document';
        Util.Snack_Bar("Error", errorMsg);
      }
    } catch (error) {
      print('❌ [DOCUMENT_UPLOAD] Error uploading: $error');
      Util.Snack_Bar("Error", "Failed to upload document");
    }
  }

  Future<void> parseUploadedDocument(int documentId) async {
    parseStatus.value = Status.LOADING;
    
    try {
      var response = await _medicalReportsRepository.parseUploadedReport(documentId);
      
      if (response['status'] == true) {
        Util.Snack_Bar("Success", "Document parsed successfully");
        loadMedicalReports(); // Refresh to show new data
        
        print('🔍 [DOCUMENT_PARSE] Successfully parsed document $documentId');
      } else {
        Util.Snack_Bar("Warning", "Document uploaded but could not be parsed automatically");
      }
    } catch (error) {
      print('❌ [DOCUMENT_PARSE] Error parsing document: $error');
      Util.Snack_Bar("Warning", "Document uploaded but could not be parsed");
    } finally {
      parseStatus.value = Status.COMPLETED;
    }
  }

  void setSelectedTab(int index) {
    selectedTab.value = index;
  }

  void setDateFilter(String filter) {
    dateFilter.value = filter;
    
    DateTime now = DateTime.now();
    String? dateFrom;
    String? dateTo = now.toIso8601String();
    
    switch (filter) {
      case 'week':
        dateFrom = now.subtract(Duration(days: 7)).toIso8601String();
        break;
      case 'month':
        dateFrom = now.subtract(Duration(days: 30)).toIso8601String();
        break;
      case 'year':
        dateFrom = now.subtract(Duration(days: 365)).toIso8601String();
        break;
      default:
        dateFrom = null;
        dateTo = null;
    }
    
    // Reload data with filter
    loadVitalSigns(dateFrom: dateFrom, dateTo: dateTo);
  }

  List<VitalSigns> get filteredVitalSigns {
    List<VitalSigns> filtered = List.from(vitalSigns);

    // Sort by date (newest first) - handle null dates safely
    filtered.sort((a, b) {
      DateTime dateA = a.recordedAt ?? DateTime(1900);
      DateTime dateB = b.recordedAt ?? DateTime(1900);
      return dateB.compareTo(dateA);
    });

    return filtered;
  }

  List<BloodTest> get filteredBloodTests {
    List<BloodTest> filtered = List.from(bloodTests);

    // Sort by date (newest first) - handle null dates safely
    filtered.sort((a, b) {
      DateTime dateA = a.testDate ?? DateTime(1900);
      DateTime dateB = b.testDate ?? DateTime(1900);
      return dateB.compareTo(dateA);
    });

    return filtered;
  }

  // Quick add methods for common vital signs
  Future<void> quickAddBloodPressure(double systolic, double diastolic) async {
    await addVitalSigns(
      type: 'blood_pressure',
      systolic: systolic,
      diastolic: diastolic,
      unit: 'mmHg',
    );
  }

  Future<void> quickAddHeartRate(double heartRate) async {
    await addVitalSigns(
      type: 'heart_rate',
      value: heartRate,
      unit: 'bpm',
    );
  }

  Future<void> quickAddWeight(double weight) async {
    await addVitalSigns(
      type: 'weight',
      value: weight,
      unit: 'kg',
    );
  }

  Future<void> quickAddBloodSugar(double bloodSugar) async {
    await addVitalSigns(
      type: 'blood_sugar',
      value: bloodSugar,
      unit: 'mg/dL',
    );
  }
}