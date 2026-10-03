package au.jly.e60updater

import android.net.Network
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.IOException

/** One file named in a release manifest, with the asset API URL to fetch it from. */
data class UpdateFile(
    val kind: String, // "dash", "speedlimits" or "apk", also the head unit upload path
    val release: Int,
    val name: String,
    val sha256: String,
    val size: Long,
    val assetUrl: String,
    val signature: String, // release-tool signature, checked by the head unit
)

/** Reads releases and their manifest.json assets from GitHub, over the given internet network. */
class GitHub(private val network: Network, private val repo: String, private val token: String) {

    private fun headers(accept: String): Map<String, String> = buildMap {
        put("Accept", accept)
        put("User-Agent", "E60CarUpdater")
        put("X-GitHub-Api-Version", "2022-11-28")
        if (token.isNotEmpty()) put("Authorization", "Bearer $token")
    }

    /**
     * Picks, per PROTOCOL.md, for each kind in [have] the highest release whose manifest has that
     * kind newer than the head unit's release of it. Kinds with nothing newer are left out.
     */
    fun pick(have: Map<String, Int>, log: (String) -> Unit): Map<String, UpdateFile> {
        val releases = JSONArray(
            Http.getText(network, "https://api.github.com/repos/$repo/releases?per_page=20",
                headers("application/vnd.github+json"))
        )
        // Highest tag first, so we can stop at the first match of each kind.
        val candidates = (0 until releases.length()).map { releases.getJSONObject(it) }
            .filter { !it.optBoolean("draft") }
            .sortedByDescending { tagNumber(it.optString("tag_name")) }

        val picked = mutableMapOf<String, UpdateFile>()
        for (rel in candidates) {
            val stillNeeded = have.filterKeys { it !in picked }
            if (stillNeeded.isEmpty()) break
            val tagN = tagNumber(rel.optString("tag_name"))
            // Tags are sorted; once a tag is not newer than anything still needed, stop listing.
            if (tagN >= 0 && stillNeeded.values.all { tagN <= it }) break
            val assets = rel.optJSONArray("assets") ?: continue
            val manifestUrl = assetUrl(assets, "manifest.json") ?: continue
            val manifest = try {
                JSONObject(Http.getText(network, manifestUrl, headers("application/octet-stream")))
            } catch (e: Exception) {
                log("Bad manifest in ${rel.optString("tag_name")}: ${e.message}")
                continue
            }
            val n = manifest.optInt("release", 0)
            for ((kind, current) in stillNeeded) {
                if (n > current) fileOf(manifest, kind, n, assets)?.let { picked[kind] = it }
            }
        }
        return picked
    }

    private fun fileOf(manifest: JSONObject, kind: String, release: Int, assets: JSONArray): UpdateFile? {
        val entry = manifest.optJSONObject(kind) ?: return null
        val name = entry.optString("name")
        val url = assetUrl(assets, name) ?: return null
        return UpdateFile(kind, release, name, entry.optString("sha256").lowercase(),
            entry.optLong("size", -1), url, entry.optString("sig"))
    }

    fun download(file: UpdateFile, dest: File): String =
        Http.download(network, file.assetUrl, headers("application/octet-stream"), dest)

    private fun assetUrl(assets: JSONArray, name: String): String? {
        if (name.isEmpty()) return null
        for (i in 0 until assets.length()) {
            val a = assets.getJSONObject(i)
            if (a.optString("name") == name) return a.optString("url").ifEmpty { null }
        }
        return null
    }

    /** "v12" -> 12; anything else -> -1 (sorted last, never stops the scan early). */
    private fun tagNumber(tag: String): Int =
        tag.removePrefix("v").toIntOrNull() ?: -1

    companion object {
        fun checkRepo(repo: String) {
            if (!Regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$").matches(repo)) {
                throw IOException("GitHub repo must look like owner/name")
            }
        }
    }
}
