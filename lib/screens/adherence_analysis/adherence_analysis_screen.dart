import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:kindura_ai/res/colors/app_color.dart';
import 'package:kindura_ai/models/medication/adherence_analysis_model.dart';
import 'adherence_analysis_controller.dart';

class AdherenceAnalysisScreen extends StatelessWidget {
  AdherenceAnalysisScreen({Key? key}) : super(key: key);

  final controller = Get.put(AdherenceAnalysisController());

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0F172A) : AppColor.surface;
    final textColor = isDark ? Colors.white : AppColor.textPrimary;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Medication Analysis',
          style: TextStyle(
            color: textColor,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Obx(() => controller.isLoadingAnalysis.value
              ? Padding(
                  padding: EdgeInsets.only(right: 16.w),
                  child: Center(
                    child: SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : IconButton(
                  icon: Icon(Icons.refresh, color: AppColor.primaryColor),
                  onPressed: () => controller.requestNewAnalysis(),
                  tooltip: 'Generate New AI Analysis',
                )),
        ],
      ),
      body: Column(
        children: [
          _buildPeriodSelector(context),
          _buildTabBar(context),
          Expanded(
            child: Obx(() {
              switch (controller.selectedTabIndex.value) {
                case 0:
                  return _buildOverviewTab(context);
                case 1:
                  return _buildHistoryTab(context);
                case 2:
                  return _buildAIInsightsTab(context);
                default:
                  return _buildOverviewTab(context);
              }
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedBg = isDark ? const Color(0xFF1E293B) : Colors.grey[100];
    final unselectedBorder = isDark ? Colors.grey[700] : Colors.grey[300];
    final unselectedText = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Obx(() => Row(
            children: controller.periods.map((period) {
              final isSelected = controller.selectedPeriod.value == period;
              return Expanded(
                child: GestureDetector(
                  onTap: () => controller.onPeriodChanged(period),
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 4.w),
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColor.primaryColor : unselectedBg,
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: isSelected ? AppColor.primaryColor : unselectedBorder!,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        period.capitalize!,
                        style: TextStyle(
                          color: isSelected ? Colors.white : unselectedText,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          )),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabBgColor = isDark ? const Color(0xFF1E293B) : Colors.grey[100];
    final selectedBg = isDark ? const Color(0xFF334155) : Colors.white;
    final unselectedText = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: tabBgColor,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Obx(() => Row(
            children: [
              _buildTab('Overview', 0, context, selectedBg, unselectedText, isDark),
              _buildTab('History', 1, context, selectedBg, unselectedText, isDark),
              _buildTab('AI Insights', 2, context, selectedBg, unselectedText, isDark),
            ],
          )),
    );
  }

  Widget _buildTab(String title, int index, BuildContext context, Color? selectedBg, Color? unselectedText, bool isDark) {
    final isSelected = controller.selectedTabIndex.value == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.setTabIndex(index),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(8.r),
            boxShadow: isSelected && !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? AppColor.primaryColor : unselectedText,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13.sp,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context) {
    return Obx(() {
      final response = controller.historyResponse.value;

      return response.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (error) => _buildErrorState(error, context),
        success: (data) => _buildOverviewContent(data, context),
      );
    });
  }

  Widget _buildOverviewContent(MedicationHistoryResponse data, BuildContext context) {
    final summary = data.summary;

    return RefreshIndicator(
      onRefresh: () async => controller.fetchAllData(),
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAdherenceCard(summary, context),
            SizedBox(height: 16.h),
            _buildDoseBreakdown(summary, context),
            SizedBox(height: 16.h),
            if (data.problematicMedications.isNotEmpty)
              _buildProblematicMedications(data.problematicMedications, context),
            if (data.byMedication.isNotEmpty) ...[
              SizedBox(height: 16.h),
              _buildMedicationBreakdown(data.byMedication, context),
            ],
            if (data.relatedSymptoms.isNotEmpty) ...[
              SizedBox(height: 16.h),
              _buildRelatedSymptoms(data.relatedSymptoms, context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdherenceCard(MedicationHistorySummary summary, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percentage = summary.overallAdherence;
    final color = controller.getAdherenceColor(percentage);
    final emoji = controller.getAdherenceEmoji(percentage);
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(isDark ? 0.2 : 0.1), color.withOpacity(isDark ? 0.1 : 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                emoji,
                style: TextStyle(fontSize: 40.sp),
              ),
              SizedBox(width: 16.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 36.sp,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    'Overall Adherence',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              summary.adherenceGrade,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoseBreakdown(MedicationHistorySummary summary, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.grey[700] : Colors.grey[200];
    final textColor = isDark ? Colors.white : AppColor.textPrimary;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: borderColor!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dose Breakdown',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(child: _buildDoseStat('Total', summary.totalEvents, Colors.blue, subtitleColor)),
              Expanded(child: _buildDoseStat('Taken', summary.taken, Colors.green, subtitleColor)),
              Expanded(child: _buildDoseStat('Late', summary.late, Colors.orange, subtitleColor)),
              Expanded(child: _buildDoseStat('Missed', summary.missed, Colors.red, subtitleColor)),
            ],
          ),
          if (summary.skipped > 0) ...[
            SizedBox(height: 12.h),
            _buildDoseStat('Skipped', summary.skipped, Colors.grey, subtitleColor),
          ],
        ],
      ),
    );
  }

  Widget _buildDoseStat(String label, int count, Color color, Color? subtitleColor) {
    return Column(
      children: [
        Container(
          width: 50.w,
          height: 50.w,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 18.sp,
              ),
            ),
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: subtitleColor,
          ),
        ),
      ],
    );
  }

  Widget _buildProblematicMedications(List<MedicationStats> medications, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.red[900]!.withOpacity(0.3) : Colors.red[50];
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red[600], size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'Needs Attention',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.red[300] : Colors.red[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ...medications.map((med) => Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        med.medicationName,
                        style: TextStyle(fontSize: 14.sp, color: textColor),
                      ),
                    ),
                    if (med.missed > 0)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          '${med.missed} missed',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                    SizedBox(width: 8.w),
                    if (med.late > 0)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          '${med.late} late',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.orange[700],
                          ),
                        ),
                      ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildMedicationBreakdown(List<MedicationStats> medications, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.grey[700] : Colors.grey[200];
    final textColor = isDark ? Colors.white : AppColor.textPrimary;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: borderColor!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'By Medication',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          SizedBox(height: 12.h),
          ...medications.map((med) => _buildMedicationRow(med, context)),
        ],
      ),
    );
  }

  Widget _buildMedicationRow(MedicationStats med, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = controller.getAdherenceColor(med.adherencePercentage);
    final rowBg = isDark ? const Color(0xFF334155) : Colors.grey[50];
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  med.medicationName,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  '${med.adherencePercentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.sp,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          LinearProgressIndicator(
            value: med.adherencePercentage / 100,
            backgroundColor: isDark ? Colors.grey[700] : Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              _buildSmallStat('Taken', med.taken, Colors.green, subtitleColor),
              SizedBox(width: 12.w),
              _buildSmallStat('Late', med.late, Colors.orange, subtitleColor),
              SizedBox(width: 12.w),
              _buildSmallStat('Missed', med.missed, Colors.red, subtitleColor),
              if (med.avgDelayMinutes > 0) ...[
                Spacer(),
                Text(
                  'Avg delay: ${controller.formatDuration(med.avgDelayMinutes.toInt())}',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: subtitleColor,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStat(String label, int count, Color color, Color? subtitleColor) {
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
          '$count $label',
          style: TextStyle(
            fontSize: 11.sp,
            color: subtitleColor,
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedSymptoms(List<RelatedSymptom> symptoms, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.purple[900]!.withOpacity(0.3) : Colors.purple[50];
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.purple[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety, color: Colors.purple[600], size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'Related Symptoms',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.purple[300] : Colors.purple[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ...symptoms.take(5).map((symptom) => Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6.w,
                      height: 6.w,
                      margin: EdgeInsets.only(top: 6.h),
                      decoration: BoxDecoration(
                        color: _getSeverityColor(symptom.severity),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            symptom.title,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                          Text(
                            DateFormat('MMM d, h:mm a').format(symptom.reportedDateTime),
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: _getSeverityColor(symptom.severity).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        symptom.severity,
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: _getSeverityColor(symptom.severity),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'severe':
        return Colors.red;
      case 'moderate':
        return Colors.orange;
      case 'mild':
        return Colors.yellow[700]!;
      default:
        return Colors.grey;
    }
  }

  Widget _buildHistoryTab(BuildContext context) {
    return Obx(() {
      final response = controller.historyResponse.value;

      return response.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (error) => _buildErrorState(error, context),
        success: (data) => _buildHistoryContent(data.events, context),
      );
    });
  }

  Widget _buildHistoryContent(List<DoseEventDetail> events, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64.sp, color: isDark ? Colors.grey[600] : Colors.grey[300]),
            SizedBox(height: 16.h),
            Text(
              'No medication history',
              style: TextStyle(
                fontSize: 16.sp,
                color: subtitleColor,
              ),
            ),
          ],
        ),
      );
    }

    // Group events by date
    final groupedEvents = <String, List<DoseEventDetail>>{};
    for (var event in events) {
      final dateKey = DateFormat('yyyy-MM-dd').format(event.scheduledDateTime);
      groupedEvents[dateKey] ??= [];
      groupedEvents[dateKey]!.add(event);
    }

    final sortedDates = groupedEvents.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: sortedDates.length,
      itemBuilder: (ctx, index) {
        final dateKey = sortedDates[index];
        final dayEvents = groupedEvents[dateKey]!;
        final date = DateTime.parse(dateKey);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Text(
                _formatDateHeader(date),
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: subtitleColor,
                ),
              ),
            ),
            ...dayEvents.map((event) => _buildEventCard(event, context)),
            SizedBox(height: 8.h),
          ],
        );
      },
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(date.year, date.month, date.day);

    if (eventDate == today) return 'Today';
    if (eventDate == today.subtract(Duration(days: 1))) return 'Yesterday';
    return DateFormat('EEEE, MMM d').format(date);
  }

  Widget _buildEventCard(DoseEventDetail event, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = controller.getStatusColor(event.status);
    final statusIcon = controller.getStatusIcon(event.status);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 20.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.medicationName,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                if (event.strength.isNotEmpty)
                  Text(
                    event.strength,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: subtitleColor,
                    ),
                  ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 12.sp, color: subtitleColor),
                    SizedBox(width: 4.w),
                    Text(
                      DateFormat('h:mm a').format(event.scheduledDateTime),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: subtitleColor,
                      ),
                    ),
                    if (event.takenAt != null) ...[
                      SizedBox(width: 8.w),
                      Icon(Icons.check, size: 12.sp, color: Colors.green),
                      SizedBox(width: 4.w),
                      Text(
                        DateFormat('h:mm a').format(event.takenDateTime!),
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  event.status.capitalize!,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (event.delayMinutes != null && event.delayMinutes! > 0) ...[
                SizedBox(height: 4.h),
                Text(
                  '+${controller.formatDuration(event.delayMinutes!)}',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: Colors.orange,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAIInsightsTab(BuildContext context) {
    return Obx(() {
      final response = controller.aiInsightResponse.value;

      return response.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (error) => _buildAIErrorState(error, context),
        success: (data) => _buildAIInsightsContent(data, context),
      );
    });
  }

  Widget _buildAIErrorState(String error, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.psychology, size: 64.sp, color: AppColor.primaryColor),
            SizedBox(height: 16.h),
            Text(
              'AI Analysis',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Generate a comprehensive analysis of your medication adherence, vitals, and lab results.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: subtitleColor,
              ),
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: () => controller.requestNewAnalysis(),
              icon: Icon(Icons.auto_awesome),
              label: Text('Generate Analysis'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColor.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIInsightsContent(AIAdherenceInsight data, BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAIHeader(data),
          SizedBox(height: 16.h),
          _buildOverallAssessment(data.overallAssessment, context),
          SizedBox(height: 16.h),
          ...data.sections.map((section) => _buildInsightSection(section, context)),
          if (data.warnings.isNotEmpty) ...[
            SizedBox(height: 16.h),
            _buildWarningsSection(data.warnings, context),
          ],
          if (data.recommendations.isNotEmpty) ...[
            SizedBox(height: 16.h),
            _buildRecommendationsSection(data.recommendations, context),
          ],
          if (data.parkinsonsSpecificNotes != null) ...[
            SizedBox(height: 16.h),
            _buildParkinsonsNotes(data.parkinsonsSpecificNotes!, context),
          ],
        ],
      ),
    );
  }

  Widget _buildAIHeader(AIAdherenceInsight data) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColor.primaryColor, AppColor.primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.psychology, color: Colors.white, size: 24.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Medical Analysis',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Generated ${DateFormat('MMM d, yyyy').format(DateTime.parse(data.analysisDate))}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                Icon(Icons.verified, color: Colors.white, size: 14.sp),
                SizedBox(width: 4.w),
                Text(
                  '${(data.confidenceScore * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallAssessment(String assessment, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.blue[900]!.withOpacity(0.3) : Colors.blue[50];
    final textColor = isDark ? Colors.white : Colors.grey[800];

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.summarize, color: Colors.blue[600], size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'Overall Assessment',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.blue[300] : Colors.blue[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            assessment,
            style: TextStyle(
              fontSize: 14.sp,
              color: textColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightSection(InsightSection section, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final severityColor = _getSeverityColorForSection(section.severity);
    final textColor = isDark ? Colors.white : Colors.grey[800];
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[700];

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: severityColor.withOpacity(isDark ? 0.15 : 0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: severityColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8.w,
                height: 8.w,
                decoration: BoxDecoration(
                  color: severityColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                section.title,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            section.content,
            style: TextStyle(
              fontSize: 13.sp,
              color: subtitleColor,
              height: 1.5,
            ),
          ),
          if (section.bulletPoints != null && section.bulletPoints!.isNotEmpty) ...[
            SizedBox(height: 8.h),
            ...section.bulletPoints!.map((point) => Padding(
                  padding: EdgeInsets.only(left: 8.w, bottom: 4.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: TextStyle(color: severityColor)),
                      Expanded(
                        child: Text(
                          point,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
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

  Color _getSeverityColorForSection(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
      default:
        return Colors.blue;
    }
  }

  Widget _buildWarningsSection(List<String> warnings, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.red[900]!.withOpacity(0.3) : Colors.red[50];
    final textColor = isDark ? Colors.white : Colors.grey[800];

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red[600], size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'Warnings',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.red[300] : Colors.red[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ...warnings.map((warning) => Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[400], size: 16.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        warning,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildRecommendationsSection(List<String> recommendations, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.green[900]!.withOpacity(0.3) : Colors.green[50];
    final textColor = isDark ? Colors.white : Colors.grey[800];

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.green[600], size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'Recommendations',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.green[300] : Colors.green[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ...recommendations.asMap().entries.map((entry) => Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20.w,
                      height: 20.w,
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${entry.key + 1}',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildParkinsonsNotes(String notes, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.grey[800];

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [Colors.purple[900]!.withOpacity(0.4), Colors.indigo[900]!.withOpacity(0.4)]
              : [Colors.purple[50]!, Colors.indigo[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.purple[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.medical_information, color: Colors.purple[600], size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                "Parkinson's Disease Considerations",
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.purple[300] : Colors.purple[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            notes,
            style: TextStyle(
              fontSize: 13.sp,
              color: textColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64.sp, color: Colors.red[300]),
          SizedBox(height: 16.h),
          Text(
            'Failed to load data',
            style: TextStyle(
              fontSize: 16.sp,
              color: subtitleColor,
            ),
          ),
          SizedBox(height: 8.h),
          TextButton(
            onPressed: () => controller.fetchAllData(),
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }
}
