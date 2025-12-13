import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/res/routes/routes_name.dart';
import 'package:kindura_ai/utils/utils.dart';

class PhysicalActivityController extends GetxController {
  // Text Controllers
  final exerciseTypeController = TextEditingController().obs;
  final averageDurationController = TextEditingController().obs;

  // Focus Nodes
  final exerciseTypeFocusNode = FocusNode().obs;
  final averageDurationFocusNode = FocusNode().obs;

  // Observable Variables
  final exerciseFrequency = 'never'.obs;
  final requestStatus = Status.COMPLETED.obs;
  Map data = {};

  // Exercise frequency choices
  final exerciseFrequencyChoices = [
    {'value': 'never', 'label': 'Never'},
    {'value': '1-2', 'label': '1-2 times per week'},
    {'value': '3-4', 'label': '3-4 times per week'},
    {'value': '5-6', 'label': '5-6 times per week'},
    {'value': 'daily', 'label': 'Daily'},
  ];

  void setExerciseFrequency(String value) => exerciseFrequency.value = value;
  void setRequestStatus(Status value) => requestStatus.value = value;

  void savePhysicalActivity() {
    // Validate exercise type if frequency is not 'never'
    if (exerciseFrequency.value != 'never' &&
        exerciseTypeController.value.text.isEmpty) {
      Util.Snack_Bar("Warning", "Please enter the type of exercise you do");
      return;
    }

    // Validate average duration if frequency is not 'never'
    if (exerciseFrequency.value != 'never') {
      if (averageDurationController.value.text.isEmpty) {
        Util.Snack_Bar(
            "Warning", "Please enter the average duration of your exercise");
        return;
      }

      int? duration = int.tryParse(averageDurationController.value.text);
      if (duration == null || duration <= 0) {
        Util.Snack_Bar("Warning", "Please enter a valid duration (in minutes)");
        return;
      }

      if (duration > 480) {
        // 8 hours max
        Util.Snack_Bar(
            "Warning", "Please enter a reasonable duration (max 8 hours)");
        return;
      }
    }

    data["exercise_frequency"] = exerciseFrequency.value;
    if (exerciseFrequency.value != 'never') {
      data["exercise_type"] = exerciseTypeController.value.text;
      data["average_duration"] = averageDurationController.value.text;
    } else {
      data.remove('exercise_type');
      data.remove('average_duration');
    }

    Get.toNamed(RoutesName.dietaryHabitsScreen);
  }

  @override
  void onClose() {
    // Dispose controllers
    exerciseTypeController.value.dispose();
    averageDurationController.value.dispose();

    // Dispose focus nodes
    exerciseTypeFocusNode.value.dispose();
    averageDurationFocusNode.value.dispose();

    super.onClose();
  }
}
