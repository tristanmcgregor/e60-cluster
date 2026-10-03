package au.jly.e60updater

import android.content.Context
import android.net.ConnectivityManager
import java.io.File
import java.io.IOException

/** One update pass: find the car, fetch what it lacks from GitHub, push it. Never throws. */
class Updater(private val context: Context, private val isCancelled: () -> Boolean) {

    /** [notify] is null when there is nothing worth a notification (no car, already up to date). */
    data class Outcome(val notify: String?)

    private val settings = Settings(context)
    private val cm = context.getSystemService(ConnectivityManager::class.java)
    private val cacheDir = File(context.cacheDir, "updates").apply { mkdirs() }

    fun run(): Outcome = try {
        runChecked()
    } catch (e: Exception) {
        val msg = "Update failed: ${e.message ?: e.javaClass.simpleName}"
        settings.log(msg)
        Outcome(msg)
    }

    private fun runChecked(): Outcome {
        val repo = settings.repo
        if (repo.isEmpty()) {
            settings.log("Set the GitHub repo")
            return Outcome(null)
        }
        GitHub.checkRepo(repo)

        val (car, status) = findCar() ?: run {
            settings.log("Car not found on any Wi-Fi network")
            return Outcome(null)
        }
        settings.saveStatus(status)
        settings.log("Car found: app v${status.apkRelease} (staged v${status.pendingApkRelease}), " +
            "dash v${status.dashRelease}, cluster v${status.clusterDashRelease}")

        // A staged APK counts as present, so we do not upload the same release again.
        val apkHave = maxOf(status.apkRelease, status.pendingApkRelease)
        val (dash, apk) = InternetNetwork.acquire(cm, car.network)?.use { internet ->
            val github = GitHub(internet.network, repo, settings.token)
            val picks = github.pick(status.dashRelease, apkHave, settings::log)
            val files = listOfNotNull(picks.first, picks.second)
            pruneCache(files)
            files.forEach { fetch(github, it) }
            picks
        } ?: throw IOException("No internet network (mobile data unavailable)")

        if (dash == null && apk == null) {
            settings.log("Car is up to date")
            return Outcome(null)
        }

        // Dash first, then the APK (the APK install may restart the head unit app).
        val pushed = mutableListOf<String>()
        for (file in listOfNotNull(dash, apk)) {
            if (isCancelled()) throw IOException("Stopped by the system")
            settings.log("Uploading ${file.name} to the car")
            when (car.upload(file.kind, file.release, file.sha256, cached(file), file.signature)) {
                HeadUnit.UploadResult.OK -> pushed += "${file.kind} v${file.release}"
                HeadUnit.UploadResult.NOT_NEWER -> settings.log("Car already has ${file.kind} v${file.release}")
            }
        }
        runCatching { settings.saveStatus(car.status()) }

        if (pushed.isEmpty()) return Outcome(null)
        val msg = "Car updated: " + pushed.joinToString(", ")
        settings.log(msg)
        return Outcome(msg)
    }

    /** Wi-Fi may report "connected" before routing works, so try a few times. */
    private fun findCar(): Pair<HeadUnit, HeadUnitStatus>? {
        repeat(3) { attempt ->
            HeadUnit.find(cm, settings::log)?.let { return it }
            if (attempt < 2 && !isCancelled()) Thread.sleep(3_000)
        }
        return null
    }

    private fun cached(file: UpdateFile) = File(cacheDir, file.name)

    /** Downloads [file] unless an identical verified copy is already cached. */
    private fun fetch(github: GitHub, file: UpdateFile) {
        val dest = cached(file)
        if (dest.exists() && Http.sha256(dest) == file.sha256) {
            settings.log("Using cached ${file.name}")
            return
        }
        settings.log("Downloading ${file.name}")
        val part = File(cacheDir, file.name + ".part")
        try {
            val hash = github.download(file, part)
            if (file.size >= 0 && part.length() != file.size) {
                throw IOException("${file.name}: size ${part.length()}, expected ${file.size}")
            }
            if (hash != file.sha256) throw IOException("${file.name}: sha256 mismatch")
            dest.delete()
            if (!part.renameTo(dest)) throw IOException("Could not store ${file.name}")
        } finally {
            part.delete()
        }
    }

    /** Keeps only the files still needed, so old releases do not pile up. */
    private fun pruneCache(keep: List<UpdateFile>) {
        val names = keep.map { it.name }.toSet()
        cacheDir.listFiles()?.filter { it.name !in names }?.forEach { it.delete() }
    }
}
