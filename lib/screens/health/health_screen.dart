import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/common_widgets/activity_card.dart';
import 'package:kindura_ai/common_widgets/home_app_bar.dart';
import 'package:kindura_ai/common_widgets/toogle_botton.dart';
import 'package:kindura_ai/common_widgets/sleep_summary_card.dart';
import 'package:kindura_ai/res/assets/image_constant.dart';
import 'package:kindura_ai/screens/health/health_controller.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final controller = Get.put(HealthController());
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: "Kindura AI"),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text("Health",
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    Spacer(),
                    Icon(Icons.refresh, color: Colors.red)
                  ],
                ),
                Text("Monitor your vital signal and health",
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
                SizedBox(height: 20.h),
                Obx(
                  () => Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    padding: EdgeInsets.all(5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CustomToggle(
                          isSelected:
                              controller.selectedTab.value == 'Vital Signs',
                          onTap: () => controller.selectTab('Vital Signs'),
                          child: Text(
                            'Vital Signs',
                          ),
                        ),
                        Spacer(),
                        CustomToggle(
                          isSelected: controller.selectedTab.value == 'Sleep',
                          onTap: () => controller.selectTab('Sleep'),
                          child: Text('Sleep'),
                        ),
                        Spacer(),
                        CustomToggle(
                          isSelected: controller.selectedTab.value ==
                              'Movement & Falls',
                          onTap: () => controller.selectTab('Movement & Falls'),
                          child: Text('Movement & Falls'),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Obx(() {
                  if (controller.selectedTab.value == 'Vital Signs') {
                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _infoCard(
                              icon: SvgPicture.asset(
                                  ImageConstant.bloodPressueIcon,
                                  height: 32,
                                  width: 32),
                              label: 'Blood Pressure',
                              value: controller.bloodPressure.value,
                              time: controller.recordedTime.value,
                              unit: 'mmHg',
                            ),
                            _infoCard(
                              icon: SvgPicture.asset(ImageConstant.heartIcon,
                                  height: 32, width: 32),
                              label: 'Heart Rate',
                              value: '${controller.heartRate.value}',
                              time: controller.recordedTime.value,
                              unit: 'bpm',
                            ),
                          ],
                        ),
                        SizedBox(height: 30),
                        _summarySection(
                          bp: controller.bloodPressure.value,
                          hr: controller.heartRate.value,
                          temp: controller.temperature.value,
                          o2: controller.oxygen.value,
                        ),
                      ],
                    );
                  } else if (controller.selectedTab.value == 'Sleep') {
                    return Column(
                      children: [
                        Column(
                          children: [
                            SleepSummaryCard(
                              date: '2024-01-15',
                              deepSleep: '2h 15m',
                              totalSleep: '7h 32m',
                              quality: 'Good',
                              qualityColor: Colors.blue,
                            ),
                            SleepSummaryCard(
                              date: '2024-01-14',
                              deepSleep: '1h 52m',
                              totalSleep: '6h 45m',
                              quality: 'Fair',
                              qualityColor: Colors.orange,
                            ),
                            SleepSummaryCard(
                              date: '2024-01-13',
                              deepSleep: '2h 38m',
                              totalSleep: '8h 12m',
                              quality: 'Excellent',
                              qualityColor: Colors.green,
                            ),
                          ],
                        )
                      ],
                    );
                  } else if (controller.selectedTab.value ==
                      'Movement & Falls') {
                    return Column(
                      children: [
                        ActivityCard(
                            date: '2024-01-15',
                            steps: 5420,
                            falls: 0,
                            tremors: 3),
                        ActivityCard(
                            date: '2024-01-14',
                            steps: 4890,
                            falls: 0,
                            tremors: 5),
                        ActivityCard(
                            date: '2024-01-13',
                            steps: 6120,
                            falls: 1,
                            tremors: 2),
                      ],
                    );
                  } else {
                    return SizedBox.shrink(); // fallback
                  }
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _infoCard({
  required Widget icon,
  required String label,
  required String value,
  required String time,
  required String unit,
}) {
  return Container(
    width: 150,
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.blue.shade50,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        icon,
        SizedBox(height: 8),
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text(time, style: TextStyle(color: Colors.grey)),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(unit, style: TextStyle(color: Colors.grey)),
      ],
    ),
  );
}

Widget _summarySection({
  required String bp,
  required int hr,
  required double temp,
  required int o2,
}) {
  return Container(
    width: double.infinity,
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
        color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Today's Summary", style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _summaryItem('BP', bp),
            _summaryItem('HR', '$hr bpm'),
            _summaryItem('Temp', '${temp}°F'),
            _summaryItem('O2', '$o2%'),
          ],
        ),
      ],
    ),
  );
}

Widget _summaryItem(String label, String value) {
  return Column(
    children: [
      Text(label, style: TextStyle(color: Colors.grey)),
      SizedBox(height: 4),
      Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
    ],
  );
}
