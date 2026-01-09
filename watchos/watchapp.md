# KinduraWatch - Apple Watch App Documentation

**Last Updated**: 2026-01-08 (Updated with iPhone sync requirements)
**App Version**: 1.0
**Platform**: watchOS (Native Swift/SwiftUI) - **NOT Flutter**

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [File Structure](#file-structure)
4. [Technologies Used](#technologies-used)
5. [Features](#features)
6. [Data Flow](#data-flow)
7. [How to Edit/Update](#how-to-editupdate)
8. [Graphics & Assets](#graphics--assets)
9. [Configuration & Settings](#configuration--settings)
10. [Building & Deployment](#building--deployment)
11. [Moving to Another Location/PC](#moving-to-another-locationpc)
12. [Troubleshooting](#troubleshooting)
13. [API Reference](#api-reference)
14. [iPhone App Requirements](#iphone-app-requirements-appdelegateswift)

---

## Overview

KinduraWatch is a **100% native Apple Watch app** built with Swift and SwiftUI. It is NOT built with Flutter or any cross-platform framework. The app:

- Monitors health vitals in real-time (Heart Rate, Blood Oxygen, HRV, Respiratory Rate)
- Tracks sleep data and stages
- Detects falls using CoreMotion accelerometer
- Syncs data to iPhone app via WatchConnectivity
- Collects activity data (steps, calories, distance, floors, exercise)

### Companion App Relationship

```
┌─────────────────────────────────────────────────────────────┐
│                    KinduraWatch (watchOS)                   │
│                   Bundle ID: com.kindura.ai.watchkitapp     │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │HealthManager│  │ContentView  │  │ConfigurationManager │ │
│  │ (HealthKit) │  │ (SwiftUI)   │  │ (App Groups)        │ │
│  └──────┬──────┘  └─────────────┘  └──────────┬──────────┘ │
│         │                                      │            │
│         │ WCSession.sendMessage()              │            │
│         │ WCSession.transferUserInfo()         │            │
│         └──────────────────┬───────────────────┘            │
└────────────────────────────│────────────────────────────────┘
                             │
                    WatchConnectivity
                             │
┌────────────────────────────│────────────────────────────────┐
│                            ▼                                │
│                 Kindura iOS App (Flutter)                   │
│                 Bundle ID: com.kindura.ai                   │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ AppDelegate.swift                                      │ │
│  │ - didReceiveMessage()                                  │ │
│  │ - didReceiveUserInfo()                                 │ │
│  │ - forwardVitalsToDjango()                              │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## Architecture

### Design Pattern
- **SwiftUI App Lifecycle** (@main, App protocol)
- **ObservableObject** pattern for state management
- **@EnvironmentObject** for dependency injection
- **Singleton** for ConfigurationManager

### Main Components

| Component | Purpose |
|-----------|---------|
| `KinduraWatchApp` | App entry point, initializes HealthManager |
| `HealthManager` | Core health data collection and communication |
| `ContentView` | Main UI with tab navigation |
| `ConfigurationManager` | Manages API configuration via App Groups |
| `SettingsView` | User settings and status display |

---

## File Structure

```
/Users/ralabaji/Kinduraios/watchos/
│
├── KinduraWatch/                          # Source Code
│   │
│   ├── KinduraWatchApp.swift             # App entry point (@main)
│   │   - Initializes HealthManager as @StateObject
│   │   - Auto-starts health monitoring on launch
│   │   - Requests HealthKit authorization
│   │
│   ├── HealthManager.swift               # Core health data manager (57KB)
│   │   - HealthKit queries and authorization
│   │   - WatchConnectivity (WCSession) communication
│   │   - HKWorkoutSession for real-time heart rate
│   │   - CoreMotion fall detection
│   │   - Data buffering and guaranteed delivery
│   │   - Activity data collection
│   │
│   ├── ContentView.swift                 # Main UI (TabView)
│   │   - VitalsView: Heart Rate, SpO2, HRV, Respiratory
│   │   - SleepView: Sleep duration and stages
│   │   - FallDetectionView: G-force, fall history, SOS
│   │   - VitalCard: Reusable vital display component
│   │
│   ├── SettingsView.swift                # Settings screen
│   │   - Backend connection status
│   │   - HealthKit authorization button
│   │   - Workout session controls
│   │   - Background query controls
│   │
│   ├── ConfigurationManager.swift        # API configuration
│   │   - App Groups storage (group.com.kindura.ai)
│   │   - API base URL and auth token storage
│   │   - Offline vitals buffering
│   │
│   ├── Info.plist                        # App configuration
│   │   - Bundle display name: "Kindura"
│   │   - HealthKit usage descriptions
│   │   - Background modes
│   │   - Companion app bundle ID
│   │
│   ├── KinduraWatch.entitlements         # App capabilities
│   │   - com.apple.developer.healthkit
│   │   - com.apple.developer.healthkit.background-delivery
│   │   - com.apple.security.application-groups
│   │
│   └── Assets.xcassets/                  # Graphics
│       └── AppIcon.appiconset/           # App icons (all sizes)
│
├── KinduraWatch.xcodeproj/               # Xcode project
│   ├── project.pbxproj                   # Build settings
│   ├── project.xcworkspace/              # Workspace settings
│   └── xcuserdata/                       # User-specific settings
│
└── build/                                # Build output (generated)
```

---

## Technologies Used

| Technology | Purpose | Version |
|------------|---------|---------|
| **Swift** | Programming language | 5.9+ |
| **SwiftUI** | UI framework | watchOS 9.0+ |
| **HealthKit** | Health data access | Native |
| **WatchConnectivity** | iPhone communication | Native |
| **CoreMotion** | Accelerometer for falls | Native |
| **Combine** | Reactive data binding | Native |

### Frameworks Imported

```swift
import Foundation
import HealthKit
import SwiftUI
import Combine
import WatchConnectivity
import WatchKit
import CoreMotion
```

---

## Features

### 1. Vitals Monitoring
- **Heart Rate**: Real-time BPM via HKWorkoutSession
- **Blood Oxygen (SpO2)**: Percentage from HealthKit
- **HRV**: Heart Rate Variability in milliseconds
- **Respiratory Rate**: Breaths per minute

### 2. Sleep Tracking
- Total sleep hours
- Sleep stages (Deep, REM, Core, Awake)
- Awakenings count
- Sleep quality indicators

### 3. Fall Detection
- Real-time G-force monitoring via CoreMotion
- Free-fall detection (< 0.3G)
- Impact detection (> 3G)
- Fall severity classification (low/medium/high)
- Emergency SOS button
- Fall event history

### 4. Activity Data
- Steps count
- Calories burned
- Distance (km)
- Floors climbed
- Exercise minutes
- Stand minutes

### 5. Data Sync
- Real-time sync when iPhone reachable
- Guaranteed delivery via `transferUserInfo()`
- Offline buffering with UserDefaults
- Application context for latest state

---

## Data Flow

### Vitals Collection Flow

```
┌──────────────────────────────────────────────────────────┐
│                    HealthManager                          │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  1. HealthKit Queries                                    │
│     ├── HKObserverQuery (background updates)             │
│     ├── HKAnchoredObjectQuery (real-time)                │
│     └── HKStatisticsQuery (aggregated data)              │
│                                                          │
│  2. HKWorkoutSession (live heart rate)                   │
│     └── HKLiveWorkoutBuilder                             │
│                                                          │
│  3. CoreMotion (fall detection)                          │
│     └── CMMotionManager.startAccelerometerUpdates()      │
│                                                          │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  createVitalsPayload() → [String: Any] dictionary        │
│                                                          │
│  {                                                       │
│    "type": "watch_vitals",                               │
│    "timestamp": "2024-01-08T10:30:00Z",                  │
│    "heart_rate": 72,                                     │
│    "blood_oxygen": 98,                                   │
│    "hrv": 42,                                            │
│    "respiratory_rate": 16,                               │
│    "total_sleep_hours": 7.5,                             │
│    "steps": 8432,                                        │
│    "calories": 420,                                      │
│    ...                                                   │
│  }                                                       │
│                                                          │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  sendVitalsToiPhone()                                    │
│     │                                                    │
│     ├── isReachable? → WCSession.sendMessage()           │
│     │                     ↓ (real-time)                  │
│     │                  iPhone AppDelegate                │
│     │                                                    │
│     └── Not reachable? → bufferVitals()                  │
│                          ├── Save to UserDefaults        │
│                          └── transferUserInfo()          │
│                              (guaranteed delivery)       │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

### Communication Methods

| Method | Use Case | Delivery |
|--------|----------|----------|
| `sendMessage()` | Real-time when reachable | Immediate |
| `transferUserInfo()` | Guaranteed delivery | Queued |
| `updateApplicationContext()` | Latest state sync | Replaced |
| `UserDefaults` buffering | Offline storage | Persisted |

---

## How to Edit/Update

### Opening the Project

```bash
# Open in Xcode
open /Users/ralabaji/Kinduraios/watchos/KinduraWatch.xcodeproj
```

### Making UI Changes

**File**: `ContentView.swift`

The UI is organized into tabs:
- Tab 0: `VitalsView` - Edit vital cards here
- Tab 1: `SleepView` - Edit sleep display here
- Tab 2: `FallDetectionView` - Edit fall detection UI here
- Tab 3: `SettingsView` - Edit settings here

Example - Adding a new vital card:
```swift
// In VitalsView body
VitalCard(
    icon: "figure.walk",        // SF Symbol name
    iconColor: .green,          // Color
    title: "Steps",             // Label
    value: "\(healthManager.steps)",  // Value
    unit: "steps"               // Unit
)
```

### Adding New Health Data Types

**File**: `HealthManager.swift`

1. Add published property:
```swift
@Published var newMetric: Double = 0
```

2. Add to `requestAuthorization()` types array:
```swift
let typesToRead: Set<HKObjectType> = [
    // ... existing types
    HKObjectType.quantityType(forIdentifier: .newHealthType)!
]
```

3. Create fetch method:
```swift
func fetchNewMetric() {
    guard let type = HKQuantityType.quantityType(forIdentifier: .newHealthType) else { return }
    // Query implementation
}
```

4. Add to `createVitalsPayload()`:
```swift
"new_metric": newMetric
```

### Changing Communication Logic

**File**: `HealthManager.swift`

Key methods:
- `sendVitalsToiPhone()` - Main send logic
- `bufferVitals()` - Offline buffering
- `sendBufferedVitals()` - Retry buffered data
- `sendVitalsViaTransferUserInfo()` - Guaranteed delivery

### Changing Fall Detection Sensitivity

**File**: `HealthManager.swift`

```swift
// Fall detection thresholds (around line 77)
private let freeFallThreshold: Double = 0.3      // Below = free fall
private let impactThreshold: Double = 3.0        // Above = hard impact
private let fallConfirmationWindow: TimeInterval = 2.0
```

---

## Graphics & Assets

### App Icon Location

```
/Users/ralabaji/Kinduraios/watchos/KinduraWatch/Assets.xcassets/AppIcon.appiconset/
```

### Required Icon Sizes

| Size | Scale | Pixels | Use |
|------|-------|--------|-----|
| 1024 | @1x | 1024x1024 | App Store |
| 129 | @2x | 258x258 | Apple Watch Ultra |
| 117 | @2x | 234x234 | 45mm Watch |
| 108 | @2x | 216x216 | 44mm Watch |
| 98 | @2x | 196x196 | 42mm Watch |
| 86 | @2x | 172x172 | 40mm Watch |
| 54 | @2x | 108x108 | Short Look (Ultra) |
| 51 | @2x | 102x102 | Short Look (45mm) |
| 50 | @2x | 100x100 | Short Look (44mm) |
| 46 | @2x | 92x92 | Short Look (42mm) |
| 44 | @2x | 88x88 | Short Look (40mm) |
| 40 | @2x | 80x80 | Short Look (38mm) |
| 33 | @2x | 66x66 | Notification Center |
| 29 | @2x/@3x | 58/87 | Settings |
| 27.5 | @2x | 55x55 | Notification Center |
| 24 | @2x | 48x48 | Notification Center |

### Updating App Icon

1. Create a 1024x1024 PNG with your new icon
2. Use an icon generator tool (e.g., App Icon Generator, makeappicon.com)
3. Replace files in `Assets.xcassets/AppIcon.appiconset/`
4. Update `Contents.json` if filenames change

### SF Symbols Used

The app uses Apple's SF Symbols for icons:
- `heart.fill` - Heart rate
- `lungs.fill` - Blood oxygen
- `waveform.path.ecg` - HRV
- `wind` - Respiratory rate
- `moon.fill` - Sleep
- `figure.fall` - Fall detection
- `gearshape.fill` - Settings
- `sos` - Emergency button

---

## Configuration & Settings

### Info.plist Key Settings

| Key | Value | Purpose |
|-----|-------|---------|
| `CFBundleDisplayName` | Kindura | App name on Watch |
| `WKCompanionAppBundleIdentifier` | com.kindura.ai | Links to iOS app |
| `WKRunsIndependentlyOfCompanionApp` | true | Can run standalone |
| `NSHealthShareUsageDescription` | (Privacy text) | HealthKit permission |
| `UIBackgroundModes` | health-sharing, workout-processing | Background access |

### Entitlements

| Entitlement | Purpose |
|-------------|---------|
| `com.apple.developer.healthkit` | Access HealthKit |
| `com.apple.developer.healthkit.background-delivery` | Background health updates |
| `com.apple.security.application-groups` | Share data with iOS app |

### App Groups

The Watch and iOS apps share data via App Groups:
```
group.com.kindura.ai
```

Stored data:
- `api_base_url` - Backend API URL
- `auth_token` - Authentication token
- `pending_vitals` - Buffered vitals for sync

---

## Building & Deployment

### Prerequisites

- Mac with Xcode 15+ installed
- Apple Developer account ($99/year)
- watchOS 9.0+ target device

### Build for Development

```bash
# Open Xcode
open /Users/ralabaji/Kinduraios/watchos/KinduraWatch.xcodeproj

# Or build from command line
xcodebuild -project /Users/ralabaji/Kinduraios/watchos/KinduraWatch.xcodeproj \
           -scheme KinduraWatch \
           -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'
```

### Build for TestFlight/App Store

1. **Configure Signing**
   - Open Xcode project
   - Select KinduraWatch target
   - Go to Signing & Capabilities
   - Select your Team
   - Ensure Bundle ID matches App Store Connect

2. **Set Version Numbers**
   - Target → General → Version (e.g., 1.0.1)
   - Target → General → Build (e.g., 2)

3. **Archive**
   - Product → Destination → Any watchOS Device
   - Product → Archive
   - Wait for build to complete

4. **Upload**
   - In Organizer, select archive
   - Click "Distribute App"
   - Choose "App Store Connect" → "Upload"
   - Follow prompts

5. **TestFlight**
   - Go to App Store Connect
   - Select app → TestFlight
   - Wait for processing (5-30 min)
   - Add testers

### Command Line Archive

```bash
xcodebuild -project /Users/ralabaji/Kinduraios/watchos/KinduraWatch.xcodeproj \
           -scheme KinduraWatch \
           -destination 'generic/platform=watchOS' \
           -archivePath ./KinduraWatch.xcarchive \
           archive

# Then upload via Xcode or Transporter app
```

---

## Moving to Another Location/PC

### What to Copy

Copy the entire `watchos` folder:
```
/Users/ralabaji/Kinduraios/watchos/
├── KinduraWatch/              # REQUIRED - Source code
├── KinduraWatch.xcodeproj/    # REQUIRED - Project file
└── build/                     # OPTIONAL - Can be regenerated
```

### Steps to Move

1. **Copy Files**
```bash
# Copy to new location
cp -R /Users/ralabaji/Kinduraios/watchos /path/to/new/location/
```

2. **Open on New Machine**
```bash
open /path/to/new/location/watchos/KinduraWatch.xcodeproj
```

3. **Update Signing**
   - Select new development team in Xcode
   - Xcode will re-provision automatically

4. **Clean Build**
```bash
# Remove old build artifacts
rm -rf /path/to/new/location/watchos/build
rm -rf ~/Library/Developer/Xcode/DerivedData/KinduraWatch-*
```

### Bundle Identifier Notes

If moving to a different Apple Developer account, you may need to:
1. Change Bundle ID in Info.plist
2. Update App Groups identifier
3. Update `WKCompanionAppBundleIdentifier` to match iOS app
4. Create new provisioning profiles

### Dependencies

The app has **NO external dependencies** (CocoaPods, SPM, etc.). All frameworks are Apple-native:
- HealthKit
- WatchConnectivity
- CoreMotion
- SwiftUI
- Combine

---

## Troubleshooting

### Common Issues

#### "WCSession not reachable"
- Ensure iPhone app is running
- Check both devices are signed into same iCloud
- Restart both Watch and iPhone apps

#### "HealthKit authorization failed"
- Go to Watch Settings → Health → Apps → Kindura
- Enable all health permissions
- Re-authorize from app Settings tab

#### "Configuration not received"
- Open iPhone Kindura app first
- Tap "Request Config from iPhone" in Watch Settings
- Check App Groups are configured on both apps

#### Build Errors
```bash
# Clean build folder
Product → Clean Build Folder (Shift+Cmd+K)

# Delete derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/KinduraWatch-*
```

#### Signing Issues
- Ensure Apple Developer account is active
- Check team selection in Signing & Capabilities
- Delete and re-download provisioning profiles

### Debug Logging

Console logs are prefixed with `[HealthManager]`, `[ConfigurationManager]`, etc.

View logs:
1. Connect Watch to Mac
2. Open Xcode → Window → Devices and Simulators
3. Select Watch → Open Console

### Testing Fall Detection

1. Enable fall detection in Settings
2. Watch the G-force display
3. Sharply drop and catch the watch (careful!)
4. G-force should spike above 3G
5. Fall should be logged in history

---

## API Reference

### HealthManager Key Methods (Watch Side)

| Method | Description |
|--------|-------------|
| `requestAuthorization()` | Request HealthKit permissions |
| `startWorkoutSession()` | Start real-time heart rate |
| `stopWorkoutSession()` | Stop workout session |
| `startRealTimeMonitoring()` | Start background queries |
| `stopRealTimeMonitoring()` | Stop background queries |
| `startFallDetection()` | Enable CoreMotion monitoring |
| `sendVitalsToiPhone()` | Send data to iPhone |
| `sendFallAlertToiPhone()` | Send fall alert (critical, never dropped) |
| `bufferVitals()` | Store vitals when iPhone unreachable |
| `bufferFallAlert()` | Store fall alerts (persistent) |
| `sendBufferedVitals()` | Retry buffered vitals |
| `sendBufferedFallAlerts()` | Retry buffered fall alerts |
| `fetchLatestVitals()` | Query latest health data |
| `fetchSleepData()` | Query sleep data |
| `fetchActivityData()` | Query activity data |
| `createVitalsPayload()` | Build vitals dictionary for sync |
| `checkReachabilityAndSync()` | Periodic check for iPhone and sync |

### ConfigurationManager Key Methods (Watch Side)

| Method | Description |
|--------|-------------|
| `loadConfiguration()` | Load from App Groups |
| `updateConfiguration()` | Save new config |
| `clearConfiguration()` | Clear stored config |
| `storePendingVitals()` | Buffer for offline |
| `retrievePendingVitals()` | Get buffered data |

---

## iPhone App Requirements (AppDelegate.swift)

**CRITICAL**: The iPhone app (Flutter) requires native Swift code in `AppDelegate.swift` to receive and process Watch data. The Watch app will NOT work without these iPhone-side functions.

**File Location**: `/Users/ralabaji/Kinduraios/ios/Runner/AppDelegate.swift`

### Required WCSessionDelegate Methods

The iPhone AppDelegate MUST implement `WCSessionDelegate` with these methods:

```swift
// Required: Receive real-time messages from Watch
func session(_ session: WCSession, didReceiveMessage message: [String : Any],
             replyHandler: @escaping ([String : Any]) -> Void)

// Required: Receive queued transfers (guaranteed delivery)
func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any])

// Required: Receive application context updates
func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any])

// Required: Session activation callback
func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
             error: Error?)

// Required for iOS: Session state changes
func sessionDidBecomeInactive(_ session: WCSession)
func sessionDidDeactivate(_ session: WCSession)
```

### Required iPhone Functions

| Function | Location (Line) | Purpose |
|----------|-----------------|---------|
| `setupWatchConnectivity()` | ~100 | Initialize WCSession and set delegate |
| `applicationDidBecomeActive()` | ~51 | Trigger proactive Watch sync on app open |
| `syncWithWatch()` | ~60 | Send config to Watch, request vitals |
| `sendConfigurationToWatch()` | ~1730 | Send API URL + auth token to Watch |
| `resendStoredConfiguration()` | ~2175 | Re-send stored config when Watch requests |
| `forwardVitalsToDjango()` | ~1860 | Send received vitals to backend API |
| `forwardFallAlertToDjango()` | ~1900 | Send fall alerts to backend API (high priority) |
| `cleanupOldTransferKeys()` | ~2125 | Cleanup processed transfer/fall dedup keys |

### Message Handling Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                   iPhone AppDelegate.swift                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  didReceiveMessage (real-time)                                       │
│  ├── type == "watch_vitals" → store + forward to Django + Flutter   │
│  ├── type == "fall_alert"   → DEDUP by timestamp → forward + alert  │
│  ├── type == "request_config" → send API URL + token to Watch       │
│  └── command == "start_workout" / "stop_workout" / "get_status"     │
│                                                                      │
│  didReceiveUserInfo (guaranteed delivery)                            │
│  ├── DEDUP by transfer_id first                                      │
│  ├── type == "fall_alert" → DEDUP by timestamp+severity → forward   │
│  └── type == "watch_vitals" → store + forward to Django + Flutter   │
│                                                                      │
│  didReceiveApplicationContext                                        │
│  ├── type == "watch_vitals" → store as latest vitals                │
│  └── type == "fall_alert" → DEDUP by timestamp → forward            │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Fall Alert Deduplication (CRITICAL)

Fall alerts can arrive via multiple channels (real-time, transferUserInfo, applicationContext). Deduplication uses **timestamp + severity** (NOT transfer_id):

```swift
// Fall-specific deduplication
let fallTimestamp = userInfo["timestamp"] as? String ?? ""
let severity = userInfo["severity"] as? String ?? ""
let fallEventKey = "processedFall_\(fallTimestamp)_\(severity)"

if UserDefaults.standard.bool(forKey: fallEventKey) {
    // Skip duplicate
    return
}
UserDefaults.standard.set(true, forKey: fallEventKey)
```

### Proactive Sync on App Launch

When iPhone app becomes active, it should:

1. **Send configuration to Watch** - So Watch can start syncing
2. **Request current vitals** - Pull latest data from Watch

```swift
override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    syncWithWatch()
}

private func syncWithWatch() {
    // 1. Send config to Watch
    resendStoredConfiguration()

    // 2. Request current vitals if reachable
    if session.isReachable {
        session.sendMessage(["type": "request_vitals"], replyHandler: { response in
            // Process vitals response
        }, errorHandler: { error in
            // Handle error
        })
    }
}
```

### Flutter Method Channel

The AppDelegate exposes Watch data to Flutter via method channel:

```swift
// Channel name
private let watchVitalsChannel: FlutterMethodChannel?
// Channel ID: "com.kindura.ai/watch_vitals"

// Methods exposed to Flutter:
// - "sendConfigToWatch" : Send API config to Watch
// - "getLatestVitals"   : Get last received vitals
// - "startWatchWorkout" : Remote start workout on Watch
// - "stopWatchWorkout"  : Remote stop workout on Watch
// - "getWatchStatus"    : Get Watch connection status

// Events sent to Flutter:
// - "onWatchVitalsReceived" : New vitals from Watch
// - "onFallDetected"        : Fall alert from Watch
```

### Data Storage

| Storage Location | Purpose |
|------------------|---------|
| `UserDefaults.standard` | Transfer dedup keys, fall event keys |
| `UserDefaults(suiteName: appGroupIdentifier)` | Shared config (API URL, token) |
| `latestWatchVitals` | In-memory latest vitals |

### Error Handling

The iPhone app should handle:
- WCSession activation failures
- Django API failures (queue for retry)
- Missing configuration (request from Flutter)
- Watch not reachable (data will arrive via transferUserInfo later)

### Required Capabilities (iOS App)

Ensure iOS app has these in `Info.plist` / Entitlements:
- `com.apple.security.application-groups` : `group.com.kindura.ai`
- Background modes if needed for processing

---

## Contact & Support

For issues with the Watch app:
1. Check Troubleshooting section above
2. Review console logs for error messages
3. Ensure iOS app is up to date
4. Verify HealthKit permissions

---

*This documentation is maintained alongside the KinduraWatch source code.*
