import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  FirebaseRemoteConfig? _remoteConfig;
  PackageInfo? _packageInfo;

  // Update configuration keys
  static const String _minVersionKey = 'min_app_version';
  static const String _latestVersionKey = 'latest_app_version';
  static const String _forceUpdateKey = 'force_update_enabled';
  static const String _updateMessageKey = 'update_message';
  static const String _updateTitleKey = 'update_title';
  static const String _playStoreUrlKey = 'play_store_url';
  static const String _appStoreUrlKey = 'app_store_url';

  // SharedPreferences keys
  static const String _lastUpdateCheckKey = 'last_update_check';
  static const String _updateDismissedKey = 'update_dismissed_';

  /// Initialize the update service
  Future<void> initialize() async {
    try {
      // Initialize package info
      _packageInfo = await PackageInfo.fromPlatform();
      
      // Initialize Firebase Remote Config
      _remoteConfig = FirebaseRemoteConfig.instance;
      
      // Set default values
      await _remoteConfig!.setDefaults({
        _minVersionKey: _packageInfo!.version,
        _latestVersionKey: _packageInfo!.version,
        _forceUpdateKey: false,
        _updateTitleKey: 'Update Available',
        _updateMessageKey: 'A new version of the app is available. Please update to continue using the app.',
        _playStoreUrlKey: 'https://play.google.com/store/apps/details?id=${_packageInfo!.packageName}',
        _appStoreUrlKey: 'https://apps.apple.com/app/id${_packageInfo!.packageName}',
      });

      // Set fetch timeout
      await _remoteConfig!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));

      // Fetch and activate
      await _remoteConfig!.fetchAndActivate();
      
      print('✅ App Update Service initialized successfully');
      print('📱 Current app version: ${_packageInfo!.version}');
      print('📱 Package name: ${_packageInfo!.packageName}');
    } catch (e) {
      print('❌ Error initializing App Update Service: $e');
    }
  }

  /// Check if app update is available
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      if (_remoteConfig == null || _packageInfo == null) {
        await initialize();
      }

      if (_remoteConfig == null || _packageInfo == null) {
        print('❌ App Update Service not properly initialized');
        return null;
      }

      final currentVersion = _packageInfo!.version;
      final minVersion = _remoteConfig!.getString(_minVersionKey);
      final latestVersion = _remoteConfig!.getString(_latestVersionKey);
      final forceUpdate = _remoteConfig!.getBool(_forceUpdateKey);
      final updateTitle = _remoteConfig!.getString(_updateTitleKey);
      final updateMessage = _remoteConfig!.getString(_updateMessageKey);

      print('🔍 Update Check:');
      print('   Current: $currentVersion');
      print('   Min Required: $minVersion');
      print('   Latest: $latestVersion');
      print('   Force Update: $forceUpdate');

      // Check if current version is below minimum required version
      if (_isVersionLower(currentVersion, minVersion)) {
        return UpdateInfo(
          isUpdateAvailable: true,
          isForceUpdate: forceUpdate,
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          minVersion: minVersion,
          title: updateTitle,
          message: updateMessage,
        );
      }

      // Check if current version is below latest version (optional update)
      if (_isVersionLower(currentVersion, latestVersion)) {
        return UpdateInfo(
          isUpdateAvailable: true,
          isForceUpdate: false,
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          minVersion: minVersion,
          title: updateTitle,
          message: updateMessage,
        );
      }

      return null; // No update available
    } catch (e) {
      print('❌ Error checking for update: $e');
      return null;
    }
  }

  /// Check if update should be shown (considering user dismissals)
  Future<bool> shouldShowUpdate(UpdateInfo updateInfo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // If it's a force update, always show
      if (updateInfo.isForceUpdate) {
        return true;
      }

      // Check if user has dismissed this version
      final dismissedKey = '${_updateDismissedKey}${updateInfo.latestVersion}';
      final isDismissed = prefs.getBool(dismissedKey) ?? false;
      
      if (isDismissed) {
        print('🚫 Update dismissed for version ${updateInfo.latestVersion}');
        return false;
      }

      // Check if enough time has passed since last check
      final lastCheck = prefs.getInt(_lastUpdateCheckKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final timeSinceLastCheck = now - lastCheck;
      
      // Show update if more than 24 hours have passed since last check
      const oneDayInMs = 24 * 60 * 60 * 1000;
      if (timeSinceLastCheck > oneDayInMs) {
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Error checking if should show update: $e');
      return true; // Default to showing update on error
    }
  }

  /// Mark update as dismissed
  Future<void> dismissUpdate(UpdateInfo updateInfo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissedKey = '${_updateDismissedKey}${updateInfo.latestVersion}';
      await prefs.setBool(dismissedKey, true);
      
      // Update last check time
      await prefs.setInt(_lastUpdateCheckKey, DateTime.now().millisecondsSinceEpoch);
      
      print('✅ Update dismissed for version ${updateInfo.latestVersion}');
    } catch (e) {
      print('❌ Error dismissing update: $e');
    }
  }

  /// Launch app store for update
  Future<void> launchAppStore() async {
    try {
      if (_remoteConfig == null) {
        await initialize();
      }

      String storeUrl;
      if (Platform.isAndroid) {
        storeUrl = _remoteConfig!.getString(_playStoreUrlKey);
      } else if (Platform.isIOS) {
        storeUrl = _remoteConfig!.getString(_appStoreUrlKey);
      } else {
        print('❌ Platform not supported for app store launch');
        return;
      }

      final uri = Uri.parse(storeUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('✅ Launched app store: $storeUrl');
      } else {
        print('❌ Could not launch app store: $storeUrl');
      }
    } catch (e) {
      print('❌ Error launching app store: $e');
    }
  }

  /// Compare version strings (e.g., "1.2.3" vs "1.2.4")
  bool _isVersionLower(String current, String required) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final requiredParts = required.split('.').map(int.parse).toList();

      // Pad shorter version with zeros
      while (currentParts.length < requiredParts.length) {
        currentParts.add(0);
      }
      while (requiredParts.length < currentParts.length) {
        requiredParts.add(0);
      }

      for (int i = 0; i < currentParts.length; i++) {
        if (currentParts[i] < requiredParts[i]) {
          return true;
        } else if (currentParts[i] > requiredParts[i]) {
          return false;
        }
      }
      return false; // Versions are equal
    } catch (e) {
      print('❌ Error comparing versions: $e');
      return false;
    }
  }

  /// Force refresh remote config
  Future<void> refreshConfig() async {
    try {
      if (_remoteConfig == null) {
        await initialize();
        return;
      }

      await _remoteConfig!.fetchAndActivate();
      print('✅ Remote config refreshed');
    } catch (e) {
      print('❌ Error refreshing remote config: $e');
    }
  }

  /// Get current app version
  String getCurrentVersion() {
    return _packageInfo?.version ?? 'Unknown';
  }

  /// Get package name
  String getPackageName() {
    return _packageInfo?.packageName ?? 'Unknown';
  }
}

/// Data class for update information
class UpdateInfo {
  final bool isUpdateAvailable;
  final bool isForceUpdate;
  final String currentVersion;
  final String latestVersion;
  final String minVersion;
  final String title;
  final String message;

  UpdateInfo({
    required this.isUpdateAvailable,
    required this.isForceUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.minVersion,
    required this.title,
    required this.message,
  });

  @override
  String toString() {
    return 'UpdateInfo(isUpdateAvailable: $isUpdateAvailable, isForceUpdate: $isForceUpdate, currentVersion: $currentVersion, latestVersion: $latestVersion)';
  }
}
