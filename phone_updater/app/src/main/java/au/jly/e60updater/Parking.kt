package au.jly.e60updater

import android.Manifest
import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.CancellationSignal
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * "Where I parked": when the phone's Bluetooth link to the car's head unit drops (ignition off),
 * the phone's own location is saved as the parking spot and shown as a notification that opens
 * the map. The phone, not the head unit, is asked: during a wireless Android Auto drive this app
 * cannot reach the head unit in the background, and once the car is off nothing can.
 *
 * Needs the car's Bluetooth device chosen in the app, Bluetooth "nearby devices" permission (to
 * receive the disconnect) and location "Allow all the time" (to read it with the app closed).
 */
object Parking {
    private const val CHANNEL = "parking"
    private const val NOTIFY_ID = 2
    private const val KEY_DEVICE = "park.device"
    private const val KEY_DEVICE_NAME = "park.deviceName"
    private const val KEY_LAT = "park.lat"
    private const val KEY_LON = "park.lon"
    private const val KEY_ACC = "park.acc"
    private const val KEY_TIME = "park.time"
    private const val FRESH_MS = 2 * 60_000L       // a last-known fix younger than this is good enough

    data class Spot(val lat: Double, val lon: Double, val accuracyM: Int, val time: Long)

    fun carDevice(context: Context): Pair<String, String>? {
        val p = Settings(context).prefs
        val address = p.getString(KEY_DEVICE, null) ?: return null
        return address to (p.getString(KEY_DEVICE_NAME, null) ?: address)
    }

    fun setCarDevice(context: Context, address: String, name: String) {
        Settings(context).prefs.edit().putString(KEY_DEVICE, address).putString(KEY_DEVICE_NAME, name).apply()
    }

    fun spot(context: Context): Spot? {
        val p = Settings(context).prefs
        if (!p.contains(KEY_TIME)) return null
        return Spot(
            java.lang.Double.longBitsToDouble(p.getLong(KEY_LAT, 0)),
            java.lang.Double.longBitsToDouble(p.getLong(KEY_LON, 0)),
            p.getInt(KEY_ACC, 0), p.getLong(KEY_TIME, 0),
        )
    }

    private fun save(context: Context, loc: Location) {
        Settings(context).prefs.edit()
            .putLong(KEY_LAT, java.lang.Double.doubleToRawLongBits(loc.latitude))
            .putLong(KEY_LON, java.lang.Double.doubleToRawLongBits(loc.longitude))
            .putInt(KEY_ACC, if (loc.hasAccuracy()) loc.accuracy.toInt() else 0)
            .putLong(KEY_TIME, System.currentTimeMillis())
            .apply()
    }

    fun describe(spot: Spot): String =
        "Parked " + SimpleDateFormat("EEE d MMM, HH:mm", Locale.getDefault()).format(Date(spot.time)) +
            (if (spot.accuracyM > 0) "  (±${spot.accuracyM} m)" else "")

    /** Map app intent for the spot, with a pin labelled "Car". */
    fun mapIntent(spot: Spot): Intent =
        Intent(Intent.ACTION_VIEW, Uri.parse("geo:${spot.lat},${spot.lon}?q=${spot.lat},${spot.lon}(Car)"))

    fun hasPermissions(context: Context): Boolean = missingPermissions(context).isEmpty()

    /** Permissions still needed, in the order Android lets us ask for them. */
    fun missingPermissions(context: Context): List<String> {
        val wanted = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= 31) wanted += Manifest.permission.BLUETOOTH_CONNECT
        wanted += Manifest.permission.ACCESS_FINE_LOCATION
        // background location has to be granted after (and separately from) foreground location
        if (Build.VERSION.SDK_INT >= 29) wanted += Manifest.permission.ACCESS_BACKGROUND_LOCATION
        return wanted.filter { context.checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
    }

    /** Called from [ParkReceiver] off the main thread: get a fix, save it, notify. */
    @SuppressLint("MissingPermission")
    fun capture(context: Context) {
        val settings = Settings(context)
        if (context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            settings.log("Car switched off, but location permission is missing: parking spot not saved")
            return
        }
        val lm = context.getSystemService(LocationManager::class.java)
        val providers = buildList {
            if (Build.VERSION.SDK_INT >= 31) add(LocationManager.FUSED_PROVIDER)
            add(LocationManager.GPS_PROVIDER)
            add(LocationManager.NETWORK_PROVIDER)
        }.filter { runCatching { lm.isProviderEnabled(it) }.getOrDefault(false) }

        // the phone was navigating a moment ago, so a recent fix is usually there already
        val recent = providers.mapNotNull { runCatching { lm.getLastKnownLocation(it) }.getOrNull() }
            .filter { System.currentTimeMillis() - it.time < FRESH_MS }
            .minByOrNull { if (it.hasAccuracy()) it.accuracy else 999f }
        val loc = if (recent != null && recent.hasAccuracy() && recent.accuracy <= 30f) recent
                  else currentFix(lm, providers) ?: recent
        if (loc == null) {
            settings.log("Car switched off, but no location was available: parking spot not saved")
            return
        }
        save(context, loc)
        val spot = spot(context)!!
        settings.log(describe(spot))
        notify(context, spot)
    }

    /** One fresh fix (Android 11+), waiting up to 20 s. */
    @SuppressLint("MissingPermission")
    private fun currentFix(lm: LocationManager, providers: List<String>): Location? {
        if (Build.VERSION.SDK_INT < 30 || providers.isEmpty()) return null
        val latch = CountDownLatch(1)
        var got: Location? = null
        val cancel = CancellationSignal()
        val exec = Executors.newSingleThreadExecutor()
        try {
            lm.getCurrentLocation(providers.first(), cancel, exec) { got = it; latch.countDown() }
            latch.await(20, TimeUnit.SECONDS)
        } catch (e: Exception) {
            // provider gone or not allowed in the background: fall back to the last known fix
        } finally {
            cancel.cancel()
            exec.shutdown()
        }
        return got
    }

    private fun notify(context: Context, spot: Spot) {
        try {
            val nm = context.getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(NotificationChannel(CHANNEL, "Parking spot", NotificationManager.IMPORTANCE_LOW))
            val open = PendingIntent.getActivity(context, 1, mapIntent(spot),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            val n = Notification.Builder(context, CHANNEL)
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setContentTitle("Car parked")
                .setContentText(describe(spot).removePrefix("Parked ") + " — tap for the map")
                .setContentIntent(open)
                .build()
            nm.notify(NOTIFY_ID, n)
        } catch (e: SecurityException) {
            // notifications not allowed; the spot is still in the app
        }
    }
}

/** Bluetooth link to some device dropped; if it is the car, save where the phone is. */
class ParkReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != BluetoothDevice.ACTION_ACL_DISCONNECTED) return
        val device: BluetoothDevice? = if (Build.VERSION.SDK_INT >= 33)
            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
        else @Suppress("DEPRECATION") intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
        val car = Parking.carDevice(context) ?: return
        if (device?.address != car.first) return
        val pending = goAsync()
        Thread({
            try {
                Parking.capture(context.applicationContext)
            } finally {
                pending.finish()
            }
        }, "park").start()
    }
}
