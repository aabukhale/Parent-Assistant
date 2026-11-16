package com.example.my_app.rules

import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.concurrent.Executors

/** `mamily/device_rules` — see lib/features/device_rules/application/native_enforcement.dart. */
object DeviceRulesChannel {
    private val io = Executors.newSingleThreadExecutor()

    fun register(ctx: Context, messenger: BinaryMessenger) {
        val engine = PolicyEngine(ctx.applicationContext)
        MethodChannel(messenger, "mamily/device_rules").setMethodCallHandler { call, result ->
            fun bg(work: () -> Any?) = io.execute {
                try {
                    val v = work()
                    android.os.Handler(android.os.Looper.getMainLooper()).post { result.success(v) }
                } catch (e: Exception) {
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        result.error("native_error", e.javaClass.simpleName, null)
                    }
                }
            }
            when (call.method) {
                "capabilities" -> bg { engine.capabilities() }
                "apply" -> bg {
                    @Suppress("UNCHECKED_CAST")
                    val json = JSONObject(call.arguments as Map<String, Any?>).toString()
                    val r = engine.apply(json)
                    mapOf("status" to r.status, "results" to r.results, "error" to r.error)
                }
                "verify" -> bg { engine.verify((call.argument<Int>("version")) ?: 0) }
                "enforcementActive" -> bg { engine.enforcementActive() }
                "clear" -> bg { engine.clear(call.argument<Boolean>("release") ?: false); null }
                "installedApps" -> bg { engine.installedApps() }
                "usageSince" -> bg { engine.usageSince((call.argument<Number>("from") ?: 0).toLong()) }
                "openSetup" -> {
                    val what = call.argument<String>("what")
                    val intent = when (what) {
                        "usage_access" -> Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                        "location" -> Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
                        "exact_alarms" -> if (android.os.Build.VERSION.SDK_INT >= 31) {
                            Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, android.net.Uri.parse("package:${ctx.packageName}"))
                        } else null
                        else -> null
                    }
                    if (intent == null) {
                        result.success(false)
                    } else {
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        ctx.startActivity(intent)
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
