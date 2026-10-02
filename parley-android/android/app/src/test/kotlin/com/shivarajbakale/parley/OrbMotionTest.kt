package com.shivarajbakale.parley

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OrbMotionTest {

    /** Runs [spring] at 120 Hz for [seconds]; returns the furthest it got past the target. */
    private fun run(spring: Spring, seconds: Float): Float {
        var overshoot = 0f
        var t = 0f
        while (t < seconds) {
            spring.step(1f / 120f)
            overshoot = maxOf(overshoot, spring.value - spring.target)
            t += 1f / 120f
        }
        return overshoot
    }

    @Test fun `a spring comes to rest exactly on its target`() {
        val s = Spring(0f, 420f, 0.82f)
        s.target = 150f
        run(s, 2f)
        assertTrue(s.settled)
        assertEquals(150f, s.value, 0f)
    }

    @Test fun `an underdamped spring overshoots, a critically damped one does not`() {
        val bouncy = Spring(1f, 700f, 0.5f).apply { target = 1.12f }
        assertTrue(run(bouncy, 1f) > 0.01f)
        val firm = Spring(0f, 260f, 1f).apply { target = 1f }
        assertTrue(run(firm, 1f) < 0.001f)
    }

    @Test fun `step reports motion until settled`() {
        val s = Spring(0f, 420f, 0.82f)
        s.target = 1f
        assertTrue(s.step(1f / 60f))
        run(s, 2f)
        assertFalse(s.step(1f / 60f))
    }

    @Test fun `retargeting mid-flight keeps the velocity`() {
        val s = Spring(0f, 420f, 0.82f)
        s.target = 100f
        repeat(6) { s.step(1f / 120f) }
        val v = s.velocity
        s.target = 0f
        assertEquals(v, s.velocity, 0f)
    }

    @Test fun `jumpTo restarts from a value and springs back to the same target`() {
        val s = Spring(1f, 700f, 0.5f)
        s.jumpTo(0.35f)
        assertEquals(0.35f, s.value, 0f)
        assertEquals(1f, s.target, 0f)
        assertTrue(run(s, 1f) > 0.01f) // pops past full size before settling
        assertEquals(1f, s.value, 0f)
    }

    @Test fun `a long frame does not blow up`() {
        val s = Spring(0f, 700f, 0.5f)
        s.target = 1f
        s.step(0.5f)
        assertTrue(s.value in 0.5f..1.5f)
    }

    @Test fun `wave history returns newest first and wraps`() {
        val w = WaveHistory(3)
        w.push(0.1f); w.push(0.2f); w.push(0.3f); w.push(0.4f)
        assertEquals(0.4f, w[0], 0f)
        assertEquals(0.3f, w[1], 0f)
        assertEquals(0.2f, w[2], 0f)
        w.push(2f)
        assertEquals(1f, w[0], 0f)
        w.clear()
        assertEquals(0f, w[0], 0f)
    }

    @Test fun `lerpArgb blends every channel`() {
        assertEquals(0xFF000000.toInt(), lerpArgb(0xFF000000.toInt(), 0xFFFFFFFF.toInt(), 0f))
        assertEquals(0xFFFFFFFF.toInt(), lerpArgb(0xFF000000.toInt(), 0xFFFFFFFF.toInt(), 1f))
        assertEquals(0x80808080.toInt(), lerpArgb(0x00000000, 0xFFFFFFFF.toInt(), 0.5f))
        assertEquals(0xFF5B4FE0.toInt(), lerpArgb(0xFF5B4FE0.toInt(), 0xFF2FA86A.toInt(), -1f))
    }
}
