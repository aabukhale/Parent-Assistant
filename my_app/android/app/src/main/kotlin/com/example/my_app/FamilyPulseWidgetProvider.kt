package com.example.my_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen Family Pulse widget. Redrawn whenever the app calls
 * `HomeWidget.updateWidget` (on resume and after approvals) — never on a
 * timer — so it shows its age and turns "stale" rather than pretending to be
 * live. Logout writes null, which shows the signed-out state.
 */
class FamilyPulseWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val surface = PulseSurface.parse(widgetData.getString(PulseSurface.DATA_KEY, null))
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, render(context, surface))
        }
    }

    private fun render(context: Context, surface: PulseSurface?): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.family_pulse_widget)
        views.setOnClickPendingIntent(R.id.pulse_root, openApp(context, surface != null))

        if (surface == null) {
            views.setTextViewText(R.id.pulse_headline, context.getString(R.string.pulse_title))
            views.setTextViewText(R.id.pulse_footer, context.getString(R.string.pulse_signed_out))
            CHILD_ROWS.forEach { views.setViewVisibility(it, View.GONE) }
            views.setViewVisibility(R.id.pulse_more, View.GONE)
            return views
        }

        views.setTextViewText(R.id.pulse_headline, surface.headline(context))
        CHILD_ROWS.forEachIndexed { i, rowId ->
            val child = surface.children.getOrNull(i)
            if (child == null) {
                views.setViewVisibility(rowId, View.GONE)
            } else {
                views.setViewVisibility(rowId, View.VISIBLE)
                views.setTextViewText(rowId, surface.childLine(context, child))
            }
        }
        val extra = surface.children.size - CHILD_ROWS.size
        if (extra > 0) {
            views.setViewVisibility(R.id.pulse_more, View.VISIBLE)
            views.setTextViewText(
                R.id.pulse_more,
                context.resources.getQuantityString(R.plurals.pulse_more, extra, extra),
            )
        } else {
            views.setViewVisibility(R.id.pulse_more, View.GONE)
        }
        views.setTextViewText(R.id.pulse_footer, surface.updatedLine(context))
        return views
    }

    companion object {
        private val CHILD_ROWS = intArrayOf(R.id.pulse_child_1, R.id.pulse_child_2, R.id.pulse_child_3)

        /** Opens the inbox when signed in, otherwise just the app. */
        fun openApp(context: Context, signedIn: Boolean): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                if (signedIn) data = Uri.parse("mamily://open/parent/inbox")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            return PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}
