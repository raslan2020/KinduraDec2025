# Kindura Development Changes Log

**Last Updated**: 2026-01-09

---

## 2026-01-09 - Fall Detection HealthKit Sync Improvements (Complete)

### Problem
User enabled Apple's native Fall Detection on their Apple Watch, but no falls were showing in HealthKit or Kindura. The app was relying solely on CoreMotion detection and not properly syncing with HealthKit where Apple's native falls are written.

### Solution
Implemented bidirectional HealthKit sync for falls: our CoreMotion detections write to HealthKit, AND we read from HealthKit to capture Apple's native fall detections.

### Implementation

**1. watchOS HealthManager (watchos/KinduraWatch/HealthManager.swift)**
- NEW `fallObserverQuery: HKObserverQuery?` property - background observer for HealthKit falls
- NEW fall observer in `startBackgroundHealthQueries()` - catches Apple native + Kindura falls
- NEW background delivery enabled for `numberOfTimesFallen` with `.immediate` frequency
- IMPROVED `fetchFallData()` with comprehensive logging:
  - Logs source of each fall (Apple/Kindura bundle ID)
  - Extracts metadata for severity/impactG if present
  - Distinguishes Apple native falls vs our CoreMotion detections
- NEW `handleHealthKitFallDetected()` method:
  - Queries most recent fall from HealthKit
  - Detects if it's an Apple native fall (different bundle ID)
  - Creates FallEvent and sends alert to iPhone for Apple native falls

**2. Flutter Profile Screen (lib/screens/profile/profile_screen.dart)**
- NEW "Fall Detection" settings section in Settings dialog
- NEW `_showFallDetectionGuide()` method with step-by-step instructions:
  - Opens Watch app → My Watch → Emergency SOS → Fall Detection
  - Recommends "Always On" for best coverage
  - Explains that Apple falls sync via HealthKit automatically
- NEW `_buildStepItem()` helper widget for numbered step list
- Added info box explaining dual-source fall detection (Apple + Kindura)

### Data Flow
```
Apple Native Fall Detection (System-Level)
    │
    └──► Writes to HealthKit (numberOfTimesFallen)
              │
              └──► HKObserverQuery triggers (background delivery)
                        │
                        └──► handleHealthKitFallDetected()
                                  │
                                  ├──► Identifies source (Apple vs Kindura)
                                  │
                                  └──► Sends fall alert to iPhone
                                            │
                                            └──► Flutter receives + shows alert

Kindura CoreMotion Fall Detection
    │
    └──► Detects via accelerometer
              │
              ├──► Writes to HealthKit (with Kindura metadata)
              │
              └──► Sends fall alert to iPhone directly
```

### Key Insight
Apple's native Fall Detection (enabled in Watch Settings → Emergency SOS → Fall Detection):
- Works at the SYSTEM level, not app level
- Requires: free-fall + hard impact + post-fall immobility
- Writes falls to HealthKit automatically
- Works even when Kindura isn't running

Our solution now reads FROM HealthKit to capture these Apple native detections, ensuring comprehensive fall coverage from both sources.

### Files Modified
- `watchos/KinduraWatch/HealthManager.swift` - Background observer + improved fetchFallData
- `lib/screens/profile/profile_screen.dart` - Fall Detection settings UI

---

## 2026-01-09 - Medication Reminders Push to Apple Watch (Complete)

### Feature
When medication reminders fire on iPhone, they now also push to Apple Watch. Users can mark medications as taken/skipped/snoozed directly from their Watch.

### Implementation

**1. iOS AppDelegate (ios/Runner/AppDelegate.swift)**
- NEW `sendMedicationReminder` method channel case (line 204)
- NEW `sendMedicationReminderToWatch()` method - sends reminder via WCSession
- NEW `queueMedicationReminderForDelivery()` - guaranteed delivery fallback
- NEW handler for `medication_reminder_response` in `didReceiveMessage`

**2. watchOS HealthManager (watchos/KinduraWatch/HealthManager.swift)**
- NEW `MedicationReminder` struct - parses reminder payload from iPhone
- NEW `@Published` properties: `currentMedicationReminder`, `showMedicationReminderAlert`, `pendingMedicationReminders`
- NEW handler in `didReceiveMessage` for `medication_reminder`
- NEW `handleMedicationReminder()` - processes incoming reminders, plays haptic
- NEW `sendMedicationReminderResponse()` - sends taken/skipped/snoozed response
- NEW `bufferMedicationResponse()` - guaranteed delivery for responses
- NEW `dismissCurrentReminder()` - handles queued reminders

**3. watchOS MedicationReminderView (NEW FILE: watchos/KinduraWatch/MedicationReminderView.swift)**
- SwiftUI view showing medication name, dosage, time, instructions
- Three action buttons: "Take Now" (green), "Snooze 15m" (orange), "Skip" (gray)
- Form icon mapping for different medication types
- Urgency indicator for follow-up reminders
- Haptic feedback on button press

**4. watchOS ContentView (watchos/KinduraWatch/ContentView.swift)**
- Added `.sheet(isPresented:)` modifier to present MedicationReminderView

**5. Flutter WatchVitalsService (lib/services/watch_vitals_service.dart)**
- NEW `onMedicationReminderResponse` callback
- NEW `sendMedicationReminder()` method - invokes native channel
- NEW handler in `_setupMethodCallHandler()` for `onMedicationReminderResponse`

**6. Flutter NotificationService (lib/services/notification_service.dart)**
- NEW `_setupWatchResponseHandler()` - registers Watch response callback
- NEW `_handleWatchMedicationResponse()` - processes Watch responses
- NEW `_sendReminderToWatch()` - sends reminder to Watch when timer fires
- Modified `_showMedicationReminder()` to also call `_sendReminderToWatch()`

### Data Flow
```
Flutter NotificationService (Timer fires)
    │
    ├──► _showMedicationReminder() ──► AlertDialog on iPhone
    │
    └──► _sendReminderToWatch()
              │
              └──► WatchVitalsService.sendMedicationReminder()
                        │
                        └──► iOS MethodChannel
                                  │
                                  └──► sendMedicationReminderToWatch()
                                            │
                                            ├──► sendMessage() (if Watch reachable)
                                            │         │
                                            │         └──► Watch: handleMedicationReminder()
                                            │                    │
                                            │                    ├──► Play haptic
                                            │                    │
                                            │                    └──► Show MedicationReminderView
                                            │
                                            └──► transferUserInfo() (fallback)

Watch User Action (Take/Skip/Snooze)
    │
    └──► sendMedicationReminderResponse()
              │
              └──► sendMessage() to iPhone
                        │
                        └──► iOS didReceiveMessage
                                  │
                                  └──► Flutter MethodChannel callback
                                            │
                                            └──► _handleWatchMedicationResponse()
                                                      │
                                                      ├──► "taken" ──► recordDoseTaken()
                                                      │
                                                      ├──► "skipped" ──► recordDoseSkipped()
                                                      │
                                                      └──► "snoozed" ──► _scheduleReminder() +15min
```

### Payload Structures

**iPhone → Watch (medication_reminder)**
```json
{
  "type": "medication_reminder",
  "reminder_id": "uuid",
  "medication_id": "123",
  "medication_name": "Metformin",
  "dosage": "500 mg",
  "form": "tablet",
  "scheduled_time": "2026-01-09T08:00:00Z",
  "instructions": "Take with food",
  "is_follow_up": false,
  "follow_up_number": 0,
  "requires_escalation": false
}
```

**Watch → iPhone (medication_reminder_response)**
```json
{
  "type": "medication_reminder_response",
  "reminder_id": "uuid",
  "medication_id": "123",
  "action": "taken",
  "scheduled_time": "2026-01-09T08:00:00Z",
  "taken_at": "2026-01-09T08:05:23Z",
  "source": "apple_watch"
}
```

### Files Modified
- `ios/Runner/AppDelegate.swift` - Method channel + WCSession send
- `watchos/KinduraWatch/HealthManager.swift` - Handler + response methods
- `watchos/KinduraWatch/ContentView.swift` - Sheet presentation
- `lib/services/watch_vitals_service.dart` - Flutter bridge method
- `lib/services/notification_service.dart` - Watch integration
- `watchos/watchapp.md` - Documentation updated with full medication reminder flow

### Files Created
- `watchos/KinduraWatch/MedicationReminderView.swift` - Watch UI

### Documentation Updates
- Updated `watchos/watchapp.md` with:
  - Added MedicationReminderView.swift to file structure
  - Added "Medication Reminders" feature (section 6)
  - Added detailed medication reminder data flow diagram
  - Added MedicationReminder struct documentation to API Reference
  - Added medication reminder methods to HealthManager API table
  - Updated iPhone App Requirements with medication reminder handling

---

## 2026-01-09 - Fall Detection Data Sync Fix (Complete)

### Problem
iPhone app showed "No falls" even when Apple Watch detected falls. Fall count (`falls_count`) wasn't being displayed correctly on the iPhone home screen.

### Root Cause
1. **Watch detected falls via CoreMotion but NEVER wrote to HealthKit** - only stored locally
2. **Watch sent fall alerts without `falls_count`** - iPhone couldn't display cumulative count
3. **iOS `getHealthSummary()` didn't query HealthKit for falls** - no fall data source
4. **Watch only requested READ permission** for falls, not WRITE

### Solution (Multi-Layer Fix)

**1. Watch: Write falls to HealthKit (HealthManager.swift)**
- NEW `saveFallToHealthKit()` function writes detected falls to HealthKit
- Called from `handleFallDetected()` when CoreMotion detects impact
- Falls now persist in Apple Health and sync across devices

**2. Watch: Request WRITE permission for falls (HealthManager.swift)**
- Added `typesToShare` with `numberOfTimesFallen`
- Watch app will prompt user to allow writing fall data
- Required for `healthStore.save()` to work

**3. Watch: Include `falls_count` in fall alerts (HealthManager.swift)**
- Added `falls_count: recentFalls.count` to fall alert payload
- Added explicit `fall_detected: true` flag
- Real-time count available immediately when fall detected

**4. iOS: Query HealthKit for falls (AppDelegate.swift)**
- NEW `fetchTodayFalls()` queries `numberOfTimesFallen` from HealthKit
- Gets falls written by Watch to Apple Health

**5. iOS: Merge falls from multiple sources (AppDelegate.swift)**
- Combines falls from HealthKit AND WatchConnectivity
- Uses maximum of both sources for accurate count
- Fallback ensures falls are never lost

### Files Modified
- `watchos/KinduraWatch/HealthManager.swift`:
  - `saveFallToHealthKit()` - NEW: Writes fall to HealthKit
  - `handleFallDetected()` - Calls saveFallToHealthKit()
  - `requestAuthorization()` - Added write permission for falls
  - `sendFallAlertToiPhone()` - Added `falls_count` to payload

- `ios/Runner/AppDelegate.swift`:
  - `fetchTodayFalls()` - NEW: Queries falls from HealthKit
  - `getHealthSummary()` - Merges falls from HealthKit + WatchConnectivity

### Data Flow (Fixed)
```
Watch detects fall (CoreMotion)
    │
    ├──► saveFallToHealthKit() ─────────────────────┐
    │         │                                      │
    │         └──► HealthKit (Apple Health)          │
    │                    │                           │
    ├──► recentFalls.append()                        │
    │                                                │
    ├──► sendFallAlertToiPhone() with falls_count    │
    │         │                                      │
    │         └──► iPhone latestWatchVitals          │
    │                    │                           │
    └──► sendVitalsToiPhone() with falls_count       │
                         │                           │
                         ▼                           ▼
iPhone getHealthSummary()
    │
    ├──► fetchTodayFalls() ──► HealthKit falls ──────┤
    │                                                │
    ├──► latestWatchVitals ──► WatchConnectivity ────┤
    │                                                │
    └──► MAX(HealthKit, WatchConnectivity) ──────────┘
           │
           ▼
Flutter displays falls_count on Home screen
```

### User Action Required
After rebuilding both Watch and iOS apps:
1. Open Watch app - it will prompt for HealthKit write permission for falls
2. Grant permission to allow fall data to sync via Apple Health

---

## 2026-01-08 - Watch → iPhone → Django Reliability Improvements

### Problem
Watch vitals (BPM, O2, HRV, Br/M, Sleep, Falls, Activity) could be lost if iPhone was unreachable or app restarted before data was sent to Django API.

### Solution: Multi-Layer Reliability

**1. Activity Data Collection (Watch)**
- Added activity metrics to vitals payload:
  - Steps count
  - Calories burned
  - Distance (km)
  - Floors climbed
  - Exercise minutes
  - Stand minutes
- Activity data fetched from HealthKit every 60 seconds
- Included in all vitals transmissions to iPhone

**2. Persistent Buffer (Watch - Survives App Restart)**
- `UserDefaults` storage for pending vitals
- `savePendingVitals()` - Saves buffer to disk when iPhone unreachable
- `loadPendingVitals()` - Loads buffered vitals on app launch
- `clearPendingVitalsStorage()` - Clears disk after successful sends
- Buffer limit: 100 vitals to prevent memory issues
- Uses `DispatchGroup` to track send completion before clearing storage

**3. Guaranteed Delivery via transferUserInfo (Watch)**
- `sendVitalsViaTransferUserInfo()` - Queues vitals for guaranteed delivery
- `sendFallAlertViaTransferUserInfo()` - High priority fall alert queue
- Data queued on Watch OS and delivered when iPhone available
- Each transfer includes unique `transfer_id` for deduplication
- Fall alerts ALWAYS use transferUserInfo (critical data)

**4. didReceiveUserInfo Handler (iPhone)**
- `session(_:didReceiveUserInfo:)` - Receives queued Watch transfers
- Deduplication using `transfer_id` stored in UserDefaults
- Handles both `watch_vitals` and `fall_alert` types
- Forwards data to Django API and notifies Flutter
- Cleanup of old transfer keys (keeps last 50)

### Files Modified
- `watchos/KinduraWatch/HealthManager.swift`:
  - Added activity data properties and fetching
  - Added UserDefaults persistence for pending vitals
  - Added transferUserInfo methods
  - Updated fall alerts to use guaranteed delivery

- `ios/Runner/AppDelegate.swift`:
  - Added `didReceiveUserInfo` delegate method
  - Added transfer deduplication logic
  - Added cleanup for old transfer keys

### Data Flow (Enhanced)
```
Apple Watch HealthManager
    │
    ├──► sendMessage() (real-time if reachable)
    │         │
    │         └──► On failure: bufferVitals() + transferUserInfo()
    │
    ├──► transferUserInfo() (guaranteed, queued)
    │
    └──► updateApplicationContext() (latest state)
           │
           ▼
iPhone AppDelegate
    │
    ├──► didReceiveMessage (real-time)
    ├──► didReceiveUserInfo (queued)  ← NEW
    └──► didReceiveApplicationContext (background)
           │
           ▼
Django API (/api/watch-vitals/dev/)
```

### Activity Data Payload
```json
{
  "type": "watch_vitals",
  "heart_rate": 72,
  "blood_oxygen": 98,
  "hrv": 42,
  "respiratory_rate": 16,
  "steps": 8432,
  "calories": 420,
  "distance_km": 5.2,
  "floors_climbed": 12,
  "exercise_minutes": 35,
  "stand_minutes": 10
}
```

---

## 2026-01-02 - Report Dialog & Navigation Improvements

### Changes
1. **Dialog closes immediately on Generate click**
   - Used `Builder` to get proper dialog context
   - `Navigator.of(dialogContext).pop()` for instant dismissal
   - `Future.microtask()` triggers generation after dialog animation

2. **Progress overlay shows globally during navigation**
   - Added `ReportProgressOverlay` to `bottom_navigation_screen.dart`
   - Overlay persists while navigating between Home, Labs, Meds, Profile
   - Removed duplicate overlay from `kindura_reports_screen.dart`

3. **Works for all report types**
   - Daily, Weekly, and Monthly reports all benefit from same improvements

### Files Modified
- `lib/screens/kindura_reports/kindura_reports_screen.dart` - Fixed dialog dismissal
- `lib/screens/bottom_navigation/bottom_navigation_screen.dart` - Added global overlay

---

## 2026-01-02 - Report Generation Bug Fixes

### Issues Fixed

**1. `'WatchVitals' object has no attribute 'sleep_hours'` Error**
- Report generation was failing due to stale Python bytecode cache
- The code referenced `v.sleep_hours` instead of `v.total_sleep_hours`
- **Fix**: Cleared `__pycache__` directories and `.pyc` files

**2. Duplicate Key Violation on Report Regeneration**
- When regenerating a report for the same date/type, the system threw:
  `IntegrityError: duplicate key value violates unique constraint`
- **Root Cause**: Code only checked for `status='processing'` reports, not completed/failed ones
- **Fix**: Modified `generate_report_async()` in `users/views.py` to:
  - Check for ANY existing report (not just processing)
  - If completed/failed report exists, reset it and regenerate
  - If processing report exists, return its current status

### Files Modified
- `KinduraAPIs-0.0.1/users/views.py` - Added proper duplicate handling

### Test Results
- Report generation now completes successfully (status: completed, progress: 100%)
- Regenerating same report type/date works without errors

---

## 2026-01-02 - Sleep Data Fix: Prioritize Apple Watch/HealthKit

### Issue
Sleep hours showing ~13.5h instead of actual ~6h 52m from Apple Health.

### Root Cause
The app was summing sleep samples from ALL sources (Apple Watch, iPhone, third-party apps) without deduplication, causing double/triple counting of the same sleep period.

### Fix
Updated `AppDelegate.swift` to:

1. **Prioritize Apple Watch/HealthKit data**
   - Filter samples by source bundle identifier
   - Prefer `com.apple.health`, `com.apple.nano` (watchOS), or device name containing "watch"
   - Fall back to other sources only if no Watch data available

2. **Deduplicate overlapping intervals**
   - Added `deduplicateSleepSamples()` function
   - Removes samples with overlapping time periods
   - Keeps first sample when duplicates found

### Files Changed
- `ios/Runner/AppDelegate.swift`:
  - `fetchLastNightSleep()` - Added source filtering and deduplication
  - `fetchSleepHistory()` - Added same logic for history view
  - `deduplicateSleepSamples()` - New helper function

### Console Output (Debug)
```
😴 Found 24 total sleep samples from all sources
😴 Using 12 Apple Watch/HealthKit samples (prioritized)
😴 Ignoring 12 samples from other sources
😴 After deduplication: 8 unique sleep intervals
😴 Final sleep: 6.87 hours
```

---

## 2026-01-02 - Agent Medication Update Permission Feature

### Feature
Added a user-controlled setting that allows the Kindura AI agent to mark medications as taken or missed via voice commands. When disabled, the agent directs users to update manually in the app.

### How It Works
1. User enables "Allow Medication Updates" in Settings > Kindura AI Permissions
2. User tells agent: "I took my Metformin" or "I missed my morning medication"
3. If enabled: Agent finds medication and calls dose-events API to record
4. If disabled: Agent tells user to update manually in the Medications tab

### Backend Changes

**1. User Model** (`users/models.py`)
- Added `allow_agent_medication_updates` BooleanField (default False)
- Migration: `0019_add_agent_medication_permission.py`

**2. UserProfileSerializer** (`users/serializers.py`)
- Added `allow_agent_medication_updates` to fields
- Included in extra_kwargs as optional

### Flutter Changes

**3. UserProfile Model** (`lib/models/user_profile/user_profile_model.dart`)
- Added `allowAgentMedicationUpdates` field
- Updated fromJson/toJson methods

**4. ProfileController** (`lib/screens/profile/profile_controller.dart`)
- Added `allowAgentMedicationUpdates` observable
- Load value in onInit()
- Include in saveProfile() API call

**5. ProfileScreen Settings Dialog** (`lib/screens/profile/profile_screen.dart`)
- Added "Kindura AI Permissions" section
- Toggle switch for "Allow Medication Updates"
- Info box explaining the feature

**6. HomeController** (`lib/screens/home/home_controller.dart`)
- Pass `allow_agent_medication_updates` to agent via LiveKit metadata

### Agent Changes

**7. Global Variables** (`kinduralivekit/agent.py`)
- Added `_allow_agent_medication_updates` flag
- Added `_medications_cache` for name lookup

**8. Medication Functions** (`kinduralivekit/agent.py`)
- `mark_medication_taken()` - Now checks permission, finds med by name, calls API
- `mark_medication_missed()` - Now checks permission, records missed dose
- `_find_medication_by_name()` - Helper for fuzzy medication name matching

**9. Metadata Parsing** (`kinduralivekit/agent.py`)
- Parse `allow_agent_medication_updates` from participant metadata
- Log permission status on agent startup
- Cache medications list for voice command lookups

### Security
- Feature is OFF by default
- User must explicitly enable in Settings
- Respects user's privacy and control preferences

---

## 2026-01-02 - Agent Contacts & Communication Feature

### Feature
Added ability for the AI agent to call contacts and send iMessages to contacts saved in the Kindura app (family, caregivers, doctors).

### How It Works
1. User tells agent: "Call my daughter" or "Send a message to Dr. Smith"
2. Agent looks up the contact in Kindura's saved contacts
3. Agent creates a "communication request" in the backend
4. Flutter app polls for pending requests and shows confirmation dialog
5. User confirms → App opens FaceTime/Phone/Messages with content ready
6. User just taps to complete the action (iOS security requirement)

### Backend Changes

**1. CommunicationRequest Model** (`users/models.py`)
- New model for storing agent-initiated communication requests
- Request types: 'call', 'facetime_video', 'facetime_audio', 'message'
- Status tracking: pending → approved → completed
- 5-minute expiration for security

**2. CommunicationRequestViewSet** (`users/views.py`)
- `POST /api/communication-requests/` - Create request (called by agent)
- `GET /api/communication-requests/` - Get pending requests (polled by app)
- `POST /api/communication-requests/{id}/approve/` - User approved
- `POST /api/communication-requests/{id}/reject/` - User declined
- `POST /api/communication-requests/{id}/complete/` - Action executed

### Agent Changes

**3. ContactsAPI Updates** (`kinduralivekit/utils/contacts_api.py`)
- `create_call_request()` - Request a call to a contact
- `create_message_request()` - Request to send a message
- `search_contact()` - Find contact by name

**4. New Agent Tools** (`kinduralivekit/agent.py`)
- `call_contact(contact_name, call_type)` - Call a contact via FaceTime/phone
- `send_message_to_contact(contact_name, message)` - Send iMessage to contact
- `get_kindura_contacts()` - List all saved contacts

### iOS Native Changes

**5. AppDelegate.swift** - Method channels for native communication
- `com.kindura.ai/contacts` method channel
- `sendMessage` - Open Messages app with content
- `makeCall` - Open Phone app
- `startFaceTimeCall` - Open FaceTime

### Flutter Changes

**6. ContactsCommunicationService** (`lib/services/contacts_communication_service.dart`)
- Bridge to native iOS functionality
- Methods: `sendMessage()`, `makePhoneCall()`, `startFaceTimeCall()`

**7. URL Updates** (`lib/res/app_url/app_url.dart`)
- Added communication request endpoints

### Example User Flow
```
User: "Kindura, can you call my wife?"
Agent: "I'm setting up a FaceTime video call to Mary. The app will ask you to confirm."
[App shows confirmation dialog]
User: [Taps Confirm]
[FaceTime opens with Mary's number]
```

### Files Changed
- `KinduraAPIs-0.0.1/users/models.py` - Added CommunicationRequest model
- `KinduraAPIs-0.0.1/users/views.py` - Added CommunicationRequestViewSet
- `KinduraAPIs-0.0.1/medical_app/urls.py` - Registered new viewset
- `kinduralivekit-0.0.1/utils/contacts_api.py` - Added communication methods
- `kinduralivekit-0.0.1/agent.py` - Added call_contact, send_message_to_contact tools
- `ios/Runner/AppDelegate.swift` - Added Contacts framework & method channels
- `lib/services/contacts_communication_service.dart` (NEW)
- `lib/res/app_url/app_url.dart` - Added URLs

### Migration
```bash
cd KinduraAPIs-0.0.1
../.venv/bin/python manage.py migrate
# Migration: 0018_add_device_contacts_and_communication_requests
```

---

## 2026-01-02 - Background Report Generation with Progress Tracking

### Problem
Report generation blocked the UI - users had to wait on the reports screen while daily/weekly/monthly reports were generated, preventing navigation.

### Solution: Seamless Background Generation
Implemented background report generation with real-time progress tracking that allows users to navigate freely while reports generate.

**Backend Changes:**

**1. PatientReport Model** (`users/models.py`)
- Added `status` field: 'pending', 'processing', 'completed', 'failed'
- Added `progress` field: 0-100 integer for progress percentage
- Added `error_message` field for failure details
- Migration: `0017_add_report_progress_fields.py`

**2. ReportService Progress Tracking** (`users/report_service.py`)
- Modified to accept `report_instance` and update progress in DB
- Progress stages: 5% (started) → 15% (observations) → 25% (medication) → 40% (vitals) → 55% (sleep) → 65% (falls) → 75% (biomarkers) → 85% (scores) → 90% (AI analysis) → 100% (complete)
- Report instance updated with status='completed' when done

**3. Async API Endpoints** (`users/views.py`)
- `POST /api/users/patient_reports/generate_async/` - Starts background generation, returns immediately with report_id
- `GET /api/users/patient_reports/{id}/status/` - Returns current status and progress
- Uses Python threading for background execution
- Proper Django DB connection management in threads

**Flutter Changes:**

**4. ReportGenerationService** (`lib/services/report_generation_service.dart` - NEW)
- GetX service registered at app startup (persistent singleton)
- Observable state: `isGenerating`, `progress`, `currentReportType`, `activeReportId`, `status`
- Polls status endpoint every 2 seconds
- Callbacks: `onReportCompleted`, `onReportFailed`
- Shows snackbar notifications on completion/failure

**5. ReportProgressOverlay** (`lib/common_widgets/report_progress_overlay.dart` - NEW)
- Floating progress indicator widget
- Shows at bottom of screen during navigation
- Displays progress bar, percentage, and status text
- Color changes: blue (generating) → green (complete) → red (failed)
- Clickable to navigate to report when complete
- Dismissible when done

**6. KinduraReportsScreen Update** (`lib/screens/kindura_reports/kindura_reports_screen.dart`)
- `_triggerReportGeneration()` now uses background service
- No more blocking dialog - immediate response
- Auto-refreshes when report completes (if still on reports screen)
- Added `ReportProgressOverlay` to screen body

**7. Service Registration** (`lib/main.dart`)
- Added `ReportGenerationService` import
- Registered as permanent singleton at startup

### User Flow
1. User taps "Generate Daily Report" → snackbar confirms generation started
2. Floating progress pill appears at bottom: "Generating Daily Report... 10%"
3. User can navigate anywhere - progress pill follows
4. Progress updates: 25% → 45% → 70% → 85% → 100%
5. On completion: Pill shows "Daily Report Ready!" with checkmark
6. User taps pill → navigates to report OR dismiss after viewing

### Files Modified
- `KinduraAPIs-0.0.1/users/models.py` - Added status/progress/error_message fields
- `KinduraAPIs-0.0.1/users/report_service.py` - Progress tracking at each stage
- `KinduraAPIs-0.0.1/users/views.py` - Async generate and status endpoints
- `lib/services/report_generation_service.dart` (NEW) - Background service
- `lib/common_widgets/report_progress_overlay.dart` (NEW) - Floating overlay widget
- `lib/screens/kindura_reports/kindura_reports_screen.dart` - Integrated with service
- `lib/main.dart` - Registered ReportGenerationService
- `lib/res/app_url/app_url.dart` - Added new endpoint URLs

---

## 2025-12-30 - App Resilience & Crash Prevention

### Problem
App showed white screen when reopened after manual close. Network errors or backend unavailability caused app crashes.

### Solution: Resilient App Startup

**1. Splash Screen Improvements** (`lib/screens/splash_screen/`)
- Added 5-second safety timeout - app ALWAYS navigates somewhere
- Error handling in `isLogin()` - catches all exceptions
- Prevents double navigation
- Shows loading indicator with status message

**2. Lazy Controller Initialization** (`lib/main.dart`)
- Removed `HomeController` from main.dart startup
- Network-dependent controllers now lazily initialized when needed
- Only local services (ThemeService, NotificationService, VoiceService) registered at startup

**3. Lazy HomeController Loading** (`lib/screens/bottom_navigation/` & `lib/screens/home/`)
- `Get.isRegistered<HomeController>()` check before access
- `Get.put()` only called if controller not already registered
- Prevents crashes from missing controller

**4. Login Error Handling** (`lib/screens/login/login_controller.dart`)
- User-friendly error messages for network issues
- Handles SocketException, timeout, connection refused
- Never shows raw error messages to user

### App Data Strategy
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

### Files Modified
- `lib/main.dart` - Removed HomeController from startup
- `lib/screens/splash_screen/splash_screen.dart` - Loading indicator, status message
- `lib/screens/splash_screen/splash_controller.dart` - Safety timeout, error handling
- `lib/screens/login/login_controller.dart` - Better error messages
- `lib/screens/bottom_navigation/bottom_navigation_screen.dart` - Lazy HomeController
- `lib/screens/home/home_screen.dart` - Lazy HomeController

---

## 2025-12-30 - Login Authentication Fix

### Problem
Login API was returning 400 Bad Request errors even with correct credentials. The Flutter app couldn't authenticate users.

### Root Cause
The `LoginRepository` and `SignupRepository` were calling `postApi()` without `requireAuth: false`. Since login/signup endpoints don't require authentication (they're used to GET a token), the network layer was incorrectly trying to fetch a stored token that didn't exist.

### Solution
**File**: `lib/repository/login_repository/login_repository.dart`
- Added `requireAuth: false` to `loginApi()` call
- Added `requireAuth: false` to `signupApi()` call

```dart
// Before (broken):
await _apiServices.postApi(data, AppUrl.loginUrl);

// After (fixed):
await _apiServices.postApi(data, AppUrl.loginUrl, requireAuth: false);
```

### Password Reset
- Reset user password to `Test1234` (without special characters for easier testing)
- Verified login works via both curl and Flutter app

---

## 2025-12-30 - HealthKit Observer Updates for HRV & Respiratory Rate

### Problem
Initial health data (BPM, O2, HRV, br/min) was loading correctly from Apple Watch, but subsequent updates weren't being reflected in the UI.

### Root Cause
The HealthKit observers in `AppDelegate.swift` were only set up for:
- Heart Rate ✅
- Blood Oxygen ✅
- Steps ✅
- Sleep ✅

Missing observers for:
- HRV (Heart Rate Variability) ❌
- Respiratory Rate ❌

### Solution
**File**: `ios/Runner/AppDelegate.swift`
- Added `hrvObserver: HKObserverQuery?` and `respiratoryRateObserver: HKObserverQuery?` properties
- Added HRV observer with `heartRateVariabilitySDNN` type
- Added Respiratory Rate observer with `respiratoryRate` type
- Both observers trigger `notifyFlutterHealthUpdate()` when data changes
- Enabled background delivery for both types
- Updated `stopHealthKitObservers()` to clean up new observers

Now monitoring 6 HealthKit types:
- Heart Rate
- Blood Oxygen
- HRV
- Respiratory Rate
- Steps
- Sleep

---

## 2025-12-29 - Multi-Device Health Data Architecture

### Problem
Previous architecture assumed Apple Watch was the primary data source. Users with other devices (Oura Ring, Ultrahuman, Whoop, etc.) needed a HealthKit-only mode.

### Solution: DataSourceMode System
Added intelligent mode detection to support multiple health data sources:

**New Enum**: `lib/models/health/data_source_mode.dart`
- `appleWatch` - Watch paired, use WCSession + HealthKit
- `healthKitOnly` - No Watch, use HealthKit only (Oura, Whoop, Ultrahuman, etc.)
- `manualOnly` - User enters data manually

**Auto-Detection Flow**:
1. App checks if Apple Watch is paired via WCSession
2. If paired → `appleWatch` mode (full Watch integration)
3. If not paired → check HealthKit authorization → `healthKitOnly` mode
4. If neither → `manualOnly` mode

**User Override**: Settings allow manual override of auto-detection

### Files Modified
- `lib/models/health/data_source_mode.dart` (NEW) - DataSourceMode enum with extensions
- `lib/services/watch_vitals_service.dart` - Added mode detection, user override, storage
- `lib/screens/home/home_controller.dart` - Conditional setup based on mode
- `lib/screens/home/home_screen.dart` - Data source indicator, conditional falls section
- `lib/screens/profile/profile_screen.dart` - Data source picker in Settings

### UI Changes
- Health card header shows current data source (Apple Watch / Apple Health)
- Falls section shows "Requires Apple Watch" when in HealthKit-only mode
- Settings dialog includes Health Data Source picker with 4 options:
  - Auto-detect (Recommended)
  - Apple Watch
  - Apple Health Only
  - Manual Entry

### Feature Availability by Mode
| Feature | Apple Watch | HealthKit-Only | Manual |
|---------|-------------|----------------|--------|
| WCSession | ✅ | ❌ | ❌ |
| HealthKit Observers | ✅ | ✅ | ❌ |
| Fall Detection | ✅ | ❌ | ❌ |
| Real-time HR | ✅ | ⚠️ Delayed | ❌ |

---

## 2025-12-29 - Event-Driven Health Updates & UI Improvements

### Event-Driven Health Updates (Removed 30s Refresh)
**Problem**: 30-second periodic refresh was annoying and caused UI flickers without meaningful data changes.

**Solution**:
- Removed periodic refresh timer from `home_controller.dart`
- Added `HKObserverQuery` observers in `AppDelegate.swift` for real-time HealthKit changes
- Observers for: heart rate, blood oxygen, steps, sleep with background delivery
- 5-second debounce prevents rapid successive updates
- New Flutter callbacks: `onHealthKitDataChanged`, `startHealthKitObservers()`, `stopHealthKitObservers()`

**Result**: UI updates instantly only when data actually changes (Watch, HealthKit, or manual refresh).

### UI Changes
- Health widget now spans full width
- AI Conversation changed to compact pill button
- Sleep section always visible with all metrics (total, score, deep, REM, core, awake)
- Falls section always visible with status indicator
- Activity section uses Wrap to prevent overflow

### Bug Fixes
- Fixed HealthKit unit conversion error (`min` vs `count` for exercise/stand time)
- Fixed User Script Sandboxing build failures (`ENABLE_USER_SCRIPT_SANDBOXING = NO`)
- Removed `health-records` entitlement (requires Apple approval)
- Extended sleep query range from 24h to 36h for better capture

### HealthKit Entitlements Fix
- Added `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements` to all build configurations
- Entitlements: `healthkit`, `healthkit.background-delivery`, `application-groups`

---

## 2025-12-25 - Real-Time Health Data & PostgreSQL Storage

### Real-Time Watch Sync
- Watch sends vitals immediately when values change (not throttled):
  - Heart rate: 2+ BPM change
  - Blood oxygen: 1%+ change
  - HRV: 2+ ms change
  - Respiratory rate: 0.5+ br/m change
- Enhanced `onVitalsReceived` callback includes all vitals, sleep, activity, falls

### PostgreSQL Storage for Apple Health Data
**New Tables**: `health_heart_rate_history`, `health_blood_oxygen_history`, `health_hrv_history`, `health_sleep_history`, `health_activity_history`

**API Endpoints**:
- `POST /api/health-history/batch/` - Bulk save health records
- `GET /api/health-history/` - Retrieve with day/week/month grouping

**Retention**: 3 months of historical data per user.

### Vitals History Screen Fix
- Falls back to direct HealthKit queries when API returns empty
- Shows real Apple Health data instead of demo values

### Biomarker Improvements
- Immediate graph refresh after saving biomarker observations
- CRUD endpoints for biomarker management

### Apple Health Settings Integration
- Added "Apple Health Settings" button to profile page
- Opens device Settings > Health > Kindura directly

### Watch Memory Crash Fix
- 30-second throttle for Watch API transmissions
- Proper WebSocket connection state tracking
- 10-second reconnect delay to prevent storms

### Apple Watch Real-Time Vitals
- Added `HKWorkoutSession` for live heart rate streaming
- `startWorkoutSession()` / `stopWorkoutSession()` methods

---

## 2025-12-24 - WatchConnectivity & TestFlight Fix

### Problem
Watch app sending to wrong API endpoint in production (using local IP).

### Solution
- Watch requests API configuration from iPhone via `didReceiveMessage`
- Configuration stored in App Groups (`group.com.kindura.ai`)
- Automatic sync when WCSession activates

---

## 2025-12-13 - Dark Theme & Navigation Fixes

### Dark Theme
- Proper dark backgrounds throughout app
- Fixed tab bar with dark background
- Consistent text colors (white on dark)
- `ThemeController` for theme management with persistence

### Bug Fixes
- Fixed BottomNavigationBar appearing on sub-screens
- Fixed logout confirmation dialog styling
- Fixed profile buttons contrast issues

---

## 2025-12-09 - Dark Mode & App Icon

### Dark Mode
- Dark theme colors: background `#1A1A1A`, surface `#2D2D2D`
- Theme toggle in profile settings
- Fixed white flash on startup

### App Icon
- Updated app icon across all sizes (1024x1024 base)

---

## Key Architecture Notes

### Data Flow
```
Apple Watch → WCSession → iPhone AppDelegate → Flutter → Django API → PostgreSQL
                ↓
         HealthKit → HKObserverQuery → Flutter (event-driven)
```

### Health Update Triggers
1. **Apple Watch**: WCSession message (real-time on significant change)
2. **HealthKit Observer**: HKObserverQuery fires when data changes
3. **Manual Refresh**: User pull-to-refresh

### Key Files
- `ios/Runner/AppDelegate.swift` - WatchConnectivity, HealthKit, method channels
- `watchos/KinduraWatch/HealthManager.swift` - Watch health data collection
- `lib/screens/home/home_controller.dart` - Flutter health state management
- `lib/services/watch_vitals_service.dart` - Native bridge service
- `kinduralivekit-0.0.1/utils/watch_vitals_api.py` - Agent health data access
