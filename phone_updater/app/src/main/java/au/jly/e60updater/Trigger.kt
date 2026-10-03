package au.jly.e60updater

import android.app.PendingIntent
import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build

object Trigger {
    private const val JOB_ID = 6001
    const val ACTION_WIFI = "au.jly.e60updater.WIFI_AVAILABLE"

    /**
     * Asks ConnectivityService to fire [WifiReceiver] whenever a Wi-Fi network becomes available.
     * The PendingIntent form (unlike an in-process NetworkCallback) is held by the system, so it keeps
     * working after our process dies, without a foreground service. It is lost on reboot and on
     * app update, hence the re-registration from BootReceiver and from the UI.
     */
    fun registerWifiCallback(context: Context) {
        val cm = context.getSystemService(ConnectivityManager::class.java)
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .build()
        val pi = wifiPendingIntent(context)
        try {
            // Re-registering the same PendingIntent replaces the old request; unregister first
            // anyway so we never pile up registrations (the system caps them per app).
            runCatching { cm.unregisterNetworkCallback(pi) }
            cm.registerNetworkCallback(request, pi)
        } catch (e: Exception) {
            Settings(context).log("Could not watch Wi-Fi: ${e.message}")
        }
    }

    private fun wifiPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, WifiReceiver::class.java).setAction(ACTION_WIFI)
        // Must be MUTABLE on Android 12+: the system fills in the Network extra when it fires.
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
        return PendingIntent.getBroadcast(context, 0, intent, flags)
    }

    /**
     * Schedules one update pass. A JobScheduler job gets its own execution window (up to ~10 min)
     * even when the app is in the background, which a broadcast receiver does not.
     */
    fun scheduleCheck(context: Context, reason: String, delayMs: Long = 0) {
        val js = context.getSystemService(JobScheduler::class.java)
        // schedule() with the ID of a running job would stop it; let the current pass finish instead.
        if (UpdateJobService.running || js.getPendingJob(JOB_ID) != null) return
        val job = JobInfo.Builder(JOB_ID, ComponentName(context, UpdateJobService::class.java))
            .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
            .setMinimumLatency(delayMs)
            .build()
        val ok = js.schedule(job) == JobScheduler.RESULT_SUCCESS
        if (!ok) Settings(context).log("Could not schedule check ($reason)")
    }
}
