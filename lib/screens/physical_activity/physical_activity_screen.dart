import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/common_widgets/custom_button.dart';
import 'package:kindura_ai/common_widgets/custom_text_field_new.dart';
import 'package:kindura_ai/common_widgets/loading_indicator.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/res/colors/app_color.dart';
import 'package:kindura_ai/screens/physical_activity/physical_activity_controller.dart';

class PhysicalActivityScreen extends StatefulWidget {
  const PhysicalActivityScreen({super.key});

  @override
  State<PhysicalActivityScreen> createState() => _PhysicalActivityScreenState();
}

class _PhysicalActivityScreenState extends State<PhysicalActivityScreen> {
  final physicalActivityController = Get.put(PhysicalActivityController());
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
                  "Physical Activity",
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
                                  text: "Physical Activity",
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
                            "Tell us about your exercise routine and physical activities",
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
                                // Exercise Frequency Section
                                Text(
                                  "Exercise Frequency",
                                  style: TextStyle(
                                    color: AppColor.black,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                Obx(() => Column(
                                      children: physicalActivityController
                                          .exerciseFrequencyChoices
                                          .map((choice) {
                                        return Padding(
                                          padding: EdgeInsets.only(bottom: 8.h),
                                          child: GestureDetector(
                                            onTap: () =>
                                                physicalActivityController
                                                    .setExerciseFrequency(
                                                        choice['value']!),
                                            child: Container(
                                              width: double.infinity,
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 12.h,
                                                  horizontal: 16.w),
                                              decoration: BoxDecoration(
                                                color: physicalActivityController
                                                            .exerciseFrequency
                                                            .value ==
                                                        choice['value']
                                                    ? AppColor.primaryColor
                                                    : Colors.grey[200],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: physicalActivityController
                                                              .exerciseFrequency
                                                              .value ==
                                                          choice['value']
                                                      ? AppColor.primaryColor
                                                      : Colors.grey[300]!,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    physicalActivityController
                                                                .exerciseFrequency
                                                                .value ==
                                                            choice['value']
                                                        ? Icons
                                                            .radio_button_checked
                                                        : Icons
                                                            .radio_button_unchecked,
                                                    color: physicalActivityController
                                                                .exerciseFrequency
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
                                                        color: physicalActivityController
                                                                    .exerciseFrequency
                                                                    .value ==
                                                                choice['value']
                                                            ? Colors.white
                                                            : AppColor.black,
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

                                // Exercise Type Section (only show if not 'never')
                                Obx(() {
                                  if (physicalActivityController
                                          .exerciseFrequency.value ==
                                      'never') {
                                    return Container();
                                  }
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Type of Exercise",
                                        style: TextStyle(
                                          color: AppColor.black,
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 5.h),
                                      Text(
                                        "e.g., walking, running, gym, yoga",
                                        style: TextStyle(
                                          color:
                                              AppColor.black.withOpacity(0.7),
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                      SizedBox(height: 10.h),
                                      CustomTextFieldNew(
                                        controller: physicalActivityController
                                            .exerciseTypeController.value,
                                        labelText: 'Enter your exercise type',
                                        obscureText: false,
                                        keyboardType: TextInputType.text,
                                        borderRadius: 8,
                                        isLabel: false,
                                        fontColor: AppColor.black,
                                        focusNode: physicalActivityController
                                            .exerciseTypeFocusNode.value,
                                        readOnly: false,
                                      ),
                                      SizedBox(height: 25.h),
                                    ],
                                  );
                                }),

                                // Average Duration Section (only show if not 'never')
                                Obx(() {
                                  if (physicalActivityController
                                          .exerciseFrequency.value ==
                                      'never') {
                                    return Container();
                                  }
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Average Duration",
                                        style: TextStyle(
                                          color: AppColor.black,
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 5.h),
                                      Text(
                                        "Duration in minutes",
                                        style: TextStyle(
                                          color:
                                              AppColor.black.withOpacity(0.7),
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                      SizedBox(height: 10.h),
                                      CustomTextFieldNew(
                                        controller: physicalActivityController
                                            .averageDurationController.value,
                                        labelText: 'Enter duration in minutes',
                                        obscureText: false,
                                        keyboardType: TextInputType.number,
                                        borderRadius: 8,
                                        isLabel: false,
                                        fontColor: AppColor.black,
                                        focusNode: physicalActivityController
                                            .averageDurationFocusNode.value,
                                        readOnly: false,
                                        maxLength: 3,
                                      ),
                                      SizedBox(height: 25.h),
                                    ],
                                  );
                                }),

                                // Save Button
                                CustomButton(
                                  text: "Save Physical Activity",
                                  onPressed: () {
                                    physicalActivityController
                                        .savePhysicalActivity();
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
            switch (physicalActivityController.requestStatus.value) {
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
