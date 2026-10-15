package au.jly.e60updater

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import java.io.File

/**
 * Hands exported log files (cache/logs) to the app the user shares them with, read-only, via
 * the per-share URI grant. Stands in for androidx FileProvider, which this app doesn't pull in.
 */
class LogFileProvider : ContentProvider() {
    companion object {
        const val AUTHORITY = "au.jly.e60updater.logs"
        fun dir(context: android.content.Context) = File(context.cacheDir, "logs").apply { mkdirs() }
        fun uri(file: File): Uri = Uri.parse("content://$AUTHORITY/${Uri.encode(file.name)}")
    }

    private fun file(uri: Uri): File {
        val name = uri.lastPathSegment ?: throw IllegalArgumentException("no file")
        val f = File(dir(context!!), name)
        if (f.parentFile != dir(context!!) || !f.isFile) throw IllegalArgumentException("no such log: $name")
        return f
    }

    override fun onCreate() = true

    override fun getType(uri: Uri) = "text/plain"

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor =
        ParcelFileDescriptor.open(file(uri), ParcelFileDescriptor.MODE_READ_ONLY)

    override fun query(uri: Uri, projection: Array<String>?, selection: String?,
                       selectionArgs: Array<String>?, sortOrder: String?): Cursor {
        val f = file(uri)
        val cols = projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
        return MatrixCursor(cols, 1).apply {
            addRow(cols.map { if (it == OpenableColumns.SIZE) f.length() else if (it == OpenableColumns.DISPLAY_NAME) f.name else null })
        }
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<String>?) = 0
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<String>?) = 0
}
