package com.shivarajbakale.parley

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private var bridge: ParleyBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ParleyRuntime.init(applicationContext)
        bridge?.dispose()
        bridge = ParleyBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        bridge?.dispose()
        bridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onResume() {
        super.onResume()
        // Mic, battery and the accessibility toggle change in Settings with no
        // callback; coming back to the app is when they are re-read.
        ParleyRuntime.init(applicationContext)
        ParleyRuntime.refreshStatus()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        bridge?.onPermissionResult(requestCode)
    }
}
