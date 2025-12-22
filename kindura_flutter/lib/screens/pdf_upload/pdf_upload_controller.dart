import 'dart:io';
import 'package:get/get.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/res/routes/routes_name.dart';
import 'package:kindura_ai/utils/utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kindura_ai/repository/pdf_upload_repository/pdf_upload_repository.dart';
import 'package:kindura_ai/repository/medical_reports_repository/medical_reports_repository.dart';

class PdfUploadController extends GetxController {
  final PdfUploadRepository _pdfUploadRepository = PdfUploadRepository();
  final MedicalReportsRepository _medicalReportsRepository = MedicalReportsRepository();

  // Support both single and multiple file selection
  Rx<File?> selectedFile = Rx<File?>(null);
  RxString fileName = ''.obs;
  RxList<File> selectedFiles = <File>[].obs;
  RxList<String> fileNames = <String>[].obs;

  RxBool isUploading = false.obs;
  Rx<Status> requestStatus = Status.COMPLETED.obs;

  // Track upload progress
  RxInt uploadedCount = 0.obs;
  RxInt totalCount = 0.obs;

  void setRequestStatus(Status value) => requestStatus.value = value;

  Future<bool> pickPdfFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        // Store all selected files
        selectedFiles.value = result.files.map((file) => File(file.path!)).toList();
        fileNames.value = result.files.map((file) => file.name).toList();

        // Also store first file for backward compatibility
        selectedFile.value = selectedFiles.first;
        fileName.value = fileNames.first;

        // Reset progress counters
        uploadedCount.value = 0;
        totalCount.value = selectedFiles.length;

        return true;
      }
    } catch (e) {
      Util.Snack_Bar("Error", "Failed to pick file: $e");
    }
    return false;
  }

  Future<bool> uploadPdfFile() async {
    if (selectedFile.value == null) {
      Util.Snack_Bar("Warning", "Please select a PDF file first");
      return false;
    }

    setRequestStatus(Status.LOADING);
    isUploading.value = true;

    try {
      final response = await _pdfUploadRepository.uploadPdfFile(
        selectedFile.value!,
      );

      print("the response is ${response}");

      if (response['status'] == true) {
        Util.Snack_Bar("Success", "Your course is being uploaded");
        Get.toNamed(RoutesName.mainScreen);

        // Reset the form
        selectedFile.value = null;
        fileName.value = '';
        return true;
      } else {
        Util.Snack_Bar("Error", "Failed to upload file");
        return false;
      }
    } catch (e) {
      Util.Snack_Bar("Error", "Failed to upload file: $e");
      return false;
    } finally {
      isUploading.value = false;
      setRequestStatus(Status.COMPLETED);
    }
  }

  Future<bool> uploadMedicalDocument() async {
    if (selectedFile.value == null) {
      Util.Snack_Bar("Warning", "Please select a PDF file first");
      return false;
    }

    setRequestStatus(Status.LOADING);
    isUploading.value = true;

    try {
      print("📤 Uploading medical report to NEW AI-powered system...");
      print("File: ${selectedFile.value!.path}");

      // Use the NEW uploaded reports endpoint with AI processing
      final response = await _medicalReportsRepository.uploadReport(
        selectedFile.value!,
        reportDate: DateTime.now().toIso8601String().split('T')[0], // YYYY-MM-DD format
      );

      print("=" * 80);
      print("Medical document upload response: ${response}");
      print("=" * 80);

      if (response != null && response['status'] == true) {
        Util.Snack_Bar("Success", "Medical report uploaded and AI processing started!");

        // Reset the form
        selectedFile.value = null;
        fileName.value = '';
        return true;
      } else {
        final errorMsg = response?['message'] ?? response?['error'] ?? "Failed to upload medical document";
        Util.Snack_Bar("Error", errorMsg);
        print("❌ Upload failed: $errorMsg");
        return false;
      }
    } catch (e) {
      print("❌ Exception uploading medical document: $e");
      Util.Snack_Bar("Error", "Failed to upload medical document: $e");
      return false;
    } finally {
      isUploading.value = false;
      setRequestStatus(Status.COMPLETED);
    }
  }

  /// Upload multiple medical documents
  Future<bool> uploadMultipleMedicalDocuments() async {
    if (selectedFiles.isEmpty) {
      Util.Snack_Bar("Warning", "Please select at least one file");
      return false;
    }

    setRequestStatus(Status.LOADING);
    isUploading.value = true;
    uploadedCount.value = 0;
    totalCount.value = selectedFiles.length;

    int successCount = 0;
    int failedCount = 0;

    try {
      print("📤 Uploading ${selectedFiles.length} medical report(s)...");

      for (int i = 0; i < selectedFiles.length; i++) {
        final file = selectedFiles[i];
        final filename = fileNames[i];

        print("\n📄 Uploading file ${i + 1}/${selectedFiles.length}: $filename");

        try {
          final response = await _medicalReportsRepository.uploadReport(
            file,
            reportDate: DateTime.now().toIso8601String().split('T')[0],
          );

          if (response != null && response['status'] == true) {
            successCount++;
            uploadedCount.value = successCount;
            print("✅ Successfully uploaded: $filename");
          } else {
            failedCount++;
            final errorMsg = response?['message'] ?? response?['error'] ?? "Upload failed";
            print("❌ Failed to upload $filename: $errorMsg");
          }
        } catch (e) {
          failedCount++;
          print("❌ Exception uploading $filename: $e");
        }

        // Small delay between uploads to avoid overwhelming the server
        if (i < selectedFiles.length - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      print("\n" + "=" * 80);
      print("📊 Upload Summary:");
      print("   ✅ Success: $successCount");
      print("   ❌ Failed: $failedCount");
      print("   📁 Total: ${selectedFiles.length}");
      print("=" * 80);

      // Show result to user
      if (failedCount == 0) {
        Util.Snack_Bar("Success", "All $successCount report(s) uploaded successfully!");
      } else if (successCount == 0) {
        Util.Snack_Bar("Error", "All uploads failed");
      } else {
        Util.Snack_Bar("Partial Success", "$successCount uploaded, $failedCount failed");
      }

      // Reset the form if at least one succeeded
      if (successCount > 0) {
        clearSelection();
        return true;
      }

      return false;
    } catch (e) {
      print("❌ Exception in batch upload: $e");
      Util.Snack_Bar("Error", "Batch upload failed: $e");
      return false;
    } finally {
      isUploading.value = false;
      setRequestStatus(Status.COMPLETED);
    }
  }

  void clearSelection() {
    selectedFile.value = null;
    fileName.value = '';
    selectedFiles.clear();
    fileNames.clear();
    uploadedCount.value = 0;
    totalCount.value = 0;
  }
}
