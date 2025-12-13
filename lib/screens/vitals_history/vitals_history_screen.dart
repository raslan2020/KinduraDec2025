import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:kindura_ai/res/colors/app_color.dart';
import 'vitals_history_controller.dart';

class VitalsHistoryScreen extends StatelessWidget {
  VitalsHistoryScreen({Key? key}) : super(key: key);

  final controller = Get.put(VitalsHistoryController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.surface,
      appBar: AppBar(
        title: Text('Vitals History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColor.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
        titleTextStyle: TextStyle(color: Colors.black87, fontSize: 18.sp, fontWeight: FontWeight.bold),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPeriodSelector(),
              SizedBox(height: 16.h),
              _buildVitalChart('Heart Rate', 'heart_rate', Colors.red, 'bpm', 40, 120),
              SizedBox(height: 16.h),
              _buildVitalChart('Blood Oxygen', 'blood_oxygen', Colors.cyan, '%', 90, 100),
              SizedBox(height: 16.h),
              _buildVitalChart('Sleep', 'sleep', Colors.indigo, 'hrs', 0, 12),
              SizedBox(height: 16.h),
              _buildVitalChart('HRV', 'hrv', Colors.purple, 'ms', 0, 100),
              SizedBox(height: 20.h),
              _buildInsights(),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildPeriodSelector() {
    return Obx(() => Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8.w),
      ),
      child: Row(
        children: [
          _periodButton('Day', 'day'),
          _periodButton('Week', 'week'),
          _periodButton('Month', 'month'),
        ],
      ),
    ));
  }

  Widget _periodButton(String label, String value) {
    final isSelected = controller.selectedPeriod.value == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.changePeriod(value),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: isSelected ? AppColor.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6.w),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.black54,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVitalChart(String title, String metric, Color color, String unit, double minY, double maxY) {
    final dataPoints = controller.getDataPoints(metric);
    final avg = controller.getAverage(metric);

    if (dataPoints.isEmpty || dataPoints.every((v) => v == 0)) {
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.w),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 8.h),
            Text('No data available', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.w),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
              Text(
                'Avg: ${avg.toStringAsFixed(1)} $unit',
                style: TextStyle(fontSize: 12.sp, color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          SizedBox(
            height: 120.h,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: TextStyle(fontSize: 10.sp, color: Colors.grey),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: dataPoints.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value.clamp(minY, maxY));
                    }).toList(),
                    isCurved: true,
                    color: color,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: dataPoints.length <= 10,
                      getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                        radius: 3,
                        color: color,
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsights() {
    if (controller.insights.isEmpty) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12.w),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                'Insights',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ...controller.insights.map((insight) => Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(fontSize: 12.sp, color: Colors.blue.shade700)),
                Expanded(
                  child: Text(
                    insight,
                    style: TextStyle(fontSize: 12.sp, color: Colors.blue.shade900),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
