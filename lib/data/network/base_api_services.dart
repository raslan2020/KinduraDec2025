import 'dart:io';

abstract class BaseApiServices {
  Future<dynamic> getApi(String url, {String? token, Map<String, dynamic>? queryParameters});
  Future<dynamic> deleteApi(String url, {String? token});
  Future<dynamic> postApi(dynamic data, String url, {String? token, bool requireAuth = true});
  Future<dynamic> putApi(var data, String url, {String? token});
  Future<dynamic> patchApi(var data, String url, {String? token});
  Future<dynamic> uploadFileApi(File file, String url, {String? token});
  Future<dynamic> postApiMultipart(String url, Map<String, dynamic> formData, {String? token});
}
