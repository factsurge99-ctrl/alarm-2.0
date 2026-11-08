package com.mistressalarm.app

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val channel = "com.mistressalarm/alarms"
    private var alarmEvents: MethodChannel? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createChannel(this)
        alarmEvents = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
        alarmEvents?.setMethodCallHandler { call, result ->
            when (call.method) {
                "saveAlarms" -> {
                    val raw = call.argument<String>("alarms") ?: "[]"
                    getSharedPreferences("mistress_alarm", Context.MODE_PRIVATE).edit().putString("alarms", raw).apply()
                    if (Build.VERSION.SDK_INT < 31 || getSystemService(AlarmManager::class.java).canScheduleExactAlarms()) AlarmScheduler.rescheduleAll(this)
                    result.success(true)
                }
                "hasExactAlarmPermission" -> result.success(Build.VERSION.SDK_INT < 31 || getSystemService(AlarmManager::class.java).canScheduleExactAlarms())
                "requestExactAlarmPermission" -> {
                    if (Build.VERSION.SDK_INT >= 31 && !getSystemService(AlarmManager::class.java).canScheduleExactAlarms()) {
                        startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName")))
                    }
                    result.success(true)
                }
                "hasNotificationPermission" -> result.success(Build.VERSION.SDK_INT < 33 || checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == android.content.pm.PackageManager.PERMISSION_GRANTED)
                "hasFullScreenIntentPermission" -> result.success(Build.VERSION.SDK_INT < 34 || getSystemService(android.app.NotificationManager::class.java).canUseFullScreenIntent())
                "requestFullScreenIntentPermission" -> {
                    if (Build.VERSION.SDK_INT >= 34 && !getSystemService(android.app.NotificationManager::class.java).canUseFullScreenIntent()) {
                        startActivity(Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:$packageName")))
                    }
                    result.success(true)
                }
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                        requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 7381)
                    }
                    result.success(true)
                }
                "stopRinging" -> { AlarmRingingService.stop(this); result.success(true) }
                "snooze" -> {
                    val minutes = call.argument<Int>("minutes") ?: 5
                    AlarmScheduler.scheduleSnooze(this, minutes)
                    AlarmRingingService.stop(this)
                    result.success(true)
                }
                "getInitialAlarm" -> result.success(intent.getStringExtra("alarmJson"))
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.getStringExtra("alarmJson")?.let { alarmEvents?.invokeMethod("alarmFired", it) }
    }

    companion object {
        fun createChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= 26) {
                val manager = context.getSystemService(android.app.NotificationManager::class.java)
                val channel = android.app.NotificationChannel("mistress_alarm", "Alarm alerts", android.app.NotificationManager.IMPORTANCE_HIGH)
                channel.description = "Wake-up alarms and ringing controls"
                channel.setSound(null, null)
                manager.createNotificationChannel(channel)
            }
        }
    }
}

object AlarmScheduler {
    fun schedule(context: Context, id: Int, timeMillis: Long, title: String, message: String) {
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = "com.mistressalarm.RING_$id"
            putExtra("alarmId", id); putExtra("title", title); putExtra("message", message)
        }
        val pending = android.app.PendingIntent.getBroadcast(context, id, intent, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
        if (Build.VERSION.SDK_INT >= 23) alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMillis, pending)
        else alarmManager.setExact(AlarmManager.RTC_WAKEUP, timeMillis, pending)
    }

    fun cancel(context: Context, id: Int) {
        val intent = Intent(context, AlarmReceiver::class.java).apply { action = "com.mistressalarm.RING_$id" }
        val pending = android.app.PendingIntent.getBroadcast(context, id, intent, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
        context.getSystemService(AlarmManager::class.java).cancel(pending)
    }

    fun scheduleSnooze(context: Context, minutes: Int) {
        val at = System.currentTimeMillis() + minutes * 60_000L
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = "com.mistressalarm.SNOOZE"
            putExtra("alarmId", 2_000_000_000); putExtra("title", "Snoozed alarm"); putExtra("message", "Your next wake-up starts now.")
        }
        val pending = android.app.PendingIntent.getBroadcast(context, 2_000_000_000, intent, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
        if (Build.VERSION.SDK_INT >= 23) alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
        else alarmManager.setExact(AlarmManager.RTC_WAKEUP, at, pending)
    }

    fun rescheduleAll(context: Context) {
        val raw = context.getSharedPreferences("mistress_alarm", Context.MODE_PRIVATE).getString("alarms", "[]") ?: "[]"
        val arr = JSONArray(raw)
        for (i in 0 until arr.length()) {
            val item = arr.getJSONObject(i)
            val id = item.optInt("id")
            cancel(context, id)
            if (!item.optBoolean("enabled", false)) continue
            val hour = item.optInt("hour"); val minute = item.optInt("minute")
            val cal = java.util.Calendar.getInstance().apply {
                set(java.util.Calendar.HOUR_OF_DAY, hour); set(java.util.Calendar.MINUTE, minute); set(java.util.Calendar.SECOND, 0); set(java.util.Calendar.MILLISECOND, 0)
                if (timeInMillis <= System.currentTimeMillis()) add(java.util.Calendar.DAY_OF_YEAR, 1)
            }
            schedule(context, id, cal.timeInMillis, item.optString("label", "Mistress Alarm"), item.optString("message", "Rise and meet the day."))
        }
    }
}

class AlarmReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("alarmId", -1)
        if (id != 2_000_000_000) {
            val raw = context.getSharedPreferences("mistress_alarm", Context.MODE_PRIVATE).getString("alarms", "[]") ?: "[]"
            val arr = JSONArray(raw)
            for (i in 0 until arr.length()) {
                val item = arr.getJSONObject(i)
                if (item.optInt("id") == id && item.optBoolean("enabled") && item.optBoolean("repeatDaily")) {
                    val next = java.util.Calendar.getInstance().apply {
                        set(java.util.Calendar.HOUR_OF_DAY, item.optInt("hour")); set(java.util.Calendar.MINUTE, item.optInt("minute")); set(java.util.Calendar.SECOND, 0); set(java.util.Calendar.MILLISECOND, 0); add(java.util.Calendar.DAY_OF_YEAR, 1)
                    }
                    AlarmScheduler.schedule(context, id, next.timeInMillis, item.optString("label"), item.optString("message"))
                    break
                }
            }
        }
        val service = Intent(context, AlarmRingingService::class.java).apply {
            putExtras(intent)
        }
        val alarmJson = JSONObject().put("id", id).put("label", intent.getStringExtra("title") ?: "Wake up").put("message", intent.getStringExtra("message") ?: "").toString()
        MainActivityEventRelay.deliver(context, alarmJson)
        if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(service) else context.startService(service)
    }
}

object MainActivityEventRelay {
    fun deliver(context: Context, alarmJson: String) {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("alarmJson", alarmJson)
        }
        context.startActivity(intent)
    }
}

class BootReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) { AlarmScheduler.rescheduleAll(context) }
}
