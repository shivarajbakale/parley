package com.shivarajbakale.parley

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.Rect
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/**
 * The long-lived half of Parley: bound by the system, it draws the orb, reads
 * the volume-down gesture, tracks the focused field, and runs sessions.
 */
class ParleyAccessibilityService : AccessibilityService(), SessionDeps {

    companion object {
        private const val TAG = "ParleyService"
        private const val FOCUS_DEBOUNCE_MS = 80L
    }

    private var scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val handler = Handler(Looper.getMainLooper())

    private lateinit var store: ConfigStore
    private lateinit var session: Session
    private lateinit var orb: OrbController
    private lateinit var recorder: Recorder
    private lateinit var injector: Injector
    private lateinit var audio: AudioManager
    private lateinit var detector: VolumeGestureDetector
    private var ready = false

    /** A non-password editable field has input focus right now. */
    private var editableFocused = false
    /** We swallowed the last volume-down press, so we must swallow its release. */
    private var consumingVolume = false

    // ---- lifecycle ------------------------------------------------------

    override fun onServiceConnected() {
        super.onServiceConnected()
        ParleyRuntime.init(this)
        scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
        store = ParleyRuntime.config
        audio = getSystemService(AudioManager::class.java)
        injector = Injector(this)
        recorder = Recorder(this) { rms -> handler.post { if (ready) orb.view.setLevel(rms) } }
        session = Session(scope, this)
        detector = VolumeGestureDetector(gestureListener)
        orb = OrbController(this, store, orbListener)
        ready = true

        scope.launch {
            combine(store.config, store.paused, session.state) { c, p, s -> Triple(c, p, s) }
                .collect { (c, paused, state) ->
                    orb.applySize(c.orbSize)
                    if ((paused || !c.volumeGestureEnabled) && (detector.recording || consumingVolume)) detector.disarm()
                    orb.view.visual = visualFor(state)
                    updateOrbVisibility()
                    refreshPill()
                }
        }
        scope.launch(Dispatchers.IO) {
            try {
                val removed = ParleyRuntime.history.prune(store.config.value.historyRetentionDays, System.currentTimeMillis())
                if (removed > 0) Log.i(TAG, "pruned $removed history entries")
            } catch (e: Exception) {
                Log.w(TAG, "history prune failed", e)
            }
        }
        refreshFocus()
        ParleyRuntime.serviceConnected()
    }

    override fun onUnbind(intent: Intent?): Boolean {
        teardown()
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        teardown()
        super.onDestroy()
    }

    private fun teardown() {
        if (!ready) return
        ready = false
        ParleyRuntime.serviceDisconnected()
        session.cancel()
        recorder.cancel()
        MicForegroundService.stop(this)
        handler.removeCallbacks(pillTick)
        orb.destroy()
        handler.removeCallbacksAndMessages(null)
        focusCheckPending = false
        scope.cancel()
    }

    override fun onInterrupt() = Unit

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (ready) orb.onConfigurationChanged()
    }

    // ---- focus + orb visibility ----------------------------------------

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (!ready || event == null) return
        when (event.eventType) {
            AccessibilityEvent.TYPE_VIEW_FOCUSED,
            AccessibilityEvent.TYPE_VIEW_TEXT_SELECTION_CHANGED,
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED,
            AccessibilityEvent.TYPE_WINDOWS_CHANGED -> scheduleFocusCheck()
        }
    }

    private var focusCheckPending = false
    private val focusCheck = Runnable {
        focusCheckPending = false
        refreshFocus()
    }

    /**
     * Throttled, not debounced: a busy screen sends content-changed events
     * without pause, and a debounce would keep pushing the check back, so the
     * orb would notice the keyboard seconds late. At most one check is pending,
     * and it runs [FOCUS_DEBOUNCE_MS] after the first event.
     */
    private fun scheduleFocusCheck() {
        if (focusCheckPending) return
        focusCheckPending = true
        handler.postDelayed(focusCheck, FOCUS_DEBOUNCE_MS)
    }

    private fun refreshFocus() {
        if (!ready) return
        val node = focusedInput()
        editableFocused = node != null && node.isEditable && !node.isPassword
        orb.setImeTop(imeTop())
        updateOrbVisibility()
    }

    /** The node with input focus, looking through every interactive window. */
    private fun focusedInput(): AccessibilityNodeInfo? {
        try {
            rootInActiveWindow?.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)?.let { return it }
            for (w in windows) {
                if (w.type != AccessibilityWindowInfo.TYPE_APPLICATION) continue
                w.root?.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)?.let { return it }
            }
        } catch (e: Exception) {
            Log.w(TAG, "focus lookup failed", e)
        }
        return null
    }

    private fun imeTop(): Int? = try {
        windows.firstOrNull { it.type == AccessibilityWindowInfo.TYPE_INPUT_METHOD }?.let { w ->
            Rect().also { w.getBoundsInScreen(it) }.top.takeIf { it > 0 }
        }
    } catch (e: Exception) {
        null
    }

    private fun updateOrbVisibility() {
        if (!ready) return
        val c = store.config.value
        val busy = session.state.value.busy
        // With nothing to type into, the orb tucks into the edge rather than vanishing.
        orb.setTucked(c.hideOrbWithoutField && !busy && !editableFocused)
        orb.setVisible(c.orbEnabled && !store.paused.value)
    }

    // ---- capsule --------------------------------------------------------

    private val pillTick = Runnable { refreshPill() }

    /** Sets the capsule from the session, and keeps its timer ticking while listening. */
    private fun refreshPill() {
        if (!ready) return
        handler.removeCallbacks(pillTick)
        val state = session.state.value
        val now = System.currentTimeMillis()
        orb.setPill(PillContent.forState(state, now))
        if (state is SessionState.Listening) {
            // Land just after the next whole second so the clock never skips one.
            val elapsed = (now - state.startedAt).coerceAtLeast(0)
            handler.postDelayed(pillTick, 1000 - elapsed % 1000 + 16)
        }
    }

    private fun visualFor(state: SessionState): OrbView.Visual = when (state) {
        SessionState.Idle -> OrbView.Visual.IDLE
        is SessionState.Listening ->
            if (state.mode == SessionMode.EDIT) OrbView.Visual.LISTENING_EDIT else OrbView.Visual.LISTENING_DICTATION
        is SessionState.Transcribing ->
            if (state.mode == SessionMode.EDIT) OrbView.Visual.WORKING_EDIT else OrbView.Visual.WORKING_DICTATION
        SessionState.Rewriting -> OrbView.Visual.WORKING_EDIT
        is SessionState.Inserting ->
            if (state.mode == SessionMode.EDIT) OrbView.Visual.WORKING_EDIT else OrbView.Visual.WORKING_DICTATION
        is SessionState.Done ->
            if (state.method == InsertMethod.CLIPBOARD_ONLY) OrbView.Visual.COPIED else OrbView.Visual.DONE
        is SessionState.Error -> OrbView.Visual.ERROR
    }

    // ---- orb touches ----------------------------------------------------

    private val orbListener = object : OrbController.Listener {
        override fun onHoldStart() {
            Log.d(TAG, "orb hold start")
            session.start(SessionMode.DICTATION)
        }

        override fun onHoldEnd(zone: SlideZone) {
            Log.d(TAG, "orb hold end on $zone")
            when (zone) {
                SlideZone.CANCEL -> cancelListening(animated = false) // the orb already played its discard
                SlideZone.EDIT -> {
                    session.switchTo(SessionMode.EDIT)
                    session.stop()
                }
                SlideZone.DICTATE -> session.stop()
            }
        }

        override fun onZoneChanged(zone: SlideZone) {
            haptic()
            when (zone) {
                SlideZone.EDIT -> session.switchTo(SessionMode.EDIT)
                SlideZone.DICTATE -> session.switchTo(SessionMode.DICTATION)
                SlideZone.CANCEL -> Unit // the mode stops mattering; the take is going away
            }
        }

        override fun editRefusal(): String? = session.editRefusal()

        override fun onTap() {
            when {
                session.state.value is SessionState.Error -> if (session.copyLastText()) haptic()
                session.canUndo() -> if (session.undoLastEdit()) haptic()
            }
        }
    }

    // ---- volume gesture -------------------------------------------------

    private fun volumeArmed(): Boolean {
        val c = store.config.value
        if (!c.volumeGestureEnabled || store.paused.value) return false
        // Never get between the user and the volume of a call.
        val mode = audio.mode
        if (mode == AudioManager.MODE_IN_CALL || mode == AudioManager.MODE_IN_COMMUNICATION || mode == AudioManager.MODE_RINGTONE) {
            return false
        }
        return !session.state.value.busy || detector.recording
    }

    /** Throws the recording in progress away: nothing is sent, nothing is kept. */
    private fun cancelListening(animated: Boolean) {
        if (session.state.value !is SessionState.Listening) return
        if (animated) orb.view.discard()
        session.cancel()
        haptic()
    }

    /** We swallowed a volume-up press that cancelled, so we swallow its release. */
    private var consumingVolumeUp = false

    override fun onKeyEvent(event: KeyEvent): Boolean {
        if (!ready) return false
        // Volume-up while recording cancels it.
        if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            when (event.action) {
                KeyEvent.ACTION_DOWN -> {
                    if (!consumingVolumeUp && session.state.value !is SessionState.Listening) return false
                    if (event.repeatCount == 0) cancelListening(animated = true)
                    consumingVolumeUp = true
                    return true
                }
                KeyEvent.ACTION_UP -> {
                    if (!consumingVolumeUp) return false
                    consumingVolumeUp = false
                    return true
                }
            }
            return false
        }
        if (event.keyCode != KeyEvent.KEYCODE_VOLUME_DOWN) return false
        // Timestamped on arrival, not event.eventTime: some input devices stamp
        // events on another clock, and the deadlines are posted on uptimeMillis.
        val now = SystemClock.uptimeMillis()
        when (event.action) {
            KeyEvent.ACTION_DOWN -> {
                if (!consumingVolume && !volumeArmed()) return false
                consumingVolume = true
                detector.onKeyDown(now, event.repeatCount)
            }
            KeyEvent.ACTION_UP -> {
                if (!consumingVolume) return false
                detector.onKeyUp(now)
                consumingVolume = false
            }
            else -> return false
        }
        scheduleGestureTick()
        return true
    }

    private val gestureTick = Runnable {
        detector.tick(SystemClock.uptimeMillis())
        scheduleGestureTick()
    }

    private fun scheduleGestureTick() {
        handler.removeCallbacks(gestureTick)
        detector.nextDeadline()?.let { handler.postAtTime(gestureTick, it) }
    }

    private val gestureListener = object : VolumeGestureDetector.Listener {
        override fun onStart() {
            Log.d(TAG, "volume gesture: tap-tap-hold")
            session.start(SessionMode.DICTATION)
        }

        override fun onStop() {
            session.stop()
        }

        override fun onReplay(presses: Int) {
            Log.d(TAG, "volume gesture: replaying $presses press(es)")
            repeat(presses) {
                audio.adjustSuggestedStreamVolume(
                    AudioManager.ADJUST_LOWER,
                    AudioManager.USE_DEFAULT_STREAM_TYPE,
                    AudioManager.FLAG_SHOW_UI,
                )
            }
        }
    }

    // ---- SessionDeps ----------------------------------------------------

    override fun now(): Long = System.currentTimeMillis()
    override fun transcriptionKey(): String? = store.transcriptionKey
    override fun minimaxKey(): String? = store.minimaxKey
    override fun config(): Config = store.config.value

    override fun captureTarget(): FieldTarget? {
        val node = focusedInput() ?: return null
        if (!node.isEditable) return null
        val hint = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && node.isShowingHintText
        return FieldTarget(
            packageName = node.packageName?.toString().orEmpty(),
            windowId = node.windowId,
            text = node.text?.toString(),
            isShowingHint = hint,
            selStart = node.textSelectionStart,
            selEnd = node.textSelectionEnd,
            secure = node.isPassword,
            handle = node,
        )
    }

    override suspend fun startRecording(): String? {
        MicForegroundService.start(this)?.let { return it }
        val problem = withContext(Dispatchers.IO) { recorder.start() }
        if (problem != null) MicForegroundService.stop(this)
        return problem
    }

    override suspend fun stopRecording(): RecordedAudio {
        val result = withContext(Dispatchers.IO) { recorder.stop() }
        MicForegroundService.stop(this)
        return result
    }

    override fun cancelRecording() {
        recorder.cancel()
        MicForegroundService.stop(this)
    }

    override suspend fun transcribe(file: File, key: String, language: String): String =
        ParleyRuntime.transcriber(store.config.value.transcriptionProvider).transcribe(file, key, language)

    override suspend fun rewrite(text: String, instruction: String, key: String): String =
        ParleyRuntime.rewriter.rewrite(text, instruction, key)

    override suspend fun insert(target: FieldTarget?, text: String, mode: SessionMode, leadingSpace: Boolean): InsertMethod =
        injector.insert(target, text, mode, leadingSpace)

    override suspend fun restore(target: FieldTarget, fullText: String): Boolean = injector.restore(target, fullText)

    override fun copyToClipboard(text: String) {
        injector.copy(text)
    }

    override fun appLabel(packageName: String): String = try {
        val info = packageManager.getApplicationInfo(packageName, 0)
        packageManager.getApplicationLabel(info).toString()
    } catch (e: PackageManager.NameNotFoundException) {
        packageName
    }

    override fun record(entry: HistoryEntry) {
        ParleyRuntime.scope.launch(Dispatchers.IO) {
            try {
                ParleyRuntime.recordHistory(entry)
            } catch (e: Exception) {
                Log.w(TAG, "history write failed", e)
            }
        }
    }

    override fun haptic() {
        if (!store.config.value.haptics) return
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(VibratorManager::class.java).defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Vibrator::class.java)
            }
            val effect = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                VibrationEffect.createPredefined(VibrationEffect.EFFECT_CLICK)
            } else {
                VibrationEffect.createOneShot(20, VibrationEffect.DEFAULT_AMPLITUDE)
            }
            vibrator.vibrate(effect)
        } catch (e: Exception) {
            Log.w(TAG, "haptic failed", e)
        }
    }
}
