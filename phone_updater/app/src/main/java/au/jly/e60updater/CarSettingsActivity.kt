package au.jly.e60updater

import android.annotation.SuppressLint
import android.app.Activity
import android.net.ConnectivityManager
import android.os.Bundle
import android.view.Gravity
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.TextView

/**
 * The car's settings page (served by the head unit) inside this app. The whole process is bound
 * to the car Wi-Fi while it is open, so the page loads even when a browser could not reach the
 * car: a VPN that does not let apps bypass it, or the car network being reserved for Android
 * Auto. If our own access is needed, Android asks once to allow it (see [CarWifi]).
 */
class CarSettingsActivity : Activity() {
    private lateinit var cm: ConnectivityManager
    private var ownWifi: CarWifi? = null
    @Volatile private var closed = false

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        cm = getSystemService(ConnectivityManager::class.java)
        val status = TextView(this).apply {
            text = "Finding the car…"
            gravity = Gravity.CENTER
            textSize = 18f
        }
        setContentView(status)
        val prefs = Settings(this)
        Thread({
            val found = HeadUnit.find(cm) {} ?: CarWifi.request(cm, prefs.carSsid, prefs.carPassword)
                ?.also { ownWifi = it }
                ?.let { HeadUnit.probe(cm, it.network) {} }
            runOnUiThread {
                if (closed) return@runOnUiThread
                if (found == null) {
                    status.text = "Car not found.\n\nConnect to the car's Wi-Fi, and check its name and password in the updater."
                    return@runOnUiThread
                }
                val (car, _) = found
                cm.bindProcessToNetwork(car.network)     // the WebView's traffic goes to the car
                setContentView(WebView(this).apply {
                    settings.javaScriptEnabled = true
                    webViewClient = WebViewClient()
                    loadUrl(car.url("/settings"))
                })
            }
        }, "car-settings").start()
    }

    override fun onDestroy() {
        closed = true
        cm.bindProcessToNetwork(null)
        ownWifi?.close()
        super.onDestroy()
    }
}
