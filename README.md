# Kindura AI

**A comprehensive health and wellness platform with AI-powered voice assistance**

Kindura AI helps patients track medications, manage health data, and communicate with an AI health assistant through voice interactions.

## Project Structure

This monorepo contains three main components:

```
KinduraDec2025/
├── flutter/          # Flutter mobile app (iOS/Android/watchOS)
├── django/           # Django REST API backend
├── livekit/          # LiveKit voice AI agent
├── docs/             # Additional documentation
└── scripts           # Startup and setup scripts
```

### 📱 Flutter App (`/flutter`)

The mobile application built with Flutter featuring:
- Health dashboard with metrics visualization
- Medication tracking and reminders
- Medical report uploads and lab results viewing
- Voice AI integration via LiveKit
- Apple Watch companion app

**[View Flutter Documentation →](flutter/README.md)**

### 🔧 Django Backend (`/django`)

REST API server handling:
- User authentication and profiles
- Medication management and adherence tracking
- Medical report processing with AI
- Biomarker extraction and insights
- Patient report generation (daily/weekly/monthly)

**[View Django Documentation →](django/README.md)**

### 🎤 LiveKit Agent (`/livekit`)

AI voice assistant featuring:
- Real-time voice conversations
- Medication queries and health observations
- Lab results explanations
- Multi-language support (English, Arabic)
- Health data recording from conversations

**[View LiveKit Documentation →](livekit/README.md)**

## Quick Start

### Prerequisites

- **macOS** (for iOS development)
- **Flutter SDK** 3.x
- **Python** 3.11+
- **PostgreSQL** 15+
- **Xcode** (for iOS)

### One-Command Setup

```bash
# Run setup script (creates database, venv, test user)
./setup_local.sh

# Start all services
./startkindura.sh
```

### Manual Setup

1. **Start PostgreSQL**
   ```bash
   brew services start postgresql@15
   ```

2. **Start Django Backend**
   ```bash
   cd django
   source ../venv/bin/activate
   python manage.py runserver
   ```

3. **Start LiveKit Agent**
   ```bash
   cd livekit
   source ../venv/bin/activate
   python agent.py dev
   ```

4. **Start Flutter App**
   ```bash
   cd flutter
   flutter run
   ```

## Documentation

| Document | Description |
|----------|-------------|
| [CLAUDE.md](CLAUDE.md) | AI assistant instructions for development |
| [docs/DEVELOPER_GUIDE.md](docs/DEVELOPER_GUIDE.md) | Comprehensive developer guide |
| [docs/RAG_PLAN.md](docs/RAG_PLAN.md) | Future RAG implementation plan |
| [LOCAL_SETUP.md](LOCAL_SETUP.md) | Detailed local setup instructions |
| [HANDOVER.md](HANDOVER.md) | Project handover documentation |

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                          KINDURA AI                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                      FLUTTER MOBILE APP                       │  │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────────────┐  │  │
│  │  │ Screens │──│Controllers│─│ Repos   │──│NetworkApiServices│  │  │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────────────┘  │  │
│  │       │                                          │            │  │
│  │       └───────────────────┬──────────────────────┘            │  │
│  │                           │                                   │  │
│  │  ┌────────────────────────▼───────────────────────────────┐  │  │
│  │  │              LiveKit Client (Voice/Audio)               │  │  │
│  │  └────────────────────────┬───────────────────────────────┘  │  │
│  └───────────────────────────│──────────────────────────────────┘  │
│                              │                                     │
│            ┌─────────────────┼─────────────────┐                  │
│            │                 │                 │                  │
│            ▼                 ▼                 ▼                  │
│  ┌──────────────────┐  ┌───────────────┐  ┌──────────────────┐   │
│  │   DJANGO API     │  │ LIVEKIT CLOUD │  │  LIVEKIT AGENT   │   │
│  │  (REST Backend)  │  │(WebRTC Infra) │  │  (Python AI)     │   │
│  │                  │  │               │  │                  │   │
│  │ - Users          │  │ - Audio/Video │  │ - OpenAI GPT-4o  │   │
│  │ - Medicines      │  │ - Rooms       │  │ - Function Tools │   │
│  │ - Health Profile │  │ - Tokens      │  │ - STT/TTS        │   │
│  │ - Medical Reports│  └───────────────┘  │                  │   │
│  │ - Observations   │                     │ (API calls to    │   │
│  │ - Patient Reports│◄────────────────────│  Django)         │   │
│  └────────┬─────────┘                     └──────────────────┘   │
│           │                                                       │
│           ▼                                                       │
│  ┌──────────────────────────────────────────────────────────────┐│
│  │                      POSTGRESQL DATABASE                      ││
│  │  Users, Medicines, MedicationEvents, PatientReports, etc.    ││
│  └──────────────────────────────────────────────────────────────┘│
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

## Environment Configuration

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

# OpenAI
OPENAI_API_KEY=your_openai_key

# Auth token for local testing
LOCAL_DEV_TOKEN=your_test_token
```

## Key Features

| Feature | Description |
|---------|-------------|
| 💊 **Medication Tracking** | Full medication management with adherence analytics |
| 📋 **Medical Reports** | Upload PDFs, AI extraction of biomarkers |
| 🔬 **Lab Results** | Track biomarkers with health insights |
| 🎤 **Voice AI** | Hands-free health assistant via LiveKit |
| 📊 **Health Reports** | AI-generated daily/weekly/monthly summaries |
| ⌚ **Watch Integration** | Sync vitals from Apple Watch |
| 🌍 **Multi-language** | English and Arabic support |

## Contributing

1. Create feature branch from `dev`
2. Follow existing code patterns
3. Update `changes.md` with your changes
4. Submit PR to `dev` branch

## License

This project is proprietary. All rights reserved.
