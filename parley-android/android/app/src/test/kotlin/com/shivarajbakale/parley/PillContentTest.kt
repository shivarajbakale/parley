package com.shivarajbakale.parley

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PillContentTest {

    private val start = 1_000_000L

    private fun listening(mode: SessionMode, elapsedMs: Long) =
        PillContent.forState(SessionState.Listening(mode, start), start + elapsedMs)!!

    @Test fun `clock is m colon ss in whole seconds`() {
        assertEquals("0:00", PillContent.clock(0))
        assertEquals("0:04", PillContent.clock(4_999))
        assertEquals("0:59", PillContent.clock(59_999))
        assertEquals("1:00", PillContent.clock(60_000))
        assertEquals("2:00", PillContent.clock(120_000))
    }

    @Test fun `dictation shows just the elapsed time`() {
        assertEquals(PillContent(null, "0:04", PillContent.Tone.DICTATION), listening(SessionMode.DICTATION, 4_200))
    }

    @Test fun `voice edit carries no text, only its tone`() {
        assertEquals(PillContent(null, "0:12", PillContent.Tone.EDIT), listening(SessionMode.EDIT, 12_000))
    }

    @Test fun `the last ten seconds before the cap warn`() {
        val justBefore = Session.MAX_RECORDING_MS - PillContent.WARN_BEFORE_CAP_MS - 1
        assertEquals(PillContent.Tone.DICTATION, listening(SessionMode.DICTATION, justBefore).tone)
        val warn = listening(SessionMode.EDIT, Session.MAX_RECORDING_MS - PillContent.WARN_BEFORE_CAP_MS)
        assertEquals(PillContent.Tone.WARN, warn.tone)
        assertEquals("1:50", warn.timer)
    }

    @Test fun `a clock that ran backwards shows zero, not a negative`() {
        assertEquals("0:00", listening(SessionMode.DICTATION, -3_000).timer)
    }

    @Test fun `an error opens the capsule with its message`() {
        assertEquals(
            PillContent("No Groq key", null, PillContent.Tone.WARN),
            PillContent.forState(SessionState.Error("No Groq key"), start),
        )
    }

    @Test fun `working, done and idle keep the orb a circle`() {
        assertNull(PillContent.forState(SessionState.Idle, start))
        assertNull(PillContent.forState(SessionState.Transcribing(SessionMode.DICTATION), start))
        assertNull(PillContent.forState(SessionState.Rewriting, start))
        assertNull(PillContent.forState(SessionState.Inserting(SessionMode.DICTATION), start))
        assertNull(PillContent.forState(SessionState.Done(SessionMode.DICTATION, InsertMethod.SET_TEXT), start))
    }
}
