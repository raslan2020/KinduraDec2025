import 'dart:async';
import 'package:get/get.dart';
import 'package:kindura_ai/res/routes/routes_name.dart';
import 'package:kindura_ai/user_preference/user_preferences_view_model.dart';

/// SplashServices handles the initial app startup flow.
///
/// It checks if the user is logged in and navigates to the appropriate screen.
/// All operations are wrapped in try-catch to prevent app crashes.
class SplashServices {
  static const int _splashDuration = 2; // seconds
  bool _hasNavigated = false;

  /// Check if user is logged in and navigate accordingly.
  /// This method is resilient to errors - it will always navigate somewhere.
  void isLogin() {
    // Safety timeout - navigate to login if nothing happens in 5 seconds
    _startSafetyTimeout();

    // Try to check login status
    _checkLoginStatus();
  }

  /// Safety timeout ensures app never gets stuck on splash screen
  void _startSafetyTimeout() {
    Timer(const Duration(seconds: 5), () {
      if (!_hasNavigated) {
        print('[SplashServices] Safety timeout - navigating to login');
        _navigateTo(RoutesName.loginScreen);
      }
    });
  }

  /// Check login status with proper error handling
  void _checkLoginStatus() {
    try {
      UserPreferences().getToken().then((value) {
        Timer(Duration(seconds: _splashDuration), () {
          if (_hasNavigated) return; // Prevent double navigation

          if (value != null && value.isNotEmpty) {
            print('[SplashServices] Token found - navigating to main screen');
            _navigateTo(RoutesName.mainScreen);
          } else {
            print('[SplashServices] No token - navigating to login screen');
            _navigateTo(RoutesName.loginScreen);
          }
        });
      }).catchError((error) {
        print('[SplashServices] Error checking token: $error');
        Timer(Duration(seconds: _splashDuration), () {
          _navigateTo(RoutesName.loginScreen);
        });
      });
    } catch (e) {
      print('[SplashServices] Exception in checkLoginStatus: $e');
      Timer(Duration(seconds: _splashDuration), () {
        _navigateTo(RoutesName.loginScreen);
      });
    }
  }

  /// Safe navigation that prevents double navigation
  void _navigateTo(String routeName) {
    if (_hasNavigated) return;
    _hasNavigated = true;

    try {
      Get.offAllNamed(routeName);
    } catch (e) {
      print('[SplashServices] Navigation error: $e');
      // Last resort - try direct navigation
      try {
        Get.toNamed(routeName);
      } catch (e2) {
        print('[SplashServices] Critical navigation error: $e2');
      }
    }
  }
}
