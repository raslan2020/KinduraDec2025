import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../services/report_generation_service.dart';
import '../res/colors/app_color.dart';

/// A small inline progress banner shown at the top of the reports screen.
/// Non-blocking - user can navigate freely while report generates.
class ReportProgressBanner extends StatelessWidget {
  const ReportProgressBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ReportGenerationService>()) {
      return const SizedBox.shrink();
    }

    final service = Get.find<ReportGenerationService>();

    return Obx(() {
      // Only show when actively generating
      if (!service.isGenerating.value) {
        return const SizedBox.shrink();
      }

      return Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: AppColor.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10.w),
          border: Border.all(
            color: AppColor.primaryColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Spinning indicator
            SizedBox(
              width: 18.w,
              height: 18.w,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColor.primaryColor),
              ),
            ),
            SizedBox(width: 12.w),
            // Progress text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Generating ${_formatReportType(service.currentReportType.value)} Report...',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColor.primaryColor,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3.w),
                    child: LinearProgressIndicator(
                      value: service.progress.value / 100,
                      backgroundColor: AppColor.primaryColor.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation(AppColor.primaryColor),
                      minHeight: 4.h,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            // Progress percentage
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: AppColor.primaryColor,
                borderRadius: BorderRadius.circular(12.w),
              ),
              child: Text(
                '${service.progress.value}%',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  String _formatReportType(String type) {
    switch (type.toLowerCase()) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      default:
        return type;
    }
  }
}
