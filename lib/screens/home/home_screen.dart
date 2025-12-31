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
import 'package:kindura_ai/models/health/data_source_mode.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with SingleTickerProviderStateMixin {
  // Lazily get or create HomeController
  HomeController get homeController {
    if (!Get.isRegistered<HomeController>()) {
      Get.put(HomeController(), permanent: true);
    }
    return Get.find<HomeController>();
  }

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
                  
                  // Health widget - full width
                  GestureDetector(
                    onTap: () => Get.toNamed(RoutesName.vitalsHistoryScreen),
                    child: _buildWatchVitalsCard(),
                  ),

                  SizedBox(height: 12.h),

                  // AI Chat Button - small centered icon
                  Center(
                    child: GestureDetector(
                      onTap: () => Get.to(() => const ConservationScreen()),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(24.w),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                  Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.05),
                              spreadRadius: 0,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              color: Colors.purple,
                              size: 20.sp,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'Chat with Kindura',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                color: Colors.purple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
      final isLoading = homeController.watchVitalsStatus.value == Status.LOADING;
      final hasData = vitals['data_available'] == true;
      final source = vitals['source'] ?? 'none';

      // Vitals
      final heartRate = (vitals['heart_rate'] ?? 0).toInt();
      final bloodOxygen = (vitals['blood_oxygen'] ?? 0).toInt();
      final hrv = (vitals['hrv'] ?? 0).toInt();
      final respRate = (vitals['respiratory_rate'] ?? 0).toDouble();

      // Sleep
      final sleepHours = (vitals['sleep_hours'] ?? 0.0).toDouble();
      final sleepScore = (vitals['sleep_score'] ?? 0).toInt();
      final deepSleep = (vitals['deep_sleep_hours'] ?? 0.0).toDouble();
      final remSleep = (vitals['rem_sleep_hours'] ?? 0.0).toDouble();
      final coreSleep = (vitals['core_sleep_hours'] ?? 0.0).toDouble();
      final awakeSleep = (vitals['awake_hours'] ?? 0.0).toDouble();

      // Falls
      final fallsCount = vitals['falls_count'] ?? 0;
      final fallDetected = vitals['fall_detected'] ?? false;

      // Determine colors based on values
      Color heartRateColor = heartRate < 50 || heartRate > 100 ? Colors.orange : Colors.red;
      Color oxygenColor = bloodOxygen < 95 ? Colors.orange : Colors.cyan;
      Color sleepScoreColor = sleepScore >= 80 ? Colors.green : (sleepScore >= 50 ? Colors.orange : Colors.red);

      final isDark = Theme.of(context).brightness == Brightness.dark;
      final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
      final textColor = isDark ? Colors.white : Colors.black87;
      final subtextColor = isDark ? Colors.white70 : Colors.black54;

      // If loading, show loading indicator
      if (isLoading) {
        return Container(
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 24.w,
                height: 24.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'Syncing...',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: subtextColor,
                ),
              ),
            ],
          ),
        );
      }

      // If no data available, show "Syncing with Apple Health" message
      if (!hasData && heartRate == 0 && bloodOxygen == 0) {
        return Container(
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
                    width: 28.w,
                    height: 28.w,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6.w),
                    ),
                    child: Icon(Icons.watch, color: Colors.red, size: 14.sp),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    'Health',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.sync,
                      size: 32.sp,
                      color: subtextColor,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Syncing with Apple Health...',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: subtextColor,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Pull down to refresh',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: subtextColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

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
            // Header with data source mode indicator
            Row(
              children: [
                Container(
                  width: 28.w,
                  height: 28.w,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6.w),
                  ),
                  child: Icon(
                    homeController.dataSourceMode.value == DataSourceMode.appleWatch
                        ? Icons.watch
                        : Icons.favorite,
                    color: Colors.red,
                    size: 14.sp,
                  ),
                ),
                SizedBox(width: 6.w),
                Text(
                  'Health',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                SizedBox(width: 4.w),
                // Data source mode indicator
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: homeController.dataSourceMode.value == DataSourceMode.appleWatch
                        ? Colors.blue.withOpacity(0.1)
                        : homeController.dataSourceMode.value == DataSourceMode.healthKitOnly
                            ? Colors.green.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.w),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        homeController.dataSourceMode.value == DataSourceMode.appleWatch
                            ? Icons.watch
                            : homeController.dataSourceMode.value == DataSourceMode.healthKitOnly
                                ? Icons.favorite
                                : Icons.edit,
                        size: 10.sp,
                        color: homeController.dataSourceMode.value == DataSourceMode.appleWatch
                            ? Colors.blue
                            : homeController.dataSourceMode.value == DataSourceMode.healthKitOnly
                                ? Colors.green
                                : Colors.grey,
                      ),
                      SizedBox(width: 3.w),
                      Text(
                        homeController.dataSourceDisplayName,
                        style: TextStyle(
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w500,
                          color: homeController.dataSourceMode.value == DataSourceMode.appleWatch
                              ? Colors.blue
                              : homeController.dataSourceMode.value == DataSourceMode.healthKitOnly
                                  ? Colors.green
                                  : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Spacer(),
                // Fall alert badge - only show when fall detection is supported and detected
                if (homeController.supportsFallDetection && (fallDetected || fallsCount > 0))
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4.w),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning, color: Colors.red, size: 10.sp),
                        SizedBox(width: 2.w),
                        Text(
                          'Fall',
                          style: TextStyle(fontSize: 8.sp, color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8.h),

            // VITALS ROW - Heart Rate, Blood Oxygen, HRV, Resp Rate
            Row(
              children: [
                // Heart Rate
                Expanded(
                  child: _buildVitalItem(
                    Icons.favorite,
                    '$heartRate',
                    'bpm',
                    heartRateColor,
                    subtextColor,
                  ),
                ),
                // Blood Oxygen
                Expanded(
                  child: _buildVitalItem(
                    Icons.air,
                    '$bloodOxygen%',
                    'O₂',
                    oxygenColor,
                    subtextColor,
                  ),
                ),
                // HRV
                if (hrv > 0)
                  Expanded(
                    child: _buildVitalItem(
                      Icons.timeline,
                      '$hrv',
                      'HRV',
                      Colors.purple,
                      subtextColor,
                    ),
                  ),
                // Respiratory Rate
                if (respRate > 0)
                  Expanded(
                    child: _buildVitalItem(
                      Icons.waves,
                      '${respRate.toStringAsFixed(0)}',
                      'br/m',
                      Colors.teal,
                      subtextColor,
                    ),
                  ),
              ],
            ),

            // SLEEP SECTION - Always show all metrics
            SizedBox(height: 8.h),
            Divider(height: 1, color: subtextColor.withOpacity(0.2)),
            SizedBox(height: 8.h),

            // Sleep Header
            Row(
              children: [
                Icon(Icons.bedtime, color: Colors.indigo, size: 12.sp),
                SizedBox(width: 4.w),
                Text(
                  'Sleep',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Spacer(),
                // Total Hours
                Text(
                  sleepHours > 0 ? '${sleepHours.toStringAsFixed(1)}h' : '--',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                SizedBox(width: 8.w),
                // Score Badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: (sleepScore > 0 ? sleepScoreColor : Colors.grey).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4.w),
                  ),
                  child: Text(
                    sleepScore > 0 ? 'Score: $sleepScore' : 'Score: --',
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.bold,
                      color: sleepScore > 0 ? sleepScoreColor : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),

            // Sleep Stages Bar (show placeholder if no data)
            if (sleepHours > 0)
              _buildSleepStagesBar(deepSleep, remSleep, coreSleep, awakeSleep, sleepHours)
            else
              Container(
                height: 8.h,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4.w),
                ),
              ),
            SizedBox(height: 6.h),

            // Sleep Stage Labels - Always show
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSleepLabel('Deep', deepSleep, Color(0xFF1E3A8A)),
                _buildSleepLabel('REM', remSleep, Color(0xFF7C3AED)),
                _buildSleepLabel('Core', coreSleep, Color(0xFF0891B2)),
                _buildSleepLabel('Awake', awakeSleep, Color(0xFFF59E0B)),
              ],
            ),

            // ACTIVITY SECTION
            if ((vitals['steps'] ?? 0) > 0 || (vitals['calories'] ?? 0) > 0) ...[
              SizedBox(height: 8.h),
              Divider(height: 1, color: subtextColor.withOpacity(0.2)),
              SizedBox(height: 6.h),

              // Activity Header
              Row(
                children: [
                  Icon(Icons.directions_run, color: Colors.green, size: 11.sp),
                  SizedBox(width: 4.w),
                  Text(
                    'Activity',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),

              // Activity Row - Using Wrap to prevent overflow
              Wrap(
                spacing: 12.w,
                runSpacing: 4.h,
                children: [
                  // Steps
                  _buildActivityItem(Icons.directions_walk, '${_formatNumber(vitals['steps'] ?? 0)}', Colors.green),
                  // Calories
                  _buildActivityItem(Icons.local_fire_department, '${vitals['calories'] ?? 0}', Colors.deepOrange),
                  // Distance
                  if ((vitals['distance_km'] ?? 0) > 0)
                    _buildActivityItem(Icons.straighten, '${(vitals['distance_km'] ?? 0).toStringAsFixed(1)}km', Colors.blue),
                  // Exercise Minutes
                  if ((vitals['exercise_minutes'] ?? 0) > 0)
                    _buildActivityItem(Icons.fitness_center, '${vitals['exercise_minutes']}m', Colors.pink),
                  // Floors Climbed
                  if ((vitals['floors_climbed'] ?? 0) > 0)
                    _buildActivityItem(Icons.stairs, '${vitals['floors_climbed']}fl', Colors.purple),
                ],
              ),
            ],

            // FALL DETECTION SECTION - Conditional based on data source mode
            SizedBox(height: 8.h),
            Divider(height: 1, color: subtextColor.withOpacity(0.2)),
            SizedBox(height: 6.h),
            Row(
              children: [
                Icon(
                  homeController.supportsFallDetection
                      ? (fallDetected ? Icons.warning_amber_rounded : Icons.health_and_safety)
                      : Icons.info_outline,
                  color: homeController.supportsFallDetection
                      ? (fallDetected ? Colors.red : Colors.green)
                      : Colors.grey,
                  size: 12.sp,
                ),
                SizedBox(width: 4.w),
                Text(
                  'Falls',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Spacer(),
                // Show different content based on whether fall detection is supported
                if (homeController.supportsFallDetection)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: (fallDetected || fallsCount > 0)
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.w),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (fallDetected) ...[
                          Icon(Icons.warning, color: Colors.red, size: 10.sp),
                          SizedBox(width: 4.w),
                          Text(
                            'Fall Detected!',
                            style: TextStyle(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ] else if (fallsCount > 0) ...[
                          Text(
                            '$fallsCount today',
                            style: TextStyle(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.red,
                            ),
                          ),
                        ] else ...[
                          Icon(Icons.check_circle, color: Colors.green, size: 10.sp),
                          SizedBox(width: 4.w),
                          Text(
                            'No falls',
                            style: TextStyle(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  // Fall detection not available (HealthKit-only mode)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.w),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.watch_off, color: Colors.grey, size: 10.sp),
                        SizedBox(width: 4.w),
                        Text(
                          'Requires Apple Watch',
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildVitalItem(IconData icon, String value, String label, Color color, Color subtextColor) {
    return Column(
      children: [
        Icon(icon, color: color, size: 12.sp),
        SizedBox(height: 2.h),
        Text(
          value,
          style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 7.sp, color: subtextColor),
        ),
      ],
    );
  }

  Widget _buildActivityItem(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 11.sp),
        SizedBox(width: 2.w),
        Text(
          value,
          style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }

  Widget _buildSleepStagesBar(double deep, double rem, double core, double awake, double total) {
    if (total == 0) return SizedBox.shrink();

    return Container(
      height: 8.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4.w),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4.w),
        child: Row(
          children: [
            if (deep > 0)
              Expanded(
                flex: (deep / total * 100).round(),
                child: Container(color: Color(0xFF1E3A8A)), // Deep - dark blue
              ),
            if (rem > 0)
              Expanded(
                flex: (rem / total * 100).round(),
                child: Container(color: Color(0xFF7C3AED)), // REM - purple
              ),
            if (core > 0)
              Expanded(
                flex: (core / total * 100).round(),
                child: Container(color: Color(0xFF0891B2)), // Core - cyan
              ),
            if (awake > 0)
              Expanded(
                flex: (awake / total * 100).round(),
                child: Container(color: Color(0xFFF59E0B)), // Awake - amber
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepLabel(String label, double hours, Color color) {
    return Column(
      children: [
        Container(
          width: 8.w,
          height: 8.w,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.w),
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          hours > 0 ? '${hours.toStringAsFixed(1)}h' : '-',
          style: TextStyle(fontSize: 8.sp, fontWeight: FontWeight.w500, color: color),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 6.sp, color: Colors.grey),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
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
