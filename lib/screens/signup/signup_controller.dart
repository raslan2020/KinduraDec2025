import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/repository/login_repository/login_repository.dart';
import 'package:kindura_ai/res/routes/routes_name.dart';
import 'package:kindura_ai/utils/utils.dart';
import 'package:kindura_ai/user_preference/user_preferences_view_model.dart';

class SignupScreenController extends GetxController {
  final _api = SignupRepository();
  final emailController = TextEditingController().obs;
  final passwordController = TextEditingController().obs;
  final confirmPasswordController = TextEditingController().obs;

  final emailFocusNode = FocusNode().obs;
  final passwordFocusNode = FocusNode().obs;
  final confirmPasswordFocusNode = FocusNode().obs;

  RxString error = ''.obs;
  UserPreferences userPreferences = UserPreferences();
  Rx<Status> requestStatus = Status.LOADING.obs;

  void setRequestStatus(Status value) => requestStatus.value = value;
  void setError(String value) => error.value = value;

  void signupApi() {
    if (!emailController.value.text.contains("@")) {
      Util.Snack_Bar("Warning", "Please Enter Valid Email");
    } else if (passwordController.value.text.isEmpty) {
      Util.Snack_Bar("Warning", "Please Enter Password");
    } else if (confirmPasswordController.value.text.isEmpty) {
      Util.Snack_Bar("Warning", "Please Confirm Password");
    } else if (passwordController.value.text !=
        confirmPasswordController.value.text) {
      Util.Snack_Bar("Warning", "Passwords do not match");
    } else if (passwordController.value.text.length < 6) {
      Util.Snack_Bar("Warning", "Password must be at least 6 characters");
    } else {
      Map data = {
        "email": emailController.value.text,
        "password": passwordController.value.text,
        "confirm_password": confirmPasswordController.value.text,
        "username": emailController.value.text,
      };
      setRequestStatus(Status.COMPLETED);
      _api.signupApi(data).then((value) {
        if (value['status'] == true) {
          String? token = value['result']['token'];
          userPreferences.setToken(token!);
          setRequestStatus(Status.LOADING);
          Get.toNamed(RoutesName.profileScreen,
              arguments: {"screen": "signup"});
        } else {
          Util.Snack_Bar("Warning", value['result']['error']);
          setRequestStatus(Status.LOADING);
        }
      }).onError((error, stackTrace) {
        setRequestStatus(Status.ERROR);
        Util.Snack_Bar("Error", error.toString());
      });
    }
  }
}
