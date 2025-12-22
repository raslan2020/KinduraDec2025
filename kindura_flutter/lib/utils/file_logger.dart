import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class FileLogger {
  static const String _logFileName = 'kindura_app_logs.txt';
  static File? _logFile;

  static Future<void> initialize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/$_logFileName');

      // Create file if it doesn't exist
      if (!await _logFile!.exists()) {
        await _logFile!.create();
      }

      await _writeToFile('\n\n🚀 NEW APP SESSION STARTED - ${DateTime.now().toIso8601String()} 🚀\n${'='*80}');
    } catch (e) {
      print('Failed to initialize FileLogger: $e');
    }
  }

  static Future<void> _writeToFile(String message) async {
    if (_logFile == null) {
      await initialize();
    }

    try {
      final timestamp = DateTime.now().toIso8601String();
      final logEntry = '[$timestamp] $message\n';

      await _logFile!.writeAsString(logEntry, mode: FileMode.append);

      // Also print to console in debug mode
      if (kDebugMode) {
        print(logEntry.trim());
      }

      // Also use developer.log
      developer.log(message, name: 'FileLogger');
    } catch (e) {
      print('Failed to write to log file: $e');
    }
  }

  static Future<void> logApiRequest({
    required String method,
    required String url,
    String? token,
    dynamic data,
  }) async {
    final message = '''
🌐 API REQUEST
Method: $method
URL: $url
Token: ${token != null ? '${token.substring(0, 10)}...' : 'None'}
Data: ${data?.toString() ?? 'None'}
''';
    await _writeToFile(message);
  }

  static Future<void> logApiResponse({
    required String url,
    required int statusCode,
    dynamic response,
    Duration? duration,
  }) async {
    final message = '''
📡 API RESPONSE
URL: $url
Status: $statusCode
Duration: ${duration?.inMilliseconds ?? 'Unknown'}ms
Response: ${response?.toString() ?? 'None'}
''';
    await _writeToFile(message);
  }

  static Future<void> logApiError({
    required String url,
    required String error,
    int? statusCode,
    dynamic response,
  }) async {
    final message = '''
❌ API ERROR
URL: $url
Status: ${statusCode ?? 'Unknown'}
Error: $error
Response: ${response?.toString() ?? 'None'}
''';
    await _writeToFile(message);
  }

  static Future<void> logUiError({
    required String screen,
    required String widget,
    required String error,
    Map<String, dynamic>? context,
  }) async {
    final message = '''
🎨 UI ERROR
Screen: $screen
Widget: $widget
Error: $error
Context: ${context?.toString() ?? 'None'}
''';
    await _writeToFile(message);
  }

  static Future<void> logDatabaseOperation({
    required String operation,
    required String table,
    String? result,
    String? error,
  }) async {
    final message = '''
🗄️ DATABASE OPERATION
Operation: $operation
Table: $table
Result: ${result ?? 'None'}
Error: ${error ?? 'None'}
''';
    await _writeToFile(message);
  }

  static Future<void> logFileUpload({
    required String fileName,
    required String endpoint,
    String? result,
    String? error,
  }) async {
    final message = '''
📤 FILE UPLOAD
File: $fileName
Endpoint: $endpoint
Result: ${result ?? 'None'}
Error: ${error ?? 'None'}
''';
    await _writeToFile(message);
  }

  static Future<void> logVoiceOperation({
    required String operation,
    String? result,
    String? error,
  }) async {
    final message = '''
🎤 VOICE OPERATION
Operation: $operation
Result: ${result ?? 'None'}
Error: ${error ?? 'None'}
''';
    await _writeToFile(message);
  }

  static Future<void> logGeneral({
    required String category,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    final logMessage = '''
📋 $category
Message: $message
Data: ${data?.toString() ?? 'None'}
''';
    await _writeToFile(logMessage);
  }

  static Future<String> getLogFilePath() async {
    if (_logFile == null) {
      await initialize();
    }
    return _logFile?.path ?? 'Log file not initialized';
  }

  static Future<String> getLogContents() async {
    if (_logFile == null) {
      await initialize();
    }

    try {
      if (await _logFile!.exists()) {
        return await _logFile!.readAsString();
      }
      return 'Log file does not exist';
    } catch (e) {
      return 'Failed to read log file: $e';
    }
  }

  static Future<void> clearLogs() async {
    if (_logFile == null) {
      await initialize();
    }

    try {
      await _logFile!.writeAsString('');
      await _writeToFile('🧹 LOG FILE CLEARED');
    } catch (e) {
      print('Failed to clear log file: $e');
    }
  }

  static Future<void> logAppLifecycle(String event) async {
    await _writeToFile('🔄 APP LIFECYCLE: $event');
  }

  static Future<void> logNavigation({
    required String from,
    required String to,
    Map<String, dynamic>? parameters,
  }) async {
    final message = '''
🧭 NAVIGATION
From: $from
To: $to
Parameters: ${parameters?.toString() ?? 'None'}
''';
    await _writeToFile(message);
  }
}