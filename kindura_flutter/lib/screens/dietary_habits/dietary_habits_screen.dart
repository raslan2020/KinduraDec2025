import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/common_widgets/custom_button.dart';
import 'package:kindura_ai/common_widgets/custom_text_field_new.dart';
import 'package:kindura_ai/common_widgets/loading_indicator.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/res/colors/app_color.dart';
import 'package:kindura_ai/screens/dietary_habits/dietary_habits_controller.dart';

class DietaryHabitsScreen extends StatefulWidget {
  const DietaryHabitsScreen({super.key});

  @override
  State<DietaryHabitsScreen> createState() => _DietaryHabitsScreenState();
}

class _DietaryHabitsScreenState extends State<DietaryHabitsScreen> {
  final dietaryHabitsController = Get.put(DietaryHabitsController());
  final _formkey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              AppBar(
                centerTitle: true,
                title: Text(
                  "Dietary Habits",
                  style: TextStyle(
                    color: AppColor.black,
                  ),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: AppColor.black),
                  onPressed: () => Get.back(),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: "Your ",
                                  style: TextStyle(
                                      color: AppColor.black,
                                      fontSize: 20.sp,
                                      fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                  text: "Dietary Habits",
                                  style: TextStyle(
                                      color: AppColor.primaryColor,
                                      fontSize: 20.sp,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            "Help us understand your eating habits and dietary preferences",
                            style: TextStyle(
                              color: AppColor.black.withOpacity(0.7),
                              fontSize: 14.sp,
                            ),
                          ),
                          SizedBox(height: 30.h),
                          Form(
                            key: _formkey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Diet Type Section
                                Text(
                                  "Diet Type",
                                  style: TextStyle(
                                    color: AppColor.black,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                Obx(() => Column(
                                      children: dietaryHabitsController
                                          .dietTypeChoices
                                          .map((choice) {
                                        return Padding(
                                          padding: EdgeInsets.only(bottom: 8.h),
                                          child: GestureDetector(
                                            onTap: () => dietaryHabitsController
                                                .setDietType(choice['value']!),
                                            child: Container(
                                              width: double.infinity,
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 12.h,
                                                  horizontal: 16.w),
                                              decoration: BoxDecoration(
                                                color: dietaryHabitsController
                                                            .dietType.value ==
                                                        choice['value']
                                                    ? AppColor.primaryColor
                                                    : Colors.grey[200],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: dietaryHabitsController
                                                              .dietType.value ==
                                                          choice['value']
                                                      ? AppColor.primaryColor
                                                      : Colors.grey[300]!,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    dietaryHabitsController
                                                                .dietType
                                                                .value ==
                                                            choice['value']
                                                        ? Icons
                                                            .radio_button_checked
                                                        : Icons
                                                            .radio_button_unchecked,
                                                    color:
                                                        dietaryHabitsController
                                                                    .dietType
                                                                    .value ==
                                                                choice['value']
                                                            ? Colors.white
                                                            : Colors.grey[600],
                                                    size: 20,
                                                  ),
                                                  SizedBox(width: 12.w),
                                                  Expanded(
                                                    child: Text(
                                                      choice['label']!,
                                                      style: TextStyle(
                                                        color:
                                                            dietaryHabitsController
                                                                        .dietType
                                                                        .value ==
                                                                    choice[
                                                                        'value']
                                                                ? Colors.white
                                                                : AppColor
                                                                    .black,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    )),
                                SizedBox(height: 25.h),

                                // Dietary Restrictions Section
                                Text(
                                  "Dietary Restrictions",
                                  style: TextStyle(
                                    color: AppColor.black,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 5.h),
                                Text(
                                  "e.g., allergies, religious, medical",
                                  style: TextStyle(
                                    color: AppColor.black.withOpacity(0.7),
                                    fontSize: 12.sp,
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                CustomTextFieldNew(
                                  controller: dietaryHabitsController
                                      .dietaryRestrictionsController.value,
                                  labelText:
                                      'Enter any dietary restrictions (optional)',
                                  obscureText: false,
                                  keyboardType: TextInputType.text,
                                  borderRadius: 8,
                                  isLabel: false,
                                  fontColor: AppColor.black,
                                  focusNode: dietaryHabitsController
                                      .dietaryRestrictionsFocusNode.value,
                                  readOnly: false,
                                  maxLines: 3,
                                ),
                                SizedBox(height: 25.h),

                                // Daily Water Intake Section
                                Text(
                                  "Daily Water Intake",
                                  style: TextStyle(
                                    color: AppColor.black,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 5.h),
                                Text(
                                  "Liters per day",
                                  style: TextStyle(
                                    color: AppColor.black.withOpacity(0.7),
                                    fontSize: 12.sp,
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                // it only accepts numbers
                                CustomTextFieldNew(
                                  controller: dietaryHabitsController
                                      .dailyWaterIntakeController.value,
                                  labelText:
                                      'Enter daily water intake in liters',
                                  obscureText: false,
                                  keyboardType: TextInputType.number,
                                  borderRadius: 8,
                                  isLabel: false,
                                  fontColor: AppColor.black,
                                  focusNode: dietaryHabitsController
                                      .dailyWaterIntakeFocusNode.value,
                                  readOnly: false,
                                ),
                                SizedBox(height: 40.h),

                                // Save Button
                                CustomButton(
                                  text: "Save Dietary Habits",
                                  onPressed: () {
                                    dietaryHabitsController.saveDietaryHabits();
                                  },
                                  textColor: Colors.white,
                                  bgColor: AppColor.primaryColor,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Obx(() {
            switch (dietaryHabitsController.requestStatus.value) {
              case Status.COMPLETED:
                return Container();
              case Status.LOADING:
                return Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(child: LoadingIndicator()),
                );
              case Status.ERROR:
                return Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: Text(
                      "Something Went Wrong",
                      style: TextStyle(color: Colors.amber),
                    ),
                  ),
                );
            }
          }),
        ],
      ),
    );
  }
}
