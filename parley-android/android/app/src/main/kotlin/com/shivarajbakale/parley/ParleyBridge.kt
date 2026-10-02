package com.shivarajbakale.parley

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * The Flutter side's only door into the native core; see
 * docs/plans/bridge-contract.md. Method names, argument keys and result shapes
 * are the contract's, verbatim.
 */
class ParleyBridge(private val activity: Activity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val TAG = "ParleyBridge"
        const val METHODS = "parley/bridge"
        const val EVENTS = "parley/events"
        const val PERMISSION_REQUEST = 4201
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val methods = MethodChannel(messenger, METHODS)
    private val events = EventChannel(messenger, EVENTS)
    private var eventJob: Job? = null
    private var pendingPermission: MethodChannel.Result? = null

    init {
        ParleyRuntime.init(activity)
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    fun dispose() {
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        pendingPermission?.success(micGranted())
        pendingPermission = null
        scope.cancel()
    }

    private val config get() = ParleyRuntime.config
    private val history get() = ParleyRuntime.history

    // ---- events ---------------------------------------------------------

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        eventJob?.cancel()
        eventJob = scope.launch {
            // A new listener starts from the current state, then follows changes.
            sink.success(mapOf("type" to "status", "status" to ParleyRuntime.currentStatus().toMap()))
            ParleyRuntime.events.collect { sink.success(it) }
        }
    }

    override fun onCancel(arguments: Any?) {
        eventJob?.cancel()
        eventJob = null
    }

    // ---- methods --------------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                handle(call, result)
            } catch (e: IllegalArgumentException) {
                result.error("invalid_argument", e.message, null)
            } catch (e: java.io.IOException) {
                result.error("io", e.message, null)
            } catch (e: android.database.SQLException) {
                result.error("io", e.message, null)
            } catch (e: Exception) {
                Log.w(TAG, "${call.method} failed", e)
                result.error("unavailable", e.message ?: e.javaClass.simpleName, null)
            }
        }
    }

    private suspend fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getStatus" -> result.success(ParleyRuntime.refreshStatus().toMap())

            "setPaused" -> {
                val paused = call.argument<Boolean>("paused") ?: throw IllegalArgumentException("paused must be a bool")
                config.setPaused(paused)
                result.success(ParleyRuntime.refreshStatus().toMap())
            }

            "openSystemSettings" -> {
                openSettings(call.argument<String>("target"))
                result.success(null)
            }

            "requestMicPermission" -> requestMic(result)

            "verifyKey" -> {
                val key = call.argument<String>("key") ?: throw IllegalArgumentException("key must be a string")
                val verdict = when (call.argument<String>("provider")) {
                    "groq" -> ParleyRuntime.groq.verify(key)
                    "deepgram" -> ParleyRuntime.deepgram.verify(key)
                    "minimax" -> ParleyRuntime.rewriter.verify(key)
                    else -> throw IllegalArgumentException("provider must be groq, deepgram or minimax")
                }
                result.success(verdict.toMap())
            }

            "setKeys" -> result.success(setKeys(call))

            "getConfig" -> result.success(config.config.value.toMap())

            "setConfig" -> {
                val key = call.argument<String>("key") ?: throw IllegalArgumentException("key must be a string")
                val updated = config.set(key, call.argument<Any?>("value"))
                if (key == "historyRetentionDays") {
                    withContext(Dispatchers.IO) { history.prune(updated.historyRetentionDays, System.currentTimeMillis()) }
                }
                result.success(updated.toMap())
            }

            "getUsageSummary" -> result.success(
                withContext(Dispatchers.IO) { history.usageSummary(System.currentTimeMillis()) }.toMap()
            )

            "listHistory" -> {
                val offset = call.argument<Number>("offset")?.toInt() ?: 0
                val limit = call.argument<Number>("limit")?.toInt() ?: 50
                val filter = HistoryFilter.fromWire(call.argument<String>("filter"))
                    ?: throw IllegalArgumentException("filter must be all, dictation, edit or notInserted")
                val query = call.argument<String>("query")
                val rows = withContext(Dispatchers.IO) { history.list(offset, limit, query, filter) }
                result.success(rows.map { it.toMap() })
            }

            "getHistoryEntry" -> {
                val id = call.argument<Number>("id")?.toLong() ?: throw IllegalArgumentException("id must be an int")
                result.success(withContext(Dispatchers.IO) { history.get(id) }?.toMap())
            }

            "deleteHistory" -> {
                val id = call.argument<Number>("id")?.toLong()
                result.success(withContext(Dispatchers.IO) { history.delete(id) })
            }

            "restoreHistory" -> {
                val raw = call.argument<Map<*, *>>("entry") ?: throw IllegalArgumentException("entry must be a map")
                val entry = HistoryEntry.fromMap(raw)
                result.success(withContext(Dispatchers.IO) { history.restore(entry) })
            }

            else -> result.notImplemented()
        }
    }

    /** Verifies every non-empty key first and saves none if any fails. */
    private suspend fun setKeys(call: MethodCall): Map<String, Any?> {
        val groq = call.argument<String>("groq")?.trim()
        val minimax = call.argument<String>("minimax")?.trim()
        val deepgram = call.argument<String>("deepgram")?.trim()
        val groqCheck = groq?.takeIf { it.isNotEmpty() }?.let { scope.async { ParleyRuntime.groq.verify(it) } }
        val deepgramCheck = deepgram?.takeIf { it.isNotEmpty() }?.let { scope.async { ParleyRuntime.deepgram.verify(it) } }
        val minimaxCheck = minimax?.takeIf { it.isNotEmpty() }?.let { scope.async { ParleyRuntime.rewriter.verify(it) } }
        val errors = mutableMapOf<String, String>()
        groqCheck?.await()?.let { if (!it.ok) errors["groq"] = it.message ?: "Key rejected" }
        deepgramCheck?.await()?.let { if (!it.ok) errors["deepgram"] = it.message ?: "Key rejected" }
        minimaxCheck?.await()?.let { if (!it.ok) errors["minimax"] = it.message ?: "Key rejected" }
        if (errors.isEmpty()) {
            config.setKeys(groq, minimax, deepgram)
            ParleyRuntime.refreshStatus()
        }
        return mapOf("ok" to errors.isEmpty(), "errors" to errors)
    }

    private fun openSettings(target: String?) {
        val pkg = activity.packageName
        val intent = when (target) {
            "accessibility" -> Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            "battery" -> {
                val direct = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$pkg"))
                try {
                    activity.startActivity(direct)
                    return
                } catch (e: ActivityNotFoundException) {
                    Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                } catch (e: SecurityException) {
                    Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                }
            }
            "appDetails" -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$pkg"))
            else -> throw IllegalArgumentException("target must be accessibility, battery or appDetails")
        }
        try {
            activity.startActivity(intent)
        } catch (e: ActivityNotFoundException) {
            throw IllegalStateException("No settings screen for $target", e)
        }
    }

    // ---- permissions ----------------------------------------------------

    private fun micGranted() =
        ContextCompat.checkSelfPermission(activity, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    private fun requestMic(result: MethodChannel.Result) {
        val wanted = buildList {
            if (!micGranted()) add(Manifest.permission.RECORD_AUDIO)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
            ) add(Manifest.permission.POST_NOTIFICATIONS)
        }
        if (micGranted()) {
            // The result reports the mic, which is already granted; a missing
            // notification permission is still asked for, without waiting on it.
            if (wanted.isNotEmpty()) activity.requestPermissions(wanted.toTypedArray(), PERMISSION_REQUEST)
            result.success(true)
            ParleyRuntime.refreshStatus()
            return
        }
        pendingPermission?.success(micGranted()) // a second request supersedes the first
        pendingPermission = result
        activity.requestPermissions(wanted.toTypedArray(), PERMISSION_REQUEST)
    }

    /** Called from MainActivity.onRequestPermissionsResult. */
    fun onPermissionResult(requestCode: Int): Boolean {
        if (requestCode != PERMISSION_REQUEST) return false
        pendingPermission?.success(micGranted())
        pendingPermission = null
        ParleyRuntime.refreshStatus()
        return true
    }
}
