package com.example.applockbytime

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Process
import android.os.SystemClock
import android.provider.Settings
import android.text.TextUtils
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.Calendar
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.applockbytime/app_lock"
    private val executor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityServiceEnabled" -> {
                    result.success(isAccessibilityServiceEnabled(this))
                }
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
                    result.success(true)
                }
                "canDrawOverlays" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        result.success(Settings.canDrawOverlays(this))
                    } else {
                        result.success(true)
                    }
                }
                "openOverlaySettings" -> {
                    openOverlaySettings()
                    result.success(true)
                }
                "hasUsageStatsPermission" -> {
                    result.success(hasUsageStatsPermission(this))
                }
                "openUsageAccessSettings" -> {
                    openUsageAccessSettings()
                    result.success(true)
                }
                "getUsageStats" -> {
                    val daysBack = call.argument<Int>("days") ?: 0
                    executor.execute {
                        try {
                            val stats = getAppUsageStats(daysBack)
                            runOnUiThread { result.success(stats) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("USAGE_STATS_ERROR", e.message, null) }
                        }
                    }
                }
                "setEmergencyUnlock" -> {
                    val pkg = call.argument<String>("packageName") ?: ""
                    val duration = call.argument<Number>("durationMillis")?.toLong() ?: (5 * 60 * 1000L)
                    if (pkg.isNotEmpty()) {
                        LockStorage.setEmergencyUnlock(this, pkg, duration)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Package name required", null)
                    }
                }
                "isEmergencyUnlocked" -> {
                    val pkg = call.argument<String>("packageName") ?: ""
                    result.success(LockStorage.isEmergencyUnlocked(this, pkg))
                }
                "getInstalledApps" -> {
                    executor.execute {
                        try {
                            val apps = getInstalledLaunchableApps()
                            runOnUiThread { result.success(apps) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("APP_DISCOVERY_ERROR", e.message, null) }
                        }
                    }
                }
                "saveLockNative" -> {
                    val pkg = call.argument<String>("packageName") ?: ""
                    val appName = call.argument<String>("appName") ?: ""
                    val lockedAt = call.argument<Number>("lockedAt")?.toLong() ?: 0L
                    val unlockAt = call.argument<Number>("unlockAt")?.toLong() ?: 0L
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    val lockType = call.argument<String>("lockType") ?: "temporary"
                    val sourceId = call.argument<String>("sourceId") ?: ""
                    val startMinutes = call.argument<Int>("startMinutes") ?: -1
                    val endMinutes = call.argument<Int>("endMinutes") ?: -1
                    val daysOfWeek = call.argument<String>("daysOfWeek") ?: ""

                    if (pkg.isNotEmpty()) {
                        val duration = unlockAt - System.currentTimeMillis()
                        val elapsedDeadline = if (duration > 0 && lockType == "temporary") SystemClock.elapsedRealtime() + duration else 0L

                        val lock = LockInfo(
                            packageName = pkg,
                            appName = appName,
                            lockedAt = lockedAt,
                            unlockAt = unlockAt,
                            enabled = enabled,
                            elapsedRealtimeDeadline = elapsedDeadline,
                            lockType = lockType,
                            sourceId = sourceId,
                            startMinutes = startMinutes,
                            endMinutes = endMinutes,
                            daysOfWeek = daysOfWeek
                        )
                        LockStorage.saveLock(this, lock)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Missing package name", null)
                    }
                }
                "removeLockNative" -> {
                    val pkg = call.argument<String>("packageName") ?: ""
                    val lockType = call.argument<String>("lockType")
                    val sourceId = call.argument<String>("sourceId")
                    if (pkg.isNotEmpty()) {
                        LockStorage.removeLock(this, pkg, lockType, sourceId)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Package name cannot be empty", null)
                    }
                }
                "getActiveLocksNative" -> {
                    val locks = LockStorage.getAllLocks(this)
                    val list = locks.map {
                        mapOf(
                            "packageName" to it.packageName,
                            "appName" to it.appName,
                            "lockedAt" to it.lockedAt,
                            "unlockAt" to it.unlockAt,
                            "enabled" to it.enabled,
                            "elapsedRealtimeDeadline" to it.elapsedRealtimeDeadline,
                            "lockType" to it.lockType,
                            "sourceId" to it.sourceId,
                            "startMinutes" to it.startMinutes,
                            "endMinutes" to it.endMinutes,
                            "daysOfWeek" to it.daysOfWeek
                        )
                    }
                    result.success(list)
                }
                "getDiagnostics" -> {
                    val diagnostics = mapOf(
                        "isAccessibilityActive" to AppLockAccessibilityService.isServiceRunning,
                        "isAccessibilityPermissionGranted" to isAccessibilityServiceEnabled(this),
                        "isOverlayGranted" to (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) Settings.canDrawOverlays(this) else true),
                        "isUsageAccessGranted" to hasUsageStatsPermission(this),
                        "nativeLocksCount" to LockStorage.getAllLocks(this).size,
                        "lastForegroundPackage" to LockStorage.lastForegroundPackage,
                        "lastForegroundEventTime" to LockStorage.lastForegroundEventTime,
                        "lastEnforcementCheckTime" to LockStorage.lastEnforcementCheckTime,
                        "lastEnforcementAction" to LockStorage.lastEnforcementAction,
                        "lastError" to LockStorage.lastError
                    )
                    result.success(diagnostics)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isAccessibilityServiceEnabled(context: Context): Boolean {
        val expectedServiceName = "${context.packageName}/${AppLockAccessibilityService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServices)
        while (colonSplitter.hasNext()) {
            val componentName = colonSplitter.next()
            if (componentName.equals(expectedServiceName, ignoreCase = true)) {
                return true
            }
        }
        return AppLockAccessibilityService.isServiceRunning
    }

    private fun hasUsageStatsPermission(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        } else {
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun openUsageAccessSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
    }

    private fun openAccessibilitySettings() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
    }

    private fun openOverlaySettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            ).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
        }
    }

    private fun getAppUsageStats(daysBack: Int): List<Map<String, Any>> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return emptyList()
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)

        if (daysBack > 0) {
            cal.add(Calendar.DAY_OF_YEAR, -daysBack)
        }
        val startTime = cal.timeInMillis
        val endTime = System.currentTimeMillis()

        val stats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, endTime)
        val usageMap = mutableMapOf<String, Long>()

        for (u in stats) {
            val current = usageMap[u.packageName] ?: 0L
            val totalTime = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                u.totalTimeVisible
            } else {
                u.totalTimeInForeground
            }
            usageMap[u.packageName] = current + totalTime
        }

        val pm = packageManager
        val list = mutableListOf<Map<String, Any>>()
        for ((pkg, totalTime) in usageMap) {
            if (totalTime <= 0) continue
            var appName = pkg
            try {
                val appInfo = pm.getApplicationInfo(pkg, 0)
                appName = pm.getApplicationLabel(appInfo).toString()
            } catch (_: Exception) {}

            list.add(mapOf(
                "packageName" to pkg,
                "appName" to appName,
                "totalTimeForegroundMillis" to totalTime
            ))
        }

        list.sortByDescending { it["totalTimeForegroundMillis"] as Long }
        return list
    }

    private fun getInstalledLaunchableApps(): List<Map<String, Any>> {
        val pm = packageManager
        val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val resolveInfos = pm.queryIntentActivities(mainIntent, 0)
        val appList = mutableListOf<Map<String, Any>>()
        val seenPackages = HashSet<String>()

        val systemBlacklist = setOf(
            packageName,
            "com.android.settings",
            "com.android.systemui",
            "com.android.permissioncontroller",
            "com.google.android.packageinstaller"
        )

        for (info in resolveInfos) {
            val pkg = info.activityInfo.packageName
            if (systemBlacklist.contains(pkg)) continue
            if (seenPackages.contains(pkg)) continue
            seenPackages.add(pkg)

            val appName = try {
                info.loadLabel(pm).toString()
            } catch (e: Exception) {
                pkg
            }

            val iconBase64 = try {
                val drawable = info.loadIcon(pm)
                val bitmap = drawableToBitmap(drawable)
                bitmapToBase64(bitmap)
            } catch (e: Exception) {
                ""
            }

            val isSystemApp = (info.activityInfo.applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0

            val item = mapOf(
                "packageName" to pkg,
                "appName" to if (appName.isBlank()) pkg else appName,
                "iconBase64" to iconBase64,
                "isSystemApp" to isSystemApp
            )
            appList.add(item)
        }

        appList.sortBy { (it["appName"] as String).lowercase() }
        return appList
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap != null) {
            return drawable.bitmap
        }
        val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 72
        val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 72
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }

    private fun bitmapToBase64(bitmap: Bitmap): String {
        val outputStream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 90, outputStream)
        val byteArray = outputStream.toByteArray()
        return Base64.encodeToString(byteArray, Base64.NO_WRAP)
    }
}
