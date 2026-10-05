package com.burakaydogmus.ruya

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterFragmentActivity() {
    private val cryptoExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CRYPTO_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pbkdf2Sha256" -> {
                        val password = call.argument<ByteArray>("password")
                        val salt = call.argument<ByteArray>("salt")
                        val iterations = call.argument<Int>("iterations")
                        val length = call.argument<Int>("length")
                        if (password == null || salt == null || iterations == null || length == null ||
                            iterations < 1 || length < 1
                        ) {
                            result.error("bad_args", "Invalid PBKDF2 arguments", null)
                            return@setMethodCallHandler
                        }
                        cryptoExecutor.execute {
                            try {
                                val key = RuyaCrypto.pbkdf2Sha256(password, salt, iterations, length)
                                runOnUiThread { result.success(key) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("pbkdf2_failed", e.message, null) }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, IDENTITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "setDiscrete" -> {
                            setDiscrete(call.argument<Boolean>("enabled") == true)
                            result.success(isDiscrete())
                        }
                        "isDiscrete" -> result.success(isDiscrete())
                        "setHideInRecents" -> {
                            setHideInRecents(call.argument<Boolean>("hide") == true)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("identity_failed", e.message, null)
                }
            }
    }

    /**
     * Discrete mode: switches the launcher entry between the RUYA alias and the
     * neutral alias. The new alias is enabled before the old one is disabled so
     * there is always a launcher entry. DONT_KILL_APP keeps the process alive;
     * some launchers need a few seconds to refresh the icon.
     */
    private fun setDiscrete(enabled: Boolean) {
        val pm = packageManager
        val on = PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        val off = PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        val (show, hide) = if (enabled) discreteAlias() to defaultAlias() else defaultAlias() to discreteAlias()
        pm.setComponentEnabledSetting(show, on, PackageManager.DONT_KILL_APP)
        pm.setComponentEnabledSetting(hide, off, PackageManager.DONT_KILL_APP)
    }

    /**
     * Hides the app content in the recents (overview) screen. Android 13+ has a
     * dedicated API that keeps screenshots possible; older versions fall back to
     * FLAG_SECURE, which also blocks screenshots while enabled.
     */
    private fun setHideInRecents(hide: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(!hide)
        } else if (hide) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    private fun isDiscrete(): Boolean =
        packageManager.getComponentEnabledSetting(discreteAlias()) == PackageManager.COMPONENT_ENABLED_STATE_ENABLED

    private fun defaultAlias() = ComponentName(this, "$packageName.LauncherDefault")
    private fun discreteAlias() = ComponentName(this, "$packageName.LauncherDiscrete")

    override fun onDestroy() {
        cryptoExecutor.shutdown()
        super.onDestroy()
    }

    companion object {
        private const val CRYPTO_CHANNEL = "com.burakaydogmus.ruya/crypto"
        private const val IDENTITY_CHANNEL = "com.burakaydogmus.ruya/app_identity"
    }
}
