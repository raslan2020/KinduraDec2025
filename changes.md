# Kindura Development Changes Log

**Last Updated**: 2026-01-10

---

## 2026-01-10 - Fix: Missing Back Button in Medical Reports Screen (Complete)

### Issue
Medical Reports screen was missing back navigation button in the top left.

### Fix
Added `showBackButton: true` to the CustomAppBar in `medical_reports_screen.dart`.

### Files Modified
- `lib/screens/medical_reports/medical_reports_screen.dart`

---

## 2026-01-10 - Fix: Database Migration for Analytics Fields (Complete)

### Issue
Reports were not loading/generating because the database was missing new columns (`activity_analytics`, `mobility_analytics`, `clinical_analytics`).

### Fix
Created and applied migration `users/migrations/0022_add_analytics_fields.py`.

### Files Created
- `KinduraAPIs-0.0.1/users/migrations/0022_add_analytics_fields.py`

---

## 2026-01-10 - Fix: Unintended Logout on API Errors (Complete)

### Issue
Clicking "Kindura Reports" was logging users out and redirecting to the login screen.

### Root Cause
The `FetchDataException` class in `lib/data/app_exceptions.dart` had side effects in its constructor that:
1. Called `userPreferences.removeUser()` - clearing the auth token
2. Called `Get.deleteAll()` - clearing all controllers
3. Navigated to splash screen with `Get.offAllNamed(RoutesName.splashScreen)`

This was triggered whenever any API call returned an unhandled status code (like 401, 500, etc.) and the response body wasn't valid JSON.

### Fix
1. **Removed auto-logout from FetchDataException** (`lib/data/app_exceptions.dart`)
   - Exceptions should not have side effects
   - Logout should only happen when user explicitly requests it

2. **Added proper HTTP status code handling** (`lib/data/network/network_api_services.dart`)
   - 401 Unauthorized: Returns error response with `unauthorized: true` flag
   - 403 Forbidden: Returns error response
   - 500/502/503/504: Returns server error response
   - Default: Returns error response instead of throwing exception

3. **Added UnauthorizedException class** for future use if needed

### Files Modified
- `lib/data/app_exceptions.dart` - Removed auto-logout, added UnauthorizedException
- `lib/data/network/network_api_services.dart` - Added proper status code handling

---

## 2026-01-10 - Monthly Report Enhancements (Complete)

### Feature
Enhanced monthly reports with comprehensive activity and mobility analytics, including previous month comparison tables and improved data persistence.

### Improvements

**1. Activity & Mobility Analytics Persistence** (`KinduraAPIs-0.0.1/users/report_service.py`)
- Added saving of `activity_analytics` to PatientReport model
  - avg_steps, total_steps, avg_calories, avg_distance_km, avg_exercise_minutes
  - activity_level classification (Very Active, Active, Moderate, Low, Sedentary)
  - step_goal_met_days tracking
- Added saving of `mobility_analytics` to PatientReport model
  - walking_asymmetry (avg_percent, status, readings)
  - walking_speed (avg_m_per_s, status)
  - double_support_time (avg_percent, status)
  - stair_climbing (avg_ascent_speed, avg_descent_speed)
  - six_minute_walk (avg_distance_m)
- Added saving of `clinical_analytics` with trends data
  - motor/non-motor symptoms, safety events, speech metrics, cognitive screening
  - symptom_trends, concerning_patterns, improving_patterns, correlations
- Added `extended_vitals` to vitals_analytics (BP, glucose, temperature, VO2 max, AFib, walking steadiness)

**2. Previous Month Comparison** (`KinduraAPIs-0.0.1/users/pdf_generator.py`)
- Monthly reports now fetch previous month's report for comparison
- `_get_comprehensive_clinical_data()` retrieves prev_avg_daily_steps and prev_mobility_data
- Enables trend analysis across reporting periods

**3. Mobility Assessment Table** (Monthly Reports Only)
- New table showing:
  - Walking Asymmetry: Current vs Previous with status and trend (↑ Worsening / ↓ Improving / → Stable)
  - Walking Speed: m/s with status and trend
  - Double Support Time: % with balance status and trend
  - Stair Ascent Speed: steps/min
  - Six-Minute Walk Distance: meters with trend
- Color-coded header (dark blue) for professional appearance

**4. Activity Summary Table** (Monthly Reports Only)
- New table showing:
  - Daily Steps (avg): Current vs Previous month with % change
  - Exercise (min/day): Average daily exercise
  - Distance (km/day): Average walking distance
  - Active Calories (kcal/day): Energy expenditure
  - Step Goal Met (7500): Days achieved / total days with success %
  - Activity Classification: Overall activity level
- Color-coded header (dark green) for visual distinction

### Key Field Mappings
- `mobility_analytics.walking_asymmetry.avg_percent` - Walking asymmetry %
- `mobility_analytics.walking_speed.avg_m_per_s` - Walking speed m/s
- `mobility_analytics.double_support_time.avg_percent` - Double support time %
- `activity_analytics.avg_steps` - Daily step average
- `activity_analytics.activity_level` - Activity classification

### Files Modified
- `KinduraAPIs-0.0.1/users/report_service.py` - Added analytics persistence
- `KinduraAPIs-0.0.1/users/pdf_generator.py` - Added tables and comparison logic

---

## 2026-01-10 - Comprehensive Clinical PDF Report Format (Complete)

### Feature
Completely rewrote the PDF report generator to match the professional Parkinson's Disease clinical report format with 12 structured sections designed for neurologist review.

### Report Structure (12 Sections)
1. **Chief Complaint / Visit Focus** - Auto-generated from symptom data, describes patient's primary concerns
2. **Interim History Since Last Visit** - Falls, hospitalizations, hallucinations, symptom progression
3. **Detailed Motor Symptom Assessment** - Table with Baseline, Current, Trend, Time-of-Day Pattern
   - Bradykinesia, Rest Tremor, Rigidity, Gait/Balance, Freezing
4. **Non-Motor Symptom Assessment** - Narrative text covering sleep, constipation, mood, hallucinations, autonomic symptoms
5. **Cognitive & Psychological Status** - MoCA-lite scores, PHQ-9 depression screening
6. **Functional Status & Quality of Life** - ADLs, walking endurance, speech, swallowing
7. **Lifestyle, Sleep, and Activity Review** - Sleep duration, daily steps, daytime napping, exercise
8. **Medication Review & Adherence** - Current medications, adherence %, late doses, wearing-off detection, side effects
9. **Objective Device-Derived Data** - Step trends, gait variability, falls, heart rate, HRV
10. **Laboratory & Diagnostic Review** - Abnormal biomarkers, lab values
11. **AI-Generated Clinical Considerations** - Observation, Confidence Level, Clinical Context
12. **Physician Assessment & Plan** - Blank lines for doctor to write notes

### Key Improvements
- **Baseline vs Current Comparison**: Motor symptoms show previous period as baseline for trend analysis
- **Time-of-Day Patterns**: Identifies "Worse afternoons", "Pre-dose", "End of day" patterns for wearing-off detection
- **Trend Analysis**: Automatic classification (Gradual worsening, Mild increase, Stable, Improving)
- **Narrative Style**: Professional prose instead of just data tables
- **Wearing-Off Detection**: Correlates rigidity patterns with dosing timing
- **Freezing of Gait**: New tracking with Absent/Occasional/Frequent status
- **Confidence Level**: High/Medium/Low based on data completeness
- **Proper Clinical Disclaimer**: "Intended to support, not replace, clinical judgment. Kindura does not diagnose or prescribe."

### Data Sources Utilized
- Motor symptom entries (daily self-reported, 1-5 scale)
- Non-motor symptom entries (weekly self-reported)
- Safety events (falls, hallucinations, rapid worsening)
- Cognitive screening (MoCA-lite, PHQ-9)
- Medication adherence (doses taken, missed, late)
- Device vitals (heart rate, HRV from Apple Watch)
- Activity data (steps, exercise minutes)
- Sleep analytics (hours, stages)
- Lab biomarkers (abnormalities)

### Files Modified
- `KinduraAPIs-0.0.1/users/pdf_generator.py` - Complete rewrite with 12-section format

---

## 2026-01-10 - Report Generation UX Improvements (Complete)

### Feature
Improved the report generation UX so users aren't blocked while waiting for reports. The progress indicator is now a small inline banner at the top of the reports screen, and users receive a push notification when the report is ready.

### Changes

**1. Inline Progress Banner** (`lib/common_widgets/report_progress_banner.dart` - NEW)
- Small, non-blocking banner at top of reports screen
- Shows spinning indicator, report type, and progress percentage
- Automatically hides when not generating
- Doesn't block user from navigating or interacting

**2. Push Notification on Completion** (`lib/services/report_generation_service.dart`)
- Added `_sendReportReadyNotification()` method
- Sends local notification when report is complete
- User can tap notification to view the report
- Works even if user navigates away from reports screen

**3. Removed Global Floating Overlay**
- Removed `ReportProgressOverlay` from bottom_navigation_screen.dart
- Old overlay was floating at bottom of all screens - now inline only in reports

**4. Fixed Stuck Report**
- Reset monthly report that was stuck at 90% for 7 days
- Added 60-second timeout to OpenAI API call to prevent future hangs

### User Experience
1. User taps "Generate Report" button
2. Small inline banner appears at top showing progress
3. User can freely navigate to other tabs (Home, Labs, Meds, Profile)
4. When report completes, user receives push notification
5. Tapping notification opens the report

### Files Created
- `lib/common_widgets/report_progress_banner.dart`

### Files Modified
- `lib/services/report_generation_service.dart` - Added notification support
- `lib/screens/kindura_reports/kindura_reports_screen.dart` - Added inline banner
- `lib/screens/bottom_navigation/bottom_navigation_screen.dart` - Removed global overlay
- `KinduraAPIs-0.0.1/users/report_service.py` - Added timeout to OpenAI call

---

## 2026-01-09 - Comprehensive AI Report Generation (Complete)

### Feature
Enhanced the report generation service to analyze ALL available data sources for comprehensive AI-generated clinical reports. The AI now considers labs, medical reports, HealthKit vitals, agent conversations, clinical symptoms, trends, and patterns to provide actionable insights for neurologists.

### Data Sources Now Analyzed
1. **Clinical Data** (per Reports.md) - Motor symptoms, non-motor symptoms, safety events
2. **HealthKit Vitals** - Heart rate, SpO2, HRV, sleep stages, activity
3. **Medication Adherence** - Doses taken/missed, timing, side effects
4. **Lab Results & Biomarkers** - Abnormalities, trends, critical values
5. **Conversation Insights** - Topics discussed, concerns raised, mood observations
6. **Medical Reports** - Uploaded documents and their AI summaries
7. **Trend Analysis** - Patterns across all data sources

### New Collection Methods Added to ReportService
- `_collect_clinical_data()` - Motor/non-motor symptoms, safety events, laterality
- `_collect_conversation_data()` - Agent conversation insights, topics, concerns
- `_collect_medical_reports()` - Uploaded medical documents and findings
- `_analyze_trends()` - Cross-source pattern analysis (worsening/improving trends)

### Enhanced AI Analysis
The AI prompt now includes:
- Parkinson's-specific clinical context (MDS-UPDRS awareness)
- Motor symptom progression tracking
- Medication wearing-off pattern detection
- Sleep-symptom correlations
- Safety event pattern analysis
- Data completeness validation per Reports.md

### New AI Response Fields
- `clinical_assessment` - Motor/non-motor symptom analysis
- `trend_summary` - Improving and worsening patterns
- `red_flags` - Safety events requiring immediate attention
- `data_gaps` - Missing data per Reports.md requirements

### Clinical Score Added
New health score weighting for Parkinson's Disease:
- Clinical Score: 35% (motor symptoms, safety events, data completeness)
- Adherence Score: 25%
- Sleep Score: 20%
- Vitals Score: 20%

### Files Modified
- `KinduraAPIs-0.0.1/users/report_service.py` - Added 4 new collection methods, enhanced AI prompt

---

## 2026-01-09 - Clinical Data Collection per Reports.md (Complete)

### Feature
Implemented clinical data collection system following the Reports.md specification for Parkinson's Disease monitoring. The AI agent now proactively collects motor symptoms daily, non-motor symptoms weekly, and records safety events. Flutter UI updated to display clinical data in reports.

### Reports.md Specification Coverage

**Core Motor Symptoms (Daily Collection)**
- Bradykinesia (1-5 scale) - mandatory core feature
- Tremor (1-5 scale)
- Rigidity (1-5 scale)
- Gait Difficulty (1-5 scale)
- Laterality (L/R/Both) - diagnostic relevance

**Non-Motor Symptoms (Weekly Collection)**
- Sleep disturbance / REM behavior
- Constipation
- Dizziness / autonomic symptoms
- Mood / apathy
- Fatigue
- Smell loss

**Safety Events (Event-Driven)**
- Falls
- Hallucinations
- Rapid symptom worsening
- Severe autonomic symptoms
- Poor levodopa response

### Backend Implementation

**1. Django Models** (`health_profile/models.py`)
- `PatientClinicalProfile` - Patient context data (age, onset, family history)
- `MotorSymptomEntry` - Daily motor symptom recordings
- `NonMotorSymptomEntry` - Weekly non-motor symptom recordings
- `MedicationDoseEntry` - Per-dose medication tracking
- `SafetyEvent` - Safety event logging with severity
- `SpeechMetrics` - Weekly voice/speech metrics
- `CognitiveScreening` - Monthly MoCA-lite and PHQ-9 scores
- `ClinicalReport` - Generated clinical reports
- `AgentDataCollection` - Tracks data gaps for agent prompts

**2. Serializers** (`health_profile/serializers.py`)
- Added serializers for all clinical data models
- `AgentSymptomCollectionSerializer` - Simplified one-symptom-at-a-time collection
- `DataGapsSerializer` - Returns prioritized questions with prompts

**3. API Views** (`health_profile/views.py`)
- `MotorSymptomView` - Motor symptom CRUD
- `NonMotorSymptomView` - Non-motor symptom CRUD
- `SafetyEventView` - Safety event logging
- `CognitiveScreeningView` - PHQ-9 with Q9 escalation check
- `ClinicalReportView` - Report retrieval
- `AgentDataGapsView` - Returns what the agent needs to ask
- `AgentSymptomCollectView` - Single symptom submission endpoint

**4. Clinical Data in Patient Reports** (`users/views.py`)
- Added `_get_clinical_data_for_period()` helper method
- Patient reports now include `clinical_data` with:
  - Motor symptoms list and averages
  - Non-motor symptoms list and averages
  - Safety events
  - Data completeness percentage (per Reports.md Section 6)

### LiveKit Agent Updates

**5. Clinical Data API Service** (`kinduralivekit-0.0.1/utils/clinical_data_api.py` - NEW)
- `ClinicalDataAPI` class for agent to call backend
- Methods: `get_data_gaps()`, `collect_symptom()`, `record_safety_event()`
- Formatting helpers for agent context

**6. Agent Function Tools** (`kinduralivekit-0.0.1/agent.py`)
- `get_clinical_data_gaps` - Get list of questions to ask
- `record_bradykinesia`, `record_tremor`, `record_rigidity`, `record_gait_difficulty` - Motor symptoms
- `record_laterality` - Which side is more affected
- `record_safety_event` - Log falls, hallucinations, etc.
- `get_motor_symptom_history` - Get recent symptom trends
- `get_clinical_reports` - Access clinical reports

**7. Agent Prompt Updates** (`kinduralivekit-0.0.1/utils/global_variables.py`)
- Added "CLINICAL DATA COLLECTION" section to agent prompt
- Daily prompts: "How stiff did you feel today, 1-5?"
- Weekly prompts: Non-motor symptoms (sleep, constipation, etc.)
- Collection rules: One symptom per question, ≤12 words, 1-5 scale
- Safety event handling with escalation

**8. Report Generation Command** (`health_profile/management/commands/generate_clinical_reports.py`)
- Management command to generate daily/weekly/monthly clinical reports
- Calculates data completeness per Reports.md thresholds
- Daily ≥60%, Weekly ≥4 days, Monthly ≥70%
- Identifies red flags and generates AI insights

### Flutter UI Updates

**9. New Clinical Tab in Reports** (`lib/screens/kindura_reports/kindura_reports_screen.dart`)
- Added "Clinical" tab to report detail view (now 6 tabs)
- `_buildClinicalTab()` - Main clinical data display
- `_buildCompletenessCard()` - Shows data completeness %
- `_buildSafetyEventsCard()` - Displays falls, hallucinations, etc.
- `_buildMotorSymptomsCard()` - Motor symptom bars with trend chart
- `_buildNonMotorSymptomsCard()` - Non-motor symptom bars
- `_buildSymptomBar()` - Color-coded progress bars (1-5 scale)
- `_buildMotorTrendChart()` - Line chart showing symptom trends

**10. Clinical API URLs** (`lib/res/app_url/app_url.dart`)
- `clinicalProfileUrl` - Patient clinical profile
- `motorSymptomsUrl` - Motor symptoms endpoint
- `nonMotorSymptomsUrl` - Non-motor symptoms endpoint
- `safetyEventsUrl` - Safety events endpoint
- `clinicalReportsUrl` - Clinical reports
- `agentDataGapsUrl` - Agent data gaps

### Data Collection Rules (per Reports.md Section 4)
- One symptom per question
- ≤ 12 words per prompt
- Numeric scales (1-5) preferred
- Plain language only
- No diagnostic phrasing

Example agent prompts:
- "How stiff did you feel today, from 1 to 5?"
- "Any trouble with balance or walking today?"
- "Did you experience any tremor today, 1-5?"

### Files Created
- `KinduraAPIs-0.0.1/health_profile/migrations/0008_add_clinical_data_models.py`
- `KinduraAPIs-0.0.1/health_profile/management/commands/generate_clinical_reports.py`
- `kinduralivekit-0.0.1/utils/clinical_data_api.py`

### Files Modified
- `KinduraAPIs-0.0.1/health_profile/models.py` - Added 9 clinical data models
- `KinduraAPIs-0.0.1/health_profile/serializers.py` - Added clinical serializers
- `KinduraAPIs-0.0.1/health_profile/views.py` - Added clinical API views
- `KinduraAPIs-0.0.1/medical_app/urls.py` - Added clinical API URLs
- `KinduraAPIs-0.0.1/users/views.py` - Added clinical data to patient reports
- `kinduralivekit-0.0.1/agent.py` - Added clinical data collection tools
- `kinduralivekit-0.0.1/utils/global_variables.py` - Updated agent prompt
- `lib/screens/kindura_reports/kindura_reports_screen.dart` - Added Clinical tab
- `lib/res/app_url/app_url.dart` - Added clinical endpoints

### Migrations
- `health_profile/migrations/0008_add_clinical_data_models.py`

---

## 2026-01-09 - Individual Extended Vitals Toggle Settings (Complete)

### Feature
Added granular control for users to enable/disable each extended vital individually from Settings. Users can now choose exactly which health metrics they want to see displayed on their home screen.

### Settings UI
When "Extended Vitals Collection" is enabled, a new "Individual Vitals" section appears with:
- **All On / All Off** quick toggle buttons
- **4 categorized groups** with color-coded headers:
  - **Cardiovascular** (Red): Blood Pressure, AFib Detection
  - **Metabolic** (Orange): Blood Glucose, Body Temperature, Wrist Temperature
  - **Fitness** (Blue): VO2 Max, Perfusion Index
  - **Mobility** (Teal): Walking Steadiness, Walking Speed, Walking Asymmetry, 6-Min Walk, Balance, Stair Ascent/Descent

### Implementation

**1. Django Backend**
- Added `extended_vitals_preferences` JSONField to User model
- Updated UserProfileSerializer to include the new field
- Created migration `0021_add_extended_vitals_preferences.py`

**2. Flutter Model (`user_profile_model.dart`)**
- Added `extendedVitalsPreferences` field (Map<String, bool>)
- Created `ExtendedVitalsPreferences` class with:
  - `defaults` - default enabled state for all vitals
  - `displayNames` - human-readable names for each vital
  - `categories` - grouping of vitals by category

**3. Profile Controller (`profile_controller.dart`)**
- Added `extendedVitalsPreferences` observable
- Added helper methods: `isVitalEnabled()`, `toggleVital()`, `enableAllVitals()`, `disableAllVitals()`
- Updated `saveProfile()` to include preferences in API call

**4. Profile Screen (`profile_screen.dart`)**
- Added `_buildExtendedVitalsToggles()` method
- Added `_buildVitalCategory()` method for categorized display
- Category headers with icons and colors
- SwitchListTile for each individual vital

**5. Home Screen (`home_screen.dart`)**
- Updated `_buildExtendedVitalsSection()` to check user preferences
- Only displays vitals that are enabled in user preferences
- Hidden vitals don't appear even if data exists

### Files Modified
- `KinduraAPIs-0.0.1/users/models.py`
- `KinduraAPIs-0.0.1/users/serializers.py`
- `lib/models/user_profile/user_profile_model.dart`
- `lib/screens/profile/profile_controller.dart`
- `lib/screens/profile/profile_screen.dart`
- `lib/screens/home/home_screen.dart`

### Migrations
- `users/migrations/0021_add_extended_vitals_preferences.py`

---

## 2026-01-09 - Extended Vitals Home Screen Display (Complete)

### Feature
Added comprehensive extended vitals display to the home screen health widget. All 17 extended health metrics from HealthKit are now visible when data is available.

### Extended Vitals Now Displayed

**Primary Vitals Section:**
- Blood Glucose (mg/dL) - with color-coded status
- Blood Pressure (systolic/diastolic) - with BP classification colors
- Body Temperature (°C) - with fever detection colors
- Wrist Temperature Delta (°C) - Apple Watch baseline deviation
- VO2 Max - cardiovascular fitness indicator
- Peripheral Perfusion Index (%) - blood flow quality

**Mobility Section:**
- Six-Minute Walk Distance (m) - cardiopulmonary fitness test
- Walking Speed (m/s) - gait speed indicator
- Walking Asymmetry (%) - leg movement balance
- Double Support Time (%) - balance indicator
- Stair Ascent Speed (m/s)
- Stair Descent Speed (m/s)

**Special Alerts:**
- AFib Detection banner with burden percentage
- Walking Steadiness classification (OK/Low/Very Low)

### Implementation

**1. Home Controller (`home_controller.dart`)**
- Added `getExtendedVitals()` call in `loadWatchVitals()`
- Merges all 17 extended vitals into the watchVitals observable
- Logs extended vitals in summary output

**2. Home Screen (`home_screen.dart`)**
- Updated `_buildExtendedVitalsSection()` to show ALL extended vitals
- Added new "Mobility" sub-section for walking/stair metrics
- Added color helper functions for wrist temp delta and walking asymmetry
- Removed requirement for `extended_vitals_enabled` flag - now shows if data exists

### Color-Coded Health Indicators
- Walking Asymmetry: Green (<8%), Orange (8-15%), Red (>15%)
- Wrist Temp Delta: Green (±0.5°C), Orange (±1°C), Red (>1°C deviation)
- All existing color functions retained (BP, glucose, temp, VO2 max, etc.)

### Files Modified
- `lib/screens/home/home_controller.dart` - Extended vitals fetching
- `lib/screens/home/home_screen.dart` - Extended vitals UI display

---

## 2026-01-09 - Extended Vitals & Data Retention Settings (Complete)

### Feature
Added support for extended HealthKit vitals collection and user-configurable data retention periods. Users can now enable collection of 17+ additional health metrics and choose how long their vitals data is retained (30 or 60 days).

### Extended Vitals Added (17 new metrics)
- **Cardiovascular**: Blood pressure (systolic/diastolic), AFib detection, AFib burden %
- **Metabolic**: Blood glucose, body temperature, wrist temperature delta
- **Fitness**: VO2 Max, walking steadiness (% and classification), walking speed, walking asymmetry
- **Mobility**: Stair ascent/descent speed, six-minute walk distance, double support time (balance)
- **Other**: Peripheral perfusion index, sleep apnea detection (AHI score)

### Implementation

**1. Django Backend (KinduraAPIs-0.0.1)**
- `health_profile/models.py` - Added 17 extended vitals fields to WatchVitals model
- `health_profile/serializers.py` - Updated serializer with all new fields
- `health_profile/migrations/0007_add_extended_vitals_and_retention.py` - Migration for health_profile
- `users/models.py` - Added `extended_vitals_enabled` (bool) and `vitals_retention_days` (int) to User
- `users/serializers.py` - Updated UserSerializer with new fields
- `users/migrations/0020_add_extended_vitals_and_retention.py` - Migration for users

**2. Flutter Frontend**
- `lib/models/user_profile/user_profile_model.dart` - Added `extendedVitalsEnabled` and `vitalsRetentionDays` fields
- `lib/screens/profile/profile_controller.dart` - Added observable variables and included in saveProfile() API call
- `lib/screens/profile/profile_screen.dart` - UI toggle for extended vitals and retention period picker

**3. iOS/watchOS Native**
- `watchos/KinduraWatch/HealthManager.swift` - Extended vitals properties already present (BP, glucose, temp, AFib)
- `ios/Runner/AppDelegate.swift` - `fetchExtendedVitals()` method for HealthKit queries

### User Settings
- **Extended Vitals Toggle**: Enable/disable collection of additional health metrics
- **Data Retention**: Choose 30 or 60 days for vitals data retention

### Files Modified
- `KinduraAPIs-0.0.1/health_profile/models.py`
- `KinduraAPIs-0.0.1/health_profile/serializers.py`
- `KinduraAPIs-0.0.1/users/models.py`
- `KinduraAPIs-0.0.1/users/serializers.py`
- `lib/models/user_profile/user_profile_model.dart`
- `lib/screens/profile/profile_controller.dart`
- `lib/screens/profile/profile_screen.dart`

---

## 2026-01-09 - Settings Dialog UI Overflow Fix

### Problem
The Settings dialog had a UI overflow (57 pixels) in the Fall Detection section. The title "How to Enable Apple Fall Detection" was too long for the container width.

### Solution
- Shortened title from "How to Enable Apple Fall Detection" to "Enable Apple Fall Detection"
- Changed `Expanded` to `Flexible` for better text handling
- Reduced icon size from 22.sp to 20.sp to give more space

### Files Modified
- `lib/screens/profile/profile_screen.dart` - Fixed header row in Fall Detection section

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
