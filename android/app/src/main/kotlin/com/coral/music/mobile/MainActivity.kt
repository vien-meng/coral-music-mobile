package com.coral.music.mobile

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Bundle
import com.ryanheise.audioservice.AudioService
import com.ryanheise.audioservice.MediaButtonReceiver
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: AudioServiceActivity() {
    private lateinit var userApiRunner: UserApiRunner

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
                    "resolveLyric" -> userApiRunner.resolveLyric(call.arguments as? Map<*, *>, result)
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
    }

    override fun onDestroy() {
        userApiRunner.dispose()
        super.onDestroy()
    }
}
