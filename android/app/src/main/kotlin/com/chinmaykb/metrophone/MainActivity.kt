package com.chinmaykb.metrophone

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private lateinit var launcherBridge: LauncherBridge

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        launcherBridge = LauncherBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onDestroy() {
        if (::launcherBridge.isInitialized) launcherBridge.dispose()
        super.onDestroy()
    }
}
