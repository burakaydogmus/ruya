package com.burakaydogmus.ruya

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
    }

    override fun onDestroy() {
        cryptoExecutor.shutdown()
        super.onDestroy()
    }

    companion object {
        private const val CRYPTO_CHANNEL = "com.burakaydogmus.ruya/crypto"
    }
}
