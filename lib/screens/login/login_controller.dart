import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/repository/login_repository/login_repository.dart';
import 'package:kindura_ai/res/routes/routes_name.dart';
import 'package:kindura_ai/utils/utils.dart';
import 'package:kindura_ai/user_preference/user_preferences_view_model.dart';

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

  void loginApi() {
    if (!emailController.value.text.contains("@")) {
      Util.Snack_Bar("Warning", "Please Enter Valid Email");
    } else if (passwordController.value.text.isEmpty) {
      Util.Snack_Bar("Warning", "Please Enter Password");
    } else {
      setRequestStatus(Status.LOADING);
      Map data = {
        "email": emailController.value.text,
        "password": passwordController.value.text,
      };
      _api.loginApi(data).then((value) {
        if (value['status'] == true) {
          String? token = value['result']['token'];
          userPreferences.setToken(token!);
          Get.toNamed(RoutesName.mainScreen);
        } else {
          Util.Snack_Bar("Warning", value['result']['error']);
        }
        setRequestStatus(Status.COMPLETED);
      }).catchError((error) {
        setRequestStatus(Status.COMPLETED);
        Util.Snack_Bar("Error", "Login failed: ${error.toString()}");
      });
    }
  }
}
