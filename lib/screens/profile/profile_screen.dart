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

    Get.dialog(
      AlertDialog(
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

              // Caregiver Notifications Section
              Text(
                'Caregiver Notifications',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColor.black,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Notify caregiver when medication time arrives',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColor.gray500,
                ),
              ),
              SizedBox(height: 16.h),

              // SMS Notification Toggle
              Obx(() => SwitchListTile(
                    title: Text('SMS Notifications',
                        style: TextStyle(color: AppColor.black)),
                    subtitle: Text('Send SMS to caregiver',
                        style: TextStyle(
                            color: AppColor.gray500, fontSize: 12.sp)),
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
                        style: TextStyle(color: AppColor.black)),
                    subtitle: Text('Send email to caregiver',
                        style: TextStyle(
                            color: AppColor.gray500, fontSize: 12.sp)),
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
}
