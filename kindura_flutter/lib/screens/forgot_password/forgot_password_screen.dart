import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/common_widgets/custom_button.dart';
import 'package:kindura_ai/common_widgets/custom_text_field_new.dart';
import 'package:kindura_ai/common_widgets/loading_indicator.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/res/colors/app_color.dart';
import 'package:kindura_ai/screens/forgot_password/forgot_password_controller.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final controller = Get.put(ForgotPasswordController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Forgot Password",
          style: TextStyle(color: AppColor.black),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColor.black),
          onPressed: () => Get.back(),
        ),
      ),
      body: Stack(
        children: [
          Obx(() => _buildStepContent()),
          Obx(() {
            if (controller.requestStatus.value == Status.LOADING) {
              return Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(child: LoadingIndicator()),
              );
            }
            return SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (controller.currentStep.value) {
      case 0:
        return _buildEmailStep();
      case 1:
        return _buildCodeStep();
      case 2:
        return _buildNewPasswordStep();
      default:
        return _buildEmailStep();
    }
  }

  Widget _buildEmailStep() {
    return ListView(
      padding: EdgeInsets.all(20),
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: "Reset your ",
                style: TextStyle(
                  color: AppColor.black,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: "Password",
                style: TextStyle(
                  color: AppColor.primaryColor,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 10.h),
        Text(
          "Enter your email address and we'll send you a code to reset your password.",
          style: TextStyle(
            color: AppColor.textSecondary,
            fontSize: 14.sp,
          ),
        ),
        SizedBox(height: 30.h),
        Align(
          alignment: Alignment.topLeft,
          child: Text(
            "Enter your email*",
            style: TextStyle(
              color: AppColor.black,
              fontSize: 14.sp,
              fontFamily: 'Inter-Medium',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(height: 8.h),
        CustomTextFieldNew(
          controller: controller.emailController.value,
          labelText: 'abc@gmail.com',
          obscureText: false,
          keyboardType: TextInputType.emailAddress,
          borderRadius: 8,
          isLabel: false,
          fontColor: AppColor.black,
          focusNode: controller.emailFocusNode.value,
          readOnly: false,
        ),
        SizedBox(height: 30.h),
        CustomButton(
          text: "Send Reset Code",
          textColor: AppColor.black,
          bgColor: AppColor.buttonColor,
          onPressed: () {
            FocusScope.of(context).unfocus();
            controller.requestResetCode();
          },
        ),
      ],
    );
  }

  Widget _buildCodeStep() {
    return ListView(
      padding: EdgeInsets.all(20),
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: "Enter ",
                style: TextStyle(
                  color: AppColor.black,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: "Code",
                style: TextStyle(
                  color: AppColor.primaryColor,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 10.h),
        Text(
          "We've sent a 6-digit code to your email. Please enter it below.",
          style: TextStyle(
            color: AppColor.textSecondary,
            fontSize: 14.sp,
          ),
        ),
        SizedBox(height: 30.h),
        Align(
          alignment: Alignment.topLeft,
          child: Text(
            "Enter 6-digit code*",
            style: TextStyle(
              color: AppColor.black,
              fontSize: 14.sp,
              fontFamily: 'Inter-Medium',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(height: 8.h),
        CustomTextFieldNew(
          controller: controller.codeController.value,
          labelText: '000000',
          obscureText: false,
          keyboardType: TextInputType.number,
          borderRadius: 8,
          isLabel: false,
          fontColor: AppColor.black,
          focusNode: controller.codeFocusNode.value,
          readOnly: false,
        ),
        SizedBox(height: 30.h),
        CustomButton(
          text: "Verify Code",
          textColor: AppColor.black,
          bgColor: AppColor.buttonColor,
          onPressed: () {
            FocusScope.of(context).unfocus();
            controller.verifyCode();
          },
        ),
        SizedBox(height: 20.h),
        GestureDetector(
          onTap: () => controller.requestResetCode(),
          child: Center(
            child: Text(
              "Resend Code",
              style: TextStyle(
                color: AppColor.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewPasswordStep() {
    return ListView(
      padding: EdgeInsets.all(20),
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: "Create New ",
                style: TextStyle(
                  color: AppColor.black,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: "Password",
                style: TextStyle(
                  color: AppColor.primaryColor,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 10.h),
        Text(
          "Your new password must be at least 8 characters long.",
          style: TextStyle(
            color: AppColor.textSecondary,
            fontSize: 14.sp,
          ),
        ),
        SizedBox(height: 30.h),
        Align(
          alignment: Alignment.topLeft,
          child: Text(
            "New Password*",
            style: TextStyle(
              color: AppColor.black,
              fontSize: 14.sp,
              fontFamily: 'Inter-Medium',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(height: 8.h),
        CustomTextFieldNew(
          controller: controller.newPasswordController.value,
          labelText: '********',
          obscureText: true,
          keyboardType: TextInputType.text,
          borderRadius: 8,
          isLabel: false,
          fontColor: AppColor.black,
          focusNode: controller.newPasswordFocusNode.value,
          readOnly: false,
        ),
        SizedBox(height: 20.h),
        Align(
          alignment: Alignment.topLeft,
          child: Text(
            "Confirm Password*",
            style: TextStyle(
              color: AppColor.black,
              fontSize: 14.sp,
              fontFamily: 'Inter-Medium',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(height: 8.h),
        CustomTextFieldNew(
          controller: controller.confirmPasswordController.value,
          labelText: '********',
          obscureText: true,
          keyboardType: TextInputType.text,
          borderRadius: 8,
          isLabel: false,
          fontColor: AppColor.black,
          focusNode: controller.confirmPasswordFocusNode.value,
          readOnly: false,
        ),
        SizedBox(height: 30.h),
        CustomButton(
          text: "Reset Password",
          textColor: AppColor.black,
          bgColor: AppColor.buttonColor,
          onPressed: () {
            FocusScope.of(context).unfocus();
            controller.resetPassword();
          },
        ),
      ],
    );
  }
}
