package au.jly.e60updater

import android.net.Network
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

/**
 * Small HttpURLConnection helpers. Every connection is opened through network.openConnection()
 * so the socket is bound to that exact network: the car Wi-Fi has no internet, and the phone's
 * default network may be either the Wi-Fi or mobile data, so we never rely on the default.
 */
object Http {
    class HttpException(val code: Int, message: String) : IOException(message)

    fun open(network: Network, url: String, connectMs: Int, readMs: Int): HttpURLConnection {
        val conn = network.openConnection(URL(url)) as HttpURLConnection
        conn.connectTimeout = connectMs
        conn.readTimeout = readMs
        conn.useCaches = false
        return conn
    }

    /** GET returning the body as text; throws HttpException on a non-2xx reply. */
    fun getText(
        network: Network, url: String, headers: Map<String, String> = emptyMap(),
        connectMs: Int = 10_000, readMs: Int = 20_000,
    ): String {
        val conn = openFollowing(network, url, headers, connectMs, readMs)
        try {
            return conn.inputStream.use { it.readBytes().toString(Charsets.UTF_8) }
        } finally {
            conn.disconnect()
        }
    }

    /** GET streamed to a file, returning the hex sha256 of what was written. */
    fun download(network: Network, url: String, headers: Map<String, String>, dest: File): String {
        val conn = openFollowing(network, url, headers, 15_000, 60_000)
        val digest = MessageDigest.getInstance("SHA-256")
        try {
            conn.inputStream.use { input ->
                dest.outputStream().use { out ->
                    val buf = ByteArray(64 * 1024)
                    while (true) {
                        val n = input.read(buf)
                        if (n < 0) break
                        digest.update(buf, 0, n)
                        out.write(buf, 0, n)
                    }
                }
            }
        } finally {
            conn.disconnect()
        }
        return digest.digest().toHex()
    }

    /**
     * Follows redirects by hand. GitHub asset downloads redirect to a signed storage URL on another
     * host; the Authorization header must not be sent there, and each hop must stay on [network].
     */
    private fun openFollowing(
        network: Network, startUrl: String, headers: Map<String, String>,
        connectMs: Int, readMs: Int,
    ): HttpURLConnection {
        var url = startUrl
        val startHost = URL(startUrl).host
        repeat(5) {
            val conn = open(network, url, connectMs, readMs)
            conn.instanceFollowRedirects = false
            val sameHost = URL(url).host == startHost
            headers.forEach { (k, v) ->
                if (sameHost || !k.equals("Authorization", ignoreCase = true)) conn.setRequestProperty(k, v)
            }
            val code = conn.responseCode
            when {
                code in 200..299 -> return conn
                code in 300..399 -> {
                    val location = conn.getHeaderField("Location")
                    conn.disconnect()
                    if (location.isNullOrEmpty()) throw HttpException(code, "Redirect without Location")
                    url = URL(URL(url), location).toString()
                }
                else -> {
                    val body = errorBody(conn)
                    conn.disconnect()
                    throw HttpException(code, "HTTP $code from ${URL(url).host}: $body")
                }
            }
        }
        throw IOException("Too many redirects for $startUrl")
    }

    fun errorBody(conn: HttpURLConnection): String = try {
        conn.errorStream?.use { it.readBytes().toString(Charsets.UTF_8).trim().take(200) } ?: ""
    } catch (e: IOException) {
        ""
    }

    fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buf = ByteArray(64 * 1024)
            while (true) {
                val n = input.read(buf)
                if (n < 0) break
                digest.update(buf, 0, n)
            }
        }
        return digest.digest().toHex()
    }

    private fun ByteArray.toHex(): String = joinToString("") { "%02x".format(it) }
}
