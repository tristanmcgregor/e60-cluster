package au.jly.e60updater

import android.app.Activity
import android.content.Intent
import android.graphics.Typeface
import android.net.ConnectivityManager
import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * The head unit's recent log (GET /log on the car Wi-Fi), newest at the bottom, with Refresh,
 * Share (as text) and Export (the whole log as a .txt file). Finds the car the same way as [CarSettingsActivity], including our own Wi-Fi
 * request when the phone's normal connection can't reach it.
 */
class CarLogActivity : Activity() {
    private lateinit var cm: ConnectivityManager
    private lateinit var text: TextView
    private lateinit var scroll: ScrollView
    private var car: HeadUnit? = null
    private var log: String? = null     // the last log fetched, whole
    private var ownWifi: CarWifi? = null
    @Volatile private var closed = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        cm = getSystemService(ConnectivityManager::class.java)
        val pad = (12 * resources.displayMetrics.density).toInt()
        text = TextView(this).apply {
            typeface = Typeface.MONOSPACE
            textSize = 11f
            setTextIsSelectable(true)
            setPadding(pad, pad, pad, pad)
            text = "Finding the car…"
        }
        scroll = ScrollView(this).apply { addView(text) }
        val buttons = LinearLayout(this).apply {
            addView(Button(context).apply {
                this.text = "Refresh"
                setOnClickListener { load() }
            }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            addView(Button(context).apply {
                this.text = "Share"
                setOnClickListener { share() }
            }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            addView(Button(context).apply {
                this.text = "Export"
                setOnClickListener { export() }
            }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        }
        setContentView(LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            addView(buttons)
            addView(scroll, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f))
        })
        load()
    }

    private fun load() {
        text.text = if (car == null) "Finding the car…" else "Loading…"
        val prefs = Settings(this)
        Thread({
            var fetched: String? = null
            val result = try {
                val hu = car ?: (HeadUnit.find(cm) {} ?: CarWifi.request(cm, prefs.carSsid, prefs.carPassword)
                    ?.also { ownWifi = it }
                    ?.let { HeadUnit.probe(cm, it.network) {} })?.first
                if (hu == null) {
                    "Car not found.\n\nConnect to the car's Wi-Fi, and check its name and password in the updater."
                } else {
                    car = hu
                    Http.getText(hu.network, hu.url("/log"), connectMs = 3_000, readMs = 10_000)
                        .also { if (it.isNotBlank()) fetched = it }
                        .ifBlank { "The head unit log is empty." }
                }
            } catch (e: Exception) {
                car = null      // look for the car again on the next refresh
                "Couldn't read the head unit log: ${e.message ?: e.javaClass.simpleName}"
            }
            runOnUiThread {
                if (closed) return@runOnUiThread
                log = fetched
                text.text = result
                scroll.post { scroll.fullScroll(View.FOCUS_DOWN) }
            }
        }, "car-log").start()
    }

    private fun share() {
        val body = text.text.toString().takeLast(200_000)    // keep under the Intent size limit
        startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_SUBJECT, "E60 head unit log")
            putExtra(Intent.EXTRA_TEXT, body)
        }, "Share log"))
    }

    /** Saves the whole log to a .txt file and shares it as an attachment, so nothing is cut off. */
    private fun export() {
        val body = log ?: run {
            Toast.makeText(this, "No log loaded yet — tap Refresh.", Toast.LENGTH_SHORT).show()
            return
        }
        val dir = LogFileProvider.dir(this)
        dir.listFiles()?.forEach { it.delete() }     // only keep the latest export
        val stamp = SimpleDateFormat("yyyy-MM-dd_HHmm", Locale.US).format(Date())
        val file = File(dir, "e60-headunit-log_$stamp.txt").apply { writeText(body) }
        startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_SUBJECT, "E60 head unit log $stamp")
            putExtra(Intent.EXTRA_STREAM, LogFileProvider.uri(file))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }, "Export log"))
    }

    override fun onDestroy() {
        closed = true
        ownWifi?.close()
        super.onDestroy()
    }
}
