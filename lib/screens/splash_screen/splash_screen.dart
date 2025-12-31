import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kindura_ai/screens/splash_screen/splash_controller.dart';

/// SplashScreen - Initial loading screen shown on app startup.
///
/// Features:
/// - Shows app branding while checking login status
/// - Has loading indicator to show activity
/// - Handles all errors gracefully - never gets stuck
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final SplashServices _splashServices = SplashServices();
  String _statusMessage = 'Starting...';

  @override
  void initState() {
    super.initState();
    _startApp();
  }

  void _startApp() {
    setState(() {
      _statusMessage = 'Checking login status...';
    });

    // Start the login check - this will handle all errors internally
    try {
      _splashServices.isLogin();
    } catch (e) {
      print('[SplashScreen] Error starting app: $e');
      setState(() {
        _statusMessage = 'Starting app...';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo/Name
              Text(
                "Kindura AI",
                style: TextStyle(
                  fontSize: 32.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2563EB), // Primary blue
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                "Your Health Companion",
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 40.h),

              // Loading indicator
              const CircularProgressIndicator(
                color: Color(0xFF2563EB),
                strokeWidth: 3,
              ),
              SizedBox(height: 16.h),

              // Status message
              Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
