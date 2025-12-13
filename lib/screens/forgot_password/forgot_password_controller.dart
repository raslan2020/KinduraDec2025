import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/data/network/network_api_services.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/res/app_url/app_url.dart';
import 'package:kindura_ai/res/routes/routes_name.dart';

class ForgotPasswordController extends GetxController {
  final emailController = TextEditingController().obs;
  final codeController = TextEditingController().obs;
  final newPasswordController = TextEditingController().obs;
  final confirmPasswordController = TextEditingController().obs;

  final emailFocusNode = FocusNode().obs;
  final codeFocusNode = FocusNode().obs;
  final newPasswordFocusNode = FocusNode().obs;
  final confirmPasswordFocusNode = FocusNode().obs;

  final requestStatus = Status.COMPLETED.obs;
  final currentStep = 0.obs; // 0: email, 1: code, 2: new password

  final _apiServices = NetworkApiServices();

  Future<void> requestResetCode() async {
    final email = emailController.value.text.trim();

    if (email.isEmpty) {
      Get.snackbar('Error', 'Please enter your email',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    if (!GetUtils.isEmail(email)) {
      Get.snackbar('Error', 'Please enter a valid email',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    requestStatus.value = Status.LOADING;

    try {
      final response = await _apiServices.postApi(
        {'email': email},
        AppUrl.forgotPasswordUrl,
        requireAuth: false,
      );

      requestStatus.value = Status.COMPLETED;

      if (response['status'] == true) {
        currentStep.value = 1;
        Get.snackbar('Success', 'Reset code sent to your email',
            backgroundColor: Colors.green, colorText: Colors.white);
      } else {
        Get.snackbar('Error', response['message'] ?? 'Failed to send reset code',
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      requestStatus.value = Status.COMPLETED;
      Get.snackbar('Error', e.toString(),
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> verifyCode() async {
    final email = emailController.value.text.trim();
    final code = codeController.value.text.trim();

    if (code.isEmpty || code.length != 6) {
      Get.snackbar('Error', 'Please enter the 6-digit code',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    requestStatus.value = Status.LOADING;

    try {
      final response = await _apiServices.postApi(
        {'email': email, 'code': code},
        AppUrl.verifyResetCodeUrl,
        requireAuth: false,
      );

      requestStatus.value = Status.COMPLETED;

      if (response['status'] == true) {
        currentStep.value = 2;
        Get.snackbar('Success', 'Code verified successfully',
            backgroundColor: Colors.green, colorText: Colors.white);
      } else {
        Get.snackbar('Error', response['message'] ?? 'Invalid code',
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      requestStatus.value = Status.COMPLETED;
      Get.snackbar('Error', e.toString(),
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> resetPassword() async {
    final email = emailController.value.text.trim();
    final code = codeController.value.text.trim();
    final newPassword = newPasswordController.value.text;
    final confirmPassword = confirmPasswordController.value.text;

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      Get.snackbar('Error', 'Please fill in all fields',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    if (newPassword.length < 8) {
      Get.snackbar('Error', 'Password must be at least 8 characters',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    if (newPassword != confirmPassword) {
      Get.snackbar('Error', 'Passwords do not match',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    requestStatus.value = Status.LOADING;

    try {
      final response = await _apiServices.postApi(
        {
          'email': email,
          'code': code,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        },
        AppUrl.resetPasswordUrl,
        requireAuth: false,
      );

      requestStatus.value = Status.COMPLETED;

      if (response['status'] == true) {
        Get.snackbar('Success', 'Password reset successfully',
            backgroundColor: Colors.green, colorText: Colors.white);
        Get.offAllNamed(RoutesName.loginScreen);
      } else {
        Get.snackbar('Error', response['message'] ?? 'Failed to reset password',
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      requestStatus.value = Status.COMPLETED;
      Get.snackbar('Error', e.toString(),
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  @override
  void onClose() {
    emailController.value.dispose();
    codeController.value.dispose();
    newPasswordController.value.dispose();
    confirmPasswordController.value.dispose();
    emailFocusNode.value.dispose();
    codeFocusNode.value.dispose();
    newPasswordFocusNode.value.dispose();
    confirmPasswordFocusNode.value.dispose();
    super.onClose();
  }
}
