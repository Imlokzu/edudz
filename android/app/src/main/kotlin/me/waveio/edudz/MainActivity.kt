package me.waveio.edudz

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity: FlutterActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private var pendingFile: File? = null

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "edudz/files").setMethodCallHandler { call, result ->
            if (call.method != "save") { result.notImplemented(); return@setMethodCallHandler }
            try {
                val source = File(call.argument<String>("path") ?: "").canonicalFile
                val allowed = listOf(cacheDir.canonicalFile, filesDir.canonicalFile)
                require(allowed.any { source.path.startsWith(it.path + File.separator) } && source.isFile)
                val name = (call.argument<String>("name") ?: source.name).replace(Regex("[/\\\\\\x00-\\x1f]"), "_").take(180)
                val mime = call.argument<String>("mime") ?: "application/octet-stream"
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    executor.execute {
                        var uri: Uri? = null
                        try {
                            val values = ContentValues().apply {
                                put(MediaStore.Downloads.DISPLAY_NAME, name)
                                put(MediaStore.Downloads.MIME_TYPE, mime)
                                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/edudz")
                                put(MediaStore.Downloads.IS_PENDING, 1)
                            }
                            uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values) ?: error("Cannot create download")
                            contentResolver.openOutputStream(uri!!)?.use { output -> source.inputStream().use { it.copyTo(output) } } ?: error("Cannot save download")
                            contentResolver.update(uri!!, ContentValues().apply { put(MediaStore.Downloads.IS_PENDING, 0) }, null, null)
                            runOnUiThread { result.success(uri.toString()) }
                        } catch (e: Exception) {
                            uri?.let { contentResolver.delete(it, null, null) }
                            runOnUiThread { result.error("save_failed", "Could not save attachment", null) }
                        }
                    }
                } else {
                    if (pending != null) { result.error("save_busy", "Another save is in progress", null); return@setMethodCallHandler }
                    pending = result; pendingFile = source
                    startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE); type = mime; putExtra(Intent.EXTRA_TITLE, name)
                    }, 2181)
                }
            } catch (e: Exception) { result.error("save_failed", "Could not save attachment", null) }
        }
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 2181) return
        val result = pending ?: return; val source = pendingFile
        pending = null; pendingFile = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || source == null) { result.success(null); return }
        executor.execute {
            try {
                contentResolver.openOutputStream(uri)?.use { output -> source.inputStream().use { it.copyTo(output) } } ?: error("Cannot save")
                runOnUiThread { result.success(uri.toString()) }
            } catch (e: Exception) { runOnUiThread { result.error("save_failed", "Could not save attachment", null) } }
        }
    }
    override fun onDestroy() { pending?.error("save_cancelled", "Activity closed", null); pending = null; executor.shutdown(); super.onDestroy() }
}
