package com.example.my_app.rules

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * After reboot, time change or an app update: re-apply the cached policy and
 * re-arm the next alarm (alarms don't survive reboot).
 */
class RulesBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED, Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED" -> {
                val pending = goAsync()
                Thread {
                    try {
                        PolicyEngine(context).evaluateAndEnforce("boot:" + intent.action)
                    } finally {
                        pending.finish()
                    }
                }.start()
            }
        }
    }
}
