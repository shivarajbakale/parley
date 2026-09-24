package com.shivarajbakale.parley

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * The detents a hold slides through: rest dictates, the first stop edits, the
 * far stop cancels. Pure, so the thresholds and the stickiness are unit tests.
 */
class SlideZonesTest {

    private val density = 3f
    private fun dp(v: Float) = v * density

    /** A capsule with room for both detents. */
    private fun roomy() = SlideZones.thresholds(density, track = dp(200f), editable = true)

    @Test fun `a roomy capsule uses the full distances`() {
        val t = roomy()
        assertEquals(dp(SlideZones.EDIT_DP), t.editPx!!, 0.5f)
        assertEquals(dp(SlideZones.CANCEL_DP), t.cancelPx, 0.5f)
    }

    @Test fun `a short capsule compresses but keeps the detents apart`() {
        val t = SlideZones.thresholds(density, track = dp(60f), editable = true)
        val edit = t.editPx!!
        assertEquals(dp(SlideZones.EDIT_FLOOR_DP), edit, 0.5f)
        assertEquals(dp(SlideZones.CANCEL_FLOOR_DP), t.cancelPx, 0.5f)
        assertEquals(true, edit < t.cancelPx)
    }

    @Test fun `no edit detent when the field cannot be edited`() {
        val t = SlideZones.thresholds(density, track = dp(200f), editable = false)
        assertNull(t.editPx)
        assertEquals(dp(SlideZones.CANCEL_DP), t.cancelPx, 0.5f)
    }

    @Test fun `sliding out passes rest, then edit, then cancel`() {
        val t = roomy()
        val edit = t.editPx!!
        assertEquals(SlideZone.DICTATE, t.zoneFor(0f, SlideZone.DICTATE))
        assertEquals(SlideZone.DICTATE, t.zoneFor(edit - 1f, SlideZone.DICTATE))
        assertEquals(SlideZone.EDIT, t.zoneFor(edit, SlideZone.DICTATE))
        assertEquals(SlideZone.EDIT, t.zoneFor(t.cancelPx - 1f, SlideZone.EDIT))
        assertEquals(SlideZone.CANCEL, t.zoneFor(t.cancelPx, SlideZone.EDIT))
    }

    @Test fun `a zone holds until the finger comes back past the hysteresis`() {
        val t = roomy()
        val edit = t.editPx!!
        val hyst = dp(SlideZones.HYSTERESIS_DP)
        assertEquals(SlideZone.CANCEL, t.zoneFor(t.cancelPx - hyst + 1f, SlideZone.CANCEL))
        assertEquals(SlideZone.EDIT, t.zoneFor(t.cancelPx - hyst - 1f, SlideZone.CANCEL))
        assertEquals(SlideZone.EDIT, t.zoneFor(edit - hyst + 1f, SlideZone.EDIT))
        assertEquals(SlideZone.DICTATE, t.zoneFor(edit - hyst - 1f, SlideZone.EDIT))
    }

    @Test fun `without an edit detent the slide goes straight from rest to cancel`() {
        val t = SlideZones.thresholds(density, track = dp(200f), editable = false)
        assertEquals(SlideZone.DICTATE, t.zoneFor(dp(60f), SlideZone.DICTATE))
        assertEquals(SlideZone.CANCEL, t.zoneFor(t.cancelPx, SlideZone.DICTATE))
        assertEquals(SlideZone.DICTATE, t.zoneFor(t.cancelPx - dp(SlideZones.HYSTERESIS_DP) - 1f, SlideZone.CANCEL))
    }

    @Test fun `the orb parks on the detent, not under the finger`() {
        val t = roomy()
        assertEquals(0f, t.snapPx(SlideZone.DICTATE), 0f)
        assertEquals(t.editPx!!, t.snapPx(SlideZone.EDIT), 0f)
        assertEquals(t.cancelPx, t.snapPx(SlideZone.CANCEL), 0f)
    }

    @Test fun `an unavailable edit detent never parks the orb`() {
        val t = SlideZones.thresholds(density, track = dp(200f), editable = false)
        assertEquals(0f, t.snapPx(SlideZone.EDIT), 0f)
    }
}
