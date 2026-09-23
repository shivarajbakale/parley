package com.shivarajbakale.parley

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.PowerManager
import android.util.Log
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch

/**
 * The process-wide hub. The accessibility service and MainActivity live in the
 * same process, so they share one set of stores and one event stream here
 * instead of talking over IPC.
 */
object ParleyRuntime {
    private const val TAG = "ParleyRuntime"

    lateinit var app: Context
        private set
    lateinit var config: ConfigStore
        private set
    lateinit var history: HistoryStore
        private set

    val transcriber = GroqTranscriber()
    val rewriter = MiniMaxRewriter()

    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    private val _serviceBound = MutableStateFlow(false)
    val serviceBound: StateFlow<Boolean> = _serviceBound.asStateFlow()

    private val _status = MutableStateFlow<Status?>(null)
    val status: StateFlow<Status?> = _status.asStateFlow()

    /** Contract events: `{type: 'status', ...}` and `{type: 'history', ...}`. */
    private val _events = MutableSharedFlow<Map<String, Any?>>(extraBufferCapacity = 64)
    val events: SharedFlow<Map<String, Any?>> = _events.asSharedFlow()

    @Volatile private var initialised = false

    @Synchronized
    fun init(context: Context) {
        if (initialised) return
        app = context.applicationContext
        config = ConfigStore.create(app)
        history = HistoryStore(app)
        initialised = true
        scope.launch {
            combine(config.config, config.paused, _serviceBound) { _, _, _ -> }.collect { refreshStatus() }
        }
    }

    fun serviceConnected() {
        Log.i(TAG, "accessibility service connected")
        _serviceBound.value = true
    }

    fun serviceDisconnected() {
        Log.i(TAG, "accessibility service disconnected")
        _serviceBound.value = false
    }

    fun currentStatus(): Status {
        val c = config.config.value
        val power = app.getSystemService(PowerManager::class.java)
        return Status(
            serviceBound = _serviceBound.value,
            paused = config.paused.value,
            micGranted = ContextCompat.checkSelfPermission(app, Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED,
            batteryUnrestricted = power?.isIgnoringBatteryOptimizations(app.packageName) == true,
            groqKeySet = c.groqKeyLast4 != null,
            minimaxKeySet = c.minimaxKeyLast4 != null,
            orbEnabled = c.orbEnabled,
            volumeGestureEnabled = c.volumeGestureEnabled,
        )
    }

    /**
     * Recomputes Status and emits it when anything changed. Mic and battery
     * state have no callback, so the activity calls this on resume and after a
     * permission result.
     */
    fun refreshStatus(): Status {
        val next = currentStatus()
        if (next != _status.value) {
            _status.value = next
            _events.tryEmit(mapOf("type" to "status", "status" to next.toMap()))
        }
        return next
    }

    /** Writes an entry (call off the main thread) and tells the Flutter side. */
    fun recordHistory(entry: HistoryEntry): HistoryEntry {
        val saved = history.insert(entry)
        _events.tryEmit(mapOf("type" to "history", "entry" to saved.toMap()))
        return saved
    }
}
