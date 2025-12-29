/// ============================================================================
/// KINDURA AI - MAIN ENTRY POINT
/// ============================================================================
/// This is the main entry point for the Kindura AI Flutter application.
///
/// The app follows the MVVM pattern with GetX for state management:
/// - Screens (Views): UI components in /lib/screens/
/// - Controllers (ViewModels): Business logic with GetxController
/// - Models: Data classes in /lib/models/
/// - Repositories: Data access layer in /lib/repository/
///
/// Key Architecture Components:
/// 1. GetX - State management, dependency injection, routing
/// 2. ScreenUtil - Responsive design across device sizes
/// 3. LiveKit - Real-time voice communication with AI agent
/// 4. Token-based Auth - REST API authentication
///
/// @see /docs/DEVELOPER_GUIDE.md for full documentation
/// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/res/routes/routes.dart';
import 'package:kindura_ai/screens/splash_screen/splash_screen.dart';
import 'package:kindura_ai/screens/home/home_controller.dart';
import 'package:kindura_ai/services/notification_service.dart';
import 'package:kindura_ai/services/voice_service.dart';
import 'package:kindura_ai/services/theme_service.dart';
import 'package:kindura_ai/utils/file_logger.dart';

/// Application entry point.
///
/// Initialization sequence:
/// 1. Flutter bindings initialization (required for async operations before runApp)
/// 2. File logger setup for debugging
/// 3. Core services registration with GetX DI (permanent: true means singleton)
/// 4. Launch the app with MyApp widget
void main() async {
  // Required for async operations before runApp()
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize file logger for debugging and error tracking
  // Logs are stored in the app's documents directory
  try {
    await FileLogger.initialize();
    await FileLogger.logAppLifecycle('App Started');
  } catch (e) {
    print('FileLogger initialization failed: $e');
  }

  // =========================================================================
  // DEPENDENCY INJECTION - WITH ERROR HANDLING
  // =========================================================================
  // Register core services as singletons using GetX.
  // permanent: true ensures they persist throughout app lifecycle.
  //
  // Each service is wrapped in try-catch to prevent app crashes
  // =========================================================================

  // ThemeService: Manages dark/light mode switching
  try {
    Get.put(ThemeService(), permanent: true);
  } catch (e) {
    print('ThemeService initialization failed: $e');
  }

  // NotificationService: Handles local push notifications for medication reminders
  try {
    Get.put(NotificationService(), permanent: true);
  } catch (e) {
    print('NotificationService initialization failed: $e');
  }

  // VoiceService: Manages speech recognition for "Hey Kindura" trigger
  try {
    Get.put(VoiceService(), permanent: true);
  } catch (e) {
    print('VoiceService initialization failed: $e');
  }

  // HomeController: Central controller for dashboard and LiveKit voice connection
  // Registered early because the mic button in bottom navigation needs it
  // This controller now handles backend connection failures gracefully
  try {
    Get.put(HomeController(), permanent: true);
  } catch (e) {
    print('HomeController initialization failed: $e');
  }

  runApp(const MyApp());
}

/// Root application widget.
///
/// Configures:
/// - ScreenUtil for responsive design (design size: 375x812 = iPhone X)
/// - GetMaterialApp for routing and navigation
/// - Theme configuration (light/dark mode support)
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ScreenUtilInit adapts UI to different screen sizes
    // designSize is the reference size from the UI design (iPhone X dimensions)
    return ScreenUtilInit(
      builder: (BuildContext context, Widget? widget) {
        // GetMaterialApp is the GetX wrapper around MaterialApp
        // It enables GetX navigation, snackbars, dialogs, and bottomSheets
        return GetMaterialApp(
          title: 'Kindura AI',
          debugShowCheckedModeBanner: false,

          // Theme configuration - supports both light and dark modes
          // See lib/services/theme_service.dart for theme definitions
          theme: ThemeService.lightTheme,
          darkTheme: ThemeService.darkTheme,
          themeMode: ThemeMode.light, // Default, updated by ThemeService

          // Route configuration - all routes defined in AppRoutes.appRoutes()
          // Navigation: Get.toNamed(RoutesName.screenName)
          getPages: AppRoutes.appRoutes(),

          // Initial screen - SplashScreen handles auth check and navigation
          home: const SplashScreen(),
        );
      },
      // Design size for responsive calculations
      // Use .w for width, .h for height, .sp for font sizes
      // Example: Container(width: 100.w, height: 50.h)
      designSize: const Size(375, 812),
    );
  }
}
