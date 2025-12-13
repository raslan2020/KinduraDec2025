import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/common_widgets/custom_button.dart';
import 'package:kindura_ai/common_widgets/loading_indicator.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/res/colors/app_color.dart';
import 'package:kindura_ai/screens/lifestyle_habits/lifestyle_habits_controller.dart';

class LifestyleHabitsScreen extends StatefulWidget {
  const LifestyleHabitsScreen({super.key});

  @override
  State<LifestyleHabitsScreen> createState() => _LifestyleHabitsScreenState();
}

class _LifestyleHabitsScreenState extends State<LifestyleHabitsScreen> {
  final lifestyleHabitsController = Get.put(LifestyleHabitsController());
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
                  "Lifestyle Habits",
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
                                  text: "Lifestyle Habits",
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
                            "Help us understand your daily habits for better health insights",
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
                                // Smoking Section
                                Text(
                                  "Smoking",
                                  style: TextStyle(
                                    color: AppColor.black,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                Obx(() => Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () =>
                                                lifestyleHabitsController
                                                    .setSmoking(true),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 12.h),
                                              decoration: BoxDecoration(
                                                color: lifestyleHabitsController
                                                        .smoking.value
                                                    ? AppColor.primaryColor
                                                    : Colors.grey[200],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color:
                                                      lifestyleHabitsController
                                                              .smoking.value
                                                          ? AppColor
                                                              .primaryColor
                                                          : Colors.grey[300]!,
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  "Yes",
                                                  style: TextStyle(
                                                    color:
                                                        lifestyleHabitsController
                                                                .smoking.value
                                                            ? Colors.white
                                                            : AppColor.black,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 10.w),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () =>
                                                lifestyleHabitsController
                                                    .setSmoking(false),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 12.h),
                                              decoration: BoxDecoration(
                                                color:
                                                    !lifestyleHabitsController
                                                            .smoking.value
                                                        ? AppColor.primaryColor
                                                        : Colors.grey[200],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color:
                                                      !lifestyleHabitsController
                                                              .smoking.value
                                                          ? AppColor
                                                              .primaryColor
                                                          : Colors.grey[300]!,
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  "No",
                                                  style: TextStyle(
                                                    color:
                                                        !lifestyleHabitsController
                                                                .smoking.value
                                                            ? Colors.white
                                                            : AppColor.black,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )),
                                SizedBox(height: 25.h),

                                // Alcohol Consumption Section
                                Text(
                                  "Alcohol Consumption",
                                  style: TextStyle(
                                    color: AppColor.black,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                Obx(() => Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () =>
                                                lifestyleHabitsController
                                                    .setDrinkAlcohol(true),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 12.h),
                                              decoration: BoxDecoration(
                                                color: lifestyleHabitsController
                                                        .drinkAlcohol.value
                                                    ? AppColor.primaryColor
                                                    : Colors.grey[200],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color:
                                                      lifestyleHabitsController
                                                              .drinkAlcohol
                                                              .value
                                                          ? AppColor
                                                              .primaryColor
                                                          : Colors.grey[300]!,
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  "Yes",
                                                  style: TextStyle(
                                                    color:
                                                        lifestyleHabitsController
                                                                .drinkAlcohol
                                                                .value
                                                            ? Colors.white
                                                            : AppColor.black,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 10.w),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () =>
                                                lifestyleHabitsController
                                                    .setDrinkAlcohol(false),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 12.h),
                                              decoration: BoxDecoration(
                                                color:
                                                    !lifestyleHabitsController
                                                            .drinkAlcohol.value
                                                        ? AppColor.primaryColor
                                                        : Colors.grey[200],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color:
                                                      !lifestyleHabitsController
                                                              .drinkAlcohol
                                                              .value
                                                          ? AppColor
                                                              .primaryColor
                                                          : Colors.grey[300]!,
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  "No",
                                                  style: TextStyle(
                                                    color:
                                                        !lifestyleHabitsController
                                                                .drinkAlcohol
                                                                .value
                                                            ? Colors.white
                                                            : AppColor.black,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )),
                                SizedBox(height: 25.h),

                                // Caffeine Intake Section
                                Text(
                                  "Caffeine Intake",
                                  style: TextStyle(
                                    color: AppColor.black,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 5.h),
                                Text(
                                  "Cups of tea/coffee/energy drinks per day",
                                  style: TextStyle(
                                    color: AppColor.black.withOpacity(0.7),
                                    fontSize: 12.sp,
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                Obx(() => Row(
                                      children: [
                                        IconButton(
                                          onPressed: () {
                                            if (lifestyleHabitsController
                                                    .caffeineIntake.value >
                                                0) {
                                              lifestyleHabitsController
                                                  .setCaffeineIntake(
                                                      lifestyleHabitsController
                                                              .caffeineIntake
                                                              .value -
                                                          1);
                                            }
                                          },
                                          icon: Icon(
                                              Icons.remove_circle_outline,
                                              color: AppColor.primaryColor),
                                        ),
                                        Expanded(
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 12.h),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: Colors.grey[300]!),
                                            ),
                                            child: Center(
                                              child: Text(
                                                "${lifestyleHabitsController.caffeineIntake.value}",
                                                style: TextStyle(
                                                  color: AppColor.black,
                                                  fontSize: 18.sp,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () {
                                            if (lifestyleHabitsController
                                                    .caffeineIntake.value <
                                                20) {
                                              lifestyleHabitsController
                                                  .setCaffeineIntake(
                                                      lifestyleHabitsController
                                                              .caffeineIntake
                                                              .value +
                                                          1);
                                            }
                                          },
                                          icon: Icon(Icons.add_circle_outline,
                                              color: AppColor.primaryColor),
                                        ),
                                      ],
                                    )),
                                SizedBox(height: 40.h),

                                // Save Button
                                CustomButton(
                                  text: "Save Lifestyle Habits",
                                  onPressed: () {
                                    lifestyleHabitsController
                                        .saveLifestyleHabits();
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
            switch (lifestyleHabitsController.requestStatus.value) {
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
