package au.jly.e60updater

import android.Manifest
import android.app.Activity
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast

class MainActivity : Activity() {
    private lateinit var settings: Settings
    private lateinit var versions: TextView
    private lateinit var log: TextView

    // The job runs in this process, so prefs changes show up live while the screen is open.
    private val prefsListener = SharedPreferences.OnSharedPreferenceChangeListener { _, _ ->
        runOnUiThread { refresh() }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        settings = Settings(this)
        versions = findViewById(R.id.versions)
        log = findViewById(R.id.log)

        val repo = findViewById<EditText>(R.id.repo)
        val token = findViewById<EditText>(R.id.token)
        repo.setText(settings.repo)
        token.setText(settings.token)

        findViewById<Button>(R.id.save).setOnClickListener {
            settings.save(repo.text.toString(), token.text.toString())
            Toast.makeText(this, "Saved", Toast.LENGTH_SHORT).show()
        }
        // The car's settings page is served by the head unit, the gateway of the car Wi-Fi.
        // Its address changes when the head unit restarts its hotspot, so look it up now.
        findViewById<Button>(R.id.openSettings).setOnClickListener {
            val gw = HeadUnit.wifiGateway(getSystemService(android.net.ConnectivityManager::class.java))
            if (gw == null) {
                Toast.makeText(this, "Connect to the car's Wi-Fi first", Toast.LENGTH_LONG).show()
            } else {
                val host = if (gw.contains(':')) "[$gw]" else gw
                startActivity(android.content.Intent(android.content.Intent.ACTION_VIEW,
                    android.net.Uri.parse("http://$host:${HeadUnit.PORT}/settings")))
            }
        }
        findViewById<Button>(R.id.checkNow).setOnClickListener {
            if (settings.repo.isEmpty()) {
                settings.log("Set the GitHub repo")
            } else {
                settings.log("Check requested")
                Trigger.scheduleCheck(this, "Check now")
            }
        }

        Notifier.ensureChannel(this)
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        }
        // Opening the UI is a cheap moment to make sure the Wi-Fi watch is registered.
        Trigger.registerWifiCallback(this)
    }

    override fun onStart() {
        super.onStart()
        settings.prefs.registerOnSharedPreferenceChangeListener(prefsListener)
        refresh()
    }

    override fun onStop() {
        settings.prefs.unregisterOnSharedPreferenceChangeListener(prefsListener)
        super.onStop()
    }

    private fun refresh() {
        val repoHint = if (settings.repo.isEmpty()) "Set the GitHub repo\n\n" else ""
        versions.text = repoHint + settings.versionsText()
        log.text = settings.logText.ifEmpty { "(empty)" }
    }
}
