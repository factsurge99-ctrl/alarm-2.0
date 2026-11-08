package com.mistressalarm.app

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.core.app.NotificationCompat

class AlarmRingingService : Service() {
    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra("title") ?: "Mistress Alarm"
        val message = intent?.getStringExtra("message") ?: "Your day is waiting."
        val id = intent?.getIntExtra("alarmId", 0) ?: 0
        MainActivity.createChannel(this)
        val open = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("alarmJson", """{"id":$id,"label":${JSONObjectQuote.quote(title)},"message":${JSONObjectQuote.quote(message)}}""")
        }
        val fullScreen = PendingIntent.getActivity(this, id, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = NotificationCompat.Builder(this, "mistress_alarm")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm).setContentTitle(title).setContentText("Wake-up challenge ready")
            .setCategory(NotificationCompat.CATEGORY_ALARM).setPriority(NotificationCompat.PRIORITY_MAX)
            .setOngoing(true).setFullScreenIntent(fullScreen, true).setContentIntent(fullScreen).build()
        startForeground(91, notification)
        startAudioAndVibration()
        try { startActivity(open) } catch (_: Exception) { }
        return START_STICKY
    }

    private fun startAudioAndVibration() {
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM) ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            player = MediaPlayer().apply {
                setDataSource(this@AlarmRingingService, uri)
                setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
                isLooping = true; prepare(); start()
            }
        } catch (_: Exception) { }
        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        val pattern = longArrayOf(0, 650, 350, 650, 350)
        if (Build.VERSION.SDK_INT >= 26) vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0)) else @Suppress("DEPRECATION") vibrator?.vibrate(pattern, 0)
    }

    override fun onDestroy() { player?.stop(); player?.release(); player = null; vibrator?.cancel(); super.onDestroy() }
    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        fun stop(context: Context) { context.stopService(Intent(context, AlarmRingingService::class.java)) }
    }
}

private object JSONObjectQuote {
    fun quote(value: String): String = org.json.JSONObject.quote(value)
}
