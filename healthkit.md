# Task: Implement Semi-Real-Time Apple Watch Health Data Sync

You are working on Kindura AI, a Flutter app for Parkinson's patients. Your task is to implement aggressive HealthKit polling to achieve 5-10 second health data latency.

## Why This Approach

Flutter has no native watchOS support. WatchConnectivity and HKWorkoutSession cannot be used from Dart. A native watchOS app already exists at `watchos/KinduraWatch/` handling real-time via WatchConnectivity. Your job is to optimize the HealthKit polling path as a complementary fallback.

## Before You Start

1. Read the existing `lib/services/watch_vitals_service.dart` to understand current implementation
2. Read `lib/user_preference/` to understand the SharedPreferences wrapper
3. Check `pubspec.yaml` for current dependencies
4. Check `ios/Runner/Info.plist` and entitlements for current HealthKit setup

## Project Structure
```
lib/
├── main.dart
├── screens/{feature}/        # screen.dart + controller.dart per feature
├── models/                   # Data models
├── repository/               # Data access layer
├── services/                 # Your new files go here
├── res/                      # Colors, routes, assets
├── common_widgets/           
└── user_preference/          # SharedPreferences wrapper - USE THIS
```

## Coding Standards - FOLLOW STRICTLY

- **State Management:** GetX (get: ^4.7.2)
- **Pattern:** MVVM + Repository
- **Naming:** `_privateMethod()` for private methods
- **Logging:** `print('[ClassName] message')` format
- **Errors:** try-catch, graceful degradation, user-friendly messages, never show raw exceptions
- **Controllers:** Extend GetxController, use Rx types (RxInt, RxDouble, Rxn<T>)
- **Services:** Singleton or GetX service pattern with Get.put()

## Step 1: Create the Health Snapshot Model

Create `lib/models/health_snapshot.dart`:

- Include these classes:
  - HealthSnapshot (all vitals + timestamp + source)
  - SleepSnapshot (deep, rem, core, awake durations)
  - enum HealthDataSource { healthKit, watchConnectivity }
  - enum ConnectionStatus { connected, disconnected, syncing, error }
- All vitals nullable except steps (default 0)
- Include toJson() and fromJson() for caching and API
- Include copyWith() method

## Step 2: Create the Health Data Service

Create `lib/services/health_data_service.dart`:

POLLING:
- Poll HealthKit every 5 seconds when foreground
- Stop polling when app goes to background
- Fetch: heartRate, heartRateVariabilitySDNN, oxygenSaturation, respiratoryRate, stepCount, activeEnergyBurned, distanceWalkingRunning
- Query last 10 seconds of data to catch recent measurements

STREAMING:
- Expose Stream<HealthSnapshot> via StreamController
- Emit new snapshot on each successful poll
- Include timestamp and source in every emission

PERMISSIONS:
- Request permissions on first use
- Return bool success from requestPermissions()
- Degrade gracefully if denied (emit null values, don't crash)

THROTTLING:
- Track _lastApiCallTime
- Only POST to backend if 30+ seconds since last call
- Always update local cache and stream regardless of throttle

COORDINATION:
- Accept external data via injectWatchConnectivityData(HealthSnapshot)
- Compare timestamps to avoid emitting stale data
- WatchConnectivity data takes priority if newer

LIFECYCLE:
- startPolling() - begins 5-second timer
- stopPolling() - cancels timer
- dispose() - cleanup StreamController and timer

Use the health package (already installed: health: ^11.1.0). Use print('[HealthDataService] message') for all logging.

## Step 3: Create the Background Sync Service

Create `lib/services/background_sync_service.dart`:

INITIALIZATION:
- Call Workmanager().initialize() in main.dart
- Register periodic task with unique name "com.kindura.healthSync"
- Frequency: Duration(minutes: 15) - iOS minimum

CALLBACK HANDLER:
- Top-level function (not class method) for workmanager callback
- Fetch latest HealthKit data
- POST to backend: POST /api/watch-vitals/
- Cache in SharedPreferences using existing user_preference/ wrapper

ERROR HANDLING:
- Wrap everything in try-catch
- Return Future.value(true) on success
- Return Future.value(false) on failure (workmanager will retry)
- Log all errors with print('[BackgroundSyncService] error')

Provide setup instructions for main.dart.

## Step 4: Create the GetX Controller

Create `lib/controllers/health_monitor_controller.dart`:

OBSERVABLE STATE:
```dart
final bpm = Rxn<double>();
final hrv = Rxn<double>();
final spo2 = Rxn<double>();
final respiratoryRate = Rxn<double>();
final steps = RxInt(0);
final calories = RxDouble(0.0);
final distance = RxDouble(0.0);
final sleepData = Rxn<SleepSnapshot>();
final connectionStatus = Rx<ConnectionStatus>(ConnectionStatus.disconnected);
final lastSyncTimestamp = Rxn<DateTime>();
final isPolling = RxBool(false);
final syncError = Rxn<String>();
```

LIFECYCLE:
- @override onInit() - request permissions, start polling, listen to stream
- @override onClose() - stop polling, dispose subscriptions

STREAM SUBSCRIPTION:
- Subscribe to HealthDataService.healthStream
- Update all Rx values when new HealthSnapshot arrives
- Update lastSyncTimestamp
- Clear syncError on success

PUBLIC METHODS:
- Future<void> startMonitoring()
- Future<void> stopMonitoring()
- Future<void> forceSync() - manual refresh button

APP LIFECYCLE:
- Listen to AppLifecycleState
- onResumed: startPolling()
- onPaused: stopPolling()

ERROR HANDLING:
- Catch all errors in stream subscription
- Set syncError.value to user-friendly message
- Never expose raw exception messages

Register in main.dart with Get.put(HealthMonitorController()).

## Step 5: Update pubspec.yaml

Add this dependency:
```yaml
dependencies:
  workmanager: ^0.5.2
```

Run `flutter pub get` after.

## Step 6: Update iOS Configuration

Check and update `ios/Runner/Info.plist` - add if missing:
```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
  <string>com.kindura.healthSync</string>
</array>
<key>UIBackgroundModes</key>
<array>
  <string>fetch</string>
  <string>processing</string>
</array>
```

Verify `ios/Runner/Runner.entitlements` includes:
```xml
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.healthkit.background-delivery</key>
<true/>
```

## Step 7: Update main.dart

Add initialization:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Add: Initialize workmanager
  await BackgroundSyncService.initialize();
  
  // Add: Register health monitor controller
  Get.put(HealthMonitorController());
  
  runApp(MyApp());
}
```

## Step 8: Create Usage Example Widget

Create example showing how to use in UI:
```dart
class VitalsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetBuilder<HealthMonitorController>(
      init: Get.find<HealthMonitorController>(),
      builder: (controller) {
        return Obx(() => Column(
          children: [
            Text('♥ ${controller.bpm.value?.toStringAsFixed(0) ?? '--'} BPM'),
            Text('HRV: ${controller.hrv.value?.toStringAsFixed(0) ?? '--'} ms'),
            Text('SpO2: ${controller.spo2.value?.toStringAsFixed(0) ?? '--'}%'),
            Text('Status: ${controller.connectionStatus.value}'),
            Text('Last sync: ${controller.lastSyncTimestamp.value ?? 'Never'}'),
            if (controller.syncError.value != null)
              Text('Error: ${controller.syncError.value}', style: TextStyle(color: Colors.red)),
          ],
        ));
      },
    );
  }
}
```

## API Integration

POST health data to existing endpoint:
```
POST /api/watch-vitals/
Content-Type: application/json

{
  "heart_rate": 72.0,
  "hrv": 45.0,
  "blood_oxygen": 98.0,
  "respiratory_rate": 16.0,
  "steps": 5432,
  "calories": 234.5,
  "distance": 3.2,
  "source": "healthkit",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

Use existing http package for API calls. Check `lib/repository/` for existing API call patterns and base URL configuration.

## Coordination with Existing Code

1. **watch_vitals_service.dart** - Read this first. Your HealthDataService should use same data models if they exist, not duplicate WatchConnectivity functionality, and accept injected data from WatchConnectivity via public method.

2. **user_preference/** - Use this for SharedPreferences, don't create new wrapper.

3. **Django WebSocket** - Data you POST to /api/watch-vitals/ will be broadcast via WebSocket automatically. LiveKit agent reads from this. No additional work needed.

## Testing Checklist

After implementation, verify:

- [ ] `flutter analyze` passes with no errors
- [ ] App compiles and runs on iOS simulator
- [ ] Health permissions dialog appears on first launch
- [ ] BPM/HRV values appear in UI within 10 seconds (when Watch worn)
- [ ] Values update every 5 seconds in foreground
- [ ] Polling stops when app backgrounded (check logs)
- [ ] No crashes when permissions denied
- [ ] API calls throttled to 30-second minimum (check logs)

## Files to Create/Modify

CREATE:
- lib/models/health_snapshot.dart
- lib/services/health_data_service.dart
- lib/services/background_sync_service.dart
- lib/controllers/health_monitor_controller.dart

MODIFY:
- pubspec.yaml (add workmanager)
- lib/main.dart (add initialization)
- ios/Runner/Info.plist (add background modes if missing)

READ FIRST (don't modify unless necessary):
- lib/services/watch_vitals_service.dart
- lib/user_preference/
- lib/repository/ (for API patterns)

## Output Format

For each file you create:
1. Show the complete file content
2. Explain key implementation decisions
3. Note any assumptions made

After all files, provide:
1. Summary of changes to existing files
2. Testing instructions
3. Troubleshooting guide for common issues