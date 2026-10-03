package au.jly.e60updater

import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Holds an internet network that is not the car Wi-Fi. The car hotspot has no internet, so we ask
 * for mobile data explicitly; requestNetwork keeps cellular up for us even while Wi-Fi is connected.
 * Call [close] to release the request.
 */
class InternetNetwork private constructor(
    private val cm: ConnectivityManager,
    val network: Network,
    private val callback: ConnectivityManager.NetworkCallback?,
) : AutoCloseable {

    override fun close() {
        callback?.let { runCatching { cm.unregisterNetworkCallback(it) } }
    }

    companion object {
        fun acquire(cm: ConnectivityManager, carNetwork: Network?, timeoutMs: Long = 15_000): InternetNetwork? {
            val latch = CountDownLatch(1)
            var found: Network? = null
            val callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    found = network
                    latch.countDown()
                }
                override fun onUnavailable() = latch.countDown()
            }
            val request = NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_CELLULAR)
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build()
            val requested = try {
                cm.requestNetwork(request, callback, timeoutMs.toInt())
                true
            } catch (e: Exception) {
                false // e.g. SecurityException or too many requests; fall back below
            }
            if (requested) {
                latch.await(timeoutMs + 1_000, TimeUnit.MILLISECONDS)
                found?.let { return InternetNetwork(cm, it, callback) }
                runCatching { cm.unregisterNetworkCallback(callback) }
            }
            return fallback(cm, carNetwork)?.let { InternetNetwork(cm, it, null) }
        }

        /** Any validated network other than the car's (e.g. home Wi-Fi when there is no SIM data). */
        @Suppress("DEPRECATION")
        private fun fallback(cm: ConnectivityManager, carNetwork: Network?): Network? =
            cm.allNetworks.firstOrNull { n ->
                n != carNetwork && cm.getNetworkCapabilities(n)?.let {
                    it.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                        it.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
                } == true
            }
    }
}
