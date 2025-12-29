# Kindura Development Changes Log

**Last Updated**: 2025-12-29

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
