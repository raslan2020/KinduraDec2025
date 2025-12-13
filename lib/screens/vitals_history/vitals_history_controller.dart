import 'package:get/get.dart';
import 'package:kindura_ai/data/network/network_api_services.dart';
import 'package:kindura_ai/res/app_url/app_url.dart';

class VitalsHistoryController extends GetxController {
  final _apiService = NetworkApiServices();

  var isLoading = true.obs;
  var selectedPeriod = 'day'.obs; // day, week, month
  var vitalsHistory = <Map<String, dynamic>>[].obs;
  var insights = <String>[].obs;

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

      final response = await _apiService.getApi(
        '${AppUrl.watchVitalsHistoryUrl}?days=$days',
      );

      if (response['status'] == true) {
        vitalsHistory.value = List<Map<String, dynamic>>.from(response['result'] ?? []);
        _generateInsights();
      }
    } catch (e) {
      print('Error loading vitals history: $e');
    } finally {
      isLoading.value = false;
    }
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
