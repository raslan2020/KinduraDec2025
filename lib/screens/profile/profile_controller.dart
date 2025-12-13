import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/models/user_profile/user_profile_model.dart';
import 'package:kindura_ai/repository/profile_repository/profile_repository_dart.dart';
import 'package:kindura_ai/res/routes/routes_name.dart';
import 'package:kindura_ai/screens/home/home_controller.dart';
import 'package:kindura_ai/utils/utils.dart';
import 'package:kindura_ai/user_preference/user_preferences_view_model.dart';

class ProfileController extends GetxController {
  final _api = ProfileRepository();
  final UserPreferences userPreferences = UserPreferences();

  // Text Controllers
  final firstNameController = TextEditingController().obs;
  final lastNameController = TextEditingController().obs;
  final phoneController = TextEditingController().obs;
  final ageController = TextEditingController().obs;
  final addressController = TextEditingController().obs;
  final languageController = TextEditingController().obs;

  // Focus Nodes
  final firstNameFocusNode = FocusNode().obs;
  final lastNameFocusNode = FocusNode().obs;
  final phoneFocusNode = FocusNode().obs;
  final ageFocusNode = FocusNode().obs;
  final addressFocusNode = FocusNode().obs;
  final languageFocusNode = FocusNode().obs;

  // Observable Variables
  final selectedGender = ''.obs;
  final selectedConservation = ''.obs;
  final selectedLanguage = ''.obs;
  final selectedUnitSystem = 'US'.obs; // US or SI
  final acceptedTerms = false.obs;
  final requestStatus = Status.COMPLETED.obs;

  // Unit system options with display labels
  final Map<String, String> unitSystems = {
    'US': 'US Standard (mg/dL, lbs, °F)',
    'SI': 'International SI (mmol/L, kg, °C)',
  };

  // Legacy variables for compatibility
  var selectedTab = 'Settings'.obs;
  var notifications = true.obs;
  var voiceOnly = false.obs;
  var humorMode = true.obs;
  var faceTimeFirst = false.obs;
  var arguments = Get.arguments;

  // Supported languages map: Display name to locale codes
  final Map<String, dynamic> languages = {
    "Arabic": "ar",
    "Arabic (Lebanese)": "ar-LB",  // Lebanese Arabic dialect
    "Bulgarian": "bg",
    "Catalan": "ca",
    "Chinese": "zh",
    "Czech": "cs",
    "Danish": "da",
    "Dutch": "nl",
    "English": "en",
    "Estonian": "et",
    "Finnish": "fi",
    "French": "fr",
    "German": "de",
    "Greek": "el",
    "Hindi": "hi",
    "Hungarian": "hu",
    "Indonesian": "id",
    "Italian": "it",
    "Japanese": "ja",
    "Korean": "ko",
    "Latvian": "lv",
    "Lithuanian": "lt",
    "Malay": "ms",
    "Norwegian": "no",
    "Polish": "pl",
    "Portuguese": "pt",
    "Romanian": "ro",
    "Russian": "ru",
    "Slovak": "sk",
    "Spanish": "es",
    "Swedish": "sv",
    "Thai": "th",
    "Turkish": "tr",
    "Ukrainian": "uk",
    "Vietnamese": "vi"
  };

  @override
  void onInit() {
    super.onInit();
    if (arguments == null) {
      final homeController = Get.find<HomeController>();
      firstNameController.value.text =
          homeController.userProfile.value.result?.firstName ?? '';
      lastNameController.value.text =
          homeController.userProfile.value.result?.lastName ?? '';
      phoneController.value.text =
          homeController.userProfile.value.result?.phoneNumber ?? '';
      ageController.value.text =
          homeController.userProfile.value.result?.age.toString() ?? '';
      addressController.value.text =
          homeController.userProfile.value.result?.address ?? '';
      languageController.value.text =
          homeController.userProfile.value.result?.language ?? '';
      selectedLanguage.value = getLanguageName(
          homeController.userProfile.value.result?.language ?? '');
      selectedConservation.value = homeController
                  .userProfile.value.result?.agentConservationChoice ==
              'S'
          ? 'Short'
          : homeController.userProfile.value.result?.agentConservationChoice ==
                  'M'
              ? 'Medium'
              : homeController.userProfile.value.result?.agentConservationChoice ==
                      'D'
                  ? 'Detailed'
                  : '';
      selectedGender.value =
          homeController.userProfile.value.result?.gender == 'M'
              ? 'Male'
              : homeController.userProfile.value.result?.gender == 'F'
                  ? 'Female'
                  : 'Other';
      acceptedTerms.value =
          homeController.userProfile.value.result?.termsAndConditions ?? false;
      selectedUnitSystem.value =
          homeController.userProfile.value.result?.unitSystem ?? 'US';
    }
  }

  String getLanguageName(String? code) {
    if (code == null) return '';
    return languages.entries
        .firstWhere((entry) => entry.value == code,
            orElse: () => const MapEntry('', ''))
        .key;
  }

  void selectTab(String tab) {
    selectedTab.value = tab;
  }

  void setRequestStatus(Status value) => requestStatus.value = value;

  /// Logout the user - clear all data and navigate to login screen
  void logout() async {
    try {
      setRequestStatus(Status.LOADING);

      // Clear all user data from SharedPreferences
      await userPreferences.removeUser();

      // Clear any cached controllers
      if (Get.isRegistered<HomeController>()) {
        Get.delete<HomeController>();
      }

      setRequestStatus(Status.COMPLETED);

      // Navigate to login screen and remove all previous routes
      Get.offAllNamed(RoutesName.loginScreen);

      Util.Snack_Bar("Success", "Logged out successfully");
    } catch (e) {
      setRequestStatus(Status.ERROR);
      Util.Snack_Bar("Error", "Logout failed: ${e.toString()}");
    }
  }

  void saveProfile() {
    // Validate all fields
    if (firstNameController.value.text.isEmpty) {
      Util.Snack_Bar("Warning", "Please enter your first name");
      return;
    }

    if (lastNameController.value.text.isEmpty) {
      Util.Snack_Bar("Warning", "Please enter your last name");
      return;
    }

    if (phoneController.value.text.isEmpty) {
      Util.Snack_Bar("Warning", "Please enter your phone number");
      return;
    }

    if (ageController.value.text.isEmpty) {
      Util.Snack_Bar("Warning", "Please enter your age");
      return;
    }

    // Validate age is a number and reasonable
    int? age = int.tryParse(ageController.value.text);
    if (age == null || age < 1 || age > 120) {
      Util.Snack_Bar("Warning", "Please enter a valid age (1-120)");
      return;
    }

    if (selectedConservation.value.isEmpty) {
      Util.Snack_Bar("Warning", "Please select your agent conservation mode");
      return;
    }

    if (selectedGender.value.isEmpty) {
      Util.Snack_Bar("Warning", "Please select your gender");
      return;
    }

    if (selectedLanguage.value.isEmpty) {
      Util.Snack_Bar("Warning", "Please select your language");
      return;
    }

    if (addressController.value.text.isEmpty) {
      Util.Snack_Bar("Warning", "Please enter your address");
      return;
    }

    // Only check terms acceptance during initial signup (when arguments != null)
    if (arguments != null && !acceptedTerms.value) {
      Util.Snack_Bar("Warning", "Please accept the terms and conditions");
      return;
    }

    setRequestStatus(Status.LOADING);

    Map data = {
      "first_name": firstNameController.value.text,
      "last_name": lastNameController.value.text,
      "phone_number": phoneController.value.text,
      "age": ageController.value.text,
      "gender": selectedGender.value == 'Male'
          ? 'M'
          : selectedGender.value == 'Female'
              ? 'F'
              : 'O',
      "address": addressController.value.text,
      "terms_and_conditions": acceptedTerms.value,
      "language": languageController.value.text,
      "agent_conservation_choice": selectedConservation.value == 'Short'
          ? 'S'
          : selectedConservation.value == 'Medium'
              ? 'M'
              : 'D',
      "unit_system": selectedUnitSystem.value,
    };
    print("the data is $data");

    _api.profileApi(data).then((value) {
      if (value['status'] == true) {
        setRequestStatus(Status.COMPLETED);
        if (arguments != null) {
          Get.toNamed(RoutesName.lifestyleHabitsScreen);
        } else {
          final homeController = Get.find<HomeController>();
          homeController.userProfile.value = UserProfile.fromJson(value);
          homeController.userProfile.refresh();
          // Refresh LiveKit token with new language setting
          homeController.livekitTokenApi();
          Util.Snack_Bar("Success", "Profile updated successfully");
        }
      } else {
        setRequestStatus(Status.COMPLETED);
        Util.Snack_Bar("Warning", value['result']['error']);
      }
    }).onError((error, stackTrace) {
      setRequestStatus(Status.ERROR);
      Util.Snack_Bar("Error", error.toString());
    });
  }

  @override
  void onClose() {
    // Dispose controllers
    firstNameController.value.dispose();
    lastNameController.value.dispose();
    phoneController.value.dispose();
    ageController.value.dispose();
    addressController.value.dispose();
    languageController.value.dispose();

    // Dispose focus nodes
    firstNameFocusNode.value.dispose();
    lastNameFocusNode.value.dispose();
    phoneFocusNode.value.dispose();
    ageFocusNode.value.dispose();
    addressFocusNode.value.dispose();

    super.onClose();
  }
}
