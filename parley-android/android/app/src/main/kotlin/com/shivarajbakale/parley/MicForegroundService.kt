package com.shivarajbakale.parley

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.withTimeoutOrNull

/**
 * Holds the `microphone` foreground-service status for exactly as long as a
 * recording runs, so the mic keeps working while another app is in front.
 * The recording itself happens in the accessibility service; this only
 * carries the notification and the FGS type.
 */
class MicForegroundService : Service() {

    companion object {
        private const val TAG = "ParleyMicFgs"
        private const val CHANNEL = "parley_listening"
        private const val NOTIFICATION_ID = 7001
        private const val START_TIMEOUT_MS = 2_000L

        @Volatile private var pending: CompletableDeferred<Boolean>? = null

        /** Returns null once the service is in the foreground, else why it is not. */
        suspend fun start(context: Context): String? {
            val started = CompletableDeferred<Boolean>()
            pending = started
            try {
                ContextCompat.startForegroundService(context, Intent(context, MicForegroundService::class.java))
            } catch (e: Exception) {
                // ForegroundServiceStartNotAllowedException and friends.
                Log.w(TAG, "startForegroundService refused", e)
                pending = null
                return "Android blocked the microphone"
            }
            val ok = withTimeoutOrNull(START_TIMEOUT_MS) { started.await() } ?: false
            pending = null
            return if (ok) null else "Android blocked the microphone"
        }

        fun stop(context: Context) {
            try {
                context.stopService(Intent(context, MicForegroundService::class.java))
            } catch (e: Exception) {
                Log.w(TAG, "stopService failed", e)
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            ensureChannel()
            val notification = NotificationCompat.Builder(this, CHANNEL)
                .setSmallIcon(R.drawable.ic_stat_parley)
                .setContentTitle("Parley is listening")
                .setOngoing(true)
                .setSilent(true)
                .setCategory(Notification.CATEGORY_SERVICE)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .build()
            val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE else 0
            ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, type)
            pending?.complete(true)
        } catch (e: Exception) {
            Log.w(TAG, "startForeground failed", e)
            pending?.complete(false)
            stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(NotificationChannel(CHANNEL, "Listening", NotificationManager.IMPORTANCE_LOW))
        }
    }
}
