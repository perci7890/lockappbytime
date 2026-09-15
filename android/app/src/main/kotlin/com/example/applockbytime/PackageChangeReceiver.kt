package com.example.applockbytime

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class PackageChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == Intent.ACTION_PACKAGE_FULLY_REMOVED) {
            val pkgUri = intent.data
            val uninstalledPkg = pkgUri?.schemeSpecificPart
            if (!uninstalledPkg.isNullOrEmpty()) {
                Log.d("PackageChangeReceiver", "Uninstalled app detected: $uninstalledPkg. Removing lock if present.")
                LockStorage.removeLock(context, uninstalledPkg)
            }
        }
    }
}
