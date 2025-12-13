import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';

class AppToast {
  static void showToast(String message, {
    Toast length = Toast.LENGTH_SHORT,
    ToastGravity gravity = ToastGravity.BOTTOM,
    Color backgroundColor = const Color(0xFF323232),
    Color textColor = Colors.white,
    double fontSize = 14.0,
  }) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: length,
      gravity: gravity,
      backgroundColor: backgroundColor,
      textColor: textColor,
      fontSize: fontSize,
    );
  }

  static void showSuccess(String message) {
    showToast(
      message,
      backgroundColor: Colors.green.shade600,
      textColor: Colors.white,
    );
  }

  static void showError(String message) {
    showToast(
      message,
      backgroundColor: Colors.red.shade600,
      textColor: Colors.white,
    );
  }

  static void showWarning(String message) {
    showToast(
      message,
      backgroundColor: Colors.orange.shade600,
      textColor: Colors.white,
    );
  }

  static void showInfo(String message) {
    showToast(
      message,
      backgroundColor: Colors.blue.shade600,
      textColor: Colors.white,
    );
  }
}