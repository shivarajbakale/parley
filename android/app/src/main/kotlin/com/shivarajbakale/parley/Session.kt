package com.shivarajbakale.parley

import android.util.Log
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.io.File

/**
 * The field a session writes to, captured the moment the gesture starts so
 * focus moving during transcription cannot send the text somewhere else.
 * [handle] is the AccessibilityNodeInfo in the app; tests leave it null.
 */
data class FieldTarget(
    val packageName: String,
    val windowId: Int,
    val text: String?,
    val isShowingHint: Boolean,
    val selStart: Int,
    val selEnd: Int,
    /** A password field: nothing in it is Parley's to send anywhere. */
    val secure: Boolean = false,
    val handle: Any? = null,
)

data class RecordedAudio(val file: File?, val durationMs: Long)

sealed class SessionState {
    object Idle : SessionState()
    data class Listening(val mode: SessionMode, val startedAt: Long) : SessionState()
    data class Transcribing(val mode: SessionMode) : SessionState()
    object Rewriting : SessionState()
    data class Inserting(val mode: SessionMode) : SessionState()
    data class Done(val mode: SessionMode, val method: InsertMethod) : SessionState()
    data class Error(val message: String) : SessionState()

    val busy: Boolean get() = this !is Idle
}

/** Everything a session touches, so the rules are unit tests with fakes. */
interface SessionDeps {
    fun now(): Long
    fun groqKey(): String?
    fun minimaxKey(): String?
    fun config(): Config
    fun captureTarget(): FieldTarget?
    /** Starts the mic. Returns null on success, or why it could not start. */
    suspend fun startRecording(): String?
    suspend fun stopRecording(): RecordedAudio
    fun cancelRecording()
    suspend fun transcribe(file: File, key: String, language: String): String
    suspend fun rewrite(text: String, instruction: String, key: String): String
    /** Dictation inserts at the captured selection; edit replaces the captured range. */
    suspend fun insert(target: FieldTarget?, text: String, mode: SessionMode, leadingSpace: Boolean): InsertMethod
    /** Puts the whole field back to [fullText]. */
    suspend fun restore(target: FieldTarget, fullText: String): Boolean
    fun copyToClipboard(text: String)
    fun appLabel(packageName: String): String
    fun record(entry: HistoryEntry)
    fun haptic()
}

/**
 * One recording at a time:
 * idle → listening → transcribing → (rewriting) → inserting → done | error → idle.
 * Ported from the Mac app's session.ts.
 */
class Session(private val scope: CoroutineScope, private val deps: SessionDeps) {

    companion object {
        private const val TAG = "ParleySession"
        const val MIN_AUDIO_MS = 300L
        const val MAX_RECORDING_MS = 120_000L
        const val DONE_MS = 1_200L
        const val ERROR_MS = 2_000L
        const val UNDO_WINDOW_MS = 10_000L
    }

    private val _state = MutableStateFlow<SessionState>(SessionState.Idle)
    val state: StateFlow<SessionState> = _state.asStateFlow()

    private var mode = SessionMode.DICTATION
    private var target: FieldTarget? = null
    private var startJob: Job? = null
    private var maxJob: Job? = null
    private var workJob: Job? = null
    private var settleJob: Job? = null

    /** What a tap on the orb in the error state copies. */
    var lastText: String? = null
        private set

    private data class Undo(val target: FieldTarget, val fullText: String, val expiresAt: Long)
    private var undo: Undo? = null

    /**
     * Why an edit cannot run against the captured field, or null when it can.
     * The orb asks this to decide whether the edit detent exists at all, so the
     * reason shows while the user reaches for it rather than after they speak.
     */
    fun editRefusal(): String? {
        if (deps.minimaxKey().isNullOrEmpty()) return MiniMaxRewriter.messageFor(ApiException.Kind.NO_KEY)
        val t = target ?: return "No text field"
        if (t.secure) return "Can't edit a password field"
        val source = TextSplicer.editSource(t.text, t.isShowingHint, t.selStart, t.selEnd)
        if (source.isBlank()) return "Nothing to edit"
        if (TextSplicer.tooLongToEdit(source)) return "Too much text to edit"
        return null
    }

    /**
     * The finger moved to another detent: what the recording will do when it
     * is let go changes, while it keeps running. The field captured at the
     * start stays captured, so focus cannot drift underneath a switch.
     */
    fun switchTo(mode: SessionMode): Boolean {
        val listening = _state.value as? SessionState.Listening ?: return false
        if (listening.mode == mode) return true
        if (mode == SessionMode.EDIT && editRefusal() != null) return false
        this.mode = mode
        _state.value = SessionState.Listening(mode, listening.startedAt)
        return true
    }

    fun canUndo(): Boolean = undo?.let { deps.now() < it.expiresAt } == true

    /** Starts listening. Returns false when a session is already in flight. */
    fun start(requested: SessionMode): Boolean {
        if (_state.value.busy) return false
        undo = null
        mode = requested
        if (deps.groqKey().isNullOrEmpty()) return fail(GroqTranscriber.messageFor(ApiException.Kind.NO_KEY))
        target = deps.captureTarget()
        // An edit is refused before the mic opens, so the user never speaks an
        // instruction into a request that was already impossible.
        if (requested == SessionMode.EDIT) editRefusal()?.let { return fail(it) }

        _state.value = SessionState.Listening(requested, deps.now())
        if (deps.config().haptics) deps.haptic()
        startJob = scope.launch {
            val problem = try {
                deps.startRecording()
            } catch (e: Exception) {
                if (e is CancellationException) throw e
                Log.w(TAG, "startRecording threw", e)
                e.message ?: "Microphone unavailable"
            }
            if (problem != null) {
                deps.cancelRecording()
                val s = _state.value
                if (s is SessionState.Listening || s is SessionState.Transcribing) {
                    maxJob?.cancel()
                    fail(problem)
                }
            }
        }
        maxJob = scope.launch {
            delay(MAX_RECORDING_MS)
            stop()
        }
        return true
    }

    /** The hold ended: transcribe what was heard. */
    fun stop() {
        val listening = _state.value as? SessionState.Listening ?: return
        maxJob?.cancel()
        if (deps.config().haptics) deps.haptic()
        _state.value = SessionState.Transcribing(listening.mode)
        workJob = scope.launch { process(listening) }
    }

    /** Throws the recording away without calling any API. */
    fun cancel() {
        if (_state.value !is SessionState.Listening) return
        maxJob?.cancel()
        startJob?.cancel()
        deps.cancelRecording()
        _state.value = SessionState.Idle
    }

    /** Tap on the orb within 10 s of an edit: put the field back. */
    fun undoLastEdit(): Boolean {
        val u = undo ?: return false
        undo = null
        if (deps.now() >= u.expiresAt) return false
        scope.launch {
            try {
                deps.restore(u.target, u.fullText)
            } catch (e: Exception) {
                if (e is CancellationException) throw e
                Log.w(TAG, "undo failed", e)
            }
        }
        return true
    }

    /** Tap on the orb while it shows an error: the last text goes to the clipboard. */
    fun copyLastText(): Boolean {
        val text = lastText ?: return false
        deps.copyToClipboard(text)
        return true
    }

    private suspend fun process(listening: SessionState.Listening) {
        var audio: RecordedAudio? = null
        try {
            startJob?.join()
            if (_state.value !is SessionState.Transcribing) return // start failed meanwhile
            audio = deps.stopRecording()
            val file = audio.file
            if (file == null || audio.durationMs < MIN_AUDIO_MS) {
                _state.value = SessionState.Idle
                return
            }
            val config = deps.config()
            val key = deps.groqKey() ?: throw ApiException(ApiException.Kind.NO_KEY, GroqTranscriber.messageFor(ApiException.Kind.NO_KEY))
            val heard = deps.transcribe(file, key, config.language).trim()
            if (heard.isEmpty()) {
                _state.value = SessionState.Idle
                return
            }
            val t = target
            if (listening.mode == SessionMode.EDIT && t != null) {
                _state.value = SessionState.Rewriting
                val source = TextSplicer.editSource(t.text, t.isShowingHint, t.selStart, t.selEnd)
                val mmKey = deps.minimaxKey()
                    ?: throw ApiException(ApiException.Kind.NO_KEY, MiniMaxRewriter.messageFor(ApiException.Kind.NO_KEY))
                val rewritten = deps.rewrite(source, heard, mmKey)
                lastText = rewritten
                _state.value = SessionState.Inserting(SessionMode.EDIT)
                val method = deps.insert(t, rewritten, SessionMode.EDIT, false)
                if (method == InsertMethod.SET_TEXT || method == InsertMethod.PASTE) {
                    undo = Undo(t, TextSplicer.effectiveText(t.text, t.isShowingHint), deps.now() + UNDO_WINDOW_MS)
                }
                writeHistory(SessionMode.EDIT, rewritten, heard, source, t, method, audio.durationMs)
                finish(SessionMode.EDIT, method)
            } else {
                lastText = heard
                _state.value = SessionState.Inserting(SessionMode.DICTATION)
                val method = deps.insert(t, heard, SessionMode.DICTATION, config.leadingSpace)
                writeHistory(SessionMode.DICTATION, heard, null, null, t, method, audio.durationMs)
                finish(SessionMode.DICTATION, method)
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: ApiException) {
            fail(e.message ?: "Something went wrong")
        } catch (e: Exception) {
            Log.w(TAG, "session failed", e)
            fail(e.message ?: "Something went wrong")
        } finally {
            audio?.file?.delete()
        }
    }

    private fun writeHistory(
        mode: SessionMode,
        text: String,
        instruction: String?,
        beforeText: String?,
        target: FieldTarget?,
        method: InsertMethod,
        recordingMs: Long,
    ) {
        val pkg = target?.packageName ?: ""
        try {
            deps.record(
                HistoryEntry(
                    createdAt = deps.now(),
                    mode = mode,
                    text = text,
                    instruction = instruction,
                    beforeText = beforeText,
                    appPackage = pkg,
                    appLabel = if (pkg.isEmpty()) "Unknown app" else deps.appLabel(pkg),
                    insertMethod = method,
                    recordingMs = recordingMs,
                )
            )
        } catch (e: Exception) {
            // A full disk must not turn a successful insert into an error.
            Log.w(TAG, "history write failed", e)
        }
    }

    private fun finish(mode: SessionMode, method: InsertMethod) {
        if (method == InsertMethod.FAILED) {
            fail("Could not insert")
            return
        }
        _state.value = SessionState.Done(mode, method)
        settle(DONE_MS)
    }

    private fun fail(message: String): Boolean {
        Log.i(TAG, "error: $message")
        _state.value = SessionState.Error(message)
        settle(ERROR_MS)
        return false
    }

    private fun settle(afterMs: Long) {
        settleJob?.cancel()
        val shown = _state.value
        settleJob = scope.launch {
            delay(afterMs)
            if (_state.value == shown) _state.value = SessionState.Idle
        }
    }
}
