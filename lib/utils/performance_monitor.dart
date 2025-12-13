import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Comprehensive performance and communication monitoring utility
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final List<Map<String, dynamic>> _logs = [];
  final Map<String, DateTime> _timers = {};
  bool _isEnabled = true;
  
  /// Start timing an operation
  void startTimer(String operation) {
    _timers[operation] = DateTime.now();
    _log('TIMER_START', 'Started timing: $operation', {
      'operation': operation,
      'start_time': DateTime.now().toIso8601String(),
    });
  }
  
  /// End timing an operation and return duration
  Duration? endTimer(String operation) {
    final startTime = _timers.remove(operation);
    if (startTime == null) {
      _log('TIMER_ERROR', 'No start time found for: $operation', {
        'operation': operation,
        'error': 'timer_not_started'
      });
      return null;
    }
    
    final duration = DateTime.now().difference(startTime);
    _log('TIMER_END', 'Completed timing: $operation', {
      'operation': operation,
      'duration_ms': duration.inMilliseconds,
      'duration_seconds': duration.inSeconds,
      'end_time': DateTime.now().toIso8601String(),
    });
    return duration;
  }
  
  /// Log API call start
  void logApiCallStart(String endpoint, Map<String, dynamic>? params) {
    final operationId = 'api_${endpoint}_${DateTime.now().millisecondsSinceEpoch}';
    startTimer(operationId);
    
    _log('API_CALL_START', 'Starting API call', {
      'endpoint': endpoint,
      'params': params,
      'operation_id': operationId,
      'method': 'inferred_from_endpoint'
    });
  }
  
  /// Log API call completion
  void logApiCallEnd(String endpoint, int statusCode, dynamic response, [String? error]) {
    final operationId = 'api_${endpoint}_${DateTime.now().millisecondsSinceEpoch}';
    final duration = endTimer(operationId);
    
    _log('API_CALL_END', 'API call completed', {
      'endpoint': endpoint,
      'status_code': statusCode,
      'response_size': response?.toString().length ?? 0,
      'duration_ms': duration?.inMilliseconds,
      'success': statusCode >= 200 && statusCode < 300,
      'error': error,
      'operation_id': operationId
    });
  }
  
  /// Log LiveKit connection events
  void logLiveKitEvent(String event, Map<String, dynamic> data) {
    _log('LIVEKIT_EVENT', event, {
      'event_type': event,
      'connection_data': data,
      'performance_impact': _calculatePerformanceImpact(event)
    });
  }
  
  /// Log transcription events with timing
  void logTranscription(String transcriptionId, String text, String source, [bool isFinal = false]) {
    _log('TRANSCRIPTION', 'Transcription received', {
      'transcription_id': transcriptionId,
      'text': text,
      'source': source,
      'is_final': isFinal,
      'text_length': text.length,
      'processing_delay': 'calculated_if_available'
    });
  }
  
  /// Log voice trigger events
  void logVoiceTrigger(String recognizedText, bool isValidTrigger) {
    _log('VOICE_TRIGGER', 'Voice trigger detected', {
      'recognized_text': recognizedText,
      'is_valid_trigger': isValidTrigger,
      'trigger_patterns': ['hey kindura', 'hey candura', 'he can dora']
    });
  }
  
  /// Log errors with context
  void logError(String category, String message, dynamic error, [StackTrace? stackTrace]) {
    _log('ERROR', message, {
      'category': category,
      'error': error?.toString(),
      'stack_trace': stackTrace?.toString(),
      'error_type': error.runtimeType.toString(),
      'recovery_action': 'pending'
    });
  }
  
  /// Log performance metrics
  void logPerformanceMetric(String metric, dynamic value, [String? unit]) {
    _log('PERFORMANCE_METRIC', 'Performance metric recorded', {
      'metric_name': metric,
      'value': value,
      'unit': unit ?? 'ms',
      'threshold_exceeded': _checkThreshold(metric, value)
    });
  }
  
  /// Get recent logs (last N entries)
  List<Map<String, dynamic>> getRecentLogs([int limit = 100]) {
    return _logs.reversed.take(limit).toList();
  }
  
  /// Get logs by category
  List<Map<String, dynamic>> getLogsByCategory(String category) {
    return _logs.where((log) => log['level'] == category).toList();
  }
  
  /// Get performance summary
  Map<String, dynamic> getPerformanceSummary() {
    final apiCalls = _logs.where((log) => log['level'] == 'API_CALL_END').toList();
    final errors = _logs.where((log) => log['level'] == 'ERROR').toList();
    final liveKitEvents = _logs.where((log) => log['level'] == 'LIVEKIT_EVENT').toList();
    
    return {
      'total_api_calls': apiCalls.length,
      'total_errors': errors.length,
      'total_livekit_events': liveKitEvents.length,
      'average_api_response_time': _calculateAverageApiTime(apiCalls),
      'error_rate': errors.length / (_logs.length == 0 ? 1 : _logs.length),
      'last_activity': _logs.isNotEmpty ? _logs.last['timestamp'] : null,
      'performance_alerts': _getPerformanceAlerts()
    };
  }
  
  /// Export logs as JSON string
  String exportLogs() {
    return JsonEncoder.withIndent('  ').convert({
      'export_timestamp': DateTime.now().toIso8601String(),
      'logs': _logs,
      'performance_summary': getPerformanceSummary()
    });
  }
  
  /// Clear all logs
  void clearLogs() {
    _logs.clear();
    _timers.clear();
    _log('SYSTEM', 'Logs cleared', {});
  }
  
  /// Enable or disable monitoring
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    _log('SYSTEM', 'Performance monitoring ${enabled ? 'enabled' : 'disabled'}', {
      'enabled': enabled,
    });
  }
  
  /// Check if monitoring is enabled
  bool get isEnabled => _isEnabled;

  /// Internal logging method
  void _log(String level, String message, Map<String, dynamic> data) {
    if (!_isEnabled && level != 'SYSTEM') return;
    
    final logEntry = {
      'timestamp': DateTime.now().toIso8601String(),
      'level': level,
      'message': message,
      'data': data,
      'memory_usage': _getMemoryUsage(),
    };
    
    _logs.add(logEntry);
    
    // Keep only last 1000 logs to prevent memory issues
    if (_logs.length > 1000) {
      _logs.removeAt(0);
    }
    
    // Print to console in debug mode
    if (kDebugMode) {
      print('🔍 [${level}] ${message}');
      if (data.isNotEmpty && level != 'PERFORMANCE_METRIC') {
        print('📊 Data: ${JsonEncoder.withIndent('  ').convert(data)}');
      }
    }
  }
  
  /// Calculate performance impact of events
  String _calculatePerformanceImpact(String event) {
    switch (event.toLowerCase()) {
      case 'connection_start':
      case 'connection_established':
        return 'high';
      case 'transcription_received':
        return 'medium';
      case 'audio_track_subscribed':
        return 'low';
      default:
        return 'unknown';
    }
  }
  
  /// Check if metric exceeds threshold
  bool _checkThreshold(String metric, dynamic value) {
    final thresholds = {
      'api_response_time': 5000, // 5 seconds
      'connection_time': 10000, // 10 seconds
      'transcription_delay': 2000, // 2 seconds
    };
    
    if (value is num && thresholds.containsKey(metric)) {
      return value > thresholds[metric]!;
    }
    return false;
  }
  
  /// Calculate average API response time
  double _calculateAverageApiTime(List<Map<String, dynamic>> apiCalls) {
    if (apiCalls.isEmpty) return 0.0;
    
    final durations = apiCalls
        .map((call) => call['data']['duration_ms'] as int? ?? 0)
        .where((duration) => duration > 0);
    
    if (durations.isEmpty) return 0.0;
    
    return durations.reduce((a, b) => a + b) / durations.length;
  }
  
  /// Get performance alerts
  List<String> _getPerformanceAlerts() {
    final alerts = <String>[];
    final summary = getPerformanceSummary();
    
    if (summary['error_rate'] > 0.1) {
      alerts.add('High error rate: ${(summary['error_rate'] * 100).toStringAsFixed(1)}%');
    }
    
    if (summary['average_api_response_time'] > 5000) {
      alerts.add('Slow API responses: ${summary['average_api_response_time'].toStringAsFixed(0)}ms avg');
    }
    
    return alerts;
  }
  
  /// Get approximate memory usage
  String _getMemoryUsage() {
    // This is a simplified memory usage indicator
    final logSize = _logs.length * 500; // Approximate 500 bytes per log
    if (logSize > 1024 * 1024) {
      return '${(logSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    } else if (logSize > 1024) {
      return '${(logSize / 1024).toStringAsFixed(1)}KB';
    }
    return '${logSize}B';
  }
}

/// Extension to easily add performance monitoring to any class
extension PerformanceMonitoringExtension on Object {
  PerformanceMonitor get performanceMonitor => PerformanceMonitor();
}