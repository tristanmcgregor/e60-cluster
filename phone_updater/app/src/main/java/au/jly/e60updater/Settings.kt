package au.jly.e60updater

import android.content.Context
import android.content.SharedPreferences
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Configuration (BuildConfig defaults, overridable from the UI), status log and last known versions. */
class Settings(context: Context) {
    val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    // A blank override falls back to the build-time default.
    val repo: String get() = pick(KEY_REPO, BuildConfig.GITHUB_REPO)
    val token: String get() = pick(KEY_TOKEN, BuildConfig.GITHUB_TOKEN)
    // The car hotspot, for asking Android for our own access to it (CarWifi). Entered on the
    // phone, never built in: this APK is published.
    val carSsid: String get() = pick(KEY_CAR_SSID, "Bmw")
    val carPassword: String get() = prefs.getString(KEY_CAR_PASSWORD, "") ?: ""

    private fun pick(key: String, default: String): String =
        prefs.getString(key, null)?.trim()?.takeIf { it.isNotEmpty() } ?: default.trim()

    fun save(repo: String, token: String, carSsid: String, carPassword: String) {
        prefs.edit()
            .putString(KEY_REPO, repo.trim())
            .putString(KEY_TOKEN, token.trim())
            .putString(KEY_CAR_SSID, carSsid.trim())
            .putString(KEY_CAR_PASSWORD, carPassword)
            .apply()
    }

    @Synchronized
    fun log(message: String) {
        val stamp = SimpleDateFormat("MM-dd HH:mm:ss", Locale.US).format(Date())
        val lines = (listOf("$stamp  $message") + logText.lines().filter { it.isNotBlank() })
            .take(MAX_LOG_LINES)
        prefs.edit().putString(KEY_LOG, lines.joinToString("\n")).apply()
    }

    val logText: String get() = prefs.getString(KEY_LOG, "") ?: ""

    fun saveStatus(status: HeadUnitStatus) {
        prefs.edit()
            .putInt(KEY_APK, status.apkRelease)
            .putInt(KEY_PENDING_APK, status.pendingApkRelease)
            .putInt(KEY_DASH, status.dashRelease)
            .putInt(KEY_CLUSTER, status.clusterDashRelease)
            .putLong(KEY_SEEN, System.currentTimeMillis())
            .apply()
    }

    fun versionsText(): String {
        val seen = prefs.getLong(KEY_SEEN, 0)
        if (seen == 0L) return "Car not seen yet."
        fun v(key: String) = prefs.getInt(key, 0).let { if (it == 0) "none" else "v$it" }
        val at = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.US).format(Date(seen))
        return "Last seen $at\n" +
            "Head unit app: ${v(KEY_APK)} (staged: ${v(KEY_PENDING_APK)})\n" +
            "Head unit dash: ${v(KEY_DASH)}\n" +
            "Cluster dash: ${v(KEY_CLUSTER)}"
    }

    companion object {
        const val PREFS = "e60_updater"
        const val KEY_REPO = "github.repo"
        const val KEY_TOKEN = "github.token"
        const val KEY_CAR_SSID = "car.ssid"
        const val KEY_CAR_PASSWORD = "car.password"
        const val KEY_LOG = "log"
        const val KEY_APK = "hu.apkRelease"
        const val KEY_PENDING_APK = "hu.pendingApkRelease"
        const val KEY_DASH = "hu.dashRelease"
        const val KEY_CLUSTER = "hu.clusterDashRelease"
        const val KEY_SEEN = "hu.seenAt"
        private const val MAX_LOG_LINES = 40
    }
}
