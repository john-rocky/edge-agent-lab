package io.github.johnrocky.phoneagent

import android.content.ActivityNotFoundException
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.provider.AlarmClock
import android.provider.CalendarContract
import com.google.gson.Gson
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * The tools the agent can call. Every one of them does the real thing on this phone: the alarm
 * lands in the Clock app, the event in the calendar provider (visible in the Calendar app), the
 * timer in the Clock app. Nothing is simulated; a tool that cannot do its job says so in its result.
 */
class PhoneTools(private val ctx: Context) {
    data class Param(val name: String, val type: String, val description: String)
    data class Spec(val name: String, val description: String, val params: List<Param>)

    val specs = listOf(
        Spec("get_current_datetime", "Returns the current local date and time, including the day of the week.", emptyList()),
        Spec("get_calendar_events", "Lists the events already on the phone calendar for one day.",
            listOf(Param("date", "string", "The day to list, as YYYY-MM-DD."))),
        Spec("set_alarm", "Sets an alarm on this phone.",
            listOf(Param("hour", "integer", "Hour in 24-hour time (0-23)."),
                Param("minute", "integer", "Minute (0-59)."),
                Param("label", "string", "Short label shown with the alarm."))),
        Spec("add_calendar_event", "Adds an event to the phone calendar.",
            listOf(Param("title", "string", "Event title."),
                Param("start", "string", "Start time as YYYY-MM-DD HH:MM."),
                Param("end", "string", "End time as YYYY-MM-DD HH:MM."),
                Param("location", "string", "Where the event takes place."))),
        Spec("set_timer", "Starts a countdown timer on this phone.",
            listOf(Param("minutes", "integer", "Length of the timer in minutes."),
                Param("label", "string", "Short label shown with the timer."))),
    )

    /** OpenAI-style function list, the shape the vendor chat template renders with `tool.function | tojson`. */
    fun descriptions(): List<Map<String, Any>> = specs.map { s ->
        mapOf(
            "type" to "function",
            "function" to mapOf(
                "name" to s.name,
                "description" to s.description,
                "parameters" to mapOf(
                    "type" to "object",
                    "properties" to s.params.associate { p -> p.name to mapOf("type" to p.type, "description" to p.description) },
                    "required" to s.params.map { it.name },
                ),
            ),
        )
    }

    fun icon(name: String): String = when (name) {
        "get_current_datetime" -> "🕒"; "get_calendar_events" -> "📅"; "set_alarm" -> "⏰"
        "add_calendar_event" -> "📆"; "set_timer" -> "⏳"; else -> "🔧"
    }

    fun call(name: String, args: Map<String, Any?>): String = try {
        when (name) {
            "get_current_datetime" -> currentDatetime()
            "get_calendar_events" -> calendarEvents(str(args, "date"))
            "set_alarm" -> setAlarm(int(args, "hour"), int(args, "minute"), str(args, "label"))
            "add_calendar_event" -> addCalendarEvent(str(args, "title"), str(args, "start"), str(args, "end"), str(args, "location"))
            "set_timer" -> setTimer(int(args, "minutes"), str(args, "label"))
            else -> "Error: unknown tool $name"
        }
    } catch (e: Exception) {
        "Error: ${e.message ?: e.javaClass.simpleName}"
    }

    private fun str(a: Map<String, Any?>, k: String): String = a[k]?.toString() ?: throw IllegalArgumentException("missing $k")
    private fun int(a: Map<String, Any?>, k: String): Int = when (val v = a[k]) {
        is Number -> v.toInt()
        is String -> v.trim().toDouble().toInt()
        else -> throw IllegalArgumentException("missing $k")
    }

    private val fmtDay = SimpleDateFormat("EEEE, yyyy-MM-dd HH:mm", Locale.US)
    private val fmtMin = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.US)

    private fun currentDatetime(): String = fmtDay.format(Date())

    private fun parseMinute(s: String): Long {
        val t = s.trim().replace('T', ' ').take(16)
        return fmtMin.parse(t)?.time ?: throw IllegalArgumentException("bad time '$s' (use YYYY-MM-DD HH:MM)")
    }

    private fun calendarEvents(date: String): String {
        val day = SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(date.trim().take(10))
            ?: throw IllegalArgumentException("bad date '$date' (use YYYY-MM-DD)")
        val begin = day.time
        val end = begin + 24L * 3600 * 1000
        val uri = CalendarContract.Instances.CONTENT_URI.buildUpon()
            .appendPath(begin.toString()).appendPath(end.toString()).build()
        val proj = arrayOf(CalendarContract.Instances.TITLE, CalendarContract.Instances.BEGIN,
            CalendarContract.Instances.END, CalendarContract.Instances.EVENT_LOCATION)
        val rows = mutableListOf<Map<String, String>>()
        ctx.contentResolver.query(uri, proj, CalendarContract.Instances.CALENDAR_ID + "=?",
            arrayOf(calendarId().toString()), CalendarContract.Instances.BEGIN + " ASC")?.use { c ->
            while (c.moveToNext()) {
                rows.add(mapOf(
                    "title" to (c.getString(0) ?: ""),
                    "start" to fmtMin.format(Date(c.getLong(1))),
                    "end" to fmtMin.format(Date(c.getLong(2))),
                    "location" to (c.getString(3) ?: ""),
                ))
            }
        }
        return if (rows.isEmpty()) "No events on ${date.trim().take(10)}" else Gson().toJson(rows)
    }

    private fun setAlarm(hour: Int, minute: Int, label: String): String {
        require(hour in 0..23 && minute in 0..59) { "hour must be 0-23 and minute 0-59" }
        val i = Intent(AlarmClock.ACTION_SET_ALARM)
            .putExtra(AlarmClock.EXTRA_HOUR, hour)
            .putExtra(AlarmClock.EXTRA_MINUTES, minute)
            .putExtra(AlarmClock.EXTRA_MESSAGE, label)
            .putExtra(AlarmClock.EXTRA_SKIP_UI, true)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            ctx.startActivity(i)
            "Alarm set for %02d:%02d (%s)".format(hour, minute, label)
        } catch (e: ActivityNotFoundException) {
            "Error: no clock app can set alarms on this phone"
        }
    }

    private fun setTimer(minutes: Int, label: String): String {
        require(minutes in 1..1440) { "minutes must be 1-1440" }
        val i = Intent(AlarmClock.ACTION_SET_TIMER)
            .putExtra(AlarmClock.EXTRA_LENGTH, minutes * 60)
            .putExtra(AlarmClock.EXTRA_MESSAGE, label)
            .putExtra(AlarmClock.EXTRA_SKIP_UI, true)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            ctx.startActivity(i)
            "Timer started: $minutes min ($label)"
        } catch (e: ActivityNotFoundException) {
            "Error: no clock app can start timers on this phone"
        }
    }

    /**
     * The agent reads and writes one calendar: its own local "Phone Agent" calendar (created on first
     * use). It never touches an account calendar, so a demo cannot leak or alter someone's real schedule.
     */
    fun calendarId(): Long {
        val proj = arrayOf(CalendarContract.Calendars._ID)
        ctx.contentResolver.query(CalendarContract.Calendars.CONTENT_URI, proj,
            CalendarContract.Calendars.ACCOUNT_TYPE + "=? AND " + CalendarContract.Calendars.NAME + "=?",
            arrayOf(CalendarContract.ACCOUNT_TYPE_LOCAL, CAL_NAME), null)?.use { c ->
            if (c.moveToFirst()) return c.getLong(0)
        }
        val uri = CalendarContract.Calendars.CONTENT_URI.buildUpon()
            .appendQueryParameter(CalendarContract.CALLER_IS_SYNCADAPTER, "true")
            .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_NAME, CAL_NAME)
            .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_TYPE, CalendarContract.ACCOUNT_TYPE_LOCAL)
            .build()
        val v = ContentValues().apply {
            put(CalendarContract.Calendars.ACCOUNT_NAME, CAL_NAME)
            put(CalendarContract.Calendars.ACCOUNT_TYPE, CalendarContract.ACCOUNT_TYPE_LOCAL)
            put(CalendarContract.Calendars.NAME, CAL_NAME)
            put(CalendarContract.Calendars.CALENDAR_DISPLAY_NAME, CAL_NAME)
            put(CalendarContract.Calendars.CALENDAR_COLOR, 0xFF58A6FF.toInt())
            put(CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL, CalendarContract.Calendars.CAL_ACCESS_OWNER)
            put(CalendarContract.Calendars.OWNER_ACCOUNT, CAL_NAME)
            put(CalendarContract.Calendars.VISIBLE, 1)
            put(CalendarContract.Calendars.SYNC_EVENTS, 1)
        }
        val row = ctx.contentResolver.insert(uri, v) ?: throw IllegalStateException("could not create a calendar")
        return ContentUris.parseId(row)
    }

    private fun addCalendarEvent(title: String, start: String, end: String, location: String): String {
        val s = parseMinute(start)
        val e = parseMinute(end)
        require(e > s) { "end must be after start" }
        val v = ContentValues().apply {
            put(CalendarContract.Events.CALENDAR_ID, calendarId())
            put(CalendarContract.Events.TITLE, title)
            put(CalendarContract.Events.EVENT_LOCATION, location)
            put(CalendarContract.Events.DTSTART, s)
            put(CalendarContract.Events.DTEND, e)
            put(CalendarContract.Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
        }
        ctx.contentResolver.insert(CalendarContract.Events.CONTENT_URI, v)
            ?: throw IllegalStateException("calendar refused the event")
        return "Event '$title' added: ${fmtMin.format(Date(s))} to ${fmtMin.format(Date(e))} at $location"
    }

    /** What Android itself reports after the run: the next alarm the OS will fire, and the agent's calendar for tomorrow. */
    fun phoneState(): String {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        val next = am.nextAlarmClock?.let { SimpleDateFormat("EEE HH:mm", Locale.US).format(Date(it.triggerTime)) } ?: "none"
        val day = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(tomorrowNoon()))
        val events = try {
            val raw = calendarEvents(day)
            if (raw.startsWith("No events")) "none" else
                com.google.gson.JsonParser.parseString(raw).asJsonArray.joinToString("\n") { e ->
                    val o = e.asJsonObject
                    "   ${o["start"].asString.takeLast(5)}–${o["end"].asString.takeLast(5)}  ${o["title"].asString}"
                }
        } catch (e: Exception) { "?" }
        return "⏰ Next alarm (Android): $next\n📅 Calendar, $day:\n$events"
    }

    /** Intents the UI offers after a run, so the viewer can see the state the agent changed. */
    fun showAlarms(): Intent = Intent(AlarmClock.ACTION_SHOW_ALARMS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    fun showCalendar(atMillis: Long): Intent = Intent(Intent.ACTION_VIEW)
        .setData(CalendarContract.CONTENT_URI.buildUpon().appendPath("time").appendPath(atMillis.toString()).build())
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

    /** Demo fixture: two events on the agent's own calendar for tomorrow, added once (by title). */
    fun seedTomorrow(): String {
        val day = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(tomorrowNoon()))
        val existing = calendarEvents(day)
        var added = 0
        for ((title, start, end, loc) in listOf(
            listOf("Team standup", "$day 09:00", "$day 09:15", "Office, room 4"),
            listOf("Dentist", "$day 17:00", "$day 17:45", "Smile Clinic"))) {
            if (!existing.contains("\"title\":\"$title\"")) { addCalendarEvent(title, start, end, loc); added++ }
        }
        return "seeded $added events on $day"
    }

    /** Removes everything the demo created on the calendar side (the alarm is removed in the Clock app). */
    fun wipeOwnCalendar(): String {
        val n = ctx.contentResolver.delete(CalendarContract.Calendars.CONTENT_URI.buildUpon()
            .appendQueryParameter(CalendarContract.CALLER_IS_SYNCADAPTER, "true")
            .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_NAME, CAL_NAME)
            .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_TYPE, CalendarContract.ACCOUNT_TYPE_LOCAL).build(),
            CalendarContract.Calendars.NAME + "=?", arrayOf(CAL_NAME))
        return "deleted $n calendar(s)"
    }

    companion object {
        const val CAL_NAME = "Phone Agent"
        fun tomorrowNoon(): Long = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1); set(Calendar.HOUR_OF_DAY, 12); set(Calendar.MINUTE, 0)
        }.timeInMillis
    }
}
