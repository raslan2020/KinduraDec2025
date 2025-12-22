import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/screens/medication/medication_controller.dart';
import 'package:kindura_ai/screens/medication/widgets/medication_card.dart';
import 'package:kindura_ai/screens/medication/add_medication_screen.dart';
import 'package:kindura_ai/models/medication/medication_models.dart';
import 'package:kindura_ai/common_widgets/custom_button.dart';
import 'package:kindura_ai/utils/app_toast.dart';

class MedicationScreen extends GetView<MedicationController> {
  const MedicationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'My Medications',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => controller.loadMedications(forceRefresh: true),
            icon: Obx(() => controller.isLoading
                ? SizedBox(
                    width: 20.w,
                    height: 20.h,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.blue,
                    ),
                  )
                : Icon(Icons.refresh, color: Colors.blue)),
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: Column(
        children: [
          _buildVoiceCommandDisplay(),
          _buildTodayOverview(),
          Expanded(child: _buildMedicationList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.to(() => AddMedicationScreen()),
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Medication',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildVoiceCommandDisplay() {
    return Obx(() {
      if (controller.lastVoiceCommand.value.isEmpty) {
        return SizedBox.shrink();
      }
      
      return Container(
        width: double.infinity,
        margin: EdgeInsets.all(16.w),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.mic, color: Colors.blue, size: 20.sp),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'Voice: "${controller.lastVoiceCommand.value}"',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: Colors.blue.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            IconButton(
              onPressed: () => controller.lastVoiceCommand.value = '',
              icon: Icon(Icons.close, color: Colors.blue.shade400, size: 18.sp),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildTodayOverview() {
    return Obx(() {
      final todaySchedule = controller.getTodaySchedule();
      if (todaySchedule.isEmpty) {
        return SizedBox.shrink();
      }

      final overdue = todaySchedule.where((item) => item['is_overdue'] == true).length;
      final upcoming = todaySchedule.where((item) => item['is_overdue'] == false).length;

      return Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Schedule',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                _buildScheduleCounter('Upcoming', upcoming, Colors.blue),
                SizedBox(width: 20.w),
                if (overdue > 0) _buildScheduleCounter('Overdue', overdue, Colors.red),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildScheduleCounter(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 8.w,
          height: 8.h,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          '$count $label',
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMedicationList() {
    return Obx(() {
      if (controller.isLoading && controller.medications.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.blue),
              SizedBox(height: 16.h),
              Text(
                'Loading medications...',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      }

      if (controller.medications.isEmpty) {
        return _buildEmptyState();
      }

      return RefreshIndicator(
        onRefresh: () => controller.loadMedications(forceRefresh: true),
        color: Colors.blue,
        child: ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          itemCount: controller.medications.length,
          itemBuilder: (context, index) {
            final medication = controller.medications[index];
            return Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: MedicationCard(
                medication: medication,
                onTap: () => _showMedicationDetails(medication),
                onTakeDose: () => controller.recordDoseTaken(
                  medicationId: medication.id,
                  scheduledAt: DateTime.now(),
                  method: 'manual',
                ),
                onEdit: () => Get.to(() => AddMedicationScreen(medication: medication)),
                onDelete: () => _showDeleteConfirmation(medication),
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medication_outlined,
              size: 64.sp,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16.h),
            Text(
              'No Medications Added',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Add your first medication to start tracking reminders and adherence.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            SizedBox(height: 24.h),
            CustomButton(
              text: 'Add Medication',
              onPressed: () => Get.to(() => AddMedicationScreen()),
              bgColor: Colors.blue,
              textColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  void _showMedicationDetails(Medication medication) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.r),
            topRight: Radius.circular(20.r),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    medication.displayName,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Get.back(),
                  icon: Icon(Icons.close, color: Colors.grey[600]),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            _buildDetailRow('Strength', medication.strengthDisplay),
            _buildDetailRow('Form', medication.form),
            _buildDetailRow('Route', medication.route),
            if (medication.instructionsText.isNotEmpty)
              _buildDetailRow('Instructions', medication.instructionsText),
            if (medication.takeWithFood != null)
              _buildDetailRow('Food', medication.takeWithFood! ? 'Take with food' : 'Take on empty stomach'),
            _buildDetailRow('Times', medication.schedule.times.join(', ')),
            if (medication.schedule.days != null)
              _buildDetailRow('Days', medication.schedule.days!.join(', ')),
            SizedBox(height: 20.h),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Take Now',
                    bgColor: Colors.green,
                    textColor: Colors.white,
                    onPressed: () {
                      Get.back();
                      controller.recordDoseTaken(
                        medicationId: medication.id,
                        scheduledAt: DateTime.now(),
                        method: 'manual',
                      );
                    },
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: CustomButton(
                    text: 'Edit',
                    bgColor: Colors.blue,
                    textColor: Colors.white,
                    onPressed: () {
                      Get.back();
                      Get.to(() => AddMedicationScreen(medication: medication));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80.w,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Medication medication) {
    Get.dialog(
      AlertDialog(
        title: Text('Delete Medication'),
        content: Text(
          'Are you sure you want to delete ${medication.displayName}? This will also cancel all scheduled reminders.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.deleteMedication(medication.id, 'User requested deletion');
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}