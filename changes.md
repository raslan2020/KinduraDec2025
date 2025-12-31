# Kindura Development Changes Log

**Last Updated**: 2025-12-30

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
