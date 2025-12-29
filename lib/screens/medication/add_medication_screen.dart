import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/screens/medication/medication_controller.dart';
import 'package:kindura_ai/models/medication/medication_models.dart';
import 'package:kindura_ai/common_widgets/custom_button.dart';
import 'package:kindura_ai/common_widgets/custom_text_field_new.dart';
import 'package:kindura_ai/utils/app_toast.dart';
import 'package:kindura_ai/data/response/status.dart';

class AddMedicationScreen extends GetView<MedicationController> {
  final Medication? medication;

  const AddMedicationScreen({super.key, this.medication});

  bool get isEditing => medication != null;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0F172A) : Colors.grey[50];
    final appBarColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    // Initialize form when editing
    if (isEditing && medication != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.populateFormFromMedication(medication!);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.clearForm();
      });
    }
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Get.back(),
        ),
        title: Text(
          isEditing ? 'Edit Medication' : 'Add Medication',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        backgroundColor: appBarColor,
        elevation: isDark ? 0 : 1,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            _buildMedicationInfoSection(context),
            SizedBox(height: 20.h),
            _buildScheduleSection(context),
            SizedBox(height: 20.h),
            _buildReminderSection(context),
            SizedBox(height: 32.h),
            _buildSaveButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationInfoSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Medication Information',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          SizedBox(height: 16.h),
          CustomTextFieldNew(
            controller: controller.drugNameController,
            labelText: 'Drug Name *',
            focusNode: controller.drugNameFocusNode,
          ),
          SizedBox(height: 12.h),
          CustomTextFieldNew(
            controller: controller.brandNameController,
            labelText: 'Brand Name (Optional)',
            focusNode: controller.brandNameFocusNode,
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: CustomTextFieldNew(
                  controller: controller.strengthController,
                  labelText: 'Strength (optional)',
                  focusNode: controller.strengthFocusNode,
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Obx(() => _buildDropdown(
                  context: context,
                  value: controller.strengthUnit.value,
                  items: ['mg', 'ml', 'units', 'mcg', 'g'],
                  onChanged: (value) => controller.strengthUnit.value = value!,
                  hint: 'Unit',
                )),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Obx(() => _buildDropdown(
            context: context,
            value: controller.medicationForm.value,
            items: ['tablet', 'capsule', 'liquid', 'injection', 'inhaler', 'cream', 'ointment'],
            onChanged: (value) => controller.medicationForm.value = value!,
            hint: 'Medication Form *',
          )),
          SizedBox(height: 12.h),
          Obx(() => _buildDropdown(
            context: context,
            value: controller.medicationRoute.value,
            items: ['oral', 'injection', 'topical', 'inhalation', 'sublingual'],
            onChanged: (value) => controller.medicationRoute.value = value!,
            hint: 'Route *',
          )),
          SizedBox(height: 12.h),
          CustomTextFieldNew(
            controller: controller.instructionsController,
            labelText: 'Instructions',
            focusNode: controller.instructionsFocusNode,
            maxLines: 2,
          ),
          SizedBox(height: 12.h),
          _buildFoodPreferenceSection(context),
        ],
      ),
    );
  }

  Widget _buildFoodPreferenceSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Food Requirements',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
        SizedBox(height: 8.h),
        Obx(() => Column(
          children: [
            RadioListTile<bool?>(
              title: Text('No specific requirement', style: TextStyle(fontSize: 14.sp, color: textColor)),
              value: null,
              groupValue: controller.takeWithFood.value,
              onChanged: (value) => controller.takeWithFood.value = value,
              contentPadding: EdgeInsets.zero,
            ),
            RadioListTile<bool?>(
              title: Text('Take with food', style: TextStyle(fontSize: 14.sp, color: textColor)),
              value: true,
              groupValue: controller.takeWithFood.value,
              onChanged: (value) => controller.takeWithFood.value = value,
              contentPadding: EdgeInsets.zero,
            ),
            RadioListTile<bool?>(
              title: Text('Take on empty stomach', style: TextStyle(fontSize: 14.sp, color: textColor)),
              value: false,
              groupValue: controller.takeWithFood.value,
              onChanged: (value) => controller.takeWithFood.value = value,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        )),
      ],
    );
  }

  Widget _buildScheduleSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schedule',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          SizedBox(height: 16.h),
          Obx(() => CheckboxListTile(
            title: Text('As needed (PRN)', style: TextStyle(fontSize: 14.sp, color: textColor)),
            subtitle: Text('Take only when needed, not on a schedule', style: TextStyle(fontSize: 12.sp, color: subtitleColor)),
            value: controller.asNeeded.value,
            onChanged: (value) => controller.asNeeded.value = value!,
            contentPadding: EdgeInsets.zero,
          )),
          Obx(() {
            if (controller.asNeeded.value) {
              return SizedBox.shrink();
            }
            return Column(
              children: [
                SizedBox(height: 16.h),
                _buildTimesList(context),
                SizedBox(height: 16.h),
                _buildDaysSelection(context),
                SizedBox(height: 16.h),
                _buildMissedDosePolicySection(context),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMissedDosePolicySection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'If Dose is Missed',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
        SizedBox(height: 8.h),
        Obx(() => _buildMissedDoseDropdown(
          context: context,
          value: controller.missedDoseAction.value,
          onChanged: (value) => controller.missedDoseAction.value = value!,
        )),
        SizedBox(height: 8.h),
        Text(
          _getMissedDoseDescription(controller.missedDoseAction.value),
          style: TextStyle(
            fontSize: 12.sp,
            color: subtitleColor,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildMissedDoseDropdown({
    required BuildContext context,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final borderColor = isDark ? Colors.grey[600]! : Colors.grey[300]!;
    final fillColor = isDark ? const Color(0xFF0F172A) : Colors.white;

    final items = {
      'no_policy': 'No specific policy',
      'skip_dose': 'Skip and wait for next dose',
      'take_asap': 'Take as soon as possible',
      'take_and_shift': 'Take now and shift schedule',
      'contact_doctor': 'Contact doctor first',
    };

    return DropdownButtonFormField<String>(
      value: value.isEmpty ? 'no_policy' : value,
      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      style: TextStyle(fontSize: 14.sp, color: textColor),
      decoration: InputDecoration(
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: Colors.blue),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      ),
      items: items.entries.map((entry) {
        return DropdownMenuItem<String>(
          value: entry.key,
          child: Text(entry.value, style: TextStyle(fontSize: 14.sp, color: textColor)),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  String _getMissedDoseDescription(String policy) {
    switch (policy) {
      case 'skip_dose':
        return 'If you miss a dose, skip it and take the next dose at your regular time. Do not double up.';
      case 'take_asap':
        return 'Take the missed dose as soon as you remember, then continue with your regular schedule.';
      case 'take_and_shift':
        return 'Take the dose now and shift your remaining doses for the day to maintain proper intervals.';
      case 'contact_doctor':
        return 'This medication requires medical guidance when a dose is missed. Contact your doctor or pharmacist.';
      default:
        return 'No specific guidance set. Check with your pharmacist if you miss a dose.';
    }
  }

  Widget _buildTimesList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final unselectedBg = isDark ? const Color(0xFF0F172A) : Colors.grey[100];
    final borderColor = isDark ? Colors.grey[600]! : Colors.grey[300]!;
    final timeBg = isDark ? const Color(0xFF0F172A) : Colors.grey[50];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Doses per day selector
        Text(
          'How many times per day?',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
        SizedBox(height: 8.h),
        Obx(() => Row(
          children: [1, 2, 3, 4].map((count) {
            final isSelected = controller.dosesPerDay.value == count;
            return Expanded(
              child: GestureDetector(
                onTap: () => controller.onDosesPerDayChanged(count),
                child: Container(
                  margin: EdgeInsets.only(right: count < 4 ? 8.w : 0),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue : unselectedBg,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: isSelected ? Colors.blue : borderColor,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${count}x',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : textColor,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        )),
        SizedBox(height: 4.h),
        Obx(() => Text(
          _getDoseFrequencyHint(controller.dosesPerDay.value),
          style: TextStyle(
            fontSize: 12.sp,
            color: subtitleColor,
            fontStyle: FontStyle.italic,
          ),
        )),
        SizedBox(height: 16.h),

        // Times header with add button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Dose Times',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
            TextButton.icon(
              onPressed: controller.addTime,
              icon: Icon(Icons.add, size: 16.sp),
              label: Text('Add', style: TextStyle(fontSize: 13.sp)),
            ),
          ],
        ),
        SizedBox(height: 8.h),

        // Times list - tappable to edit
        Obx(() => Column(
          children: controller.scheduleTimes.asMap().entries.map((entry) {
            final index = entry.key;
            final time = entry.value;
            return GestureDetector(
              onTap: () => controller.editTime(index),
              child: Container(
                margin: EdgeInsets.only(bottom: 8.h),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: timeBg,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 18.sp, color: Colors.blue),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        _formatTimeForDisplay(time),
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: textColor,
                        ),
                      ),
                    ),
                    Text(
                      'Tap to edit',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: subtitleColor,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    GestureDetector(
                      onTap: () => controller.removeTime(index),
                      child: Icon(Icons.close, size: 18.sp, color: Colors.red[400]),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        )),
        if (controller.scheduleTimes.isEmpty)
          TextButton.icon(
            onPressed: controller.addTime,
            icon: Icon(Icons.add, size: 16.sp),
            label: Text('Add first dose time', style: TextStyle(fontSize: 13.sp)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue,
              padding: EdgeInsets.symmetric(vertical: 12.h),
            ),
          ),
      ],
    );
  }

  Widget _buildDaysSelection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final chipBg = isDark ? const Color(0xFF0F172A) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Days',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
        SizedBox(height: 8.h),
        Obx(() => Column(
          children: [
            CheckboxListTile(
              title: Text('Daily', style: TextStyle(fontSize: 14.sp, color: textColor)),
              value: controller.isDailySchedule.value,
              onChanged: (value) {
                if (value!) {
                  controller.selectedDays.assignAll(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']);
                } else {
                  controller.selectedDays.clear();
                }
                controller.isDailySchedule.value = value;
              },
              contentPadding: EdgeInsets.zero,
            ),
            if (!controller.isDailySchedule.value) ...[
              SizedBox(height: 8.h),
              Wrap(
                spacing: 8.w,
                children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day) {
                  return Obx(() => FilterChip(
                    label: Text(day, style: TextStyle(fontSize: 12.sp, color: controller.selectedDays.contains(day) ? Colors.blue : textColor)),
                    selected: controller.selectedDays.contains(day),
                    onSelected: (selected) {
                      if (selected) {
                        controller.selectedDays.add(day);
                      } else {
                        controller.selectedDays.remove(day);
                      }
                    },
                    backgroundColor: chipBg,
                    selectedColor: Colors.blue.withValues(alpha: 0.3),
                    checkmarkColor: Colors.blue,
                  ));
                }).toList(),
              ),
            ],
          ],
        )),
      ],
    );
  }

  Widget _buildReminderSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reminders',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          SizedBox(height: 16.h),
          Obx(() => SwitchListTile(
            title: Text('Enable reminders', style: TextStyle(fontSize: 14.sp, color: textColor)),
            subtitle: Text('Get notifications when it\'s time to take medication', style: TextStyle(fontSize: 12.sp, color: subtitleColor)),
            value: controller.remindersEnabled.value,
            onChanged: (value) => controller.remindersEnabled.value = value,
            contentPadding: EdgeInsets.zero,
          )),
          Obx(() {
            if (!controller.remindersEnabled.value) {
              return SizedBox.shrink();
            }
            return Column(
              children: [
                SizedBox(height: 16.h),
                SwitchListTile(
                  title: Text('Caregiver escalation', style: TextStyle(fontSize: 14.sp, color: textColor)),
                  subtitle: Text('Notify caregiver if dose is missed', style: TextStyle(fontSize: 12.sp, color: subtitleColor)),
                  value: controller.caregiverEscalationEnabled.value,
                  onChanged: (value) => controller.caregiverEscalationEnabled.value = value,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required BuildContext context,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String hint,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final borderColor = isDark ? Colors.grey[600]! : Colors.grey[300]!;
    final fillColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final labelColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return DropdownButtonFormField<String>(
      value: value?.isEmpty == true ? null : value,
      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      style: TextStyle(fontSize: 14.sp, color: textColor),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: TextStyle(color: labelColor),
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: Colors.blue),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, style: TextStyle(fontSize: 14.sp, color: textColor)),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return Obx(() => CustomButton(
      text: isEditing ? 'Update Medication' : 'Save Medication',
      onPressed: controller.requestStatus.value == Status.LOADING ? () {} : _saveMedication,
      bgColor: Colors.blue,
      textColor: Colors.white,
    ));
  }

  void _saveMedication() {
    if (_validateForm()) {
      if (isEditing) {
        controller.updateMedicationFromForm(medication!.id);
      } else {
        controller.addMedication();
      }
    }
  }

  String _getDoseFrequencyHint(int doses) {
    switch (doses) {
      case 1:
        return 'Once daily - set your preferred time';
      case 2:
        return 'Twice daily - times will be spaced 12 hours apart';
      case 3:
        return 'Three times daily - times will be spaced 8 hours apart';
      case 4:
        return 'Four times daily - times will be spaced 6 hours apart';
      default:
        return 'Times will be evenly distributed throughout the day';
    }
  }

  String _formatTimeForDisplay(String time24h) {
    try {
      final parts = time24h.split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);

      final period = hour >= 12 ? 'PM' : 'AM';
      if (hour == 0) {
        hour = 12;
      } else if (hour > 12) {
        hour = hour - 12;
      }

      return '$hour:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return time24h;
    }
  }

  bool _validateForm() {
    if (controller.drugNameController.text.trim().isEmpty) {
      AppToast.showError('Drug name is required');
      return false;
    }
    
    // Strength is optional for some medications
    // Only validate unit if strength is provided
    if (controller.strengthController.text.trim().isNotEmpty &&
        controller.strengthUnit.value.isEmpty) {
      AppToast.showError('Please select strength unit when strength is provided');
      return false;
    }
    
    if (controller.medicationForm.value.isEmpty) {
      AppToast.showError('Medication form is required');
      return false;
    }
    
    if (controller.medicationRoute.value.isEmpty) {
      AppToast.showError('Route is required');
      return false;
    }
    
    if (!controller.asNeeded.value && controller.scheduleTimes.isEmpty) {
      AppToast.showError('Please add at least one dose time');
      return false;
    }
    
    if (!controller.asNeeded.value && !controller.isDailySchedule.value && controller.selectedDays.isEmpty) {
      AppToast.showError('Please select at least one day');
      return false;
    }
    
    return true;
  }
}