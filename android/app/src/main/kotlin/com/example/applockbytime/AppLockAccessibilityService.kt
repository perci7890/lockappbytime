package com.example.applockbytime

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.SystemClock
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class AppLockAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "AppLockA11yService"
        var isServiceRunning = false
            private set

        // Prevent rapid re-triggering loops
        private var lastBlockedPackage: String? = null
        private var lastBlockedTime: Long = 0
        private const val BLOCK_DEBOUNCE_MS = 800L

        // Whitelist critical system packages that must never be blocked
        private val EXCLUDED_PACKAGES = setOf(
            "com.android.systemui",
            "android",
            "com.android.launcher",
            "com.android.launcher3",
            "com.google.android.apps.nexuslauncher",
            "com.sec.android.app.launcher",
            "com.miui.home",
            "com.oppo.launcher",
            "com.huawei.android.launcher",
            "com.oneplus.launcher",
            "com.android.settings",
            "com.google.android.inputmethod.latin",
            "com.samsung.android.honeyboard",
            "com.google.android.packageinstaller",
            "com.android.permissioncontroller"
        )
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        isServiceRunning = true
        Log.i(TAG, "AppLockAccessibilityService connected and active.")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        try {
            if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
                event.eventType == AccessibilityEvent.TYPE_WINDOWS_CHANGED
            ) {
                val packageNameCharSequence = event.packageName ?: return
                val currentPackage = packageNameCharSequence.toString()

                // Never intercept or block App Locker itself
                if (currentPackage == packageName) {
                    lastBlockedPackage = null
                    return
                }

                // Never intercept excluded system components or launchers
                if (EXCLUDED_PACKAGES.contains(currentPackage) ||
                    currentPackage.contains("inputmethod") ||
                    currentPackage.contains("launcher")
                ) {
                    lastBlockedPackage = null
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

    private fun checkAndEnforceLock(pkg: String) {
        val now = SystemClock.uptimeMillis()

        // Debounce if the same package was just handled within the debounce window
        if (pkg == lastBlockedPackage && (now - lastBlockedTime) < BLOCK_DEBOUNCE_MS) {
            return
        }

        // Clean up expired locks periodically on foreground events
        LockStorage.cleanupExpiredLocks(this)

        val activeLock = LockStorage.getActiveLock(this, pkg)
        if (activeLock != null && activeLock.isCurrentlyLocked()) {
            lastBlockedPackage = pkg
            lastBlockedTime = now
            LockStorage.recordEnforcementCheck("BLOCKED: $pkg")
            Log.d(TAG, "Blocking locked package: $pkg until ${activeLock.unlockAt}")
            showLockScreen(activeLock)
        } else {
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
