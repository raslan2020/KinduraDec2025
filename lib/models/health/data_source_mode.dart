/// Defines the source of health data for the app
///
/// The app supports multiple health data sources:
/// - Apple Watch via WCSession (real-time vitals, fall detection)
/// - HealthKit only (for Oura, Whoop, Ultrahuman, and other devices)
/// - Manual entry (user inputs data directly)
enum DataSourceMode {
  /// Apple Watch is paired - use WCSession for real-time data + HealthKit backup
  /// Features: Real-time HR, fall detection, sleep, activity
  appleWatch,

  /// No Apple Watch - use HealthKit only
  /// Works with: Oura Ring, Whoop, Ultrahuman, Fitbit, Garmin, etc.
  /// Features: Sleep, activity, HR (delayed), no fall detection
  healthKitOnly,

  /// Manual data entry only
  /// Used when HealthKit is not authorized or no devices available
  manualOnly,
}

/// Extension methods for DataSourceMode
extension DataSourceModeExtension on DataSourceMode {
  /// Returns a user-friendly display name
  String get displayName {
    switch (this) {
      case DataSourceMode.appleWatch:
        return 'Apple Watch';
      case DataSourceMode.healthKitOnly:
        return 'Apple Health';
      case DataSourceMode.manualOnly:
        return 'Manual Entry';
    }
  }

  /// Returns a description of the data source
  String get description {
    switch (this) {
      case DataSourceMode.appleWatch:
        return 'Real-time vitals from Apple Watch';
      case DataSourceMode.healthKitOnly:
        return 'Data from Oura, Whoop, Ultrahuman, etc.';
      case DataSourceMode.manualOnly:
        return 'Enter health data manually';
    }
  }

  /// Returns the icon name for the data source
  String get iconName {
    switch (this) {
      case DataSourceMode.appleWatch:
        return 'watch';
      case DataSourceMode.healthKitOnly:
        return 'favorite';
      case DataSourceMode.manualOnly:
        return 'edit';
    }
  }

  /// Whether fall detection is available in this mode
  bool get supportsFallDetection {
    return this == DataSourceMode.appleWatch;
  }

  /// Whether real-time heart rate streaming is available
  bool get supportsRealTimeHeartRate {
    return this == DataSourceMode.appleWatch;
  }

  /// Convert to string for storage
  String toStorageString() {
    switch (this) {
      case DataSourceMode.appleWatch:
        return 'apple_watch';
      case DataSourceMode.healthKitOnly:
        return 'healthkit_only';
      case DataSourceMode.manualOnly:
        return 'manual_only';
    }
  }

  /// Create from storage string
  static DataSourceMode fromStorageString(String? value) {
    switch (value) {
      case 'apple_watch':
        return DataSourceMode.appleWatch;
      case 'healthkit_only':
        return DataSourceMode.healthKitOnly;
      case 'manual_only':
        return DataSourceMode.manualOnly;
      default:
        return DataSourceMode.healthKitOnly; // Default fallback
    }
  }
}
