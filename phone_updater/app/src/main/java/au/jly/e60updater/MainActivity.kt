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
import android.app.AlertDialog
import android.bluetooth.BluetoothManager
import android.annotation.SuppressLint

class MainActivity : Activity() {
    private lateinit var settings: Settings
    private lateinit var versions: TextView
    private lateinit var log: TextView
    private lateinit var parkText: TextView
    private lateinit var parkMap: Button
    private lateinit var parkSetup: Button

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
        parkText = findViewById(R.id.parkText)
        parkMap = findViewById(R.id.parkMap)
        parkSetup = findViewById(R.id.parkSetup)
        parkMap.setOnClickListener {
            Parking.spot(this)?.let { spot ->
                try { startActivity(Parking.mapIntent(spot)) }
                catch (e: Exception) { Toast.makeText(this, "No map app", Toast.LENGTH_SHORT).show() }
            }
        }
        parkSetup.setOnClickListener { chooseCarDevice() }

        val repo = findViewById<EditText>(R.id.repo)
        val token = findViewById<EditText>(R.id.token)
        val carSsid = findViewById<EditText>(R.id.carSsid)
        val carPassword = findViewById<EditText>(R.id.carPassword)
        repo.setText(settings.repo)
        token.setText(settings.token)
        carSsid.setText(settings.carSsid)
        carPassword.setText(settings.carPassword)

        findViewById<Button>(R.id.save).setOnClickListener {
            settings.save(repo.text.toString(), token.text.toString(), carSsid.text.toString(), carPassword.text.toString())
            Toast.makeText(this, "Saved", Toast.LENGTH_SHORT).show()
        }
        // The car's settings page, shown in-app on the car Wi-Fi (CarSettingsActivity), so it
        // works even when a browser could not reach the car (VPN, Android Auto's network).
        findViewById<Button>(R.id.openSettings).setOnClickListener {
            startActivity(android.content.Intent(this, CarSettingsActivity::class.java))
        }
        findViewById<Button>(R.id.checkNow).setOnClickListener {
            if (settings.repo.isEmpty()) {
                settings.log("Set the GitHub repo")
            } else {
                settings.log("Check requested")
                Trigger.scheduleCheck(this, "Check now", interactive = true)
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

        val spot = Parking.spot(this)
        val car = Parking.carDevice(this)
        val missing = Parking.missingPermissions(this)
        parkText.text = (spot?.let { Parking.describe(it) } ?: "No parking spot saved yet.") + "\n" + when {
            car == null -> "Not set up: choose the car's Bluetooth below."
            missing.isNotEmpty() -> "Car: ${car.second}. Still needs permission: " + missing.joinToString { permissionName(it) }
            else -> "Saved automatically when the car (${car.second}) switches off."
        }
        parkMap.isEnabled = spot != null
        parkSetup.text = when {
            car == null -> "Set up parking spot"
            missing.isNotEmpty() -> "Grant parking permissions"
            else -> "Change car Bluetooth"
        }
    }

    private fun permissionName(p: String) = when (p) {
        Manifest.permission.BLUETOOTH_CONNECT -> "Nearby devices"
        Manifest.permission.ACCESS_FINE_LOCATION -> "Location"
        Manifest.permission.ACCESS_BACKGROUND_LOCATION -> "Location: Allow all the time"
        else -> p.substringAfterLast('.')
    }

    // ---- parking set-up: Bluetooth permission, pick the car, then location (foreground, then all the time)

    private fun chooseCarDevice() {
        if (Build.VERSION.SDK_INT >= 31 &&
            checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.BLUETOOTH_CONNECT), REQ_BLUETOOTH)
            return
        }
        if (Parking.carDevice(this) != null && Parking.missingPermissions(this).isNotEmpty()) {
            askLocation()
            return
        }
        @SuppressLint("MissingPermission")
        val devices = getSystemService(BluetoothManager::class.java)?.adapter?.bondedDevices
            ?.map { it.address to (it.name ?: it.address) }?.sortedBy { it.second.lowercase() }.orEmpty()
        if (devices.isEmpty()) {
            Toast.makeText(this, "No paired Bluetooth devices", Toast.LENGTH_LONG).show()
            return
        }
        AlertDialog.Builder(this)
            .setTitle("Which is the car?")
            .setItems(devices.map { it.second }.toTypedArray()) { _, i ->
                Parking.setCarDevice(this, devices[i].first, devices[i].second)
                settings.log("Parking: car Bluetooth set to ${devices[i].second}")
                refresh()
                askLocation()
            }
            .show()
    }

    private fun askLocation() {
        when {
            checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED ->
                requestPermissions(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION), REQ_LOCATION)
            Build.VERSION.SDK_INT >= 29 &&
                checkSelfPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION) != PackageManager.PERMISSION_GRANTED ->
                AlertDialog.Builder(this)
                    .setTitle("Location all the time")
                    .setMessage("To save the spot when the car switches off, with this app closed, choose " +
                        "\"Allow all the time\" on the next screen.")
                    .setPositiveButton("Continue") { _, _ ->
                        requestPermissions(arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION), REQ_BACKGROUND)
                    }
                    .setNegativeButton("Not now", null)
                    .show()
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        when (requestCode) {
            REQ_BLUETOOTH -> if (granted) chooseCarDevice()
            REQ_LOCATION -> if (granted) askLocation()
        }
        refresh()
    }

    companion object {
        private const val REQ_BLUETOOTH = 11
        private const val REQ_LOCATION = 12
        private const val REQ_BACKGROUND = 13
    }
}
