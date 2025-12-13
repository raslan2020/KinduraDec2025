import 'package:kindura_ai/data/network/network_api_services.dart';

import 'dart:io';

import 'package:kindura_ai/res/app_url/app_url.dart';

class PdfUploadRepository {
  final NetworkApiServices _apiServices = NetworkApiServices();

  Future<dynamic> uploadPdfFile(File file) async {
    return await _apiServices.uploadFileApi(file, AppUrl.pdfUploadUrl);
  }

  Future<dynamic> uploadMedicalDocument(File file, String title) async {
    // Upload to medical documents endpoint with additional metadata
    Map<String, String> fields = {
      'title': title.isEmpty ? file.path.split('/').last : title,
      'document_type': 'lab_report',  // Default type, can be made dynamic
      'description': 'Medical document uploaded from mobile app',
    };

    return await _apiServices.uploadFileWithFieldsApi(
      file,
      AppUrl.medicalDocumentsUrl,
      fields: fields,
    );
  }
}
