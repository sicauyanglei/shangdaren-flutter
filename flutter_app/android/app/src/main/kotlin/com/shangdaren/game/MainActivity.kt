package com.shangdaren.game

import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.View
import android.view.WindowManager
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingAutoTestRounds: Int = 0
    private val testChannel = "com.shangdaren.game/test"
    private val logChannel = "com.shangdaren.game/log"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        checkIntent(intent)
        hideSystemUI()
    }

    override fun onResume() {
        super.onResume()
        hideSystemUI()
    }

    private fun hideSystemUI() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).let { controller ->
            controller.hide(WindowInsetsCompat.Type.systemBars())
            controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        checkIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, testChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPendingRounds" -> {
                        result.success(pendingAutoTestRounds)
                        pendingAutoTestRounds = 0
                    }
                    "clearPendingRounds" -> {
                        pendingAutoTestRounds = 0
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, logChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "log") {
                    val tag = call.argument<String>("tag") ?: "Game"
                    val msg = call.argument<String>("msg") ?: ""
                    Log.d(tag, msg)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun checkIntent(intent: Intent?) {
        if (intent == null) return
        val autoTest = intent.getBooleanExtra("auto_test", false)
        val testRounds = intent.getIntExtra("test_rounds", 3)
        if (autoTest) {
            pendingAutoTestRounds = testRounds
            Log.d("AUTOTEST", "Intent received: auto_test=true, rounds=$testRounds")
        }
    }
}
