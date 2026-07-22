package com.coral.music.mobile

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.Manifest
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import java.io.File
import com.ryanheise.audioservice.AudioService
import com.ryanheise.audioservice.MediaButtonReceiver
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: AudioServiceActivity() {
    companion object {
        private const val MAX_SHARED_AUDIO_BYTES = 2L * 1024 * 1024 * 1024
        private const val DIRECTORY_READ_PERMISSION_REQUEST = 4001
    }

    private lateinit var userApiRunner: UserApiRunner
    private var sharedAudioChannel: MethodChannel? = null
    private var directoryReadResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // AudioServiceActivity connects its engine during Activity creation; the
        // service must therefore be available before Flutter plugin attachment.
        packageManager.setComponentEnabledSetting(
            ComponentName(this, AudioService::class.java),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        userApiRunner = UserApiRunner(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "coral_music/user_api")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "load" -> userApiRunner.load(call.argument<String>("script") ?: "", result)
                    "clear" -> userApiRunner.clear(result)
                    "resolveMusicUrl" -> userApiRunner.resolveMusicUrl(call.arguments as? Map<*, *>, result)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "coral_music/background_media")
            .setMethodCallHandler { call, result ->
                if (call.method != "setBackgroundMediaEnabled") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val enabled = call.argument<Boolean>("enabled") ?: false
                packageManager.setComponentEnabledSetting(
                    ComponentName(this, MediaButtonReceiver::class.java),
                    if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP,
                )
                result.success(null)
            }
        val sharedChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "coral_music/shared_audio")
        sharedAudioChannel = sharedChannel
        sharedChannel
            .setMethodCallHandler { call, result ->
                if (call.method != "consume") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                result.success(consumeSharedAudio())
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "coral_music/local_audio")
            .setMethodCallHandler { call, result ->
                if (call.method != "ensureDirectoryReadAccess") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                ensureDirectoryReadAccess(result)
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "coral_music/app_task")
            .setMethodCallHandler { call, result ->
                if (call.method != "moveTaskToBack") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                result.success(moveTaskToBack(true))
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "coral_music/downloads")
            .setMethodCallHandler { call, result ->
                if (call.method != "openDirectory") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                openDownloadDirectory(call.argument<String>("path"), result)
            }
    }

    private fun openDownloadDirectory(path: String?, result: MethodChannel.Result) {
        val directory = path?.let(::File)?.canonicalFile
        val external = Environment.getExternalStorageDirectory().canonicalFile
        if (directory == null || !directory.isDirectory ||
            (directory != external && !directory.path.startsWith("${external.path}${File.separator}")) ||
            Build.VERSION.SDK_INT < Build.VERSION_CODES.O
        ) {
            result.success(false)
            return
        }
        val relativePath = directory.relativeTo(external).path.replace(File.separatorChar, '/')
        val documentId = if (relativePath.isEmpty()) "primary:" else "primary:$relativePath"
        val initialUri = DocumentsContract.buildDocumentUri(
            "com.android.externalstorage.documents",
            documentId,
        )
        try {
            startActivity(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                putExtra(DocumentsContract.EXTRA_INITIAL_URI, initialUri)
            })
            result.success(true)
        } catch (_: Exception) {
            result.success(false)
        }
    }

    private fun ensureDirectoryReadAccess(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            result.success(true)
            return
        }
        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_AUDIO
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
        if (checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }
        if (directoryReadResult != null) {
            result.error("permission_request_active", "正在等待媒体访问授权", null)
            return
        }
        directoryReadResult = result
        requestPermissions(arrayOf(permission), DIRECTORY_READ_PERMISSION_REQUEST)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (requestCode == DIRECTORY_READ_PERMISSION_REQUEST) {
            directoryReadResult?.success(
                grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED,
            )
            directoryReadResult = null
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        sharedAudioChannel?.invokeMethod("shared", consumeSharedAudio())
    }

    private fun consumeSharedAudio(): List<String> {
        val current = intent ?: return emptyList()
        if (current.action != Intent.ACTION_SEND && current.action != Intent.ACTION_SEND_MULTIPLE) {
            return emptyList()
        }
        val uris = when (current.action) {
            Intent.ACTION_SEND -> listOfNotNull(current.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))
            else -> current.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM) ?: emptyList()
        }
        val directory = File(filesDir, "shared-audio").apply { mkdirs() }
        val paths = uris.mapNotNull { uri -> copySharedAudio(uri, directory) }
        current.removeExtra(Intent.EXTRA_STREAM)
        return paths
    }

    private fun copySharedAudio(uri: Uri, directory: File): String? {
        var target: File? = null
        return try {
            val name = displayName(uri).replace(Regex("[^a-zA-Z0-9._ -]"), "_")
            val outputFile = File(directory, "${System.currentTimeMillis()}-$name")
            target = outputFile
            val input = contentResolver.openInputStream(uri) ?: return null
            input.use { stream ->
                outputFile.outputStream().use { output ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    var copied = 0L
                    while (true) {
                        val count = stream.read(buffer)
                        if (count < 0) break
                        copied += count
                        if (copied > MAX_SHARED_AUDIO_BYTES) throw IllegalArgumentException("Shared file is too large")
                        output.write(buffer, 0, count)
                    }
                }
            }
            outputFile.absolutePath
        } catch (_: Exception) {
            target?.delete()
            null
        }
    }

    private fun displayName(uri: Uri): String {
        val cursor: Cursor? = contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
        cursor?.use {
            if (it.moveToFirst()) return it.getString(0) ?: "shared-audio"
        }
        return uri.lastPathSegment ?: "shared-audio"
    }

    override fun onDestroy() {
        userApiRunner.dispose()
        super.onDestroy()
    }
}
