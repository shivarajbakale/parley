package com.shivarajbakale.parley

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

@OptIn(ExperimentalCoroutinesApi::class)
class SessionTest {

    private val field = FieldTarget("com.example.chat", 7, "Hello", false, 5, 5)

    private class Fakes(val scope: TestScope) : SessionDeps {
        var groq: String? = "gsk"
        var minimax: String? = "mm"
        var cfg = Config()
        var target: FieldTarget? = null
        var startProblem: String? = null
        var audioMs = 2_000L
        var heard = "hello world"
        var rewritten = "Hello, world."
        var transcribeError: Exception? = null
        var method = InsertMethod.SET_TEXT
        var transcribeGate: CompletableDeferred<Unit>? = null

        val calls = mutableListOf<String>()
        val inserted = mutableListOf<Triple<String, SessionMode, Boolean>>()
        val history = mutableListOf<HistoryEntry>()
        val restored = mutableListOf<String>()
        val clipboard = mutableListOf<String>()
        var file: File? = null

        override fun now() = scope.testScheduler.currentTime
        override fun groqKey() = groq
        override fun minimaxKey() = minimax
        override fun config() = cfg
        override fun captureTarget() = target
        override suspend fun startRecording(): String? { calls += "startRec"; return startProblem }
        override suspend fun stopRecording(): RecordedAudio {
            calls += "stopRec"
            val f = File.createTempFile("parley-test", ".wav").also { file = it }
            return RecordedAudio(f, audioMs)
        }
        override fun cancelRecording() { calls += "cancelRec" }
        override suspend fun transcribe(file: File, key: String, language: String): String {
            calls += "transcribe:$language"
            transcribeGate?.await()
            transcribeError?.let { throw it }
            return heard
        }
        override suspend fun rewrite(text: String, instruction: String, key: String): String {
            calls += "rewrite:$text|$instruction"
            return rewritten
        }
        override suspend fun insert(target: FieldTarget?, text: String, mode: SessionMode, leadingSpace: Boolean): InsertMethod {
            inserted += Triple(text, mode, leadingSpace)
            return method
        }
        override suspend fun restore(target: FieldTarget, fullText: String): Boolean { restored += fullText; return true }
        override fun copyToClipboard(text: String) { clipboard += text }
        override fun appLabel(packageName: String) = "Chat"
        override fun record(entry: HistoryEntry) { history += entry }
        override fun haptic() { calls += "haptic" }
    }

    private fun TestScope.session(configure: Fakes.() -> Unit = {}): Pair<Session, Fakes> {
        val fakes = Fakes(this).apply { target = field }.apply(configure)
        return Session(this, fakes) to fakes
    }

    @Test fun `dictation runs listening to done to idle`() = runTest {
        val (s, f) = session { transcribeGate = CompletableDeferred() }
        assertTrue(s.start(SessionMode.DICTATION))
        runCurrent()
        assertEquals(SessionState.Listening(SessionMode.DICTATION, 0), s.state.value)
        advanceTimeBy(2_000)
        s.stop()
        assertEquals(SessionState.Transcribing(SessionMode.DICTATION), s.state.value)
        runCurrent()
        assertEquals(SessionState.Transcribing(SessionMode.DICTATION), s.state.value)
        f.transcribeGate!!.complete(Unit)
        runCurrent()
        assertEquals(SessionState.Done(SessionMode.DICTATION, InsertMethod.SET_TEXT), s.state.value)
        assertEquals(listOf(Triple("hello world", SessionMode.DICTATION, true)), f.inserted)
        assertEquals(1, f.history.size)
        with(f.history[0]) {
            assertEquals("hello world", text)
            assertEquals(SessionMode.DICTATION, mode)
            assertEquals("com.example.chat", appPackage)
            assertEquals("Chat", appLabel)
            assertEquals(2_000L, recordingMs)
            assertEquals(2, wordCount)
            assertNull(instruction)
        }
        assertFalse("wav deleted", f.file!!.exists())
        advanceTimeBy(Session.DONE_MS + 1)
        assertEquals(SessionState.Idle, s.state.value)
        assertEquals(listOf("haptic", "startRec", "haptic", "stopRec", "transcribe:auto"), f.calls)
    }

    @Test fun `a busy session swallows a second start`() = runTest {
        val (s, _) = session()
        assertTrue(s.start(SessionMode.DICTATION))
        assertFalse(s.start(SessionMode.EDIT))
    }

    @Test fun `audio under 300 ms is discarded without a request`() = runTest {
        val (s, f) = session { audioMs = 299 }
        s.start(SessionMode.DICTATION)
        s.stop()
        advanceUntilIdle()
        assertEquals(SessionState.Idle, s.state.value)
        assertFalse(f.calls.any { it.startsWith("transcribe") })
        assertTrue(f.history.isEmpty())
    }

    @Test fun `recording stops itself at 120 s`() = runTest {
        val (s, f) = session()
        s.start(SessionMode.DICTATION)
        advanceTimeBy(Session.MAX_RECORDING_MS - 1)
        assertTrue(s.state.value is SessionState.Listening)
        advanceTimeBy(2)
        runCurrent()
        assertTrue(f.calls.contains("stopRec"))
    }

    @Test fun `no groq key is an error before the mic opens`() = runTest {
        val (s, f) = session { groq = null }
        assertFalse(s.start(SessionMode.DICTATION))
        assertEquals(SessionState.Error("No Groq key"), s.state.value)
        runCurrent()
        assertFalse(f.calls.contains("startRec"))
        advanceTimeBy(Session.ERROR_MS + 1)
        assertEquals(SessionState.Idle, s.state.value)
    }

    @Test fun `mic failure is an error, not a crash`() = runTest {
        val (s, f) = session { startProblem = "Android blocked the microphone" }
        s.start(SessionMode.DICTATION)
        runCurrent()
        assertEquals(SessionState.Error("Android blocked the microphone"), s.state.value)
        assertTrue(f.calls.contains("cancelRec"))
    }

    @Test fun `transcription failure shows the message and tap copies the last text`() = runTest {
        val (s, f) = session { transcribeError = ApiException(ApiException.Kind.RATE_LIMIT, "Rate limited") }
        s.start(SessionMode.DICTATION)
        s.stop()
        runCurrent()
        assertEquals(SessionState.Error("Rate limited"), s.state.value)
        assertFalse(s.copyLastText()) // nothing was ever heard
        assertTrue(f.clipboard.isEmpty())
    }

    @Test fun `nothing heard goes back to idle quietly`() = runTest {
        val (s, f) = session { heard = "  " }
        s.start(SessionMode.DICTATION)
        s.stop()
        runCurrent()
        assertEquals(SessionState.Idle, s.state.value)
        assertTrue(f.inserted.isEmpty())
    }

    @Test fun `failed insert is an error with the text left to copy`() = runTest {
        val (s, f) = session { method = InsertMethod.FAILED }
        s.start(SessionMode.DICTATION)
        s.stop()
        runCurrent()
        assertEquals(SessionState.Error("Could not insert"), s.state.value)
        assertEquals(InsertMethod.FAILED, f.history.single().insertMethod)
        assertTrue(s.copyLastText())
        assertEquals(listOf("hello world"), f.clipboard)
    }

    @Test fun `clipboard only still finishes as done`() = runTest {
        val (s, _) = session { method = InsertMethod.CLIPBOARD_ONLY; target = null }
        s.start(SessionMode.DICTATION)
        s.stop()
        runCurrent()
        assertEquals(SessionState.Done(SessionMode.DICTATION, InsertMethod.CLIPBOARD_ONLY), s.state.value)
    }

    @Test fun `cancel throws the recording away`() = runTest {
        val (s, f) = session()
        s.start(SessionMode.DICTATION)
        runCurrent()
        s.cancel()
        assertEquals(SessionState.Idle, s.state.value)
        advanceUntilIdle()
        assertTrue(f.calls.contains("cancelRec"))
        assertFalse(f.calls.any { it.startsWith("transcribe") })
        assertTrue(f.history.isEmpty())
    }

    @Test fun `a release after a cancel does nothing`() = runTest {
        val (s, f) = session()
        s.start(SessionMode.DICTATION)
        runCurrent()
        s.cancel() // volume-up, or a slide-to-cancel
        s.stop() // the volume-down key coming back up afterwards
        advanceUntilIdle()
        assertEquals(SessionState.Idle, s.state.value)
        assertFalse(f.calls.contains("stopRec"))
        assertFalse(f.calls.any { it.startsWith("transcribe") })
        assertTrue(f.history.isEmpty())
    }

    @Test fun `edit rewrites the captured selection and can be undone for 10 s`() = runTest {
        val (s, f) = session { target = FieldTarget("com.example.mail", 3, "hey sam thx", false, 0, 0) }
        s.start(SessionMode.EDIT)
        assertEquals(SessionState.Listening(SessionMode.EDIT, 0), s.state.value)
        s.stop()
        runCurrent()
        assertTrue(f.calls.contains("rewrite:hey sam thx|hello world"))
        assertEquals(listOf(Triple("Hello, world.", SessionMode.EDIT, false)), f.inserted)
        assertEquals(SessionState.Done(SessionMode.EDIT, InsertMethod.SET_TEXT), s.state.value)
        with(f.history.single()) {
            assertEquals(SessionMode.EDIT, mode)
            assertEquals("Hello, world.", text)
            assertEquals("hello world", instruction)
            assertEquals("hey sam thx", beforeText)
        }
        assertTrue(s.canUndo())
        assertTrue(s.undoLastEdit())
        runCurrent()
        assertEquals(listOf("hey sam thx"), f.restored)
        assertFalse(s.canUndo())
    }

    @Test fun `undo expires after 10 s`() = runTest {
        val (s, f) = session()
        s.start(SessionMode.EDIT)
        s.stop()
        runCurrent()
        advanceTimeBy(Session.UNDO_WINDOW_MS + 1)
        assertFalse(s.canUndo())
        assertFalse(s.undoLastEdit())
        assertTrue(f.restored.isEmpty())
    }

    @Test fun `edit needs a field and a minimax key`() = runTest {
        val (s1, _) = session { target = null }
        assertFalse(s1.start(SessionMode.EDIT))
        assertEquals(SessionState.Error("No text field"), s1.state.value)

        val (s2, _) = session { minimax = null }
        assertFalse(s2.start(SessionMode.EDIT))
        assertEquals(SessionState.Error("No MiniMax key"), s2.state.value)
    }

    @Test fun `language and leading space come from config`() = runTest {
        val (s, f) = session { cfg = Config(language = "fr", leadingSpace = false, haptics = false) }
        s.start(SessionMode.DICTATION)
        s.stop()
        runCurrent()
        assertTrue(f.calls.contains("transcribe:fr"))
        assertFalse(f.calls.contains("haptic"))
        assertEquals(false, f.inserted.single().third)
    }

    @Test fun `edit refuses a password field before the mic opens`() = runTest {
        val (s, f) = session { target = FieldTarget("com.example.bank", 4, "hunter2", false, 0, 0, secure = true) }
        assertFalse(s.start(SessionMode.EDIT))
        assertEquals(SessionState.Error("Can't edit a password field"), s.state.value)
        assertTrue(f.calls.isEmpty())
    }

    @Test fun `dictation into a password field is still allowed`() = runTest {
        val (s, _) = session { target = FieldTarget("com.example.bank", 4, "", false, 0, 0, secure = true) }
        assertTrue(s.start(SessionMode.DICTATION))
    }

    @Test fun `edit refuses a field holding only hint text`() = runTest {
        val (s, f) = session { target = FieldTarget("com.example.chat", 7, "Type a message", true, 0, 0) }
        assertFalse(s.start(SessionMode.EDIT))
        assertEquals(SessionState.Error("Nothing to edit"), s.state.value)
        assertTrue(f.calls.isEmpty())
    }

    @Test fun `edit refuses more text than it will send to minimax`() = runTest {
        val long = "a".repeat(TextSplicer.MAX_EDIT_CHARS + 1)
        val (s, f) = session { target = FieldTarget("com.example.notes", 9, long, false, 0, 0) }
        assertFalse(s.start(SessionMode.EDIT))
        assertEquals(SessionState.Error("Too much text to edit"), s.state.value)
        assertTrue(f.calls.isEmpty())
    }

    @Test fun `editRefusal is null when the field can be rewritten`() = runTest {
        val (s, _) = session()
        s.start(SessionMode.DICTATION)
        assertNull(s.editRefusal())
    }

    @Test fun `editRefusal names each reason an edit cannot run`() = runTest {
        val (noField, _) = session { target = null }
        noField.start(SessionMode.DICTATION)
        assertEquals("No text field", noField.editRefusal())

        val (secure, _) = session { target = FieldTarget("com.example.bank", 4, "hunter2", false, 0, 0, secure = true) }
        secure.start(SessionMode.DICTATION)
        assertEquals("Can't edit a password field", secure.editRefusal())

        val (hint, _) = session { target = FieldTarget("com.example.chat", 7, "Type a message", true, 0, 0) }
        hint.start(SessionMode.DICTATION)
        assertEquals("Nothing to edit", hint.editRefusal())

        val long = "a".repeat(TextSplicer.MAX_EDIT_CHARS + 1)
        val (big, _) = session { target = FieldTarget("com.example.notes", 9, long, false, 0, 0) }
        big.start(SessionMode.DICTATION)
        assertEquals("Too much text to edit", big.editRefusal())

        val (noKey, _) = session { minimax = null }
        noKey.start(SessionMode.DICTATION)
        assertEquals("No MiniMax key", noKey.editRefusal())
    }

    @Test fun `sliding into the edit detent switches a live recording`() = runTest {
        val (s, f) = session { target = FieldTarget("com.example.mail", 3, "hey sam thx", false, 0, 0) }
        s.start(SessionMode.DICTATION)
        assertEquals(SessionState.Listening(SessionMode.DICTATION, 0), s.state.value)

        assertTrue(s.switchTo(SessionMode.EDIT))
        assertEquals(SessionState.Listening(SessionMode.EDIT, 0), s.state.value)

        s.stop()
        runCurrent()
        assertTrue(f.calls.contains("rewrite:hey sam thx|hello world"))
        assertEquals(listOf(Triple("Hello, world.", SessionMode.EDIT, false)), f.inserted)
    }

    @Test fun `sliding back out of the edit detent dictates again`() = runTest {
        val (s, f) = session()
        s.start(SessionMode.DICTATION)
        assertTrue(s.switchTo(SessionMode.EDIT))
        assertTrue(s.switchTo(SessionMode.DICTATION))
        assertEquals(SessionState.Listening(SessionMode.DICTATION, 0), s.state.value)

        s.stop()
        runCurrent()
        assertFalse(f.calls.any { it.startsWith("rewrite") })
        assertEquals(listOf(Triple("hello world", SessionMode.DICTATION, true)), f.inserted)
    }

    @Test fun `the edit detent is refused when the field cannot be edited`() = runTest {
        val (s, _) = session { target = FieldTarget("com.example.bank", 4, "hunter2", false, 0, 0, secure = true) }
        s.start(SessionMode.DICTATION)
        assertFalse(s.switchTo(SessionMode.EDIT))
        assertEquals(SessionState.Listening(SessionMode.DICTATION, 0), s.state.value)
    }

    @Test fun `a switch outside listening is ignored`() = runTest {
        val (s, _) = session()
        assertFalse(s.switchTo(SessionMode.EDIT))
        assertEquals(SessionState.Idle, s.state.value)
    }

    @Test fun `the pill knows whether the edit has a selection`() = runTest {
        val (whole, _) = session { target = FieldTarget("com.example.mail", 3, "hey sam thx", false, 0, 0) }
        whole.start(SessionMode.DICTATION)
        assertFalse(whole.editsSelection())

        val (part, _) = session { target = FieldTarget("com.example.mail", 3, "hey sam thx", false, 4, 7) }
        part.start(SessionMode.DICTATION)
        assertTrue(part.editsSelection())
    }
}
