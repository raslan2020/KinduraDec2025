import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/models/home/course_list.dart' as course_models;
import 'package:kindura_ai/models/user_profile/user_profile_model.dart';
import 'package:kindura_ai/repository/home_repository/home_repository.dart';
import 'package:kindura_ai/res/routes/routes_name.dart';
import 'package:kindura_ai/res/app_url/app_url.dart';
import 'package:kindura_ai/utils/utils.dart';
import 'package:kindura_ai/utils/performance_monitor.dart';
import 'package:kindura_ai/user_preference/user_preferences_view_model.dart';
import 'package:livekit_client/livekit_client.dart' as livekit;
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:kindura_ai/screens/medication/medication_controller.dart';
import 'package:kindura_ai/services/watch_vitals_service.dart';
import 'package:kindura_ai/models/health/data_source_mode.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class HomeController extends GetxController {
  final HomeRepository _homeRepository = HomeRepository();
  final UserPreferences userPreferences = UserPreferences();
  final PerformanceMonitor _monitor = PerformanceMonitor();
  WatchVitalsService? _watchVitalsService;
  bool _isWatchVitalsServiceInitialized = false;
  WebSocketChannel? _watchVitalsChannel;
  livekit.Room? _room;
  RxBool isConnected = false.obs;

  // WebSocket connection state
  bool _isWebSocketConnecting = false;
  bool _isWebSocketConnected = false;
  Timer? _webSocketReconnectTimer;
  StreamSubscription? _webSocketSubscription;

  // Health data refresh timer
  Timer? _healthRefreshTimer;

  String token = "";
  DateTime? _connectionStartTime;
  DateTime? _lastTranscriptionTime;

  // Backend connection state
  final isBackendConnected = false.obs;
  final connectionError = ''.obs;
  int _connectionRetryCount = 0;
  static const int _maxRetries = 3;
  Timer? _connectionRetryTimer;

  final requestStatus = Status.COMPLETED.obs;
  final agentStatus = Status.COMPLETED.obs;
  final courseList = course_models.CourseList().obs;
  final userProfile = UserProfile().obs;
  RxString errors = ''.obs;

  // Watch vitals data - Initialize with 0 values (NOT hardcoded fake values)
  // data_available tracks if real data has been received
  final watchVitals = Rx<Map<String, dynamic>>({
    'heart_rate': 0,           // Was 72 - now 0 to indicate no data
    'blood_oxygen': 0,         // Was 98 - now 0 to indicate no data
    'hrv': 0,
    'respiratory_rate': 0,
    'sleep_hours': 0.0,
    'sleep_score': 0,
    'deep_sleep_hours': 0.0,
    'rem_sleep_hours': 0.0,
    'core_sleep_hours': 0.0,
    'awake_hours': 0.0,
    'awakenings': 0,
    'sleep_quality': 'unknown',
    'steps': 0,
    'calories': 0,
    'distance_km': 0.0,
    'floors_climbed': 0,
    'exercise_minutes': 0,
    'stand_minutes': 0,
    'falls_count': 0,
    'is_demo': false,          // Was true - now false
    'data_available': false,   // NEW: tracks if real data exists
    'source': 'none',          // NEW: tracks data source (api/apple_health/none)
    'last_sync': null,         // NEW: timestamp of last successful sync
  });
  final watchVitalsStatus = Status.COMPLETED.obs;

  // Voice trigger
  final stt.SpeechToText _speech = stt.SpeechToText();
  RxBool isListening = false.obs;
  RxBool hasTriggered = false.obs;
  String recognizedText = "";

  // Data source mode tracking
  final Rx<DataSourceMode> dataSourceMode = DataSourceMode.healthKitOnly.obs;
  final RxBool hasDataSourceOverride = false.obs;

  /// Check if current mode supports fall detection (Apple Watch only)
  bool get supportsFallDetection => dataSourceMode.value.supportsFallDetection;

  /// Check if current mode supports real-time heart rate (Apple Watch only)
  bool get supportsRealTimeHeartRate => dataSourceMode.value.supportsRealTimeHeartRate;

  /// Get the display name for the current data source
  String get dataSourceDisplayName => dataSourceMode.value.displayName;

  @override
  void onInit() async {
    super.onInit();
    _monitor.startTimer('app_initialization');

    // Initialize app with graceful error handling
    // App should NOT crash even if backend is unavailable
    await _initializeAppSafely();

    _monitor.endTimer('app_initialization');
  }

  /// Initialize app with graceful error handling
  /// This ensures the app doesn't crash if backend is unavailable
  Future<void> _initializeAppSafely() async {
    print('[HomeController] Starting safe initialization...');

    // 1. Try to connect to backend (non-blocking)
    try {
      await _connectToBackendWithRetry();
    } catch (e) {
      print('[HomeController] Backend connection failed, continuing offline: $e');
      connectionError.value = 'Unable to connect to server';
    }

    // 2. Initialize local services (these should never crash)
    try {
      _initSpeechRecognition();
    } catch (e) {
      print('[HomeController] Speech recognition init failed: $e');
    }

    // 3. Initialize Watch vitals service
    try {
      await _initWatchVitalsService();
    } catch (e) {
      print('[HomeController] Watch vitals service init failed: $e');
    }

    // 4. Start health data refresh (will handle errors internally)
    try {
      _startHealthDataRefresh();
    } catch (e) {
      print('[HomeController] Health refresh init failed: $e');
    }

    // 5. Connect WebSocket (non-blocking, will retry)
    try {
      _connectWatchVitalsWebSocket();
    } catch (e) {
      print('[HomeController] WebSocket connection failed: $e');
    }

    // 6. Load medications (non-blocking)
    try {
      _loadMedications();
    } catch (e) {
      print('[HomeController] Medications load failed: $e');
    }

    print('[HomeController] Safe initialization complete. Backend connected: ${isBackendConnected.value}');
  }

  /// Connect to backend with retry logic
  Future<void> _connectToBackendWithRetry() async {
    _connectionRetryCount = 0;

    while (_connectionRetryCount < _maxRetries) {
      try {
        print('[HomeController] Attempting backend connection (attempt ${_connectionRetryCount + 1}/$_maxRetries)...');

        // Try to call homeApi with timeout
        await homeApi().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Connection timeout');
          },
        );

        // If successful, mark as connected
        isBackendConnected.value = true;
        connectionError.value = '';
        print('[HomeController] ✅ Backend connected successfully');
        return;
      } catch (e) {
        _connectionRetryCount++;
        print('[HomeController] Connection attempt $_connectionRetryCount failed: $e');

        if (_connectionRetryCount < _maxRetries) {
          // Wait before retry (exponential backoff)
          final delay = Duration(seconds: _connectionRetryCount * 2);
          print('[HomeController] Retrying in ${delay.inSeconds} seconds...');
          await Future.delayed(delay);
        }
      }
    }

    // All retries failed
    isBackendConnected.value = false;
    connectionError.value = 'Unable to connect to server. Please check your internet connection.';
    print('[HomeController] ❌ All connection attempts failed');

    // Schedule background retry
    _scheduleBackgroundRetry();
  }

  /// Schedule background retry for connection
  void _scheduleBackgroundRetry() {
    _connectionRetryTimer?.cancel();
    _connectionRetryTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!isBackendConnected.value) {
        print('[HomeController] Background retry: attempting to reconnect...');
        try {
          await homeApi().timeout(const Duration(seconds: 10));
          isBackendConnected.value = true;
          connectionError.value = '';
          _connectionRetryTimer?.cancel();
          print('[HomeController] ✅ Background reconnection successful');
        } catch (e) {
          print('[HomeController] Background retry failed: $e');
        }
      }
    });
  }

  /// Load health data once on startup (no periodic refresh - event-driven only)
  void _startHealthDataRefresh() {
    // Initial load only - no more periodic timer
    // Updates now come from:
    // 1. Apple Watch via WCSession (onVitalsReceived callback)
    // 2. HealthKit observers (when health data changes)
    // 3. Manual pull-to-refresh by user
    print('[HomeController] Loading initial health data (event-driven mode)');
    loadWatchVitals();
  }

  void _connectWatchVitalsWebSocket() {
    // Prevent multiple simultaneous connections
    if (_isWebSocketConnecting || _isWebSocketConnected) {
      print('⚠️ WebSocket already connected or connecting - skipping');
      return;
    }

    // Don't try to connect if backend is not available
    if (!isBackendConnected.value) {
      print('⚠️ Backend not connected - skipping WebSocket connection');
      return;
    }

    _isWebSocketConnecting = true;

    try {
      // Cancel any pending reconnection timer
      _webSocketReconnectTimer?.cancel();
      _webSocketReconnectTimer = null;

      // Close existing connection if any
      _disconnectWebSocket();

      // Build WebSocket URL based on API base URL
      // Convert http to ws and remove /api suffix
      final baseUrl = AppUrl.baseUrl.replaceFirst('http', 'ws').replaceFirst('/api', '');
      final wsUrl = '${baseUrl}/ws/watch-vitals/';

      print('🔌 Connecting to Watch vitals WebSocket: $wsUrl');

      try {
        _watchVitalsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      } catch (e) {
        print('❌ WebSocket connect failed: $e');
        _isWebSocketConnecting = false;
        return;
      }

      // Listen for messages from the WebSocket with cancelOnError to prevent unhandled exceptions
      _webSocketSubscription = _watchVitalsChannel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            if (data['type'] == 'watch_vitals' && data['data'] != null) {
              final vitals = data['data'];
              print('📡 WebSocket vitals received: HR=${vitals['heart_rate']}, O2=${vitals['blood_oxygen']}');

              // Update local state immediately
              watchVitals.value = {
                'heart_rate': (vitals['heart_rate'] ?? 72).toDouble(),
                'blood_oxygen': (vitals['blood_oxygen'] ?? 98).toDouble(),
                'hrv': (vitals['hrv'] ?? 0).toDouble(),
                'respiratory_rate': (vitals['respiratory_rate'] ?? 0).toDouble(),
                'sleep_hours': (vitals['total_sleep_hours'] ?? 0).toDouble(),
                'awakenings': vitals['awakenings_count'] ?? 0,
                'sleep_quality': vitals['sleep_quality'] ?? 'unknown',
                'falls_count': vitals['falls_count'] ?? 0,
                'is_demo': false,
              };
              watchVitalsStatus.value = Status.COMPLETED;
            }
          } catch (e) {
            print('❌ Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          print('⚠️ WebSocket error (handled): $error');
          _isWebSocketConnected = false;
          _isWebSocketConnecting = false;
          // Don't schedule reconnect if backend is not connected
          if (isBackendConnected.value) {
            _scheduleReconnect();
          }
        },
        onDone: () {
          print('⚠️ WebSocket connection closed');
          _isWebSocketConnected = false;
          _isWebSocketConnecting = false;
          if (isBackendConnected.value) {
            _scheduleReconnect();
          }
        },
        cancelOnError: true, // Prevent unhandled exceptions
      );

      _isWebSocketConnected = true;
      _isWebSocketConnecting = false;
      print('✅ WebSocket connected for Watch vitals');
    } catch (e) {
      print('❌ Failed to connect WebSocket: $e');
      _isWebSocketConnecting = false;
      // Don't schedule reconnect - let background retry handle it
    }
  }

  void _scheduleReconnect() {
    // Cancel any existing timer
    _webSocketReconnectTimer?.cancel();

    // Schedule reconnect in 10 seconds (not 5, to reduce frequency)
    _webSocketReconnectTimer = Timer(Duration(seconds: 10), () {
      print('🔄 Attempting WebSocket reconnection...');
      _connectWatchVitalsWebSocket();
    });
  }

  void _disconnectWebSocket() {
    _webSocketSubscription?.cancel();
    _webSocketSubscription = null;
    _watchVitalsChannel?.sink.close();
    _watchVitalsChannel = null;
    _isWebSocketConnected = false;
  }

  Future<void> _initWatchVitalsService() async {
    _watchVitalsService = WatchVitalsService();
    _isWatchVitalsServiceInitialized = true;

    // STEP 1: Detect data source mode (Apple Watch, HealthKit only, or Manual)
    final detectedMode = await _watchVitalsService!.detectDataSourceMode();
    dataSourceMode.value = detectedMode;
    hasDataSourceOverride.value = _watchVitalsService!.hasUserOverride;
    print('[HomeController] 🔍 Data source mode detected: ${detectedMode.displayName}');

    // STEP 2: Configure based on detected mode
    if (detectedMode == DataSourceMode.appleWatch) {
      // Full Apple Watch integration
      print('[HomeController] ⌚ Apple Watch mode - enabling full Watch integration');
      await _syncWatchConfiguration();
      _setupWatchCallbacks();
    } else if (detectedMode == DataSourceMode.healthKitOnly) {
      print('[HomeController] ❤️ HealthKit-only mode - using Oura, Whoop, Ultrahuman, etc.');
    } else {
      print('[HomeController] 📝 Manual-only mode - no health device integration');
    }

    // STEP 3: Always setup HealthKit callbacks (works for both Apple Watch and HealthKit-only modes)
    if (detectedMode != DataSourceMode.manualOnly) {
      _setupHealthKitCallbacks();
    }

    // STEP 4: Start HealthKit observers for event-driven updates
    if (detectedMode != DataSourceMode.manualOnly) {
      await _watchVitalsService!.startHealthKitObservers();
      print('[HomeController] 🔔 HealthKit observers started');
    }
  }

  /// Setup callbacks specific to Apple Watch mode
  /// Only called when Watch is paired and active
  void _setupWatchCallbacks() {
    if (_watchVitalsService == null) return;

    // Listen for real-time Watch vitals updates via WCSession
    _watchVitalsService!.onVitalsReceived = (vitals) {
      print('[HomeController] ⌚️ Watch vitals received in REAL-TIME: $vitals');

      // Update local state immediately for UI - include all fields
      final updatedVitals = Map<String, dynamic>.from(watchVitals.value);

      // Vitals
      updatedVitals['heart_rate'] = (vitals['heart_rate'] ?? updatedVitals['heart_rate'] ?? 0).toDouble();
      updatedVitals['blood_oxygen'] = (vitals['blood_oxygen'] ?? updatedVitals['blood_oxygen'] ?? 0).toDouble();
      updatedVitals['hrv'] = (vitals['hrv'] ?? updatedVitals['hrv'] ?? 0).toDouble();
      updatedVitals['respiratory_rate'] = (vitals['respiratory_rate'] ?? updatedVitals['respiratory_rate'] ?? 0).toDouble();

      // Sleep
      updatedVitals['sleep_hours'] = (vitals['total_sleep_hours'] ?? vitals['sleep_hours'] ?? updatedVitals['sleep_hours'] ?? 0).toDouble();
      updatedVitals['sleep_score'] = vitals['sleep_score'] ?? updatedVitals['sleep_score'] ?? 0;
      updatedVitals['deep_sleep_hours'] = (vitals['deep_sleep_hours'] ?? updatedVitals['deep_sleep_hours'] ?? 0).toDouble();
      updatedVitals['rem_sleep_hours'] = (vitals['rem_sleep_hours'] ?? updatedVitals['rem_sleep_hours'] ?? 0).toDouble();
      updatedVitals['core_sleep_hours'] = (vitals['core_sleep_hours'] ?? updatedVitals['core_sleep_hours'] ?? 0).toDouble();
      updatedVitals['awake_hours'] = (vitals['awake_time_hours'] ?? vitals['awake_hours'] ?? updatedVitals['awake_hours'] ?? 0).toDouble();

      // Activity
      updatedVitals['steps'] = vitals['steps'] ?? updatedVitals['steps'] ?? 0;
      updatedVitals['calories'] = vitals['calories'] ?? updatedVitals['calories'] ?? 0;
      updatedVitals['distance_km'] = (vitals['distance_km'] ?? updatedVitals['distance_km'] ?? 0).toDouble();
      updatedVitals['exercise_minutes'] = vitals['exercise_minutes'] ?? updatedVitals['exercise_minutes'] ?? 0;
      updatedVitals['floors_climbed'] = vitals['floors_climbed'] ?? updatedVitals['floors_climbed'] ?? 0;

      // Falls (only available with Apple Watch)
      updatedVitals['fall_detected'] = vitals['fall_detected'] ?? false;
      updatedVitals['falls_count'] = vitals['falls_count'] ?? updatedVitals['falls_count'] ?? 0;

      // Metadata
      updatedVitals['data_available'] = true;
      updatedVitals['source'] = 'apple_watch';
      updatedVitals['is_demo'] = false;

      // Trigger UI update by assigning new map
      watchVitals.value = updatedVitals;
      print('[HomeController] ✅ UI updated with real-time Watch vitals');
    };

    // Listen for fall detection events - handle with priority (Apple Watch only feature)
    _watchVitalsService!.onFallDetected = (vitals) {
      print('[HomeController] ⚠️ FALL DETECTED from Watch!');
      _handleFallDetection(vitals);
    };
  }

  /// Setup callbacks for HealthKit data changes
  /// Called for both Apple Watch and HealthKit-only modes
  void _setupHealthKitCallbacks() {
    if (_watchVitalsService == null) return;

    // Listen for HealthKit data changes (event-driven updates)
    // This is triggered by HKObserverQuery when health data changes in HealthKit
    // Works with any HealthKit-compatible device: Apple Watch, Oura, Whoop, Ultrahuman, etc.
    _watchVitalsService!.onHealthKitDataChanged = (type) {
      print('[HomeController] 🔔 HealthKit data changed: $type - refreshing...');
      // Refresh health data from Apple Health when any data changes
      _refreshHealthDataFromHealthKit(type);
    };
  }

  /// Change the data source mode (for user override in Settings)
  Future<void> setDataSourceMode(DataSourceMode? mode) async {
    if (_watchVitalsService == null) return;

    await _watchVitalsService!.setUserOverride(mode);

    // Update override flag
    hasDataSourceOverride.value = mode != null;

    // Re-detect to get the effective mode
    final effectiveMode = await _watchVitalsService!.detectDataSourceMode();
    dataSourceMode.value = effectiveMode;
    print('[HomeController] 👤 Data source mode changed to: ${effectiveMode.displayName}');

    // Reinitialize based on new mode
    await _initWatchVitalsService();
    await loadWatchVitals();
  }

  /// Get available data source options for Settings UI
  Future<List<DataSourceOption>> getAvailableDataSources() async {
    if (_watchVitalsService == null) return [];
    return await _watchVitalsService!.getAvailableDataSources();
  }

  /// Refresh health data from Apple Health when HealthKit observer fires
  /// This provides event-driven updates without periodic polling
  Future<void> _refreshHealthDataFromHealthKit(String changedType) async {
    if (_watchVitalsService == null) return;

    try {
      print('[HomeController] 📱 Fetching fresh health data for: $changedType');

      // Get comprehensive health data from Apple Health
      final healthData = await _watchVitalsService!.getHealthSummary();

      if (healthData != null && healthData.isNotEmpty) {
        print('[HomeController] ✅ Received health data from HealthKit: $healthData');

        final updatedVitals = Map<String, dynamic>.from(watchVitals.value);

        // Update vitals
        if (healthData['heart_rate'] != null && (healthData['heart_rate'] as num) > 0) {
          updatedVitals['heart_rate'] = (healthData['heart_rate'] as num).toDouble();
        }
        if (healthData['blood_oxygen'] != null && (healthData['blood_oxygen'] as num) > 0) {
          updatedVitals['blood_oxygen'] = (healthData['blood_oxygen'] as num).toDouble();
        }
        if (healthData['hrv'] != null) {
          updatedVitals['hrv'] = (healthData['hrv'] as num).toDouble();
        }
        if (healthData['respiratory_rate'] != null) {
          updatedVitals['respiratory_rate'] = (healthData['respiratory_rate'] as num).toDouble();
        }

        // Update sleep
        if (healthData['sleep_hours'] != null) {
          updatedVitals['sleep_hours'] = (healthData['sleep_hours'] as num).toDouble();
        }
        if (healthData['sleep_score'] != null) {
          updatedVitals['sleep_score'] = healthData['sleep_score'];
        }
        if (healthData['deep_sleep_hours'] != null) {
          updatedVitals['deep_sleep_hours'] = (healthData['deep_sleep_hours'] as num).toDouble();
        }
        if (healthData['rem_sleep_hours'] != null) {
          updatedVitals['rem_sleep_hours'] = (healthData['rem_sleep_hours'] as num).toDouble();
        }
        if (healthData['core_sleep_hours'] != null) {
          updatedVitals['core_sleep_hours'] = (healthData['core_sleep_hours'] as num).toDouble();
        }
        if (healthData['awake_hours'] != null) {
          updatedVitals['awake_hours'] = (healthData['awake_hours'] as num).toDouble();
        }

        // Update activity
        if (healthData['steps'] != null) {
          updatedVitals['steps'] = healthData['steps'];
        }
        if (healthData['calories'] != null) {
          updatedVitals['calories'] = healthData['calories'];
        }
        if (healthData['distance_km'] != null) {
          updatedVitals['distance_km'] = (healthData['distance_km'] as num).toDouble();
        }
        if (healthData['exercise_minutes'] != null) {
          updatedVitals['exercise_minutes'] = healthData['exercise_minutes'];
        }
        if (healthData['floors_climbed'] != null) {
          updatedVitals['floors_climbed'] = healthData['floors_climbed'];
        }
        if (healthData['stand_minutes'] != null) {
          updatedVitals['stand_minutes'] = healthData['stand_minutes'];
        }

        // Mark data as available
        updatedVitals['data_available'] = true;
        updatedVitals['source'] = 'apple_health';
        updatedVitals['is_demo'] = false;
        updatedVitals['last_sync'] = DateTime.now().toIso8601String();

        // Trigger UI update
        watchVitals.value = updatedVitals;
        print('[HomeController] ✅ UI updated from HealthKit event ($changedType)');
      }
    } catch (e) {
      print('[HomeController] Error refreshing health data from HealthKit: $e');
    }
  }

  /// Sync API configuration to Apple Watch
  Future<void> _syncWatchConfiguration() async {
    if (_watchVitalsService == null) {
      print('[HomeController] Watch vitals service not initialized - skipping sync');
      return;
    }
    try {
      final isPaired = await _watchVitalsService!.isWatchPaired();
      if (!isPaired) {
        print('[HomeController] No Apple Watch paired - skipping sync');
        return;
      }

      print('[HomeController] Apple Watch detected, syncing configuration...');
      final success = await _watchVitalsService!.syncConfigurationToWatch();

      if (success) {
        print('[HomeController] ✅ Watch configuration synced successfully');
      } else {
        print('[HomeController] ⚠️ Watch configuration sync failed');
      }
    } catch (e) {
      print('[HomeController] Error syncing Watch configuration: $e');
    }
  }

  /// Handle fall detection event from Apple Watch
  void _handleFallDetection(Map<String, dynamic> vitals) {
    // Show immediate alert to user
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
            SizedBox(width: 8),
            Text('Fall Detected'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Apple Watch detected a possible fall.'),
            SizedBox(height: 16),
            Text('Are you okay?'),
            SizedBox(height: 8),
            if (vitals['heart_rate'] != null)
              Text('Heart rate: ${vitals['heart_rate']} bpm',
                  style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              _sendFallResponse(vitals, false); // User is okay
            },
            child: Text("I'm Okay"),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _sendFallResponse(vitals, true); // User needs help
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Need Help', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Send fall response to backend
  void _sendFallResponse(Map<String, dynamic> vitals, bool needsHelp) async {
    try {
      final response = {
        ...vitals,
        'user_response': needsHelp ? 'needs_help' : 'okay',
        'response_time': DateTime.now().toIso8601String(),
      };

      print('[HomeController] Sending fall response: $response');

      if (needsHelp) {
        // TODO: Trigger emergency contact notification
        Util.Snack_Bar('Emergency', 'Notifying your emergency contacts...');
      } else {
        Util.Snack_Bar('Fall Recorded', 'Glad you\'re okay! Event has been logged.');
      }
    } catch (e) {
      print('[HomeController] Error sending fall response: $e');
    }
  }

  Future<void> loadWatchVitals() async {
    try {
      print("[HomeController] ========== LOADING WATCH VITALS ==========");
      watchVitalsStatus.value = Status.LOADING;

      // Step 1: Check HealthKit authorization first
      bool isHealthKitAuthorized = false;
      if (_watchVitalsService != null) {
        try {
          isHealthKitAuthorized = await _watchVitalsService!.isHealthKitAuthorized();
          print("[HomeController] HealthKit authorized: $isHealthKitAuthorized");

          if (!isHealthKitAuthorized) {
            print("[HomeController] Requesting HealthKit authorization...");
            await _watchVitalsService!.requestHealthKitAuthorization();
            isHealthKitAuthorized = await _watchVitalsService!.isHealthKitAuthorized();
            print("[HomeController] HealthKit authorization after request: $isHealthKitAuthorized");
          }
        } catch (e) {
          print("[HomeController] HealthKit authorization check failed: $e");
        }
      }

      // Initialize comprehensive vitals with all data types
      Map<String, dynamic> mergedVitals = {
        // Vitals
        'heart_rate': 0.0,
        'blood_oxygen': 0.0,
        'hrv': 0.0,
        'respiratory_rate': 0.0,
        'resting_heart_rate': 0,
        'walking_heart_rate': 0,

        // Sleep
        'sleep_hours': 0.0,
        'sleep_score': 0,
        'deep_sleep_hours': 0.0,
        'rem_sleep_hours': 0.0,
        'core_sleep_hours': 0.0,
        'awake_hours': 0.0,
        'awakenings': 0,
        'sleep_quality': 'unknown',
        'sleep_stages': [],

        // Activity
        'steps': 0,
        'calories': 0,
        'distance_km': 0.0,
        'floors_climbed': 0,
        'exercise_minutes': 0,
        'stand_minutes': 0,

        // Blood Pressure
        'blood_pressure_systolic': 0,
        'blood_pressure_diastolic': 0,

        // Audio Exposure
        'headphone_audio_db': 0.0,
        'environmental_audio_db': 0.0,

        // Workouts
        'workouts_today': [],
        'workouts_count': 0,

        // AFib
        'afib_detected': false,
        'afib_history': [],

        // Falls
        'falls_count': 0,
        'fall_detected': false,

        // Meta
        'is_demo': true,
        'source': 'none',
      };

      // Track if we received any real data
      bool hasRealData = false;

      // 1. Try to get data from Django API (Watch data)
      print("[HomeController] Step 2: Fetching from Django API...");
      try {
        var apiValue = await _homeRepository.getWatchVitals();
        print("[HomeController] API Response: status=${apiValue['status']}, result=${apiValue['result']}");

        if (apiValue['status'] == true && apiValue['result'] != null) {
          final result = apiValue['result'];
          print("[HomeController] API Data: HR=${result['heart_rate']}, O2=${result['blood_oxygen']}, HRV=${result['hrv']}");

          mergedVitals['heart_rate'] = (result['heart_rate'] ?? 0).toDouble();
          mergedVitals['blood_oxygen'] = (result['blood_oxygen'] ?? 0).toDouble();
          mergedVitals['hrv'] = (result['hrv'] ?? 0).toDouble();
          mergedVitals['respiratory_rate'] = (result['respiratory_rate'] ?? 0).toDouble();
          mergedVitals['sleep_hours'] = (result['sleep_hours'] ?? 0).toDouble();
          mergedVitals['awakenings'] = result['awakenings'] ?? 0;
          mergedVitals['sleep_quality'] = result['sleep_quality'] ?? 'unknown';
          mergedVitals['falls_count'] = result['falls_count'] ?? 0;
          mergedVitals['fall_detected'] = result['fall_detected'] ?? false;
          mergedVitals['is_demo'] = result['is_demo'] ?? false;
          mergedVitals['last_updated'] = result['last_updated'];
          mergedVitals['source'] = 'api';

          // Check if we got real data (not zeros)
          if ((result['heart_rate'] ?? 0) > 0 || (result['blood_oxygen'] ?? 0) > 0) {
            hasRealData = true;
            print("[HomeController] Got REAL data from API");
          }
          print("[HomeController] Watch vitals loaded from API");
        } else {
          print("[HomeController] API returned no data or status=false");
        }
      } catch (e) {
        print("[HomeController] Could not load from API: $e");
      }

      // 2. Get COMPREHENSIVE Apple Health data (includes all data types)
      print("[HomeController] Step 3: Fetching from Apple Health...");
      if (_watchVitalsService == null) {
        print("[HomeController] Watch vitals service not initialized - skipping Apple Health");
      } else try {
        final healthData = await _watchVitalsService!.getComprehensiveHealth();
        print("[HomeController] Apple Health Response: $healthData");

        if (healthData != null) {
          print("[HomeController] Apple Health Data: HR=${healthData['heart_rate']}, O2=${healthData['blood_oxygen']}, HRV=${healthData['hrv']}, RespRate=${healthData['respiratory_rate']}");
          print("[HomeController] Sleep Data: hours=${healthData['sleep_hours']}, score=${healthData['sleep_score']}");
          print("[HomeController] Activity Data: steps=${healthData['steps']}, calories=${healthData['calories']}");

          // Vitals - Only update if we got real values (not 0)
          if ((healthData['heart_rate'] ?? 0) > 0) {
            mergedVitals['heart_rate'] = (healthData['heart_rate'] ?? 0).toDouble();
            hasRealData = true;
            print("[HomeController] Got real heart rate from Apple Health: ${healthData['heart_rate']}");
          }
          if ((healthData['blood_oxygen'] ?? 0) > 0) {
            mergedVitals['blood_oxygen'] = (healthData['blood_oxygen'] ?? 0).toDouble();
            hasRealData = true;
            print("[HomeController] Got real blood oxygen from Apple Health: ${healthData['blood_oxygen']}");
          }
          if ((healthData['hrv'] ?? 0) > 0) {
            mergedVitals['hrv'] = (healthData['hrv'] ?? 0).toDouble();
            hasRealData = true;
            print("[HomeController] Got real HRV from Apple Health: ${healthData['hrv']}");
          }
          if ((healthData['respiratory_rate'] ?? 0) > 0) {
            mergedVitals['respiratory_rate'] = (healthData['respiratory_rate'] ?? 0).toDouble();
            hasRealData = true;
            print("[HomeController] Got real respiratory rate from Apple Health: ${healthData['respiratory_rate']}");
          }
          mergedVitals['resting_heart_rate'] = healthData['resting_heart_rate'] ?? 0;
          mergedVitals['walking_heart_rate'] = healthData['walking_heart_rate'] ?? 0;

          // Sleep data
          if ((healthData['sleep_hours'] ?? 0) > 0) {
            mergedVitals['sleep_hours'] = (healthData['sleep_hours'] ?? 0).toDouble();
            mergedVitals['sleep_score'] = healthData['sleep_score'] ?? 0;
            mergedVitals['deep_sleep_hours'] = (healthData['deep_sleep_hours'] ?? 0).toDouble();
            mergedVitals['rem_sleep_hours'] = (healthData['rem_sleep_hours'] ?? 0).toDouble();
            mergedVitals['core_sleep_hours'] = (healthData['core_sleep_hours'] ?? 0).toDouble();
            mergedVitals['awake_hours'] = (healthData['awake_hours'] ?? 0).toDouble();
            mergedVitals['sleep_stages'] = healthData['sleep_stages'] ?? [];
            hasRealData = true;
            print("[HomeController] Got real sleep data from Apple Health");
          }

          // Activity data
          mergedVitals['steps'] = healthData['steps'] ?? 0;
          mergedVitals['calories'] = healthData['calories'] ?? 0;
          mergedVitals['distance_km'] = (healthData['distance_km'] ?? 0).toDouble();
          mergedVitals['floors_climbed'] = healthData['floors_climbed'] ?? 0;
          mergedVitals['exercise_minutes'] = healthData['exercise_minutes'] ?? 0;
          mergedVitals['stand_minutes'] = healthData['stand_minutes'] ?? 0;

          // Blood Pressure (if available)
          if ((healthData['blood_pressure_systolic'] ?? 0) > 0) {
            mergedVitals['blood_pressure_systolic'] = healthData['blood_pressure_systolic'];
            mergedVitals['blood_pressure_diastolic'] = healthData['blood_pressure_diastolic'];
          }

          // Audio Exposure
          if ((healthData['headphone_audio_db'] ?? 0) > 0) {
            mergedVitals['headphone_audio_db'] = healthData['headphone_audio_db'];
          }
          if ((healthData['environmental_audio_db'] ?? 0) > 0) {
            mergedVitals['environmental_audio_db'] = healthData['environmental_audio_db'];
          }

          // Workouts
          mergedVitals['workouts_today'] = healthData['workouts_today'] ?? [];
          mergedVitals['workouts_count'] = healthData['workouts_count'] ?? 0;

          // AFib History
          mergedVitals['afib_detected'] = healthData['afib_detected'] ?? false;
          mergedVitals['afib_history'] = healthData['afib_history'] ?? [];

          mergedVitals['is_demo'] = false;
          mergedVitals['source'] = 'apple_health';
          print("[HomeController] Merged with comprehensive Apple Health data");
        } else {
          print("[HomeController] Apple Health returned NULL data");
        }
      } catch (e) {
        print("[HomeController] Could not load comprehensive Apple Health data: $e");
      }

      // Set data_available and last_sync
      mergedVitals['data_available'] = hasRealData;
      mergedVitals['last_sync'] = DateTime.now().toIso8601String();

      watchVitals.value = mergedVitals;
      watchVitalsStatus.value = Status.COMPLETED;

      // Summary log
      print("[HomeController] ========== VITALS SUMMARY ==========");
      print("[HomeController] data_available: $hasRealData");
      print("[HomeController] source: ${mergedVitals['source']}");
      print("[HomeController] heart_rate: ${mergedVitals['heart_rate']}");
      print("[HomeController] blood_oxygen: ${mergedVitals['blood_oxygen']}");
      print("[HomeController] hrv: ${mergedVitals['hrv']}");
      print("[HomeController] respiratory_rate: ${mergedVitals['respiratory_rate']}");
      print("[HomeController] sleep_hours: ${mergedVitals['sleep_hours']}");
      print("[HomeController] steps: ${mergedVitals['steps']}");
      print("[HomeController] ====================================");

      // Save Apple Health data to PostgreSQL if we got new data
      if (hasRealData && mergedVitals['source'] == 'apple_health') {
        await _saveVitalsToAPI(mergedVitals);
      }

    } catch (e) {
      watchVitalsStatus.value = Status.ERROR;
      print("[HomeController] Error loading watch vitals: $e");
    }
  }

  /// Save Apple Health vitals to Django API for PostgreSQL storage
  /// This ensures all health data is persisted with timestamps for daily/weekly/monthly reports
  Future<void> _saveVitalsToAPI(Map<String, dynamic> vitals) async {
    try {
      print("[HomeController] Saving vitals to PostgreSQL...");

      // Prepare data for API
      final apiData = {
        'heart_rate': vitals['heart_rate'] ?? 0,
        'blood_oxygen': vitals['blood_oxygen'] ?? 0,
        'hrv': vitals['hrv'] ?? 0,
        'respiratory_rate': vitals['respiratory_rate'] ?? 0,
        'total_sleep_hours': vitals['sleep_hours'] ?? 0,
        'deep_sleep_hours': vitals['deep_sleep_hours'] ?? 0,
        'rem_sleep_hours': vitals['rem_sleep_hours'] ?? 0,
        'core_sleep_hours': vitals['core_sleep_hours'] ?? 0,
        'awake_time_hours': vitals['awake_hours'] ?? 0,
        'awakenings_count': vitals['awakenings'] ?? 0,
        'sleep_quality': vitals['sleep_quality'] ?? 'unknown',
        'fall_detected': vitals['fall_detected'] ?? false,
        'recorded_at': DateTime.now().toIso8601String(),
        // Activity data (stored for reports)
        'steps': vitals['steps'] ?? 0,
        'calories': vitals['calories'] ?? 0,
        'distance_km': vitals['distance_km'] ?? 0,
        'floors_climbed': vitals['floors_climbed'] ?? 0,
        'exercise_minutes': vitals['exercise_minutes'] ?? 0,
        'stand_minutes': vitals['stand_minutes'] ?? 0,
      };

      // Only save if we have meaningful data (at least heart rate or steps)
      if ((apiData['heart_rate'] as num) > 0 || (apiData['steps'] as num) > 0) {
        final response = await _homeRepository.saveWatchVitals(apiData);

        if (response['status'] == true) {
          print("[HomeController] ✅ Vitals saved to PostgreSQL successfully");
        } else {
          print("[HomeController] ⚠️ Failed to save vitals: ${response['message']}");
        }
      } else {
        print("[HomeController] Skipping API save - no meaningful data");
      }
    } catch (e) {
      print("[HomeController] ❌ Error saving vitals to API: $e");
    }
  }

  void _loadMedications() async {
    try {
      // Initialize medication controller if not already done
      if (!Get.isRegistered<MedicationController>()) {
        Get.put(MedicationController());
      }

      // Load medications from database with timeout
      final medicationController = Get.find<MedicationController>();

      // Don't wait for medications to load to avoid blocking the app
      medicationController.loadMedications(forceRefresh: true).then((_) {
        print("Loaded ${medicationController.medications.length} medications from database");
      }).catchError((e) {
        print("Error loading medications on startup: $e");
      });

      // Also load adherence summary for the home screen display
      medicationController.loadAdherenceSummary().then((_) {
        print("📊 Adherence summary loaded for home screen");
      }).catchError((e) {
        print("Error loading adherence summary: $e");
      });
    } catch (e) {
      print("Error initializing medication controller: $e");
    }
  }

  void _initSpeechRecognition() async {
    _monitor.startTimer('speech_recognition_init');

    // Disable speech recognition for now to prevent looping errors
    _monitor.endTimer('speech_recognition_init');
    _monitor.logPerformanceMetric('speech_recognition_disabled', true);

    // Comment out speech recognition to avoid continuous errors
    // Will re-enable when app is stable
    /*
    bool available = await _speech.initialize(
      onStatus: (status) {
        _monitor.logPerformanceMetric('speech_status_change', status);
        // Only restart listening if no trigger has occurred
        if (!hasTriggered.value &&
            (status == "done" || status == "notListening")) {
          _startListening();
        }
      },
      onError: (error) {
        _monitor.logError('speech_recognition', 'Speech recognition error', error);
        print("Error: $error");
      },
    );

    if (available && !hasTriggered.value) {
      _startListening();
      _monitor.endTimer('speech_recognition_init');
      _monitor.logPerformanceMetric('speech_recognition_available', true);
    } else {
      _monitor.endTimer('speech_recognition_init');
      _monitor.logError('speech_recognition', 'Speech recognition not available or already triggered', null);
    }
    */
  }

  void _startListening() {
    const triggerPhrases = [
      "hey kindura",
      "hey condura", 
      "hey candura",
      "hey kindra",
      "hey kyndura",
      "hey kandra",
      "hey kan dura",
      "hey ken dura",
      "hi kindura",
      "okay kindura",
      "kindura",
      "condura",
      "candura",
      "kindra",
      "kyndura",
      "kandra",
      "dora",
      "ken dora",
      "kendura",
      "gendura",
      "jindura",
      "cindura",
      "syndura",
    ];

    _speech.listen(
      onResult: (result) {
        recognizedText = result.recognizedWords.toLowerCase();
        print("Recognized: $recognizedText");
        _monitor.logPerformanceMetric('speech_recognition_result', recognizedText);

        bool triggerFound = false;
        
        // Check exact matches first
        for (final phrase in triggerPhrases) {
          if (recognizedText.contains(phrase)) {
            _monitor.logVoiceTrigger(recognizedText, true);
            connectToRoom(); // initiate connection
            triggerFound = true;
            break;
          }
        }
        
        // Check fuzzy matches for kindura-like sounds
        if (!triggerFound) {
          final fuzzyTriggers = [
            "i can do it",
            "i can do that",
            "i can dura",
            "i can doing", 
            "i kind of",
            "i conda",
            "icon do it",
            "icon dura",
            "can do it",
            "can dura",
          ];
          
          for (final fuzzyPhrase in fuzzyTriggers) {
            if (recognizedText.contains(fuzzyPhrase)) {
              print("Fuzzy trigger detected: $fuzzyPhrase in '$recognizedText'");
              _monitor.logVoiceTrigger(recognizedText, true);
              connectToRoom(); // initiate connection
              triggerFound = true;
              break;
            }
          }
        }
        
        if (!triggerFound && recognizedText.isNotEmpty) {
          _monitor.logVoiceTrigger(recognizedText, false);
        }
      },
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      cancelOnError: false,
    );

    isListening.value = true;
    _monitor.logPerformanceMetric('speech_listening_started', true);
  }

  Future<void> homeApi() async {
    _monitor.startTimer('home_api_initialization');
    agentStatus.value = Status.LOADING;
    
    try {
      await Future.wait([
        getCourseList(),
        userProfileApi(),
      ]).then((value) {
        livekitTokenApi();
        agentStatus.value = Status.COMPLETED;
        _monitor.endTimer('home_api_initialization');
        _monitor.logPerformanceMetric('home_api_success', true);
      }).onError((error, stackTrace) {
        agentStatus.value = Status.ERROR;
        errors.value = error.toString();
        _monitor.endTimer('home_api_initialization');
        _monitor.logError('home_api', 'Home API initialization failed', error, stackTrace);
      });
    } catch (error, stackTrace) {
      agentStatus.value = Status.ERROR;
      errors.value = error.toString();
      _monitor.endTimer('home_api_initialization');
      _monitor.logError('home_api', 'Unexpected error in home API', error, stackTrace);
    }
  }

  Future<void> livekitTokenApi() async {
    _monitor.startTimer('livekit_token_api');
    try {
      final courseDetails = courseList.value.result?.toJson() ?? {};
      courseDetails['current_time'] =
          DateTime.now().toLocal().toIso8601String();
      courseDetails['auth_token'] = await userPreferences.getToken();
      courseDetails['language'] = userProfile.value.result?.language;
      courseDetails['agent_conversation_choice'] =
          userProfile.value.result?.agentConservationChoice;
      var data = {
        "identity": userProfile.value.result?.email,
        "room": "room_${userProfile.value.result?.email}",
        "name": userProfile.value.result?.firstName,
        "course_details": courseDetails,
      };

      print("the data is $data");
      _monitor.logPerformanceMetric('livekit_token_request_data_size', data.toString().length);

      var value = await _homeRepository.livekitToken(data);
      print("the value is $value");
      
      final duration = _monitor.endTimer('livekit_token_api');
      _monitor.logPerformanceMetric('livekit_token_response_time', duration?.inMilliseconds ?? 0, 'ms');
      
      if (value['status'] == true) {
        token = value['result']['token'];
        _monitor.logPerformanceMetric('livekit_token_success', true);
        _monitor.logPerformanceMetric('livekit_token_length', token.length);
      } else {
        _monitor.logError('livekit_token', 'Failed to get LiveKit token', value["result"]["error"]);
        Util.Snack_Bar("Warning", value["result"]["error"]);
      }
    } catch (error) {
      errors.value = error.toString();
      _monitor.endTimer('livekit_token_api');
      _monitor.logError('livekit_token', 'Error getting LiveKit token', error);
      print('Error connecting: $error');
    }
  }

  Future<void> deleteLivekitRoomApi() async {
    try {
      var value = await _homeRepository.deleteLivekitRoom({
        "room": "room_${userProfile.value.result?.email}",
      });
      print("the value is $value");
      if (value['status'] == true) {
        Util.Snack_Bar("Success",
            "Your reports and feedback has been submitted successfully");
      } else {
        Util.Snack_Bar("Warning", "Something went wrong");
      }
    } catch (error) {
      errors.value = error.toString();
      print('Error connecting in deleteLivekitRoomApi: $error');
    }
  }

  Future<void> userProfileApi() async {
    try {
      var value = await _homeRepository.userProfile();
      if (value['status'] == true) {
        userProfile.value = UserProfile.fromJson(value);
      } else {
        Util.Snack_Bar("Warning", "Something went wrong");
      }
    } catch (error) {
      errors.value = error.toString();
      print('Error connecting in userProfileApi: $error');
    }
  }

  Future<void> getCourseList() async {
    // Course endpoint has been replaced with medical documents
    // Keeping this method for backward compatibility but it doesn't fetch courses anymore
    try {
      // Skip fetching courses as they've been replaced with medical documents
      print("Skipping getCourseList - courses replaced with medical documents");
      courseList.value = course_models.CourseList(status: true, result: course_models.Result());
    } catch (error) {
      errors.value = error.toString();
      print('Error in getCourseList: $error');
    }
  }

  Future<void> connectToRoom() async {
    // Prevent multiple connection attempts
    if (requestStatus.value == Status.LOADING) {
      print("Already connecting, please wait...");
      _monitor.logPerformanceMetric('connection_attempt_blocked', true);
      return;
    }
    
    _connectionStartTime = DateTime.now();
    _monitor.startTimer('livekit_connection');
    _monitor.logLiveKitEvent('connection_start', {
      'room': "room_${userProfile.value.result?.email}",
      'user': userProfile.value.result?.email,
    });
    
    requestStatus.value = Status.LOADING;
    hasTriggered.value = true;
    _speech.stop();
    
    // Always get a fresh token for new connections
    token = "";
    await livekitTokenApi();

    _room = livekit.Room();
    final options = livekit.RoomOptions(
      adaptiveStream: true,
      dynacast: true,
      defaultAudioOutputOptions: livekit.AudioOutputOptions(
        speakerOn: true,
      ),
      defaultAudioCaptureOptions: livekit.AudioCaptureOptions(
        echoCancellation: true,
        noiseSuppression: true,
      ),
    );

    try {
      final url = "wss://kindura-u99yilqz.livekit.cloud";
      print("the url is $url");
      print("the token is $token");

      _monitor.startTimer('livekit_websocket_connection');

      await _room!.connect(url, token, roomOptions: options);

      final websocketDuration = _monitor.endTimer('livekit_websocket_connection');
      _monitor.logPerformanceMetric('websocket_connection_time', websocketDuration?.inMilliseconds ?? 0, 'ms');

      await _room!.localParticipant!.setMicrophoneEnabled(true);
      _monitor.logLiveKitEvent('microphone_enabled', {'enabled': true});

      // Ensure speaker is enabled for audio output
      await livekit.Hardware.instance.setSpeakerphoneOn(true);
      print("🔊 Speaker enabled for audio output");

      // Check for any existing remote participants and their tracks
      print("🔍 Checking for existing remote participants: ${_room!.remoteParticipants.length}");
      for (final participant in _room!.remoteParticipants.values) {
        print("👤 Found existing participant: ${participant.identity}");
        print("   - Audio tracks: ${participant.audioTrackPublications.length}");
        for (final trackPublication in participant.audioTrackPublications) {
          print("   - Track pub: subscribed=${trackPublication.subscribed}, enabled=${trackPublication.enabled}");
          if (trackPublication.track != null) {
            final audioTrack = trackPublication.track as livekit.AudioTrack;
            audioTrack.start();
            print("✅ Started existing audio track from ${participant.identity}");
          } else {
            // Try to subscribe if not already
            print("⚠️ Track is null, attempting to subscribe...");
          }
        }
      }

      // Subscribe to remote participant tracks (for audio from agent)
      _room!.createListener()
        ..on<livekit.TrackPublishedEvent>((event) {
          print("📢 Track PUBLISHED: ${event.publication.kind} from ${event.participant.identity}");
          print("   - Source: ${event.publication.source}");
          print("   - Subscribed: ${event.publication.subscribed}");
          print("   - SID: ${event.publication.sid}");
        })
        ..on<livekit.TrackSubscribedEvent>((event) {
          final now = DateTime.now();
          final connectionDelay = _connectionStartTime != null
            ? now.difference(_connectionStartTime!).inMilliseconds
            : 0;

          print("✅ Track SUBSCRIBED: ${event.track.kind} from ${event.participant.identity}");
          _monitor.logLiveKitEvent('track_subscribed', {
            'track_kind': event.track.kind.toString(),
            'participant_identity': event.participant.identity,
            'connection_delay_ms': connectionDelay,
          });

          if (event.track.kind == livekit.TrackType.AUDIO) {
            print("🔊 Audio track subscribed from agent!");
            _monitor.logPerformanceMetric('audio_track_ready_time', connectionDelay, 'ms');

            // Enable audio playback for agent voice
            final audioTrack = event.track as livekit.AudioTrack;
            audioTrack.start();
            print("🎵 Agent audio track started for playback");

            // Ensure speaker is on
            livekit.Hardware.instance.setSpeakerphoneOn(true);
            print("🔊 Speaker confirmed ON");
          }
        })
        ..on<livekit.TrackUnsubscribedEvent>((event) {
          print("❌ Track UNSUBSCRIBED: ${event.track.kind} from ${event.participant.identity}");
        })
        ..on<livekit.ParticipantConnectedEvent>((event) {
          final connectionDelay = _connectionStartTime != null 
            ? DateTime.now().difference(_connectionStartTime!).inMilliseconds 
            : 0;
            
          print("Participant connected: ${event.participant.identity}");
          _monitor.logLiveKitEvent('participant_connected', {
            'participant_identity': event.participant.identity,
            'connection_delay_ms': connectionDelay,
          });
        })
        ..on<livekit.TranscriptionEvent>((event) {
          final now = DateTime.now();
          final transcriptionDelay = _lastTranscriptionTime != null 
            ? now.difference(_lastTranscriptionTime!).inMilliseconds 
            : 0;
          _lastTranscriptionTime = now;
          
          for (final segment in event.segments) {
            print("New transcription from ${segment.id}: ${segment.text}");
            _monitor.logTranscription(
              segment.id,
              segment.text,
              'agent',
              true
            );
          }
          
          _monitor.logPerformanceMetric('transcription_interval', transcriptionDelay, 'ms');

          if (event.segments.isNotEmpty) {
            requestStatus.value = Status.COMPLETED;
          }
        })
        ..on<livekit.RoomDisconnectedEvent>((event) {
          _monitor.logLiveKitEvent('room_disconnected', {
            'reason': event.reason?.toString(),
          });
        });

      final totalConnectionTime = _monitor.endTimer('livekit_connection');
      
      isConnected.value = true;
      requestStatus.value = Status.COMPLETED;
      
      _monitor.logPerformanceMetric('total_connection_time', totalConnectionTime?.inMilliseconds ?? 0, 'ms');
      _monitor.logLiveKitEvent('connection_established', {
        'connection_time_ms': totalConnectionTime?.inMilliseconds,
        'websocket_url': url,
      });
      
      print("Successfully connected to LiveKit room");
    } catch (e) {
      final failedConnectionTime = _monitor.endTimer('livekit_connection');
      
      requestStatus.value = Status.ERROR;
      isConnected.value = false;
      token = "";
      
      _monitor.logError('livekit_connection', 'Failed to connect to LiveKit room', e);
      _monitor.logPerformanceMetric('failed_connection_time', failedConnectionTime?.inMilliseconds ?? 0, 'ms');
      
      print('Error connecting in connectToRoom: $e');
      Util.Snack_Bar("Connection Error", "Failed to connect. Please try again.");
    }
  }

  Future<void> logout() async {
    hasTriggered.value = true;
    _speech.stop();
    await userPreferences.removeUser();
    // Navigate first, then delete controllers
    Get.offAllNamed(RoutesName.splashScreen);
    Get.deleteAll();
  }

  void disconnect() async {
    _monitor.startTimer('livekit_disconnect');
    try {
      requestStatus.value = Status.LOADING;

      // Disconnect from room first (only if room was initialized)
      if (_room != null && _room!.connectionState != livekit.ConnectionState.disconnected) {
        _monitor.logLiveKitEvent('disconnection_start', {
          'connection_state': _room!.connectionState.toString(),
        });

        _room!.disconnect();
        _monitor.logLiveKitEvent('room_disconnected_locally', {});
        print("Disconnected from LiveKit room");
      }
      
      // Then delete the room on server
      await deleteLivekitRoomApi();
      
      // Reset all connection state
      token = "";
      isConnected.value = false;
      hasTriggered.value = false;
      _connectionStartTime = null;
      _lastTranscriptionTime = null;
      
      // Restart speech recognition for voice triggers
      _initSpeechRecognition();

      // Refresh medication data after voice session (agent may have updated dose events)
      print("🔄 Refreshing medication data after voice session...");
      _loadMedications();

      final disconnectDuration = _monitor.endTimer('livekit_disconnect');
      _monitor.logPerformanceMetric('disconnect_time', disconnectDuration?.inMilliseconds ?? 0, 'ms');

      requestStatus.value = Status.COMPLETED;
      print("Cleanup completed, ready for new connection");
    } catch (e) {
      final failedDisconnectTime = _monitor.endTimer('livekit_disconnect');
      _monitor.logError('livekit_disconnect', 'Error during disconnect', e);
      _monitor.logPerformanceMetric('failed_disconnect_time', failedDisconnectTime?.inMilliseconds ?? 0, 'ms');
      
      print("Error during disconnect: $e");
      // Force reset state even on error
      isConnected.value = false;
      token = "";
      requestStatus.value = Status.ERROR;
    }
  }

  // Get performance report for debugging
  Map<String, dynamic> getPerformanceReport() {
    return _monitor.getPerformanceSummary();
  }

  // Get recent logs for debugging
  List<Map<String, dynamic>> getRecentLogs([int limit = 50]) {
    return _monitor.getRecentLogs(limit);
  }

  // Export all logs as JSON string
  String exportPerformanceLogs() {
    return _monitor.exportLogs();
  }

  // Start performance monitoring
  void startPerformanceMonitoring() {
    _monitor.setEnabled(true);
    print('🚀 Performance monitoring started');
    Util.Snack_Bar("Debug", "Performance monitoring started");
  }

  // Stop performance monitoring
  void stopPerformanceMonitoring() {
    _monitor.setEnabled(false);
    print('⏹️ Performance monitoring stopped');
    Util.Snack_Bar("Debug", "Performance monitoring stopped");
  }

  // Toggle performance monitoring
  void togglePerformanceMonitoring() {
    if (_monitor.isEnabled) {
      stopPerformanceMonitoring();
    } else {
      startPerformanceMonitoring();
    }
  }

  // Show debug widget
  void showDebugWidget() {
    Get.bottomSheet(
      Container(
        height: Get.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Header with controls
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bug_report, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    'Performance Monitor',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  // Toggle button
                  ElevatedButton(
                    onPressed: togglePerformanceMonitoring,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _monitor.isEnabled ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_monitor.isEnabled ? 'Stop' : 'Start'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // Performance summary
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      leading: Icon(
                        _monitor.isEnabled ? Icons.play_circle : Icons.pause_circle,
                        color: _monitor.isEnabled ? Colors.green : Colors.red,
                      ),
                      title: Text('Monitoring: ${_monitor.isEnabled ? 'Active' : 'Stopped'}'),
                      subtitle: Text('Total logs: ${_monitor.getRecentLogs().length}'),
                    ),
                  ),
                  ...getPerformanceReport().entries.map((entry) {
                    return Card(
                      child: ListTile(
                        title: Text(entry.key.toString().replaceAll('_', ' ').toUpperCase()),
                        trailing: Text(
                          entry.value.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Get.back();
                      // Import the performance debug widget
                      Get.bottomSheet(
                        const Scaffold(
                          body: Center(
                            child: Text('Full Debug Widget - Import performance_debug_widget.dart'),
                          ),
                        ),
                        isScrollControlled: true,
                      );
                    },
                    child: const Text('Open Full Debug Widget'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
      isDismissible: true,
    );
  }

  @override
  void onClose() {
    _speech.stop();
    _healthRefreshTimer?.cancel();
    _webSocketReconnectTimer?.cancel();
    _connectionRetryTimer?.cancel();
    _watchVitalsChannel?.sink.close();
    if (_watchVitalsService != null) {
      try {
        _watchVitalsService!.dispose();
      } catch (e) {
        print('[HomeController] Error disposing watch vitals service: $e');
      }
    }
    // Clean up LiveKit room if initialized
    if (_room != null) {
      try {
        _room!.disconnect();
      } catch (e) {
        print('[HomeController] Error disconnecting room: $e');
      }
    }
    super.onClose();
  }
}
