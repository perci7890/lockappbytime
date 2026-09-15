class LockRecord {
  final int? id;
  final String packageName;
  final String appName;
  final int lockedAt; // Milliseconds since epoch
  final int unlockAt; // Milliseconds since epoch
  final bool enabled;
  final int createdAt; // Milliseconds since epoch
  final String? iconBase64;
  final String lockType; // "temporary", "schedule", "focusMode"
  final String sourceId;
  final int startMinutes; // e.g. 1200 for 20:00
  final int endMinutes;   // e.g. 1320 for 22:00
  final String daysOfWeek; // "all", "weekdays", "weekends", or "2,3,4,5,6"

  LockRecord({
    this.id,
    required this.packageName,
    required this.appName,
    required this.lockedAt,
    required this.unlockAt,
    this.enabled = true,
    required this.createdAt,
    this.iconBase64,
    this.lockType = 'temporary',
    this.sourceId = '',
    this.startMinutes = -1,
    this.endMinutes = -1,
    this.daysOfWeek = '',
  });

  /// Check if the lock is currently active based on system clock
  bool get isCurrentlyLocked {
    if (!enabled) return false;
    final now = DateTime.now();

    if (lockType == 'temporary' || lockType == 'focusMode') {
      return now.millisecondsSinceEpoch < unlockAt;
    }

    if (lockType == 'schedule') {
      return isInsideSchedule(now);
    }

    return false;
  }

  bool isInsideSchedule(DateTime now) {
    if (startMinutes < 0 || endMinutes < 0) return false;
    if (startMinutes == endMinutes) return false;

    // weekday: 1=Mon, 2=Tue... 7=Sun (in Dart)
    final currentDay = now.weekday;
    final currentMinutes = now.hour * 60 + now.minute;
    final isOvernight = endMinutes < startMinutes;

    if (!isOvernight) {
      if (!matchesDay(currentDay)) return false;
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    } else {
      if (currentMinutes >= startMinutes && matchesDay(currentDay)) {
        return true;
      }
      final yesterday = currentDay == 1 ? 7 : currentDay - 1;
      if (currentMinutes < endMinutes && matchesDay(yesterday)) {
        return true;
      }
      return false;
    }
  }

  bool matchesDay(int dartWeekday) {
    // dartWeekday: 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat, 7=Sun
    if (daysOfWeek.isEmpty || daysOfWeek.toLowerCase() == 'all' || daysOfWeek.toLowerCase() == 'everyday') {
      return true;
    }
    if (daysOfWeek.toLowerCase() == 'weekdays') {
      return dartWeekday >= 1 && dartWeekday <= 5;
    }
    if (daysOfWeek.toLowerCase() == 'weekends') {
      return dartWeekday == 6 || dartWeekday == 7;
    }
    // Android Calendar.DAY_OF_WEEK: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
    // Convert dartWeekday to androidDay
    final androidDay = dartWeekday == 7 ? 1 : dartWeekday + 1;
    final parts = daysOfWeek.split(',').map((e) => int.tryParse(e.trim())).whereType<int>();
    return parts.contains(androidDay) || parts.contains(dartWeekday);
  }

  /// Calculates the next unlock timestamp for display
  DateTime get nextUnlockDateTime {
    if (lockType != 'schedule') {
      return DateTime.fromMillisecondsSinceEpoch(unlockAt);
    }
    final now = DateTime.now();
    final currentMins = now.hour * 60 + now.minute;
    var target = DateTime(now.year, now.month, now.day, endMinutes ~/ 60, endMinutes % 60);
    if (endMinutes <= startMinutes && currentMins >= startMinutes) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }

  /// Calculates the exact remaining duration
  Duration get remainingDuration {
    final now = DateTime.now();
    if (lockType == 'schedule') {
      final target = nextUnlockDateTime;
      final diff = target.difference(now);
      return diff.isNegative ? Duration.zero : diff;
    }
    final diff = unlockAt - now.millisecondsSinceEpoch;
    if (diff <= 0) return Duration.zero;
    return Duration(milliseconds: diff);
  }

  DateTime get unlockDateTime => DateTime.fromMillisecondsSinceEpoch(unlockAt);
  DateTime get lockedDateTime => DateTime.fromMillisecondsSinceEpoch(lockedAt);

  static int _parseIntSafely(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  factory LockRecord.fromMap(Map<String, dynamic> map) {
    final rawEnabled = map['enabled'];
    bool isEnabled = true;
    if (rawEnabled is bool) {
      isEnabled = rawEnabled;
    } else if (rawEnabled is num) {
      isEnabled = rawEnabled.toInt() == 1;
    } else if (rawEnabled is String) {
      isEnabled = rawEnabled == '1' || rawEnabled.toLowerCase() == 'true';
    }

    return LockRecord(
      id: map['id'] is num ? (map['id'] as num).toInt() : null,
      packageName: map['packageName']?.toString() ?? '',
      appName: map['appName']?.toString() ?? '',
      lockedAt: _parseIntSafely(map['lockedAt']),
      unlockAt: _parseIntSafely(map['unlockAt']),
      enabled: isEnabled,
      createdAt: _parseIntSafely(map['createdAt']),
      iconBase64: map['iconBase64'] as String?,
      lockType: map['lockType']?.toString() ?? 'temporary',
      sourceId: map['sourceId']?.toString() ?? '',
      startMinutes: _parseIntSafely(map['startMinutes'] ?? -1),
      endMinutes: _parseIntSafely(map['endMinutes'] ?? -1),
      daysOfWeek: map['daysOfWeek']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'packageName': packageName,
      'appName': appName,
      'lockedAt': lockedAt,
      'unlockAt': unlockAt,
      'enabled': enabled ? 1 : 0,
      'createdAt': createdAt,
      'iconBase64': iconBase64,
      'lockType': lockType,
      'sourceId': sourceId,
      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
      'daysOfWeek': daysOfWeek,
    };
  }

  Map<String, dynamic> toNativeMap() {
    return {
      'packageName': packageName,
      'appName': appName,
      'lockedAt': lockedAt,
      'unlockAt': unlockAt,
      'enabled': enabled,
      'lockType': lockType,
      'sourceId': sourceId,
      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
      'daysOfWeek': daysOfWeek,
    };
  }
}
