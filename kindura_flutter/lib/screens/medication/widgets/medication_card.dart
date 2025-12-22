import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/models/medication/medication_models.dart';

class MedicationCard extends StatelessWidget {
  final Medication medication;
  final VoidCallback? onTap;
  final VoidCallback? onTakeDose;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const MedicationCard({
    Key? key,
    required this.medication,
    this.onTap,
    this.onTakeDose,
    this.onEdit,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: medication.isExpired
              ? Border.all(color: Colors.red.shade300, width: 1.5)
              : null,
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
            _buildHeader(),
            SizedBox(height: 12.h),
            _buildMedicationInfo(),
            SizedBox(height: 12.h),
            _buildScheduleInfo(),
            if (medication.needsRefill || medication.isExpired) ...[
              SizedBox(height: 8.h),
              _buildWarnings(),
            ],
            SizedBox(height: 12.h),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 40.w,
          height: 40.h,
          decoration: BoxDecoration(
            color: _getMedicationColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(
            _getMedicationIcon(),
            color: _getMedicationColor(),
            size: 20.sp,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                medication.displayName,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                '${medication.strengthDisplay} • ${medication.form}',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 18.sp),
                  SizedBox(width: 8.w),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 18.sp, color: Colors.red),
                  SizedBox(width: 8.w),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          child: Icon(
            Icons.more_vert,
            color: Colors.grey[500],
            size: 20.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildMedicationInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (medication.instructionsText.isNotEmpty) ...[
          Text(
            medication.instructionsText,
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.grey[700],
              fontStyle: FontStyle.italic,
            ),
          ),
          SizedBox(height: 4.h),
        ],
        if (medication.takeWithFood != null) ...[
          Text(
            medication.takeWithFood! ? '🍽️ Take with food' : '🚫 Take on empty stomach',
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildScheduleInfo() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 16.sp, color: Colors.blue),
              SizedBox(width: 6.w),
              Text(
                'Schedule',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            _getScheduleText(),
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey[700],
            ),
          ),
          if (medication.schedule.reminderEnabled) ...[
            SizedBox(height: 4.h),
            Row(
              children: [
                Icon(Icons.notifications, size: 14.sp, color: Colors.green),
                SizedBox(width: 4.w),
                Text(
                  'Reminders enabled',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWarnings() {
    return Column(
      children: [
        if (medication.isExpired)
          _buildWarningChip(
            '⚠️ Expired',
            Colors.red,
          ),
        if (medication.needsRefill)
          _buildWarningChip(
            '🔄 Needs refill (${medication.refillsRemaining} left)',
            Colors.orange,
          ),
      ],
    );
  }

  Widget _buildWarningChip(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.sp,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        if (!medication.asNeeded && medication.isActive) ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onTakeDose,
              icon: Icon(Icons.check, size: 16.sp),
              label: Text('Take Now', style: TextStyle(fontSize: 13.sp)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 8.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
        ],
        Expanded(
          child: OutlinedButton(
            onPressed: onTap,
            child: Text('View Details', style: TextStyle(fontSize: 13.sp)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              padding: EdgeInsets.symmetric(vertical: 8.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getMedicationColor() {
    switch (medication.form.toLowerCase()) {
      case 'tablet':
        return Colors.blue;
      case 'capsule':
        return Colors.purple;
      case 'liquid':
        return Colors.cyan;
      case 'injection':
        return Colors.red;
      case 'inhaler':
        return Colors.teal;
      case 'cream':
      case 'ointment':
        return Colors.green;
      default:
        return Colors.indigo;
    }
  }

  IconData _getMedicationIcon() {
    switch (medication.form.toLowerCase()) {
      case 'tablet':
        return Icons.medication;
      case 'capsule':
        return Icons.medication_liquid;
      case 'liquid':
        return Icons.water_drop;
      case 'injection':
        return Icons.colorize;
      case 'inhaler':
        return Icons.air;
      case 'cream':
      case 'ointment':
        return Icons.healing;
      default:
        return Icons.medication_outlined;
    }
  }

  String _getScheduleText() {
    final times = medication.schedule.times.join(', ');
    
    if (medication.schedule.isDailySchedule) {
      return 'Daily at $times';
    } else {
      final days = medication.schedule.days!.join(', ');
      return '$days at $times';
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        onEdit?.call();
        break;
      case 'delete':
        onDelete?.call();
        break;
    }
  }
}