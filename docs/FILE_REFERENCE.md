# Kindura AI - File Reference Guide

Quick reference for locating key files and understanding the codebase.

## Flutter App (`/lib/`)

### Entry Points
| File | Purpose |
|------|---------|
| `main.dart` | App entry point, DI setup, theme config |
| `res/routes/routes.dart` | Navigation routes definition |
| `res/app_url/app_url.dart` | API endpoint URLs |

### Screens (UI)
| Directory | Purpose |
|-----------|---------|
| `screens/home/` | Dashboard, LiveKit connection |
| `screens/medication/` | Medication list & management |
| `screens/meds_vitamin/` | Daily dose tracking |
| `screens/labs/` | Lab results & biomarkers |
| `screens/scan/` | PDF upload (medical reports) |
| `screens/profile/` | User settings |
| `screens/kindura_reports/` | AI-generated health reports |
| `screens/contacts/` | Emergency contacts |

### Controllers (Business Logic)
| File | Purpose |
|------|---------|
| `screens/home/home_controller.dart` | LiveKit connection, voice trigger |
| `screens/medication/medication_controller.dart` | Medication CRUD |
| `screens/meds_vitamin/meds_vitamin_controller.dart` | Dose tracking |
| `screens/scan/scan_controller.dart` | PDF upload |
| `screens/profile/profile_controller.dart` | Profile settings |

### Models (Data Classes)
| Directory | Purpose |
|-----------|---------|
| `models/medication/medication_models.dart` | Medication, DoseEvent, DoseStatus |
| `models/user_profile/user_profile_model.dart` | User profile |
| `models/medical_reports/` | Medical documents, biomarkers |
| `models/contact/contact_model.dart` | Emergency contacts |

### Network Layer
| File | Purpose |
|------|---------|
| `data/network/network_api_services.dart` | HTTP client (GET, POST, etc.) |
| `data/network/base_api_services.dart` | Abstract interface |
| `data/response/status.dart` | Loading/Completed/Error states |
| `data/app_exceptions.dart` | Custom exceptions |

### Repositories (Data Access)
| Directory | Purpose |
|-----------|---------|
| `repository/medication_repository/` | Medication API calls |
| `repository/medical_reports_repository/` | Medical docs API |
| `repository/home_repository/` | General APIs |
| `repository/contact_repository/` | Contacts API |

### Services
| File | Purpose |
|------|---------|
| `services/notification_service.dart` | Push notifications |
| `services/voice_service.dart` | "Hey Kindura" trigger |
| `services/theme_service.dart` | Dark/Light mode |
| `services/watch_vitals_service.dart` | Apple Watch data |

---

## Django Backend (`/KinduraAPIs-0.0.1/`)

### Configuration
| File | Purpose |
|------|---------|
| `medical_app/settings.py` | Database, apps, middleware |
| `medical_app/urls.py` | URL routing |
| `medical_app/asgi.py` | WebSocket support |
| `manage.py` | Django CLI |

### Apps
| Directory | Purpose |
|-----------|---------|
| `users/` | User auth, profiles, reports, contacts |
| `medicines/` | Medication tracking |
| `health_profile/` | Biomarkers, vitals |
| `courses/` | Medical documents |
| `livekit_app/` | LiveKit token generation |

### Key Model Files
| File | Purpose |
|------|---------|
| `users/models.py` | User, UserToken, PatientReport, Contact, PatientObservation |
| `medicines/models.py` | Medicine, MedicationEvent, MedicationReminder |
| `health_profile/models.py` | Biomarker, WatchVitals |

### API Views
| File | Purpose |
|------|---------|
| `users/views.py` | Auth, profile, reports APIs |
| `medicines/views.py` | Medication CRUD APIs |
| `health_profile/views.py` | Biomarker APIs |
| `livekit_app/views.py` | Token generation |

---

## LiveKit Agent (`/kinduralivekit-0.0.1/`)

### Main Files
| File | Purpose |
|------|---------|
| `agent.py` | Main agent entry point, function tools |
| `utils/global_variables.py` | Agent prompt, greetings, config |

### API Utilities
| File | Purpose |
|------|---------|
| `utils/medication_api.py` | Fetch medications |
| `utils/biomarkers_api.py` | Fetch lab results |
| `utils/observations_api.py` | Save observations |
| `utils/contacts_api.py` | Fetch contacts |
| `utils/watch_vitals_api.py` | Fetch Apple Watch data |

---

## Common Tasks

### Add a new screen
1. Create `lib/screens/<name>/<name>_screen.dart`
2. Create `lib/screens/<name>/<name>_controller.dart`
3. Add route in `lib/res/routes/routes.dart`
4. Add route name in `lib/res/routes/routes_name.dart`

### Add a new API endpoint
1. Add URL in `lib/res/app_url/app_url.dart`
2. Add method in appropriate repository
3. Call from controller

### Add a new model
1. Create in `lib/models/<category>/<name>_model.dart`
2. Add `@JsonSerializable()` annotation
3. Run `flutter pub run build_runner build`

### Add dark mode support
```dart
final isDark = Theme.of(context).brightness == Brightness.dark;
final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
final textColor = isDark ? Colors.white : Colors.black;
```

### Compare DoseStatus (IMPORTANT!)
```dart
// CORRECT
if (event.status == DoseStatus.taken) { ... }

// WRONG - will always be false!
if (event.status == 'taken') { ... }
```

### API call parameter order
```dart
// CORRECT: data, then url
await api.postApi({'key': 'value'}, AppUrl.endpoint);

// WRONG: url, then data
await api.postApi(AppUrl.endpoint, {'key': 'value'});
```
