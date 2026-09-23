package com.shivarajbakale.parley

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VolumeGestureDetectorTest {

    /** Records what the detector did, as a readable log. */
    private class Log : VolumeGestureDetector.Listener {
        val events = mutableListOf<String>()
        override fun onStart() { events += "start" }
        override fun onStop() { events += "stop" }
        override fun onReplay(presses: Int) { events += "replay$presses" }
    }

    /**
     * A script is a list of steps: "d@t" key down, "u@t" key up, "t@t" a timer
     * tick. Ticks are also run at every deadline the detector asks for that
     * falls before the next step, like the service's Handler would.
     */
    private fun run(vararg steps: String): List<String> {
        val log = Log()
        val d = VolumeGestureDetector(log)
        var now = 0L
        fun advanceTo(t: Long) {
            while (true) {
                val due = d.nextDeadline() ?: break
                if (due > t) break
                d.tick(due)
            }
            now = t
        }
        for (step in steps) {
            val (kind, at) = step.split("@")
            val t = at.toLong()
            advanceTo(t)
            when (kind) {
                "d" -> d.onKeyDown(t)
                "r" -> d.onKeyDown(t, repeatCount = 1)
                "u" -> d.onKeyUp(t)
                "t" -> d.tick(t)
            }
        }
        advanceTo(now + 10_000)
        return log.events
    }

    @Test fun `tap tap hold starts and release stops`() {
        assertEquals(
            listOf("start", "stop"),
            run("d@0", "u@80", "d@200", "u@280", "d@400", "u@2400"),
        )
    }

    @Test fun `the hold must pass 250 ms`() {
        // Third press released at 240 ms: a third tap, all three given back.
        assertEquals(listOf("replay3"), run("d@0", "u@80", "d@200", "u@280", "d@400", "u@640"))
    }

    @Test fun `hold just over the threshold starts`() {
        assertEquals(listOf("start", "stop"), run("d@0", "u@80", "d@200", "u@280", "d@400", "u@700"))
    }

    @Test fun `single press is replayed after the gap`() {
        assertEquals(listOf("replay1"), run("d@0", "u@90"))
    }

    @Test fun `double press is replayed as two`() {
        assertEquals(listOf("replay2"), run("d@0", "u@90", "d@300", "u@380"))
    }

    @Test fun `a gap over 350 ms breaks the sequence`() {
        // Second tap arrives 400 ms after the first release: first is replayed alone.
        assertEquals(
            listOf("replay1", "replay2"),
            run("d@0", "u@80", "d@480", "u@560", "d@700", "u@780"),
        )
    }

    @Test fun `gap of exactly 350 ms still counts`() {
        assertEquals(listOf("start", "stop"), run("d@0", "u@80", "d@430", "u@510", "d@860", "u@1500"))
    }

    @Test fun `a long first press passes through and repeats are replayed`() {
        assertEquals(
            listOf("replay1", "replay1", "replay1"),
            run("d@0", "r@500", "r@550", "u@600"),
        )
    }

    @Test fun `a long second press gives back both`() {
        assertEquals(listOf("replay2"), run("d@0", "u@80", "d@200", "u@700"))
    }

    @Test fun `auto repeat during the hold is ignored`() {
        assertEquals(
            listOf("start", "stop"),
            run("d@0", "u@80", "d@200", "u@280", "d@400", "r@900", "r@950", "u@1200"),
        )
    }

    @Test fun `four quick taps replay three then one`() {
        assertEquals(
            listOf("replay3", "replay1"),
            run("d@0", "u@80", "d@200", "u@280", "d@400", "u@450", "d@600", "u@650"),
        )
    }

    @Test fun `release without tick still settles the hold`() {
        // No timer ran: the release itself notices the hold passed 250 ms.
        val log = Log()
        val d = VolumeGestureDetector(log)
        d.onKeyDown(0); d.onKeyUp(80)
        d.onKeyDown(200); d.onKeyUp(280)
        d.onKeyDown(400)
        d.onKeyUp(900)
        assertEquals(listOf("start", "stop"), log.events)
    }

    @Test fun `disarm replays held presses`() {
        val log = Log()
        val d = VolumeGestureDetector(log)
        d.onKeyDown(0); d.onKeyUp(80); d.onKeyDown(200)
        d.disarm()
        assertEquals(listOf("replay2"), log.events)
        assertEquals(null, d.nextDeadline())
    }

    @Test fun `disarm while recording stops`() {
        val log = Log()
        val d = VolumeGestureDetector(log)
        d.onKeyDown(0); d.onKeyUp(80); d.onKeyDown(200); d.onKeyUp(280); d.onKeyDown(400)
        d.tick(700)
        assertTrue(d.recording)
        d.disarm()
        assertFalse(d.recording)
        assertEquals(listOf("start", "stop"), log.events)
    }

    @Test fun `deadlines are what the service schedules`() {
        val d = VolumeGestureDetector(Log())
        assertEquals(null, d.nextDeadline())
        d.onKeyDown(1_000)
        assertEquals(1_250L, d.nextDeadline())
        d.onKeyUp(1_080)
        assertEquals(1_431L, d.nextDeadline())
    }
}
