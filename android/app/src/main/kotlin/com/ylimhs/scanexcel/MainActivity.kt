package com.ylimhs.scanexcel

import android.app.Activity
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import androidx.documentfile.provider.DocumentFile
import com.ylimhs.scanexcel.scanner.NativeDocumentChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.net.URLDecoder
import java.nio.charset.StandardCharsets
import java.util.Base64

class MainActivity : FlutterActivity() {
    private val shareChannel = "scanexcel/share_import"
    private val shareEventChannel = "scanexcel/share_import_events"
    private val savePathChannel = "scanexcel/save_path"
    private val requestPickDirectory = 41021
    private var initialSharedFile: String? = null
    private var pendingSavePathResult: MethodChannel.Result? = null
    private var shareEventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initialSharedFile = resolveSharedFile(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val shared = resolveSharedFile(intent)
        initialSharedFile = shared
        if (!shared.isNullOrEmpty()) {
            shareEventSink?.success(shared)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NativeDocumentChannel.register(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shareChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialSharedFile" -> result.success(initialSharedFile)
                else -> result.notImplemented()
            }
        }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, shareEventChannel).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                shareEventSink = events
            }
            override fun onCancel(arguments: Any?) {
                shareEventSink = null
            }
        })
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, savePathChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickBaseDirectory" -> {
                    pendingSavePathResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                    startActivityForResult(intent, requestPickDirectory)
                }
                "writeBytesToTree" -> {
                    val treeUri = call.argument<String>("treeUri") ?: ""
                    val fileName = call.argument<String>("fileName") ?: "output.bin"
                    val bytesBase64 = call.argument<String>("bytesBase64") ?: ""
                    val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                    result.success(writeBytesToTree(treeUri, fileName, bytesBase64, mimeType))
                }
                "openDocumentUri" -> {
                    val uriString = call.argument<String>("uri") ?: ""
                    val mimeType = call.argument<String>("mimeType") ?: "*/*"
                    result.success(openDocumentUri(uriString, mimeType))
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == requestPickDirectory) {
            val result = pendingSavePathResult
            pendingSavePathResult = null
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                result?.success(null)
                return
            }
            val uri = data.data!!
            val flags = data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            try {
                contentResolver.takePersistableUriPermission(uri, flags)
            } catch (_: Throwable) {
            }
            result?.success(mapOf("uri" to uri.toString(), "displayPath" to (resolveDisplayPath(uri) ?: "已选择文件夹")))
        }
    }

    private fun resolveSharedFile(intent: Intent?): String? {
        intent ?: return null
        val action = intent.action ?: return null
        val uri: Uri? = when (action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> intent.getParcelableExtra(Intent.EXTRA_STREAM)
            Intent.ACTION_SEND_MULTIPLE -> {
                val list = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                list?.firstOrNull()
            }
            else -> null
        }
        uri ?: return null
        return copyUriToCache(uri)
    }

    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val input = contentResolver.openInputStream(uri) ?: return null
            val displayName = queryDisplayName(uri)
            val safeName = sanitizeFileName(displayName ?: "shared_${System.currentTimeMillis()}.xlsx")
            val target = File(cacheDir, safeName)
            FileOutputStream(target).use { output -> input.use { it.copyTo(output) } }
            target.absolutePath
        } catch (_: Throwable) {
            null
        }
    }

    private fun resolveDisplayPath(uri: Uri): String? {
        return try {
            val docId = android.provider.DocumentsContract.getTreeDocumentId(uri)
            val parts = docId.split(":")
            if (parts.size >= 2 && parts[0].equals("primary", ignoreCase = true)) {
                "/storage/emulated/0/${decodePath(parts[1])}"
            } else decodeUriString(uri.toString())
        } catch (_: Throwable) {
            decodeUriString(uri.toString())
        }
    }

    private fun decodePath(value: String): String {
        return try {
            URLDecoder.decode(value, StandardCharsets.UTF_8.name())
        } catch (_: Throwable) {
            value
        }
    }

    private fun decodeUriString(value: String): String {
        return try {
            URLDecoder.decode(value, StandardCharsets.UTF_8.name())
        } catch (_: Throwable) {
            value
        }
    }

    private fun writeBytesToTree(treeUriString: String, fileName: String, bytesBase64: String, mimeType: String): Map<String, String>? {
        return try {
            val treeUri = Uri.parse(treeUriString)
            val root = DocumentFile.fromTreeUri(this, treeUri) ?: return null
            val appDir = root.findFile("ScanExcel") ?: root.createDirectory("ScanExcel") ?: return null
            appDir.findFile(fileName)?.delete()
            val file = appDir.createFile(mimeType, fileName) ?: return null
            val bytes = Base64.getDecoder().decode(bytesBase64)
            contentResolver.openOutputStream(file.uri)?.use { it.write(bytes) }
            mapOf(
                "uri" to file.uri.toString(),
                "displayPath" to buildDisplayPath(treeUri, fileName)
            )
        } catch (_: Throwable) {
            null
        }
    }

    private fun buildDisplayPath(treeUri: Uri, fileName: String): String {
        val base = resolveDisplayPath(treeUri) ?: "已选择文件夹"
        return "$base/ScanExcel/$fileName"
    }

    private fun queryDisplayName(uri: Uri): String? {
        return try {
            val cursor: Cursor? = contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            cursor?.use {
                if (it.moveToFirst()) {
                    val index = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (index >= 0) return it.getString(index)
                }
            }
            null
        } catch (_: Throwable) {
            null
        }
    }

    private fun openDocumentUri(uriString: String, mimeType: String): Boolean {
        return try {
            val uri = Uri.parse(uriString)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mimeType)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun sanitizeFileName(input: String): String {
        return input.replace(Regex("[\\\\/:*?\"<>|]"), "_")
    }
}
