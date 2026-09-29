package com.example.phone_comm

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private var pendingResult: MethodChannel.Result? = null
    private var pendingText: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "phone_comm/files")
            .setMethodCallHandler { call, result ->
                if (pendingResult != null) {
                    result.error("busy", "文件选择器正在使用", null)
                    return@setMethodCallHandler
                }
                try {
                    when (call.method) {
                        "pickFile" -> {
                            pendingResult = result
                            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "*/*"
                            }
                            startActivityForResult(intent, OPEN_FILE)
                        }
                        "saveLog" -> {
                            pendingResult = result
                            pendingText = call.argument<String>("text") ?: ""
                            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TITLE, "phonecomm-log.txt")
                            }
                            startActivityForResult(intent, SAVE_LOG)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    pendingResult = null
                    pendingText = null
                    result.error("file_picker", error.message, null)
                }
            }
    }

    @Deprecated("Android activity result API")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != OPEN_FILE && requestCode != SAVE_LOG) return
        val callback = pendingResult ?: return
        val text = pendingText
        pendingResult = null
        pendingText = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            callback.success(null)
            return
        }
        Thread {
            var copy: File? = null
            try {
                if (requestCode == OPEN_FILE) {
                    val source = contentResolver.openInputStream(uri)
                        ?: throw IllegalStateException("无法读取所选文件")
                    copy = File.createTempFile("phonecomm-send-", ".bin", cacheDir)
                    source.use { input ->
                        copy.outputStream().use { output -> input.copyTo(output) }
                    }
                    runOnUiThread { callback.success(copy.absolutePath) }
                } else {
                    val output = contentResolver.openOutputStream(uri, "wt")
                        ?: throw IllegalStateException("无法写入所选文件")
                    output.use { it.write((text ?: "").toByteArray(Charsets.UTF_8)) }
                    runOnUiThread { callback.success(true) }
                }
            } catch (error: Exception) {
                copy?.delete()
                runOnUiThread { callback.error("file_io", error.message, null) }
            }
        }.start()
    }

    companion object {
        private const val OPEN_FILE = 1001
        private const val SAVE_LOG = 1002
    }
}
