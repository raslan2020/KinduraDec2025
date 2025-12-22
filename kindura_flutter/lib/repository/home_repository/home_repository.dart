import 'package:kindura_ai/data/network/network_api_services.dart';
import 'package:kindura_ai/res/app_url/app_url.dart';

class HomeRepository {
  final NetworkApiServices _apiServices = NetworkApiServices();

  Future<dynamic> courseListWithTime(String currentTime) async {
    return await _apiServices
        .getApi("${AppUrl.courseListUrl}?time=$currentTime");
  }

  Future<dynamic> userProfile() async {
    return await _apiServices.getApi(AppUrl.profileUrl);
  }

  Future<dynamic> livekitToken(var data) async {
    return await _apiServices.postApi(data, AppUrl.livekitTokenUrl);
  }

  Future<dynamic> deleteLivekitRoom(var data) async {
    return await _apiServices.postApi(data, AppUrl.deleteLivekitRoomUrl);
  }

  Future<dynamic> courseList() async {
    return await _apiServices.getApi(AppUrl.courseListUrl);
  }

  Future<dynamic> coursesList() async {
    return await _apiServices.getApi(AppUrl.coursesList);
  }

  Future<dynamic> deleteCourse(int courseId) async {
    return await _apiServices
        .deleteApi("${AppUrl.coursesList}${courseId.toString()}/");
  }

  Future<dynamic> getMedicalDocuments() async {
    // Use NEW uploaded-reports endpoint instead of legacy medical-documents
    return await _apiServices.getApi(AppUrl.uploadedReportsUrl);
  }

  Future<dynamic> deleteMedicalDocument(String documentId) async {
    // Use NEW uploaded-reports endpoint for deletion
    return await _apiServices
        .deleteApi(AppUrl.uploadedReportDetailsUrl(documentId));
  }

  // Watch Vitals
  Future<dynamic> getWatchVitals() async {
    return await _apiServices.getApi(AppUrl.watchVitalsUrl);
  }

  Future<dynamic> saveWatchVitals(var data) async {
    return await _apiServices.postApi(data, AppUrl.watchVitalsUrl);
  }
}
