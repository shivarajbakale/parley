package com.shivarajbakale.parley

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Settings, API keys, the pause switch and the orb's position.
 *
 * Backed by EncryptedSharedPreferences in the app ([create]); tests pass plain
 * preferences. Full keys are readable only in-process ([groqKey], [minimaxKey]);
 * the [config] flow carries their last four characters and nothing more.
 */
class ConfigStore(private val prefs: SharedPreferences) {

    companion object {
        private const val TAG = "ParleyConfig"
        const val FILE = "parley_secure_prefs"

        private const val K_ORB_ENABLED = "orbEnabled"
        private const val K_ORB_SIZE = "orbSize"
        private const val K_HIDE_WITHOUT_FIELD = "hideOrbWithoutField"
        private const val K_VOLUME = "volumeGestureEnabled"
        private const val K_LANGUAGE = "language"
        private const val K_LEADING_SPACE = "leadingSpace"
        private const val K_HAPTICS = "haptics"
        private const val K_RETENTION = "historyRetentionDays"
        private const val K_GROQ = "groqKey"
        private const val K_MINIMAX = "minimaxKey"
        private const val K_PAUSED = "paused"
        private const val K_ORB_RIGHT = "orbDockRight"
        private const val K_ORB_Y = "orbYFraction"

        fun create(context: Context): ConfigStore = ConfigStore(openEncrypted(context.applicationContext))

        private fun openEncrypted(context: Context): SharedPreferences {
            fun open(): SharedPreferences {
                val masterKey = MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build()
                return EncryptedSharedPreferences.create(
                    context,
                    FILE,
                    masterKey,
                    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
                )
            }
            return try {
                open()
            } catch (e: Exception) {
                // A keystore reset (restore to a new device, OS bug) leaves an
                // undecryptable file. Keys are revocable at the provider, so the
                // recovery is to start clean rather than crash on every launch.
                Log.w(TAG, "Encrypted prefs unreadable, resetting", e)
                context.deleteSharedPreferences(FILE)
                open()
            }
        }

        fun last4(key: String?): String? = key?.takeIf { it.isNotEmpty() }?.takeLast(4)

        private val LANGUAGE = Regex("^(auto|[a-z]{2})$")
    }

    private val _config = MutableStateFlow(read())
    val config: StateFlow<Config> = _config.asStateFlow()

    private val _paused = MutableStateFlow(prefs.getBoolean(K_PAUSED, false))
    val paused: StateFlow<Boolean> = _paused.asStateFlow()

    val groqKey: String? get() = prefs.getString(K_GROQ, null)?.takeIf { it.isNotEmpty() }
    val minimaxKey: String? get() = prefs.getString(K_MINIMAX, null)?.takeIf { it.isNotEmpty() }

    private fun read() = Config(
        orbEnabled = prefs.getBoolean(K_ORB_ENABLED, true),
        orbSize = OrbSize.fromWire(prefs.getString(K_ORB_SIZE, null) ?: "") ?: OrbSize.MEDIUM,
        hideOrbWithoutField = prefs.getBoolean(K_HIDE_WITHOUT_FIELD, true),
        volumeGestureEnabled = prefs.getBoolean(K_VOLUME, true),
        language = prefs.getString(K_LANGUAGE, "auto") ?: "auto",
        leadingSpace = prefs.getBoolean(K_LEADING_SPACE, true),
        haptics = prefs.getBoolean(K_HAPTICS, true),
        historyRetentionDays = prefs.getInt(K_RETENTION, 30),
        groqKeyLast4 = last4(prefs.getString(K_GROQ, null)),
        minimaxKeyLast4 = last4(prefs.getString(K_MINIMAX, null)),
    )

    /**
     * Applies one bridge `setConfig` change. Throws [IllegalArgumentException]
     * for an unknown key or a value of the wrong type; the bridge reports that
     * as `invalid_argument`.
     */
    fun set(key: String, value: Any?): Config {
        val edit = prefs.edit()
        fun bool(): Boolean = value as? Boolean ?: throw IllegalArgumentException("$key must be a bool")
        when (key) {
            K_ORB_ENABLED, K_HIDE_WITHOUT_FIELD, K_VOLUME, K_LEADING_SPACE, K_HAPTICS -> edit.putBoolean(key, bool())
            K_ORB_SIZE -> {
                val size = (value as? String)?.let { OrbSize.fromWire(it) }
                    ?: throw IllegalArgumentException("orbSize must be small, medium or large")
                edit.putString(key, size.wire)
            }
            K_LANGUAGE -> {
                val lang = (value as? String)?.lowercase()
                if (lang == null || !LANGUAGE.matches(lang)) {
                    throw IllegalArgumentException("language must be an ISO-639-1 code or auto")
                }
                edit.putString(key, lang)
            }
            K_RETENTION -> {
                val days = (value as? Number)?.toInt()
                if (days == null || days !in Config.RETENTION_CHOICES) {
                    throw IllegalArgumentException("historyRetentionDays must be 7, 30, 90 or 0")
                }
                edit.putInt(key, days)
            }
            "groqKeyLast4", "minimaxKeyLast4" -> throw IllegalArgumentException("$key is read-only; use setKeys")
            else -> throw IllegalArgumentException("Unknown config key: $key")
        }
        edit.apply()
        return publish()
    }

    /** Saves keys already verified by the caller. An empty string removes that key. */
    fun setKeys(groq: String?, minimax: String?): Config {
        val edit = prefs.edit()
        groq?.let { if (it.isEmpty()) edit.remove(K_GROQ) else edit.putString(K_GROQ, it) }
        minimax?.let { if (it.isEmpty()) edit.remove(K_MINIMAX) else edit.putString(K_MINIMAX, it) }
        edit.apply()
        return publish()
    }

    fun setPaused(paused: Boolean) {
        prefs.edit().putBoolean(K_PAUSED, paused).apply()
        _paused.value = paused
    }

    data class OrbPosition(val dockRight: Boolean, val yFraction: Float)

    fun orbPosition(): OrbPosition =
        OrbPosition(prefs.getBoolean(K_ORB_RIGHT, true), prefs.getFloat(K_ORB_Y, 0.45f))

    fun saveOrbPosition(position: OrbPosition) {
        prefs.edit().putBoolean(K_ORB_RIGHT, position.dockRight)
            .putFloat(K_ORB_Y, position.yFraction.coerceIn(0f, 1f)).apply()
    }

    private fun publish(): Config = read().also { _config.value = it }
}
