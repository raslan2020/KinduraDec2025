import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/data/app_exceptions.dart';
import 'package:kindura_ai/repository/login_repository/login_repository.dart';
import 'package:kindura_ai/res/routes/routes_name.dart';
import 'package:kindura_ai/utils/utils.dart';
import 'package:kindura_ai/user_preference/user_preferences_view_model.dart';

/// LoginScreenController handles user authentication.
///
/// Features:
/// - Email/password validation
/// - Network error handling with user-friendly messages
/// - Loading state management
class LoginScreenController extends GetxController {
  final _api = LoginRepository();
  final emailController = TextEditingController().obs;
  final passwordController = TextEditingController().obs;

  final emailFocusNode = FocusNode().obs;
  final passwordFocusNode = FocusNode().obs;
  RxString error = ''.obs;
  UserPreferences userPreferences = UserPreferences();
  Rx<Status> requestStatus = Status.COMPLETED.obs;

  void setRequestStatus(Status value) => requestStatus.value = value;
  void setError(String value) => error.value = value;

  /// Perform login with proper error handling
  void loginApi() {
    // Validate email
    final email = emailController.value.text.trim();
    if (email.isEmpty || !email.contains("@")) {
      Util.Snack_Bar("Warning", "Please enter a valid email");
      return;
    }

    // Validate password
    final password = passwordController.value.text;
    if (password.isEmpty) {
      Util.Snack_Bar("Warning", "Please enter your password");
      return;
    }

    // Start login request
    setRequestStatus(Status.LOADING);
    setError('');

    final data = {
      "email": email,
      "password": password,
    };

    _api.loginApi(data).then((value) {
      setRequestStatus(Status.COMPLETED);

      if (value == null) {
        Util.Snack_Bar("Error", "Unable to connect to server. Please check your internet connection.");
        return;
      }

      if (value['status'] == true) {
        final token = value['result']?['token'];
        if (token != null && token.isNotEmpty) {
          userPreferences.setToken(token);
          print('[LoginController] Login successful, navigating to main screen');
          Get.offAllNamed(RoutesName.mainScreen);
        } else {
          Util.Snack_Bar("Error", "Invalid server response. Please try again.");
        }
      } else {
        // Handle API error response
        final errorMessage = value['result']?['error'] ??
                            value['message'] ??
                            'Login failed. Please try again.';
        Util.Snack_Bar("Warning", errorMessage);
      }
    }).catchError((error) {
      setRequestStatus(Status.COMPLETED);

      // Provide user-friendly error messages based on error type
      String errorMessage;
      if (error is SocketException || error is InternetException) {
        errorMessage = "No internet connection. Please check your network and try again.";
      } else if (error is RequestTimeOut) {
        errorMessage = "Connection timed out. Please try again.";
      } else if (error.toString().contains('SocketException') ||
                 error.toString().contains('Connection refused')) {
        errorMessage = "Unable to reach server. Please check your connection.";
      } else {
        errorMessage = "Login failed. Please try again.";
        print('[LoginController] Login error: $error');
      }

      Util.Snack_Bar("Error", errorMessage);
    });
  }

  @override
  void onClose() {
    emailController.value.dispose();
    passwordController.value.dispose();
    emailFocusNode.value.dispose();
    passwordFocusNode.value.dispose();
    super.onClose();
  }
}
