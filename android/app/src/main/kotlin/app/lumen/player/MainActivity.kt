package app.lumen.player

import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.lumen/platform")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "deviceProfile" -> result.success(deviceProfile())
                    else -> result.notImplemented()
                }
            }
    }

    /** Erkennt Android TV (Leanback / UI-Modus Fernseher) und Fire TV. */
    private fun deviceProfile(): Map<String, Boolean> {
        val pm = packageManager
        val uiMode = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
        val isFireTv = pm.hasSystemFeature("amazon.hardware.fire_tv")
        val isTv = isFireTv ||
            pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
            uiMode.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
        return mapOf("isTv" to isTv, "isFireTv" to isFireTv)
    }
}
