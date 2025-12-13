import 'package:flutter/services.dart';
import 'package:kindura_ai/repository/home_repository/home_repository.dart';

/// Service to handle Watch vitals data from iOS native layer
/// Receives data via WatchConnectivity and sends to Django API
class WatchVitalsService {
  static const MethodChannel _channel = MethodChannel('com.kindura.ai/watch_vitals');
  final HomeRepository _homeRepository = HomeRepository();

  Function(Map<String, dynamic>)? onVitalsReceived;

  WatchVitalsService() {
    _setupMethodCallHandler();
  }

  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onWatchVitalsReceived') {
        final vitals = Map<String, dynamic>.from(call.arguments as Map);
        print('Received Watch vitals from native: $vitals');

        // Send to API
        await _sendVitalsToAPI(vitals);

        // Notify listeners
        onVitalsReceived?.call(vitals);
      }
      return null;
    });
  }

  /// Get latest vitals from native layer (cached)
  Future<Map<String, dynamic>?> getLatestVitals() async {
    try {
      final result = await _channel.invokeMethod('getLatestVitals');
      if (result != null) {
        return Map<String, dynamic>.from(result as Map);
      }
      return null;
    } catch (e) {
      print('Error getting latest vitals: $e');
      return null;
    }
  }

  /// Send vitals to Django API for storage
  Future<void> _sendVitalsToAPI(Map<String, dynamic> vitals) async {
    try {
      // Convert Watch data format to API format
      final apiData = {
        'heart_rate': vitals['heart_rate'] ?? 0,
        'blood_oxygen': vitals['blood_oxygen'] ?? 0,
        'hrv': vitals['hrv'],
        'respiratory_rate': vitals['respiratory_rate'],
        'total_sleep_hours': vitals['total_sleep_hours'],
        'deep_sleep_hours': vitals['deep_sleep_hours'],
        'rem_sleep_hours': vitals['rem_sleep_hours'],
        'core_sleep_hours': vitals['core_sleep_hours'],
        'awake_time_hours': vitals['awake_time_hours'],
        'awakenings_count': vitals['awakenings_count'] ?? 0,
        'sleep_quality': vitals['sleep_quality'],
        'fall_detected': vitals['fall_detected'] ?? false,
        'recorded_at': vitals['timestamp'] ?? DateTime.now().toIso8601String(),
      };

      final response = await _homeRepository.saveWatchVitals(apiData);

      if (response['status'] == true) {
        print('Watch vitals saved to database successfully');
      } else {
        print('Failed to save Watch vitals: ${response['message']}');
      }
    } catch (e) {
      print('Error sending vitals to API: $e');
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
  }
}
