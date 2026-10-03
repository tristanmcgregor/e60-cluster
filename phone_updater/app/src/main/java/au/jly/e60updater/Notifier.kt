package au.jly.e60updater

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent

object Notifier {
    private const val CHANNEL = "car_updates"
    private const val ID = 1

    fun ensureChannel(context: Context) {
        val nm = context.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL, "Car updates", NotificationManager.IMPORTANCE_DEFAULT)
        )
    }

    fun show(context: Context, text: String) {
        try {
            ensureChannel(context)
            val open = PendingIntent.getActivity(
                context, 0, Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            val n = Notification.Builder(context, CHANNEL)
                .setSmallIcon(android.R.drawable.stat_sys_download_done)
                .setContentTitle("E60 Car Updater")
                .setContentText(text)
                .setStyle(Notification.BigTextStyle().bigText(text))
                .setContentIntent(open)
                .setAutoCancel(true)
                .build()
            context.getSystemService(NotificationManager::class.java).notify(ID, n)
        } catch (e: SecurityException) {
            // POST_NOTIFICATIONS not granted; the status log still has the result.
        }
    }
}
