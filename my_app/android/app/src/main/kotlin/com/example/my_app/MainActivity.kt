package com.example.my_app

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Floating Family Pulse card — see SurfaceSync in lib/features/surfaces.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mamily/overlay")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPermission" -> result.success(FamilyPulseOverlayService.hasPermission(this))
                    "requestPermission" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName"),
                            ),
                        )
                        result.success(null)
                    }
                    "isRunning" -> result.success(FamilyPulseOverlayService.running)
                    "start" -> result.success(FamilyPulseOverlayService.start(this))
                    "update" -> {
                        FamilyPulseOverlayService.update(this)
                        result.success(null)
                    }
                    "stop" -> {
                        FamilyPulseOverlayService.stop(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
