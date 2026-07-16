package com.coral.music.mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private lateinit var userApiRunner: UserApiRunner

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        userApiRunner = UserApiRunner(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "coral_music/user_api")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "load" -> userApiRunner.load(call.argument<String>("script") ?: "", result)
                    "resolveMusicUrl" -> userApiRunner.resolveMusicUrl(call.arguments as? Map<*, *>, result)
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        userApiRunner.dispose()
        super.onDestroy()
    }
}
