import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:get/get.dart';
import 'package:kindura_ai/common_widgets/custom_button.dart';
import 'package:kindura_ai/common_widgets/custom_text_field_new.dart';
import 'package:kindura_ai/common_widgets/loading_indicator.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/res/colors/app_color.dart';
import 'package:kindura_ai/res/routes/routes_name.dart';
import 'package:kindura_ai/screens/login/login_controller.dart';

class Login_Screen extends StatefulWidget {
  const Login_Screen({super.key});

  @override
  State<Login_Screen> createState() => _Login_ScreenState();
}

class _Login_ScreenState extends State<Login_Screen> {
  final login_controller = Get.put(LoginScreenController());
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
            // Container(
            //   height: Get.height * 0.7,
            //   decoration: BoxDecoration(
            //     image: DecorationImage(
            //       image: AssetImage(ImageConstant.imageFullVector1),
            //       fit: BoxFit.fill,
            //     ),
            //   ),
            // ),
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
                                    text: "Login to your ",
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
                                    CustomTextFieldNew(
                                      controller: login_controller
                                          .emailController.value,
                                      labelText: 'abc@gmail.com',
                                      obscureText: false,
                                      keyboardType: TextInputType.text,
                                      borderRadius: 8,
                                      isLabel: false,
                                      fontColor: AppColor.black,
                                      focusNode:
                                          login_controller.emailFocusNode.value,
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
                                    CustomTextFieldNew(
                                      controller: login_controller
                                          .passwordController.value,
                                      labelText: '********',
                                      obscureText: true,
                                      keyboardType: TextInputType.text,
                                      borderRadius: 8,
                                      isLabel: false,
                                      fontColor: AppColor.black,
                                      focusNode: login_controller
                                          .passwordFocusNode.value,
                                      readOnly: false,
                                    ),
                                  ],
                                )),
                            SizedBox(height: 10.h),
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () {
                                  Get.toNamed(RoutesName.forgotPasswordScreen);
                                },
                                child: Text(
                                  "Forgot Password?",
                                  style: TextStyle(
                                    color: AppColor.primaryColor,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 25.h,
                            ),
                            CustomButton(
                              text: "Login",
                              textColor: AppColor.black,
                              bgColor: AppColor.buttonColor,
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                login_controller.loginApi();
                              },
                            ),
                            SizedBox(
                              height: 20.h,
                            ),
                            GestureDetector(
                              onTap: () {
                                Get.toNamed(RoutesName.signupScreen);
                              },
                              child: Center(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: "Don't have account? ",
                                        style: TextStyle(
                                            color: AppColor.black,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      TextSpan(
                                        text: "Register",
                                        style: TextStyle(
                                            color: AppColor.buttonColor,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Obx(() {
              switch (login_controller.requestStatus.value) {
                case Status.COMPLETED:
                  return Container();
                case Status.LOADING:
                  return Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: LoadingIndicator(),
                    ),
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
