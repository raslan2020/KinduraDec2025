import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Comprehensive error logging utility for debugging app issues
class AppErrorLogger {
  static const String _logTag = '🚨 APP_ERROR';

  /// Log API errors with full context
  static void logApiError({
    required String endpoint,
    required int statusCode,
    required String method,
    String? token,
    dynamic response,
    dynamic error,
    Map<String, dynamic>? requestData,
  }) {
    final message = '''
══════════════════════════════════════════════════════════════
🚨 API ERROR DETECTED
══════════════════════════════════════════════════════════════
📍 Endpoint: $endpoint
📋 Method: $method
📊 Status Code: $statusCode
🔑 Token Present: ${token != null ? 'YES (${token.substring(0, 10)}...)' : 'NO'}
📥 Request Data: ${requestData ?? 'None'}
📤 Response: $response
❌ Error: $error
⏰ Timestamp: ${DateTime.now().toIso8601String()}
══════════════════════════════════════════════════════════════
    ''';

    developer.log(message, name: _logTag);
    if (kDebugMode) {
      print(message);
    }
  }

  /// Log data parsing errors
  static void logDataParsingError({
    required String operation,
    required dynamic rawData,
    required dynamic error,
    String? expectedFormat,
  }) {
    final message = '''
══════════════════════════════════════════════════════════════
🚨 DATA PARSING ERROR
══════════════════════════════════════════════════════════════
🔄 Operation: $operation
📊 Raw Data: $rawData
📋 Expected Format: ${expectedFormat ?? 'Unknown'}
❌ Error: $error
⏰ Timestamp: ${DateTime.now().toIso8601String()}
══════════════════════════════════════════════════════════════
    ''';

    developer.log(message, name: _logTag);
    if (kDebugMode) {
      print(message);
    }
  }

  /// Log UI errors (like dropdown issues)
  static void logUiError({
    required String widget,
    required String error,
    Map<String, dynamic>? context,
  }) {
    final message = '''
══════════════════════════════════════════════════════════════
🚨 UI ERROR
══════════════════════════════════════════════════════════════
🎨 Widget: $widget
❌ Error: $error
📋 Context: ${context ?? 'None'}
⏰ Timestamp: ${DateTime.now().toIso8601String()}
══════════════════════════════════════════════════════════════
    ''';

    developer.log(message, name: _logTag);
    if (kDebugMode) {
      print(message);
    }
  }

  /// Log successful operations for debugging
  static void logSuccess({
    required String operation,
    Map<String, dynamic>? data,
  }) {
    final message = '''
✅ SUCCESS: $operation
📊 Data: ${data ?? 'None'}
⏰ ${DateTime.now().toIso8601String()}
    ''';

    developer.log(message, name: '✅ APP_SUCCESS');
    if (kDebugMode) {
      print(message);
    }
  }

  /// Log general app state for debugging
  static void logAppState({
    required String component,
    required Map<String, dynamic> state,
  }) {
    final message = '''
📊 APP STATE: $component
${state.entries.map((e) => '   ${e.key}: ${e.value}').join('\n')}
⏰ ${DateTime.now().toIso8601String()}
    ''';

    developer.log(message, name: '📊 APP_STATE');
    if (kDebugMode) {
      print(message);
    }
  }
}