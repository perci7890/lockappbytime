package com.example.applockbytime

import android.content.Context
import android.content.SharedPreferences
import android.os.SystemClock
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

data class LockInfo(
    val packageName: String,
    val appName: String,
    val lockedAt: Long,
    val unlockAt: Long,
    val enabled: Boolean,
    val elapsedRealtimeDeadline: Long = 0L,
    val lockType: String = "temporary", // "temporary", "schedule", "focusMode"
    val sourceId: String = "",
    val startMinutes: Int = -1, // e.g. 1200 for 20:00
    val endMinutes: Int = -1,   // e.g. 1320 for 22:00
    val daysOfWeek: String = "" // "1,2,3,4,5" (Calendar.MONDAY..Calendar.FRIDAY) or "all", "weekdays", "weekends"
) {
    /**
     * Determines whether this individual rule/schedule is active right now.
     */
    fun isCurrentlyLocked(): Boolean = isRuleActiveNow(System.currentTimeMillis())

    fun isRuleActiveNow(nowWall: Long, cal: Calendar = Calendar.getInstance()): Boolean {
        if (!enabled) return false

        if (lockType == "temporary" || lockType == "focusMode") {
            if (nowWall >= unlockAt) return false
            if (elapsedRealtimeDeadline > 0L) {
                val nowElapsed = SystemClock.elapsedRealtime()
                if (nowElapsed >= elapsedRealtimeDeadline) return false
            }
            return true
        }

        if (lockType == "schedule") {
            return isInsideSchedule(cal)
        }

        return false
    }

    private fun isInsideSchedule(cal: Calendar): Boolean {
        if (startMinutes < 0 || endMinutes < 0) return false
        if (startMinutes == endMinutes) return false

        val currentDay = cal.get(Calendar.DAY_OF_WEEK) // 1=Sunday, 2=Monday...7=Saturday
        val currentMinutes = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)

        val isOvernight = endMinutes < startMinutes

        if (!isOvernight) {
            // Normal same-day schedule (e.g., 20:00 -> 22:00)
            if (!matchesDay(currentDay)) return false
            return currentMinutes in startMinutes until endMinutes
        } else {
            // Overnight schedule (e.g., 22:00 -> 06:00)
            // Either:
            // 1) We are in late evening of today (currentMinutes >= startMinutes), and today matches schedule
            // 2) We are in early morning of today (currentMinutes < endMinutes), and yesterday matched schedule
            if (currentMinutes >= startMinutes && matchesDay(currentDay)) {
                return true
            }
            val yesterday = if (currentDay == Calendar.SUNDAY) Calendar.SATURDAY else currentDay - 1
            if (currentMinutes < endMinutes && matchesDay(yesterday)) {
                return true
            }
            return false
        }
    }

    private fun matchesDay(day: Int): Boolean {
        if (daysOfWeek.isBlank() || daysOfWeek.equals("all", ignoreCase = true) || daysOfWeek.equals("everyday", ignoreCase = true)) {
            return true
        }
        if (daysOfWeek.equals("weekdays", ignoreCase = true)) {
            return day in Calendar.MONDAY..Calendar.FRIDAY
        }
        if (daysOfWeek.equals("weekends", ignoreCase = true)) {
            return day == Calendar.SATURDAY || day == Calendar.SUNDAY
        }
        val parts = daysOfWeek.split(",").mapNotNull { it.trim().toIntOrNull() }
        return parts.contains(day)
    }

    fun toJson(): JSONObject {
        val obj = JSONObject()
        obj.put("packageName", packageName)
        obj.put("appName", appName)
        obj.put("lockedAt", lockedAt)
        obj.put("unlockAt", unlockAt)
        obj.put("enabled", enabled)
        obj.put("elapsedRealtimeDeadline", elapsedRealtimeDeadline)
        obj.put("lockType", lockType)
        obj.put("sourceId", sourceId)
        obj.put("startMinutes", startMinutes)
        obj.put("endMinutes", endMinutes)
        obj.put("daysOfWeek", daysOfWeek)
        return obj
    }

    companion object {
        fun fromJson(obj: JSONObject): LockInfo {
            return LockInfo(
                packageName = obj.optString("packageName", ""),
                appName = obj.optString("appName", ""),
                lockedAt = obj.optLong("lockedAt", 0L),
                unlockAt = obj.optLong("unlockAt", 0L),
                enabled = obj.optBoolean("enabled", true),
                elapsedRealtimeDeadline = obj.optLong("elapsedRealtimeDeadline", 0L),
                lockType = obj.optString("lockType", "temporary"),
                sourceId = obj.optString("sourceId", ""),
                startMinutes = obj.optInt("startMinutes", -1),
                endMinutes = obj.optInt("endMinutes", -1),
                daysOfWeek = obj.optString("daysOfWeek", "")
            )
        }
    }
}

object LockStorage {
    private const val TAG = "LockStorage"
    private const val PREFS_NAME = "app_lock_prefs"
    private const val KEY_LOCKS = "active_locks_json"
    private const val KEY_EMERGENCY_PREFIX = "emergency_until_"

    // Diagnostics / telemetry tracking
    var lastForegroundPackage: String = "None"
        private set
    var lastForegroundEventTime: Long = 0L
        private set
    var lastEnforcementCheckTime: Long = 0L
        private set
    var lastEnforcementAction: String = "None"
        private set
    var lastError: String = "None"
        private set

    fun recordForegroundEvent(pkg: String) {
        lastForegroundPackage = pkg
        lastForegroundEventTime = System.currentTimeMillis()
    }

    fun recordEnforcementCheck(action: String) {
        lastEnforcementCheckTime = System.currentTimeMillis()
        lastEnforcementAction = action
    }

    fun recordError(error: String) {
        lastError = error
        Log.e(TAG, "Error: $error")
    }

    private fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    @Synchronized
    fun setEmergencyUnlock(context: Context, packageName: String, durationMillis: Long = 5 * 60 * 1000L) {
        val until = System.currentTimeMillis() + durationMillis
        getPrefs(context).edit().putLong(KEY_EMERGENCY_PREFIX + packageName, until).apply()
        Log.i(TAG, "Emergency unlock set for $packageName until $until")
    }

    @Synchronized
    fun isEmergencyUnlocked(context: Context, packageName: String): Boolean {
        val until = getPrefs(context).getLong(KEY_EMERGENCY_PREFIX + packageName, 0L)
        val now = System.currentTimeMillis()
        return now < until
    }

    @Synchronized
    fun getAllLocks(context: Context): List<LockInfo> {
        val prefs = getPrefs(context)
        val jsonStr = prefs.getString(KEY_LOCKS, "[]") ?: "[]"
        val list = mutableListOf<LockInfo>()
        try {
            val jsonArray = JSONArray(jsonStr)
            for (i in 0 until jsonArray.length()) {
                val item = jsonArray.getJSONObject(i)
                list.add(LockInfo.fromJson(item))
            }
        } catch (e: Exception) {
            recordError("getAllLocks parse failed: ${e.message}")
        }
        return list
    }

    @Synchronized
    fun saveLock(context: Context, lock: LockInfo) {
        try {
            val existing = getAllLocks(context).toMutableList()
            // Remove existing rule matching same package and lockType/sourceId
            existing.removeAll { it.packageName == lock.packageName && it.lockType == lock.lockType && it.sourceId == lock.sourceId }
            existing.add(lock)
            saveAll(context, existing)
            Log.d(TAG, "Lock saved natively for ${lock.packageName} (${lock.lockType})")
        } catch (e: Exception) {
            recordError("saveLock failed for ${lock.packageName}: ${e.message}")
        }
    }

    @Synchronized
    fun removeLock(context: Context, packageName: String, lockType: String? = null, sourceId: String? = null) {
        try {
            val existing = getAllLocks(context).toMutableList()
            existing.removeAll {
                val matchPkg = it.packageName == packageName
                val matchType = lockType == null || it.lockType == lockType
                val matchSource = sourceId == null || it.sourceId == sourceId
                matchPkg && matchType && matchSource
            }
            saveAll(context, existing)
            Log.d(TAG, "Lock removed natively for $packageName")
        } catch (e: Exception) {
            recordError("removeLock failed for $packageName: ${e.message}")
        }
    }

    /**
     * Centralized Native Decision Engine:
     * Evaluates Emergency Unlock, Temporary Locks, Recurring Schedules, and Focus Modes.
     * Returns the active LockInfo blocking the app, or null if unrestricted.
     */
    @Synchronized
    fun isPackageLocked(context: Context, packageName: String): LockInfo? {
        lastEnforcementCheckTime = System.currentTimeMillis()

        // 1. Emergency unlock overrides any locks for this package
        if (isEmergencyUnlocked(context, packageName)) {
            return null
        }

        val all = getAllLocks(context)
        val nowWall = System.currentTimeMillis()
        val cal = Calendar.getInstance()

        // Check if ANY active lock source requires blocking
        val activeRule = all.firstOrNull { it.packageName == packageName && it.isRuleActiveNow(nowWall, cal) }
        return activeRule
    }

    @Synchronized
    fun getActiveLock(context: Context, packageName: String): LockInfo? {
        return isPackageLocked(context, packageName)
    }

    /**
     * Cleans up expired temporary locks from the native store.
     * Preserves recurring schedules indefinitely.
     */
    @Synchronized
    fun cleanupExpiredLocks(context: Context): List<String> {
        val all = getAllLocks(context)
        val active = mutableListOf<LockInfo>()
        val expired = mutableListOf<String>()
        val now = System.currentTimeMillis()

        for (lock in all) {
            if (lock.lockType == "schedule") {
                active.add(lock) // Schedules never expire by epoch timestamp
            } else if (lock.unlockAt > now && lock.enabled) {
                active.add(lock)
            } else {
                expired.add(lock.packageName)
            }
        }

        if (expired.isNotEmpty()) {
            saveAll(context, active)
            Log.d(TAG, "Cleaned up expired native locks: $expired")
        }
        return expired
    }

    @Synchronized
    fun onDeviceReboot(context: Context) {
        val all = getAllLocks(context)
        val now = System.currentTimeMillis()
        val nowElapsed = SystemClock.elapsedRealtime()
        val updated = mutableListOf<LockInfo>()

        for (lock in all) {
            if (lock.lockType == "schedule") {
                updated.add(lock)
            } else if (lock.enabled && lock.unlockAt > now) {
                val remaining = lock.unlockAt - now
                val newElapsedDeadline = if (remaining > 0) nowElapsed + remaining else 0L
                updated.add(lock.copy(elapsedRealtimeDeadline = newElapsedDeadline))
                Log.d(TAG, "Re-anchored monotonic deadline for ${lock.appName} until ${lock.unlockAt}")
            }
        }
        saveAll(context, updated)
        Log.i(TAG, "Device reboot handled: preserved ${updated.size} locks.")
    }

    @Synchronized
    fun saveAll(context: Context, locks: List<LockInfo>) {
        val jsonArray = JSONArray()
        for (lock in locks) {
            jsonArray.put(lock.toJson())
        }
        getPrefs(context).edit().putString(KEY_LOCKS, jsonArray.toString()).apply()
    }
}
