package de.dartturnierverwaltung.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.net.wifi.WifiManager

class MainActivity : FlutterActivity() {
    private var backups: AndroidBackups? = null
    private var multicastLock: WifiManager.MulticastLock? = null
    private var discoveryActive = false
    private var foreground = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AndroidUpdates(this, flutterEngine.dartExecutor.binaryMessenger)
        backups = AndroidBackups(this, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dartturnier/discovery").setMethodCallHandler { call, result ->
            if (call.method == "setActive") {
                discoveryActive = call.arguments as? Boolean ?: false
                updateMulticast()
                result.success(null)
            } else result.notImplemented()
        }
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        if (backups?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }
    private fun updateMulticast() {
        if (discoveryActive && foreground) {
            if (multicastLock == null) {
                val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                multicastLock = wifi.createMulticastLock("dartturnier-discovery").apply { setReferenceCounted(false) }
            }
            if (multicastLock?.isHeld == false) multicastLock?.acquire()
        } else if (multicastLock?.isHeld == true) multicastLock?.release()
    }
    override fun onResume() { super.onResume(); foreground = true; updateMulticast() }
    override fun onPause() { foreground = false; updateMulticast(); super.onPause() }
    override fun onDestroy() { discoveryActive = false; updateMulticast(); super.onDestroy() }
}
