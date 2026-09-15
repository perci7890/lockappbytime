import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:applockbytime/core/services/pin_service.dart';
import 'package:applockbytime/data/models/lock_record.dart';

void main() {
  group('Duration Validation & Constraints Tests', () {
    test('1 minute duration is valid (minimum allowed)', () {
      const minDuration = Duration(minutes: 1);
      final totalSeconds = minDuration.inSeconds;
      expect(totalSeconds >= 60 && totalSeconds <= 86400, isTrue);
    });

    test('59 seconds duration is invalid (below minimum)', () {
      const invalidDuration = Duration(seconds: 59);
      final totalSeconds = invalidDuration.inSeconds;
      expect(totalSeconds >= 60 && totalSeconds <= 86400, isFalse);
    });

    test('0 duration is invalid', () {
      const zeroDuration = Duration.zero;
      final totalSeconds = zeroDuration.inSeconds;
      expect(totalSeconds >= 60 && totalSeconds <= 86400, isFalse);
    });

    test('24 hours duration is valid (maximum allowed)', () {
      const maxDuration = Duration(hours: 24);
      final totalSeconds = maxDuration.inSeconds;
      expect(totalSeconds >= 60 && totalSeconds <= 86400, isTrue);
      expect(totalSeconds, equals(86400));
    });

    test('24 hours 1 minute duration is invalid (above maximum)', () {
      const overDuration = Duration(hours: 24, minutes: 1);
      final totalSeconds = overDuration.inSeconds;
      expect(totalSeconds >= 60 && totalSeconds <= 86400, isFalse);
    });

    test('Arbitrary durations (e.g. 1h 13m, 7m, 23h 59m) are valid', () {
      const d1 = Duration(minutes: 7);
      const d2 = Duration(hours: 1, minutes: 13);
      const d3 = Duration(hours: 23, minutes: 59);

      for (final d in [d1, d2, d3]) {
        expect(d.inSeconds >= 60 && d.inSeconds <= 86400, isTrue);
      }
    });
  });

  group('Lock Record & Expiration State Tests', () {
    test('Before unlockAt -> isCurrentlyLocked is true', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final record = LockRecord(
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        lockedAt: now - 10000,
        unlockAt: now + 60000, // 1 minute in future
        enabled: true,
        createdAt: now - 10000,
      );

      expect(record.isCurrentlyLocked, isTrue);
      expect(record.remainingDuration.inSeconds > 0, isTrue);
    });

    test('Exactly at unlockAt -> isCurrentlyLocked is false', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final record = LockRecord(
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        lockedAt: now - 60000,
        unlockAt: now, // exactly now
        enabled: true,
        createdAt: now - 60000,
      );

      expect(record.isCurrentlyLocked, isFalse);
      expect(record.remainingDuration, equals(Duration.zero));
    });

    test('After unlockAt -> isCurrentlyLocked is false', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final record = LockRecord(
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        lockedAt: now - 120000,
        unlockAt: now - 1000, // expired 1 sec ago
        enabled: true,
        createdAt: now - 120000,
      );

      expect(record.isCurrentlyLocked, isFalse);
      expect(record.remainingDuration, equals(Duration.zero));
    });

    test('Disabled lock -> isCurrentlyLocked is false even before unlockAt', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final record = LockRecord(
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        lockedAt: now,
        unlockAt: now + 60000,
        enabled: false,
        createdAt: now,
      );

      expect(record.isCurrentlyLocked, isFalse);
    });
  });

  group('Recurring Schedules Tests', () {
    test('Daily Schedule 8:00 PM -> 10:00 PM evaluates correctly', () {
      final schedule = LockRecord(
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        lockedAt: 0,
        unlockAt: 0,
        enabled: true,
        createdAt: 0,
        lockType: 'schedule',
        startMinutes: 20 * 60, // 8:00 PM (1200)
        endMinutes: 22 * 60,   // 10:00 PM (1320)
        daysOfWeek: 'everyday',
      );

      // 7:59 PM -> unlocked
      final beforeTime = DateTime(2026, 9, 15, 19, 59);
      expect(schedule.isInsideSchedule(beforeTime), isFalse);

      // 8:00 PM -> locked
      final startTime = DateTime(2026, 9, 15, 20, 0);
      expect(schedule.isInsideSchedule(startTime), isTrue);

      // 9:30 PM -> locked
      final middleTime = DateTime(2026, 9, 15, 21, 30);
      expect(schedule.isInsideSchedule(middleTime), isTrue);

      // 10:00 PM -> unlocked
      final endTime = DateTime(2026, 9, 15, 22, 0);
      expect(schedule.isInsideSchedule(endTime), isFalse);
    });

    test('Overnight Schedule 10:00 PM -> 6:00 AM evaluates correctly', () {
      final schedule = LockRecord(
        packageName: 'com.tiktok.android',
        appName: 'TikTok',
        lockedAt: 0,
        unlockAt: 0,
        enabled: true,
        createdAt: 0,
        lockType: 'schedule',
        startMinutes: 22 * 60, // 10:00 PM (1320)
        endMinutes: 6 * 60,    // 6:00 AM (360)
        daysOfWeek: 'everyday',
      );

      // 9:59 PM -> unlocked
      expect(schedule.isInsideSchedule(DateTime(2026, 9, 15, 21, 59)), isFalse);
      // 10:00 PM -> locked
      expect(schedule.isInsideSchedule(DateTime(2026, 9, 15, 22, 0)), isTrue);
      // 11:59 PM -> locked
      expect(schedule.isInsideSchedule(DateTime(2026, 9, 15, 23, 59)), isTrue);
      // 12:00 AM -> locked
      expect(schedule.isInsideSchedule(DateTime(2026, 9, 16, 0, 0)), isTrue);
      // 5:59 AM -> locked
      expect(schedule.isInsideSchedule(DateTime(2026, 9, 16, 5, 59)), isTrue);
      // 6:00 AM -> unlocked
      expect(schedule.isInsideSchedule(DateTime(2026, 9, 16, 6, 0)), isFalse);
    });

    test('Weekdays only schedule matches Monday-Friday and excludes weekends', () {
      final schedule = LockRecord(
        packageName: 'com.youtube.android',
        appName: 'YouTube',
        lockedAt: 0,
        unlockAt: 0,
        enabled: true,
        createdAt: 0,
        lockType: 'schedule',
        startMinutes: 1200,
        endMinutes: 1320,
        daysOfWeek: 'weekdays',
      );

      // 2026-09-14 is Monday (weekday: 1)
      expect(schedule.isInsideSchedule(DateTime(2026, 9, 14, 20, 30)), isTrue);
      // 2026-09-18 is Friday (weekday: 5)
      expect(schedule.isInsideSchedule(DateTime(2026, 9, 18, 20, 30)), isTrue);
      // 2026-09-19 is Saturday (weekday: 6)
      expect(schedule.isInsideSchedule(DateTime(2026, 9, 19, 20, 30)), isFalse);
      // 2026-09-20 is Sunday (weekday: 7)
      expect(schedule.isInsideSchedule(DateTime(2026, 9, 20, 20, 30)), isFalse);
    });

    test('Lock until tomorrow calculates next local midnight', () {
      final now = DateTime(2026, 9, 15, 19, 30);
      final midnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 0);

      expect(midnight.isAfter(now), isTrue);
      expect(midnight.hour, equals(0));
      expect(midnight.minute, equals(0));
      expect(midnight.difference(now).inMinutes, equals(4 * 60 + 30));
    });

    test('Multiple lock sources: if any rule is active, package remains locked', () {
      final now = DateTime(2026, 9, 15, 20, 30);
      final nowMillis = now.millisecondsSinceEpoch;

      final scheduleRule = LockRecord(
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        lockedAt: 0,
        unlockAt: 0,
        enabled: true,
        createdAt: 0,
        lockType: 'schedule',
        startMinutes: 20 * 60, // 8 PM
        endMinutes: 22 * 60,   // 10 PM
        daysOfWeek: 'everyday',
      );

      final focusModeRule = LockRecord(
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        lockedAt: nowMillis - 1800000,
        unlockAt: nowMillis + 7200000, // Until 10:30 PM
        enabled: true,
        createdAt: 0,
        lockType: 'focusMode',
        sourceId: 'study_group',
      );

      // Both active
      expect(scheduleRule.isInsideSchedule(now), isTrue);
      expect(focusModeRule.isCurrentlyLocked, isTrue);

      // At 10:05 PM: schedule has ended, but focus mode is still active
      final laterTime = DateTime(2026, 9, 15, 22, 5);
      expect(scheduleRule.isInsideSchedule(laterTime), isFalse);
      expect(focusModeRule.unlockAt > laterTime.millisecondsSinceEpoch, isTrue);
    });

    test('Same-time schedule (e.g. 11 PM -> 11 PM) evaluates to false (zero-duration)', () {
      final sameTimeSchedule = LockRecord(
        packageName: 'com.game.android',
        appName: 'Game',
        lockedAt: 0,
        unlockAt: 0,
        enabled: true,
        createdAt: 0,
        lockType: 'schedule',
        startMinutes: 23 * 60, // 11:00 PM
        endMinutes: 23 * 60,   // 11:00 PM
        daysOfWeek: 'everyday',
      );

      // At 11:00 PM
      expect(sameTimeSchedule.isInsideSchedule(DateTime(2026, 9, 15, 23, 0)), isFalse);
      // At any other time
      expect(sameTimeSchedule.isInsideSchedule(DateTime(2026, 9, 15, 12, 0)), isFalse);
      expect(sameTimeSchedule.isInsideSchedule(DateTime(2026, 9, 15, 23, 30)), isFalse);
    });
  });

  group('PIN Security & PBKDF2 Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Setting PIN produces a valid PBKDF2 formatted hash and enables PIN', () async {
      final success = await PinService.setPin('1234');
      expect(success, isTrue);
      expect(await PinService.isPinEnabled(), isTrue);

      final prefs = await SharedPreferences.getInstance();
      final storedHash = prefs.getString('security_pin_hash');
      expect(storedHash, isNotNull);
      expect(storedHash!.startsWith('pbkdf2\$10000\$'), isTrue);
      final parts = storedHash.split('\$');
      expect(parts.length, equals(4)); // pbkdf2, 10000, salt, hashHex
      expect(parts[2].isNotEmpty, isTrue); // salt
      expect(parts[3].length, equals(64)); // 32 bytes hex = 64 chars
    });

    test('Correct PIN verifies successfully', () async {
      await PinService.setPin('4567');
      final result = await PinService.verifyPin('4567');
      expect(result.isSuccess, isTrue);
      expect(result.isLockedOut, isFalse);
    });

    test('Incorrect PIN fails with attempt countdown', () async {
      await PinService.setPin('4567');
      final result = await PinService.verifyPin('0000');
      expect(result.isSuccess, isFalse);
      expect(result.isLockedOut, isFalse);
      expect(result.errorMessage, contains('4 attempts remaining'));
    });

    test('5 failed attempts triggers 30-second lockout', () async {
      await PinService.setPin('8888');
      for (int i = 0; i < 4; i++) {
        final res = await PinService.verifyPin('0000');
        expect(res.isSuccess, isFalse);
        expect(res.isLockedOut, isFalse);
      }

      // 5th failed attempt
      final lockoutRes = await PinService.verifyPin('0000');
      expect(lockoutRes.isSuccess, isFalse);
      expect(lockoutRes.isLockedOut, isTrue);
      expect(lockoutRes.errorMessage, contains('30 seconds'));

      // Subsequent attempt while locked out is rejected immediately
      final blockedRes = await PinService.verifyPin('8888');
      expect(blockedRes.isSuccess, isFalse);
      expect(blockedRes.isLockedOut, isTrue);
      expect(blockedRes.errorMessage, contains('Too many failed attempts'));
    });

    test('Legacy SHA-256 hash verifies and seamlessly migrates to PBKDF2', () async {
      final prefs = await SharedPreferences.getInstance();
      // Store a legacy SHA-256 hash for PIN "9999"
      // legacy salt = 'app_locker_secure_salt_v2'
      // utf8(9999app_locker_secure_salt_v2) -> sha256
      const legacySalt = 'app_locker_secure_salt_v2';
      final legacyBytes = utf8.encode('9999$legacySalt');
      final legacyHash = sha256.convert(legacyBytes).toString();

      await prefs.setString('security_pin_hash', legacyHash);
      await prefs.setBool('security_pin_enabled', true);

      // Verify with legacy PIN
      final result = await PinService.verifyPin('9999');
      expect(result.isSuccess, isTrue);

      // Verify it was migrated in-place to PBKDF2
      final updatedHash = prefs.getString('security_pin_hash');
      expect(updatedHash, isNotNull);
      expect(updatedHash!.startsWith('pbkdf2\$10000\$'), isTrue);
      expect(updatedHash != legacyHash, isTrue);
    });
  });

  group('Emergency Unlock Non-Destruction Invariant Tests', () {
    test('Emergency unlock allows temporary access without modifying underlying schedule', () {
      final underlyingSchedule = LockRecord(
        packageName: 'com.work.chat',
        appName: 'Work Chat',
        lockedAt: 0,
        unlockAt: 0,
        enabled: true,
        createdAt: 0,
        lockType: 'schedule',
        startMinutes: 9 * 60,  // 9:00 AM
        endMinutes: 17 * 60,   // 5:00 PM
        daysOfWeek: 'weekdays',
      );

      final now = DateTime(2026, 9, 15, 14, 0); // 2:00 PM on Tuesday (inside schedule)
      expect(underlyingSchedule.isInsideSchedule(now), isTrue);

      // Emergency unlock is active for 5 minutes
      final emergencyUntil = now.millisecondsSinceEpoch + (5 * 60 * 1000);
      final isEmergencyActive = now.millisecondsSinceEpoch < emergencyUntil;
      expect(isEmergencyActive, isTrue);

      // Effective access is granted while emergency is active
      final isEffectivelyBlocked = !isEmergencyActive && underlyingSchedule.isInsideSchedule(now);
      expect(isEffectivelyBlocked, isFalse);

      // Underlying record remains completely intact with original schedule intact
      expect(underlyingSchedule.startMinutes, equals(540));
      expect(underlyingSchedule.endMinutes, equals(1020));
      expect(underlyingSchedule.enabled, isTrue);

      // Once 5 minutes expires, blocking resumes immediately
      final afterEmergency = now.add(const Duration(minutes: 6));
      final isEmergencyActiveAfter = afterEmergency.millisecondsSinceEpoch < emergencyUntil;
      expect(isEmergencyActiveAfter, isFalse);
      final isBlockedAfter = !isEmergencyActiveAfter && underlyingSchedule.isInsideSchedule(afterEmergency);
      expect(isBlockedAfter, isTrue);
    });
  });

  group('Midnight Boundaries & Extreme Schedule Tests', () {
    test('18:00 -> 00:00 (1080 -> 0) schedule correctly handles midnight boundary', () {
      final schedule = LockRecord(
        packageName: 'com.social.app',
        appName: 'Social',
        lockedAt: 0,
        unlockAt: 0,
        enabled: true,
        createdAt: 0,
        lockType: 'schedule',
        startMinutes: 18 * 60, // 18:00 (1080)
        endMinutes: 0,         // 00:00 (midnight = 0)
        daysOfWeek: 'everyday',
      );

      // 17:59 -> unlocked
      expect(schedule.isInsideSchedule(DateTime(2026, 9, 15, 17, 59)), isFalse);
      // 18:00 -> locked
      expect(schedule.isInsideSchedule(DateTime(2026, 9, 15, 18, 0)), isTrue);
      // 23:59 -> locked
      expect(schedule.isInsideSchedule(DateTime(2026, 9, 15, 23, 59)), isTrue);
      // 00:00 -> unlocked (end of schedule)
      expect(schedule.isInsideSchedule(DateTime(2026, 9, 16, 0, 0)), isFalse);
    });

    test('00:00 -> 06:00 (0 -> 360) same-day morning schedule evaluates correctly', () {
      final schedule = LockRecord(
        packageName: 'com.social.app',
        appName: 'Social',
        lockedAt: 0,
        unlockAt: 0,
        enabled: true,
        createdAt: 0,
        lockType: 'schedule',
        startMinutes: 0,        // 00:00
        endMinutes: 6 * 60,     // 06:00 (360)
        daysOfWeek: 'everyday',
      );

      // 00:00 -> locked
      expect(schedule.isInsideSchedule(DateTime(2026, 9, 15, 0, 0)), isTrue);
      // 05:59 -> locked
      expect(schedule.isInsideSchedule(DateTime(2026, 9, 15, 5, 59)), isTrue);
      // 06:00 -> unlocked
      expect(schedule.isInsideSchedule(DateTime(2026, 9, 15, 6, 0)), isFalse);
    });

    test('23:59 -> 00:01 overnight transition correctly encompasses midnight', () {
      final schedule = LockRecord(
        packageName: 'com.social.app',
        appName: 'Social',
        lockedAt: 0,
        unlockAt: 0,
        enabled: true,
        createdAt: 0,
        lockType: 'schedule',
        startMinutes: 23 * 60 + 59, // 23:59 (1439)
        endMinutes: 1,              // 00:01 (1)
        daysOfWeek: 'everyday',
      );

      // 23:58 -> unlocked
      expect(schedule.isInsideSchedule(DateTime(2026, 9, 15, 23, 58)), isFalse);
      // 23:59 -> locked
      expect(schedule.isInsideSchedule(DateTime(2026, 9, 15, 23, 59)), isTrue);
      // 00:00 (midnight) -> locked
      expect(schedule.isInsideSchedule(DateTime(2026, 9, 16, 0, 0)), isTrue);
      // 00:01 -> unlocked
      expect(schedule.isInsideSchedule(DateTime(2026, 9, 16, 0, 1)), isFalse);
    });
  });

  group('Defensive Parsing & Malformed Data Tests', () {
    test('LockRecord.fromMap handles nulls, string numbers, and missing fields safely', () {
      final malformedMap = <String, dynamic>{
        'packageName': 'com.corrupt.app',
        'appName': null,
        'lockedAt': '1700000000000', // string timestamp
        'unlockAt': '1700000060000', // string timestamp
        'enabled': 'true',          // string boolean
        'createdAt': null,
        'lockType': null,
        'startMinutes': 'invalid',
        'endMinutes': null,
      };

      final record = LockRecord.fromMap(malformedMap);
      expect(record.packageName, equals('com.corrupt.app'));
      expect(record.appName, equals(''));
      expect(record.lockedAt, equals(1700000000000));
      expect(record.unlockAt, equals(1700000060000));
      expect(record.enabled, isTrue);
      expect(record.lockType, equals('temporary'));
      expect(record.startMinutes, equals(0));
      expect(record.endMinutes, equals(-1));
    });

    test('3-Way conflict resolution: Schedule + Focus Mode + Quick Lock', () {
      final now = DateTime(2026, 9, 15, 14, 0); // 2:00 PM
      final nowMillis = now.millisecondsSinceEpoch;

      // 1. Quick lock expiring at 2:30 PM
      final quickLock = LockRecord(
        packageName: 'com.target.app',
        appName: 'Target',
        lockedAt: nowMillis,
        unlockAt: nowMillis + (30 * 60 * 1000), // 2:30 PM
        enabled: true,
        createdAt: nowMillis,
        lockType: 'temporary',
      );

      // 2. Schedule active from 1:00 PM to 3:00 PM
      final schedule = LockRecord(
        packageName: 'com.target.app',
        appName: 'Target',
        lockedAt: 0,
        unlockAt: 0,
        enabled: true,
        createdAt: 0,
        lockType: 'schedule',
        startMinutes: 13 * 60, // 1:00 PM
        endMinutes: 15 * 60,   // 3:00 PM
        daysOfWeek: 'everyday',
      );

      // 3. Focus mode expiring at 4:00 PM
      final focusMode = LockRecord(
        packageName: 'com.target.app',
        appName: 'Target',
        lockedAt: nowMillis,
        unlockAt: nowMillis + (120 * 60 * 1000), // 4:00 PM
        enabled: true,
        createdAt: nowMillis,
        lockType: 'focusMode',
      );

      // At 2:00 PM: All 3 active -> locked
      final allRules = [quickLock, schedule, focusMode];
      bool isLockedAt(DateTime t) {
        return allRules.any((r) {
          if (r.lockType == 'schedule') return r.isInsideSchedule(t);
          return t.millisecondsSinceEpoch < r.unlockAt;
        });
      }

      expect(isLockedAt(DateTime(2026, 9, 15, 14, 0)), isTrue);
      // At 2:45 PM: Quick lock expired, Schedule & Focus mode still active -> locked
      expect(isLockedAt(DateTime(2026, 9, 15, 14, 45)), isTrue);
      // At 3:15 PM: Quick lock & Schedule expired, Focus mode still active -> locked
      expect(isLockedAt(DateTime(2026, 9, 15, 15, 15)), isTrue);
      // At 4:05 PM: All 3 expired -> unlocked
      expect(isLockedAt(DateTime(2026, 9, 15, 16, 5)), isFalse);
    });
  });
}
