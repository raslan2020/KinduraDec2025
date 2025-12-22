import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:kindura_ai/common_widgets/home_app_bar.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/common_widgets/loading_indicator.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/res/assets/image_constant.dart';
import 'package:kindura_ai/res/routes/routes_name.dart';
import 'package:kindura_ai/screens/scan/scan_controller.dart';
import 'package:kindura_ai/utils/utils.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late ScanController controller;

  @override
  void initState() {
    super.initState();
    // Initialize controller in initState to avoid calling Get.put during build
    controller = Get.put(ScanController());
  }

  /// Format timestamp to HH:MM:SS & DD/MM/YY
  String _formatTimestamp(String isoTimestamp) {
    try {
      final dateTime = DateTime.parse(isoTimestamp).toLocal();
      final timeFormat = DateFormat('HH:mm:ss');
      final dateFormat = DateFormat('dd/MM/yy');
      return '${timeFormat.format(dateTime)} • ${dateFormat.format(dateTime)}';
    } catch (e) {
      return '';
    }
  }

  Widget _shimmerCard(bool isDark) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade600 : Colors.grey.shade100,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(8.w),
        ),
        height: 100.h,
        width: double.infinity,
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtextColor = isDark ? Colors.grey.shade400 : Colors.grey;
    final borderColor = isDark ? Colors.grey.shade600 : Colors.grey.shade400;
    final documentCardBg = isDark ? const Color(0xFF2D3748) : const Color(0xFFF5F6FF);
    final iconBg = isDark ? Colors.blue.shade900 : Colors.blue.shade100;

    return Stack(
      children: [
        Scaffold(
          appBar: CustomAppBar(title: "Kindura AI"),
          body: Padding(
            padding: EdgeInsets.only(top: 16.h, left: 16.w, right: 16.w),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: isDark ? Border.all(color: Colors.grey.shade700) : null,
                  ),
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Medical Reports",
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                      Text(
                          "Upload your lab reports and medical documents for AI analysis",
                          style: TextStyle(fontSize: 16, color: subtextColor)),
                      SizedBox(height: 20.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await controller.uploadCoursePdf();
                              },
                              icon: Icon(Icons.upload_file_outlined, size: 28, color: textColor),
                              label: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 24),
                                child: Column(
                                  children: [
                                    Text('Upload File',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold, color: textColor)),
                                    SizedBox(height: 4),
                                    Text('Choose from gallery or files',
                                        style: TextStyle(
                                            fontSize: 12, color: subtextColor)),
                                  ],
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: borderColor,
                                  style: BorderStyle.solid,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                foregroundColor: textColor,
                                alignment: Alignment.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await controller.getCourseList();
                      return;
                    },
                    child: SingleChildScrollView(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: isDark ? Border.all(color: Colors.grey.shade700) : null,
                        ),
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text("Your Medical Documents",
                                    style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: textColor)),
                                Spacer(),
                                IconButton(
                                  icon:
                                      Icon(Icons.refresh, color: textColor),
                                  onPressed: () {
                                    controller.getCourseList();
                                  },
                                )
                              ],
                            ),
                            SizedBox(height: 20.h),
                            Obx(() {
                              if (controller.requestStatus.value ==
                                  Status.LOADING) {
                                // Shimmer placeholder list
                                return Column(
                                  children: List.generate(
                                      4, (index) => _shimmerCard(isDark)),
                                );
                              }

                              // Check for medical documents
                              if (controller.medicalDocuments.isEmpty) {
                                return Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.folder_open,
                                           size: 64,
                                           color: subtextColor),
                                      SizedBox(height: 16.h),
                                      Text(
                                        "No medical reports uploaded yet",
                                        style: TextStyle(
                                          color: subtextColor,
                                          fontSize: 16.sp,
                                        ),
                                      ),
                                      SizedBox(height: 8.h),
                                      Text(
                                        "Upload a PDF medical report to get started",
                                        style: TextStyle(
                                          color: subtextColor,
                                          fontSize: 14.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return Column(
                                children: [
                                  // Display medical documents if available
                                  if (controller.medicalDocuments.isNotEmpty) ...[
                                    for (var document in controller.medicalDocuments)
                                      InkWell(
                                        customBorder:
                                            Border.all(color: borderColor),
                                        onTap: () {
                                          // Show document actions dialog
                                          _showDocumentActions(context, document);
                                        },
                                        child: Container(
                                          margin:
                                              EdgeInsets.symmetric(vertical: 6),
                                          padding: EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: documentCardBg,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: borderColor),
                                          ),
                                          child: Row(
                                            children: [
                                              // Icon container on the left
                                              Container(
                                                padding: EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: iconBg,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Icon(
                                                  Icons.description,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                              SizedBox(width: 12),

                                              // Document details in the middle
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      document['file_name'] ?? document['title'] ?? 'Medical Report',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                        color: textColor,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    SizedBox(height: 4),
                                                    // Timestamp display
                                                    if (document['uploaded_at'] != null)
                                                      Row(
                                                        children: [
                                                          Icon(Icons.access_time,
                                                            size: 12,
                                                            color: subtextColor),
                                                          SizedBox(width: 4),
                                                          Text(
                                                            _formatTimestamp(document['uploaded_at']),
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: subtextColor,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    SizedBox(height: 2),
                                                    if (document['is_processed'] == true || document['is_parsed'] == true)
                                                      Row(
                                                        children: [
                                                          Icon(Icons.check_circle,
                                                            size: 12,
                                                            color: Colors.green),
                                                          SizedBox(width: 4),
                                                          Text(
                                                            "AI Analyzed",
                                                            style: TextStyle(
                                                              color: Colors.green,
                                                              fontSize: 11,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                  ],
                                                ),
                                              ),

                                              // Delete icon on the right
                                              IconButton(
                                                icon: Icon(Icons.delete,
                                                    color: Colors.redAccent),
                                                onPressed: () {
                                                  // Handle delete for medical document
                                                  if (document['id'] != null) {
                                                    controller.deleteMedicalDocument(document['id'].toString());
                                                  } else {
                                                    Util.Snack_Bar("Error", "Cannot delete document without ID");
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                  // No additional course display needed
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
        Obx(() {
          switch (controller.uploadStatus.value) {
            case Status.COMPLETED:
              return Container();
            case Status.LOADING:
              final totalCount = controller.pdfUploadController.totalCount.value;
              final uploadedCount = controller.pdfUploadController.uploadedCount.value;
              return Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: isDark ? Border.all(color: Colors.grey.shade600) : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LoadingIndicator(),
                        SizedBox(height: 16),
                        // Show progress if uploading multiple files
                        if (totalCount > 1) ...[
                          Text(
                            'Uploading files...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '$uploadedCount of $totalCount completed',
                            style: TextStyle(
                              fontSize: 14,
                              color: subtextColor,
                            ),
                          ),
                        ] else
                          Text(
                            'Uploading...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            case Status.ERROR:
              return Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Text(
                    "error",
                    style: TextStyle(color: Colors.amber),
                  ),
                ),
              );
          }
        }),
      ],
    );
  }

  void _showDocumentActions(BuildContext context, Map<String, dynamic> document) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    final fileName = document['file_name'] ?? document['title'] ?? 'Document';
    final fileUrl = document['file_url'] as String?;
    final documentId = document['id']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
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
              fileName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.visibility, color: Colors.blue),
              title: Text('View Document', style: TextStyle(color: textColor)),
              onTap: fileUrl != null && fileUrl.isNotEmpty
                  ? () {
                      Navigator.pop(context);
                      _openDocument(fileUrl);
                    }
                  : null,
              enabled: fileUrl != null && fileUrl.isNotEmpty,
            ),
            ListTile(
              leading: Icon(Icons.download, color: Colors.green),
              title: Text('Download', style: TextStyle(color: textColor)),
              onTap: fileUrl != null && fileUrl.isNotEmpty
                  ? () {
                      Navigator.pop(context);
                      _downloadDocument(fileUrl);
                    }
                  : null,
              enabled: fileUrl != null && fileUrl.isNotEmpty,
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete', style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, documentId, fileName);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDocument(String fileUrl) async {
    final uri = Uri.parse(fileUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Util.Snack_Bar('Error', 'Could not open the document');
      }
    } catch (e) {
      Util.Snack_Bar('Error', 'Failed to open document: $e');
    }
  }

  Future<void> _downloadDocument(String fileUrl) async {
    final uri = Uri.parse(fileUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        Util.Snack_Bar('Download', 'Opening document for download...');
      } else {
        Util.Snack_Bar('Error', 'Could not download the document');
      }
    } catch (e) {
      Util.Snack_Bar('Error', 'Failed to download document: $e');
    }
  }

  void _confirmDelete(BuildContext context, String documentId, String fileName) {
    final controller = Get.find<ScanController>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Document'),
        content: Text('Are you sure you want to delete "$fileName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              controller.deleteMedicalDocument(documentId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }
}
