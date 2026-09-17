package com.example.applockbytime

import android.app.AlertDialog
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.InputFilter
import android.text.InputType
import android.text.method.PasswordTransformationMethod
import android.view.Gravity
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.TextView
import android.widget.Toast
import androidx.activity.ComponentActivity
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class LockScreenActivity : ComponentActivity() {

    companion object {
        var isLockScreenVisible: Boolean = false
            private set
    }

    private lateinit var tvAppName: TextView
    private lateinit var tvCountdown: TextView
    private lateinit var tvUnlockAt: TextView
    private lateinit var btnUnlockWithPin: Button
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
        btnUnlockWithPin = findViewById(R.id.btnUnlockWithPin)
        btnGoBack = findViewById(R.id.btnGoBack)

        extractIntentData(intent)

        btnGoBack.setOnClickListener {
            goHome()
        }

        btnUnlockWithPin.setOnClickListener {
            showUnlockWithPinDialog()
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

    private fun showUnlockWithPinDialog() {
        val isPinConfigured = LockStorage.isPinEnabled(this)
        if (!isPinConfigured) {
            // No security PIN configured yet
            AlertDialog.Builder(this)
                .setTitle("Unlock $appName")
                .setMessage("No Security PIN is configured in App Locker.\n\nDo you want to cancel the remaining lock time and unlock $appName?")
                .setPositiveButton("Unlock App") { _, _ ->
                    performUnlock()
                }
                .setNegativeButton("Cancel", null)
                .show()
            return
        }

        // Security PIN is active: require PIN entry
        val input = EditText(this).apply {
            inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_VARIATION_PASSWORD
            transformationMethod = PasswordTransformationMethod.getInstance()
            filters = arrayOf(InputFilter.LengthFilter(8))
            gravity = Gravity.CENTER
            textSize = 22f
            setTextColor(Color.WHITE)
            setHintTextColor(Color.parseColor("#64748B"))
            hint = "Enter PIN"
            setPadding(32, 24, 32, 24)
            setBackgroundColor(Color.parseColor("#0F172A"))
        }

        val container = FrameLayout(this).apply {
            setPadding(50, 30, 50, 20)
            addView(input)
        }

        val dialog = AlertDialog.Builder(this)
            .setTitle("Security PIN Verification")
            .setMessage("Enter your PIN to remove the remaining lock time for $appName:")
            .setView(container)
            .setPositiveButton("Unlock", null)
            .setNegativeButton("Cancel", null)
            .create()

        dialog.setOnShowListener {
            val unlockBtn = dialog.getButton(AlertDialog.BUTTON_POSITIVE)
            unlockBtn.setOnClickListener {
                val enteredPin = input.text.toString().trim()
                if (enteredPin.isEmpty()) {
                    input.error = "Please enter PIN"
                    return@setOnClickListener
                }

                val isCorrect = LockStorage.verifyPinNative(this, enteredPin)
                if (isCorrect) {
                    dialog.dismiss()
                    performUnlock()
                } else {
                    input.error = "Incorrect PIN"
                    input.setText("")
                }
            }

            input.requestFocus()
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
            imm?.showSoftInput(input, InputMethodManager.SHOW_IMPLICIT)
        }

        dialog.show()
    }

    private fun performUnlock() {
        if (targetPackage.isNotEmpty()) {
            LockStorage.removeLock(this, targetPackage)
            Toast.makeText(this, "$appName unlocked", Toast.LENGTH_SHORT).show()
        }
        finish()
    }

    override fun onResume() {
        super.onResume()
        isLockScreenVisible = true
        handler.removeCallbacks(updateRunnable)
        handler.post(updateRunnable)
    }

    override fun onPause() {
        super.onPause()
        isLockScreenVisible = false
        handler.removeCallbacks(updateRunnable)
    }

    override fun onDestroy() {
        super.onDestroy()
        isLockScreenVisible = false
        handler.removeCallbacks(updateRunnable)
    }

    private fun updateTimer() {
        if (targetPackage.isNotEmpty()) {
            val activeLock = LockStorage.getActiveLock(this, targetPackage)
            if (activeLock == null) {
                // Lock removed or expired
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
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
        }
        startActivity(homeIntent)
        finish()
        overridePendingTransition(0, 0)
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        super.onBackPressed()
        goHome()
    }
}
