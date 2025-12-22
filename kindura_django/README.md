# Kindura AI - Django Backend API

**Version:** 0.0.1  
**Django:** 4.x  
**Python:** 3.11+

## Overview

The Kindura Django Backend provides REST APIs for the Kindura AI health application. It handles user management, medication tracking, medical report processing, health observations, and patient report generation.

## Features

- **👤 User Management**: Registration, authentication, profiles
- **💊 Medication System**: Full medication tracking with adherence analysis
- **📋 Medical Reports**: Upload, AI parsing, biomarker extraction
- **🔬 Biomarkers**: Lab results tracking with health insights
- **📊 Patient Reports**: AI-generated daily/weekly/monthly health reports
- **📝 Health Observations**: Record sleep, mood, symptoms from voice agent
- **👥 Contacts**: Emergency contacts and caregivers
- **⌚ Watch Vitals**: Apple Watch data synchronization
- **🎫 LiveKit Tokens**: Token generation for voice agent sessions

## Architecture

```
django/
├── manage.py                 # Django management script
├── requirements.txt          # Python dependencies
├── medical_app/              # Main Django project
│   ├── settings.py           # Database, apps config
│   ├── urls.py               # URL routing
│   └── asgi.py               # WebSocket support
├── users/                    # User management
│   ├── models.py             # User, Token, PatientReport, Contact
│   ├── views.py              # Auth & profile endpoints
│   ├── report_service.py     # AI report generation
│   └── pdf_generator.py      # Report PDF export
├── medicines/                # Medication tracking
│   ├── models.py             # Medicine, MedicationEvent
│   ├── views.py              # CRUD + adherence endpoints
│   └── serializers.py        # API serialization
├── medical_reports/          # Medical documents
│   ├── models.py             # Report, Biomarker
│   ├── views.py              # Upload, parsing endpoints
│   ├── biomarker_service.py  # Biomarker processing
│   └── insight_generation_service.py
├── health_profile/           # Health data
│   ├── models.py             # WatchVitals, HealthProfile
│   └── views.py              # Vitals sync endpoints
├── courses/                  # Treatment courses
├── schedules/                # Medication schedules
├── livekit_app/              # LiveKit integration
│   └── views.py              # Token generation
├── llm_model/                # AI processing
│   ├── gpt_model.py          # OpenAI integration
│   ├── medical_report_processor.py
│   └── pdf_markdown.py       # PDF parsing
└── utils/                    # Utilities
    ├── authentication.py     # Token auth
    ├── llm_prompt.py         # AI prompts
    └── response_utils.py     # API response helpers
```

## Tech Stack

- **Framework**: Django + Django REST Framework
- **Database**: PostgreSQL
- **AI Processing**: OpenAI GPT-4
- **PDF Processing**: Custom PDF to markdown
- **Authentication**: Token-based (custom)

## Database Models

### Core Models

```python
# User with health-specific fields
class User(AbstractUser):
    email = models.EmailField(unique=True)
    language = models.CharField(default='en')
    gender = models.CharField(choices=GENDER_CHOICES)
    unit_system = models.CharField(choices=['US', 'SI'])

# Medication tracking
class Medicine(models.Model):
    user = models.ForeignKey(User)
    drug_name = models.CharField(max_length=200)
    strength = models.DecimalField()
    schedule = models.JSONField()  # {"times": ["08:00", "20:00"]}
    is_active = models.BooleanField()

# Dose events
class MedicationEvent(models.Model):
    medication = models.ForeignKey(Medicine)
    scheduled_at = models.DateTimeField()
    taken_at = models.DateTimeField(null=True)
    status = models.CharField()  # taken, missed, late, skipped

# Health observations (from voice agent)
class PatientObservation(models.Model):
    user = models.ForeignKey(User)
    observation_type = models.CharField()  # sleep, mood, symptom
    title = models.CharField()
    description = models.TextField()
    severity = models.CharField()

# AI-generated reports
class PatientReport(models.Model):
    user = models.ForeignKey(User)
    report_type = models.CharField()  # daily, weekly, monthly
    adherence_percentage = models.FloatField()
    ai_summary = models.TextField()
    ai_recommendations = models.TextField()
```

## API Endpoints

### Authentication
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/users/signup/` | POST | Register new user |
| `/api/users/login/` | POST | Login, returns token |
| `/api/users/logout/` | POST | Invalidate token |
| `/api/users/profile/` | GET/PUT | User profile |

### Medications
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/medicines/` | GET/POST | List/Create medications |
| `/api/medicines/<id>/` | PUT/DELETE | Update/Delete medication |
| `/api/dose-events/` | POST | Record dose event |
| `/api/dose-events/today/` | GET | Today's dose events |
| `/api/medicines/adherence/` | GET | Adherence statistics |

### Medical Reports & Biomarkers
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/medical-reports/documents/` | GET/POST | Upload documents |
| `/api/medical-reports/biomarkers/` | GET | All biomarkers |
| `/api/medical-reports/biomarkers/<name>/` | GET | Specific biomarker |
| `/api/medical-reports/insights/` | GET | Health insights |

### Health Observations
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/users/observations/` | GET/POST | Health observations |
| `/api/users/observations/types/` | GET | Observation types |

### Patient Reports
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/users/patient-reports/` | GET | All reports |
| `/api/users/patient-reports/daily/` | GET | Daily report |
| `/api/users/patient-reports/weekly/` | GET | Weekly report |
| `/api/users/patient-reports/monthly/` | GET | Monthly report |

### Watch Vitals
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/health-profile/watch-vitals/` | GET/POST | Sync vitals |
| `/api/health-profile/watch-vitals/latest/` | GET | Latest vitals |

### Contacts
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/users/contacts/` | GET/POST | User contacts |
| `/api/users/contacts/emergency/` | GET | Emergency contacts |

### LiveKit
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/livekit-app/token/` | POST | Generate room token |

## Getting Started

### Prerequisites

- Python 3.11+
- PostgreSQL 15+
- OpenAI API key

### Setup

1. **Create virtual environment**
   ```bash
   cd django
   python3 -m venv venv
   source venv/bin/activate
   ```

2. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

3. **Configure database**
   
   Create PostgreSQL database:
   ```bash
   createdb kindura_db
   createuser kindura_user
   ```

4. **Set environment variables**
   ```bash
   export DB_NAME=kindura_db
   export DB_USER=kindura_user
   export DB_PASSWORD=kindura_pass
   export DB_HOST=localhost
   export DB_PORT=5432
   export OPENAI_API_KEY=your_key
   ```

5. **Run migrations**
   ```bash
   python manage.py migrate
   ```

6. **Create superuser**
   ```bash
   python manage.py createsuperuser
   ```

7. **Start server**
   ```bash
   python manage.py runserver
   ```

The API will be available at `http://localhost:8000/api/`

## Authentication

All protected endpoints require token in header:

```
Authorization: Token <your_token>
```

## Response Format

**Success:**
```json
{
    "status": true,
    "result": { ... }
}
```

**Error:**
```json
{
    "status": false,
    "result": {
        "error": "Error message"
    }
}
```

## Admin Interface

Access Django admin at `http://localhost:8000/admin/`

## Scheduled Tasks

Set up cron jobs for report generation:

```bash
./setup_cron_jobs.sh
```

This configures:
- Daily reports: Generated at midnight
- Weekly reports: Generated Sunday at midnight
- Monthly reports: Generated 1st of each month

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Database connection error | Check PostgreSQL is running |
| Migration errors | Run `python manage.py migrate --run-syncdb` |
| Token expired | Generate new token via login |
| OpenAI rate limit | Implement retry logic |

## Related Components

- **Mobile App**: See `../flutter/` for Flutter app
- **Voice Agent**: See `../livekit/` for LiveKit agent
