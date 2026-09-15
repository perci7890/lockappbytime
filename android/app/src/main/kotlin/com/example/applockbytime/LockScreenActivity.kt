package com.example.applockbytime

import android.app.AlertDialog
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.widget.Button
import android.widget.TextView
import androidx.activity.ComponentActivity
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class LockScreenActivity : ComponentActivity() {

    private lateinit var tvAppName: TextView
    private lateinit var tvCountdown: TextView
    private lateinit var tvUnlockAt: TextView
    private lateinit var btnEmergencyUnlock: Button
    private lateinit var btnGoBack: Button

    private var targetPackage: String = ""
    private var appName: String = ""
    private var unlockAtMillis: Long = 0L

    private val handler = Handler(Looper.getMainLooper())
    private val updateRunnable = object : Runnable {
        override fun run() {
            updateTimer()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_lock_screen)

        tvAppName = findViewById(R.id.tvAppName)
        tvCountdown = findViewById(R.id.tvCountdown)
        tvUnlockAt = findViewById(R.id.tvUnlockAt)
        btnEmergencyUnlock = findViewById(R.id.btnEmergencyUnlock)
        btnGoBack = findViewById(R.id.btnGoBack)

        extractIntentData(intent)

        btnGoBack.setOnClickListener {
            goHome()
        }

        btnEmergencyUnlock.setOnClickListener {
            showEmergencyConfirmDialog()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        extractIntentData(intent)
    }

    private fun extractIntentData(intent: Intent?) {
        if (intent == null) return
        targetPackage = intent.getStringExtra("packageName") ?: ""
        appName = intent.getStringExtra("appName") ?: targetPackage
        unlockAtMillis = intent.getLongExtra("unlockAt", 0L)

        val activeLock = if (targetPackage.isNotEmpty()) LockStorage.getActiveLock(this, targetPackage) else null
        if (activeLock != null) {
            appName = activeLock.appName
            if (activeLock.lockType == "schedule") {
                // Calculate unlock timestamp for today or next morning
                val cal = Calendar.getInstance()
                val currentMins = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
                val targetCal = Calendar.getInstance()
                targetCal.set(Calendar.HOUR_OF_DAY, activeLock.endMinutes / 60)
                targetCal.set(Calendar.MINUTE, activeLock.endMinutes % 60)
                targetCal.set(Calendar.SECOND, 0)
                targetCal.set(Calendar.MILLISECOND, 0)
                if (activeLock.endMinutes <= activeLock.startMinutes && currentMins >= activeLock.startMinutes) {
                    targetCal.add(Calendar.DAY_OF_YEAR, 1)
                }
                unlockAtMillis = targetCal.timeInMillis
            } else if (unlockAtMillis == 0L) {
                unlockAtMillis = activeLock.unlockAt
            }
        }

        tvAppName.text = appName

        if (unlockAtMillis > 0L) {
            val sdf = SimpleDateFormat("h:mm a", Locale.getDefault())
            tvUnlockAt.text = "Available at ${sdf.format(Date(unlockAtMillis))}"
        } else {
            tvUnlockAt.text = "Lock Active"
        }

        updateTimer()
    }

    private fun showEmergencyConfirmDialog() {
        AlertDialog.Builder(this)
            .setTitle("Emergency Unlock")
            .setMessage("$appName will be temporarily accessible for 5 minutes.\n\nAfter 5 minutes, normal locking will automatically resume.")
            .setPositiveButton("Unlock for 5 Min") { _, _ ->
                if (targetPackage.isNotEmpty()) {
                    LockStorage.setEmergencyUnlock(this, targetPackage, 5 * 60 * 1000L)
                }
                finish()
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    override fun onResume() {
        super.onResume()
        handler.removeCallbacks(updateRunnable)
        handler.post(updateRunnable)
    }

    override fun onPause() {
        super.onPause()
        handler.removeCallbacks(updateRunnable)
    }

    private fun updateTimer() {
        if (targetPackage.isNotEmpty()) {
            val activeLock = LockStorage.getActiveLock(this, targetPackage)
            if (activeLock == null) {
                // Lock expired or lifted (e.g., via emergency unlock or schedule window ending)
                handler.removeCallbacks(updateRunnable)
                finish()
                return
            }
        }

        val now = System.currentTimeMillis()
        val diff = unlockAtMillis - now

        if (diff <= 0 && unlockAtMillis > 0L) {
            // Lock expired!
            tvCountdown.text = "00:00:00"
            handler.removeCallbacks(updateRunnable)
            finish()
            return
        }

        if (unlockAtMillis <= 0L) {
            tvCountdown.text = "--:--:--"
            return
        }

        val totalSecs = diff / 1000
        val hours = totalSecs / 3600
        val mins = (totalSecs % 3600) / 60
        val secs = totalSecs % 60

        tvCountdown.text = String.format(Locale.US, "%02d:%02d:%02d", hours, mins, secs)
    }

    private fun goHome() {
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
        finish()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        super.onBackPressed()
        goHome()
    }
}
