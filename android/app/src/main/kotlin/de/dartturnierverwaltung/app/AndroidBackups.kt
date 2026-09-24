package de.dartturnierverwaltung.app

import android.app.Activity
import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Android document picker exports to Downloads, USB or a document provider. */
class AndroidBackups(private val activity: Activity, messenger: BinaryMessenger) {
    private var pending: MethodChannel.Result? = null
    private var bytes: ByteArray? = null
    private val requestCode = 60183

    init {
        MethodChannel(messenger, "dartturnier/backups").setMethodCallHandler { call, result ->
            if (call.method != "export") { result.notImplemented(); return@setMethodCallHandler }
            val data = call.arguments as? ByteArray
            if (pending != null || data == null || data.size > 128 * 1024 * 1024) {
                result.error("BACKUP_EXPORT", "Export nicht möglich", null)
                return@setMethodCallHandler
            }
            pending = result
            bytes = data
            try {
                activity.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "application/octet-stream"
                    putExtra(Intent.EXTRA_TITLE, "Turniere_${System.currentTimeMillis()}.dartbackup")
                }, requestCode)
            } catch (error: Exception) {
                pending = null; bytes = null
                result.error("BACKUP_EXPORT", error.message, null)
            }
        }
    }

    fun onActivityResult(request: Int, resultCode: Int, data: Intent?): Boolean {
        if (request != requestCode) return false
        val result = pending
        val content = bytes
        pending = null; bytes = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || content == null) {
            result?.success(false)
            return true
        }
        Thread {
            try {
                val output = activity.contentResolver.openOutputStream(uri, "wt")
                    ?: throw IllegalStateException("Datei konnte nicht geöffnet werden")
                output.use { it.write(content); it.flush() }
                activity.runOnUiThread { result?.success(true) }
            } catch (error: Exception) {
                activity.runOnUiThread { result?.error("BACKUP_EXPORT", error.message, null) }
            }
        }.start()
        return true
    }
}
