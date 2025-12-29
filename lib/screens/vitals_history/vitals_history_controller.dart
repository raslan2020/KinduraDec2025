import 'package:get/get.dart';
import 'package:kindura_ai/data/network/network_api_services.dart';
import 'package:kindura_ai/res/app_url/app_url.dart';
import 'package:kindura_ai/services/watch_vitals_service.dart';

class VitalsHistoryController extends GetxController {
  final _apiService = NetworkApiServices();
  final _watchVitalsService = WatchVitalsService();

  var isLoading = true.obs;
  var selectedPeriod = 'day'.obs; // day, week, month
  var vitalsHistory = <Map<String, dynamic>>[].obs;
  var insights = <String>[].obs;
  var dataSource = 'api'.obs; // 'api' or 'apple_health'

  @override
  void onInit() {
    super.onInit();
    loadHistory();
  }

  void changePeriod(String period) {
    selectedPeriod.value = period;
    loadHistory();
  }

  Future<void> loadHistory() async {
    try {
      isLoading.value = true;

      int days = 1;
      if (selectedPeriod.value == 'week') days = 7;
      if (selectedPeriod.value == 'month') days = 30;

      print('[VitalsHistory] Loading history for $days days...');

      // 1. Try Django API first
      final response = await _apiService.getApi(
        '${AppUrl.watchVitalsHistoryUrl}?days=$days',
      );

      if (response['status'] == true) {
        final apiData = List<Map<String, dynamic>>.from(response['result'] ?? []);
        print('[VitalsHistory] API returned ${apiData.length} records');

        // 2. If API returns data, use it
        if (apiData.isNotEmpty) {
          vitalsHistory.value = apiData;
          dataSource.value = 'api';
          _generateInsights();
          return;
        }
      }

      // 3. API returned empty - try Apple Health fallback
      print('[VitalsHistory] API empty, trying Apple Health fallback...');
      final healthData = await _watchVitalsService.getHealthHistory(days);

      if (healthData != null && healthData.isNotEmpty) {
        print('[VitalsHistory] Apple Health returned ${healthData.length} records');
        vitalsHistory.value = _convertHealthDataToVitals(healthData);
        dataSource.value = 'apple_health';
        _generateInsights();
      } else {
        print('[VitalsHistory] No data from Apple Health either');
        vitalsHistory.value = [];
        dataSource.value = 'none';
      }
    } catch (e) {
      print('Error loading vitals history: $e');

      // Try Apple Health on error
      try {
        int days = selectedPeriod.value == 'week' ? 7 : (selectedPeriod.value == 'month' ? 30 : 1);
        final healthData = await _watchVitalsService.getHealthHistory(days);
        if (healthData != null && healthData.isNotEmpty) {
          vitalsHistory.value = _convertHealthDataToVitals(healthData);
          dataSource.value = 'apple_health';
          _generateInsights();
        }
      } catch (e2) {
        print('Error loading from Apple Health: $e2');
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// Convert Apple Health raw samples to vitals history format
  List<Map<String, dynamic>> _convertHealthDataToVitals(List<Map<String, dynamic>> healthData) {
    // Group by timestamp (aggregate samples by hour for day view, by day for week/month)
    Map<String, Map<String, dynamic>> aggregated = {};

    for (var sample in healthData) {
      final type = sample['type'] as String?;
      final value = sample['value'];
      final timestamp = sample['timestamp'] as String?;

      if (timestamp == null) continue;

      // Parse timestamp and create a key based on period
      String key;
      if (selectedPeriod.value == 'day') {
        // Group by hour
        key = timestamp.substring(0, 13); // YYYY-MM-DDTHH
      } else {
        // Group by day
        key = timestamp.substring(0, 10); // YYYY-MM-DD
      }

      if (aggregated[key] == null) {
        aggregated[key] = {
          'timestamp': timestamp,
          'heart_rate': 0,
          'heart_rate_count': 0,
          'blood_oxygen': 0,
          'blood_oxygen_count': 0,
          'hrv': 0,
          'hrv_count': 0,
          'total_sleep_hours': 0.0,
          'source': 'apple_health',
        };
      }

      switch (type) {
        case 'heart_rate':
          aggregated[key]!['heart_rate'] = (aggregated[key]!['heart_rate'] as num) + (value as num);
          aggregated[key]!['heart_rate_count'] = (aggregated[key]!['heart_rate_count'] as int) + 1;
          break;
        case 'blood_oxygen':
          aggregated[key]!['blood_oxygen'] = (aggregated[key]!['blood_oxygen'] as num) + (value as num);
          aggregated[key]!['blood_oxygen_count'] = (aggregated[key]!['blood_oxygen_count'] as int) + 1;
          break;
        case 'hrv':
          aggregated[key]!['hrv'] = (aggregated[key]!['hrv'] as num) + (value as num);
          aggregated[key]!['hrv_count'] = (aggregated[key]!['hrv_count'] as int) + 1;
          break;
        case 'sleep':
          aggregated[key]!['total_sleep_hours'] = value;
          if (sample['stages'] != null) {
            aggregated[key]!['sleep_stages'] = sample['stages'];
          }
          break;
      }
    }

    // Calculate averages and format for display
    List<Map<String, dynamic>> result = [];
    aggregated.forEach((key, data) {
      final hrCount = data['heart_rate_count'] as int;
      final o2Count = data['blood_oxygen_count'] as int;
      final hrvCount = data['hrv_count'] as int;

      result.add({
        'recorded_at': data['timestamp'],
        'heart_rate': hrCount > 0 ? ((data['heart_rate'] as num) / hrCount).round() : 0,
        'blood_oxygen': o2Count > 0 ? ((data['blood_oxygen'] as num) / o2Count).round() : 0,
        'hrv': hrvCount > 0 ? ((data['hrv'] as num) / hrvCount).round() : 0,
        'total_sleep_hours': data['total_sleep_hours'],
        'sleep_stages': data['sleep_stages'],
        'source': 'apple_health',
      });
    });

    // Sort by timestamp descending (newest first)
    result.sort((a, b) {
      final aTime = a['recorded_at'] as String? ?? '';
      final bTime = b['recorded_at'] as String? ?? '';
      return bTime.compareTo(aTime);
    });

    return result;
  }

  void _generateInsights() {
    insights.clear();
    if (vitalsHistory.isEmpty) return;

    // Calculate averages
    double avgHeartRate = 0;
    double avgOxygen = 0;
    double avgSleep = 0;
    int count = vitalsHistory.length;

    for (var v in vitalsHistory) {
      avgHeartRate += (v['heart_rate'] ?? 0);
      avgOxygen += (v['blood_oxygen'] ?? 0);
      avgSleep += (v['total_sleep_hours'] ?? 0);
    }

    avgHeartRate /= count;
    avgOxygen /= count;
    avgSleep /= count;

    // Generate insights
    if (avgHeartRate > 100) {
      insights.add('Your average heart rate (${avgHeartRate.toInt()} bpm) is elevated. Consider consulting your doctor.');
    } else if (avgHeartRate < 60) {
      insights.add('Your average heart rate (${avgHeartRate.toInt()} bpm) is low. This may be normal if you exercise regularly.');
    } else {
      insights.add('Your heart rate (avg ${avgHeartRate.toInt()} bpm) is in the normal range.');
    }

    if (avgOxygen < 95) {
      insights.add('Your blood oxygen (avg ${avgOxygen.toInt()}%) is below optimal. Please monitor closely.');
    } else {
      insights.add('Your blood oxygen levels are healthy (avg ${avgOxygen.toInt()}%).');
    }

    if (avgSleep < 6 && avgSleep > 0) {
      insights.add('You\'re getting less than 6 hours of sleep on average. Aim for 7-9 hours.');
    } else if (avgSleep >= 7) {
      insights.add('Great sleep patterns! Averaging ${avgSleep.toStringAsFixed(1)} hours per night.');
    }

    // Check for falls
    int fallCount = vitalsHistory.where((v) => v['fall_detected'] == true).length;
    if (fallCount > 0) {
      insights.add('$fallCount fall(s) detected in this period. Please be careful.');
    }
  }

  // Get data points for a specific metric
  List<double> getDataPoints(String metric) {
    return vitalsHistory.reversed.map<double>((v) {
      switch (metric) {
        case 'heart_rate':
          return (v['heart_rate'] ?? 0).toDouble();
        case 'blood_oxygen':
          return (v['blood_oxygen'] ?? 0).toDouble();
        case 'sleep':
          return (v['total_sleep_hours'] ?? 0).toDouble();
        case 'hrv':
          return (v['hrv'] ?? 0).toDouble();
        default:
          return 0.0;
      }
    }).toList();
  }

  // Get min/max for scaling
  double getMin(String metric) {
    if (vitalsHistory.isEmpty) return 0;
    return getDataPoints(metric).reduce((a, b) => a < b ? a : b);
  }

  double getMax(String metric) {
    if (vitalsHistory.isEmpty) return 100;
    return getDataPoints(metric).reduce((a, b) => a > b ? a : b);
  }

  double getAverage(String metric) {
    final points = getDataPoints(metric);
    if (points.isEmpty) return 0;
    return points.reduce((a, b) => a + b) / points.length;
  }
}
