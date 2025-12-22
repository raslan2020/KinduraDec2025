import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/common_widgets/loading_indicator.dart';
import 'package:kindura_ai/common_widgets/agent_loading_indicator.dart';
import 'package:kindura_ai/common_widgets/performance_debug_widget.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/screens/home/home_controller.dart';
import 'package:kindura_ai/screens/medication/medication_controller.dart';
import 'package:kindura_ai/screens/labs/labs_controller.dart';
import 'package:kindura_ai/screens/conservation/conservation_screen.dart';
import 'package:kindura_ai/screens/bottom_navigation/bottom_navigation_controller.dart';
import 'package:kindura_ai/res/routes/routes_name.dart';
import 'package:kindura_ai/services/theme_service.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with SingleTickerProviderStateMixin {
  final homeController = Get.find<HomeController>();
  final medicationController = Get.put(MedicationController());
  final labsController = Get.put(LabsController());

  final peachColor = const Color(0xFFF9A58A);
  final redColor = const Color(0xFFE53935);

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text("Kindura AI"),
            automaticallyImplyLeading: false,
            // logout button
            actions: [
              IconButton(
                onPressed: () {
                  homeController.showDebugWidget();
                },
                icon: const Icon(Icons.bug_report),
                tooltip: 'Performance Monitor',
              ),
              IconButton(
                onPressed: () {
                  homeController.logout();
                },
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          // floatingActionButton: FloatingActionButton(
          //   onPressed: () {
          //     Get.toNamed(RoutesName.pdfUploadScreen);
          //   },
          //   backgroundColor: Colors.blue,
          //   child: Icon(Icons.upload_file, color: Colors.white),
          //   tooltip: 'Upload PDF',
          // ),
          body: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                medicationController.loadMedications(forceRefresh: true),
                medicationController.loadAdherenceSummary(),
                labsController.loadLabsData(),
                homeController.loadWatchVitals(),
              ]);
            },
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good ${_getGreeting()},',
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Your Health Dashboard',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 24.h),
                  
                  // Quick actions
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Get.toNamed(RoutesName.vitalsHistoryScreen),
                          child: _buildWatchVitalsCard(),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildQuickActionCard(
                          icon: Icons.chat_bubble_outline,
                          title: 'AI Conversation',
                          subtitle: 'Chat with Kindura',
                          color: Colors.purple,
                          onTap: () => Get.to(() => const ConservationScreen()),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 24.h),
                  
                  // Medication Summary Card
                  _buildMedicationSummaryCard(),
                  
                  SizedBox(height: 16.h),
                  
                  // Lab Results Summary Card
                  _buildLabSummaryCard(),
                  
                  SizedBox(height: 16.h),
                  
                  // Voice Status Card
                  _buildVoiceStatusCard(),
                  
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ),
        ),
        Obx(() {
          switch (homeController.agentStatus.value) {
            case Status.COMPLETED:
              return Container();
            case Status.LOADING:
              return Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: AgentLoadingIndicator(),
                ),
              );
            case Status.ERROR:
              return Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: Text(
                    "Something Went Wrong",
                    style: TextStyle(color: Colors.amber),
                  ),
                ),
              );
          }
        }),
        Obx(() {
          switch (homeController.requestStatus.value) {
            case Status.COMPLETED:
              return Container();
            case Status.LOADING:
              return Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: LoadingIndicator(),
                ),
              );
            case Status.ERROR:
              return Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: Text(
                    "Something Went Wrong",
                    style: TextStyle(color: Colors.amber),
                  ),
                ),
              );
          }
        }),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  Widget _buildWatchVitalsCard() {
    return Obx(() {
      final vitals = homeController.watchVitals.value;
      final heartRate = (vitals['heart_rate'] ?? 72).toInt();
      final bloodOxygen = (vitals['blood_oxygen'] ?? 98).toInt();
      final sleepHours = (vitals['sleep_hours'] ?? 0.0);
      final awakenings = vitals['awakenings'] ?? 0;
      final sleepQuality = vitals['sleep_quality'] ?? 'unknown';
      final fallsCount = vitals['falls_count'] ?? 0;

      // Determine colors based on values
      Color heartRateColor = heartRate < 50 || heartRate > 100 ? Colors.orange : Colors.red;
      Color sleepColor = sleepHours < 6 ? Colors.orange : Colors.indigo;
      Color oxygenColor = bloodOxygen < 95 ? Colors.orange : Colors.cyan;

      // Sleep quality text
      String sleepText = sleepHours > 0
          ? '${sleepHours.toStringAsFixed(1)}h'
          : 'No data';
      String qualityText = sleepQuality != 'unknown'
          ? ' ($sleepQuality)'
          : '';

      final isDark = Theme.of(context).brightness == Brightness.dark;
      final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
      final textColor = isDark ? Colors.white : Colors.black87;
      final subtextColor = isDark ? Colors.white70 : Colors.black54;

      return Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12.w),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              spreadRadius: 0,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32.w,
                  height: 32.w,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.w),
                  ),
                  child: Icon(Icons.watch, color: Colors.red, size: 16.sp),
                ),
                SizedBox(width: 6.w),
                Text(
                  'Watch',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            // Heart rate
            Row(
              children: [
                Icon(Icons.favorite, color: heartRateColor, size: 12.sp),
                SizedBox(width: 3.w),
                Text(
                  '$heartRate',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: heartRateColor,
                  ),
                ),
                Text(
                  ' bpm',
                  style: TextStyle(fontSize: 8.sp, color: subtextColor),
                ),
              ],
            ),
            SizedBox(height: 3.h),
            // Blood Oxygen
            Row(
              children: [
                Icon(Icons.air, color: oxygenColor, size: 12.sp),
                SizedBox(width: 3.w),
                Text(
                  '$bloodOxygen%',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: oxygenColor,
                  ),
                ),
                Text(
                  ' O₂',
                  style: TextStyle(fontSize: 8.sp, color: subtextColor),
                ),
              ],
            ),
            SizedBox(height: 3.h),
            // Sleep with quality
            Row(
              children: [
                Icon(Icons.bedtime, color: sleepColor, size: 12.sp),
                SizedBox(width: 3.w),
                Expanded(
                  child: Text(
                    sleepText + qualityText,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                      color: sleepColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (awakenings > 0) ...[
              SizedBox(height: 2.h),
              Text(
                '  $awakenings wake-ups',
                style: TextStyle(fontSize: 8.sp, color: subtextColor),
              ),
            ],
            if (fallsCount > 0) ...[
              SizedBox(height: 3.h),
              Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange, size: 12.sp),
                  SizedBox(width: 3.w),
                  Text(
                    '$fallsCount falls',
                    style: TextStyle(
                      fontSize: 9.sp,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12.w),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              spreadRadius: 0,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.w),
              ),
              child: Icon(icon, color: color, size: 20.sp),
            ),
            SizedBox(height: 12.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12.sp,
                color: subtextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationSummaryCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;
    final dividerColor = isDark ? Colors.white24 : Colors.black12;

    return Obx(() => GestureDetector(
      onTap: () {
        // Switch to Meds & Vitamins tab (index 2) using the controller
        final navController = Get.find<BottomNavController>();
        navController.currentIndex.value = 2;
      },
      child: Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            spreadRadius: 0,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.w),
                ),
                child: Icon(Icons.medication, color: Colors.blue, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medications Today',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'Next dose coming up',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: subtextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16.sp, color: subtextColor),
            ],
          ),
          SizedBox(height: 16.h),
          Obx(() => Row(
            children: [
              Expanded(
                child: _buildMedicationStat(
                  'Taken',
                  medicationController.medicationAnalytics.value?['todayTaken'] ?? 0,
                  Colors.green,
                  isDark,
                ),
              ),
              Container(width: 1.w, height: 30.h, color: dividerColor),
              Expanded(
                child: _buildMedicationStat(
                  'Pending',
                  medicationController.medicationAnalytics.value?['todayPending'] ?? 0,
                  Colors.orange,
                  isDark,
                ),
              ),
              Container(width: 1.w, height: 30.h, color: dividerColor),
              Expanded(
                child: _buildMedicationStat(
                  'Missed',
                  medicationController.medicationAnalytics.value?['todayMissed'] ?? 0,
                  Colors.red,
                  isDark,
                ),
              ),
            ],
          )),
          if (medicationController.upcomingReminders.isNotEmpty) ...[
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8.w),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 16.sp, color: Colors.blue),
                  SizedBox(width: 8.w),
                  Text(
                    'Next: Medication at ${medicationController.upcomingReminders.first.scheduledTime != null ? _formatTime(medicationController.upcomingReminders.first.scheduledTime!) : "N/A"}',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
    ));
  }

  Widget _buildLabSummaryCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;
    final dividerColor = isDark ? Colors.white24 : Colors.black12;

    return Obx(() => GestureDetector(
      onTap: () {
        final navController = Get.find<BottomNavController>();
        navController.currentIndex.value = 1;
      },
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12.w),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              spreadRadius: 0,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.w),
                  ),
                  child: Icon(Icons.science, color: Colors.green, size: 20.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lab Results',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'Track your biomarkers',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16.sp, color: subtextColor),
              ],
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: _buildLabStat(
                    'Total',
                    labsController.labsSummary.value?.totalBiomarkers ?? 0,
                    Colors.blue,
                    isDark,
                  ),
                ),
                Container(width: 1.w, height: 30.h, color: dividerColor),
                Expanded(
                  child: _buildLabStat(
                    'Abnormal',
                    labsController.labsSummary.value?.abnormalCount ?? 0,
                    Colors.orange,
                    isDark,
                  ),
                ),
                Container(width: 1.w, height: 30.h, color: dividerColor),
                Expanded(
                  child: _buildLabStat(
                    'Critical',
                    labsController.labsSummary.value?.criticalCount ?? 0,
                    Colors.red,
                    isDark,
                  ),
                ),
              ],
            ),
            if (labsController.healthInsights.isNotEmpty) ...[
              SizedBox(height: 16.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: isDark ? Colors.amber.shade900.withOpacity(0.3) : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8.w),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb, size: 16.sp, color: isDark ? Colors.amber.shade300 : Colors.amber.shade700),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        '${labsController.healthInsights.length} health insights available',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: isDark ? Colors.amber.shade300 : Colors.amber.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ));
  }

  Widget _buildVoiceStatusCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;

    return Obx(() => Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            spreadRadius: 0,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: (homeController.isConnected.value
                    ? redColor : peachColor).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.w),
                ),
                child: Icon(
                  Icons.mic,
                  color: homeController.isConnected.value ? redColor : peachColor,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homeController.isConnected.value
                        ? 'Kindura is Listening'
                        : 'Voice Assistant',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      homeController.isConnected.value
                        ? 'Ready for your voice commands'
                        : 'Say "Hi Kindura" to start',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: subtextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            'Voice commands you can try:',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
          SizedBox(height: 8.h),
          ...['I took my morning medication', 'Show my lab results', 'What are my upcoming doses?'].map(
            (command) => Padding(
              padding: EdgeInsets.only(bottom: 4.h),
              child: Row(
                children: [
                  Text('• ', style: TextStyle(color: subtextColor, fontSize: 12.sp)),
                  Text(
                    command,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: subtextColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ).toList(),
        ],
      ),
    ));
  }

  Widget _buildMedicationStat(String label, int count, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildLabStat(String label, int count, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}
