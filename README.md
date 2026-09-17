# FocusLock (Android & Flutter)

A production-quality Android-first Flutter application that allows users to strictly lock apps for user-defined durations (**1 minute to 24 hours**), schedule **recurring daily and weekday locks**, activate **overnight restrictions**, initiate **Focus Modes / App Groups**, view device **Usage Statistics**, and protect unlock operations with **Secure PIN Verification**.

---

## 🎯 Architecture Overview & Advanced Engine

```
┌────────────────────────────────────────────────────────────────────────┐
│                          Flutter Dart UI                               │
│  - HomeScreen (Dashboard: Active Now, Schedules, Focus Modes)          │
│  - AppSelectionScreen (Search, filter, duplicate lock protection)      │
│  - AppDurationScreen (Quick Lock, Lock Until Tomorrow, Schedules)      │
│  - FocusModesScreen (App grouping: Study, Sleep, Work)                 │
│  - UsageStatsScreen (Android UsageStatsManager dashboard)              │
│  - PinService & PinEntryDialog (SHA-256 secure PIN & rate limiting)    │
│  - SQLite Database (v2 schema with schedules & focus groups)           │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ MethodChannel
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        Native Android Layer                            │
│  - MainActivity (MethodChannel, UsageStats, Apps & Diagnostics)       │
│  - AppLockAccessibilityService (Event-driven, debounce, sys-whitelist) │
│  - LockScreenActivity (Native blocking UI & Emergency 5-min button)    │
│  - BootReceiver (BOOT_COMPLETED & QUICKBOOT_POWERON survival)          │
│  - PackageChangeReceiver (PACKAGE_FULLY_REMOVED cleanup)               │
│  - LockStorage (Centralized multi-source rule evaluation engine)       │
│  - Dual Clock Enforcement (Absolute Wall-Clock + Monotonic Deadline)   │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Advanced Features Implemented

### 1. Recurring Daily & Weekday Schedules
* **Daily (e.g. 8:00 PM → 10:00 PM)** and **Weekdays only (Monday–Friday)**.
* **Custom Days**: Pick arbitrary combinations (e.g. Mon, Wed, Fri).
* **Local Device Time**: Evaluated using Android's `Calendar` against local device time—immune to timezone or daylight saving drifts.
* **Zero Polling Loops**: Evaluated instantaneously on foreground window change events.

### 2. Overnight Schedules (Crossing Midnight)
* Correctly handles schedules where `endMinutes <= startMinutes` (e.g. 10:00 PM to 6:00 AM).
* Evening hours (≥ 10:00 PM) match today's rule; morning hours (< 6:00 AM) match yesterday's rule.

### 3. Lock Until Tomorrow
* One-touch action calculating the exact duration from the current moment until the next local calendar midnight (12:00 AM).

### 4. 5-Minute Emergency Unlock
* Native blocking screen includes an **"⚡ Emergency 5 min"** button.
* Temporarily suppresses enforcement for 5 minutes (`emergencyUnlockUntil = now + 5 min`).
* **Does NOT destroy original lock**: Once 5 minutes pass, the original schedule or temporary lock immediately resumes.

### 5. PIN Protection & Security (PBKDF2-HMAC-SHA256)
* **PBKDF2-HMAC-SHA256**: 10,000 iterations with a cryptographically secure 16-byte random salt generated per-installation via `Random.secure()`.
* **Constant-Time Comparison**: Mitigates timing side-channel attacks during PIN verification.
* **Transparent Hash Migration**: Seamlessly upgrades legacy SHA-256 hashes to PBKDF2 upon first successful entry without user disruption.
* **Persistent Rate Limiting**: 5 consecutive failed attempts trigger a 30-second lockout; attempts and lockout deadlines persist in `SharedPreferences`.
* Protects early unlock, schedule deletion, disabling PIN, and optionally emergency unlock.

### 6. Usage Statistics Dashboard
* Queries Android's native `UsageStatsManager` for **Today**, **Yesterday**, and **Past 7 Days**.
* Displays total screen time and individual foreground app breakdown.
* Fully on-device: 100% private with no external server transmission.

### 7. Focus Modes & App Groups
* Create customized focus groups (e.g., 📚 Study, 🌙 Sleep, 💼 Work).
* Batch lock multiple distracting apps simultaneously with a single tap.
* **Conflict-Aware Resolution**: If an app is governed by multiple lock sources (e.g., Daily Schedule 8–10 PM + Study Focus 7–11 PM), it remains blocked until **all** applicable active sources expire.

---

## 🛡️ Edge Cases & Production Hardening Handled

1. **Same-Time Schedule Edge Case (`startMinutes == endMinutes`)**:
   - Explicitly handled in native `LockStorage.kt`, `lock_record.dart`, and UI validation. Evaluates to `false` (inactive/0-duration), preventing accidental 24/7 lockouts.
2. **Clock Tampering & Monotonic Protection**:
   - Combines wall-clock epoch timestamp with `SystemClock.elapsedRealtime()` deadline. Reboots reset monotonic reference safely to wall-clock timestamps.
3. **Emergency Unlock Non-Destruction Invariant**:
   - 5-minute override evaluates first in `LockStorage.isPackageLocked()`; underlying temporary locks and schedules remain intact in SQLite and SharedPreferences. Once 5 minutes elapse, enforcement automatically resumes.
4. **Auto-Dismiss on Expiration**:
   - `LockScreenActivity` verifies active lock state on every timer tick. If the lock window expires or emergency unlock is granted, the activity immediately calls `finish()` rather than getting stuck on `00:00:00`.
5. **Debounce & System Whitelisting**:
   - 800ms debounce prevents activity launch thrashing. System components (`com.android.systemui`, `com.android.settings`, keyboards, input methods) are whitelisted to prevent soft-brick loops.

---

## 🛠️ Android Permissions & Setup

| Permission | Purpose |
| :--- | :--- |
| `BIND_ACCESSIBILITY_SERVICE` | Required by `AppLockAccessibilityService` to detect foreground apps. |
| `PACKAGE_USAGE_STATS` | Used by `UsageStatsManager` to display screen time statistics. |
| `RECEIVE_BOOT_COMPLETED` | Preserves all lock rules and schedules across device reboots. |
| `QUERY_ALL_PACKAGES` | Discovers user-installed launchable applications. |
| `SYSTEM_ALERT_WINDOW` | Ensures reliable overlay and lock activity display. |

---

## 📋 Comprehensive Verification Checklist

- [x] **Quick Lock (1m – 24h)**: Boundary validation & arbitrary durations passed.
- [x] **Recurring Daily Schedule**: 8:00 PM → 10:00 PM locked inside, unlocked outside.
- [x] **Overnight Schedule**: 10:00 PM → 6:00 AM verified across midnight.
- [x] **Same-Time Edge Case**: 11:00 PM → 11:00 PM verified as 0-duration (no lockout).
- [x] **Weekdays Schedule**: Monday–Friday locked; Saturday–Sunday unlocked.
- [x] **Lock Until Tomorrow**: Accurately calculates local midnight.
- [x] **5-Minute Emergency Unlock**: Suspends enforcement without deleting underlying lock.
- [x] **Multi-Source Conflict Resolution**: App remains locked until all active rules clear.
- [x] **PIN Security**: PBKDF2-HMAC-SHA256 (10,000 iter), random salt, constant-time compare, 30s lockout after 5 attempts.
- [x] **Legacy PIN Migration**: Transparently migrates older hashes to PBKDF2 format.
- [x] **Usage Statistics**: Integrated with `UsageStatsManager`.
- [x] **Focus Modes**: App grouping & batch start/stop verified.
- [x] **Automated Tests**: 22/22 tests passing.
- [x] **Flutter Analyze**: 0 errors, 0 warnings.
