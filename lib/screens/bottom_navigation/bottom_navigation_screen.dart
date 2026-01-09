import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/res/assets/image_constant.dart';
import 'package:kindura_ai/res/colors/app_color.dart';
import 'package:kindura_ai/screens/bottom_navigation/bottom_navigation_controller.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kindura_ai/screens/home/home_screen.dart';
import 'package:kindura_ai/screens/home/home_controller.dart';
import 'package:kindura_ai/screens/labs/labs_screen.dart';
import 'package:kindura_ai/screens/meds_vitamin/meds_vitamin_screen.dart';
import 'package:kindura_ai/screens/profile/profile_screen.dart';
import 'package:kindura_ai/screens/scan/scan_screen.dart';
import 'package:kindura_ai/services/theme_service.dart';
import 'package:kindura_ai/common_widgets/report_progress_overlay.dart';

class MainPage extends StatelessWidget {
  final BottomNavController controller = Get.put(BottomNavController());

  /// Lazily get or create HomeController
  /// Uses Get.put with permanent: true to keep it alive
  HomeController get homeController {
    if (!Get.isRegistered<HomeController>()) {
      Get.put(HomeController(), permanent: true);
    }
    return Get.find<HomeController>();
  }

  // Mic button colors
  final peachColor = const Color(0xFFF9A58A);
  final redColor = const Color(0xFFE53935);

  final List<Widget> screens = [
    const Home(),
    LabsScreen(),
    const MedsVitaminScreen(),
    const ProfileScreen(),
    const ScanScreen(),
  ];

  MainPage({super.key, required int initialIndex}) {
    controller.currentIndex.value = initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Theme-aware colors
    final navBarBg = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final navPillBg = isDark ? const Color(0xFF252538) : const Color(0xFFF1F5F9);
    final navItemBg = isDark ? const Color(0xFF252538) : const Color(0xFFE2E8F0);
    final navItemSelectedBg = isDark ? const Color(0xFF2D2D44) : AppColor.primaryColor.withOpacity(0.15);
    final navIconColor = isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B);
    final navIconSelectedColor = isDark ? Colors.white : AppColor.primaryColor;
    final containerShadowColor = isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.06);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            Obx(() => screens[controller.currentIndex.value]),
            // Global report progress overlay - shows on all screens
            const ReportProgressOverlay(),
          ],
        ),
        bottomNavigationBar: Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom > 0 ? 8.h : 12.h),
          decoration: BoxDecoration(
            color: navBarBg,
            boxShadow: [
              BoxShadow(
                color: containerShadowColor,
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Container(
            height: 72.h,
            margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            decoration: BoxDecoration(
              color: navPillBg,
              borderRadius: BorderRadius.circular(40),
              border: isDark ? null : Border.all(color: const Color(0xFFE2E8F0), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Left side - 2 items
                _buildNavItem(context, ImageConstant.voiceIcon, 'Home', 0, isDark, navItemBg, navItemSelectedBg, navIconColor, navIconSelectedColor),
                _buildNavItem(context, ImageConstant.reportCheckupIcon, 'Labs', 1, isDark, navItemBg, navItemSelectedBg, navIconColor, navIconSelectedColor),

                // Center - Mic button (larger, elevated)
                _buildCenterMicButton(),

                // Right side - 2 items (symmetric)
                _buildNavItem(context, ImageConstant.medVitaminIcon, 'Meds', 2, isDark, navItemBg, navItemSelectedBg, navIconColor, navIconSelectedColor),
                _buildNavItem(context, ImageConstant.profileIcon, 'Profile', 3, isDark, navItemBg, navItemSelectedBg, navIconColor, navIconSelectedColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterMicButton() {
    return Obx(() {
      final isConnected = homeController.isConnected.value;
      return GestureDetector(
        onTap: () {
          if (isConnected) {
            homeController.disconnect();
          } else {
            homeController.connectToRoom();
          }
        },
        child: Container(
          width: 56.w,
          height: 56.w,
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isConnected
                  ? [const Color(0xFFFF6B6B), const Color(0xFFE53935)]
                  : [const Color(0xFFFFB199), const Color(0xFFF9A58A)],
            ),
            boxShadow: [
              BoxShadow(
                color: (isConnected ? redColor : peachColor).withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: (isConnected ? redColor : peachColor).withOpacity(0.3),
                blurRadius: 40,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Icon(
            isConnected ? Icons.mic_off_rounded : Icons.mic_rounded,
            color: Colors.white,
            size: 28.sp,
          ),
        ),
      );
    });
  }

  Widget _buildNavItem(
    BuildContext context,
    String asset,
    String label,
    int index,
    bool isDark,
    Color navItemBg,
    Color navItemSelectedBg,
    Color navIconColor,
    Color navIconSelectedColor,
  ) {
    return Obx(() {
      bool isSelected = controller.currentIndex.value == index;
      return GestureDetector(
        onTap: () => controller.changeTabIndex(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 44.w,
          height: 44.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? navItemSelectedBg : navItemBg,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                asset,
                width: 18.w,
                height: 18.w,
                colorFilter: ColorFilter.mode(
                  isSelected ? navIconSelectedColor : navIconColor,
                  BlendMode.srcIn,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                label,
                style: TextStyle(
                  fontSize: 7.sp,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? navIconSelectedColor : navIconColor,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
