# Kindura AI - LiveKit Voice Agent

**Version:** 0.0.1  
**Python:** 3.11+

## Overview

The Kindura LiveKit Agent is an AI-powered voice assistant that helps patients manage their health through natural conversation. It uses LiveKit for real-time audio, OpenAI GPT-4o-mini for intelligence, and integrates with the Django backend for data persistence.

## Features

- **🎤 Voice Conversations**: Real-time speech-to-text and text-to-speech
- **💊 Medication Tracking**: Query medication schedules and adherence status
- **📊 Health Observations**: Record sleep, mood, symptoms, and energy levels
- **🔬 Lab Results**: Access and explain biomarker data
- **⌚ Watch Vitals**: Fetch Apple Watch health data
- **🌍 Multi-language**: Supports English and Arabic (including Lebanese dialect)
- **📝 Conversation Logging**: Saves transcripts in token-optimized format

## Architecture

```
livekit/
├── agent.py                 # Main agent entry point
├── agent_broken.py          # Deprecated agent version
├── requirement.txt          # Python dependencies
├── test_agent.py            # Agent tests
└── utils/
    ├── global_variables.py  # Agent prompts, configurations
    ├── medication_api.py    # Medication API calls
    ├── biomarkers_api.py    # Lab results API calls
    ├── observations_api.py  # Health observations API
    ├── contacts_api.py      # User contacts API
    ├── watch_vitals_api.py  # Apple Watch data API
    ├── medical_report_api.py # Medical documents API
    ├── json_to_be.py        # Transcript upload helper
    └── language_config.py   # Language settings
```

## Tech Stack

- **Voice Platform**: LiveKit Agents SDK 1.0
- **AI Model**: OpenAI GPT-4o-mini
- **Speech-to-Text**: Deepgram (English), OpenAI Whisper (Arabic)
- **Text-to-Speech**: Deepgram (English), OpenAI TTS (Arabic)
- **Voice Activity Detection**: Silero VAD
- **Noise Cancellation**: LiveKit BVC

## Dependencies

```
livekit-agents[deepgram,openai,cartesia,silero,turn-detector]~=1.0
livekit-plugins-noise-cancellation~=0.2
livekit-agents[google]~=1.0
livekit-api
python-dotenv
```

## Getting Started

### Prerequisites

- Python 3.11+
- LiveKit Cloud account or self-hosted LiveKit server
- OpenAI API key
- Deepgram API key (for English)

### Setup

1. **Create virtual environment**
   ```bash
   cd livekit
   python3 -m venv venv
   source venv/bin/activate
   ```

2. **Install dependencies**
   ```bash
   pip install -r requirement.txt
   ```

3. **Configure environment**
   
   Create `.env` file:
   ```bash
   # LiveKit
   LIVEKIT_URL=wss://your-project.livekit.cloud
   LIVEKIT_API_KEY=your_api_key
   LIVEKIT_API_SECRET=your_api_secret
   
   # OpenAI
   OPENAI_API_KEY=your_openai_key
   
   # Deepgram
   DEEPGRAM_API_KEY=your_deepgram_key
   
   # Backend API
   BASE_URL=http://localhost:8000/api
   ```

4. **Run the agent**
   ```bash
   python agent.py dev
   ```

## Function Tools

The agent has access to these function tools for interacting with patient data:

### Medication Tools
| Tool | Description |
|------|-------------|
| `get_current_medications` | Fetch active medications from database |
| `get_medication_status` | Get today's adherence summary |
| `get_medication_history` | Get detailed adherence history |
| `mark_medication_taken` | **Disabled** - must be done in app |
| `mark_medication_missed` | **Disabled** - must be done in app |

### Observation Tools
| Tool | Description |
|------|-------------|
| `save_sleep_report` | Record sleep hours and quality |
| `save_mood_report` | Record emotional state |
| `save_symptom_report` | Record physical symptoms |
| `save_energy_report` | Record energy levels |
| `save_fall_report` | Record fall incidents |
| `save_general_observation` | Record other health info |
| `report_side_effect` | Record medication side effects |

### Lab Results Tools
| Tool | Description |
|------|-------------|
| `get_lab_results` | Fetch all biomarkers |
| `get_biomarker_detail` | Get specific biomarker info |
| `get_health_insights` | Get AI recommendations |
| `get_labs_summary` | Get lab statistics |

### Other Tools
| Tool | Description |
|------|-------------|
| `get_watch_vitals` | Fetch Apple Watch data |

## Agent Prompt

The agent prompt is configured in `utils/global_variables.py` and includes:

- Patient context (name, medical history)
- Current medications and schedules
- Medical reports summary
- Watch vitals data
- Emergency contacts
- Language-specific instructions

## Language Support

| Language | STT Engine | TTS Engine | Voice |
|----------|------------|------------|-------|
| English | Deepgram | Deepgram | Default |
| Arabic | OpenAI Whisper | OpenAI TTS | nova |
| Lebanese Arabic | OpenAI Whisper | OpenAI TTS | shimmer |

## Conversation Logging

Transcripts are saved in **Toon format** (token-optimized JSON):

```json
{
  "msgs": [
    {"id": 1, "y": "msg", "r": "u", "c": "How am I doing?", "t": 1739627000},
    {"id": 2, "y": "msg", "r": "a", "c": "You're doing well!", "t": 1739627005}
  ],
  "crs": {"id": 1, "n": "Diabetes Management", "s": []},
  "t": 1739627000,
  "uid": "user123"
}
```

Key reference:
- `y` = type (msg, lab, med)
- `r` = role (u=user, a=assistant, s=system)
- `c` = content
- `t` = timestamp

## Security Notes

⚠️ **Medication marking is disabled** - For patient safety, medications can only be marked as taken/missed through the app by the user or caregiver, not by the voice agent.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| No audio output | Check LiveKit room audio settings |
| Agent crashes silently | Check logs for Python exceptions |
| VAD not working | Ensure Silero is loaded correctly |
| Arabic not recognized | Verify OpenAI API key is valid |

## Related Components

- **Mobile App**: See `../flutter/` for Flutter app
- **Backend API**: See `../django/` for Django REST API
