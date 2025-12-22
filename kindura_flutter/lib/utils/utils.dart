import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/route_manager.dart';

import '../res/colors/app_color.dart';

class Util {
  static double button_height = 45.h;
  static double text_field_height = 60.h;

  static void fieldFocusChange(
      BuildContext context, FocusNode current, FocusNode nextFocus) {
    current.unfocus();
    FocusScope.of(context).requestFocus(nextFocus);
  }

  static toast_message(String message) {
    Fluttertoast.showToast(msg: message, backgroundColor: AppColor.buttonColor);
  }

  static Snack_Bar(String title, String message) {
    Get.snackbar(
      title,
      message,
      backgroundColor: Colors.transparent,
      duration: Duration(seconds: 5),
      forwardAnimationCurve: Curves.bounceInOut,
      // overlayBlur: 5,
      reverseAnimationCurve: Curves.bounceInOut,
      titleText: Text(
        title,
        style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
        // Increase the font size here
      ),
      messageText: Text(
        message,
        style: TextStyle(fontSize: 15.sp), // Increase the font size here
      ),
    );
  }
}
