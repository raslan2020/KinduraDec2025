# Kindura AI - Flutter Mobile App

**Version:** 1.0.1  
**Flutter SDK:** 2.19.2 - 3.0.0

## Overview

Kindura AI is a comprehensive health and wellness mobile application built with Flutter. It helps patients track medications, manage health data, and communicate with an AI voice assistant.

## Features

- **🏠 Health Dashboard**: Overview of health metrics and daily activities
- **💊 Medication Management**: Track medications, schedules, and adherence
- **📋 Medical Reports**: Upload and view lab results and medical documents
- **🔬 Lab Results (Biomarkers)**: View and track biomarker values with insights
- **🎤 Voice AI Integration**: LiveKit-powered voice assistant for hands-free interaction
- **⌚ Apple Watch Integration**: Sync vitals from watchOS companion app
- **📊 Health Reports**: AI-generated daily/weekly/monthly reports
- **🌙 Dark Mode**: Full dark theme support

## Architecture

```
lib/
├── main.dart                 # App entry point
├── common_widgets/           # Reusable UI components
├── config/                   # Local configuration
├── data/                     # Network & API layer
│   ├── network/              # HTTP client services
│   └── response/             # API response models
├── models/                   # Data models (JSON serializable)
│   ├── biomarkers/           # Lab results models
│   ├── medication/           # Medication tracking models
│   ├── medical_reports/      # Medical document models
│   └── user_profile/         # User profile data
├── repository/               # Data repositories (CRUD operations)
├── res/                      # Resources (colors, routes, URLs)
├── screens/                  # UI screens
│   ├── home/                 # Dashboard + LiveKit voice
│   ├── medication/           # Medication management
│   ├── meds_vitamin/         # Daily dose tracking
│   ├── labs/                 # Lab results view
│   ├── medical_reports/      # Medical documents
│   ├── profile/              # User settings
│   └── kindura_reports/      # AI health reports
├── services/                 # App services
│   ├── notification_service.dart
│   ├── voice_service.dart
│   └── theme_service.dart
└── utils/                    # Utilities
```

## Tech Stack

- **State Management**: GetX
- **Voice Communication**: LiveKit Client
- **HTTP Client**: http package
- **Local Storage**: SharedPreferences
- **Charts**: fl_chart
- **JSON Serialization**: json_annotation + build_runner

## Dependencies

Key dependencies from `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  get: ^4.6.5                    # State management
  livekit_client: ^2.4.3         # Voice AI
  http: ^1.4.0                   # HTTP client
  flutter_screenutil: ^5.7.0     # Responsive design
  fl_chart: ^0.69.0              # Health charts
  speech_to_text: ^7.2.0         # Voice triggers
  json_annotation: ^4.8.1        # JSON serialization
```

## Getting Started

### Prerequisites

- Flutter SDK 2.19.2+
- Xcode (for iOS development)
- Android Studio (for Android development)
- CocoaPods (for iOS dependencies)

### Setup

1. **Install Flutter dependencies**
   ```bash
   cd flutter
   flutter pub get
   ```

2. **Generate JSON serialization files**
   ```bash
   flutter pub run build_runner build
   ```

3. **Configure environment**
   
   Create `.env.local` in the project root with:
   ```
   LOCAL_DEV_TOKEN=your_auth_token
   ```

4. **Update API URL**
   
   Edit `lib/res/app_url/app_url.dart`:
   ```dart
   static const bool isLocalEnvironment = true; // For local development
   ```

5. **iOS Setup**
   ```bash
   cd ios
   pod install
   cd ..
   ```

6. **Run the app**
   ```bash
   flutter run
   ```

## Key Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry point, service registration |
| `lib/res/app_url/app_url.dart` | API endpoint URLs |
| `lib/res/colors/app_color.dart` | Theme colors |
| `lib/screens/home/home_controller.dart` | Dashboard + LiveKit |
| `lib/data/network/network_api_services.dart` | HTTP client |

## Design System

- **Primary Color**: `#2563EB` (Blue 600)
- **Typography**: Urbanist font family
- **Cards**: 12px rounded corners, subtle borders
- **Buttons**: Flat design, 8px radius

## State Management Pattern

```dart
class MedicationController extends GetxController {
  // Observable state
  final medications = <Medication>[].obs;
  final isLoading = false.obs;
  
  @override
  void onInit() {
    super.onInit();
    loadMedications();
  }
  
  Future<void> loadMedications() async {
    isLoading.value = true;
    try {
      final result = await _repository.getMedications();
      medications.value = result;
    } finally {
      isLoading.value = false;
    }
  }
}
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `Colors` not found | Add `import 'package:flutter/material.dart';` |
| API returns 401 | Check token in `.env.local` |
| LiveKit no audio | Set `speakerOn: true` in RoomOptions |
| Build runner fails | Run `flutter clean && flutter pub get` |

## Related Components

- **Backend API**: See `../django/` for Django REST API
- **Voice Agent**: See `../livekit/` for LiveKit agent
- **Apple Watch**: See `watchos/` for watchOS companion app

