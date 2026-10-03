package au.jly.e60updater

import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.net.Inet4Address
import java.net.InetAddress

data class HeadUnitStatus(
    val apkRelease: Int,
    val apkVersionCode: Int,
    val pendingApkRelease: Int,
    val dashRelease: Int,
    val clusterDashRelease: Int,
)

/** The car's head unit, reached over the car Wi-Fi network it hosts (it is the gateway). */
class HeadUnit(val network: Network, private val host: String) {

    fun status(): HeadUnitStatus {
        val json = JSONObject(Http.getText(network, "$base/update/status", connectMs = 3_000, readMs = 4_000))
        if (json.optString("service") != SERVICE) throw IOException("Not the e60-update service")
        return HeadUnitStatus(
            apkRelease = json.optInt("apkRelease", 0),
            apkVersionCode = json.optInt("apkVersionCode", 0),
            pendingApkRelease = json.optInt("pendingApkRelease", 0),
            dashRelease = json.optInt("dashRelease", 0),
            clusterDashRelease = json.optInt("clusterDashRelease", 0),
        )
    }

    enum class UploadResult { OK, NOT_NEWER }

    /** POST /update/{kind}?release=N&sha256=hex with the raw file as a fixed-length body. */
    fun upload(kind: String, release: Int, sha256: String, file: File, key: String): UploadResult {
        val conn = Http.open(network, "$base/update/$kind?release=$release&sha256=$sha256", 5_000, 120_000)
        try {
            conn.requestMethod = "POST"
            conn.doOutput = true
            // Fixed-length streaming sends Content-Length and avoids buffering the whole file in memory.
            conn.setFixedLengthStreamingMode(file.length())
            conn.setRequestProperty("X-Update-Key", key)
            conn.setRequestProperty("Content-Type", "application/octet-stream")
            conn.outputStream.use { out -> file.inputStream().use { it.copyTo(out, 64 * 1024) } }
            return when (val code = conn.responseCode) {
                200 -> UploadResult.OK
                409 -> UploadResult.NOT_NEWER
                401 -> throw Http.HttpException(code, "Head unit rejected the update key (401)")
                else -> throw Http.HttpException(code, "Head unit replied $code: ${Http.errorBody(conn)}")
            }
        } finally {
            conn.disconnect()
        }
    }

    private val base: String
        get() = "http://" + (if (host.contains(':')) "[$host]" else host) + ":$PORT"

    companion object {
        const val PORT = 8765
        const val SERVICE = "e60-update"

        /** Probes the default gateway of every Wi-Fi network; returns the one answering as the car. */
        @Suppress("DEPRECATION") // allNetworks: still the simplest way to enumerate every network.
        fun find(cm: ConnectivityManager, log: (String) -> Unit): Pair<HeadUnit, HeadUnitStatus>? {
            for (network in cm.allNetworks) {
                val caps = cm.getNetworkCapabilities(network) ?: continue
                if (!caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) continue
                val gateway = gatewayOf(cm, network) ?: continue
                val hu = HeadUnit(network, gateway.hostAddress ?: continue)
                try {
                    return hu to hu.status()
                } catch (e: Exception) {
                    log("No car at ${gateway.hostAddress}: ${e.message ?: e.javaClass.simpleName}")
                }
            }
            return null
        }

        private fun gatewayOf(cm: ConnectivityManager, network: Network): InetAddress? {
            val routes = cm.getLinkProperties(network)?.routes ?: return null
            val gateways = routes.filter { it.isDefaultRoute && it.hasGateway() }.mapNotNull { it.gateway }
            // Prefer IPv4: the hotspot head unit is reached on its IPv4 gateway address.
            return gateways.firstOrNull { it is Inet4Address } ?: gateways.firstOrNull()
        }
    }
}
