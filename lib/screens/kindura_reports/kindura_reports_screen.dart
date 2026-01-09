import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:kindura_ai/common_widgets/loading_indicator.dart';
import 'package:kindura_ai/data/network/network_api_services.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/res/app_url/app_url.dart';
import 'package:kindura_ai/res/assets/image_constant.dart';
import 'package:kindura_ai/res/colors/app_color.dart';
import 'package:kindura_ai/screens/bottom_navigation/bottom_navigation_controller.dart';
import 'package:kindura_ai/screens/home/home_controller.dart';
import 'package:kindura_ai/services/report_generation_service.dart';
import 'package:url_launcher/url_launcher.dart';

class KinduraReportsScreen extends StatefulWidget {
  const KinduraReportsScreen({super.key});

  @override
  State<KinduraReportsScreen> createState() => _KinduraReportsScreenState();
}

class _KinduraReportsScreenState extends State<KinduraReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _apiService = NetworkApiServices();

  final reports = <Map<String, dynamic>>[].obs;
  final status = Status.LOADING.obs;
  final selectedType = 'daily'.obs;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        switch (_tabController.index) {
          case 0:
            selectedType.value = 'daily';
            break;
          case 1:
            selectedType.value = 'weekly';
            break;
          case 2:
            selectedType.value = 'monthly';
            break;
        }
        loadReports();
      }
    });
    loadReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> loadReports() async {
    status.value = Status.LOADING;
    try {
      final response = await _apiService.getApi(
        AppUrl.patientReportsUrl,
        queryParameters: {'type': selectedType.value, 'limit': '20'},
      );

      if (response['status'] == true) {
        reports.value = List<Map<String, dynamic>>.from(response['result'] ?? []);
        status.value = Status.COMPLETED;
      } else {
        status.value = Status.ERROR;
      }
    } catch (e) {
      print('Error loading reports: $e');
      status.value = Status.ERROR;
    }
  }

  Future<void> _generateNewReport() async {
    Get.dialog(
      AlertDialog(
        title: Text('Generate Report'),
        content: Text('Generate a new ${selectedType.value} report with comprehensive health analytics?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Close dialog immediately using Get.back()
              Get.back();
              // Trigger generation in next frame
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _triggerReportGeneration();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColor.primaryColor,
            ),
            child: Text('Generate'),
          ),
        ],
      ),
      barrierDismissible: true,
    );
  }

  Future<void> _triggerReportGeneration() async {
    // Use background service for seamless generation
    if (!Get.isRegistered<ReportGenerationService>()) {
      Get.snackbar(
        'Error',
        'Report generation service not available',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final service = Get.find<ReportGenerationService>();

    // Check if already generating
    if (service.isGenerating.value) {
      Get.snackbar(
        'In Progress',
        'A report is already being generated. Please wait.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Set up completion callback to refresh reports
    service.onReportCompleted = (reportId, reportType) {
      if (selectedType.value == reportType) {
        loadReports();
      }
    };

    // Start background generation
    final reportId = await service.generateReport(selectedType.value);

    if (reportId != null) {
      Get.snackbar(
        'Generating Report',
        'Your ${selectedType.value} report is being generated in the background.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColor.black;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Kindura Reports',
          style: TextStyle(color: textColor),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Get.back();
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_chart, color: AppColor.primaryColor),
            onPressed: _generateNewReport,
            tooltip: 'Generate Report',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColor.primaryColor,
          unselectedLabelColor: isDark ? Colors.grey.shade400 : AppColor.textSecondary,
          indicatorColor: AppColor.primaryColor,
          tabs: const [
            Tab(text: 'Daily'),
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
          ],
        ),
      ),
      body: Stack(
        children: [
          Obx(() {
            if (status.value == Status.LOADING) {
              return Center(child: LoadingIndicator());
            }

            if (reports.isEmpty) {
              return _buildEmptyState();
            }

            return RefreshIndicator(
              onRefresh: loadReports,
              child: ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: reports.length,
                itemBuilder: (context, index) => _buildReportCard(reports[index]),
              ),
            );
          }),
          // Note: ReportProgressOverlay is now shown globally in bottom_navigation_screen
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBarBg = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final navPillBg = isDark ? const Color(0xFF252538) : const Color(0xFFF1F5F9);
    final navItemBg = isDark ? const Color(0xFF252538) : const Color(0xFFE2E8F0);
    final navItemSelectedBg = isDark ? const Color(0xFF2D2D44) : AppColor.primaryColor.withOpacity(0.15);
    final navIconColor = isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B);
    final navIconSelectedColor = isDark ? Colors.white : AppColor.primaryColor;
    final containerShadowColor = isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.06);

    // Mic button colors
    const peachColor = Color(0xFFF9A58A);
    const redColor = Color(0xFFE53935);

    HomeController? homeController;
    try {
      homeController = Get.find<HomeController>();
    } catch (_) {
      homeController = null;
    }

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom > 0 ? 8.h : 12.h),
      decoration: BoxDecoration(
        color: navBarBg,
        boxShadow: [
          BoxShadow(
            color: containerShadowColor,
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Container(
        height: 72.h,
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        decoration: BoxDecoration(
          color: navPillBg,
          borderRadius: BorderRadius.circular(40),
          border: isDark ? null : Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(context, ImageConstant.voiceIcon, 'Home', 0, isDark, navItemBg, navItemSelectedBg, navIconColor, navIconSelectedColor),
            _buildNavItem(context, ImageConstant.reportCheckupIcon, 'Labs', 1, isDark, navItemBg, navItemSelectedBg, navIconColor, navIconSelectedColor),
            // Center mic button
            GestureDetector(
              onTap: () {
                if (homeController != null) {
                  if (homeController.isConnected.value) {
                    homeController.disconnect();
                  } else {
                    homeController.connectToRoom();
                  }
                }
              },
              child: Obx(() {
                final isConnected = homeController?.isConnected.value ?? false;
                return Container(
                  width: 56.w,
                  height: 56.w,
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isConnected
                          ? [const Color(0xFFFF6B6B), redColor]
                          : [const Color(0xFFFFB199), peachColor],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isConnected ? redColor : peachColor).withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    isConnected ? Icons.mic_off_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 28.sp,
                  ),
                );
              }),
            ),
            _buildNavItem(context, ImageConstant.medVitaminIcon, 'Meds', 2, isDark, navItemBg, navItemSelectedBg, navIconColor, navIconSelectedColor),
            _buildNavItem(context, ImageConstant.profileIcon, 'Profile', 3, isDark, navItemBg, navItemSelectedBg, navIconColor, navIconSelectedColor),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    String asset,
    String label,
    int index,
    bool isDark,
    Color navItemBg,
    Color navItemSelectedBg,
    Color navIconColor,
    Color navIconSelectedColor,
  ) {
    return GestureDetector(
      onTap: () {
        // Navigate back first
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        // Change tab if controller is available
        if (Get.isRegistered<BottomNavController>()) {
          final navController = Get.find<BottomNavController>();
          navController.changeTabIndex(index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44.w,
        height: 44.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: navItemBg,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              asset,
              width: 18.w,
              height: 18.w,
              colorFilter: ColorFilter.mode(
                navIconColor,
                BlendMode.srcIn,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 7.sp,
                fontWeight: FontWeight.w400,
                color: navIconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColor.textPrimary;
    final subtextColor = isDark ? Colors.grey.shade400 : AppColor.textSecondary;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64.sp,
            color: subtextColor,
          ),
          SizedBox(height: 16.h),
          Text(
            'No ${selectedType.value} reports yet',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Text(
              'Tap the + button to generate your first comprehensive health report.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: subtextColor,
              ),
            ),
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: _generateNewReport,
            icon: Icon(Icons.add_chart),
            label: Text('Generate Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColor.primaryColor,
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : AppColor.textPrimary;
    final subtextColor = isDark ? Colors.grey.shade400 : AppColor.textSecondary;

    final adherencePercentage = (report['adherence_percentage'] ?? 0).toDouble();
    final adherenceGrade = report['adherence_grade'] ?? 'N/A';
    final reportDate = report['report_date'] ?? '';
    final dosesTaken = report['doses_taken'] ?? 0;
    final dosesMissed = report['doses_missed'] ?? 0;
    final sideEffectsCount = report['side_effects_count'] ?? 0;
    final overallScore = report['overall_health_score'] ?? 0;
    final sleepScore = report['sleep_score'] ?? 0;
    final vitalsScore = report['vitals_score'] ?? 0;
    final fallCount = report['fall_count'] ?? 0;

    Color getAdherenceColor() {
      if (adherencePercentage >= 85) return AppColor.success;
      if (adherencePercentage >= 70) return AppColor.warning;
      return AppColor.danger;
    }

    Color getScoreColor(int score) {
      if (score >= 80) return AppColor.success;
      if (score >= 60) return AppColor.warning;
      return AppColor.danger;
    }

    return GestureDetector(
      onTap: () => _showReportDetail(report),
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12.w),
          border: isDark ? Border.all(color: Colors.grey.shade700) : null,
          boxShadow: isDark ? null : [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with date and overall score
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reportDate,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${selectedType.value.capitalize} Report',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: subtextColor,
                      ),
                    ),
                  ],
                ),
                // Overall Health Score Circle
                if (overallScore > 0)
                  Container(
                    width: 50.w,
                    height: 50.w,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: overallScore / 100,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(getScoreColor(overallScore)),
                          strokeWidth: 4,
                        ),
                        Text(
                          '$overallScore',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: getScoreColor(overallScore),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: getAdherenceColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4.w),
                    ),
                    child: Text(
                      adherenceGrade,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: getAdherenceColor(),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12.h),

            // Health Scores Row
            if (overallScore > 0) ...[
              Row(
                children: [
                  _buildMiniScoreItem('Adherence', report['adherence_score'] ?? 0),
                  SizedBox(width: 12.w),
                  _buildMiniScoreItem('Sleep', sleepScore),
                  SizedBox(width: 12.w),
                  _buildMiniScoreItem('Vitals', vitalsScore),
                ],
              ),
              SizedBox(height: 12.h),
            ],

            // Adherence bar
            Row(
              children: [
                Text(
                  'Med Adherence',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: subtextColor,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4.w),
                    child: LinearProgressIndicator(
                      value: adherencePercentage / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(getAdherenceColor()),
                      minHeight: 6.h,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  '${adherencePercentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: getAdherenceColor(),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),

            // Stats row
            Row(
              children: [
                _buildStatItem(Icons.check_circle, '$dosesTaken taken', AppColor.success),
                SizedBox(width: 12.w),
                _buildStatItem(Icons.cancel, '$dosesMissed missed', AppColor.danger),
                if (sideEffectsCount > 0) ...[
                  SizedBox(width: 12.w),
                  _buildStatItem(Icons.warning, '$sideEffectsCount effects', AppColor.warning),
                ],
                if (fallCount > 0) ...[
                  SizedBox(width: 12.w),
                  _buildStatItem(Icons.personal_injury, '$fallCount falls', AppColor.danger),
                ],
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'View Details',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColor.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 4.w),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12.sp,
                  color: AppColor.primaryColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniScoreItem(String label, int score) {
    Color color;
    if (score >= 80) {
      color = AppColor.success;
    } else if (score >= 60) {
      color = AppColor.warning;
    } else {
      color = AppColor.danger;
    }

    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 8.w),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6.w),
        ),
        child: Column(
          children: [
            Text(
              '$score',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.sp,
                color: AppColor.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14.sp, color: color),
        SizedBox(width: 4.w),
        Text(
          text,
          style: TextStyle(
            fontSize: 11.sp,
            color: AppColor.textSecondary,
          ),
        ),
      ],
    );
  }

  void _showReportDetail(Map<String, dynamic> report) {
    Get.bottomSheet(
      _ReportDetailSheet(report: report, onGeneratePdf: _generateAndDownloadPdf),
      isScrollControlled: true,
    );
  }

  Future<void> _generateAndDownloadPdf(Map<String, dynamic> report) async {
    final reportId = report['id'];
    if (reportId == null) {
      Get.snackbar('Error', 'Report ID not found');
      return;
    }

    Get.dialog(
      Center(child: LoadingIndicator()),
      barrierDismissible: false,
    );

    try {
      final response = await _apiService.postApi(
        {},
        '${AppUrl.patientReportsUrl}$reportId/generate_pdf/',
      );

      Get.back(); // Close loading dialog

      if (response['status'] == true && response['result'] != null) {
        final pdfUrl = response['result']['pdf_url'];
        if (pdfUrl != null) {
          final fullUrl = pdfUrl.startsWith('http')
              ? pdfUrl
              : '${AppUrl.baseUrl.replaceAll('/api', '')}$pdfUrl';

          Get.dialog(
            AlertDialog(
              title: Text('PDF Generated'),
              content: Text('Your report PDF has been generated successfully.'),
              actions: [
                TextButton(
                  onPressed: () => Get.back(),
                  child: Text('Close'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Get.back();
                    final uri = Uri.parse(fullUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } else {
                      Get.snackbar('Error', 'Could not open PDF');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColor.primaryColor,
                  ),
                  child: Text('Open PDF'),
                ),
              ],
            ),
          );
        }
        loadReports();
      } else {
        Get.snackbar(
          'Error',
          response['message'] ?? 'Failed to generate PDF',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.back();
      print('Error generating PDF: $e');
      Get.snackbar(
        'Error',
        'Failed to generate PDF: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}

// Separate widget for report detail sheet
class _ReportDetailSheet extends StatelessWidget {
  final Map<String, dynamic> report;
  final Function(Map<String, dynamic>) onGeneratePdf;

  const _ReportDetailSheet({
    required this.report,
    required this.onGeneratePdf,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : AppColor.textPrimary;
    final subtextColor = isDark ? Colors.grey.shade400 : AppColor.textSecondary;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.w)),
      ),
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(top: 12.h),
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2.w),
            ),
          ),
          Expanded(
            child: DefaultTabController(
              length: 5,
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${report['report_type']?.toString().capitalize ?? ''} Report',
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Text(
                              report['report_date'] ?? '',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: subtextColor,
                              ),
                            ),
                          ],
                        ),
                        _buildOverallScoreWidget(),
                      ],
                    ),
                  ),
                  // Tab bar
                  TabBar(
                    labelColor: AppColor.primaryColor,
                    unselectedLabelColor: subtextColor,
                    indicatorColor: AppColor.primaryColor,
                    labelStyle: TextStyle(fontSize: 11.sp),
                    isScrollable: true,
                    tabs: const [
                      Tab(text: 'Summary'),
                      Tab(text: 'Vitals'),
                      Tab(text: 'Sleep'),
                      Tab(text: 'Labs'),
                      Tab(text: 'Meds'),
                    ],
                  ),
                  // Tab content
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildSummaryTab(),
                        _buildVitalsTab(),
                        _buildSleepTab(),
                        _buildLabsTab(),
                        _buildMedicationsTab(),
                      ],
                    ),
                  ),
                  // Bottom action
                  SafeArea(
                    child: Padding(
                      padding: EdgeInsets.all(16.w),
                      child: ElevatedButton.icon(
                        onPressed: () => onGeneratePdf(report),
                        icon: Icon(Icons.picture_as_pdf),
                        label: Text('Generate PDF Report'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColor.primaryColor,
                          minimumSize: Size(double.infinity, 48.h),
                        ),
                      ),
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

  Widget _buildOverallScoreWidget() {
    final score = report['overall_health_score'] ?? 0;
    if (score == 0) return SizedBox.shrink();

    Color color;
    if (score >= 80) {
      color = AppColor.success;
    } else if (score >= 60) {
      color = AppColor.warning;
    } else {
      color = AppColor.danger;
    }

    return Container(
      width: 60.w,
      height: 60.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color),
            strokeWidth: 5,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                'Score',
                style: TextStyle(
                  fontSize: 8.sp,
                  color: AppColor.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    final fallCount = report['fall_count'] ?? 0;
    final fallEvents = report['fall_events'] as List? ?? [];

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        // Health Scores Card
        _buildScoresCard(),
        SizedBox(height: 16.h),

        // Fall Alert (if any)
        if (fallCount > 0) ...[
          _buildFallAlertCard(fallCount, fallEvents),
          SizedBox(height: 16.h),
        ],

        // Doctor Summary
        _buildDetailSection(
          'Doctor Summary',
          report['ai_doctor_summary'] ?? report['ai_summary'],
          icon: Icons.medical_services,
          color: Colors.blue,
        ),

        // Patient Summary
        if (report['ai_patient_summary'] != null)
          _buildDetailSection(
            'Your Summary',
            report['ai_patient_summary'],
            icon: Icons.person,
            color: Colors.green,
          ),

        // Concerns
        if (report['ai_concerns'] != null && report['ai_concerns'].toString().isNotEmpty)
          _buildDetailSection(
            'Concerns',
            report['ai_concerns'],
            icon: Icons.warning,
            color: Colors.orange,
            isWarning: true,
          ),

        // Recommendations
        _buildDetailSection(
          'Recommendations',
          report['ai_recommendations'],
          icon: Icons.lightbulb,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildScoresCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColor.primaryColor, AppColor.primaryColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.w),
      ),
      child: Column(
        children: [
          Text(
            'Health Scores',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildScoreCircle('Adherence', report['adherence_score'] ?? 0),
              _buildScoreCircle('Sleep', report['sleep_score'] ?? 0),
              _buildScoreCircle('Vitals', report['vitals_score'] ?? 0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCircle(String label, int score) {
    return Column(
      children: [
        Container(
          width: 50.w,
          height: 50.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.2),
          ),
          child: Center(
            child: Text(
              '$score',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildFallAlertCard(int fallCount, List fallEvents) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColor.danger.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.w),
        border: Border.all(color: AppColor.danger.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.personal_injury, color: AppColor.danger, size: 24.sp),
              SizedBox(width: 8.w),
              Text(
                '$fallCount Fall${fallCount > 1 ? 's' : ''} Detected',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColor.danger,
                ),
              ),
            ],
          ),
          if (fallEvents.isNotEmpty) ...[
            SizedBox(height: 8.h),
            ...fallEvents.take(3).map((event) => Padding(
                  padding: EdgeInsets.only(bottom: 4.h),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 6.sp, color: AppColor.danger),
                      SizedBox(width: 6.w),
                      Text(
                        '${event['date'] ?? ''} at ${event['time'] ?? ''}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColor.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildVitalsTab() {
    final vitalsAnalytics = report['vitals_analytics'] as Map<String, dynamic>? ?? {};
    final heartRate = vitalsAnalytics['heart_rate'] as Map<String, dynamic>? ?? {};
    final bloodOxygen = vitalsAnalytics['blood_oxygen'] as Map<String, dynamic>? ?? {};
    final hrv = vitalsAnalytics['hrv'] as Map<String, dynamic>? ?? {};

    if (vitalsAnalytics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.watch_off, size: 48.sp, color: AppColor.textSecondary),
            SizedBox(height: 16.h),
            Text(
              'No vitals data available',
              style: TextStyle(
                fontSize: 16.sp,
                color: AppColor.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        // AI Vitals Analysis
        if (report['ai_vitals_analysis'] != null)
          _buildDetailSection(
            'Vitals Analysis',
            report['ai_vitals_analysis'],
            icon: Icons.favorite,
            color: Colors.red,
          ),

        // Heart Rate Card
        _buildVitalCard(
          'Heart Rate',
          '${heartRate['avg']?.toStringAsFixed(0) ?? 'N/A'} bpm',
          heartRate['min']?.toString() ?? 'N/A',
          heartRate['max']?.toString() ?? 'N/A',
          Icons.favorite,
          Colors.red,
          _buildHeartRateChart(heartRate),
        ),

        SizedBox(height: 16.h),

        // Blood Oxygen Card
        _buildVitalCard(
          'Blood Oxygen',
          '${bloodOxygen['avg']?.toStringAsFixed(1) ?? 'N/A'}%',
          bloodOxygen['min']?.toString() ?? 'N/A',
          bloodOxygen['max']?.toString() ?? 'N/A',
          Icons.air,
          Colors.blue,
          _buildSpO2Chart(bloodOxygen),
        ),

        SizedBox(height: 16.h),

        // HRV Card
        _buildVitalCard(
          'Heart Rate Variability',
          '${hrv['avg']?.toStringAsFixed(0) ?? 'N/A'} ms',
          hrv['min']?.toString() ?? 'N/A',
          hrv['max']?.toString() ?? 'N/A',
          Icons.show_chart,
          Colors.purple,
          _buildHRVChart(hrv),
        ),
      ],
    );
  }

  Widget _buildVitalCard(
    String title,
    String avgValue,
    String minValue,
    String maxValue,
    IconData icon,
    Color color,
    Widget? chart,
  ) {
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
            children: [
              Icon(icon, color: color, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColor.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Average',
                    style: TextStyle(fontSize: 11.sp, color: AppColor.textSecondary),
                  ),
                  Text(
                    avgValue,
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Text('Min', style: TextStyle(fontSize: 10.sp, color: AppColor.textSecondary)),
                  Text(minValue, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
                ],
              ),
              Column(
                children: [
                  Text('Max', style: TextStyle(fontSize: 10.sp, color: AppColor.textSecondary)),
                  Text(maxValue, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          if (chart != null) ...[
            SizedBox(height: 16.h),
            SizedBox(
              height: 120.h,
              child: chart,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeartRateChart(Map<String, dynamic> heartRate) {
    final dailyAvg = heartRate['daily_avg'] as List? ?? [];
    if (dailyAvg.isEmpty) return SizedBox.shrink();

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: dailyAvg.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), (e.value['avg'] ?? 0).toDouble());
            }).toList(),
            isCurved: true,
            color: Colors.red,
            barWidth: 2,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.red.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpO2Chart(Map<String, dynamic> bloodOxygen) {
    final dailyAvg = bloodOxygen['daily_avg'] as List? ?? [];
    if (dailyAvg.isEmpty) return SizedBox.shrink();

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: dailyAvg.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), (e.value['avg'] ?? 0).toDouble());
            }).toList(),
            isCurved: true,
            color: Colors.blue,
            barWidth: 2,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHRVChart(Map<String, dynamic> hrv) {
    final dailyAvg = hrv['daily_avg'] as List? ?? [];
    if (dailyAvg.isEmpty) return SizedBox.shrink();

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: dailyAvg.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), (e.value['avg'] ?? 0).toDouble());
            }).toList(),
            isCurved: true,
            color: Colors.purple,
            barWidth: 2,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.purple.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepTab() {
    final sleepAnalytics = report['sleep_analytics'] as Map<String, dynamic>? ?? {};
    final records = sleepAnalytics['records'] as List? ?? [];
    final patterns = sleepAnalytics['patterns'] as List? ?? [];
    final stages = sleepAnalytics['stages'] as Map<String, dynamic>? ?? {};

    if (sleepAnalytics.isEmpty || records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bedtime_off, size: 48.sp, color: AppColor.textSecondary),
            SizedBox(height: 16.h),
            Text(
              'No sleep data available',
              style: TextStyle(
                fontSize: 16.sp,
                color: AppColor.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        // AI Sleep Analysis
        if (report['ai_sleep_analysis'] != null)
          _buildDetailSection(
            'Sleep Analysis',
            report['ai_sleep_analysis'],
            icon: Icons.nightlight_round,
            color: Colors.indigo,
          ),

        // Sleep Summary Card
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(12.w),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bedtime, color: Colors.indigo, size: 20.sp),
                  SizedBox(width: 8.w),
                  Text(
                    'Sleep Summary',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSleepStat(
                    'Average',
                    '${sleepAnalytics['avg_hours']?.toStringAsFixed(1) ?? 'N/A'} hrs',
                  ),
                  _buildSleepStat(
                    'Nights Tracked',
                    records.length.toString(),
                  ),
                  _buildSleepStat(
                    'Awakenings',
                    sleepAnalytics['avg_awakenings']?.toStringAsFixed(1) ?? 'N/A',
                  ),
                ],
              ),
            ],
          ),
        ),

        SizedBox(height: 16.h),

        // Sleep Stages Chart
        if (stages.isNotEmpty)
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.w),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sleep Stages',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColor.textPrimary,
                  ),
                ),
                SizedBox(height: 12.h),
                _buildSleepStageBar('Deep Sleep', stages['deep'] ?? 0, Colors.indigo.shade800),
                SizedBox(height: 8.h),
                _buildSleepStageBar('REM Sleep', stages['rem'] ?? 0, Colors.purple),
                SizedBox(height: 8.h),
                _buildSleepStageBar('Light Sleep', stages['light'] ?? 0, Colors.indigo.shade200),
              ],
            ),
          ),

        // Patterns
        if (patterns.isNotEmpty) ...[
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.w),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sleep Patterns',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColor.textPrimary,
                  ),
                ),
                SizedBox(height: 8.h),
                ...patterns.map((pattern) => Padding(
                      padding: EdgeInsets.only(bottom: 6.h),
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 6.sp, color: Colors.indigo),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              pattern.toString(),
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColor.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],

        // Sleep Duration Chart
        SizedBox(height: 16.h),
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.w),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sleep Duration',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColor.textPrimary,
                ),
              ),
              SizedBox(height: 12.h),
              SizedBox(
                height: 120.h,
                child: _buildSleepChart(records),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSleepStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: Colors.indigo.shade400,
          ),
        ),
      ],
    );
  }

  Widget _buildSleepStageBar(String label, double hours, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 80.w,
          child: Text(
            label,
            style: TextStyle(fontSize: 11.sp, color: AppColor.textSecondary),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4.w),
            child: LinearProgressIndicator(
              value: hours / 8, // Assuming max 8 hours
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 12.h,
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          '${hours.toStringAsFixed(1)}h',
          style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildSleepChart(List records) {
    if (records.isEmpty) return SizedBox.shrink();

    return BarChart(
      BarChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: records.asMap().entries.map((e) {
          final hours = (e.value['total_hours'] ?? 0).toDouble();
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: hours,
                color: hours >= 7 ? Colors.indigo : Colors.orange,
                width: 12.w,
                borderRadius: BorderRadius.vertical(top: Radius.circular(4.w)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLabsTab() {
    final biomarkerTrends = report['biomarker_trends'] as Map<String, dynamic>? ?? {};
    final biomarkers = biomarkerTrends['biomarkers'] as Map<String, dynamic>? ?? {};
    final abnormalities = biomarkerTrends['abnormalities'] as List? ?? [];
    final criticalAbnormalities = biomarkerTrends['critical_abnormalities'] as List? ?? [];
    final abnormalCount = biomarkerTrends['abnormal_count'] ?? 0;
    final criticalCount = biomarkerTrends['critical_count'] ?? 0;

    if (biomarkers.isEmpty && abnormalities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.science_outlined, size: 48.sp, color: AppColor.textSecondary),
            SizedBox(height: 16.h),
            Text(
              'No lab data available',
              style: TextStyle(
                fontSize: 16.sp,
                color: AppColor.textSecondary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Upload medical reports to see biomarker trends',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColor.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        // Critical Abnormalities Alert
        if (criticalCount > 0) ...[
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColor.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.w),
              border: Border.all(color: AppColor.danger.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning, color: AppColor.danger, size: 24.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'Critical Abnormalities ($criticalCount)',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColor.danger,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                ...criticalAbnormalities.map((abnormality) => Padding(
                      padding: EdgeInsets.only(bottom: 6.h),
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 8.sp, color: AppColor.danger),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${abnormality['name']}: ${abnormality['value']} ${abnormality['unit'] ?? ''}',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColor.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Ref: ${abnormality['reference_range']} (${abnormality['status']?.toUpperCase()})',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: AppColor.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          SizedBox(height: 16.h),
        ],

        // Other Abnormalities
        if (abnormalCount > criticalCount) ...[
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColor.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.w),
              border: Border.all(color: AppColor.warning.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColor.warning, size: 20.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'Abnormal Values (${abnormalCount - criticalCount})',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColor.warning,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                ...abnormalities
                    .where((a) => a['severity'] == 'mild')
                    .map((abnormality) => Padding(
                          padding: EdgeInsets.only(bottom: 4.h),
                          child: Text(
                            '${abnormality['name']}: ${abnormality['value']} ${abnormality['unit'] ?? ''} (${abnormality['status']})',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColor.textSecondary,
                            ),
                          ),
                        )),
              ],
            ),
          ),
          SizedBox(height: 16.h),
        ],

        // Biomarker Trends
        if (biomarkers.isNotEmpty) ...[
          Text(
            'Biomarker Trends',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: AppColor.textPrimary,
            ),
          ),
          SizedBox(height: 12.h),
          ...biomarkers.entries.map((entry) {
            final name = entry.key;
            final data = entry.value as Map<String, dynamic>;
            final values = data['values'] as List? ?? [];
            final unit = data['unit'] ?? '';
            final currentStatus = data['current_status'] ?? 'normal';
            final latestValue = data['latest_value'];
            final trendDirection = data['trend_direction'] ?? 'stable';
            final refMin = data['reference_min'];
            final refMax = data['reference_max'];

            Color statusColor;
            if (currentStatus == 'normal') {
              statusColor = AppColor.success;
            } else if (currentStatus == 'high' || currentStatus == 'low') {
              statusColor = AppColor.warning;
            } else {
              statusColor = AppColor.textSecondary;
            }

            IconData trendIcon;
            if (trendDirection == 'increasing') {
              trendIcon = Icons.trending_up;
            } else if (trendDirection == 'decreasing') {
              trendIcon = Icons.trending_down;
            } else {
              trendIcon = Icons.trending_flat;
            }

            return Container(
              margin: EdgeInsets.only(bottom: 12.h),
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.w),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColor.textPrimary,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(trendIcon, size: 16.sp, color: statusColor),
                          SizedBox(width: 4.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4.w),
                            ),
                            child: Text(
                              currentStatus.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Text(
                        'Latest: ',
                        style: TextStyle(fontSize: 12.sp, color: AppColor.textSecondary),
                      ),
                      Text(
                        '${latestValue ?? 'N/A'} $unit',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        'Ref: ${refMin ?? '?'} - ${refMax ?? '?'} $unit',
                        style: TextStyle(fontSize: 11.sp, color: AppColor.textMuted),
                      ),
                    ],
                  ),
                  if (values.length > 1) ...[
                    SizedBox(height: 8.h),
                    SizedBox(
                      height: 60.h,
                      child: _buildBiomarkerTrendChart(values, statusColor),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildBiomarkerTrendChart(List values, Color color) {
    if (values.isEmpty) return SizedBox.shrink();

    final spots = values.asMap().entries.map((e) {
      final val = e.value['value'];
      return FlSpot(e.key.toDouble(), (val ?? 0).toDouble());
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: color.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationsTab() {
    final medicationAnalytics = report['medication_analytics'] as Map<String, dynamic>? ?? {};
    final sideEffects = report['side_effects_reported'] as List? ?? [];

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        // AI Medication Insights
        if (report['ai_medication_insights'] != null)
          _buildDetailSection(
            'Medication Insights',
            report['ai_medication_insights'],
            icon: Icons.medication,
            color: Colors.teal,
          ),

        // Side Effect Correlations
        if (report['ai_side_effect_correlations'] != null)
          _buildDetailSection(
            'Side Effect Correlations',
            report['ai_side_effect_correlations'],
            icon: Icons.warning_amber,
            color: Colors.orange,
          ),

        // Per-medication breakdown
        if (medicationAnalytics.isNotEmpty) ...[
          Text(
            'Medication Performance',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: AppColor.textPrimary,
            ),
          ),
          SizedBox(height: 12.h),
          ...medicationAnalytics.entries.map((entry) {
            final med = entry.value as Map<String, dynamic>;
            final adherence = (med['adherence_pct'] ?? 0).toDouble();

            Color adherenceColor;
            if (adherence >= 85) {
              adherenceColor = AppColor.success;
            } else if (adherence >= 70) {
              adherenceColor = AppColor.warning;
            } else {
              adherenceColor = AppColor.danger;
            }

            return Container(
              margin: EdgeInsets.only(bottom: 12.h),
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.w),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${med['drug_name'] ?? 'Unknown'} ${med['strength'] ?? ''}',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColor.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: adherenceColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4.w),
                        ),
                        child: Text(
                          '${adherence.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: adherenceColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      _buildMedStat('Taken', med['taken'] ?? 0, AppColor.success),
                      SizedBox(width: 12.w),
                      _buildMedStat('Missed', med['missed'] ?? 0, AppColor.danger),
                      SizedBox(width: 12.w),
                      _buildMedStat('Late', med['late'] ?? 0, AppColor.warning),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],

        // Reported Side Effects
        if (sideEffects.isNotEmpty) ...[
          SizedBox(height: 16.h),
          Text(
            'Reported Side Effects',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: AppColor.textPrimary,
            ),
          ),
          SizedBox(height: 12.h),
          ...sideEffects.map((effect) => Container(
                margin: EdgeInsets.only(bottom: 8.h),
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: AppColor.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.w),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, size: 16.sp, color: AppColor.warning),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            effect['medication'] ?? 'Unknown medication',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            effect['note'] ?? '',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: AppColor.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      effect['date'] ?? '',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: AppColor.textMuted,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildMedStat(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 8.w,
          height: 8.w,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 4.w),
        Text(
          '$value $label',
          style: TextStyle(
            fontSize: 11.sp,
            color: AppColor.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailSection(String title, String? content,
      {IconData? icon, Color? color, bool isWarning = false}) {
    if (content == null || content.isEmpty) return SizedBox.shrink();

    final effectiveColor = color ?? (isWarning ? AppColor.danger : AppColor.primaryColor);

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isWarning ? AppColor.danger.withOpacity(0.1) : effectiveColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12.w),
        border: Border.all(
          color: isWarning ? AppColor.danger.withOpacity(0.3) : effectiveColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18.sp, color: effectiveColor),
                SizedBox(width: 8.w),
              ],
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: isWarning ? AppColor.danger : effectiveColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            content,
            style: TextStyle(
              fontSize: 13.sp,
              color: AppColor.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
