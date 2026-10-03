package au.jly.e60updater

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Fired by the system (via our PendingIntent) when a Wi-Fi network becomes available. */
class WifiReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Trigger.ACTION_WIFI) return
        // Give DHCP and routes a few seconds to settle before probing the gateway.
        Trigger.scheduleCheck(context, "Wi-Fi joined", delayMs = 5_000)
    }
}

/** Restores the Wi-Fi watch after a reboot or an app update. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED ->
                Trigger.registerWifiCallback(context)
        }
    }
}
