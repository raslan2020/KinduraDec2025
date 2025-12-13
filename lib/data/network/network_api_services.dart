import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;
import 'package:kindura_ai/data/app_exceptions.dart';
import 'package:kindura_ai/data/network/base_api_services.dart';
import 'package:kindura_ai/user_preference/user_preferences_view_model.dart';
import 'package:kindura_ai/utils/performance_monitor.dart';
import 'package:kindura_ai/utils/file_logger.dart';

class NetworkApiServices extends BaseApiServices {
  UserPreferences userPreferences = UserPreferences();
  final PerformanceMonitor _monitor = PerformanceMonitor();
  Future<Map<String, String>> buildHeaders({
    String? token,
    bool requireAuth = true,
  }) async {
    String? finalToken = token;

    if (requireAuth && (finalToken == null || finalToken.isEmpty)) {
      finalToken = await userPreferences.getToken();
    }

    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
    };

    if (finalToken != null && finalToken.isNotEmpty) {
      headers["Authorization"] = "Token $finalToken";
    }

    return headers;
  }

  @override
  Future<dynamic> getApi(String url, {String? token, Map<String, dynamic>? queryParameters}) async {
    final operationId = 'GET_${url.split('/').last}_${DateTime.now().millisecondsSinceEpoch}';
    _monitor.startTimer(operationId);
    _monitor.logApiCallStart(url, {'method': 'GET', 'has_token': token != null});

    // File logging for API request
    await FileLogger.logApiRequest(
      method: 'GET',
      url: url,
      token: token,
      data: queryParameters,
    );

    final headers = await buildHeaders(token: token);

    try {
      Uri uri = Uri.parse(url);
      if (queryParameters != null && queryParameters.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParameters.map((key, value) => MapEntry(key, value.toString())));
      }

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 60));

      final result = return_response(response);
      final duration = _monitor.endTimer(operationId);

      // File logging for API response
      await FileLogger.logApiResponse(
        url: url,
        statusCode: response.statusCode,
        response: result,
        duration: duration,
      );

      _monitor.logApiCallEnd(url, response.statusCode, result);
      _monitor.logPerformanceMetric('api_response_time_${url.split('/').last}', duration?.inMilliseconds ?? 0, 'ms');

      return result;
    } on SocketException catch (e) {
      _monitor.endTimer(operationId);
      _monitor.logError('network_api', 'Socket exception in GET $url', e);

      // File logging for API error
      await FileLogger.logApiError(
        url: url,
        error: 'Socket exception: ${e.toString()}',
      );

      throw InternetException("Please check your internet connection");
    } on TimeoutException catch (e) {
      _monitor.endTimer(operationId);
      _monitor.logError('network_api', 'Timeout in GET $url', e);

      // File logging for API error
      await FileLogger.logApiError(
        url: url,
        error: 'Timeout exception: ${e.toString()}',
      );

      throw RequestTimeOut();
    } catch (e) {
      _monitor.endTimer(operationId);
      _monitor.logError('network_api', 'Unexpected error in GET $url', e);

      // File logging for API error
      await FileLogger.logApiError(
        url: url,
        error: 'Unexpected error: ${e.toString()}',
      );

      rethrow;
    }
  }

  @override
  Future<dynamic> deleteApi(String url, {String? token}) async {
    final headers = await buildHeaders(token: token);

    try {
      final response = await http
          .delete(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 60));

      return return_response(response);
    } on SocketException {
      throw InternetException("Please check your internet connection");
    } on TimeoutException {
      throw RequestTimeOut();
    }
  }

  @override
  Future<dynamic> postApi(
    var data,
    String url, {
    String? token,
    bool requireAuth = true,
  }) async {
    final operationId = 'POST_${url.split('/').last}_${DateTime.now().millisecondsSinceEpoch}';
    _monitor.startTimer(operationId);
    _monitor.logApiCallStart(url, {
      'method': 'POST',
      'has_token': token != null,
      'data_size': data.toString().length,
      'require_auth': requireAuth,
    });

    // File logging for API request
    await FileLogger.logApiRequest(
      method: 'POST',
      url: url,
      token: token,
      data: data,
    );

    final headers = await buildHeaders(token: token, requireAuth: requireAuth);
    final body = jsonEncode(data);

    try {
      final response = await http
          .post(Uri.parse(url), headers: headers, body: body)
          .timeout(const Duration(seconds: 60));

      final result = return_response(response);
      final duration = _monitor.endTimer(operationId);

      // File logging for API response
      await FileLogger.logApiResponse(
        url: url,
        statusCode: response.statusCode,
        response: result,
        duration: duration,
      );

      _monitor.logApiCallEnd(url, response.statusCode, result);
      _monitor.logPerformanceMetric('api_response_time_${url.split('/').last}', duration?.inMilliseconds ?? 0, 'ms');

      return result;
    } on SocketException catch (e) {
      _monitor.endTimer(operationId);
      _monitor.logError('network_api', 'Socket exception in POST $url', e);

      // File logging for API error
      await FileLogger.logApiError(
        url: url,
        error: 'Socket exception: ${e.toString()}',
      );

      throw InternetException("Please check your internet connection");
    } on TimeoutException catch (e) {
      _monitor.endTimer(operationId);
      _monitor.logError('network_api', 'Timeout in POST $url', e);

      // File logging for API error
      await FileLogger.logApiError(
        url: url,
        error: 'Timeout exception: ${e.toString()}',
      );

      throw RequestTimeOut();
    } catch (e) {
      _monitor.endTimer(operationId);
      _monitor.logError('network_api', 'Unexpected error in POST $url', e);

      // File logging for API error
      await FileLogger.logApiError(
        url: url,
        error: 'Unexpected error: ${e.toString()}',
      );

      rethrow;
    }
  }

  @override
  Future<dynamic> patchApi(var data, String url, {String? token}) async {
    final headers = await buildHeaders(token: token);
    final body = jsonEncode(data);

    try {
      final response = await http
          .patch(Uri.parse(url), headers: headers, body: body)
          .timeout(const Duration(seconds: 60));

      return return_response(response);
    } on SocketException {
      throw InternetException("Please connect to the Internet.");
    } on TimeoutException {
      throw RequestTimeOut();
    }
  }

  @override
  Future<dynamic> putApi(var data, String url, {String? token}) async {
    final headers = await buildHeaders(token: token);
    final body = jsonEncode(data);

    try {
      final response = await http
          .put(Uri.parse(url), headers: headers, body: body)
          .timeout(const Duration(seconds: 60));

      return return_response(response);
    } on SocketException {
      throw InternetException("Please connect to the Internet.");
    } on TimeoutException {
      throw RequestTimeOut();
    }
  }

  @override
  Future<dynamic> uploadFileApi(File file, String url, {String? token}) async {
    // File logging for file upload attempt
    await FileLogger.logFileUpload(
      fileName: file.path.split('/').last,
      endpoint: url,
    );

    final headers = await buildHeaders(token: token, requireAuth: true);

    // Remove Content-Type header for multipart requests
    headers.remove("Content-Type");

    try {
      var request = http.MultipartRequest('POST', Uri.parse(url));

      // Add headers
      request.headers.addAll(headers);

      // Add file
      request.files.add(
        await http.MultipartFile.fromPath(
          'pdf', // This should match the field name expected by your API
          file.path,
          filename: file.path.split('/').last,
        ),
      );

      print("the request is ${request.files}");

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      final result = return_response(response);

      // File logging for successful upload
      await FileLogger.logFileUpload(
        fileName: file.path.split('/').last,
        endpoint: url,
        result: 'Success - Status: ${response.statusCode}',
      );

      return result;
    } on SocketException catch (e) {
      // File logging for failed upload
      await FileLogger.logFileUpload(
        fileName: file.path.split('/').last,
        endpoint: url,
        error: 'Socket exception: ${e.toString()}',
      );

      throw InternetException("Please check your internet connection");
    } on TimeoutException catch (e) {
      // File logging for failed upload
      await FileLogger.logFileUpload(
        fileName: file.path.split('/').last,
        endpoint: url,
        error: 'Timeout exception: ${e.toString()}',
      );

      throw RequestTimeOut();
    } catch (e) {
      // File logging for failed upload
      await FileLogger.logFileUpload(
        fileName: file.path.split('/').last,
        endpoint: url,
        error: 'Unexpected error: ${e.toString()}',
      );

      rethrow;
    }
  }

  Future<dynamic> uploadFileWithFieldsApi(File file, String url, {Map<String, String>? fields, String? token}) async {
    // File logging for file upload attempt
    await FileLogger.logFileUpload(
      fileName: file.path.split('/').last,
      endpoint: url,
    );

    final headers = await buildHeaders(token: token, requireAuth: true);

    // Remove Content-Type header for multipart requests
    headers.remove("Content-Type");

    try {
      var request = http.MultipartRequest('POST', Uri.parse(url));

      // Add headers
      request.headers.addAll(headers);

      // Add file - use 'file' as the field name for medical documents
      request.files.add(
        await http.MultipartFile.fromPath(
          'file', // Django expects 'file' field for MedicalDocument
          file.path,
          filename: file.path.split('/').last,
        ),
      );

      // Add additional fields
      if (fields != null) {
        request.fields.addAll(fields);
      }

      print("Upload request fields: ${request.fields}");
      print("Upload request files: ${request.files}");

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      final result = return_response(response);

      // File logging for successful upload
      await FileLogger.logFileUpload(
        fileName: file.path.split('/').last,
        endpoint: url,
        result: 'Success - Status: ${response.statusCode}',
      );

      return result;
    } on SocketException catch (e) {
      // File logging for failed upload
      await FileLogger.logFileUpload(
        fileName: file.path.split('/').last,
        endpoint: url,
        error: 'Socket exception: ${e.toString()}',
      );

      throw InternetException("Please check your internet connection");
    } on TimeoutException catch (e) {
      // File logging for failed upload
      await FileLogger.logFileUpload(
        fileName: file.path.split('/').last,
        endpoint: url,
        error: 'Timeout exception: ${e.toString()}',
      );

      throw RequestTimeOut();
    } catch (e) {
      // File logging for failed upload
      await FileLogger.logFileUpload(
        fileName: file.path.split('/').last,
        endpoint: url,
        error: 'Unexpected error: ${e.toString()}',
      );

      rethrow;
    }
  }

  Future<dynamic> postApiMultipart(String url, Map<String, dynamic> formData, {String? token}) async {
    final operationId = 'MULTIPART_${url.split('/').last}_${DateTime.now().millisecondsSinceEpoch}';
    _monitor.startTimer(operationId);
    _monitor.logApiCallStart(url, {
      'method': 'MULTIPART POST',
      'has_token': token != null,
      'fields_count': formData.length,
    });

    print("=" * 80);
    print("📤 MULTIPART UPLOAD REQUEST");
    print("URL: $url");
    print("Form Data Keys: ${formData.keys.toList()}");

    final headers = await buildHeaders(token: token, requireAuth: true);

    // Remove Content-Type header for multipart requests
    headers.remove("Content-Type");

    try {
      var request = http.MultipartRequest('POST', Uri.parse(url));

      // Add headers
      request.headers.addAll(headers);
      print("Headers: ${request.headers.keys.toList()}");

      // Add form fields and files
      for (var entry in formData.entries) {
        if (entry.value is File) {
          // Handle file upload (dart:io File)
          final file = entry.value as File;
          final fileExists = await file.exists();
          final fileSize = fileExists ? await file.length() : 0;

          print("📎 Adding file: ${entry.key}");
          print("   Path: ${file.path}");
          print("   Filename: ${file.path.split('/').last}");
          print("   Exists: $fileExists");
          print("   Size: $fileSize bytes");

          // Determine content type based on file extension
          final extension = file.path.split('.').last.toLowerCase();
          final contentType = extension == 'pdf'
              ? 'application/pdf'
              : extension == 'jpg' || extension == 'jpeg'
                  ? 'image/jpeg'
                  : extension == 'png'
                      ? 'image/png'
                      : 'application/octet-stream';

          print("   Content-Type: $contentType");

          request.files.add(
            await http.MultipartFile.fromPath(
              entry.key,
              file.path,
              filename: file.path.split('/').last,
              contentType: http_parser.MediaType.parse(contentType),
            ),
          );
        } else if (entry.value.runtimeType.toString() == 'PlatformFile') {
          // Handle PlatformFile (file_picker)
          final platformFile = entry.value;
          final bytes = platformFile.bytes;
          if (bytes != null && platformFile.name != null) {
            print("📎 Adding PlatformFile: ${entry.key} - ${platformFile.name}");
            request.files.add(
              http.MultipartFile.fromBytes(
                entry.key,
                bytes,
                filename: platformFile.name,
              ),
            );
          }
        } else {
          // Handle regular form fields
          print("📝 Adding field: ${entry.key} = ${entry.value}");
          request.fields[entry.key] = entry.value.toString();
        }
      }

      print("Total files: ${request.files.length}");
      print("Total fields: ${request.fields.length}");
      print("🚀 Sending multipart request...");

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      print("📥 Response received:");
      print("   Status Code: ${response.statusCode}");
      print("   Body Length: ${response.body.length}");
      print("   Body Preview: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}");
      print("=" * 80);

      final result = return_response(response);
      final duration = _monitor.endTimer(operationId);

      // File logging for API response
      await FileLogger.logApiResponse(
        url: url,
        statusCode: response.statusCode,
        response: result,
        duration: duration,
      );

      _monitor.logApiCallEnd(url, response.statusCode, result);
      _monitor.logPerformanceMetric('api_multipart_time_${url.split('/').last}', duration?.inMilliseconds ?? 0, 'ms');

      return result;
    } on SocketException catch (e) {
      _monitor.endTimer(operationId);
      _monitor.logError('network_api', 'Socket exception in MULTIPART POST $url', e);
      print("❌ Socket Exception: ${e.toString()}");
      print("=" * 80);

      await FileLogger.logApiError(
        url: url,
        error: 'Socket exception: ${e.toString()}',
      );

      throw InternetException("Please check your internet connection");
    } on TimeoutException catch (e) {
      _monitor.endTimer(operationId);
      _monitor.logError('network_api', 'Timeout in MULTIPART POST $url', e);
      print("❌ Timeout Exception: ${e.toString()}");
      print("=" * 80);

      await FileLogger.logApiError(
        url: url,
        error: 'Timeout exception: ${e.toString()}',
      );

      throw RequestTimeOut();
    } catch (e) {
      _monitor.endTimer(operationId);
      _monitor.logError('network_api', 'Unexpected error in MULTIPART POST $url', e);
      print("❌ Unexpected Exception: ${e.toString()}");
      print("=" * 80);

      await FileLogger.logApiError(
        url: url,
        error: 'Unexpected error: ${e.toString()}',
      );

      rethrow;
    }
  }

  dynamic return_response(http.Response response) {
    switch (response.statusCode) {
      case 200:
      case 201:
      case 400:
      case 422:
        return jsonDecode(response.body);

      case 404:
        // Don't return HTML error pages as the message
        String errorMessage = 'Resource not found';

        // Try to parse JSON error message if available
        try {
          final jsonResponse = jsonDecode(response.body);
          if (jsonResponse is Map && jsonResponse.containsKey('message')) {
            errorMessage = jsonResponse['message'];
          }
        } catch (_) {
          // If response is HTML or not JSON, use generic message
          errorMessage = 'The requested resource was not found';
        }

        return {
          'status': false,
          'message': errorMessage,
          'error': 'Not Found (404)'
        };

      default:
        try {
          return jsonDecode(response.body);
        } catch (_) {
          throw FetchDataException(
            'Unexpected error: ${response.statusCode}',
          );
        }
    }
  }
}
