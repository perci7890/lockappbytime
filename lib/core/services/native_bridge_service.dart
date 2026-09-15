import 'package:flutter/services.dart';
import 'package:applockbytime/data/models/app_info.dart';
import 'package:applockbytime/data/models/lock_record.dart';

class NativeBridgeService {
  static const MethodChannel _channel =
      MethodChannel('com.example.applockbytime/app_lock');

  /// Check if the Accessibility Service is enabled in Android settings
  static Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final bool? isEnabled =
          await _channel.invokeMethod<bool>('isAccessibilityServiceEnabled');
      return isEnabled ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Direct the user to the Accessibility Settings page
  static Future<bool> openAccessibilitySettings() async {
    try {
      final bool? result =
          await _channel.invokeMethod<bool>('openAccessibilitySettings');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Check if overlay permission is granted
  static Future<bool> canDrawOverlays() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('canDrawOverlays');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Open Android Overlay permission settings
  static Future<bool> openOverlaySettings() async {
    try {
      final bool? result =
          await _channel.invokeMethod<bool>('openOverlaySettings');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Check if Usage Stats permission is granted
  static Future<bool> hasUsageStatsPermission() async {
    try {
      final bool? result =
          await _channel.invokeMethod<bool>('hasUsageStatsPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Open Android Usage Access settings
  static Future<bool> openUsageAccessSettings() async {
    try {
      final bool? result =
          await _channel.invokeMethod<bool>('openUsageAccessSettings');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Query Android UsageStatsManager
  static Future<List<Map<String, dynamic>>> getUsageStats({int days = 0}) async {
    try {
      final List<dynamic>? stats =
          await _channel.invokeMethod<List<dynamic>>('getUsageStats', {'days': days});
      if (stats == null) return [];
      return stats.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } on PlatformException {
      return [];
    }
  }

  /// Set 5-minute emergency unlock natively
  static Future<bool> setEmergencyUnlock(String packageName, {int durationMillis = 300000}) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('setEmergencyUnlock', {
        'packageName': packageName,
        'durationMillis': durationMillis,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Check emergency unlock status
  static Future<bool> isEmergencyUnlocked(String packageName) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>(
        'isEmergencyUnlocked',
        {'packageName': packageName},
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Retrieve installed launchable applications with their icons
  static Future<List<AppInfo>> getInstalledApps() async {
    try {
      final List<dynamic>? apps =
          await _channel.invokeMethod<List<dynamic>>('getInstalledApps');
      if (apps == null) return [];
      return apps
          .map((item) => AppInfo.fromMap(item as Map<dynamic, dynamic>))
          .toList();
    } on PlatformException {
      return [];
    }
  }

  /// Sync active lock record to native Android LockStorage
  static Future<bool> saveLockNative(LockRecord lock) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>(
        'saveLockNative',
        lock.toNativeMap(),
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Remove lock from native Android LockStorage
  static Future<bool> removeLockNative(String packageName, {String? lockType, String? sourceId}) async {
    try {
      final Map<String, dynamic> args = {'packageName': packageName};
      if (lockType != null) args['lockType'] = lockType;
      if (sourceId != null) args['sourceId'] = sourceId;

      final bool? result = await _channel.invokeMethod<bool>('removeLockNative', args);
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Get native locks list from Android SharedPreferences
  static Future<List<Map<dynamic, dynamic>>> getActiveLocksNative() async {
    try {
      final List<dynamic>? locks =
          await _channel.invokeMethod<List<dynamic>>('getActiveLocksNative');
      if (locks == null) return [];
      return locks.cast<Map<dynamic, dynamic>>();
    } on PlatformException {
      return [];
    }
  }

  /// Fetch native runtime diagnostic telemetry
  static Future<Map<String, dynamic>> getDiagnostics() async {
    try {
      final Map<dynamic, dynamic>? result =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getDiagnostics');
      if (result == null) return {};
      return Map<String, dynamic>.from(result);
    } on PlatformException {
      return {};
    }
  }
}
