import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/common_widgets/home_app_bar.dart';
import 'package:kindura_ai/screens/medical_reports/medical_reports_controller.dart';
import 'package:kindura_ai/screens/medical_reports/widgets/vital_signs_card.dart';
import 'package:kindura_ai/screens/medical_reports/widgets/blood_test_card.dart';
import 'package:kindura_ai/screens/medical_reports/widgets/document_card.dart';
import 'package:kindura_ai/screens/medical_reports/widgets/quick_add_dialog.dart';
import 'package:kindura_ai/screens/medical_reports/widgets/vital_trend_chart.dart';
import 'package:kindura_ai/screens/medical_reports/widgets/health_analytics_dashboard.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/models/medical_reports/medical_report_models.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

class MedicalReportsScreen extends StatefulWidget {
  const MedicalReportsScreen({super.key});

  @override
  State<MedicalReportsScreen> createState() => _MedicalReportsScreenState();
}

class _MedicalReportsScreenState extends State<MedicalReportsScreen> with TickerProviderStateMixin {
  final controller = Get.put(MedicalReportsController());
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _shimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.w),
        ),
        height: 100.h,
        width: double.infinity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: "Medical Reports"),
      floatingActionButton: Obx(() => FloatingActionButton.extended(
        onPressed: controller.uploadStatus.value == Status.LOADING
            ? null
            : _showQuickAddOptions,
        icon: controller.uploadStatus.value == Status.LOADING
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.add),
        label: Text("Add Data"),
        backgroundColor: Colors.blue,
      )),
      body: RefreshIndicator(
        onRefresh: () => controller.loadMedicalReports(),
        child: Column(
          children: [
            // Header with filters
            Container(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "Health Data",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      Obx(() => PopupMenuButton<String>(
                        initialValue: controller.dateFilter.value,
                        onSelected: (String value) {
                          controller.setDateFilter(value);
                        },
                        itemBuilder: (BuildContext context) => [
                          PopupMenuItem(value: 'all', child: Text('All Time')),
                          PopupMenuItem(value: 'week', child: Text('Last Week')),
                          PopupMenuItem(value: 'month', child: Text('Last Month')),
                          PopupMenuItem(value: 'year', child: Text('Last Year')),
                        ],
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.filter_list, size: 16),
                              SizedBox(width: 4),
                              Text(
                                controller.dateFilter.value == 'all' 
                                    ? 'All Time'
                                    : 'Last ${controller.dateFilter.value}',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      )),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Track your vital signs and medical reports",
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            
            // Tab Bar
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(25),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey.shade600,
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(text: "Analytics"),
                  Tab(text: "Vital Signs"),
                  Tab(text: "Trends"),
                  Tab(text: "Blood Tests"),
                  Tab(text: "Documents"),
                ],
              ),
            ),
            
            SizedBox(height: 16),
            
            // Tab Bar View
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAnalyticsTab(),
                  _buildVitalSignsTab(),
                  _buildTrendsTab(),
                  _buildBloodTestsTab(),
                  _buildDocumentsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return Obx(() {
      if (controller.requestStatus.value == Status.LOADING) {
        return Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: List.generate(3, (index) => _shimmerCard()),
          ),
        );
      }

      return SingleChildScrollView(
        child: HealthAnalyticsDashboard(
          vitalSigns: controller.filteredVitalSigns,
          bloodTests: controller.filteredBloodTests,
        ),
      );
    });
  }

  Widget _buildTrendsTab() {
    return Obx(() {
      if (controller.requestStatus.value == Status.LOADING) {
        return Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: List.generate(3, (index) => _shimmerCard()),
          ),
        );
      }

      final vitalSigns = controller.filteredVitalSigns;
      if (vitalSigns.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.trending_up, size: 80, color: Colors.grey.shade400),
              SizedBox(height: 16),
              Text(
                "No trend data available",
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
              SizedBox(height: 8),
              Text(
                "Add vital signs to see trends",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ],
          ),
        );
      }

      // Group vital signs by type
      final vitalTypes = vitalSigns.map((vs) => vs.type).toSet().toList();
      
      return SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            for (String type in vitalTypes) ...[
              VitalTrendChart(
                vitalSigns: vitalSigns,
                type: type,
                primaryColor: _getColorForVitalType(type),
              ),
              SizedBox(height: 16),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildVitalSignsTab() {
    return Obx(() {
      if (controller.requestStatus.value == Status.LOADING) {
        return Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: List.generate(3, (index) => _shimmerCard()),
          ),
        );
      }

      if (controller.filteredVitalSigns.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_outline, size: 80, color: Colors.grey.shade400),
              SizedBox(height: 16),
              Text(
                "No vital signs recorded",
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
              SizedBox(height: 8),
              Text(
                "Add your first vital signs measurement",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: controller.filteredVitalSigns.length,
        itemBuilder: (context, index) {
          final vitalSign = controller.filteredVitalSigns[index];
          return VitalSignsCard(vitalSigns: vitalSign);
        },
      );
    });
  }

  Widget _buildBloodTestsTab() {
    return Obx(() {
      if (controller.requestStatus.value == Status.LOADING) {
        return Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: List.generate(3, (index) => _shimmerCard()),
          ),
        );
      }

      if (controller.filteredBloodTests.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.biotech_outlined, size: 80, color: Colors.grey.shade400),
              SizedBox(height: 16),
              Text(
                "No blood tests recorded",
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
              SizedBox(height: 8),
              Text(
                "Upload your lab reports or add results manually",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: controller.filteredBloodTests.length,
        itemBuilder: (context, index) {
          final bloodTest = controller.filteredBloodTests[index];
          return BloodTestCard(bloodTest: bloodTest);
        },
      );
    });
  }

  Widget _buildDocumentsTab() {
    return Obx(() {
      if (controller.requestStatus.value == Status.LOADING) {
        return Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: List.generate(3, (index) => _shimmerCard()),
          ),
        );
      }

      // Check if both old and new systems are empty
      if (controller.uploadedReports.isEmpty && controller.medicalDocuments.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.description_outlined, size: 80, color: Colors.grey.shade400),
              SizedBox(height: 16),
              Text(
                "No documents uploaded",
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
              SizedBox(height: 8),
              Text(
                "Upload your medical reports and lab results",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          await controller.loadUploadedReports();
          await controller.loadMedicalReports();
        },
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // NEW AI-POWERED UPLOADED REPORTS SECTION
            if (controller.uploadedReports.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.biotech, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    "AI-Processed Reports",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  Text(
                    "${controller.uploadedReports.length} reports",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              ...controller.uploadedReports.map((report) => _buildUploadedReportCard(report)),
              SizedBox(height: 24),
            ],

            // OLD SYSTEM DOCUMENTS (if any)
            if (controller.medicalDocuments.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.folder, color: Colors.grey.shade600),
                  SizedBox(width: 8),
                  Text(
                    "Legacy Documents",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              ...controller.medicalDocuments.map((document) => DocumentCard(document: document)),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildUploadedReportCard(UploadedMedicalReport report) {
    final fileName = report.fileName;
    final uploadDate = report.uploadedAt;
    final isProcessed = report.isProcessed;
    final biomarkersCount = report.biomarkers?.length ?? 0;
    final recommendationsCount = report.recommendations?.length ?? 0;
    final hasFileUrl = report.fileUrl != null && report.fileUrl!.isNotEmpty;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isProcessed ? Colors.green : Colors.orange, width: 2),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isProcessed ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isProcessed ? Icons.check_circle : Icons.pending,
                    color: isProcessed ? Colors.green : Colors.orange,
                    size: 30,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Uploaded: ${uploadDate.split('T')[0]}",
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isProcessed) ...[
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.science, size: 14, color: Colors.blue),
                  SizedBox(width: 4),
                  Text("$biomarkersCount biomarkers", style: TextStyle(fontSize: 12)),
                  SizedBox(width: 12),
                  Icon(Icons.medication, size: 14, color: Colors.green),
                  SizedBox(width: 4),
                  Text("$recommendationsCount recommendations", style: TextStyle(fontSize: 12)),
                ],
              ),
            ] else ...[
              SizedBox(height: 8),
              Text(
                "Processing...",
                style: TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic),
              ),
            ],
            SizedBox(height: 12),
            Row(
              children: [
                // View/Download button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasFileUrl ? () => _viewReport(report.fileUrl!) : null,
                    icon: Icon(Icons.visibility, size: 18),
                    label: Text("View"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: BorderSide(color: hasFileUrl ? Colors.blue : Colors.grey.shade300),
                      padding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                // Download button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasFileUrl ? () => _downloadReport(report.fileUrl!) : null,
                    icon: Icon(Icons.download, size: 18),
                    label: Text("Download"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: BorderSide(color: hasFileUrl ? Colors.green : Colors.grey.shade300),
                      padding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                // Delete button
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDeleteReport(report.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _viewReport(String fileUrl) async {
    final uri = Uri.parse(fileUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Get.snackbar(
          'Error',
          'Could not open the report',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to open report: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  Future<void> _downloadReport(String fileUrl) async {
    final uri = Uri.parse(fileUrl);
    try {
      // Open in browser which will trigger download
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        Get.snackbar(
          'Download Started',
          'The file will open in your browser for download',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
        );
      } else {
        Get.snackbar(
          'Error',
          'Could not download the report',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to download report: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  void _confirmDeleteReport(String reportId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Report"),
        content: Text("Are you sure you want to delete this medical report? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              controller.deleteUploadedReport(reportId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _showQuickAddOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Add Health Data",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            
            // Quick add buttons
            Row(
              children: [
                Expanded(
                  child: _quickAddButton(
                    icon: Icons.favorite,
                    label: "Blood Pressure",
                    color: Colors.red,
                    onTap: () {
                      Navigator.pop(context);
                      _showBloodPressureDialog();
                    },
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _quickAddButton(
                    icon: Icons.monitor_heart,
                    label: "Heart Rate",
                    color: Colors.pink,
                    onTap: () {
                      Navigator.pop(context);
                      _showHeartRateDialog();
                    },
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _quickAddButton(
                    icon: Icons.scale,
                    label: "Weight",
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      _showWeightDialog();
                    },
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _quickAddButton(
                    icon: Icons.bloodtype,
                    label: "Blood Sugar",
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      _showBloodSugarDialog();
                    },
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 20),
            
            // Upload document button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  controller.uploadMedicalDocument();
                },
                icon: Icon(Icons.upload_file),
                label: Text("Upload Medical Document"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            
            SizedBox(bottom: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }

  Widget _quickAddButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBloodPressureDialog() {
    showDialog(
      context: context,
      builder: (context) => QuickAddDialog.bloodPressure(
        onSubmit: (systolic, diastolic) {
          controller.quickAddBloodPressure(systolic, diastolic);
        },
      ),
    );
  }

  void _showHeartRateDialog() {
    showDialog(
      context: context,
      builder: (context) => QuickAddDialog.heartRate(
        onSubmit: (heartRate) {
          controller.quickAddHeartRate(heartRate);
        },
      ),
    );
  }

  void _showWeightDialog() {
    showDialog(
      context: context,
      builder: (context) => QuickAddDialog.weight(
        onSubmit: (weight) {
          controller.quickAddWeight(weight);
        },
      ),
    );
  }

  void _showBloodSugarDialog() {
    showDialog(
      context: context,
      builder: (context) => QuickAddDialog.bloodSugar(
        onSubmit: (bloodSugar) {
          controller.quickAddBloodSugar(bloodSugar);
        },
      ),
    );
  }

  Color _getColorForVitalType(String type) {
    switch (type) {
      case 'blood_pressure':
        return Colors.red;
      case 'heart_rate':
        return Colors.pink;
      case 'weight':
        return Colors.green;
      case 'blood_sugar':
        return Colors.orange;
      case 'temperature':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}