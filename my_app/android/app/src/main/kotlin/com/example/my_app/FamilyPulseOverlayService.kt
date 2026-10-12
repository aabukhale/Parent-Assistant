package com.example.my_app

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.content.res.ColorStateList
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageButton
import android.widget.TextView
import es.antonborri.home_widget.HomeWidgetPlugin
import kotlin.math.abs

/**
 * Optional floating Family Pulse card (Android only, off by default).
 *
 * Runs only after the parent turns it on and grants "Display over other
 * apps". It is a foreground service, so a persistent notification makes it
 * visible and stoppable at any time; logout stops it. It shows the same
 * privacy-filtered payload as the widget and never polls — the app pushes
 * updates on resume and after decisions.
 */
class FamilyPulseOverlayService : Service() {

    private var windowManager: WindowManager? = null
    private var card: View? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startInForeground()
        if (!Settings.canDrawOverlays(this)) {
            stopSelf()
            return
        }
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        addCard()
        running = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        render()
        // Out of the way while Mamily itself is on screen.
        card?.visibility = if (appInForeground) View.GONE else View.VISIBLE
        // Not sticky: if the system kills it, it stays off until the parent
        // opens the app again — no surprise reappearing windows.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        running = false
        card?.let { runCatching { windowManager?.removeView(it) } }
        card = null
        super.onDestroy()
    }

    private fun startInForeground() {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    getString(R.string.overlay_channel_name),
                    NotificationManager.IMPORTANCE_MIN,
                ).apply { setShowBadge(false) },
            )
        }
        val stop = PendingIntent.getService(
            this, 1,
            Intent(this, FamilyPulseOverlayService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_mamily)
            .setContentTitle(getString(R.string.overlay_notification_title))
            .setContentText(getString(R.string.overlay_notification_text))
            .setOngoing(true)
            .setContentIntent(FamilyPulseWidgetProvider.openApp(this, signedIn = true))
            .addAction(
                Notification.Action.Builder(null, getString(R.string.overlay_stop), stop).build(),
            )
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    @SuppressLint("InflateParams", "ClickableViewAccessibility")
    private fun addCard() {
        val view = LayoutInflater.from(this).inflate(R.layout.family_pulse_overlay, null)
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 24
            y = 240
        }

        view.findViewById<ImageButton>(R.id.overlay_close).apply {
            imageTintList = ColorStateList.valueOf(getColor(R.color.pulse_ink_muted))
            setOnClickListener { stopSelf() }
        }

        // Drag to move; a tap (no real movement) opens the inbox.
        var startX = 0
        var startY = 0
        var touchX = 0f
        var touchY = 0f
        view.setOnTouchListener { v, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    startX = params.x; startY = params.y
                    touchX = event.rawX; touchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    params.x = startX + (event.rawX - touchX).toInt()
                    params.y = startY + (event.rawY - touchY).toInt()
                    windowManager?.updateViewLayout(v, params)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (abs(event.rawX - touchX) < TAP_SLOP && abs(event.rawY - touchY) < TAP_SLOP) {
                        v.performClick()
                        runCatching { FamilyPulseWidgetProvider.openApp(this, signedIn = true).send() }
                    }
                    true
                }
                else -> false
            }
        }

        windowManager?.addView(view, params)
        card = view
        render()
        view.visibility = if (appInForeground) View.GONE else View.VISIBLE
    }

    private fun render() {
        val view = card ?: return
        val raw = HomeWidgetPlugin.getData(this).getString(PulseSurface.DATA_KEY, null)
        val surface = PulseSurface.parse(raw)
        if (surface == null) {
            // Signed out or wiped: nothing to show, so don't linger.
            stopSelf()
            return
        }
        view.findViewById<TextView>(R.id.overlay_headline).text = surface.headline(this)
        view.findViewById<TextView>(R.id.overlay_footer).text = surface.updatedLine(this)
        view.contentDescription = listOf(
            surface.headline(this),
            surface.updatedLine(this),
        ).joinToString(". ")
    }

    companion object {
        private const val CHANNEL_ID = "mamily_overlay"
        private const val NOTIFICATION_ID = 4107
        private const val ACTION_STOP = "com.mamily.overlay.STOP"
        private const val TAP_SLOP = 12

        @Volatile
        var running = false
            private set

        @Volatile
        private var appInForeground = false

        /** Called by MainActivity on resume/pause. */
        fun setAppInForeground(context: Context, foreground: Boolean) {
            appInForeground = foreground
            update(context)
        }

        fun hasPermission(context: Context): Boolean = Settings.canDrawOverlays(context)

        fun start(context: Context): Boolean {
            if (!hasPermission(context)) return false
            val intent = Intent(context, FamilyPulseOverlayService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            return true
        }

        /** Re-reads the saved payload; no-op when the card is not running. */
        fun update(context: Context) {
            if (!running) return
            // A running foreground service accepts this; guard anyway against
            // background-start restrictions so a resume/pause never crashes.
            runCatching {
                context.startService(Intent(context, FamilyPulseOverlayService::class.java))
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, FamilyPulseOverlayService::class.java))
        }
    }
}
