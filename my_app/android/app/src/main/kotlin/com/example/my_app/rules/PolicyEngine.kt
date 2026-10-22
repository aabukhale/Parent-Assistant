package com.example.my_app.rules

import android.app.AlarmManager
import android.app.AppOpsManager
import android.app.PendingIntent
import android.app.admin.DevicePolicyManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Process
import android.provider.Telephony
import android.telecom.TelecomManager
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * Applies a compiled Mamily policy with Android's *supported* device-owner
 * APIs only:
 *
 *  - DevicePolicyManager.setPackagesSuspended (system "app paused" dialog)
 *  - Chrome managed configuration (URLBlocklist / URLAllowlist)
 *  - UsageStatsManager for daily limits (needs the Usage access permission)
 *
 * Without device-owner status nothing is enforced and the engine says so
 * ("unsupported"). No accessibility service, overlay or hidden API is used.
 *
 * The policy is stored locally so enforcement keeps working offline and
 * after reboot; an alarm re-evaluates at the next schedule boundary, pause
 * expiry, extra-time expiry, midnight, or every ~5 minutes while usage limits
 * are in play.
 */
class PolicyEngine(private val ctx: Context) {

    private val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val dpm = ctx.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    private val admin = ComponentName(ctx, MamilyDeviceAdminReceiver::class.java)
    private val pm = ctx.packageManager

    val isDeviceOwner: Boolean
        get() = dpm.isDeviceOwnerApp(ctx.packageName)

    fun hasUsageAccess(): Boolean {
        val ops = ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        @Suppress("DEPRECATION")
        val mode = if (Build.VERSION.SDK_INT >= 29) {
            ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName)
        } else {
            ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun chromeInstalled(): Boolean = try {
        pm.getPackageInfo(CHROME, 0); true
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }

    fun capabilities(): Map<String, String> {
        val owner = isDeviceOwner && Build.VERSION.SDK_INT >= 24
        val ownerCap = if (owner) "available" else "setup_needed"
        return mapOf(
            "app_blocking" to ownerCap,
            "schedules" to ownerCap,
            "restrict_now" to ownerCap,
            "app_limits" to when {
                !owner -> "setup_needed"
                !hasUsageAccess() -> "permission_needed"
                else -> "available"
            },
            "web_filter" to when {
                !owner -> "setup_needed"
                chromeInstalled() -> "available"
                else -> "unsupported"
            },
            "usage_reporting" to if (hasUsageAccess()) "available" else "permission_needed",
            // Mamily never offers a whole-device lock (lockNow only blanks the
            // screen and the child unlocks it again) — reported honestly.
            "device_lock" to "unsupported",
            // Not sent to the server's capability list (filtered there); used
            // on the phone to offer the "Alarms & reminders" setup step.
            "exact_alarms" to if (exactAlarmsAllowed()) "available" else "permission_needed",
        )
    }

    // ---- apply -------------------------------------------------------------

    data class Result(val status: String, val results: List<Map<String, String>>, val error: String? = null)

    /** Store a new policy (ignoring older versions) and enforce it now. */
    fun apply(policyJson: String): Result {
        val policy = JSONObject(policyJson)
        val version = policy.optInt("version", 0)
        val stored = prefs.getString(KEY_POLICY, null)?.let { JSONObject(it) }
        if (stored != null && stored.optInt("version", 0) > version) {
            // Out-of-order delivery: keep the newer policy.
            return evaluateAndEnforce("stale_policy")
        }
        prefs.edit().putString(KEY_POLICY, policyJson).apply()
        return evaluateAndEnforce("sync")
    }

    /** Re-evaluate the stored policy (alarm, boot, app start). */
    fun evaluateAndEnforce(trigger: String = "app"): Result {
        val policy = prefs.getString(KEY_POLICY, null)?.let { JSONObject(it) }
            ?: return Result("applied", emptyList())
        val version = policy.optInt("version", 0)
        if (!isDeviceOwner || Build.VERSION.SDK_INT < 24) {
            prefs.edit().putInt(KEY_APPLIED_VERSION, -1).apply()
            return Result(
                "unsupported",
                listOf(mapOf("rule" to "app_blocking", "state" to "setup_needed")),
            )
        }

        val now = ZonedDateTime.now(zone(policy))
        val results = mutableListOf<Map<String, String>>()
        val essentials = essentialPackages()
        val launchable = launchablePackages()
        val allowed = androidIds(policy.optJSONArray("allowed_apps"))
        val blocked = androidIds(policy.optJSONArray("blocked_apps"))

        val restrictAll = restrictNowActive(policy, now) || allowOnlyScheduleActive(policy, now) ||
            outsideAllowedWindow(policy, now)
        val usage = if (hasUsageAccess()) usageToday(now) else null
        val limitsInPlay = policy.optJSONArray("app_limits")?.length() ?: 0
        val allowanceToday = allowanceMinutes(policy, now)

        val target = mutableSetOf<String>()
        // Earliest moment a limit could run out with continuous use → next check.
        var soonestRunOutMs = Long.MAX_VALUE
        target += blocked
        if (blockListedScheduleActive(policy, now)) target += blocked
        if (restrictAll) target += (launchable - allowed)

        if (usage != null) {
            // Per-app / per-category daily limits.
            val limits = policy.optJSONArray("app_limits") ?: JSONArray()
            for (i in 0 until limits.length()) {
                val l = limits.getJSONObject(i)
                val minutes = l.optInt("minutes", Int.MAX_VALUE)
                val app = l.optJSONObject("app")
                if (app != null && app.optString("platform") == "android") {
                    val pkg = app.optString("id")
                    val left = minutes * 60_000L - (usage[pkg] ?: 0L)
                    if (left <= 0) target += pkg else soonestRunOutMs = minOf(soonestRunOutMs, left)
                } else if (l.has("category")) {
                    val cat = l.optString("category")
                    val members = launchable.filter { categoryOf(it) == cat }
                    val used = members.sumOf { usage[it] ?: 0L }
                    val left = minutes * 60_000L - used
                    if (left <= 0) target += members else soonestRunOutMs = minOf(soonestRunOutMs, left)
                }
            }
            // Total daily allowance (+ approved extra time).
            if (allowanceToday != null) {
                val total = launchable.filter { it !in essentials && it !in allowed }.sumOf { usage[it] ?: 0L }
                val left = allowanceToday * 60_000L - total
                if (left <= 0) target += (launchable - allowed) else soonestRunOutMs = minOf(soonestRunOutMs, left)
            }
        } else if (limitsInPlay > 0 || allowanceToday != null) {
            results += mapOf("rule" to "app_limits", "state" to "permission_needed")
        }

        target -= essentials
        target -= ctx.packageName
        setSupportMessage()

        val previous = prefs.getStringSet(KEY_SUSPENDED, emptySet())!!.toSet()
        val toRelease = previous - target
        if (toRelease.isNotEmpty()) {
            dpm.setPackagesSuspended(admin, toRelease.toTypedArray(), false)
        }
        val failed = if (target.isNotEmpty()) {
            dpm.setPackagesSuspended(admin, target.toTypedArray(), true).toSet()
        } else emptySet()
        // Packages the system refused (e.g. the default dialer) stay usable.
        val suspended = target - failed
        prefs.edit().putStringSet(KEY_SUSPENDED, suspended).apply()
        for (f in failed) results += mapOf("rule" to "app:$f", "state" to "not_suspendable")

        val timed = policy.optJSONObject("restrict_now") != null || (policy.optJSONArray("schedules")?.length() ?: 0) > 0
        if (timed && !exactAlarmsAllowed()) results += mapOf("rule" to "timing", "state" to "approximate")
        val web = applyWeb(policy.optJSONObject("web"))
        if (web != null) results += web

        prefs.edit().putInt(KEY_APPLIED_VERSION, version).putLong(KEY_EVALUATED_AT, System.currentTimeMillis()).apply()
        scheduleNext(
            policy, now, usage != null && (limitsInPlay > 0 || allowanceToday != null),
            if (soonestRunOutMs == Long.MAX_VALUE) null else soonestRunOutMs,
        )

        android.util.Log.i(
            "MamilyRules",
            "evaluate trigger=$trigger version=$version suspended=${suspended.size} restrictAll=$restrictAll",
        )
        val partial = results.any { it["state"] == "permission_needed" || it["state"] == "unsupported" } ||
            failed.any { it in blocked }
        return Result(if (partial) "partial" else "applied", results)
    }

    /**
     * Android shows its own "Blocked by …" title for suspended apps; the line
     * underneath is this admin support message, so it names Mamily and the
     * parent instead of an "IT admin".
     */
    private fun setSupportMessage() {
        val lang = ctx.resources.configuration.locales[0].language
        val msg = when (lang) {
            "ar" -> "أوقف والدك هذا التطبيق مؤقتاً في Mamily. يمكنك طلب وقت إضافي من تطبيق Mamily."
            "he" -> "ההורה השהה את האפליקציה הזו ב-Mamily. אפשר לבקש עוד זמן באפליקציית Mamily."
            else -> "Your parent paused this app in Mamily. You can ask for more time in the Mamily app."
        }
        try {
            dpm.setShortSupportMessage(admin, msg)
        } catch (_: Exception) {
        }
    }

    private fun applyWeb(web: JSONObject?): Map<String, String>? {
        val mode = web?.optString("mode", "off") ?: "off"
        if (!chromeInstalled()) {
            return if (mode == "off") null else mapOf("rule" to "web_filter", "state" to "unsupported")
        }
        val bundle = Bundle()
        when (mode) {
            "block_listed" -> bundle.putStringArray("URLBlocklist", strings(web?.optJSONArray("blocked_domains")))
            "approved_only" -> {
                bundle.putStringArray("URLBlocklist", arrayOf("*"))
                bundle.putStringArray("URLAllowlist", strings(web?.optJSONArray("allowed_domains")))
            }
        }
        dpm.setApplicationRestrictions(admin, CHROME, bundle)
        prefs.edit().putBoolean(KEY_WEB, mode != "off").apply()
        return null
    }

    /** True when every package we meant to suspend is still suspended. */
    fun verify(version: Int): Boolean {
        if (!isDeviceOwner || Build.VERSION.SDK_INT < 24) return false
        if (prefs.getInt(KEY_APPLIED_VERSION, -1) < version) return false
        val suspended = prefs.getStringSet(KEY_SUSPENDED, emptySet())!!
        return suspended.all {
            try {
                dpm.isPackageSuspended(admin, it)
            } catch (_: PackageManager.NameNotFoundException) {
                true // uninstalled → nothing to enforce
            }
        }
    }

    fun enforcementActive(): Boolean = isDeviceOwner && prefs.getString(KEY_POLICY, null) != null

    /**
     * Remove everything Mamily applied. With [releaseOwner] (the parent
     * unpaired this phone) Mamily also gives up device-owner status so the
     * family keeps full control of the phone and can uninstall the app.
     */
    fun clear(releaseOwner: Boolean) {
        if (isDeviceOwner && Build.VERSION.SDK_INT >= 24) {
            val suspended = prefs.getStringSet(KEY_SUSPENDED, emptySet())!!
            if (suspended.isNotEmpty()) dpm.setPackagesSuspended(admin, suspended.toTypedArray(), false)
            if (prefs.getBoolean(KEY_WEB, false)) dpm.setApplicationRestrictions(admin, CHROME, Bundle())
        }
        cancelAlarm()
        prefs.edit().clear().apply()
        if (releaseOwner && isDeviceOwner) {
            @Suppress("DEPRECATION")
            dpm.clearDeviceOwnerApp(ctx.packageName)
        }
    }

    // ---- inventory & usage ---------------------------------------------------

    /** Apps a parent can choose. Essentials are left out: they're never paused. */
    fun installedApps(): List<Map<String, String>> {
        val essentials = essentialPackages()
        return launchablePackages()
            .filter { it != ctx.packageName && it !in essentials }
        .mapNotNull { pkg ->
            try {
                val ai = pm.getApplicationInfo(pkg, 0)
                mapOf("id" to pkg, "name" to pm.getApplicationLabel(ai).toString().take(80), "category" to categoryOf(pkg))
            } catch (_: Exception) {
                null
            }
        }
            .sortedBy { it["name"]?.lowercase() }
    }

    /** Foreground sessions per app since [fromMs], for /child/usage. */
    fun usageSince(fromMs: Long): List<Map<String, Any?>> {
        if (!hasUsageAccess()) return emptyList()
        val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        // Re-read a few hours before the last upload so a session that was
        // still open then is captured whole; the server ignores duplicates
        // (client_event_id = package + start time).
        val events = usm.queryEvents(maxOf(fromMs - 6 * 3_600_000L, now - 2 * 86_400_000L), now)
        val open = mutableMapOf<String, Long>()
        val out = mutableListOf<Map<String, Any?>>()
        val e = UsageEvents.Event()
        // Same definition of "screen time" as enforcement: calls, messages,
        // settings, the home screen and Mamily itself don't count.
        val skip = essentialPackages()
        while (events.hasNextEvent()) {
            events.getNextEvent(e)
            val pkg = e.packageName ?: continue
            if (pkg in skip) continue
            when (e.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> open.putIfAbsent(pkg, e.timeStamp)
                UsageEvents.Event.ACTIVITY_PAUSED, UsageEvents.Event.ACTIVITY_STOPPED -> {
                    val start = open.remove(pkg) ?: continue
                    val secs = (e.timeStamp - start) / 1000
                    if (secs >= 1) out += session(pkg, start, e.timeStamp, secs)
                }
            }
        }
        return out
    }

    private fun session(pkg: String, start: Long, end: Long, secs: Long): Map<String, Any?> {
        val label = try {
            pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
        } catch (_: Exception) {
            pkg
        }
        return mapOf(
            "app_identifier" to pkg,
            "app_name" to label.take(190),
            "category" to when (categoryOf(pkg)) {
                "games" -> "game"
                "social", "messaging" -> "social"
                "video" -> "video"
                "education" -> "education"
                else -> "other"
            },
            "started_at" to Instant.ofEpochMilli(start).toString(),
            "ended_at" to Instant.ofEpochMilli(end).toString(),
            "used_seconds" to secs.coerceAtMost(86_400),
            "source" to "device",
            "client_event_id" to "$pkg:$start",
        )
    }

    /**
     * Foreground time per app since local midnight, from raw usage events so
     * the app that is open *right now* counts too (aggregated stats only add a
     * session once it ends, so a child staying in one app would never hit the
     * limit).
     */
    private fun usageToday(now: ZonedDateTime): Map<String, Long> {
        val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val start = now.toLocalDate().atStartOfDay(now.zone).toInstant().toEpochMilli()
        val end = System.currentTimeMillis()
        val events = usm.queryEvents(start, end)
        val open = mutableMapOf<String, Long>()
        val total = mutableMapOf<String, Long>()
        val e = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(e)
            val pkg = e.packageName ?: continue
            when (e.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> open.putIfAbsent(pkg, e.timeStamp)
                UsageEvents.Event.ACTIVITY_PAUSED, UsageEvents.Event.ACTIVITY_STOPPED -> {
                    val from = open.remove(pkg) ?: continue
                    total[pkg] = (total[pkg] ?: 0L) + (e.timeStamp - from)
                }
            }
        }
        for ((pkg, from) in open) total[pkg] = (total[pkg] ?: 0L) + (end - from)
        return total
    }

    // ---- policy evaluation ---------------------------------------------------

    private fun zone(p: JSONObject): ZoneId = try {
        ZoneId.of(p.optString("timezone", "UTC"))
    } catch (_: Exception) {
        ZoneId.systemDefault()
    }

    private fun restrictNowActive(p: JSONObject, now: ZonedDateTime): Boolean {
        val r = p.optJSONObject("restrict_now") ?: return false
        val until = r.optString("until", "")
        return until.isEmpty() || until == "null" || Instant.parse(until).isAfter(now.toInstant())
    }

    private fun activeSchedules(p: JSONObject, now: ZonedDateTime): List<JSONObject> {
        val arr = p.optJSONArray("schedules") ?: return emptyList()
        val out = mutableListOf<JSONObject>()
        for (i in 0 until arr.length()) {
            val s = arr.getJSONObject(i)
            if (!s.optBoolean("enabled", true)) continue
            if (windowEnd(s, now) != null) out += s
        }
        return out
    }

    /** If schedule [s] covers [now], when it ends (windows belong to their start day). */
    private fun windowEnd(s: JSONObject, now: ZonedDateTime): ZonedDateTime? {
        val days = (0 until (s.optJSONArray("days")?.length() ?: 0)).map { s.getJSONArray("days").getInt(it) }
        val start = LocalTime.parse(s.getString("start"))
        val end = LocalTime.parse(s.getString("end"))
        for (back in 0L..1L) {
            val day: LocalDate = now.toLocalDate().minusDays(back)
            if (day.dayOfWeek.value !in days) continue
            val from = day.atTime(start).atZone(now.zone)
            var to = day.atTime(end).atZone(now.zone)
            if (!to.isAfter(from)) to = day.plusDays(1).atTime(end).atZone(now.zone)
            if (!now.isBefore(from) && now.isBefore(to)) return to
        }
        return null
    }

    private fun allowOnlyScheduleActive(p: JSONObject, now: ZonedDateTime) =
        activeSchedules(p, now).any { it.optString("restriction") == "allow_only" }

    private fun blockListedScheduleActive(p: JSONObject, now: ZonedDateTime) =
        activeSchedules(p, now).any { it.optString("restriction") == "block_listed" }

    private fun todayAllowance(p: JSONObject, now: ZonedDateTime): JSONObject? =
        p.optJSONObject("daily_allowance")?.optJSONObject(now.dayOfWeek.value.toString())

    private fun outsideAllowedWindow(p: JSONObject, now: ZonedDateTime): Boolean {
        val a = todayAllowance(p, now) ?: return false
        val s = a.optString("window_start", ""); val e = a.optString("window_end", "")
        if (s.isEmpty() || s == "null" || e.isEmpty() || e == "null") return false
        val t = now.toLocalTime()
        val from = LocalTime.parse(s); val to = LocalTime.parse(e)
        return if (from.isBefore(to)) t.isBefore(from) || !t.isBefore(to) else (!t.isBefore(to) && t.isBefore(from))
    }

    private fun allowanceMinutes(p: JSONObject, now: ZonedDateTime): Int? {
        val a = todayAllowance(p, now) ?: return null
        var minutes = a.optInt("minutes", -1)
        if (minutes < 0) return null
        val bonus = p.optJSONArray("bonus") ?: JSONArray()
        for (i in 0 until bonus.length()) {
            val b = bonus.getJSONObject(i)
            val startsAt = Instant.parse(b.getString("starts_at"))
            val expires = Instant.parse(b.getString("expires_at"))
            if (!now.toInstant().isBefore(startsAt) && now.toInstant().isBefore(expires)) minutes += b.optInt("minutes", 0)
        }
        return minutes
    }

    // ---- alarms ------------------------------------------------------------

    private fun scheduleNext(p: JSONObject, now: ZonedDateTime, pollUsage: Boolean, runOutMs: Long?) {
        val candidates = mutableListOf<ZonedDateTime>()
        candidates += now.toLocalDate().plusDays(1).atStartOfDay(now.zone)
        p.optJSONObject("restrict_now")?.optString("until")?.takeIf { it.isNotEmpty() && it != "null" }?.let {
            candidates += Instant.parse(it).atZone(now.zone)
        }
        p.optJSONArray("bonus")?.let { b ->
            for (i in 0 until b.length()) candidates += Instant.parse(b.getJSONObject(i).getString("expires_at")).atZone(now.zone)
        }
        val arr = p.optJSONArray("schedules") ?: JSONArray()
        for (i in 0 until arr.length()) {
            val s = arr.getJSONObject(i)
            windowEnd(s, now)?.let { candidates += it }
            for (d in 0L..2L) {
                val day = now.toLocalDate().plusDays(d)
                candidates += day.atTime(LocalTime.parse(s.getString("start"))).atZone(now.zone)
            }
        }
        if (pollUsage) candidates += now.plusMinutes(5)
        // Usage only grows while an app is open, so this is the earliest a
        // limit can be reached; check again right then (plus 5 s).
        if (runOutMs != null) candidates += now.plusNanos((runOutMs + 5_000L) * 1_000_000L)
        val next = candidates.filter { it.isAfter(now) }.minOrNull() ?: return
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val at = next.toInstant().toEpochMilli() + 1_000
        // Exact only with the "Alarms & reminders" special access (Android 12+);
        // otherwise Android may run it a few minutes late, which the parent
        // is told (rule "timing" = approximate).
        if (exactAlarmsAllowed()) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, alarmIntent())
        } else {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, alarmIntent())
        }
        prefs.edit().putLong(KEY_NEXT_ALARM, next.toInstant().toEpochMilli()).apply()
    }

    fun exactAlarmsAllowed(): Boolean = Build.VERSION.SDK_INT < 31 ||
        (ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager).canScheduleExactAlarms()

    private fun cancelAlarm() {
        (ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(alarmIntent())
    }

    private fun alarmIntent(): PendingIntent = PendingIntent.getBroadcast(
        ctx, 7001, Intent(ctx, RulesAlarmReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    // ---- packages ----------------------------------------------------------

    fun launchablePackages(): Set<String> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        @Suppress("DEPRECATION")
        return pm.queryIntentActivities(intent, PackageManager.MATCH_ALL).map { it.activityInfo.packageName }.toSet()
    }

    /** Never paused: phone, SMS, emergency, settings, launcher, Mamily. */
    fun essentialPackages(): Set<String> {
        val out = mutableSetOf(ctx.packageName, "com.android.settings", "com.android.phone", "com.android.emergency",
            "com.android.systemui", "com.google.android.dialer", "com.android.dialer", "com.android.contacts")
        try {
            (ctx.getSystemService(Context.TELECOM_SERVICE) as TelecomManager).defaultDialerPackage?.let { out += it }
        } catch (_: Exception) {}
        Telephony.Sms.getDefaultSmsPackage(ctx)?.let { out += it }
        val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        pm.resolveActivity(home, 0)?.activityInfo?.packageName?.let { out += it }
        return out
    }

    private fun browsers(): Set<String> {
        val i = Intent(Intent.ACTION_VIEW, Uri.parse("https://example.com"))
        @Suppress("DEPRECATION")
        return pm.queryIntentActivities(i, PackageManager.MATCH_ALL).map { it.activityInfo.packageName }.toSet()
    }

    private var browserCache: Set<String>? = null

    fun categoryOf(pkg: String): String {
        val b = browserCache ?: browsers().also { browserCache = it }
        if (pkg in b) return "browsers"
        if (Build.VERSION.SDK_INT < 26) return "other"
        val cat = try {
            pm.getApplicationInfo(pkg, 0).category
        } catch (_: Exception) {
            ApplicationInfo.CATEGORY_UNDEFINED
        }
        return when (cat) {
            ApplicationInfo.CATEGORY_GAME -> "games"
            ApplicationInfo.CATEGORY_SOCIAL -> "social"
            ApplicationInfo.CATEGORY_VIDEO -> "video"
            else -> "other"
        }
    }

    private fun androidIds(arr: JSONArray?): Set<String> {
        if (arr == null) return emptySet()
        val out = mutableSetOf<String>()
        for (i in 0 until arr.length()) {
            val a = arr.getJSONObject(i)
            if (a.optString("platform") == "android") out += a.optString("id")
        }
        return out
    }

    private fun strings(arr: JSONArray?): Array<String> =
        if (arr == null) emptyArray() else Array(arr.length()) { arr.getString(it) }

    companion object {
        const val PREFS = "mamily_device_rules"
        private const val KEY_POLICY = "policy"
        private const val KEY_SUSPENDED = "suspended"
        private const val KEY_APPLIED_VERSION = "applied_version"
        private const val KEY_EVALUATED_AT = "evaluated_at"
        private const val KEY_WEB = "web_applied"
        private const val KEY_NEXT_ALARM = "next_alarm"
        private const val CHROME = "com.android.chrome"
    }
}
