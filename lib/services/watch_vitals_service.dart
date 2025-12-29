import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kindura_ai/repository/home_repository/home_repository.dart';
import 'package:kindura_ai/user_preference/user_preferences_view_model.dart';
import 'package:kindura_ai/res/app_url/app_url.dart';
import 'package:kindura_ai/models/health/data_source_mode.dart';

/// Service to handle Watch vitals data from iOS native layer
/// Supports multiple data sources:
/// - Apple Watch via WCSession (real-time vitals, fall detection)
/// - HealthKit only (for Oura, Whoop, Ultrahuman, etc.)
/// - Manual entry
class WatchVitalsService {
  static const MethodChannel _channel = MethodChannel('com.kindura.ai/watch_vitals');
  final HomeRepository _homeRepository = HomeRepository();
  final UserPreferences _userPreferences = UserPreferences();

  // Current data source mode
  DataSourceMode _currentMode = DataSourceMode.healthKitOnly;
  bool _modeDetected = false;

  // User override preference (null = auto-detect)
  DataSourceMode? _userOverrideMode;

  Function(Map<String, dynamic>)? onVitalsReceived;
  Function(Map<String, dynamic>)? onFallDetected;
  Function(String type)? onHealthKitDataChanged;

  /// Get the current data source mode
  DataSourceMode get currentMode => _userOverrideMode ?? _currentMode;

  /// Check if mode has been detected
  bool get isModeDetected => _modeDetected;

  /// Check if user has set a manual override
  bool get hasUserOverride => _userOverrideMode != null;

  WatchVitalsService() {
    _setupMethodCallHandler();
  }

  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onWatchVitalsReceived') {
        final vitals = Map<String, dynamic>.from(call.arguments as Map);
        print('[WatchVitalsService] ⌚ Received Watch vitals from native: $vitals');

        // Check for fall detection - handle immediately with priority
        if (vitals['fall_detected'] == true) {
          print('[WatchVitalsService] ⚠️ FALL DETECTED! Triggering emergency handler');
          _handleFallDetection(vitals);
        }

        // Send to API
        await _sendVitalsToAPI(vitals);

        // Notify listeners
        onVitalsReceived?.call(vitals);
      } else if (call.method == 'onHealthKitDataChanged') {
        // HealthKit data changed notification from iOS observers
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final type = args['type'] as String? ?? 'unknown';
        final timestamp = args['timestamp'] as String?;

        print('[WatchVitalsService] 🔔 HealthKit data changed: $type at $timestamp');

        // Notify listeners about the change
        onHealthKitDataChanged?.call(type);
      }
      return null;
    });
  }

  /// Handle fall detection event with priority
  void _handleFallDetection(Map<String, dynamic> vitals) {
    // Notify fall detection listeners immediately
    onFallDetected?.call(vitals);

    // Send fall event to API with high priority
    _sendFallEventToAPI(vitals);
  }

  /// Send fall detection event to API (separate from regular vitals)
  Future<void> _sendFallEventToAPI(Map<String, dynamic> vitals) async {
    try {
      final fallData = {
        'event_type': 'fall_detected',
        'severity': vitals['fall_severity'] ?? 'unknown',
        'heart_rate_at_fall': vitals['heart_rate'],
        'location': vitals['location'],
        'timestamp': vitals['timestamp'] ?? DateTime.now().toIso8601String(),
        'device': 'apple_watch',
      };

      print('[WatchVitalsService] Sending fall event to API: $fallData');
      // TODO: Add dedicated fall event endpoint when available
      // For now, fall_detected is sent as part of watch vitals
    } catch (e) {
      print('[WatchVitalsService] Error sending fall event: $e');
    }
  }

  /// Get latest vitals from native layer (cached)
  Future<Map<String, dynamic>?> getLatestVitals() async {
    try {
      final result = await _channel.invokeMethod('getLatestVitals');
      if (result != null) {
        return Map<String, dynamic>.from(result as Map);
      }
      return null;
    } catch (e) {
      print('Error getting latest vitals: $e');
      return null;
    }
  }

  /// Send vitals to Django API for storage
  Future<void> _sendVitalsToAPI(Map<String, dynamic> vitals) async {
    try {
      // Convert Watch data format to API format
      final apiData = {
        'heart_rate': vitals['heart_rate'] ?? 0,
        'blood_oxygen': vitals['blood_oxygen'] ?? 0,
        'hrv': vitals['hrv'],
        'respiratory_rate': vitals['respiratory_rate'],
        'total_sleep_hours': vitals['total_sleep_hours'],
        'deep_sleep_hours': vitals['deep_sleep_hours'],
        'rem_sleep_hours': vitals['rem_sleep_hours'],
        'core_sleep_hours': vitals['core_sleep_hours'],
        'awake_time_hours': vitals['awake_time_hours'],
        'awakenings_count': vitals['awakenings_count'] ?? 0,
        'sleep_quality': vitals['sleep_quality'],
        'fall_detected': vitals['fall_detected'] ?? false,
        'recorded_at': vitals['timestamp'] ?? DateTime.now().toIso8601String(),
      };

      final response = await _homeRepository.saveWatchVitals(apiData);

      if (response['status'] == true) {
        print('Watch vitals saved to database successfully');
      } else {
        print('Failed to save Watch vitals: ${response['message']}');
      }
    } catch (e) {
      print('Error sending vitals to API: $e');
    }
  }

  // MARK: - Watch Configuration Sync

  /// Sync API configuration to Apple Watch
  /// Should be called after user login and when token is refreshed
  Future<bool> syncConfigurationToWatch() async {
    try {
      final token = await _userPreferences.getToken();
      if (token == null || token.isEmpty) {
        print('[WatchVitalsService] Cannot sync to Watch - no auth token available');
        return false;
      }

      // Get the base URL (remove /api suffix for Watch)
      String baseURL = AppUrl.baseUrl;
      if (baseURL.endsWith('/api')) {
        baseURL = baseURL.substring(0, baseURL.length - 4);
      }

      print('[WatchVitalsService] Syncing configuration to Watch...');
      print('[WatchVitalsService] Base URL: $baseURL');

      // Add 10-second timeout to prevent UI hanging if Watch doesn't respond
      final result = await _channel.invokeMethod<bool>('updateWatchConfiguration', {
        'baseURL': baseURL,
        'token': token,
      }).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('[WatchVitalsService] ⏱️ Watch sync timed out after 10 seconds');
          return false;
        },
      );

      if (result == true) {
        print('[WatchVitalsService] ✅ Configuration synced to Watch successfully');
        return true;
      } else {
        print('[WatchVitalsService] ⚠️ Watch configuration sync returned false or timed out');
        return false;
      }
    } on PlatformException catch (e) {
      print('[WatchVitalsService] ❌ Platform error syncing to Watch: ${e.message}');
      return false;
    } catch (e) {
      print('[WatchVitalsService] ❌ Error syncing configuration to Watch: $e');
      return false;
    }
  }

  /// Check if Apple Watch is paired with this iPhone
  Future<bool> isWatchPaired() async {
    try {
      final result = await _channel.invokeMethod<bool>('isWatchPaired');
      return result ?? false;
    } catch (e) {
      print('[WatchVitalsService] Error checking Watch pairing: $e');
      return false;
    }
  }

  /// Check if Apple Watch is currently reachable
  Future<bool> isWatchReachable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isWatchReachable');
      return result ?? false;
    } catch (e) {
      print('[WatchVitalsService] Error checking Watch reachability: $e');
      return false;
    }
  }

  /// Get Watch connection status for UI display
  Future<Map<String, dynamic>> getWatchStatus() async {
    final isPaired = await isWatchPaired();
    final isReachable = await isWatchReachable();

    return {
      'isPaired': isPaired,
      'isReachable': isReachable,
      'statusText': !isPaired
          ? 'No Watch paired'
          : (isReachable ? 'Connected' : 'Watch not reachable'),
    };
  }

  // MARK: - HealthKit Authorization

  /// Request HealthKit authorization for reading health data
  /// Returns true if authorization was granted or already authorized
  Future<bool> requestHealthKitAuthorization() async {
    try {
      print('[WatchVitalsService] Requesting HealthKit authorization...');
      final result = await _channel.invokeMethod<bool>('requestHealthKitAuthorization');

      if (result == true) {
        print('[WatchVitalsService] ✅ HealthKit authorization granted');
        return true;
      } else {
        print('[WatchVitalsService] ⚠️ HealthKit authorization denied or unavailable');
        return false;
      }
    } on PlatformException catch (e) {
      print('[WatchVitalsService] ❌ Platform error requesting HealthKit: ${e.message}');
      return false;
    } catch (e) {
      print('[WatchVitalsService] ❌ Error requesting HealthKit authorization: $e');
      return false;
    }
  }

  /// Check if HealthKit authorization has been granted
  Future<bool> isHealthKitAuthorized() async {
    try {
      final result = await _channel.invokeMethod<bool>('isHealthKitAuthorized');
      return result ?? false;
    } catch (e) {
      print('[WatchVitalsService] Error checking HealthKit authorization: $e');
      return false;
    }
  }

  /// Get comprehensive health integration status
  Future<Map<String, dynamic>> getHealthIntegrationStatus() async {
    final watchStatus = await getWatchStatus();
    final healthKitAuthorized = await isHealthKitAuthorized();

    return {
      ...watchStatus,
      'healthKitAuthorized': healthKitAuthorized,
      'isFullyConfigured': watchStatus['isPaired'] == true && healthKitAuthorized,
    };
  }

  // MARK: - Apple Health Data (iPhone-side)

  /// Get comprehensive health summary from Apple Health
  /// Includes vitals, sleep, and activity data from any connected device
  Future<Map<String, dynamic>?> getHealthSummary() async {
    try {
      final result = await _channel.invokeMethod<Map>('getHealthSummary');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      print('[WatchVitalsService] Error getting health summary: ${e.message}');
      return null;
    } catch (e) {
      print('[WatchVitalsService] Error getting health summary: $e');
      return null;
    }
  }

  /// Get sleep data from Apple Health
  /// Returns sleep from any source (Watch, Oura, Whoop, etc.)
  Future<Map<String, dynamic>?> getSleepData() async {
    try {
      final result = await _channel.invokeMethod<Map>('getSleepData');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      print('[WatchVitalsService] Error getting sleep data: ${e.message}');
      return null;
    } catch (e) {
      print('[WatchVitalsService] Error getting sleep data: $e');
      return null;
    }
  }

  /// Get today's activity data from Apple Health
  /// Returns steps, calories, distance, floors from any source
  Future<Map<String, dynamic>?> getActivityData() async {
    try {
      final result = await _channel.invokeMethod<Map>('getActivityData');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      print('[WatchVitalsService] Error getting activity data: ${e.message}');
      return null;
    } catch (e) {
      print('[WatchVitalsService] Error getting activity data: $e');
      return null;
    }
  }

  /// Get weekly health summary from Apple Health
  /// Returns aggregated data for the past 7 days
  Future<Map<String, dynamic>?> getWeeklySummary() async {
    try {
      final result = await _channel.invokeMethod<Map>('getWeeklySummary');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      print('[WatchVitalsService] Error getting weekly summary: ${e.message}');
      return null;
    } catch (e) {
      print('[WatchVitalsService] Error getting weekly summary: $e');
      return null;
    }
  }

  /// Get monthly health summary from Apple Health
  /// Returns aggregated data for the past 30 days
  Future<Map<String, dynamic>?> getMonthlySummary() async {
    try {
      final result = await _channel.invokeMethod<Map>('getMonthlySummary');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      print('[WatchVitalsService] Error getting monthly summary: ${e.message}');
      return null;
    } catch (e) {
      print('[WatchVitalsService] Error getting monthly summary: $e');
      return null;
    }
  }

  /// Get comprehensive health data from Apple Health
  /// Returns all available vitals, sleep, activity, workouts, blood pressure, audio
  Future<Map<String, dynamic>?> getComprehensiveHealth() async {
    try {
      final result = await _channel.invokeMethod<Map>('getComprehensiveHealth');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      print('[WatchVitalsService] Error getting comprehensive health: ${e.message}');
      return null;
    } catch (e) {
      print('[WatchVitalsService] Error getting comprehensive health: $e');
      return null;
    }
  }

  /// Get health history for a specified number of days
  /// Returns raw samples for heart rate, blood oxygen, HRV, and sleep
  /// Used by Vitals History screen when API returns empty
  Future<List<Map<String, dynamic>>?> getHealthHistory(int days) async {
    try {
      print('[WatchVitalsService] Getting health history for $days days');
      final result = await _channel.invokeMethod<List>('getHealthHistory', {'days': days});
      if (result != null) {
        final history = result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        print('[WatchVitalsService] Retrieved ${history.length} health history records');
        return history;
      }
      return null;
    } on PlatformException catch (e) {
      print('[WatchVitalsService] Error getting health history: ${e.message}');
      return null;
    } catch (e) {
      print('[WatchVitalsService] Error getting health history: $e');
      return null;
    }
  }

  // MARK: - HealthKit Observers (Event-Driven Updates)

  /// Start HealthKit observers for real-time event-driven updates
  /// Observers will notify via onHealthKitDataChanged callback when data changes
  Future<bool> startHealthKitObservers() async {
    try {
      print('[WatchVitalsService] 🔔 Starting HealthKit observers...');
      final result = await _channel.invokeMethod<bool>('startHealthKitObservers');
      if (result == true) {
        print('[WatchVitalsService] ✅ HealthKit observers started');
        return true;
      }
      return false;
    } on PlatformException catch (e) {
      print('[WatchVitalsService] Error starting HealthKit observers: ${e.message}');
      return false;
    } catch (e) {
      print('[WatchVitalsService] Error starting HealthKit observers: $e');
      return false;
    }
  }

  /// Stop HealthKit observers (for cleanup or battery saving)
  Future<bool> stopHealthKitObservers() async {
    try {
      print('[WatchVitalsService] 🔕 Stopping HealthKit observers...');
      final result = await _channel.invokeMethod<bool>('stopHealthKitObservers');
      if (result == true) {
        print('[WatchVitalsService] ✅ HealthKit observers stopped');
        return true;
      }
      return false;
    } on PlatformException catch (e) {
      print('[WatchVitalsService] Error stopping HealthKit observers: ${e.message}');
      return false;
    } catch (e) {
      print('[WatchVitalsService] Error stopping HealthKit observers: $e');
      return false;
    }
  }

  // MARK: - Data Source Mode Detection & Management

  /// Detect the appropriate data source mode based on available devices
  /// Call this on app startup to determine how to fetch health data
  ///
  /// Priority:
  /// 1. User override (if set in Settings)
  /// 2. Apple Watch (if paired and app installed)
  /// 3. HealthKit (if authorized)
  /// 4. Manual only (fallback)
  Future<DataSourceMode> detectDataSourceMode() async {
    print('[WatchVitalsService] 🔍 Detecting data source mode...');

    // Check for user override first
    final savedOverride = await _loadUserOverride();
    if (savedOverride != null) {
      _userOverrideMode = savedOverride;
      print('[WatchVitalsService] 👤 User override active: ${savedOverride.displayName}');
      _modeDetected = true;
      return savedOverride;
    }

    // Auto-detect based on available devices
    try {
      final isPaired = await isWatchPaired();
      final isHealthKitAuth = await isHealthKitAuthorized();

      if (isPaired) {
        _currentMode = DataSourceMode.appleWatch;
        print('[WatchVitalsService] ⌚ Apple Watch detected - using Watch mode');
      } else if (isHealthKitAuth) {
        _currentMode = DataSourceMode.healthKitOnly;
        print('[WatchVitalsService] ❤️ No Watch - using HealthKit only mode (Oura, Whoop, etc.)');
      } else {
        _currentMode = DataSourceMode.manualOnly;
        print('[WatchVitalsService] 📝 No devices - using manual entry mode');
      }
    } catch (e) {
      print('[WatchVitalsService] Error detecting mode: $e - defaulting to HealthKit');
      _currentMode = DataSourceMode.healthKitOnly;
    }

    _modeDetected = true;
    return _currentMode;
  }

  /// Set user override for data source mode
  /// Pass null to clear override and return to auto-detect
  Future<void> setUserOverride(DataSourceMode? mode) async {
    _userOverrideMode = mode;

    final prefs = await SharedPreferences.getInstance();
    if (mode != null) {
      await prefs.setString('data_source_override', mode.toStorageString());
      print('[WatchVitalsService] 👤 User override set: ${mode.displayName}');
    } else {
      await prefs.remove('data_source_override');
      print('[WatchVitalsService] 👤 User override cleared - using auto-detect');
    }
  }

  /// Load user override preference from storage
  Future<DataSourceMode?> _loadUserOverride() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('data_source_override');
    if (stored != null && stored.isNotEmpty) {
      return DataSourceModeExtension.fromStorageString(stored);
    }
    return null;
  }

  /// Check if current mode supports fall detection
  bool get supportsFallDetection => currentMode.supportsFallDetection;

  /// Check if current mode supports real-time heart rate
  bool get supportsRealTimeHeartRate => currentMode.supportsRealTimeHeartRate;

  /// Get available data source options for Settings UI
  Future<List<DataSourceOption>> getAvailableDataSources() async {
    final isPaired = await isWatchPaired();
    final isHealthKitAuth = await isHealthKitAuthorized();

    return [
      DataSourceOption(
        mode: null, // null = auto-detect
        label: 'Auto-detect',
        description: 'Automatically use Watch if paired',
        isAvailable: true,
        isSelected: _userOverrideMode == null,
      ),
      DataSourceOption(
        mode: DataSourceMode.appleWatch,
        label: 'Apple Watch',
        description: 'Real-time vitals & fall detection',
        isAvailable: isPaired,
        isSelected: _userOverrideMode == DataSourceMode.appleWatch,
      ),
      DataSourceOption(
        mode: DataSourceMode.healthKitOnly,
        label: 'Apple Health Only',
        description: 'Oura, Whoop, Ultrahuman, etc.',
        isAvailable: isHealthKitAuth,
        isSelected: _userOverrideMode == DataSourceMode.healthKitOnly,
      ),
      DataSourceOption(
        mode: DataSourceMode.manualOnly,
        label: 'Manual Entry',
        description: 'Enter health data manually',
        isAvailable: true,
        isSelected: _userOverrideMode == DataSourceMode.manualOnly,
      ),
    ];
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
  }
}

/// Represents a data source option for Settings UI
class DataSourceOption {
  final DataSourceMode? mode; // null = auto-detect
  final String label;
  final String description;
  final bool isAvailable;
  final bool isSelected;

  DataSourceOption({
    required this.mode,
    required this.label,
    required this.description,
    required this.isAvailable,
    required this.isSelected,
  });
}
