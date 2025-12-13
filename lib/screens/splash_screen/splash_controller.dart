import 'dart:async';
import 'package:get/get.dart';
import 'package:kindura_ai/res/routes/routes_name.dart';
import 'package:kindura_ai/user_preference/user_preferences_view_model.dart';

class SplashServices {
  void isLogin() {
    Timer(const Duration(seconds: 3), () {
      // Get.toNamed(RoutesName.mainScreen);
      // Get.toNamed(RoutesName.loginScreen);
    });
    UserPreferences().getToken().then((value) {
      if (value == null || value.isEmpty) {
        Timer(const Duration(seconds: 3), () {
          Get.toNamed(RoutesName.loginScreen);
        });
      } else {
        Timer(const Duration(seconds: 3), () {
          Get.toNamed(RoutesName.mainScreen);
        });
      }
    });
  }
}
