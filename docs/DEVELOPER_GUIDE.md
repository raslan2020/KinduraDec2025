# Kindura AI Developer Guide

**Version:** 1.0.0
**Last Updated:** 2025-12-13

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Project Structure](#project-structure)
4. [Flutter App (Frontend)](#flutter-app-frontend)
5. [Django Backend (API)](#django-backend-api)
6. [LiveKit Voice Agent](#livekit-voice-agent)
7. [Database Schema](#database-schema)
8. [API Reference](#api-reference)
9. [Development Setup](#development-setup)
10. [Key Patterns & Conventions](#key-patterns--conventions)
11. [Troubleshooting](#troubleshooting)

---

## Project Overview

**Kindura AI** is a comprehensive health and wellness mobile application with voice AI integration. The app helps patients:

- Track medications and adherence
- Upload and analyze medical reports (lab results, prescriptions)
- Monitor health vitals from Apple Watch
- Communicate with an AI health assistant via voice
- Generate daily/weekly/monthly health reports for doctors

### Core Components

| Component | Technology | Location |
|-----------|------------|----------|
| Mobile App | Flutter/Dart | `/lib/` |
| Backend API | Django/Python | `/KinduraAPIs-0.0.1/` |
| Voice Agent | LiveKit/Python | `/kinduralivekit-0.0.1/` |
| Database | PostgreSQL | Configured in Django settings |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          KINDURA AI ARCHITECTURE                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                      FLUTTER MOBILE APP                       │  │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────────────┐  │  │
│  │  │ Screens │──│Controllers│─│Repos   │──│NetworkApiServices│  │  │
│  │  │ (UI)    │  │(GetX)    │  │        │  │ (HTTP Client)   │  │  │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────────────┘  │  │
│  │       │                                          │            │  │
│  │       └────────────────────┬─────────────────────┘            │  │
│  │                            │                                  │  │
│  │  ┌─────────────────────────▼──────────────────────────────┐  │  │
│  │  │              LiveKit Client (Voice/Audio)               │  │  │
│  │  └─────────────────────────┬──────────────────────────────┘  │  │
│  └────────────────────────────│──────────────────────────────────┘  │
│                               │                                     │
│            ┌──────────────────┼──────────────────┐                  │
│            │                  │                  │                  │
│            ▼                  ▼                  ▼                  │
│  ┌──────────────────┐  ┌───────────────┐  ┌──────────────────────┐ │
│  │   DJANGO API     │  │ LIVEKIT CLOUD │  │  LIVEKIT AGENT       │ │
│  │  (REST Backend)  │  │(WebRTC Infra) │  │  (Python AI Agent)   │ │
│  │                  │  │               │  │                      │ │
│  │ - Users          │  │ - Audio/Video │  │ - OpenAI GPT-4o-mini │ │
│  │ - Medicines      │  │ - Rooms       │  │ - Function Tools     │ │
│  │ - Health Profile │  │ - Tokens      │  │ - STT/TTS            │ │
│  │ - Medical Reports│  └───────────────┘  │ - Patient Context    │ │
│  │ - Observations   │                     │                      │ │
│  │ - Patient Reports│◄────────────────────│ (API calls to Django)│ │
│  └────────┬─────────┘                     └──────────────────────┘ │
│           │                                                         │
│           ▼                                                         │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                      POSTGRESQL DATABASE                      │  │
│  │  Users, Medicines, MedicationEvents, PatientReports, etc.   │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **User Interaction** → Flutter UI screens
2. **State Management** → GetX controllers handle UI logic
3. **Data Layer** → Repositories abstract API calls
4. **Network** → `NetworkApiServices` makes HTTP requests to Django
5. **Voice** → LiveKit handles real-time audio; Agent processes speech

---

## Project Structure

```
Kinduraios/
├── lib/                              # Flutter app source code
│   ├── main.dart                     # App entry point
│   ├── common_widgets/               # Reusable UI components
│   ├── data/                         # Network & API layer
│   │   ├── network/                  # HTTP client services
│   │   └── response/                 # API response models
│   ├── models/                       # Data models (JSON serializable)
│   │   ├── medication/               # Medication tracking models
│   │   ├── medical_reports/          # Lab reports, biomarkers
│   │   ├── contact/                  # User contacts
│   │   └── user_profile/             # User profile data
│   ├── repository/                   # Data repositories
│   │   ├── medication_repository/    # Medication CRUD
│   │   ├── medical_reports_repository/ # Medical docs
│   │   └── home_repository/          # General APIs
│   ├── res/                          # Resources
│   │   ├── app_url/                  # API endpoints
│   │   ├── colors/                   # Theme colors
│   │   └── routes/                   # Navigation routes
│   ├── screens/                      # UI screens
│   │   ├── home/                     # Dashboard + LiveKit
│   │   ├── medication/               # Medication management
│   │   ├── meds_vitamin/             # Daily dose tracking
│   │   ├── labs/                     # Lab results view
│   │   ├── scan/                     # PDF upload
│   │   ├── profile/                  # User settings
│   │   └── kindura_reports/          # Patient reports
│   ├── services/                     # App services
│   │   ├── notification_service.dart # Push notifications
│   │   ├── voice_service.dart        # Voice trigger
│   │   └── theme_service.dart        # Dark/Light mode
│   └── utils/                        # Utilities
│
├── KinduraAPIs-0.0.1/               # Django backend
│   ├── manage.py                     # Django management
│   ├── medical_app/                  # Project settings
│   │   ├── settings.py               # Database, apps config
│   │   ├── urls.py                   # URL routing
│   │   └── asgi.py                   # WebSocket support
│   ├── users/                        # User management
│   │   ├── models.py                 # User, Token, PatientReport
│   │   ├── views.py                  # API endpoints
│   │   └── serializers.py            # Data serialization
│   ├── medicines/                    # Medication tracking
│   │   ├── models.py                 # Medicine, MedicationEvent
│   │   ├── views.py                  # CRUD endpoints
│   │   └── serializers.py
│   ├── health_profile/               # Health data
│   │   ├── models.py                 # Biomarkers, Vitals
│   │   └── views.py                  # Lab results API
│   ├── courses/                      # Medical documents
│   └── livekit_app/                  # LiveKit token generation
│
├── kinduralivekit-0.0.1/            # LiveKit voice agent
│   ├── agent.py                      # Main agent entry point
│   └── utils/
│       ├── global_variables.py       # Agent prompts, configs
│       ├── medication_api.py         # Medication API calls
│       ├── biomarkers_api.py         # Lab results API calls
│       ├── observations_api.py       # Health observations
│       ├── contacts_api.py           # User contacts
│       └── watch_vitals_api.py       # Apple Watch data
│
├── docs/                             # Documentation
│   ├── DEVELOPER_GUIDE.md            # This file
│   └── RAG_PLAN.md                   # Future RAG implementation
│
├── ios/                              # iOS native code
├── android/                          # Android native code
├── watchos/                          # Apple Watch app
│
├── setup_local.sh                    # Local dev setup script
├── startkindura.sh                   # Start all services
├── CLAUDE.md                         # AI assistant instructions
└── pubspec.yaml                      # Flutter dependencies
```

---

## Flutter App (Frontend)

### State Management: GetX

The app uses **GetX** for state management, dependency injection, and navigation.

#### Controller Pattern

```dart
// lib/screens/medication/medication_controller.dart

class MedicationController extends GetxController {
  // Observable state variables (reactive)
  final medications = <Medication>[].obs;
  final isLoading = false.obs;
  final error = ''.obs;

  // Dependency injection
  final MedicationRepository _repository = MedicationRepository();

  // Lifecycle hooks
  @override
  void onInit() {
    super.onInit();
    loadMedications();  // Load data on init
  }

  // Methods update state, which triggers UI rebuilds
  Future<void> loadMedications() async {
    isLoading.value = true;
    try {
      final result = await _repository.getMedications();
      medications.value = result;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}
```

#### Screen Pattern

```dart
// lib/screens/medication/medication_screen.dart

class MedicationScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Initialize controller
    final controller = Get.put(MedicationController());

    return Scaffold(
      body: Obx(() {  // Reactive UI updates
        if (controller.isLoading.value) {
          return LoadingIndicator();
        }
        return ListView.builder(
          itemCount: controller.medications.length,
          itemBuilder: (ctx, i) => MedicationCard(
            medication: controller.medications[i],
          ),
        );
      }),
    );
  }
}
```

### Network Layer

All API calls go through `NetworkApiServices`:

```dart
// lib/data/network/network_api_services.dart

class NetworkApiServices {
  // Builds headers with authentication token
  Future<Map<String, String>> buildHeaders({String? token}) async {
    final headers = {"Content-Type": "application/json"};
    if (token != null) {
      headers["Authorization"] = "Token $token";
    }
    return headers;
  }

  // GET request with optional query parameters
  Future<dynamic> getApi(String url, {String? token, Map<String, dynamic>? queryParameters});

  // POST request with JSON body
  Future<dynamic> postApi(var data, String url, {String? token});

  // File upload (multipart)
  Future<dynamic> uploadFileApi(File file, String url, {String? token});
}
```

### Repository Pattern

Repositories encapsulate data operations:

```dart
// lib/repository/medication_repository/medication_repository.dart

class MedicationRepository {
  final NetworkApiServices _networkApi = NetworkApiServices();

  // Get all medications for current user
  Future<List<Medication>> getMedications() async {
    final response = await _networkApi.getApi(AppUrl.medicationsUrl);
    if (response['status'] == true) {
      return (response['result'] as List)
          .map((json) => Medication.fromJson(json))
          .toList();
    }
    throw Exception(response['message']);
  }

  // Create dose event (taken/missed)
  Future<void> recordDoseEvent(String medicationId, String status) async {
    await _networkApi.postApi({
      'medication_id': medicationId,
      'status': status,
      'taken_at': DateTime.now().toIso8601String(),
    }, AppUrl.doseEventsUrl);
  }
}
```

### Model Serialization

Models use `json_annotation` for JSON serialization:

```dart
// lib/models/medication/medication_models.dart

@JsonSerializable()
class Medication {
  final String id;
  final String drugName;
  final String? brandName;
  final double strength;
  final String strengthUnit;
  final MedicationSchedule schedule;
  final bool isActive;

  // Generated factory
  factory Medication.fromJson(Map<String, dynamic> json)
      => _$MedicationFromJson(json);
  Map<String, dynamic> toJson() => _$MedicationToJson(this);
}
```

Run `flutter pub run build_runner build` to generate `.g.dart` files.

### Key Files Reference

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry point, registers services |
| `lib/res/app_url/app_url.dart` | API endpoint URLs |
| `lib/res/colors/app_color.dart` | Theme colors |
| `lib/screens/home/home_controller.dart` | Dashboard + LiveKit connection |
| `lib/screens/medication/medication_controller.dart` | Medication management |
| `lib/screens/meds_vitamin/meds_vitamin_screen.dart` | Daily dose tracking UI |
| `lib/data/network/network_api_services.dart` | HTTP client |

---

## Django Backend (API)

### Project Configuration

```python
# KinduraAPIs-0.0.1/medical_app/settings.py

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.getenv('DB_NAME', 'kindura_db'),
        'USER': os.getenv('DB_USER', 'kindura_user'),
        'PASSWORD': os.getenv('DB_PASSWORD', 'kindura_pass'),
        'HOST': os.getenv('DB_HOST', 'localhost'),
        'PORT': os.getenv('DB_PORT', '5432'),
    }
}
```

### Core Models

#### User Model (`users/models.py`)

```python
class User(AbstractUser):
    """Custom User model with health-specific fields"""
    email = models.EmailField(unique=True)
    phone_number = models.CharField(max_length=15, blank=True)
    language = models.CharField(default='en')
    gender = models.CharField(choices=GENDER_CHOICES)
    agent_conservation_choice = models.CharField(choices=['S', 'M', 'D'])
    unit_system = models.CharField(choices=['US', 'SI'], default='US')

    USERNAME_FIELD = 'email'  # Login with email

class UserToken(models.Model):
    """Token-based authentication with expiration"""
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    token = models.CharField(max_length=255, unique=True)
    expires_at = models.DateTimeField()
    is_active = models.BooleanField(default=True)

class PatientReport(models.Model):
    """AI-generated health reports (daily/weekly/monthly)"""
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    report_type = models.CharField(choices=['daily', 'weekly', 'monthly'])
    report_date = models.DateField()

    # Medication adherence
    total_doses_scheduled = models.IntegerField()
    doses_taken = models.IntegerField()
    adherence_percentage = models.FloatField()

    # AI-generated content
    ai_summary = models.TextField()
    ai_recommendations = models.TextField()
    ai_concerns = models.TextField()

class PatientObservation(models.Model):
    """Health observations from voice conversations"""
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    observation_type = models.CharField(choices=['medication', 'sleep', 'mood', 'symptom', ...])
    severity = models.CharField(choices=['normal', 'mild', 'moderate', 'severe'])
    title = models.CharField(max_length=200)
    description = models.TextField()
    observed_at = models.DateTimeField()

class Contact(models.Model):
    """User's emergency contacts and caregivers"""
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    name = models.CharField(max_length=100)
    contact_type = models.CharField(choices=['family', 'caregiver', 'doctor', ...])
    phone_number = models.CharField(max_length=20)
    is_emergency = models.BooleanField(default=False)
```

#### Medicine Model (`medicines/models.py`)

```python
class Medicine(models.Model):
    """Comprehensive medication tracking"""
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    drug_name = models.CharField(max_length=200)
    brand_name = models.CharField(max_length=200, blank=True)
    form = models.CharField(choices=['tablet', 'capsule', 'liquid', ...])
    strength = models.DecimalField(max_digits=10, decimal_places=2)
    strength_unit = models.CharField(choices=['mg', 'ml', 'units', ...])
    route = models.CharField(choices=['oral', 'injection', 'topical', ...])

    # Instructions
    instructions_text = models.TextField()
    take_with_food = models.BooleanField(null=True)
    as_needed = models.BooleanField(default=False)
    missed_dose_action = models.CharField(choices=[
        'skip_dose', 'take_asap', 'take_and_shift', 'contact_doctor', 'no_policy'
    ])

    # Schedule as JSON: {"times": ["08:00", "20:00"], "days": ["Mon", "Tue", ...]}
    schedule = models.JSONField()

    is_active = models.BooleanField(default=True)

class MedicationEvent(models.Model):
    """Dose tracking events"""
    medication = models.ForeignKey(Medicine, on_delete=models.CASCADE)
    scheduled_at = models.DateTimeField()
    taken_at = models.DateTimeField(null=True)
    status = models.CharField(choices=[
        'scheduled', 'taken', 'late', 'missed', 'skipped', 'snoozed'
    ])
    delay_minutes = models.IntegerField(null=True)
    side_effect_note = models.TextField(blank=True)
    source = models.CharField(choices=['patient', 'caregiver', 'voice', 'auto'])
```

### Authentication

The app uses token-based authentication:

```python
# utils/authentication.py

def get_user_from_token(request):
    """Extract user from Authorization header"""
    auth_header = request.headers.get('Authorization', '')
    if auth_header.startswith('Token '):
        token_key = auth_header.split(' ')[1]
        try:
            token = UserToken.objects.get(token=token_key, is_active=True)
            if token.is_valid():
                return token.user
        except UserToken.DoesNotExist:
            pass
    return None
```

### Key API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/users/signup/` | POST | Create new user |
| `/api/users/login/` | POST | Login, returns token |
| `/api/users/profile/` | GET | Get user profile |
| `/api/medicines/` | GET/POST | List/Create medications |
| `/api/medicines/<id>/` | PUT/DELETE | Update/Delete medication |
| `/api/dose-events/` | POST | Record dose taken/missed |
| `/api/dose-events/today/` | GET | Today's dose events |
| `/api/health-profile/biomarkers/` | GET | Lab results |
| `/api/medical-reports/documents/` | GET/POST | Medical documents |
| `/api/livekit-app/token/` | POST | Get LiveKit connection token |
| `/api/users/patient-reports/` | GET | Health reports |
| `/api/users/observations/` | POST | Save health observation |
| `/api/users/contacts/` | GET/POST | Emergency contacts |

---

## LiveKit Voice Agent

### Agent Entry Point

```python
# kinduralivekit-0.0.1/agent.py

from livekit import agents
from livekit.agents import AgentSession, function_tool
from livekit.plugins import openai, silero

async def entrypoint(ctx: agents.JobContext):
    """Main agent entry point - runs for each voice session"""

    # Get user context from room metadata
    room_metadata = ctx.room.metadata
    auth_token = room_metadata.get('auth_token')
    patient_name = room_metadata.get('name')

    # Build agent prompt with patient context
    prompt = build_agent_prompt(room_metadata)

    # Create agent session with OpenAI
    session = AgentSession(
        llm=openai.LLM(model="gpt-4o-mini"),
        stt=openai.STT(),  # Speech-to-text
        tts=openai.TTS(),  # Text-to-speech
        vad=silero.VAD.load(),  # Voice activity detection
    )

    # Register function tools
    session.register_tool(mark_medication_taken)
    session.register_tool(save_observation)
    session.register_tool(get_lab_results)
    # ... more tools

    # Start conversation
    await session.start(ctx.room)
    await session.say(f"Hello {patient_name}, how are you feeling today?")
```

### Function Tools

The agent can call these functions during conversation:

```python
@function_tool(description="Record that patient took their medication")
async def mark_medication_taken(
    medication_name: str,
    notes: str = "",
    taken_on_time: bool = True
) -> str:
    """
    IMPORTANT: Agent should NOT call this directly.
    Medication updates must be done by user in the app.
    """
    return ("I'm sorry, but I cannot mark medications as taken. "
            "Please use the Kindura app to record your doses.")

@function_tool(description="Save a health observation from conversation")
async def save_observation(
    observation_type: str,  # sleep, mood, symptom, etc.
    title: str,
    description: str,
    severity: str = "normal"
) -> str:
    """Save patient observation to database"""
    response = await http_client.post(
        f"{BASE_URL}/users/observations/",
        json={
            "observation_type": observation_type,
            "title": title,
            "description": description,
            "severity": severity,
        },
        headers={"Authorization": f"Token {auth_token}"}
    )
    return "I've recorded that observation in your health record."

@function_tool(description="Get patient's lab results")
async def get_lab_results(category: str = None) -> str:
    """Fetch biomarker data for patient"""
    response = await http_client.get(
        f"{BASE_URL}/health-profile/biomarkers/",
        params={"category": category} if category else {},
        headers={"Authorization": f"Token {auth_token}"}
    )
    return format_lab_results_for_speech(response.json())
```

### Agent Prompt

The agent prompt is in `kinduralivekit-0.0.1/utils/global_variables.py`:

```python
agent_prompt = """
You are Kindura AI, a helpful and empathetic digital health assistant...

Patient Context:
Patient Name: {patient_name}
Medicines: {medicines}
Medication Schedule: {schedules}
Current Time: {current_time}
Medical Reports: {medical_reports_summary}

Available Tools - YOU MUST USE THESE FUNCTIONS:
1. save_observation(type, title, description, severity)
2. get_lab_results(category)
3. save_sleep_report(hours, quality, notes)
4. save_mood_report(mood, notes)
...

CRITICAL: You CANNOT mark medications as taken. Direct users to the app.
"""
```

---

## Apple Watch & Apple Health Integration

### Overview

Kindura AI integrates with Apple Health and Apple Watch to provide real-time health monitoring. The system supports two data sources:

1. **Apple Watch** (via WatchConnectivity) - Real-time data from paired Apple Watch
2. **Apple Health** (via HealthKit) - Data from any HealthKit-compatible device (Watch, Oura, Whoop, etc.)

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    APPLE HEALTH INTEGRATION ARCHITECTURE                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────┐       ┌─────────────────┐       ┌───────────────┐ │
│  │   Apple Watch   │◄─────►│     iPhone      │◄─────►│  Apple Health │ │
│  │  (watchOS App)  │  WC   │  (Flutter App)  │  HK   │   Database    │ │
│  └────────┬────────┘       └────────┬────────┘       └───────────────┘ │
│           │                         │                                   │
│           │ WatchConnectivity       │ Method Channel                    │
│           │                         │                                   │
│           ▼                         ▼                                   │
│  ┌────────────────────────────────────────────────────────────────────┐│
│  │                    iOS Native (AppDelegate.swift)                   ││
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐ ││
│  │  │ WCSessionDelegate│  │   HKHealthStore │  │  FlutterMethodChannel│ ││
│  │  │ - Receive vitals│  │ - Query samples │  │ - Handle Flutter API│ ││
│  │  │ - Send config   │  │ - Request auth  │  │ - Return health data│ ││
│  │  └─────────────────┘  └─────────────────┘  └─────────────────────┘ ││
│  └────────────────────────────────────────────────────────────────────┘│
│                                    │                                    │
│                                    ▼                                    │
│  ┌────────────────────────────────────────────────────────────────────┐│
│  │                     Flutter (WatchVitalsService)                    ││
│  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────────────┐   ││
│  │  │ getLatestVitals│  │getHealthSummary│  │  getHealthHistory     │   ││
│  │  │               │  │               │  │  (for Vitals History) │   ││
│  │  └───────────────┘  └───────────────┘  └───────────────────────┘   ││
│  └────────────────────────────────────────────────────────────────────┘│
│                                    │                                    │
│                                    ▼                                    │
│  ┌────────────────────────────────────────────────────────────────────┐│
│  │                          Django API                                 ││
│  │              /api/watch-vitals/ - Store/retrieve vitals             ││
│  │           /api/watch-vitals/history/ - Historical data              ││
│  └────────────────────────────────────────────────────────────────────┘│
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘

Legend:
  WC = WatchConnectivity Framework
  HK = HealthKit Framework
```

### Data Flow

#### 1. Real-Time Updates (Home Widget)

```
User opens app
    │
    ▼
HomeController.onInit()
    │
    ├─► _startHealthDataRefresh()
    │       │
    │       └─► Timer.periodic(30 seconds)
    │               │
    │               └─► loadWatchVitals()
    │
    └─► loadWatchVitals()
            │
            ├─► 1. Try Django API (stored Watch data)
            │       └─► GET /api/watch-vitals/
            │
            └─► 2. Get Apple Health data
                    │
                    └─► WatchVitalsService.getComprehensiveHealth()
                            │
                            └─► Native iOS: getHealthSummary()
                                    │
                                    ├─► fetchLatestQuantity(.heartRate)
                                    ├─► fetchLatestQuantity(.oxygenSaturation)
                                    ├─► fetchLatestQuantity(.heartRateVariabilitySDNN)
                                    ├─► fetchTodayQuantity(.stepCount)
                                    ├─► fetchTodayQuantity(.activeEnergyBurned)
                                    ├─► fetchLastNightSleep()
                                    └─► ... other health metrics
```

#### 2. Vitals History Screen

```
User opens Vitals History
    │
    ▼
VitalsHistoryController.loadHistory()
    │
    ├─► 1. Try Django API first
    │       └─► GET /api/watch-vitals/history/?days=N
    │               │
    │               └─► If data → Display it (dataSource = 'api')
    │
    └─► 2. If API empty → Fall back to Apple Health
            │
            └─► WatchVitalsService.getHealthHistory(days)
                    │
                    └─► Native iOS: getHealthHistory(days:)
                            │
                            ├─► fetchQuantitySamples(.heartRate)
                            ├─► fetchQuantitySamples(.oxygenSaturation)
                            ├─► fetchQuantitySamples(.heartRateVariabilitySDNN)
                            └─► fetchSleepHistory()
                                    │
                                    └─► _convertHealthDataToVitals()
                                            │
                                            └─► Display (dataSource = 'apple_health')
```

#### 3. Apple Watch → iPhone → Django

```
Apple Watch (watchOS app)
    │
    └─► Collects real-time vitals
            │
            ▼
    WCSession.sendMessage()
            │
            ▼
iPhone AppDelegate (WCSessionDelegate)
    │
    └─► session(_ session:, didReceiveMessage:)
            │
            ├─► Update latestWatchVitals
            │
            └─► Forward to Flutter via MethodChannel
                    │
                    ▼
            Flutter WatchVitalsService
                    │
                    └─► _sendVitalsToAPI()
                            │
                            └─► POST /api/watch-vitals/
                                    │
                                    └─► Store in PostgreSQL
```

### Key Files

#### iOS Native Layer

| File | Purpose |
|------|---------|
| `ios/Runner/AppDelegate.swift` | Central hub for Watch/HealthKit integration |
| `watchos/KinduraWatch/HealthManager.swift` | Watch-side health data collection |
| `watchos/KinduraWatch/ContentView.swift` | Watch app UI |

#### Flutter Service Layer

| File | Purpose |
|------|---------|
| `lib/services/watch_vitals_service.dart` | Flutter interface to native health APIs |
| `lib/screens/home/home_controller.dart` | Home screen health data management |
| `lib/screens/vitals_history/vitals_history_controller.dart` | Historical data with Apple Health fallback |

### iOS Native Methods (AppDelegate.swift)

```swift
// Method Channel: "com.kindura.ai/watch_vitals"

// Get real-time vitals from Apple Health
case "getHealthSummary":
    // Returns: heart_rate, blood_oxygen, hrv, respiratory_rate,
    //          steps, calories, sleep_hours, sleep_stages, etc.

// Get historical data for N days
case "getHealthHistory":
    // Parameters: {"days": 7}
    // Returns: Array of samples with type, value, timestamp

// Check/request HealthKit permissions
case "requestHealthKitAuthorization":
case "isHealthKitAuthorized":

// Watch connectivity status
case "isWatchPaired":
case "isWatchReachable":

// Sync configuration to Watch
case "updateWatchConfiguration":
    // Sends API baseURL and auth token to Watch
```

### Flutter Service API

```dart
class WatchVitalsService {
  // Real-time health summary (for home widget)
  Future<Map<String, dynamic>?> getHealthSummary();
  Future<Map<String, dynamic>?> getComprehensiveHealth();

  // Historical data (for vitals history)
  Future<List<Map<String, dynamic>>?> getHealthHistory(int days);

  // Period summaries
  Future<Map<String, dynamic>?> getWeeklySummary();
  Future<Map<String, dynamic>?> getMonthlySummary();

  // HealthKit authorization
  Future<bool> requestHealthKitAuthorization();
  Future<bool> isHealthKitAuthorized();

  // Watch status
  Future<bool> isWatchPaired();
  Future<bool> isWatchReachable();
  Future<Map<String, dynamic>> getWatchStatus();
}
```

### Health Data Types Collected

| Category | Data Type | Source | Frequency |
|----------|-----------|--------|-----------|
| **Vitals** | Heart Rate | Watch/Health | Latest sample |
| | Blood Oxygen | Watch/Health | Latest sample |
| | HRV | Watch/Health | Latest sample |
| | Respiratory Rate | Watch/Health | Latest sample |
| | Resting Heart Rate | Health | Daily average |
| **Sleep** | Sleep Duration | Watch/Health | Last night |
| | Sleep Stages (Deep/REM/Core/Awake) | Watch/Health | Last night |
| | Sleep Score | Calculated | Last night |
| **Activity** | Steps | Watch/Health | Today's total |
| | Active Calories | Watch/Health | Today's total |
| | Distance | Watch/Health | Today's total |
| | Exercise Minutes | Watch/Health | Today's total |
| | Floors Climbed | Watch/Health | Today's total |
| **Other** | Blood Pressure | Health | Latest reading |
| | Audio Exposure | Health | Today's average |
| | Workouts | Watch/Health | Today's list |
| | AFib History | Watch/Health | All time |
| | Fall Detection | Watch | Event-based |

### HealthKit Authorization

Required entitlement in `ios/Runner/Runner.entitlements`:
```xml
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.healthkit.access</key>
<array/>
```

Required in `Info.plist`:
```xml
<key>NSHealthShareUsageDescription</key>
<string>Kindura needs access to your health data to track vitals, sleep patterns, and activity levels for your health dashboard.</string>
```

### Periodic Refresh Mechanism

The home widget automatically refreshes health data every 30 seconds:

```dart
// lib/screens/home/home_controller.dart

Timer? _healthRefreshTimer;

void _startHealthDataRefresh() {
  // Initial load
  loadWatchVitals();

  // Refresh every 30 seconds
  _healthRefreshTimer = Timer.periodic(
    const Duration(seconds: 30),
    (_) => loadWatchVitals(),
  );
}

@override
void onClose() {
  _healthRefreshTimer?.cancel();
  super.onClose();
}
```

### Fall Detection Flow

```
Apple Watch detects fall
    │
    ▼
WatchOS app sends fall event via WCSession
    │
    ▼
AppDelegate receives via didReceiveMessage
    │
    └─► Forward to Flutter via MethodChannel
            │
            ▼
    WatchVitalsService.onFallDetected callback
            │
            ▼
    HomeController._handleFallDetection()
            │
            ├─► Show alert dialog to user
            ├─► Send fall event to Django API
            └─► Notify emergency contacts (if configured)
```

### Debugging Health Data

Enable logging in AppDelegate.swift to trace data flow:

```swift
print("[AppDelegate] getHealthSummary called")
print("[AppDelegate] Heart rate fetched: \(value)")
print("[AppDelegate] Health data complete - HR: \(hr), O2: \(o2)")
```

Check Xcode console for these logs during development.

### Testing Without Apple Watch

The app works without an Apple Watch by reading from Apple Health directly. To test:

1. Open Apple Health app on iPhone
2. Add sample data manually (Profile → Health Details → Edit)
3. Kindura will read this data via HealthKit

Alternatively, use the iOS Simulator with simulated health data.

---

## Database Schema

### Entity Relationship Diagram

```
┌──────────────┐       ┌───────────────────┐       ┌─────────────────┐
│     User     │       │     Medicine      │       │ MedicationEvent │
├──────────────┤       ├───────────────────┤       ├─────────────────┤
│ id           │◄──────│ user_id (FK)      │◄──────│ medication_id(FK)│
│ email        │       │ drug_name         │       │ scheduled_at    │
│ first_name   │       │ brand_name        │       │ taken_at        │
│ language     │       │ strength          │       │ status          │
│ gender       │       │ schedule (JSON)   │       │ delay_minutes   │
│ unit_system  │       │ is_active         │       │ source          │
└──────────────┘       └───────────────────┘       └─────────────────┘
       │
       │       ┌───────────────────┐       ┌─────────────────────┐
       ├──────►│   PatientReport   │       │ PatientObservation  │
       │       ├───────────────────┤       ├─────────────────────┤
       │       │ user_id (FK)      │       │ user_id (FK)        │
       │       │ report_type       │       │ observation_type    │
       │       │ report_date       │       │ title               │
       │       │ adherence_%       │       │ description         │
       │       │ ai_summary        │       │ severity            │
       │       │ ai_recommendations│       │ observed_at         │
       │       └───────────────────┘       └─────────────────────┘
       │
       │       ┌───────────────────┐       ┌─────────────────────┐
       └──────►│     Contact       │       │    WatchVitals      │
               ├───────────────────┤       ├─────────────────────┤
               │ user_id (FK)      │       │ user_id (FK)        │
               │ name              │       │ heart_rate          │
               │ phone_number      │       │ blood_oxygen        │
               │ contact_type      │       │ sleep_hours         │
               │ is_emergency      │       │ recorded_at         │
               └───────────────────┘       └─────────────────────┘
```

---

## Development Setup

### Prerequisites

- **macOS** (for iOS development)
- **Flutter SDK** 3.x
- **Python** 3.11+
- **PostgreSQL** 15+
- **Xcode** (for iOS)

### Quick Start

```bash
# 1. Clone repository
git clone <repo-url>
cd Kinduraios

# 2. Run setup script (creates DB, venv, test user)
./setup_local.sh

# 3. Start all services
./startkindura.sh
```

This starts:
- PostgreSQL database
- Django API server (port 8000)
- LiveKit agent
- Flutter app on iOS Simulator

### Manual Setup

```bash
# Create Python virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install Django dependencies
cd KinduraAPIs-0.0.1
pip install -r requirements.txt

# Run migrations
python manage.py migrate

# Create superuser
python manage.py createsuperuser

# Start Django
python manage.py runserver

# In another terminal, start LiveKit agent
cd kinduralivekit-0.0.1
python agent.py dev

# In another terminal, start Flutter
flutter pub get
flutter run
```

### Environment Variables

Create `.env.local` in project root:

```bash
# Database
DB_NAME=kindura_db
DB_USER=kindura_user
DB_PASSWORD=kindura_pass
DB_HOST=localhost
DB_PORT=5432

# API
API_BASE_URL=http://127.0.0.1:8000/api

# LiveKit
LIVEKIT_URL=wss://your-livekit-cloud.livekit.cloud
LIVEKIT_API_KEY=your_api_key
LIVEKIT_API_SECRET=your_api_secret

# OpenAI (for voice agent)
OPENAI_API_KEY=your_openai_key

# Auth token for local testing
LOCAL_DEV_TOKEN=your_test_token
```

---

## Key Patterns & Conventions

### 1. Dark Theme Support

Always check theme and use appropriate colors:

```dart
@override
Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
  final textColor = isDark ? Colors.white : Colors.black;

  return Container(
    color: cardBg,
    child: Text("Hello", style: TextStyle(color: textColor)),
  );
}
```

### 2. API Response Pattern

Use the `ApiResponse` wrapper with `.when()`:

```dart
Obx(() => apiResponse.when(
  loading: () => LoadingIndicator(),
  completed: (data) => DataWidget(data: data),
  error: (error) => ErrorWidget(message: error),
)),
```

### 3. Error Handling

Always handle errors gracefully:

```dart
try {
  final result = await repository.fetchData();
  // Handle success
} catch (e) {
  // Log error
  print("Error fetching data: $e");
  // Show user-friendly message
  Util.Snack_Bar("Error", "Something went wrong. Please try again.");
}
```

### 4. Parameter Order in API Calls

Data comes before URL:

```dart
// Correct
await networkApi.postApi(data, url);
await networkApi.putApi(data, url);

// Wrong
await networkApi.postApi(url, data);  // Don't do this!
```

### 5. DoseStatus Enum Comparison

Use enum values, not strings:

```dart
// Correct
if (event.status == DoseStatus.taken) { ... }

// Wrong
if (event.status == 'taken') { ... }  // String comparison fails!
```

### 6. Toon Format (Token-Optimized JSON)

When working with AI/embeddings, use short keys:

```json
{"id":1,"y":"msg","r":"u","t":1739627000,"c":"Hello","m":{}}
```

Key reference:
- `id` = identifier
- `r` = role (u=user, a=assistant)
- `c` = content
- `t` = timestamp
- `y` = type

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| `Colors` not found | Add `import 'package:flutter/material.dart';` |
| API returns 401 | Check token in `.env.local`, ensure not expired |
| LiveKit no audio | Set `speakerOn: true` in RoomOptions |
| Enum comparison fails | Use `DoseStatus.taken` not `'taken'` |
| Database connection error | Run `brew services start postgresql@15` |
| Voice trigger not working | Fuzzy match phrases in home_controller.dart |
| Build runner fails | Run `flutter clean && flutter pub get` |

### Debug Mode

Triple-tap the home icon to show performance debug widget.

### Logs

- **Flutter**: `print()` → Xcode/Android Studio console
- **Django**: Check terminal running `manage.py runserver`
- **LiveKit Agent**: Check terminal running `agent.py`
- **File logs**: `Documents/kindura_logs/` on device

---

## Contributing

1. Create feature branch from `dev`
2. Follow code patterns above
3. Update `changes.md` with your changes
4. Submit PR to `dev` branch

---

## Support

- **Issues**: https://github.com/anthropics/claude-code/issues
- **CLAUDE.md**: AI assistant instructions for codebase
