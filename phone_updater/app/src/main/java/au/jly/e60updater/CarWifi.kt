package au.jly.e60updater

import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiNetworkSpecifier
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Our own request for the car's Wi-Fi, for when we cannot use the connection the phone already
 * has. When wireless Android Auto joins the car hotspot it requests the network for itself, and
 * Android can reserve such a network for the app that asked; binding to it from here then fails
 * with EPERM. Asking for it with a WifiNetworkSpecifier gives this app its own access. Android
 * shows a one-time "allow this app to connect" prompt, and only allows the request while the app
 * is on screen, so this is used from "Check now" and the settings screen, not background checks.
 * Call [close] to release the request.
 */
class CarWifi private constructor(
    private val cm: ConnectivityManager,
    val network: Network,
    private val callback: ConnectivityManager.NetworkCallback,
) : AutoCloseable {

    override fun close() {
        runCatching { cm.unregisterNetworkCallback(callback) }
    }

    companion object {
        fun request(cm: ConnectivityManager, ssid: String, password: String, timeoutMs: Long = 45_000): CarWifi? {
            if (ssid.isBlank()) return null
            val specifier = WifiNetworkSpecifier.Builder().setSsid(ssid).apply {
                if (password.isNotEmpty()) setWpa2Passphrase(password)
            }.build()
            val request = NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)   // the hotspot has none
                .setNetworkSpecifier(specifier)
                .build()
            val latch = CountDownLatch(1)
            var found: Network? = null
            val callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    found = network
                    latch.countDown()
                }
                override fun onUnavailable() = latch.countDown()
            }
            try {
                cm.requestNetwork(request, callback, timeoutMs.toInt())
            } catch (e: Exception) {
                return null
            }
            // the user may take a while to answer the system prompt
            latch.await(timeoutMs + 2_000, TimeUnit.MILLISECONDS)
            val network = found ?: run {
                runCatching { cm.unregisterNetworkCallback(callback) }
                return null
            }
            return CarWifi(cm, network, callback)
        }
    }
}
