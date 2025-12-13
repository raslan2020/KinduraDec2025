import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/common_widgets/custom_button.dart';
import 'package:kindura_ai/common_widgets/custom_text_field_new.dart';
import 'package:kindura_ai/common_widgets/loading_indicator.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/res/colors/app_color.dart';
import 'package:kindura_ai/screens/signup/signup_controller.dart';

class Signup_Screen extends StatefulWidget {
  const Signup_Screen({super.key});

  @override
  State<Signup_Screen> createState() => _Signup_ScreenState();
}

class _Signup_ScreenState extends State<Signup_Screen> {
  final signup_controller = Get.put(SignupScreenController());
  final _formkey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        body: Stack(
          children: [
            Column(
              children: [
                Container(
                  child: AppBar(
                    title: Center(
                      child: Text("Kindura AI",
                          style: TextStyle(
                            color: AppColor.black,
                          )),
                    ),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    automaticallyImplyLeading: false,
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
                                    text: "Create your ",
                                    style: TextStyle(
                                        color: AppColor.black,
                                        fontSize: 20.sp,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(
                                    text: "Account",
                                    style: TextStyle(
                                        color: AppColor.primaryColor,
                                        fontSize: 20.sp,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 20.h,
                            ),
                            Form(
                                key: _formkey,
                                child: Column(
                                  children: [
                                    Align(
                                      alignment: Alignment.topLeft,
                                      child: Text(
                                        "Enter your email*",
                                        style: TextStyle(
                                            color: AppColor.black,
                                            fontSize: 14.sp,
                                            fontFamily: 'Inter-Medium',
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    SizedBox(height: 8.h),
                                    // Email Field
                                    CustomTextFieldNew(
                                      controller: signup_controller
                                          .emailController.value,
                                      labelText: 'abc@gmail.com',
                                      obscureText: false,
                                      keyboardType: TextInputType.text,
                                      borderRadius: 8,
                                      isLabel: false,
                                      fontColor: AppColor.black,
                                      focusNode: signup_controller
                                          .emailFocusNode.value,
                                      readOnly: false,
                                    ),
                                    SizedBox(
                                      height: 25.h,
                                    ),
                                    Align(
                                      alignment: Alignment.topLeft,
                                      child: Text(
                                        "Enter your password*",
                                        style: TextStyle(
                                            color: AppColor.black,
                                            fontSize: 14.sp,
                                            fontFamily: 'Inter-Medium',
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    SizedBox(height: 8.h),
                                    // Password Field
                                    CustomTextFieldNew(
                                      controller: signup_controller
                                          .passwordController.value,
                                      labelText: '********',
                                      obscureText: true,
                                      keyboardType: TextInputType.text,
                                      borderRadius: 8,
                                      isLabel: false,
                                      fontColor: AppColor.black,
                                      focusNode: signup_controller
                                          .passwordFocusNode.value,
                                      readOnly: false,
                                    ),
                                    SizedBox(height: 25.h),

                                    Align(
                                      alignment: Alignment.topLeft,
                                      child: Text(
                                        "Confirm your password*",
                                        style: TextStyle(
                                            color: AppColor.black,
                                            fontSize: 14.sp,
                                            fontFamily: 'Inter-Medium',
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    SizedBox(height: 8.h),
                                    // Confirm Password Field
                                    CustomTextFieldNew(
                                      controller: signup_controller
                                          .confirmPasswordController.value,
                                      labelText: '********',
                                      obscureText: true,
                                      keyboardType: TextInputType.text,
                                      borderRadius: 8,
                                      isLabel: false,
                                      fontColor: AppColor.black,
                                      focusNode: signup_controller
                                          .confirmPasswordFocusNode.value,
                                      readOnly: false,
                                    ),
                                  ],
                                )),
                            SizedBox(
                              height: 25.h,
                            ),
                            CustomButton(
                              text: "Sign Up",
                              textColor: AppColor.black,
                              bgColor: AppColor.buttonColor,
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                signup_controller.signupApi();
                              },
                            ),
                            SizedBox(
                              height: 20.h,
                            ),
                            GestureDetector(
                              onTap: () {
                                Get.back();
                              },
                              child: Center(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: "Already have an account? ",
                                        style: TextStyle(
                                            color: AppColor.black,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      TextSpan(
                                        text: "Login",
                                        style: TextStyle(
                                            color: AppColor.primaryColor,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 20.h,
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
              switch (signup_controller.requestStatus.value) {
                case Status.LOADING:
                  return Container();
                case Status.COMPLETED:
                  return Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(child: LoadingIndicator()),
                  );
                case Status.ERROR:
                  return Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: Text(
                        "error",
                        style: TextStyle(color: Colors.amber),
                      ),
                    ),
                  );
              }
            }),
          ],
        ),
      ),
    );
  }
}
