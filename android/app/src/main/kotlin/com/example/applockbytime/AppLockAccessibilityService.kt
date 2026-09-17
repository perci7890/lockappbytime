package com.example.applockbytime

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.content.pm.PackageManager
import android.os.SystemClock
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class AppLockAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "AppLockA11yService"
        var isServiceRunning = false
            private set

        private var lastBlockedPackage: String? = null
        private var lastBlockedTime: Long = 0L

        // Whitelist essential Android OS components that must never be blocked
        private val EXCLUDED_PACKAGES = setOf(
            "com.android.systemui",
            "android",
            "com.android.inputmethod.latin",
            "com.google.android.inputmethod.latin",
            "com.samsung.android.honeyboard",
            "com.android.permissioncontroller",
            "com.google.android.packageinstaller"
        )
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        isServiceRunning = true
        Log.i(TAG, "AppLockAccessibilityService connected and active.")
        // Ensure persistent foreground service runs to prevent Android OS termination
        AppLockForegroundService.start(this)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        try {
            if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
                val packageNameCharSequence = event.packageName ?: return
                val currentPackage = packageNameCharSequence.toString()

                // Never intercept or block FocusLock itself
                if (currentPackage == packageName) {
                    lastBlockedPackage = null
                    return
                }

                // If user is on the launcher / home screen, clear last blocked package immediately
                if (isLauncherPackage(currentPackage)) {
                    lastBlockedPackage = null
                    return
                }

                // Never intercept excluded system components
                if (EXCLUDED_PACKAGES.contains(currentPackage) ||
                    currentPackage.contains("inputmethod")
                ) {
                    return
                }

                // Record diagnostic telemetry
                LockStorage.recordForegroundEvent(currentPackage)

                checkAndEnforceLock(currentPackage)
            }
        } catch (e: Exception) {
            LockStorage.recordError("onAccessibilityEvent error: ${e.message}")
        }
    }

    private fun isLauncherPackage(pkg: String): Boolean {
        if (pkg.contains("launcher", ignoreCase = true) || pkg.contains("home", ignoreCase = true)) {
            return true
        }
        try {
            val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
            val resolveInfo = packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
            if (resolveInfo?.activityInfo?.packageName == pkg) {
                return true
            }
        } catch (_: Exception) {}
        return false
    }

    private fun checkAndEnforceLock(pkg: String) {
        val now = SystemClock.uptimeMillis()

        // Clean up expired locks periodically on foreground events
        LockStorage.cleanupExpiredLocks(this)

        val activeLock = LockStorage.getActiveLock(this, pkg)
        if (activeLock != null && activeLock.isCurrentlyLocked()) {
            // If the lock screen is already visible for this exact package, do not re-launch
            if (LockScreenActivity.isLockScreenVisible && pkg == lastBlockedPackage) {
                return
            }

            lastBlockedPackage = pkg
            lastBlockedTime = now
            LockStorage.recordEnforcementCheck("BLOCKED: $pkg")
            Log.d(TAG, "Blocking locked package: $pkg until ${activeLock.unlockAt}")
            showLockScreen(activeLock)
        } else {
            if (pkg == lastBlockedPackage) {
                lastBlockedPackage = null
            }
            LockStorage.recordEnforcementCheck("ALLOWED: $pkg")
        }
    }

    private fun showLockScreen(lock: LockInfo) {
        try {
            val intent = Intent(this, LockScreenActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_NO_ANIMATION
                putExtra("packageName", lock.packageName)
                putExtra("appName", lock.appName)
                putExtra("unlockAt", lock.unlockAt)
            }
            startActivity(intent)
        } catch (e: Exception) {
            LockStorage.recordError("Failed to launch LockScreenActivity: ${e.message}")
            // Strict enforcement fallback: kick user back to home immediately if activity start blocked
            performGlobalAction(GLOBAL_ACTION_HOME)
        }
    }

    override fun onInterrupt() {
        Log.w(TAG, "AppLockAccessibilityService interrupted.")
    }

    override fun onDestroy() {
        super.onDestroy()
        isServiceRunning = false
        Log.i(TAG, "AppLockAccessibilityService destroyed.")
    }
}
