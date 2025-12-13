import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/common_widgets/home_app_bar.dart';
import 'package:kindura_ai/screens/medication/medication_controller.dart';
import 'package:kindura_ai/screens/medication/add_medication_screen.dart';
import 'package:kindura_ai/models/medication/medication_models.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/res/routes/routes_name.dart';
import 'package:shimmer/shimmer.dart';

class MedsVitaminScreen extends StatefulWidget {
  const MedsVitaminScreen({super.key});

  @override
  State<MedsVitaminScreen> createState() => _MedsVitaminScreenState();
}

class _MedsVitaminScreenState extends State<MedsVitaminScreen> {
  final MedicationController controller = Get.put(MedicationController());

  Widget _shimmerCard({bool? isDarkMode}) {
    final isDark = isDarkMode ?? (Theme.of(context).brightness == Brightness.dark);
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12.w),
        ),
        height: 120.h,
        width: double.infinity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: "Medications & Vitamins",
        actions: [
          IconButton(
            onPressed: () => Get.to(() => AddMedicationScreen()),
            icon: Icon(Icons.add),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'refresh':
                  controller.loadMedications();
                  break;
                case 'analytics':
                  _showAnalytics();
                  break;
                case 'voice_test':
                  controller.processVoiceCommand("I took my morning medication");
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'refresh', child: Text('Refresh')),
              PopupMenuItem(value: 'analytics', child: Text('View Analytics')),
              PopupMenuItem(value: 'voice_test', child: Text('Test Voice Command')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.to(() => AddMedicationScreen()),
        icon: Icon(Icons.medical_services),
        label: Text("Add Medication"),
        backgroundColor: Colors.blue,
      ),
      body: RefreshIndicator(
        onRefresh: controller.loadMedications,
        child: Obx(() {
          if (controller.requestStatus.value == Status.LOADING) {
            return _buildLoadingState();
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(),
                SizedBox(height: 20.h),
                _buildUpcomingReminders(),
                SizedBox(height: 20.h),
                _buildMedicationsList(),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: List.generate(5, (index) => _shimmerCard()),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _showAnalytics,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
              ? [Colors.blue.shade900, Colors.blue.shade800]
              : [Colors.blue.shade50, Colors.blue.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.w),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Medications",
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.blue.shade800,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Obx(() => Text(
                        "${controller.medications.length} medications scheduled",
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: isDark ? Colors.blue.shade200 : Colors.blue.shade600,
                        ),
                      )),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.blue.shade700 : Colors.blue.shade200,
                    borderRadius: BorderRadius.circular(12.w),
                  ),
                  child: Icon(
                    Icons.medication,
                    color: isDark ? Colors.white : Colors.blue.shade800,
                    size: 24.w,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isDark ? Colors.blue.shade800.withOpacity(0.5) : Colors.blue.shade200.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8.w),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined, size: 16.w, color: isDark ? Colors.white : Colors.blue.shade800),
                  SizedBox(width: 8.w),
                  Text(
                    "View Adherence Analysis & AI Insights",
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.blue.shade800,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Icon(Icons.arrow_forward_ios, size: 12.w, color: isDark ? Colors.white : Colors.blue.shade800),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingReminders() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Upcoming Reminders",
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        SizedBox(height: 12.h),
        Obx(() {
          if (controller.upcomingReminders.isEmpty) {
            return Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12.w),
                border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.schedule, size: 48.w, color: subtextColor),
                    SizedBox(height: 8.h),
                    Text(
                      "No upcoming reminders",
                      style: TextStyle(
                        color: subtextColor,
                        fontSize: 16.sp,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: controller.upcomingReminders.take(3).map((reminder) {
              return Container(
                margin: EdgeInsets.only(bottom: 8.h),
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: isDark ? Colors.orange.shade900.withOpacity(0.3) : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12.w),
                  border: Border.all(color: isDark ? Colors.orange.shade700 : Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.orange.shade800 : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8.w),
                      ),
                      child: Icon(Icons.access_time, color: isDark ? Colors.orange.shade300 : Colors.orange.shade700, size: 20.w),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Medication ${reminder.medicationId}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.sp,
                              color: textColor,
                            ),
                          ),
                          Text(
                            "Due at ${reminder.scheduledTime.hour}:${reminder.scheduledTime.minute.toString().padLeft(2, '0')}",
                            style: TextStyle(
                              color: isDark ? Colors.orange.shade300 : Colors.orange.shade700,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => controller.recordDoseTaken(
                        medicationId: reminder.medicationId,
                        scheduledAt: reminder.scheduledTime,
                      ),
                      icon: Icon(Icons.check_circle_outline, color: Colors.green),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  Widget _buildMedicationsList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "My Medications",
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            TextButton.icon(
              onPressed: () => Get.to(() => AddMedicationScreen()),
              icon: Icon(Icons.add, size: 16.w),
              label: Text("Add New"),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Obx(() {
          // Observe both medications and recentDoseEvents for reactive updates
          final _ = controller.recentDoseEvents.length; // Force observation

          if (controller.medications.isEmpty) {
            return Container(
              padding: EdgeInsets.all(40.w),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12.w),
                border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.medication_liquid, size: 64.w, color: subtextColor),
                    SizedBox(height: 16.h),
                    Text(
                      "No medications added yet",
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w500,
                        color: subtextColor,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      "Tap the + button to add your first medication",
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          // Sort medications by next due time
          final sortedMeds = List<Medication>.from(controller.medications);
          sortedMeds.sort((a, b) => _getNextDoseMinutes(a).compareTo(_getNextDoseMinutes(b)));

          return Column(
            children: sortedMeds.map((medication) {
              return _buildMedicationCard(medication);
            }).toList(),
          );
        }),
      ],
    );
  }

  Widget _buildMedicationCard(Medication medication) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade200;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12.w),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medication.drugName,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    if (medication.brandName?.isNotEmpty == true)
                      Text(
                        medication.brandName!,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: subtextColor,
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _showEditMedicationDialog(medication);
                      break;
                    case 'delete':
                      _confirmDeleteMedication(medication);
                      break;
                    case 'mark_taken':
                      _showTakenTimeDialog(medication);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'mark_taken', child: Text('Mark as Taken')),
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              _buildInfoChip("${medication.strength} ${medication.strengthUnit}", Icons.medical_services),
              SizedBox(width: 8.w),
              _buildInfoChip(medication.form, Icons.medication),
            ],
          ),
          SizedBox(height: 8.h),
          // Show scheduled times
          if (medication.schedule.times.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.schedule, size: 14.w, color: subtextColor),
                SizedBox(width: 4.w),
                Expanded(
                  child: Text(
                    "Due: ${_formatScheduleTimes(medication.schedule.times)}",
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: subtextColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            // Show next dose time or taken status
            _buildDoseStatusText(medication),
          ] else
            Text(
              "No schedule set",
              style: TextStyle(
                fontSize: 12.sp,
                color: subtextColor,
              ),
            ),
          if (medication.instructionsText.isNotEmpty) ...[
            SizedBox(height: 4.h),
            Text(
              "Instructions: ${medication.instructionsText}",
              style: TextStyle(
                fontSize: 12.sp,
                color: subtextColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: isDark ? Colors.blue.shade900.withOpacity(0.4) : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8.w),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.w, color: isDark ? Colors.blue.shade300 : Colors.blue.shade700),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoseStatusText(Medication medication) {
    // Get all dose events for this medication today
    final todayEvents = _getTodayDoseEvents(medication.id);
    final scheduledTimes = medication.schedule.times;
    final now = DateTime.now();

    // Build a map of scheduled time -> dose event status
    Map<String, DoseEvent?> timeToEvent = {};
    for (String time in scheduledTimes) {
      timeToEvent[time] = null;
    }

    // Match events to scheduled times
    for (final event in todayEvents) {
      final eventHour = event.scheduledAt.hour;
      final eventMinute = event.scheduledAt.minute;

      // Find matching scheduled time (within 30 min tolerance)
      for (String scheduledTime in scheduledTimes) {
        try {
          final parts = scheduledTime.split(':');
          final schedHour = int.parse(parts[0]);
          final schedMinute = int.parse(parts[1]);
          if ((eventHour == schedHour && (eventMinute - schedMinute).abs() <= 30) ||
              (eventHour - schedHour).abs() <= 1 && eventMinute == schedMinute) {
            timeToEvent[scheduledTime] = event;
            break;
          }
        } catch (e) {
          continue;
        }
      }
    }

    // Find the most recent taken dose and next pending dose
    DoseEvent? lastTakenEvent;
    String? nextPendingTime;
    bool hasOverdueDose = false;

    for (String time in scheduledTimes) {
      try {
        final parts = time.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final doseTime = DateTime(now.year, now.month, now.day, hour, minute);
        final event = timeToEvent[time];

        if (event != null && (event.status == DoseStatus.taken || event.status == DoseStatus.late)) {
          lastTakenEvent = event;
        } else if (event == null || event.status == DoseStatus.scheduled) {
          // No event for this time slot - check if pending or overdue
          if (doseTime.isBefore(now)) {
            hasOverdueDose = true;
          } else if (nextPendingTime == null) {
            nextPendingTime = time;
          }
        }
      } catch (e) {
        continue;
      }
    }

    // Build display based on status
    List<Widget> statusWidgets = [];

    if (lastTakenEvent != null) {
      final takenTime = lastTakenEvent.takenAt != null
          ? _formatTime(lastTakenEvent.takenAt!)
          : _formatTime(lastTakenEvent.scheduledAt);
      statusWidgets.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14.w, color: Colors.green),
            SizedBox(width: 4.w),
            Text(
              "Taken at $takenTime",
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Check for missed events
    final missedEvents = todayEvents.where((e) => e.status == DoseStatus.missed).toList();
    if (missedEvents.isNotEmpty) {
      statusWidgets.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel, size: 14.w, color: Colors.red),
            SizedBox(width: 4.w),
            Text(
              "${missedEvents.length} missed",
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Show next dose or overdue status
    if (hasOverdueDose && lastTakenEvent == null) {
      statusWidgets.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning, size: 14.w, color: Colors.red),
            SizedBox(width: 4.w),
            Text(
              _getNextDoseText(medication),
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else if (nextPendingTime != null) {
      final nextDoseText = _getTimeDisplayText(nextPendingTime, now);
      statusWidgets.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 14.w, color: Colors.blue),
            SizedBox(width: 4.w),
            Text(
              "Next: $nextDoseText",
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else if (lastTakenEvent != null && scheduledTimes.length == todayEvents.where((e) =>
        e.status == DoseStatus.taken || e.status == DoseStatus.late).length) {
      // All doses taken for today
      statusWidgets.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done_all, size: 14.w, color: Colors.green),
            SizedBox(width: 4.w),
            Text(
              "All doses taken today",
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // If no status to show, show next dose text
    if (statusWidgets.isEmpty) {
      return Text(
        _getNextDoseText(medication),
        style: TextStyle(
          fontSize: 11.sp,
          color: _isOverdue(medication) ? Colors.red : Colors.green.shade700,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    // Return combined status
    if (statusWidgets.length == 1) {
      return statusWidgets.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: statusWidgets.map((w) => Padding(
        padding: EdgeInsets.only(bottom: 2.h),
        child: w,
      )).toList(),
    );
  }

  String _getTimeDisplayText(String time24h, DateTime now) {
    try {
      final parts = time24h.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final doseTime = DateTime(now.year, now.month, now.day, hour, minute);
      final diff = doseTime.difference(now);

      if (diff.inMinutes < 60 && diff.inMinutes > 0) {
        return "in ${diff.inMinutes} min";
      } else {
        return _formatTime(doseTime);
      }
    } catch (e) {
      return time24h;
    }
  }

  List<DoseEvent> _getTodayDoseEvents(String medicationId) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(Duration(days: 1));

    return controller.recentDoseEvents.where((event) =>
      event.medicationId == medicationId &&
      event.scheduledAt.isAfter(todayStart) &&
      event.scheduledAt.isBefore(todayEnd)
    ).toList();
  }

  String _formatScheduleTimes(List<String> times) {
    if (times.isEmpty) return "No times set";

    return times.map((time) {
      // Convert 24h format to 12h format
      try {
        final parts = time.split(':');
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        String period = hour >= 12 ? 'PM' : 'AM';
        if (hour > 12) hour -= 12;
        if (hour == 0) hour = 12;
        return minute == 0 ? '$hour $period' : '$hour:${minute.toString().padLeft(2, '0')} $period';
      } catch (e) {
        return time;
      }
    }).join(', ');
  }

  String _getNextDoseText(Medication medication) {
    final now = DateTime.now();
    final times = medication.schedule.times;

    if (times.isEmpty) return "No schedule";

    // Find the next dose time
    DateTime? nextDose;
    DateTime? lastDose;

    for (String time in times) {
      try {
        final parts = time.split(':');
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        final doseTime = DateTime(now.year, now.month, now.day, hour, minute);

        if (doseTime.isAfter(now)) {
          if (nextDose == null || doseTime.isBefore(nextDose)) {
            nextDose = doseTime;
          }
        } else {
          if (lastDose == null || doseTime.isAfter(lastDose)) {
            lastDose = doseTime;
          }
        }
      } catch (e) {
        continue;
      }
    }

    if (nextDose != null) {
      final diff = nextDose.difference(now);
      if (diff.inMinutes < 60) {
        return "Next dose in ${diff.inMinutes} min";
      } else {
        return "Next dose at ${_formatTime(nextDose)}";
      }
    } else if (lastDose != null) {
      final diff = now.difference(lastDose);
      if (diff.inMinutes < 60) {
        return "Due ${diff.inMinutes} min ago";
      } else {
        return "Last dose was at ${_formatTime(lastDose)}";
      }
    }

    return "Check schedule";
  }

  String _formatTime(DateTime time) {
    int hour = time.hour;
    String period = hour >= 12 ? 'PM' : 'AM';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    return time.minute == 0
        ? '$hour $period'
        : '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }

  int _getNextDoseMinutes(Medication medication) {
    final now = DateTime.now();
    final times = medication.schedule.times;

    if (times.isEmpty) return 9999; // No schedule, put at end

    int minMinutes = 9999;

    for (String time in times) {
      try {
        final parts = time.split(':');
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        final doseTime = DateTime(now.year, now.month, now.day, hour, minute);

        int diffMinutes;
        if (doseTime.isAfter(now)) {
          diffMinutes = doseTime.difference(now).inMinutes;
        } else {
          // Past doses - use negative to sort overdue items first
          diffMinutes = -now.difference(doseTime).inMinutes;
        }

        if (diffMinutes.abs() < minMinutes.abs() ||
            (diffMinutes < 0 && minMinutes > 0)) { // Overdue takes priority
          minMinutes = diffMinutes;
        }
      } catch (e) {
        continue;
      }
    }

    return minMinutes;
  }

  bool _isOverdue(Medication medication) {
    final now = DateTime.now();
    final times = medication.schedule.times;

    for (String time in times) {
      try {
        final parts = time.split(':');
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        final doseTime = DateTime(now.year, now.month, now.day, hour, minute);

        // If any dose time has passed but there might not be a future one
        if (doseTime.isBefore(now)) {
          // Check if there's a future dose
          bool hasFutureDose = times.any((t) {
            try {
              final p = t.split(':');
              final dt = DateTime(now.year, now.month, now.day, int.parse(p[0]), int.parse(p[1]));
              return dt.isAfter(now);
            } catch (e) {
              return false;
            }
          });
          if (!hasFutureDose) return true;
        }
      } catch (e) {
        continue;
      }
    }
    return false;
  }

  void _showTakenTimeDialog(Medication medication) {
    // Get ALL scheduled times for today
    final now = DateTime.now();
    List<DateTime> allDoseTimes = [];

    if (medication.schedule.times.isNotEmpty) {
      for (String time in medication.schedule.times) {
        try {
          final parts = time.split(':');
          int hour = int.parse(parts[0]);
          int minute = int.parse(parts[1]);
          final doseTime = DateTime(now.year, now.month, now.day, hour, minute);
          allDoseTimes.add(doseTime);
        } catch (e) {
          continue;
        }
      }
    }

    // Sort by time
    allDoseTimes.sort((a, b) => a.compareTo(b));

    // If no scheduled times, use current time
    if (allDoseTimes.isEmpty) {
      allDoseTimes.add(now);
    }

    // Check which doses are already taken today
    Set<String> takenDoseTimes = {};
    for (var event in controller.recentDoseEvents) {
      if (event.medicationId == medication.id &&
          event.scheduledAt.year == now.year &&
          event.scheduledAt.month == now.month &&
          event.scheduledAt.day == now.day &&
          (event.status == DoseStatus.taken || event.status == DoseStatus.late)) {
        takenDoseTimes.add('${event.scheduledAt.hour}:${event.scheduledAt.minute}');
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mark ${medication.displayName} as Taken'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select which dose to mark:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 12),
              // Show ALL doses for today
              ...allDoseTimes.asMap().entries.map((entry) {
                final index = entry.key;
                final doseTime = entry.value;
                final doseKey = '${doseTime.hour}:${doseTime.minute}';
                final isTaken = takenDoseTimes.contains(doseKey);
                final isPast = doseTime.isBefore(now);
                final isUpcoming = !isPast;

                String doseLabel = 'Dose ${index + 1}';
                if (allDoseTimes.length == 1) {
                  doseLabel = 'Today\'s dose';
                } else if (index == 0) {
                  doseLabel = 'Morning dose';
                } else if (index == allDoseTimes.length - 1) {
                  doseLabel = 'Evening dose';
                } else {
                  doseLabel = 'Dose ${index + 1}';
                }

                return Container(
                  margin: EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isTaken
                        ? Colors.green.shade50
                        : (isPast ? Colors.orange.shade50 : Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isTaken
                          ? Colors.green.shade300
                          : (isPast ? Colors.orange.shade300 : Colors.grey.shade300),
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      isTaken ? Icons.check_circle : (isPast ? Icons.pending_actions : Icons.schedule),
                      color: isTaken ? Colors.green : (isPast ? Colors.orange : Colors.grey),
                    ),
                    title: Text(
                      '$doseLabel - ${_formatTime(doseTime)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isTaken ? Colors.green.shade700 : Colors.black87,
                        decoration: isTaken ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: Text(
                      isTaken ? 'Already taken' : (isPast ? 'Pending (past due)' : 'Upcoming'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isTaken ? Colors.green.shade600 : (isPast ? Colors.orange.shade700 : Colors.grey.shade600),
                      ),
                    ),
                    trailing: isTaken
                        ? null
                        : Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: isTaken ? null : () {
                      Navigator.pop(context);
                      _showTakenTimeOptionsDialog(medication, doseTime, index + 1, allDoseTimes.length);
                    },
                  ),
                );
              }).toList(),
              SizedBox(height: 8),
              Divider(),
              // Option to mark a custom time
              ListTile(
                leading: Icon(Icons.add_circle_outline, color: Colors.blue),
                title: Text('Mark custom dose...'),
                subtitle: Text('Choose a specific date and time'),
                onTap: () {
                  Navigator.pop(context);
                  _showCustomDoseDialog(medication);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showTakenTimeOptionsDialog(Medication medication, DateTime scheduledTime, int doseNumber, int totalDoses) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Dose $doseNumber of $totalDoses'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: Colors.blue.shade700, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Scheduled at ${_formatTime(scheduledTime)}',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text('When did you take this dose?'),
            SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.access_time, color: Colors.green),
              title: Text('Just now'),
              onTap: () {
                Navigator.pop(context);
                controller.recordDoseTaken(
                  medicationId: medication.id,
                  scheduledAt: scheduledTime,
                  takenAt: DateTime.now(),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.schedule, color: Colors.blue),
              title: Text('On time (${_formatTime(scheduledTime)})'),
              onTap: () {
                Navigator.pop(context);
                controller.recordDoseTaken(
                  medicationId: medication.id,
                  scheduledAt: scheduledTime,
                  takenAt: scheduledTime,
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.edit_calendar, color: Colors.orange),
              title: Text('Choose time...'),
              onTap: () async {
                Navigator.pop(context);
                final TimeOfDay? pickedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(scheduledTime),
                );
                if (pickedTime != null) {
                  final now = DateTime.now();
                  final takenAt = DateTime(now.year, now.month, now.day, pickedTime.hour, pickedTime.minute);
                  controller.recordDoseTaken(
                    medicationId: medication.id,
                    scheduledAt: scheduledTime,
                    takenAt: takenAt,
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showCustomDoseDialog(Medication medication) async {
    // First pick the date
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(Duration(days: 30)),
      lastDate: DateTime.now().add(Duration(days: 1)),
      helpText: 'Select the date of the dose',
    );

    if (pickedDate == null) return;

    // Then pick the scheduled time
    final TimeOfDay? scheduledTimeOfDay = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'What time was this dose scheduled?',
    );

    if (scheduledTimeOfDay == null) return;

    // Then pick when it was actually taken
    final TimeOfDay? takenTimeOfDay = await showTimePicker(
      context: context,
      initialTime: scheduledTimeOfDay,
      helpText: 'What time did you take it?',
    );

    if (takenTimeOfDay == null) return;

    final scheduledAt = DateTime(
      pickedDate.year, pickedDate.month, pickedDate.day,
      scheduledTimeOfDay.hour, scheduledTimeOfDay.minute,
    );

    final takenAt = DateTime(
      pickedDate.year, pickedDate.month, pickedDate.day,
      takenTimeOfDay.hour, takenTimeOfDay.minute,
    );

    controller.recordDoseTaken(
      medicationId: medication.id,
      scheduledAt: scheduledAt,
      takenAt: takenAt,
    );
  }

  void _showAddMedicationDialog() {
    final TextEditingController drugNameController = TextEditingController();
    final TextEditingController brandNameController = TextEditingController();
    final TextEditingController strengthController = TextEditingController();
    final TextEditingController instructionsController = TextEditingController();
    
    String selectedForm = 'tablet';
    String selectedUnit = 'mg';
    String selectedFrequency = 'once_daily';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Medication'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: drugNameController,
                decoration: InputDecoration(
                  labelText: 'Drug Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: brandNameController,
                decoration: InputDecoration(
                  labelText: 'Brand Name (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: strengthController,
                      decoration: InputDecoration(
                        labelText: 'Strength *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedUnit,
                      decoration: InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                      items: ['mg', 'ml', 'units', 'tablets'].map((unit) => 
                        DropdownMenuItem(value: unit, child: Text(unit))
                      ).toList(),
                      onChanged: (value) => selectedUnit = value!,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              DropdownButtonFormField<String>(
                value: selectedForm,
                decoration: InputDecoration(
                  labelText: 'Form',
                  border: OutlineInputBorder(),
                ),
                items: ['tablet', 'capsule', 'liquid', 'injection', 'topical'].map((form) => 
                  DropdownMenuItem(value: form, child: Text(form.capitalize!))
                ).toList(),
                onChanged: (value) => selectedForm = value!,
              ),
              SizedBox(height: 12.h),
              DropdownButtonFormField<String>(
                value: selectedFrequency,
                decoration: InputDecoration(
                  labelText: 'Frequency',
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 'once_daily', child: Text('Once Daily')),
                  DropdownMenuItem(value: 'twice_daily', child: Text('Twice Daily')),
                  DropdownMenuItem(value: 'three_times_daily', child: Text('Three Times Daily')),
                  DropdownMenuItem(value: 'four_times_daily', child: Text('Four Times Daily')),
                ],
                onChanged: (value) => selectedFrequency = value!,
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: instructionsController,
                decoration: InputDecoration(
                  labelText: 'Instructions (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (drugNameController.text.isNotEmpty && strengthController.text.isNotEmpty) {
                final medication = Medication(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  profileId: 'current_user',
                  drugName: drugNameController.text,
                  brandName: brandNameController.text.isEmpty ? null : brandNameController.text,
                  form: selectedForm,
                  strength: double.tryParse(strengthController.text) ?? 0.0,
                  strengthUnit: selectedUnit,
                  route: 'oral', // Adding required route parameter
                  instructionsText: instructionsController.text.isEmpty ? '' : instructionsController.text,
                  asNeeded: false, // Adding required asNeeded parameter
                  schedule: MedicationSchedule(
                    frequency: _getFrequencyFromString(selectedFrequency),
                    times: _getDefaultTimesForFrequency(selectedFrequency),
                    days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
                    reminderEnabled: true,
                    reminderMinutesBefore: 15,
                    caregiverEscalationEnabled: false,
                  ),
                  isActive: true,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                await controller.addMedication();
                Navigator.pop(context);
              }
            },
            child: Text('Add Medication'),
          ),
        ],
      ),
    );
  }

  void _showEditMedicationDialog(Medication medication) {
    final drugNameController = TextEditingController(text: medication.drugName);
    final strengthController = TextEditingController(text: medication.strength.toString());
    final instructionsController = TextEditingController(text: medication.instructionsText ?? '');

    String selectedForm = medication.form;
    String selectedUnit = medication.strengthUnit;
    bool asNeeded = medication.asNeeded;

    Get.dialog(
      AlertDialog(
        title: Text('Edit Medication'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: drugNameController,
                decoration: InputDecoration(labelText: 'Drug Name'),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: strengthController,
                      decoration: InputDecoration(labelText: 'Strength'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: StatefulBuilder(
                      builder: (context, setState) => DropdownButtonFormField<String>(
                        value: selectedUnit,
                        decoration: InputDecoration(labelText: 'Unit'),
                        items: ['mg', 'mcg', 'g', 'ml', 'IU', '%']
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) => setState(() => selectedUnit = v!),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              StatefulBuilder(
                builder: (context, setState) => DropdownButtonFormField<String>(
                  value: selectedForm,
                  decoration: InputDecoration(labelText: 'Form'),
                  items: ['tablet', 'capsule', 'liquid', 'injection', 'patch', 'cream', 'drops', 'inhaler']
                      .map((f) => DropdownMenuItem(value: f, child: Text(f.capitalize!)))
                      .toList(),
                  onChanged: (v) => setState(() => selectedForm = v!),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: instructionsController,
                decoration: InputDecoration(labelText: 'Instructions'),
                maxLines: 2,
              ),
              SizedBox(height: 12),
              StatefulBuilder(
                builder: (context, setState) => SwitchListTile(
                  title: Text('As Needed'),
                  value: asNeeded,
                  onChanged: (v) => setState(() => asNeeded = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedMedication = medication.copyWith(
                drugName: drugNameController.text,
                strength: double.tryParse(strengthController.text) ?? medication.strength,
                strengthUnit: selectedUnit,
                form: selectedForm,
                instructionsText: instructionsController.text,
                asNeeded: asNeeded,
              );

              await controller.updateMedication(medication.id, updatedMedication);
              Get.back();
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteMedication(Medication medication) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Medication'),
        content: Text('Are you sure you want to delete ${medication.drugName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await controller.deleteMedication(medication.id, 'User deleted');
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAnalytics() {
    Get.toNamed(RoutesName.adherenceAnalysisScreen);
  }

  MedicationFrequency _getFrequencyFromString(String frequency) {
    switch (frequency) {
      case 'once_daily':
      case 'twice_daily':
      case 'three_times_daily':
      case 'four_times_daily':
        return MedicationFrequency.daily;
      case 'weekly':
        return MedicationFrequency.weekly;
      case 'as_needed':
        return MedicationFrequency.asNeeded;
      default:
        return MedicationFrequency.daily;
    }
  }

  List<String> _getDefaultTimesForFrequency(String frequency) {
    switch (frequency) {
      case 'once_daily':
        return ['09:00'];
      case 'twice_daily':
        return ['09:00', '21:00'];
      case 'three_times_daily':
        return ['09:00', '14:00', '21:00'];
      case 'four_times_daily':
        return ['09:00', '13:00', '17:00', '21:00'];
      default:
        return ['09:00'];
    }
  }
}