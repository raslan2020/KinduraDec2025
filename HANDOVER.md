# Kindura AI - Complete Project Handover Documentation

## Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Repository Structure](#repository-structure)
4. [Setup Instructions](#setup-instructions)
5. [Running the Application](#running-the-application)
6. [Key Features](#key-features)
7. [Language Support](#language-support)
8. [API Documentation](#api-documentation)
9. [Troubleshooting](#troubleshooting)
10. [Development Guidelines](#development-guidelines)

---

## Project Overview

Kindura AI is a health and wellness application that provides AI-powered voice assistance for patients with medical conditions. The system consists of three main components:

1. **Flutter Mobile App** - iOS/Android client application
2. **Django REST API** - Backend server for data management
3. **LiveKit Agent** - Real-time voice communication with AI

### Key Technologies
- **Frontend**: Flutter, GetX state management, LiveKit client SDK
- **Backend**: Django REST Framework, SQLite database
- **AI Agent**: Python, LiveKit SDK, OpenAI GPT-4, Deepgram/OpenAI Whisper STT/TTS
- **Real-time Communication**: LiveKit WebRTC platform

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Mobile App                       │
│  (iOS/Android - Voice activation, UI, LiveKit client)        │
└────────────┬─────────────────────────┬──────────────────────┘
             │                         │
             │ HTTP/REST               │ WebRTC/WebSocket
             │                         │
┌────────────▼─────────────┐ ┌────────▼──────────────────────┐
│   Django REST API        │ │    LiveKit Cloud Server        │
│  (localhost:8000)        │ │  (wss://kindura-u99yilqz...)  │
└────────────┬─────────────┘ └────────┬──────────────────────┘
             │                         │
┌────────────▼─────────────┐ ┌────────▼──────────────────────┐
│    SQLite Database       │ │    LiveKit Python Agent       │
│  (User data, courses)    │ │  (AI conversation handler)    │
└──────────────────────────┘ └───────────────────────────────┘
```

### Data Flow
1. User speaks trigger phrase ("hey kindura") → Flutter app detects
2. App requests LiveKit token from Django API
3. App connects to LiveKit room
4. LiveKit Agent joins room and starts conversation
5. Real-time audio streaming between app and agent
6. Agent uses GPT-4 for responses, STT/TTS for audio processing

---

## Repository Structure

```
Kinduraios/                     # Main Flutter project
├── lib/
│   ├── screens/               # UI screens and controllers
│   │   ├── home/             # Home screen with voice activation
│   │   ├── profile/          # User profile and language settings
│   │   └── login/            # Authentication
│   ├── models/               # Data models
│   ├── repository/           # API communication layer
│   ├── data/
│   │   └── network/          # Network services
│   ├── res/
│   │   ├── app_url/          # API endpoints configuration
│   │   └── routes/           # Navigation routes
│   └── user_preference/      # Local storage management
├── android/                   # Android specific code
├── ios/                      # iOS specific code
└── pubspec.yaml              # Flutter dependencies

KinduraAPIs-0.0.1/             # Django backend
├── kinduraapis/
│   ├── settings.py           # Django configuration
│   ├── urls.py              # Main URL routing
│   └── wsgi.py
├── users/                    # User management app
├── health_profile/           # Health profile management
├── courses/                  # Medical courses management
├── livekit/                  # LiveKit integration
├── manage.py                 # Django management script
├── requirements.txt          # Python dependencies
├── db.sqlite3               # SQLite database
└── .env                     # Environment variables

kinduralivekit-0.0.1/          # LiveKit Agent
├── agent.py                  # Main agent script
├── utils/
│   ├── global_variables.py  # Prompts and configurations
│   ├── json_to_be.py        # JSON upload utilities
│   └── language_config.py   # Modular language configuration
├── user_logs/               # Conversation transcripts
├── requirements.txt         # Python dependencies
├── venv/                    # Python virtual environment
└── .env                     # Environment variables
```

---

## Setup Instructions

### Prerequisites
- **macOS** (for iOS development) or Linux/Windows (Android only)
- **Flutter SDK** 3.x or higher
- **Python** 3.11 or higher
- **Xcode** (for iOS)
- **Android Studio** (for Android)
- **Git**

### 1. Clone the Repository
```bash
git clone <repository-url>
cd Kinduraios
```

### 2. Setup Django Backend

```bash
# Navigate to Django project
cd KinduraAPIs-0.0.1

# Create virtual environment
python3.11 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Create .env file
cat > .env << 'EOF'
SECRET_KEY=your-secret-key-here
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1
LIVEKIT_HOST=wss://kindura-u99yilqz.livekit.cloud
LIVEKIT_API_KEY=APImEMbwqie8wdf
LIVEKIT_SECRET_KEY=LqFYfro1D2IVIGV0UiPm5Fk2GxS3lqCeP2r0Y7HHfyP
EOF

# Run migrations
python manage.py migrate

# Create superuser (optional)
python manage.py createsuperuser

# Start server
python manage.py runserver
```

### 3. Setup LiveKit Agent

```bash
# Navigate to agent directory
cd ../kinduralivekit-0.0.1

# Create virtual environment
python3.11 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Create .env file
cat > .env << 'EOF'
LIVEKIT_URL=wss://kindura-u99yilqz.livekit.cloud
LIVEKIT_API_KEY=APImEMbwqie8wdf
LIVEKIT_API_SECRET=LqFYfro1D2IVIGV0UiPm5Fk2GxS3lqCeP2r0Y7HHfyP
OPENAI_API_KEY=your-openai-api-key
DEEPGRAM_API_KEY=your-deepgram-api-key
EOF

# Run agent
python agent.py dev
```

### 4. Setup Flutter App

```bash
# Navigate to Flutter project
cd ../Kinduraios

# Install Flutter dependencies
flutter pub get

# Update API endpoints for local development
# Edit lib/res/app_url/app_url.dart:
# Change baseUrl to: http://localhost:8000/api

# For iOS setup
cd ios
pod install
cd ..

# List available devices
flutter devices

# Run on iOS simulator
flutter run -d <device-id>

# Or run on Android
flutter run -d android
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
2. Review code comments and docstrings
3. Test in development environment
4. Check logs for error messages

---

*Last Updated: September 2, 2025*
*Version: 1.0.0*