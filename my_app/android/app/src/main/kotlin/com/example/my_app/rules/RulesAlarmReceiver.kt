package com.example.my_app.rules

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Re-evaluates the cached policy at schedule/expiry boundaries — offline too. */
class RulesAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        Thread {
            try {
                PolicyEngine(context).evaluateAndEnforce("alarm")
            } finally {
                pending.finish()
            }
        }.start()
    }
}
