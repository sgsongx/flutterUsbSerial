package com.example.phone_comm

import android.app.Activity
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStream
import java.util.concurrent.Executors

class MainActivity: FlutterActivity() {
    private var pendingResult: MethodChannel.Result? = null
    private var pendingText: String? = null
    private val recordExecutor = Executors.newSingleThreadExecutor()
    private var recordStream: OutputStream? = null

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
                        "startRecording" -> recordTask(result) {
                            val name = call.argument<String>("name")?.trim() ?: ""
                            require(name.isNotEmpty() && name.length <= 100 && name != "." && name != ".." &&
                                name.none { it in "\\/:*?\"<>|" || it.code < 32 }) { "文件名无效" }
                            val append = call.argument<Boolean>("append") == true
                            recordStream?.close()
                            recordStream = null
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                val path = "${Environment.DIRECTORY_DOWNLOADS}/PhoneComm/"
                                val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                                val columns = arrayOf(MediaStore.Downloads._ID)
                                val selection = "${MediaStore.Downloads.DISPLAY_NAME}=? AND ${MediaStore.Downloads.RELATIVE_PATH}=?"
                                val uri = contentResolver.query(collection, columns, selection,
                                    arrayOf(name, path), null)?.use { cursor ->
                                    if (cursor.moveToFirst()) ContentUris.withAppendedId(collection, cursor.getLong(0)) else null
                                } ?: contentResolver.insert(collection, ContentValues().apply {
                                    put(MediaStore.Downloads.DISPLAY_NAME, name)
                                    put(MediaStore.Downloads.MIME_TYPE, "text/plain")
                                    put(MediaStore.Downloads.RELATIVE_PATH, path)
                                }) ?: throw IllegalStateException("无法创建记录文件")
                                recordStream = contentResolver.openOutputStream(uri, if (append) "wa" else "wt")
                                    ?: throw IllegalStateException("无法打开记录文件")
                                "下载/PhoneComm/$name"
                            } else {
                                val folder = File(getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS) ?: filesDir,
                                    "PhoneComm")
                                check(folder.isDirectory || folder.mkdirs()) { "无法创建记录目录" }
                                val file = File(folder, name)
                                recordStream = FileOutputStream(file, append)
                                file.absolutePath
                            }
                        }
                        "appendRecording" -> recordTask(result) {
                            val stream = recordStream ?: throw IllegalStateException("尚未开始记录")
                            try {
                                stream.write((call.argument<String>("text") ?: "").toByteArray(Charsets.UTF_8))
                                stream.flush()
                            } catch (error: Exception) {
                                recordStream = null
                                runCatching { stream.close() }
                                throw error
                            }
                            true
                        }
                        "stopRecording" -> recordTask(result) {
                            recordStream?.close()
                            recordStream = null
                            true
                        }
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

    private fun recordTask(result: MethodChannel.Result, work: () -> Any?) {
        recordExecutor.execute {
            try {
                val value = work()
                runOnUiThread { result.success(value) }
            } catch (error: Exception) {
                runOnUiThread { result.error("record_file", error.message, null) }
            }
        }
    }

    override fun onDestroy() {
        recordExecutor.execute { runCatching { recordStream?.close() }; recordStream = null }
        recordExecutor.shutdown()
        super.onDestroy()
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
