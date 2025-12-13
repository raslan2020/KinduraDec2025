/// Local Development Configuration
/// This file loads configuration from .env.local for local development
///
/// IMPORTANT: This configuration is only used when isLocalEnvironment = true
/// For production, use the standard authentication flow

import 'dart:io';

class LocalConfig {
  static String? _localDevToken;
  static bool _isLoaded = false;

  /// Load local development token from .env.local file
  static Future<void> load() async {
    if (_isLoaded) return;

    try {
      // Read .env.local file from project root
      final file = File('.env.local');

      if (await file.exists()) {
        final contents = await file.readAsLines();

        for (var line in contents) {
          // Skip comments and empty lines
          if (line.trim().startsWith('#') || line.trim().isEmpty) {
            continue;
          }

          // Parse KEY=VALUE format
          if (line.contains('=')) {
            final parts = line.split('=');
            if (parts.length >= 2) {
              final key = parts[0].trim();
              final value = parts.sublist(1).join('=').trim();

              if (key == 'LOCAL_DEV_TOKEN') {
                _localDevToken = value;
                print('✅ Loaded local dev token from .env.local');
                break;
              }
            }
          }
        }
      } else {
        print('⚠️ .env.local not found. Run ./setup_local.sh to create it.');
      }
    } catch (e) {
      print('⚠️ Could not load .env.local: $e');
    }

    _isLoaded = true;
  }

  /// Get the local development token
  static Future<String?> getLocalDevToken() async {
    if (!_isLoaded) {
      await load();
    }

    if (_localDevToken == null || _localDevToken!.isEmpty) {
      print('⚠️ LOCAL_DEV_TOKEN not found in .env.local');
      print('💡 Run ./setup_local.sh to set up your local environment');
      return null;
    }

    return _localDevToken;
  }

  /// Check if config is loaded
  static bool get isLoaded => _isLoaded;

  /// Get token synchronously (must call load() first)
  static String? get token => _localDevToken;
}
