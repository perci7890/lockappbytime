import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:applockbytime/core/services/native_bridge_service.dart';
import 'package:applockbytime/data/models/app_info.dart';
import 'package:applockbytime/data/models/lock_record.dart';
import 'package:applockbytime/data/repositories/lock_repository.dart';

class LockProvider with ChangeNotifier {
  final LockRepository _repository = LockRepository();

  List<LockRecord> _activeLocks = [];
  List<LockRecord> _allSchedules = [];
  List<Map<String, dynamic>> _focusModes = [];
  List<AppInfo> _installedApps = [];
  bool _isLoadingApps = false;
  bool _isAccessibilityEnabled = false;
  Timer? _countdownTimer;

  List<LockRecord> get activeLocks => _activeLocks;
  List<LockRecord> get allSchedules => _allSchedules;
  List<Map<String, dynamic>> get focusModes => _focusModes;
  List<AppInfo> get installedApps => _installedApps;
  bool get isLoadingApps => _isLoadingApps;
  bool get isAccessibilityEnabled => _isAccessibilityEnabled;

  LockProvider() {
    _startCountdownTicker();
    refreshAll();
  }

  void _startCountdownTicker() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_activeLocks.isEmpty && _allSchedules.isEmpty) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final hadExpired = _activeLocks.any((lock) => lock.lockType != 'schedule' && now >= lock.unlockAt);
      if (hadExpired) {
        loadActiveLocks();
      } else {
        notifyListeners();
      }
    });
  }

  Future<void> refreshAll() async {
    await checkAccessibilityPermission();
    await loadActiveLocks();
    await loadSchedules();
    await loadFocusModes();
  }

  Future<void> checkAccessibilityPermission() async {
    _isAccessibilityEnabled =
        await NativeBridgeService.isAccessibilityServiceEnabled();
    notifyListeners();
  }

  Future<void> openAccessibilitySettings() async {
    await NativeBridgeService.openAccessibilitySettings();
  }

  Future<void> loadActiveLocks() async {
    _activeLocks = await _repository.getActiveLocks();
    notifyListeners();
  }

  Future<void> loadSchedules() async {
    _allSchedules = await _repository.getSchedules();
    notifyListeners();
  }

  Future<void> loadFocusModes() async {
    _focusModes = await _repository.getFocusModes();
    notifyListeners();
  }

  Future<void> loadInstalledApps() async {
    if (_installedApps.isNotEmpty) return;
    _isLoadingApps = true;
    notifyListeners();

    try {
      _installedApps = await NativeBridgeService.getInstalledApps();
    } catch (e) {
      _installedApps = [];
    } finally {
      _isLoadingApps = false;
      notifyListeners();
    }
  }

  /// Lock app for a temporary duration (1m - 24h)
  Future<void> lockApp({
    required AppInfo app,
    required Duration duration,
    String lockType = 'temporary',
    String sourceId = '',
  }) async {
    final now = DateTime.now();
    final unlockAt = now.add(duration);

    final lock = LockRecord(
      packageName: app.packageName,
      appName: app.appName,
      lockedAt: now.millisecondsSinceEpoch,
      unlockAt: unlockAt.millisecondsSinceEpoch,
      enabled: true,
      createdAt: now.millisecondsSinceEpoch,
      iconBase64: app.iconBase64,
      lockType: lockType,
      sourceId: sourceId,
    );

    await _repository.saveLock(lock);
    await refreshAll();
  }

  /// Lock app until tomorrow midnight
  Future<void> lockUntilTomorrow({required AppInfo app}) async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 0);
    final duration = midnight.difference(now);

    await lockApp(app: app, duration: duration);
  }

  /// Save or update a recurring schedule
  Future<void> saveSchedule({
    required AppInfo app,
    required int startMinutes,
    required int endMinutes,
    required String daysOfWeek,
    bool enabled = true,
  }) async {
    final now = DateTime.now();
    final lock = LockRecord(
      packageName: app.packageName,
      appName: app.appName,
      lockedAt: now.millisecondsSinceEpoch,
      unlockAt: 0,
      enabled: enabled,
      createdAt: now.millisecondsSinceEpoch,
      iconBase64: app.iconBase64,
      lockType: 'schedule',
      sourceId: 'schedule_${app.packageName}',
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      daysOfWeek: daysOfWeek,
    );

    await _repository.saveLock(lock);
    await refreshAll();
  }

  Future<void> deleteSchedule(String packageName, {String? sourceId}) async {
    await _repository.removeLock(packageName, lockType: 'schedule', sourceId: sourceId);
    await refreshAll();
  }

  Future<void> unlockEarly(String packageName, {String? lockType, String? sourceId}) async {
    await _repository.removeLock(packageName, lockType: lockType, sourceId: sourceId);
    await refreshAll();
  }

  /// 5-minute emergency unlock
  Future<void> triggerEmergencyUnlock(String packageName) async {
    await NativeBridgeService.setEmergencyUnlock(packageName);
    await refreshAll();
  }

  // Focus Modes
  Future<void> createFocusMode({
    required String id,
    required String name,
    required String icon,
    required List<String> packageNames,
    required int durationMinutes,
    int startMinutes = -1,
    int endMinutes = -1,
    String daysOfWeek = '',
  }) async {
    final map = {
      'id': id,
      'name': name,
      'icon': icon,
      'packageNames': packageNames.join(','),
      'durationMinutes': durationMinutes,
      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
      'daysOfWeek': daysOfWeek,
      'isActive': 0,
      'unlockAt': 0,
    };
    await _repository.saveFocusMode(map);
    await loadFocusModes();
  }

  Future<void> startFocusMode(String focusModeId) async {
    final mode = _focusModes.firstWhere((m) => m['id'] == focusModeId);
    final durationMins = mode['durationMinutes'] as int? ?? 60;
    final packageNames = (mode['packageNames'] as String).split(',').map((e) => e.trim()).toList();
    final now = DateTime.now();
    final unlockAt = now.add(Duration(minutes: durationMins));

    for (final pkg in packageNames) {
      if (pkg.isEmpty) continue;
      final app = _installedApps.firstWhere(
        (a) => a.packageName == pkg,
        orElse: () => AppInfo(packageName: pkg, appName: pkg, iconBase64: '', isSystemApp: false),
      );

      final lock = LockRecord(
        packageName: pkg,
        appName: app.appName,
        lockedAt: now.millisecondsSinceEpoch,
        unlockAt: unlockAt.millisecondsSinceEpoch,
        enabled: true,
        createdAt: now.millisecondsSinceEpoch,
        iconBase64: app.iconBase64,
        lockType: 'focusMode',
        sourceId: focusModeId,
      );
      await _repository.saveLock(lock);
    }

    final updated = Map<String, dynamic>.from(mode);
    updated['isActive'] = 1;
    updated['unlockAt'] = unlockAt.millisecondsSinceEpoch;
    await _repository.saveFocusMode(updated);
    await refreshAll();
  }

  Future<void> stopFocusMode(String focusModeId) async {
    final mode = _focusModes.firstWhere((m) => m['id'] == focusModeId);
    final packageNames = (mode['packageNames'] as String).split(',').map((e) => e.trim()).toList();

    for (final pkg in packageNames) {
      if (pkg.isEmpty) continue;
      await _repository.removeLock(pkg, lockType: 'focusMode', sourceId: focusModeId);
    }

    final updated = Map<String, dynamic>.from(mode);
    updated['isActive'] = 0;
    updated['unlockAt'] = 0;
    await _repository.saveFocusMode(updated);
    await refreshAll();
  }

  Future<void> deleteFocusMode(String focusModeId) async {
    await stopFocusMode(focusModeId);
    await _repository.deleteFocusMode(focusModeId);
    await loadFocusModes();
  }

  bool isAppLocked(String packageName) {
    return _activeLocks.any((l) => l.packageName == packageName && l.isCurrentlyLocked);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}
