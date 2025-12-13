import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/repository/health_profile/health_profile.dart';
import 'package:kindura_ai/res/routes/routes_name.dart';
import 'package:kindura_ai/screens/lifestyle_habits/lifestyle_habits_controller.dart';
import 'package:kindura_ai/screens/physical_activity/physical_activity_controller.dart';
import 'package:kindura_ai/utils/utils.dart';

class DietaryHabitsController extends GetxController {
  final _api = HealthProfileRepository();
  // Text Controllers
  final dietaryRestrictionsController = TextEditingController().obs;
  final dailyWaterIntakeController = TextEditingController().obs;

  // Focus Nodes
  final dietaryRestrictionsFocusNode = FocusNode().obs;
  final dailyWaterIntakeFocusNode = FocusNode().obs;

  // Observable Variables
  final dietType = 'vegetarian'.obs;
  final requestStatus = Status.COMPLETED.obs;

  // Diet type choices
  final dietTypeChoices = [
    {'value': 'vegetarian', 'label': 'Vegetarian'},
    {'value': 'non_vegetarian', 'label': 'Non-vegetarian'},
    {'value': 'vegan', 'label': 'Vegan'},
    {'value': 'other', 'label': 'Other'},
  ];

  Map dietaryHabitsData = {};
  Map healthProfileData = {};

  final lifestyleController = Get.find<LifestyleHabitsController>();
  final physicalActivityController = Get.find<PhysicalActivityController>();

  void setDietType(String value) => dietType.value = value;
  void setRequestStatus(Status value) => requestStatus.value = value;

  void saveDietaryHabits() {
    // Validate daily water intake
    if (dailyWaterIntakeController.value.text.isEmpty) {
      Util.Snack_Bar("Warning", "Please enter your daily water intake");
      return;
    }

    double? waterIntake =
        double.tryParse(dailyWaterIntakeController.value.text);
    if (waterIntake == null || waterIntake <= 0) {
      Util.Snack_Bar(
          "Warning", "Please enter a valid water intake (in liters)");
      return;
    }

    if (waterIntake > 10) {
      // 10 liters max
      Util.Snack_Bar(
          "Warning", "Please enter a reasonable water intake (max 10 liters)");
      return;
    }

    setRequestStatus(Status.LOADING);

    dietaryHabitsData["diet_type"] = dietType.value;
    if (dietaryRestrictionsController.value.text.isNotEmpty) {
      dietaryHabitsData["dietary_restrictions"] =
          dietaryRestrictionsController.value.text;
    } else {
      dietaryHabitsData.remove('dietary_restrictions');
    }
    dietaryHabitsData["daily_water_intake"] =
        dailyWaterIntakeController.value.text;
    print("the data is $dietaryHabitsData");

    healthProfileData["lifestyle_habits"] = lifestyleController.data;
    healthProfileData["physical_activity"] = physicalActivityController.data;
    healthProfileData["dietary_habits"] = dietaryHabitsData;
    print("the data is $healthProfileData");

    _api.healthProfileApi(healthProfileData).then((value) {
      print("the value is $value");
      if (value['status'] == true) {
        Util.Snack_Bar(
            "Success", "Your health profile has been saved successfully");
        Get.toNamed(RoutesName.pdfUploadScreen);
      } else {
        Util.Snack_Bar("Error", "Failed to save dietary habits");
      }
    });

    // Get.toNamed(RoutesName.mainScreen);
    setRequestStatus(Status.COMPLETED);
  }

  @override
  void onClose() {
    // Dispose controllers
    dietaryRestrictionsController.value.dispose();
    dailyWaterIntakeController.value.dispose();

    // Dispose focus nodes
    dietaryRestrictionsFocusNode.value.dispose();
    dailyWaterIntakeFocusNode.value.dispose();

    super.onClose();
  }
}
