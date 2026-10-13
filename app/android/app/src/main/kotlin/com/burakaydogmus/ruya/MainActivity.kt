package com.burakaydogmus.ruya

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.SoundPool
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterFragmentActivity() {
    private val cryptoExecutor = Executors.newSingleThreadExecutor()

    // Interface sounds (off by default in the app). Loaded on first use.
    private var soundPool: SoundPool? = null
    private val soundIds = HashMap<String, Int>()

    // Launcher alias to switch to once the app is left, see requestLauncher.
    private var pendingLauncher: String? = null
    private var openedAnotherActivity = false
    private val soundRes = mapOf(
        "save" to R.raw.sfx_save,
        "select" to R.raw.sfx_select,
        "celebrate" to R.raw.sfx_celebrate,
        "pet" to R.raw.sfx_pet,
    )

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SFX_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "play") {
                    playSound(call.argument<String>("name") ?: "")
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, IDENTITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "setLauncher" -> {
                            requestLauncher(call.argument<String>("alias") ?: "")
                            result.success(pendingLauncher ?: currentLauncher())
                        }
                        "currentLauncher" -> result.success(pendingLauncher ?: currentLauncher())
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
     * Remembers the launcher entry to switch to. Android closes a task as soon
     * as the alias it was started from is disabled, so the switch waits until
     * the user leaves the app (see onStop) instead of closing it under her hands.
     */
    private fun requestLauncher(alias: String) {
        if (alias !in LAUNCHER_ALIASES) throw IllegalArgumentException("Unknown launcher alias")
        pendingLauncher = if (alias == currentLauncher()) null else alias
    }

    override fun startActivityForResult(intent: Intent, requestCode: Int, options: Bundle?) {
        // a file picker or share sheet opened by the app: it must find the task alive on return
        openedAnotherActivity = true
        super.startActivityForResult(intent, requestCode, options)
    }

    override fun onResume() {
        super.onResume()
        openedAnotherActivity = false
    }

    override fun onStop() {
        super.onStop()
        val alias = pendingLauncher
        if (alias != null && !openedAnotherActivity && !isChangingConfigurations) {
            pendingLauncher = null
            try {
                setLauncher(alias)
            } catch (e: Exception) {
                // the app asks again on the next start
            }
        }
    }

    /**
     * Switches the launcher entry to one alias: "Default" (RUYA), an icon
     * choice, or "Discrete" (neutral name and icon). The new alias is enabled
     * before the others are disabled so there is always a launcher entry.
     * Launchers may need a few seconds to refresh, and some drop a home screen
     * shortcut that pointed at the old alias.
     */
    private fun setLauncher(alias: String) {
        val pm = packageManager
        pm.setComponentEnabledSetting(
            launcherAlias(alias), PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP,
        )
        for (other in LAUNCHER_ALIASES) {
            if (other == alias) continue
            pm.setComponentEnabledSetting(
                launcherAlias(other), PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP,
            )
        }
    }

    /** The alias that is enabled now; "Default" is the one the manifest enables. */
    private fun currentLauncher(): String =
        LAUNCHER_ALIASES.firstOrNull {
            packageManager.getComponentEnabledSetting(launcherAlias(it)) ==
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        } ?: "Default"

    private fun launcherAlias(alias: String) = ComponentName(this, "$packageName.Launcher$alias")

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

    /** Plays a short interface sound; the first request for a sound loads it and plays it once ready. */
    private fun playSound(name: String) {
        val res = soundRes[name] ?: return
        val pool = soundPool ?: SoundPool.Builder()
            .setMaxStreams(2)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            .build()
            .also { p ->
                soundPool = p
                p.setOnLoadCompleteListener { pool, id, status -> if (status == 0) pool.play(id, 0.6f, 0.6f, 1, 0, 1f) }
            }
        val id = soundIds[name]
        if (id != null) {
            pool.play(id, 0.6f, 0.6f, 1, 0, 1f)
        } else {
            soundIds[name] = pool.load(this, res, 1)
        }
    }

    override fun onDestroy() {
        cryptoExecutor.shutdown()
        soundPool?.release()
        soundPool = null
        super.onDestroy()
    }

    companion object {
        private const val CRYPTO_CHANNEL = "com.burakaydogmus.ruya/crypto"
        private const val IDENTITY_CHANNEL = "com.burakaydogmus.ruya/app_identity"
        private const val SFX_CHANNEL = "com.burakaydogmus.ruya/sfx"

        /** Names of the launcher activity-aliases in the manifest, without the "Launcher" prefix. */
        private val LAUNCHER_ALIASES = listOf("Default", "Pamuk", "Tarcin", "Lokum", "Ay", "Lale", "Discrete")
    }
}
