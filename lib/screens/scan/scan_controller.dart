import 'package:get/get.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/models/courses_list/courses_list_model.dart';
import 'package:kindura_ai/repository/home_repository/home_repository.dart';
import 'package:kindura_ai/screens/home/home_controller.dart';
import 'package:kindura_ai/screens/pdf_upload/pdf_upload_controller.dart';
import 'package:kindura_ai/utils/utils.dart';

class ScanController extends GetxController {
  final HomeRepository _homeRepository = HomeRepository();
  late final PdfUploadController pdfUploadController;
  late final HomeController homeController;
  final requestStatus = Status.COMPLETED.obs;
  final uploadStatus = Status.COMPLETED.obs;
  final medicalDocuments = [].obs;  // Store medical documents
  RxString errors = ''.obs;

  @override
  void onInit() {
    super.onInit();
    // Initialize controllers in onInit to avoid issues during build phase
    pdfUploadController = Get.put(PdfUploadController(), tag: "homePdfUploadController");
    homeController = Get.find<HomeController>();
    getMedicalDocumentsList();  // Fetch medical documents on init
  }

  // Renamed to properly reflect its purpose
  Future<void> getMedicalDocumentsList() async {
    requestStatus.value = Status.LOADING;
    try {
      var value = await _homeRepository.getMedicalDocuments();
      print("Medical documents response: $value");
      if (value['status'] == true && value['result'] != null) {
        medicalDocuments.value = value['result'];
      }
    } catch (error) {
      errors.value = error.toString();
      print('Error fetching medical documents: $error');
    } finally {
      requestStatus.value = Status.COMPLETED;
    }
  }

  // Kept for backward compatibility with UI
  Future<void> getCourseList() async {
    await getMedicalDocumentsList();
  }

  Future<void> uploadMedicalReport() async {
    final result = await pdfUploadController.pickPdfFile();
    uploadStatus.value = Status.LOADING;
    if (result) {
      // Check if multiple files were selected
      bool uploadResult;
      if (pdfUploadController.selectedFiles.length > 1) {
        print("🔄 Uploading ${pdfUploadController.selectedFiles.length} files...");
        uploadResult = await pdfUploadController.uploadMultipleMedicalDocuments();
      } else {
        print("🔄 Uploading single file...");
        uploadResult = await pdfUploadController.uploadMedicalDocument();
      }

      if (uploadResult) {
        uploadStatus.value = Status.COMPLETED;
        await getMedicalDocumentsList();  // Refresh medical documents list
        homeController.homeApi();  // Refresh agent metadata with new documents
      }
    }
    uploadStatus.value = Status.COMPLETED;
  }

  // Kept for backward compatibility
  Future<void> uploadCoursePdf() async {
    await uploadMedicalReport();
  }

  Future<void> deleteMedicalDocument(String documentId) async {
    requestStatus.value = Status.LOADING;
    try {
      var value = await _homeRepository.deleteMedicalDocument(documentId);
      print("Delete medical document response: $value");
      if (value['status'] == true) {
        await getCourseList();  // Refresh the list
        homeController.homeApi();  // Refresh agent data
        Util.Snack_Bar("Success", "Document deleted successfully");
      } else {
        Util.Snack_Bar("Warning", "Failed to delete document");
      }
    } catch (error) {
      errors.value = error.toString();
      print('Error deleting medical document: $error');
      Util.Snack_Bar("Error", "Failed to delete document");
    } finally {
      requestStatus.value = Status.COMPLETED;
    }
  }
}
