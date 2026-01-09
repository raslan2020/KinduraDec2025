import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/common_widgets/custom_button.dart';
import 'package:kindura_ai/common_widgets/custom_text_field_new.dart';
import 'package:kindura_ai/common_widgets/loading_indicator.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/res/colors/app_color.dart';
import 'package:kindura_ai/screens/bottom_navigation/bottom_navigation_controller.dart';
import 'package:kindura_ai/screens/profile/profile_controller.dart';
import 'package:kindura_ai/services/theme_service.dart';
import 'package:kindura_ai/services/watch_vitals_service.dart';
import 'package:kindura_ai/screens/home/home_controller.dart';
import 'package:kindura_ai/models/health/data_source_mode.dart';
import 'package:kindura_ai/models/user_profile/user_profile_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final profileController = Get.put(ProfileController());
  final _formkey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColor.black;
    final borderColor = isDark ? Colors.grey.shade600 : AppColor.black;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              AppBar(
                title: Center(
                  child: Text("Kindura AI",
                      style: TextStyle(
                        color: textColor,
                      )),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: false,
                actions: [
                  if (profileController.arguments == null)
                    IconButton(
                      icon: Icon(Icons.settings, color: AppColor.primaryColor),
                      onPressed: () => _showSettingsDialog(context),
                      tooltip: 'Settings',
                    ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: profileController.arguments == null
                                      ? "Update your "
                                      : "Complete your ",
                                  style: TextStyle(
                                      color: textColor,
                                      fontSize: 20.sp,
                                      fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                  text: "Profile",
                                  style: TextStyle(
                                      color: AppColor.primaryColor,
                                      fontSize: 20.sp,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 20.h,
                          ),
                          Form(
                              key: _formkey,
                              child: Column(
                                children: [
                                  // First Name Field
                                  Align(
                                    alignment: Alignment.topLeft,
                                    child: Text(
                                      "First Name*",
                                      style: TextStyle(
                                          color: textColor,
                                          fontSize: 14.sp,
                                          fontFamily: 'Inter-Medium',
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  CustomTextFieldNew(
                                    controller: profileController
                                        .firstNameController.value,
                                    labelText: 'Enter your first name',
                                    obscureText: false,
                                    keyboardType: TextInputType.text,
                                    borderRadius: 8,
                                    isLabel: false,
                                    fontColor: textColor,
                                    focusNode: profileController
                                        .firstNameFocusNode.value,
                                    readOnly: false,
                                  ),
                                  SizedBox(height: 25.h),

                                  // Last Name Field
                                  Align(
                                    alignment: Alignment.topLeft,
                                    child: Text(
                                      "Last Name*",
                                      style: TextStyle(
                                          color: textColor,
                                          fontSize: 14.sp,
                                          fontFamily: 'Inter-Medium',
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  CustomTextFieldNew(
                                    controller: profileController
                                        .lastNameController.value,
                                    labelText: 'Enter your last name',
                                    obscureText: false,
                                    keyboardType: TextInputType.text,
                                    borderRadius: 8,
                                    isLabel: false,
                                    fontColor: textColor,
                                    focusNode: profileController
                                        .lastNameFocusNode.value,
                                    readOnly: false,
                                  ),
                                  SizedBox(height: 25.h),

                                  // Phone Number Field
                                  Align(
                                    alignment: Alignment.topLeft,
                                    child: Text(
                                      "Phone Number*",
                                      style: TextStyle(
                                          color: textColor,
                                          fontSize: 14.sp,
                                          fontFamily: 'Inter-Medium',
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  CustomTextFieldNew(
                                    controller:
                                        profileController.phoneController.value,
                                    labelText: '+1 (555) 123-4567',
                                    obscureText: false,
                                    keyboardType: TextInputType.phone,
                                    borderRadius: 8,
                                    isLabel: false,
                                    fontColor: textColor,
                                    focusNode:
                                        profileController.phoneFocusNode.value,
                                    readOnly: false,
                                  ),
                                  SizedBox(height: 25.h),

                                  // Age Field
                                  Align(
                                    alignment: Alignment.topLeft,
                                    child: Text(
                                      "Age*",
                                      style: TextStyle(
                                          color: textColor,
                                          fontSize: 14.sp,
                                          fontFamily: 'Inter-Medium',
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  CustomTextFieldNew(
                                    controller:
                                        profileController.ageController.value,
                                    labelText: 'Enter your age',
                                    obscureText: false,
                                    keyboardType: TextInputType.number,
                                    borderRadius: 8,
                                    isLabel: false,
                                    fontColor: textColor,
                                    focusNode:
                                        profileController.ageFocusNode.value,
                                    readOnly: false,
                                    maxLength: 3,
                                  ),
                                  SizedBox(height: 25.h),

                                  // Gender Field
                                  Align(
                                    alignment: Alignment.topLeft,
                                    child: Text(
                                      "Select Agent Conservation Mode*",
                                      style: TextStyle(
                                          color: textColor,
                                          fontSize: 14.sp,
                                          fontFamily: 'Inter-Medium',
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  Obx(() => Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: borderColor,
                                            width: 1.h,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8.w),
                                        ),
                                        child: DropdownButtonFormField<String>(
                                          value: profileController
                                                  .selectedConservation
                                                  .value
                                                  .isEmpty
                                              ? null
                                              : profileController
                                                  .selectedConservation.value,
                                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                          decoration: InputDecoration(
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              vertical: 14.h,
                                              horizontal: 16.w,
                                            ),
                                            border: InputBorder.none,
                                            hintText:
                                                'Select Agent Conservation Mode',
                                            hintStyle: TextStyle(
                                              color: AppColor.gray500,
                                              fontFamily: 'Inter-Regular',
                                              fontWeight: FontWeight.w400,
                                              fontSize: 16.sp,
                                            ),
                                          ),
                                          items: ['Short', 'Medium', 'Detailed']
                                              .map((String value) {
                                            return DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(
                                                value,
                                                style: TextStyle(
                                                  fontSize: 16.sp,
                                                  color: textColor,
                                                  fontFamily: 'Inter-Regular',
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (String? newValue) {
                                            if (newValue != null) {
                                              profileController
                                                  .selectedConservation
                                                  .value = newValue;
                                            }
                                          },
                                        ),
                                      )),
                                  SizedBox(height: 25.h),
                                  // Gender Field
                                  Align(
                                    alignment: Alignment.topLeft,
                                    child: Text(
                                      "Gender*",
                                      style: TextStyle(
                                          color: textColor,
                                          fontSize: 14.sp,
                                          fontFamily: 'Inter-Medium',
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  Obx(() => Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: borderColor,
                                            width: 1.h,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8.w),
                                        ),
                                        child: DropdownButtonFormField<String>(
                                          value: profileController
                                                  .selectedGender.value.isEmpty
                                              ? null
                                              : profileController
                                                  .selectedGender.value,
                                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                          decoration: InputDecoration(
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              vertical: 14.h,
                                              horizontal: 16.w,
                                            ),
                                            border: InputBorder.none,
                                            hintText: 'Select your gender',
                                            hintStyle: TextStyle(
                                              color: AppColor.gray500,
                                              fontFamily: 'Inter-Regular',
                                              fontWeight: FontWeight.w400,
                                              fontSize: 16.sp,
                                            ),
                                          ),
                                          items: ['Male', 'Female', 'Other']
                                              .map((String value) {
                                            return DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(
                                                value,
                                                style: TextStyle(
                                                  fontSize: 16.sp,
                                                  color: textColor,
                                                  fontFamily: 'Inter-Regular',
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (String? newValue) {
                                            if (newValue != null) {
                                              profileController.selectedGender
                                                  .value = newValue;
                                            }
                                          },
                                        ),
                                      )),
                                  SizedBox(height: 25.h),
                                  Align(
                                    alignment: Alignment.topLeft,
                                    child: Text(
                                      "Language*",
                                      style: TextStyle(
                                          color: textColor,
                                          fontSize: 14.sp,
                                          fontFamily: 'Inter-Medium',
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  Obx(() => Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: borderColor,
                                            width: 1.h,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8.w),
                                        ),
                                        child: DropdownButtonFormField<String>(
                                          value: profileController
                                                  .selectedLanguage
                                                  .value
                                                  .isEmpty
                                              ? null
                                              : profileController
                                                  .selectedLanguage.value,
                                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                          decoration: InputDecoration(
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              vertical: 14.h,
                                              horizontal: 16.w,
                                            ),
                                            border: InputBorder.none,
                                            hintText: 'Select your language',
                                            hintStyle: TextStyle(
                                              color: AppColor.gray500,
                                              fontFamily: 'Inter-Regular',
                                              fontWeight: FontWeight.w400,
                                              fontSize: 16.sp,
                                            ),
                                          ),
                                          items: profileController
                                              .languages.keys
                                              .map((String key) {
                                            return DropdownMenuItem<String>(
                                              value: key,
                                              child: Text(
                                                key,
                                                style: TextStyle(
                                                  fontSize: 16.sp,
                                                  color: textColor,
                                                  fontFamily: 'Inter-Regular',
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (String? newValue) {
                                            print(newValue);
                                            if (newValue != null) {
                                              profileController.selectedLanguage
                                                  .value = newValue;
                                              var code = profileController
                                                  .languages[newValue];
                                              if (code is List) {
                                                profileController
                                                    .languageController
                                                    .value
                                                    .text = code.first;
                                              } else {
                                                profileController
                                                    .languageController
                                                    .value
                                                    .text = code.toString();
                                              }
                                            }
                                          },
                                        ),
                                      )),
                                  SizedBox(height: 25.h),

                                  Align(
                                    alignment: Alignment.topLeft,
                                    child: Text(
                                      "Address*",
                                      style: TextStyle(
                                          color: textColor,
                                          fontSize: 14.sp,
                                          fontFamily: 'Inter-Medium',
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  CustomTextFieldNew(
                                    controller: profileController
                                        .addressController.value,
                                    labelText: 'Enter your address',
                                    obscureText: false,
                                    keyboardType: TextInputType.multiline,
                                    borderRadius: 8,
                                    isLabel: false,
                                    fontColor: textColor,
                                    focusNode: profileController
                                        .addressFocusNode.value,
                                    readOnly: false,
                                    maxLines: 3,
                                  ),
                                  SizedBox(height: 25.h),

                                  if (profileController.arguments != null)
                                    Obx(() => Row(
                                          children: [
                                            Checkbox(
                                              value: profileController
                                                  .acceptedTerms.value,
                                              onChanged: (bool? value) {
                                                profileController.acceptedTerms
                                                    .value = value ?? false;
                                              },
                                              activeColor: AppColor.buttonColor,
                                            ),
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () {
                                                  profileController
                                                          .acceptedTerms.value =
                                                      !profileController
                                                          .acceptedTerms.value;
                                                },
                                                child: Text.rich(
                                                  TextSpan(
                                                    children: [
                                                      TextSpan(
                                                        text: "I agree to the ",
                                                        style: TextStyle(
                                                          color: textColor,
                                                          fontSize: 14.sp,
                                                          fontFamily:
                                                              'Inter-Regular',
                                                        ),
                                                      ),
                                                      TextSpan(
                                                        text:
                                                            "Terms and Conditions",
                                                        style: TextStyle(
                                                          color: AppColor
                                                              .buttonColor,
                                                          fontSize: 14.sp,
                                                          fontFamily:
                                                              'Inter-Medium',
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          decoration:
                                                              TextDecoration
                                                                  .underline,
                                                        ),
                                                      ),
                                                      TextSpan(
                                                        text: " and ",
                                                        style: TextStyle(
                                                          color: textColor,
                                                          fontSize: 14.sp,
                                                          fontFamily:
                                                              'Inter-Regular',
                                                        ),
                                                      ),
                                                      TextSpan(
                                                        text: "Privacy Policy*",
                                                        style: TextStyle(
                                                          color: AppColor
                                                              .buttonColor,
                                                          fontSize: 14.sp,
                                                          fontFamily:
                                                              'Inter-Medium',
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          decoration:
                                                              TextDecoration
                                                                  .underline,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        )),
                                ],
                              )),
                          SizedBox(height: 25.h),
                          CustomButton(
                            text: profileController.arguments == null
                                ? "Update Profile"
                                : "Save Profile",
                            textColor: AppColor.black,
                            bgColor: AppColor.buttonColor,
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                              profileController.saveProfile();
                            },
                          ),
                          SizedBox(height: 15.h),

                          // Show reports and logout button only when editing profile (not during signup)
                          if (profileController.arguments == null)
                            CustomButton(
                              text: "Kindura Reports",
                              textColor: AppColor.black,
                              bgColor: AppColor.surfaceDark,
                              onPressed: () {
                                Get.toNamed('/kindura_reports');
                              },
                            ),
                          if (profileController.arguments == null)
                            SizedBox(height: 15.h),
                          if (profileController.arguments == null)
                            CustomButton(
                              text: "My Contacts",
                              textColor: AppColor.black,
                              bgColor: AppColor.surfaceDark,
                              onPressed: () {
                                Get.toNamed('/contacts');
                              },
                            ),
                          if (profileController.arguments == null)
                            SizedBox(height: 15.h),
                          if (profileController.arguments == null)
                            CustomButton(
                              text: "Add Medical Reports",
                              textColor: AppColor.black,
                              bgColor: AppColor.surfaceDark,
                              onPressed: () {
                                // Navigate to Scan screen (index 4) within bottom navigation
                                final navController = Get.find<BottomNavController>();
                                navController.currentIndex.value = 4;
                              },
                            ),
                          if (profileController.arguments == null)
                            SizedBox(height: 15.h),
                          if (profileController.arguments == null)
                            CustomButton(
                              text: "Logout",
                              textColor: Colors.white,
                              bgColor: Colors.red,
                              onPressed: () {
                                // Show confirmation dialog
                                Get.dialog(
                                  AlertDialog(
                                    title: Text('Logout',
                                        style: TextStyle(
                                            color: AppColor.black,
                                            fontWeight: FontWeight.bold)),
                                    content: Text(
                                        'Are you sure you want to logout?',
                                        style: TextStyle(color: AppColor.black)),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Get.back(),
                                        child: Text('Cancel',
                                            style: TextStyle(
                                                color: AppColor.primaryColor)),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Get.back(); // Close dialog
                                          profileController.logout();
                                        },
                                        child: Text('Logout',
                                            style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          SizedBox(height: 30.h),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Obx(() {
            switch (profileController.requestStatus.value) {
              case Status.LOADING:
                return Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: Center(child: LoadingIndicator()),
                );
              case Status.ERROR:
                return Container();
              case Status.COMPLETED:
                return Container();
              default:
                return Container();
            }
          }),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    // TODO: Load these values from user preferences/database
    final caregiverSmsEnabled = false.obs;
    final caregiverEmailEnabled = false.obs;
    final themeService = Get.find<ThemeService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final watchVitalsService = WatchVitalsService();
    final healthKitAuthorized = false.obs;
    final watchPaired = false.obs;
    final isLoadingHealth = true.obs;

    // Load health integration status
    _loadHealthIntegrationStatus(
      watchVitalsService,
      healthKitAuthorized,
      watchPaired,
      isLoadingHealth,
    );

    Get.dialog(
      AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: [
            Icon(Icons.settings, color: AppColor.primaryColor),
            SizedBox(width: 8.w),
            Text('Settings',
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Theme Section
              Text(
                'Appearance',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              SizedBox(height: 8.h),
              Obx(() => Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColor.gray500),
                      borderRadius: BorderRadius.circular(8.w),
                    ),
                    child: SwitchListTile(
                      title: Row(
                        children: [
                          Icon(
                            themeService.isDarkMode
                                ? Icons.dark_mode
                                : Icons.light_mode,
                            color: themeService.isDarkMode
                                ? Colors.amber
                                : Colors.orange,
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            themeService.isDarkMode ? 'Dark Mode' : 'Light Mode',
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      value: themeService.isDarkMode,
                      onChanged: (value) {
                        themeService.setDarkMode(value);
                      },
                      activeColor: AppColor.primaryColor,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12.w),
                    ),
                  )),
              SizedBox(height: 24.h),

              // Apple Health Section
              Text(
                'Apple Health',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Connect to Apple Health to sync vitals from your Apple Watch',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              SizedBox(height: 12.h),
              Obx(() => Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColor.gray500),
                      borderRadius: BorderRadius.circular(8.w),
                    ),
                    child: isLoadingHealth.value
                        ? Center(
                            child: SizedBox(
                              height: 24.h,
                              width: 24.h,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColor.primaryColor,
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              // Watch Status Row
                              Row(
                                children: [
                                  Icon(
                                    Icons.watch,
                                    color: watchPaired.value
                                        ? Colors.green
                                        : Colors.grey,
                                    size: 24.sp,
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Apple Watch',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.color,
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          watchPaired.value
                                              ? 'Paired'
                                              : 'Not paired',
                                          style: TextStyle(
                                            color: watchPaired.value
                                                ? Colors.green
                                                : Colors.grey,
                                            fontSize: 12.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Divider(height: 24.h, color: AppColor.gray500),
                              // HealthKit Status Row
                              Row(
                                children: [
                                  Icon(
                                    Icons.favorite,
                                    color: healthKitAuthorized.value
                                        ? Colors.red
                                        : Colors.grey,
                                    size: 24.sp,
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Health Data Access',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.color,
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          healthKitAuthorized.value
                                              ? 'Authorized'
                                              : 'Not authorized',
                                          style: TextStyle(
                                            color: healthKitAuthorized.value
                                                ? Colors.green
                                                : Colors.grey,
                                            fontSize: 12.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!healthKitAuthorized.value)
                                    ElevatedButton(
                                      onPressed: () async {
                                        // Close the dialog first
                                        Get.back();
                                        // Then request HealthKit access
                                        await _requestHealthKitAccess(
                                          watchVitalsService,
                                          healthKitAuthorized,
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColor.primaryColor,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12.w,
                                          vertical: 8.h,
                                        ),
                                      ),
                                      child: Text(
                                        'Connect',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                  )),
              SizedBox(height: 8.h),
              Text(
                'Kindura reads heart rate, blood oxygen, sleep data, and fall detection from your Apple Watch.',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontStyle: FontStyle.italic,
                ),
              ),
              SizedBox(height: 24.h),

              // Fall Detection Section
              Text(
                'Fall Detection',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Apple Watch has built-in fall detection. When enabled, falls are automatically recorded to HealthKit and synced to Kindura.',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(8.w),
                  color: Colors.orange.withOpacity(0.05),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(
                          Icons.health_and_safety,
                          color: Colors.orange,
                          size: 20.sp,
                        ),
                        SizedBox(width: 8.w),
                        Flexible(
                          child: Text(
                            'Enable Apple Fall Detection',
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    // Step-by-step instructions
                    _buildInlineStep(context, '1', 'Open the Watch app on your iPhone'),
                    _buildInlineStep(context, '2', 'Tap "My Watch" tab at the bottom'),
                    _buildInlineStep(context, '3', 'Scroll down and tap "Emergency SOS"'),
                    _buildInlineStep(context, '4', 'Tap "Fall Detection"'),
                    _buildInlineStep(context, '5', 'Toggle Fall Detection ON'),
                    _buildInlineStep(context, '6', 'Select "Always On" for best coverage'),
                    SizedBox(height: 12.h),
                    // Success indicator
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6.w),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 18.sp),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              'Once enabled, Apple-detected falls will automatically sync to Kindura via HealthKit.',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10.h),
                    // Info about dual detection
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6.w),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 16.sp, color: Colors.blue),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              'Kindura also detects falls using its own accelerometer analysis. Both sources sync to HealthKit for comprehensive coverage.',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10.h),
                    // Note about fall detection sensitivity
                    Text(
                      'Note: Apple\'s fall detection is designed for hard falls with free-fall + impact + post-fall immobility. It won\'t trigger from minor bumps.',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),

              // Health Data Source Section
              Text(
                'Health Data Source',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Choose how Kindura collects your health data',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              SizedBox(height: 12.h),
              _buildDataSourcePicker(context),
              SizedBox(height: 24.h),

              // Unit System Section
              Text(
                'Unit System',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Choose how lab values and measurements are displayed',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              SizedBox(height: 12.h),
              Obx(() => Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColor.gray500),
                      borderRadius: BorderRadius.circular(8.w),
                    ),
                    child: Column(
                      children: [
                        // US Standard option
                        RadioListTile<String>(
                          title: Text('US Standard',
                              style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500)),
                          subtitle: Text('mg/dL, lbs, °F',
                              style: TextStyle(
                                  color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12.sp)),
                          value: 'US',
                          groupValue: profileController.selectedUnitSystem.value,
                          onChanged: (value) {
                            if (value != null) {
                              profileController.selectedUnitSystem.value = value;
                            }
                          },
                          activeColor: AppColor.primaryColor,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8.w),
                          dense: true,
                        ),
                        Divider(height: 1, color: AppColor.gray500),
                        // International SI option
                        RadioListTile<String>(
                          title: Text('International SI',
                              style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500)),
                          subtitle: Text('mmol/L, kg, °C',
                              style: TextStyle(
                                  color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12.sp)),
                          value: 'SI',
                          groupValue: profileController.selectedUnitSystem.value,
                          onChanged: (value) {
                            if (value != null) {
                              profileController.selectedUnitSystem.value = value;
                            }
                          },
                          activeColor: AppColor.primaryColor,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8.w),
                          dense: true,
                        ),
                      ],
                    ),
                  )),
              SizedBox(height: 24.h),

              // Kindura AI Permissions Section
              Text(
                'Kindura AI Permissions',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Control what actions Kindura can perform',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              SizedBox(height: 12.h),
              Obx(() => SwitchListTile(
                    title: Text('Allow Medication Updates',
                        style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500)),
                    subtitle: Text(
                        'Let Kindura mark medications as taken when you tell her',
                        style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontSize: 12.sp)),
                    value: profileController.allowAgentMedicationUpdates.value,
                    onChanged: (value) {
                      profileController.allowAgentMedicationUpdates.value = value;
                    },
                    activeColor: AppColor.primaryColor,
                    contentPadding: EdgeInsets.zero,
                  )),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8.w),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue.shade700, size: 20.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'When enabled, you can say "I took my medication" and Kindura will update your tracking. When disabled, she will remind you to do it manually in the app.',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),

              // Extended Vitals Section
              Text(
                'Extended Health Vitals',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Enable collection of additional health metrics from HealthKit',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              SizedBox(height: 12.h),
              Obx(() => SwitchListTile(
                    title: Text('Extended Vitals Collection',
                        style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500)),
                    subtitle: Text(
                        'Walking steadiness, blood glucose, blood pressure, VO2 max, AFib, temperature, mobility metrics',
                        style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontSize: 11.sp)),
                    value: profileController.extendedVitalsEnabled.value,
                    onChanged: (value) {
                      profileController.extendedVitalsEnabled.value = value;
                    },
                    activeColor: AppColor.primaryColor,
                    contentPadding: EdgeInsets.zero,
                  )),
              SizedBox(height: 16.h),

              // Vitals Retention Period
              Text(
                'Vitals Data Retention',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              SizedBox(height: 8.h),
              Obx(() => Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColor.gray500),
                      borderRadius: BorderRadius.circular(8.w),
                    ),
                    child: Column(
                      children: [
                        RadioListTile<int>(
                          title: Text('30 days',
                              style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500)),
                          subtitle: Text('Less storage, recent data only',
                              style: TextStyle(
                                  color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 11.sp)),
                          value: 30,
                          groupValue: profileController.vitalsRetentionDays.value,
                          onChanged: (value) {
                            if (value != null) {
                              profileController.vitalsRetentionDays.value = value;
                            }
                          },
                          activeColor: AppColor.primaryColor,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8.w),
                          dense: true,
                        ),
                        Divider(height: 1, color: AppColor.gray500),
                        RadioListTile<int>(
                          title: Text('60 days',
                              style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500)),
                          subtitle: Text('More data for trend analysis',
                              style: TextStyle(
                                  color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 11.sp)),
                          value: 60,
                          groupValue: profileController.vitalsRetentionDays.value,
                          onChanged: (value) {
                            if (value != null) {
                              profileController.vitalsRetentionDays.value = value;
                            }
                          },
                          activeColor: AppColor.primaryColor,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8.w),
                          dense: true,
                        ),
                      ],
                    ),
                  )),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8.w),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.storage, color: Colors.orange.shade700, size: 16.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Older vitals data will be automatically deleted after this period to save storage space.',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              // Individual Extended Vitals Toggles
              Obx(() => profileController.extendedVitalsEnabled.value
                  ? _buildExtendedVitalsToggles(context, profileController)
                  : SizedBox.shrink()),

              SizedBox(height: 24.h),

              // Caregiver Notifications Section
              Text(
                'Caregiver Notifications',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Notify caregiver when medication time arrives',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              SizedBox(height: 16.h),

              // SMS Notification Toggle
              Obx(() => SwitchListTile(
                    title: Text('SMS Notifications',
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                    subtitle: Text('Send SMS to caregiver',
                        style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12.sp)),
                    value: caregiverSmsEnabled.value,
                    onChanged: (value) {
                      caregiverSmsEnabled.value = value;
                      // TODO: Implement SMS notification to caregiver
                      // This should:
                      // 1. Save preference to user settings in DB
                      // 2. When medication time arrives, send SMS to caregiver contacts
                      // 3. Include medication name, dose, and time in SMS
                      print('Caregiver SMS notifications: $value');
                    },
                    activeColor: AppColor.primaryColor,
                    contentPadding: EdgeInsets.zero,
                  )),

              // Email Notification Toggle
              Obx(() => SwitchListTile(
                    title: Text('Email Notifications',
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                    subtitle: Text('Send email to caregiver',
                        style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12.sp)),
                    value: caregiverEmailEnabled.value,
                    onChanged: (value) {
                      caregiverEmailEnabled.value = value;
                      // TODO: Implement email notification to caregiver
                      // This should:
                      // 1. Save preference to user settings in DB
                      // 2. When medication time arrives, send email to caregiver contacts
                      // 3. Include medication details and adherence info in email
                      print('Caregiver email notifications: $value');
                    },
                    activeColor: AppColor.primaryColor,
                    contentPadding: EdgeInsets.zero,
                  )),

              SizedBox(height: 16.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8.w),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.amber.shade700, size: 20.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Ensure caregiver contacts are added in the Medications section',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Close', style: TextStyle(color: AppColor.primaryColor)),
          ),
          ElevatedButton(
            onPressed: () {
              // Save settings including unit system
              Get.back();
              profileController.saveProfile();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColor.primaryColor,
            ),
            child: Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // MARK: - Apple Health Helper Methods

  Future<void> _loadHealthIntegrationStatus(
    WatchVitalsService service,
    RxBool healthKitAuthorized,
    RxBool watchPaired,
    RxBool isLoading,
  ) async {
    try {
      final status = await service.getHealthIntegrationStatus();
      healthKitAuthorized.value = status['healthKitAuthorized'] ?? false;
      watchPaired.value = status['isPaired'] ?? false;
    } catch (e) {
      print('[ProfileScreen] Error loading health status: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _requestHealthKitAccess(
    WatchVitalsService service,
    RxBool healthKitAuthorized,
  ) async {
    try {
      final success = await service.requestHealthKitAuthorization();
      healthKitAuthorized.value = success;

      if (success) {
        print('[ProfileScreen] ✅ HealthKit access granted');
        // Show success dialog
        _showHealthAccessResultDialog(
          title: 'Health Access Granted',
          message: 'Apple Health access granted! Your vitals will now sync automatically.',
          isSuccess: true,
        );
      } else {
        print('[ProfileScreen] ⚠️ HealthKit access denied or unavailable');
        // Show instructions dialog
        _showHealthAccessResultDialog(
          title: 'Health Access Required',
          message: 'Please enable Health access:\n\n1. Open iPhone Settings\n2. Go to Privacy & Security\n3. Tap Health\n4. Find Kindura and enable all permissions',
          isSuccess: false,
        );
      }
    } catch (e) {
      print('[ProfileScreen] ❌ Error requesting HealthKit access: $e');
      _showHealthAccessResultDialog(
        title: 'Error',
        message: 'Failed to request Health access. Please try again.',
        isSuccess: false,
      );
    }
  }

  void _showHealthAccessResultDialog({
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    final isDark = Theme.of(Get.context!).brightness == Brightness.dark;

    Get.dialog(
      AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.info_outline,
              color: isSuccess ? Colors.green : Colors.orange,
              size: 28,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16.sp,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
            fontSize: 14.sp,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'OK',
              style: TextStyle(
                color: AppColor.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      barrierDismissible: true,
    );
  }

  void _showFallDetectionGuide(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Get.dialog(
      AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.health_and_safety,
              color: Colors.orange,
              size: 28,
            ),
            SizedBox(width: 8.w),
            Text(
              'Enable Fall Detection',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold,
                fontSize: 18.sp,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Apple Watch has built-in fall detection that works even when Kindura isn\'t running.\n',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 14.sp,
                ),
              ),
              Text(
                'To enable Apple Fall Detection:',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14.sp,
                ),
              ),
              SizedBox(height: 12.h),
              _buildStepItem('1', 'Open the Watch app on your iPhone'),
              _buildStepItem('2', 'Tap "My Watch" tab'),
              _buildStepItem('3', 'Scroll down and tap "Emergency SOS"'),
              _buildStepItem('4', 'Tap "Fall Detection"'),
              _buildStepItem('5', 'Toggle Fall Detection ON'),
              _buildStepItem('6', 'Choose "Always On" for best coverage'),
              SizedBox(height: 16.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.w),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Once enabled, falls detected by Apple will automatically sync to Kindura via HealthKit.',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'Note: Apple\'s fall detection is designed for hard falls. It requires the Watch to detect free-fall, hard impact, and post-fall immobility.',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Got it',
              style: TextStyle(
                color: AppColor.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      barrierDismissible: true,
    );
  }

  Widget _buildStepItem(String number, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24.w,
            height: 24.w,
            decoration: BoxDecoration(
              color: AppColor.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.sp,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.sp,
                color: Get.isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineStep(BuildContext context, String number, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20.w,
            height: 20.w,
            decoration: BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11.sp,
                ),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.sp,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // MARK: - Data Source Picker Widget

  Widget _buildDataSourcePicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Check if HomeController is registered
    if (!Get.isRegistered<HomeController>()) {
      return Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          border: Border.all(color: AppColor.gray500),
          borderRadius: BorderRadius.circular(8.w),
        ),
        child: Text(
          'Health data source settings not available',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodySmall?.color,
            fontSize: 12.sp,
          ),
        ),
      );
    }

    final homeController = Get.find<HomeController>();

    return Obx(() {
      final currentMode = homeController.dataSourceMode.value;

      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColor.gray500),
          borderRadius: BorderRadius.circular(8.w),
        ),
        child: Column(
          children: [
            // Auto-detect option
            _buildDataSourceOption(
              context: context,
              icon: Icons.auto_mode,
              title: 'Auto-detect',
              subtitle: 'Automatically use Watch if paired',
              color: Colors.purple,
              isSelected: !homeController.hasDataSourceOverride.value,
              onTap: () async {
                await homeController.setDataSourceMode(null);
                Get.back();
                Get.snackbar(
                  'Data Source Updated',
                  'Now using auto-detection',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green.withOpacity(0.9),
                  colorText: Colors.white,
                );
              },
            ),
            Divider(height: 1, color: AppColor.gray500),
            // Apple Watch option
            _buildDataSourceOption(
              context: context,
              icon: Icons.watch,
              title: 'Apple Watch',
              subtitle: 'Real-time vitals & fall detection',
              color: Colors.blue,
              isSelected: currentMode == DataSourceMode.appleWatch,
              onTap: () async {
                await homeController.setDataSourceMode(DataSourceMode.appleWatch);
                Get.back();
                Get.snackbar(
                  'Data Source Updated',
                  'Now using Apple Watch mode',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green.withOpacity(0.9),
                  colorText: Colors.white,
                );
              },
            ),
            Divider(height: 1, color: AppColor.gray500),
            // Apple Health Only option
            _buildDataSourceOption(
              context: context,
              icon: Icons.favorite,
              title: 'Apple Health Only',
              subtitle: 'Oura, Whoop, Ultrahuman, etc.',
              color: Colors.green,
              isSelected: currentMode == DataSourceMode.healthKitOnly,
              onTap: () async {
                await homeController.setDataSourceMode(DataSourceMode.healthKitOnly);
                Get.back();
                Get.snackbar(
                  'Data Source Updated',
                  'Now using Apple Health only',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green.withOpacity(0.9),
                  colorText: Colors.white,
                );
              },
            ),
            Divider(height: 1, color: AppColor.gray500),
            // Manual Entry option
            _buildDataSourceOption(
              context: context,
              icon: Icons.edit,
              title: 'Manual Entry',
              subtitle: 'Enter health data manually',
              color: Colors.grey,
              isSelected: currentMode == DataSourceMode.manualOnly,
              onTap: () async {
                await homeController.setDataSourceMode(DataSourceMode.manualOnly);
                Get.back();
                Get.snackbar(
                  'Data Source Updated',
                  'Now using manual entry mode',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green.withOpacity(0.9),
                  colorText: Colors.white,
                );
              },
            ),
          ],
        ),
      );
    });
  }

  Widget _buildDataSourceOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        color: isSelected
            ? color.withOpacity(isDark ? 0.2 : 0.1)
            : Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.w),
              ),
              child: Icon(icon, color: color, size: 20.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 11.sp,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 20.sp),
          ],
        ),
      ),
    );
  }

  /// Build the extended vitals toggles section
  Widget _buildExtendedVitalsToggles(BuildContext context, ProfileController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Enable/Disable All buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Individual Vitals',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => controller.enableAllVitals(),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('All On', style: TextStyle(fontSize: 11.sp, color: Colors.green)),
                ),
                Text('|', style: TextStyle(color: Colors.grey, fontSize: 11.sp)),
                TextButton(
                  onPressed: () => controller.disableAllVitals(),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('All Off', style: TextStyle(fontSize: 11.sp, color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 8.h),

        // Vitals grouped by category
        ...ExtendedVitalsPreferences.categories.entries.map((category) {
          return _buildVitalCategory(context, controller, category.key, category.value);
        }).toList(),
      ],
    );
  }

  /// Build a category of vitals with toggles
  Widget _buildVitalCategory(
    BuildContext context,
    ProfileController controller,
    String categoryName,
    List<String> vitalKeys,
  ) {
    // Category icons
    final categoryIcons = {
      'Cardiovascular': Icons.favorite,
      'Metabolic': Icons.thermostat,
      'Fitness': Icons.fitness_center,
      'Mobility': Icons.directions_walk,
    };

    // Category colors
    final categoryColors = {
      'Cardiovascular': Colors.red,
      'Metabolic': Colors.orange,
      'Fitness': Colors.blue,
      'Mobility': Colors.teal,
    };

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        border: Border.all(color: AppColor.gray500.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: (categoryColors[categoryName] ?? Colors.grey).withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(7.w),
                topRight: Radius.circular(7.w),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  categoryIcons[categoryName] ?? Icons.health_and_safety,
                  size: 16.sp,
                  color: categoryColors[categoryName] ?? Colors.grey,
                ),
                SizedBox(width: 8.w),
                Text(
                  categoryName,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: categoryColors[categoryName] ?? Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          // Vital toggles
          ...vitalKeys.asMap().entries.map((entry) {
            final index = entry.key;
            final vitalKey = entry.value;
            final displayName = ExtendedVitalsPreferences.displayNames[vitalKey] ?? vitalKey;
            final isLast = index == vitalKeys.length - 1;

            return Column(
              children: [
                Obx(() => SwitchListTile(
                      title: Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      value: controller.isVitalEnabled(vitalKey),
                      onChanged: (value) => controller.toggleVital(vitalKey, value),
                      activeColor: categoryColors[categoryName] ?? AppColor.primaryColor,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12.w),
                      dense: true,
                      visualDensity: VisualDensity.compact,
                    )),
                if (!isLast) Divider(height: 1, indent: 12.w, endIndent: 12.w, color: AppColor.gray500.withOpacity(0.3)),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }
}
