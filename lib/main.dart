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
/// RESILIENCE: App is designed to start even without network connectivity.
/// Network errors are handled gracefully without crashes.
///
/// @see /docs/DEVELOPER_GUIDE.md for full documentation
/// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/res/routes/routes.dart';
import 'package:kindura_ai/screens/splash_screen/splash_screen.dart';
import 'package:kindura_ai/services/notification_service.dart';
import 'package:kindura_ai/services/voice_service.dart';
import 'package:kindura_ai/services/theme_service.dart';
import 'package:kindura_ai/services/report_generation_service.dart';
import 'package:kindura_ai/utils/file_logger.dart';

/// Application entry point.
///
/// Initialization sequence:
/// 1. Flutter bindings initialization (required for async operations before runApp)
/// 2. File logger setup for debugging
/// 3. Core services registration with GetX DI (permanent: true means singleton)
/// 4. Launch the app with MyApp widget
///
/// NOTE: HomeController is NOT initialized here - it's lazily initialized
/// when the user navigates to the main screen after login. This prevents
/// network-related crashes on app startup.
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
    // Non-critical - continue without logging
  }

  // =========================================================================
  // DEPENDENCY INJECTION - LOCAL SERVICES ONLY
  // =========================================================================
  // Register core services as singletons using GetX.
  // permanent: true ensures they persist throughout app lifecycle.
  //
  // IMPORTANT: Only register services that don't require network calls.
  // Network-dependent controllers (like HomeController) are lazily loaded
  // when the user navigates to the appropriate screen.
  // =========================================================================

  // ThemeService: Manages dark/light mode switching (local only)
  try {
    Get.put(ThemeService(), permanent: true);
  } catch (e) {
    print('ThemeService initialization failed: $e');
  }

  // NotificationService: Handles local push notifications (local only)
  try {
    Get.put(NotificationService(), permanent: true);
  } catch (e) {
    print('NotificationService initialization failed: $e');
  }

  // VoiceService: Manages speech recognition (local only)
  try {
    Get.put(VoiceService(), permanent: true);
  } catch (e) {
    print('VoiceService initialization failed: $e');
  }

  // ReportGenerationService: Manages background report generation with progress tracking
  try {
    Get.put(ReportGenerationService(), permanent: true);
  } catch (e) {
    print('ReportGenerationService initialization failed: $e');
  }

  // NOTE: HomeController is NOT registered here.
  // It will be lazily initialized when the user navigates to main_screen.dart
  // This prevents network errors from crashing the app on startup.

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
