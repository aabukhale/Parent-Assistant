package com.example.my_app

import android.content.Context
import android.text.format.DateUtils
import org.json.JSONObject
import java.time.Instant

/**
 * The Family Pulse surface payload written by the Flutter app
 * (`GET /families/{f}/pulse/surface`, key `mamily_surface`).
 *
 * The server already removed everything the parent chose not to show (names,
 * mood and points are off by default), so this only renders what is present.
 * Shared by the home-screen widget and the floating card.
 */
data class PulseSurface(
    val pendingTotal: Int?,
    val children: List<Child>,
    val generatedAtMillis: Long?,
) {
    data class Child(
        val index: Int,
        val label: String?,
        val avatarKey: String?,
        val tasksDone: Int?,
        val tasksTotal: Int?,
        val pending: Int?,
        val mood: String?,
        val points: Int?,
        val routineProgress: Double?,
        val contactState: String?,
    )

    /** Older than this, the surface says so instead of looking live. */
    fun isStale(now: Long = System.currentTimeMillis()): Boolean =
        generatedAtMillis == null || now - generatedAtMillis > STALE_AFTER_MS

    fun updatedLine(context: Context, now: Long = System.currentTimeMillis()): String {
        if (isStale(now)) return context.getString(R.string.pulse_stale)
        // Never "in 0 minutes": server and device clocks can differ slightly.
        val at = minOf(generatedAtMillis!!, now)
        if (now - at < DateUtils.MINUTE_IN_MILLIS) {
            return context.getString(R.string.pulse_updated_just_now)
        }
        val ago = DateUtils.getRelativeTimeSpanString(
            at, now, DateUtils.MINUTE_IN_MILLIS,
        ).toString()
        return context.getString(R.string.pulse_updated, ago)
    }

    fun headline(context: Context): String {
        val pending = pendingTotal ?: return context.getString(R.string.pulse_title)
        return if (pending == 0) {
            context.getString(R.string.pulse_all_caught_up)
        } else {
            context.resources.getQuantityString(R.plurals.pulse_waiting, pending, pending)
        }
    }

    fun childLine(context: Context, c: Child): String {
        val parts = mutableListOf<String>()
        val name = c.label ?: context.getString(R.string.pulse_child_fallback, c.index)
        parts += listOfNotNull(avatarEmoji(c.avatarKey), name).joinToString(" ")
        if (c.tasksDone != null && c.tasksTotal != null) {
            parts += context.resources.getQuantityString(
                R.plurals.pulse_tasks, c.tasksTotal, c.tasksDone, c.tasksTotal,
            )
        }
        if (c.routineProgress != null) {
            parts += context.getString(
                R.string.pulse_routine, (c.routineProgress * 100).toInt(),
            )
        }
        if (c.pending != null && c.pending > 0) {
            parts += context.resources.getQuantityString(
                R.plurals.pulse_to_review, c.pending, c.pending,
            )
        }
        c.mood?.let { parts += moodEmoji(it) }
        c.points?.let { parts += context.getString(R.string.pulse_points, it) }
        if (c.contactState == "offline") parts += context.getString(R.string.pulse_no_contact)
        return parts.joinToString(context.getString(R.string.pulse_separator))
    }

    companion object {
        const val DATA_KEY = "mamily_surface"
        private const val STALE_AFTER_MS = 2 * 60 * 60 * 1000L

        fun parse(raw: String?): PulseSurface? {
            if (raw.isNullOrBlank()) return null
            return try {
                val json = JSONObject(raw)
                val list = json.optJSONArray("children")
                val children = (0 until (list?.length() ?: 0)).map { i ->
                    val c = list!!.getJSONObject(i)
                    Child(
                        index = c.optInt("index", i + 1),
                        label = c.optStringOrNull("label"),
                        avatarKey = c.optStringOrNull("avatar_key"),
                        tasksDone = c.optIntOrNull("tasks_done"),
                        tasksTotal = c.optIntOrNull("tasks_total"),
                        pending = c.optIntOrNull("pending_approvals"),
                        mood = c.optStringOrNull("mood"),
                        points = c.optIntOrNull("points"),
                        routineProgress = if (c.has("routine_progress")) c.optDouble("routine_progress") else null,
                        contactState = c.optStringOrNull("last_contact_state"),
                    )
                }
                PulseSurface(
                    pendingTotal = json.optIntOrNull("pending_total"),
                    children = children,
                    // The device's own write time: comparable with the device
                    // clock (the server's generated_at may be skewed).
                    generatedAtMillis = (json.optStringOrNull("written_at")
                        ?: json.optStringOrNull("generated_at"))?.let {
                        runCatching { Instant.parse(it).toEpochMilli() }.getOrNull()
                    },
                )
            } catch (_: Exception) {
                null
            }
        }

        private fun JSONObject.optStringOrNull(key: String): String? =
            if (has(key) && !isNull(key)) optString(key) else null

        private fun JSONObject.optIntOrNull(key: String): Int? =
            if (has(key) && !isNull(key)) optInt(key) else null

        /** Mirrors `ChildAvatar.emoji` in the Flutter app. */
        fun avatarEmoji(key: String?): String? = when (key) {
            "cat" -> "🐱"
            "bunny" -> "🐰"
            "panda" -> "🐼"
            "lion" -> "🦁"
            "whale" -> "🐳"
            "dino" -> "🦕"
            "robot" -> "🤖"
            "unicorn" -> "🦄"
            "astronaut" -> "🧑‍🚀"
            else -> null
        }

        /** Mirrors `moodEmoji` in the Flutter app. */
        fun moodEmoji(mood: String): String = when (mood) {
            "great" -> "🤩"
            "happy" -> "😊"
            "tired" -> "🥱"
            "sad" -> "😢"
            "worried" -> "😟"
            "angry" -> "😠"
            else -> "🙂"
        }
    }
}
