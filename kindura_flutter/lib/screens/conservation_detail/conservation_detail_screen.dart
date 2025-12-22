import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/res/colors/app_color.dart';
import 'package:intl/intl.dart';

import 'package:kindura_ai/screens/conservation_detail/conservation_detail_controller.dart';

class ConservationDetailScreen extends StatefulWidget {
  const ConservationDetailScreen({super.key});

  @override
  State<ConservationDetailScreen> createState() =>
      _ConservationDetailScreenState();
}

class _ConservationDetailScreenState extends State<ConservationDetailScreen> {
  final controller = Get.put(ConservationDetailController());

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColor.black),
          onPressed: () {
            Get.back();
          },
        ),
        title: Text(
          "Kindura AI",
          style: TextStyle(
            color: AppColor.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("AI Conversation Log",
                          style: TextStyle(
                              fontSize: 18.sp, fontWeight: FontWeight.w600)),
                      SizedBox(height: 8.h),
                      // Timestamp display
                      if (controller.result.uploadedAt != null)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                              SizedBox(width: 6.w),
                              Text(
                                _formatTimestamp(controller.result.uploadedAt!),
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: 20.h),
                      if (controller.result.conservation?.conversation?.messages != null &&
                          controller.result.conservation!.conversation!.messages.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: controller
                              .result.conservation!.conversation!.messages
                              .map((pair) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (pair.human != null)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      margin:
                                          const EdgeInsets.symmetric(vertical: 4),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: RichText(
                                        text: TextSpan(
                                          style: TextStyle(
                                            color: Colors.black87,
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w400,
                                            height: 1.4,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: "Human: ",
                                              style: TextStyle(fontWeight: FontWeight.w400),
                                            ),
                                            TextSpan(text: pair.human!),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                if (pair.ai != null)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      margin:
                                          const EdgeInsets.symmetric(vertical: 4),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: RichText(
                                        text: TextSpan(
                                          style: TextStyle(
                                            color: Colors.black87,
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w400,
                                            height: 1.4,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: "AI: ",
                                              style: TextStyle(fontWeight: FontWeight.w400),
                                            ),
                                            TextSpan(text: pair.ai!),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          }).toList(),
                        )
                      else
                        Center(
                          child: Text(
                            "No conversation messages available",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14.sp,
                            ),
                          ),
                        )
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 20.h),
          Container(
            height: 200.h,
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(bottom: 16.h, left: 16.w, right: 16.w),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Summary Of Conversation",
                          style: TextStyle(
                              fontSize: 18.sp, fontWeight: FontWeight.w600)),
                      SizedBox(height: 20.h),
                      Text(
                          controller.result.summarizePatientReport ??
                              "Kindly Refresh for Summary",
                          style: TextStyle(fontSize: 13.sp, color: Colors.black)),
                    ],
                  ),
                ),
              ),
            ),
          ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }
}
