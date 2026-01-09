# Kindura AI - Complete Project Handover Documentation

**Last Updated**: 2026-01-02

## Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Repository Structure](#repository-structure)
4. [Setup Instructions](#setup-instructions)
5. [Running the Application](#running-the-application)
6. [Key Features](#key-features)
7. [Health Data Architecture](#health-data-architecture)
8. [Language Support](#language-support)
9. [API Documentation](#api-documentation)
10. [Troubleshooting](#troubleshooting)
11. [Development Guidelines](#development-guidelines)
12. [Recent Changes](#recent-changes)

---

## Project Overview

Kindura AI is a health and wellness application that provides AI-powered voice assistance for patients with medical conditions. The system consists of four main components:

1. **Flutter Mobile App** - iOS client application
2. **Django REST API** - Backend server for data management
3. **LiveKit Agent** - Real-time voice communication with AI
4. **Apple Watch App** - Real-time vitals monitoring & fall detection

### Key Technologies
- **Frontend**: Flutter, GetX state management, LiveKit client SDK
- **Backend**: Django REST Framework, PostgreSQL database
- **AI Agent**: Python, LiveKit SDK, OpenAI GPT-4, Deepgram/OpenAI Whisper STT/TTS
- **Real-time Communication**: LiveKit WebRTC platform
- **Health Data**: Apple HealthKit, WatchConnectivity (WCSession)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Apple Watch App                             │
│  (watchOS - Real-time vitals, Fall detection, HKWorkoutSession) │
└────────────┬────────────────────────────────────────────────────┘
             │ WCSession
             ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Flutter Mobile App (iOS)                     │
│  (Voice activation, UI, LiveKit client, HealthKit integration)  │
└────────────┬─────────────────────────┬──────────────────────────┘
             │                         │
             │ HTTP/REST               │ WebRTC/WebSocket
             │                         │
┌────────────▼─────────────┐ ┌────────▼──────────────────────────┐
│   Django REST API        │ │    LiveKit Cloud Server           │
│  (localhost:8000)        │ │  (wss://kindura-u99yilqz...)      │
└────────────┬─────────────┘ └────────┬──────────────────────────┘
             │                         │
┌────────────▼─────────────┐ ┌────────▼──────────────────────────┐
│   PostgreSQL Database    │ │    LiveKit Python Agent           │
│  (kindura_db)            │ │  (AI conversation handler)        │
└──────────────────────────┘ └───────────────────────────────────┘
```

### Health Data Flow
```
┌─────────────────────────────────────────────────────────────┐
│                   PRIMARY: Apple Health (HealthKit)          │
│  - Always the main data source                               │
│  - Works with Oura, Whoop, Ultrahuman, and any HealthKit app│
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│           SECONDARY: Apple Watch (if paired)                 │
│  - Real-time vitals updates via WCSession                   │
│  - Fall detection (Watch-exclusive feature)                  │
│  - Supplements HealthKit data, doesn't replace it           │
└─────────────────────────────────────────────────────────────┘
```

### Voice Activation Flow
1. User speaks trigger phrase ("hey kindura") → Flutter app detects
2. App requests LiveKit token from Django API
3. App connects to LiveKit room
4. LiveKit Agent joins room and starts conversation
5. Real-time audio streaming between app and agent
6. Agent uses GPT-4 for responses, STT/TTS for audio processing

### Health Update Triggers
1. **Apple Watch**: WCSession message (real-time on significant change)
2. **HealthKit Observer**: HKObserverQuery fires when data changes
3. **Manual Refresh**: User pull-to-refresh

---

## Repository Structure

```
Kinduraios/                     # Main Flutter project
├── lib/
│   ├── screens/               # UI screens and controllers
│   │   ├── home/             # Home screen with health dashboard
│   │   ├── profile/          # User profile and settings
│   │   ├── medication/       # Medication tracking
│   │   ├── labs/             # Lab reports & biomarkers
│   │   ├── vitals_history/   # Historical health data
│   │   └── login/            # Authentication
│   ├── models/               # Data models (health, medication, etc.)
│   ├── repository/           # API communication layer
│   ├── services/             # App services
│   │   ├── watch_vitals_service.dart  # Native bridge for Watch/HealthKit
│   │   ├── notification_service.dart  # Local notifications
│   │   └── voice_service.dart         # Speech recognition
│   ├── res/
│   │   ├── app_url/          # API endpoints configuration
│   │   └── routes/           # Navigation routes
│   └── user_preference/      # Local storage management
├── ios/
│   └── Runner/
│       └── AppDelegate.swift  # WatchConnectivity, HealthKit observers
├── watchos/                   # Apple Watch app
│   └── KinduraWatch/
│       ├── KinduraWatchApp.swift
│       ├── HealthManager.swift  # Watch health data collection
│       └── ContentView.swift
├── startkindura.sh           # Quick start script (all services)
├── setup_local.sh            # Local development setup
└── pubspec.yaml              # Flutter dependencies

KinduraAPIs-0.0.1/             # Django backend
├── medical_app/
│   ├── settings.py           # Django configuration (PostgreSQL)
│   └── urls.py              # Main URL routing
├── users/                    # User management app
├── medicines/                # Medication management
├── health_profile/           # Health profile management
├── medical_reports/          # Lab reports & documents
├── livekit_app/              # LiveKit integration
├── manage.py                 # Django management script
├── requirements.txt          # Python dependencies
└── .env                     # Environment variables

kinduralivekit-0.0.1/          # LiveKit Agent
├── agent.py                  # Main agent script
├── utils/
│   ├── global_variables.py  # Prompts and configurations
│   ├── watch_vitals_api.py  # Agent access to health data
│   └── language_config.py   # Modular language configuration
├── user_logs/               # Conversation transcripts
├── requirements.txt         # Python dependencies
└── .env                     # Environment variables
```

---

## Setup Instructions

### Prerequisites
- **macOS** (required for iOS/watchOS development)
- **Flutter SDK** 3.x or higher
- **Python** 3.11 or higher
- **Xcode** 15+ (for iOS/watchOS)
- **PostgreSQL** 15 (via Homebrew)
- **Git**

### Quick Start (Recommended)

```bash
# First time setup (installs PostgreSQL, creates database, test user)
./setup_local.sh

# Start all services (PostgreSQL, Django API, LiveKit, Flutter)
./startkindura.sh
```

### Manual Setup

#### 1. Clone the Repository
```bash
git clone <repository-url>
cd Kinduraios
```

#### 2. Setup PostgreSQL Database

```bash
# Install PostgreSQL
brew install postgresql@15
brew services start postgresql@15

# Create database and user
/opt/homebrew/opt/postgresql@15/bin/createdb kindura_db
/opt/homebrew/opt/postgresql@15/bin/psql -d kindura_db -c "CREATE USER kindura_user WITH PASSWORD 'kindura_pass';"
/opt/homebrew/opt/postgresql@15/bin/psql -d kindura_db -c "GRANT ALL PRIVILEGES ON DATABASE kindura_db TO kindura_user;"
/opt/homebrew/opt/postgresql@15/bin/psql -d kindura_db -c "ALTER ROLE kindura_user SET default_transaction_isolation TO 'read committed';"
/opt/homebrew/opt/postgresql@15/bin/psql -d kindura_db -c "ALTER ROLE kindura_user SET timezone TO 'UTC';"
```

#### 3. Setup Django Backend

```bash
cd KinduraAPIs-0.0.1

# Create virtual environment
python3.11 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run migrations
python manage.py migrate

# Create test user (or use setup_local.sh)
python manage.py createsuperuser

# Start server
python manage.py runserver 0.0.0.0:8000
```

#### 4. Setup LiveKit Agent

```bash
cd kinduralivekit-0.0.1

# Create virtual environment
python3.11 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Create .env file with your API keys
cat > .env << 'EOF'
LIVEKIT_URL=wss://kindura-u99yilqz.livekit.cloud
LIVEKIT_API_KEY=<your-key>
LIVEKIT_API_SECRET=<your-secret>
OPENAI_API_KEY=<your-openai-key>
DEEPGRAM_API_KEY=<your-deepgram-key>
EOF

# Run agent
python agent.py dev
```

#### 5. Setup Flutter App

```bash
cd Kinduraios

# Install Flutter dependencies
flutter pub get

# Configure for local development
# Edit lib/res/app_url/app_url.dart:
# Set: static const bool isLocalEnvironment = true;

# For iOS setup
cd ios && pod install && cd ..

# Run on iOS simulator
flutter run -d <device-id>
```

### Environment Configuration

**`.env.local`** - Auto-generated by `setup_local.sh`:
```bash
LOCAL_DEV_TOKEN=<your_token_here>
DB_NAME=kindura_db
DB_USER=kindura_user
DB_PASSWORD=kindura_pass
```

### PostgreSQL Management

```bash
# Start/Stop PostgreSQL
brew services start postgresql@15
brew services stop postgresql@15

# Access database directly
/opt/homebrew/opt/postgresql@15/bin/psql -d kindura_db

# Reset database
/opt/homebrew/opt/postgresql@15/bin/dropdb kindura_db
/opt/homebrew/opt/postgresql@15/bin/createdb kindura_db
cd KinduraAPIs-0.0.1 && ../.venv/bin/python manage.py migrate
```

---

## Running the Application

### Starting All Services (Recommended Order)

1. **Start Django Backend**
```bash
cd KinduraAPIs-0.0.1
source venv/bin/activate
python manage.py runserver
# Server runs on http://localhost:8000
```

2. **Start LiveKit Agent**
```bash
cd kinduralivekit-0.0.1
source venv/bin/activate
python agent.py dev
# Agent registers with LiveKit cloud
```

3. **Start Flutter App**
```bash
cd Kinduraios
flutter run -d <device-id>
# App launches on selected device
```

### Development Commands

**Flutter:**
```bash
flutter run                  # Run in debug mode
flutter run --release        # Run in release mode
flutter build apk           # Build Android APK
flutter build ios           # Build iOS app
flutter analyze             # Run static analysis
flutter test               # Run tests
```

**Django:**
```bash
python manage.py runserver              # Start development server
python manage.py makemigrations        # Create migrations
python manage.py migrate               # Apply migrations
python manage.py shell                 # Django shell
python manage.py test                  # Run tests
```

---

## Key Features

### 1. Voice Activation
- **Trigger Phrases**: "hey kindura", "hey candura", "hey kendra", "hey kundura"
- **Implementation**: `lib/screens/home/home_controller.dart`
- Speech recognition runs continuously in background
- Automatic connection to LiveKit on trigger detection

### 2. User Authentication
- Token-based authentication
- Login/Signup endpoints: `/api/users/login/`, `/api/users/signup/`
- Token stored in SharedPreferences
- Auto-logout functionality

### 3. Health Profile Management
- User medical information storage
- Profile endpoint: `/api/health-profile/profile/`
- Language preference selection
- Agent conversation mode settings (Short/Medium/Detailed)

### 4. Medical Courses
- Active course tracking
- Medicine schedules
- Doctor instructions
- Endpoints: `/api/courses/`, `/api/courses/get_current_course/`

### 5. Real-time Voice Communication
- WebRTC-based audio streaming
- Automatic room creation/deletion
- Transcription display
- Connection state management

### 6. Health Data Integration
- HealthKit integration for vitals, sleep, activity
- Apple Watch real-time sync via WCSession
- Event-driven updates (no polling)
- Multi-device support (Oura, Whoop, Ultrahuman via HealthKit)

---

## Health Data Architecture

### Data Source Modes

The app supports multiple health data sources via `DataSourceMode`:

| Mode | Description | Features |
|------|-------------|----------|
| `appleWatch` | Watch paired, use WCSession + HealthKit | Full real-time vitals, fall detection |
| `healthKitOnly` | No Watch, use HealthKit only | Works with Oura, Whoop, Ultrahuman |
| `manualOnly` | User enters data manually | No automatic data collection |

### HealthKit Observers

The app uses `HKObserverQuery` for event-driven updates (no polling):

- **Heart Rate** (`heartRate`)
- **Blood Oxygen** (`oxygenSaturation`)
- **HRV** (`heartRateVariabilitySDNN`)
- **Respiratory Rate** (`respiratoryRate`)
- **Steps** (`stepCount`)
- **Sleep** (`sleepAnalysis`)

All observers have background delivery enabled with 5-second debounce.

### Key Files

| File | Purpose |
|------|---------|
| `ios/Runner/AppDelegate.swift` | WatchConnectivity, HealthKit observers, method channels |
| `watchos/KinduraWatch/HealthManager.swift` | Watch health data collection, HKWorkoutSession |
| `lib/services/watch_vitals_service.dart` | Flutter native bridge service |
| `lib/screens/home/home_controller.dart` | Health state management |
| `lib/models/health/data_source_mode.dart` | DataSourceMode enum |

### Watch Real-Time Vitals

Apple Watch sends vitals immediately when values change significantly:
- Heart rate: 2+ BPM change
- Blood oxygen: 1%+ change
- HRV: 2+ ms change
- Respiratory rate: 0.5+ br/m change

### PostgreSQL Health Tables

- `health_heart_rate_history`
- `health_blood_oxygen_history`
- `health_hrv_history`
- `health_sleep_history`
- `health_activity_history`

**API Endpoints**:
- `POST /api/health-history/batch/` - Bulk save health records
- `GET /api/health-history/` - Retrieve with day/week/month grouping

---

## Language Support

### Supported Languages

The system supports dynamic language switching with different STT/TTS providers:

#### Currently Configured:
- **English (en)**: Deepgram STT/TTS
- **Arabic (ar)**: OpenAI Whisper STT, OpenAI TTS (nova voice)
- **Arabic Lebanese (ar-LB)**: OpenAI Whisper STT, OpenAI TTS (shimmer voice)

#### Voice Configuration (agent.py):
```python
if language == 'ar-LB':
    voice_choice = "shimmer"  # Softer, expressive voice
else:
    voice_choice = "nova"     # Natural, lighter voice
```

### Adding New Languages

1. **Update Flutter Profile Controller** (`lib/screens/profile/profile_controller.dart`):
```dart
final Map<String, dynamic> languages = {
    "Arabic": "ar",
    "Arabic (Lebanese)": "ar-LB",
    "Spanish": "es",  // Add new language
    // ...
};
```

2. **Update Agent Language Configuration** (`kinduralivekit-0.0.1/agent.py`):
```python
elif language == 'es':
    stt_engine = deepgram.STT(language='es')
    tts_engine = deepgram.TTS()
```

3. **Add Language-Specific Prompts** (`utils/global_variables.py`):
```python
greeting_msg_language = {
    "es": "Hola, ¿cómo estás hoy?",
    # ...
}
```

---

## API Documentation

### Base URL
- **Production**: `http://65.109.75.25:8000/api`
- **Development**: `http://localhost:8000/api`

### Authentication
All authenticated endpoints require:
```
Authorization: Token <user-token>
```

### Key Endpoints

#### User Management
- `POST /users/login/` - User login
  ```json
  {
    "email": "user@example.com",
    "password": "password123"
  }
  ```

- `POST /users/signup/` - User registration
- `POST /users/logout/` - User logout

#### Health Profile
- `GET /health-profile/profile/` - Get user profile
- `POST /health-profile/profile/` - Update profile
  ```json
  {
    "first_name": "John",
    "last_name": "Doe",
    "language": "ar-LB",
    "agent_conversation_choice": "M"
  }
  ```

#### LiveKit Integration
- `POST /livekit/get-token/` - Get LiveKit connection token
  ```json
  {
    "identity": "user@example.com",
    "room": "room_user@example.com",
    "name": "John",
    "course_details": {...}
  }
  ```

- `POST /livekit/delete-room/` - Delete LiveKit room
  ```json
  {
    "room": "room_user@example.com"
  }
  ```

---

## Troubleshooting

### Common Issues and Solutions

#### 1. Agent Not Receiving Connections
**Issue**: Flutter app connects but agent doesn't respond

**Solutions**:
- Ensure only ONE agent process is running
- Kill all agent processes: `pkill -f "python agent.py"`
- Restart agent: `python agent.py dev`
- Check agent is registered in logs: "registered worker"

#### 2. No Audio Playback
**Issue**: Transcriptions appear but no audio

**Solutions**:
- Check iOS simulator audio settings
- Verify audio track subscription in Flutter logs
- Test on real device (simulator has audio limitations)
- Check language settings match profile

#### 3. Voice Trigger Not Working
**Issue**: Saying "hey kindura" doesn't trigger connection

**Solutions**:
- Check microphone permissions in iOS/Android settings
- Verify speech recognition is initialized
- Check Flutter logs for "Recognized:" messages
- Try alternative triggers: "hey candura", "hey kendra"

#### 4. API Connection Errors
**Issue**: "Something went wrong" error

**Solutions**:
- Verify Django server is running: `http://localhost:8000/admin`
- Check `.env` files have correct API keys
- Ensure Flutter app points to localhost (not production)
- Check network connectivity

#### 5. Multiple Agent Processes
**Issue**: Conflicting agent instances

**Solutions**:
```bash
# Check running processes
ps aux | grep agent.py

# Kill all agents
pkill -f "python agent.py"

# Start fresh
python agent.py dev
```

---

## Development Guidelines

### Code Style

#### Flutter/Dart
- Follow Flutter style guide
- Use meaningful variable names
- Implement MVVM pattern with GetX
- Keep controllers separate from views

#### Python
- Follow PEP 8
- Use type hints where applicable
- Document functions and classes
- Handle exceptions properly

### Git Workflow

1. **Branch Naming**:
   - `feature/description` - New features
   - `fix/description` - Bug fixes
   - `refactor/description` - Code improvements

2. **Commit Messages**:
   - Use present tense
   - Be descriptive but concise
   - Reference issue numbers

### Testing

#### Flutter Tests
```bash
# Run all tests
flutter test

# Run specific test
flutter test test/widget_test.dart
```

#### Django Tests
```bash
# Run all tests
python manage.py test

# Run specific app tests
python manage.py test users
```

### Security Considerations

1. **Never commit sensitive data**:
   - API keys
   - Passwords
   - Token secrets

2. **Use environment variables** for all credentials

3. **Validate all inputs** in both frontend and backend

4. **Implement proper authentication** for all API endpoints

---

## Deployment

### Production Configuration

#### Django Settings
```python
# settings.py
DEBUG = False
ALLOWED_HOSTS = ['your-domain.com']
SECRET_KEY = os.environ.get('SECRET_KEY')
```

#### Flutter Build
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

#### Environment Variables
Ensure all `.env` files are properly configured with production values.

---

## Important Notes

1. **LiveKit Room Management**: One room per user email to prevent conflicts
2. **Language Switching**: Requires app restart after profile update
3. **Audio on iOS Simulator**: Limited functionality, test on real device
4. **Token Expiration**: Implement token refresh mechanism for production
5. **Database**: SQLite for development, consider PostgreSQL for production

---

## Support and Resources

### Documentation Links
- [Flutter Documentation](https://flutter.dev/docs)
- [Django REST Framework](https://www.django-rest-framework.org/)
- [LiveKit Documentation](https://docs.livekit.io/)
- [OpenAI API](https://platform.openai.com/docs)
- [Deepgram API](https://developers.deepgram.com/)

### Project Dependencies

#### Flutter (pubspec.yaml)
- `get: ^4.6.5` - State management
- `livekit_client: ^2.4.3` - WebRTC communication
- `speech_to_text: ^7.2.0` - Voice recognition
- `shared_preferences: ^2.0.18` - Local storage
- `http: ^1.4.0` - HTTP requests

#### Python (requirements.txt)
- `django==4.2.x` - Web framework
- `djangorestframework==3.14.x` - REST API
- `livekit==0.17.x` - LiveKit SDK
- `openai==1.x` - OpenAI API
- `python-dotenv==1.0.x` - Environment variables

---

## Contact and Maintenance

For issues or questions about the codebase:
1. Check this documentation first
2. Review `changes.md` for recent updates
3. Review code comments and docstrings
4. Test in development environment
5. Check logs for error messages

---

## Recent Changes

### 2025-12-30

**App Resilience & Crash Prevention**
- Fixed white screen when app reopened after manual close
- Added 5-second safety timeout in splash screen
- Lazy controller initialization (network-dependent controllers)
- Better error handling for network issues in login

**Login Authentication Fix**
- Added `requireAuth: false` to login/signup API calls
- Fixed 400 Bad Request errors

**HealthKit Observer Updates**
- Added HRV observer (`heartRateVariabilitySDNN`)
- Added Respiratory Rate observer (`respiratoryRate`)
- Now monitoring 6 HealthKit types total

### 2025-12-29

**Multi-Device Health Data Architecture**
- Added `DataSourceMode` enum (appleWatch, healthKitOnly, manualOnly)
- Auto-detection of Apple Watch pairing
- Settings UI for manual override
- Conditional features based on mode (e.g., fall detection requires Watch)

**Event-Driven Health Updates**
- Removed 30-second periodic refresh
- Added `HKObserverQuery` for real-time HealthKit changes
- 5-second debounce prevents rapid successive updates

### 2025-12-25

**Real-Time Watch Sync**
- Watch sends vitals on significant change (not throttled)
- Enhanced `onVitalsReceived` callback

**PostgreSQL Storage for Health Data**
- New tables for heart rate, blood oxygen, HRV, sleep, activity history
- Batch save and retrieval API endpoints
- 3-month retention per user

---

*Last Updated: 2026-01-02*
*Version: 2.0.0*