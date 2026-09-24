package com.shivarajbakale.parley

import kotlin.math.abs
import kotlin.math.min
import kotlin.math.sqrt

/**
 * A damped spring, stepped by frame time. Everything the orb does that has
 * weight (the press squash, the done pop, the capsule growing out of the orb)
 * runs through one of these, so interrupting a motion keeps its velocity
 * instead of snapping.
 *
 * Pure Kotlin: no Android, so the physics are unit-tested.
 */
class Spring(
    initial: Float,
    private val stiffness: Float,
    dampingRatio: Float,
) {
    var value = initial
        private set
    var velocity = 0f
        private set
    var target = initial

    private val damping = 2f * dampingRatio * sqrt(stiffness)

    val settled: Boolean get() = value == target && velocity == 0f

    /** Advances [dtSec]; returns true while still moving. */
    fun step(dtSec: Float): Boolean {
        var remaining = dtSec
        while (remaining > 0f) {
            val h = min(remaining, MAX_STEP)
            val accel = -stiffness * (value - target) - damping * velocity
            velocity += accel * h
            value += velocity * h
            remaining -= h
        }
        val scale = maxOf(1f, abs(target))
        if (abs(value - target) < REST_DISTANCE * scale && abs(velocity) < REST_VELOCITY * scale) {
            snap()
            return false
        }
        return true
    }

    /** Starts from [v] at rest, keeping the target: a pop that springs from small. */
    fun jumpTo(v: Float) {
        value = v
        velocity = 0f
    }

    /** Jumps to the target with no velocity: reduce-motion, or a first frame. */
    fun snap() {
        value = target
        velocity = 0f
    }

    companion object {
        private const val MAX_STEP = 1f / 240f
        private const val REST_DISTANCE = 0.0015f
        private const val REST_VELOCITY = 0.01f
    }
}

/** The last [size] mic levels, oldest first, for the capsule's waveform. */
class WaveHistory(val size: Int) {
    private val values = FloatArray(size)
    private var head = 0

    fun push(level: Float) {
        values[head] = level.coerceIn(0f, 1f)
        head = (head + 1) % size
    }

    /** [age] 0 is the newest sample. */
    operator fun get(age: Int): Float = values[((head - 1 - age) % size + size) % size]

    fun clear() = values.fill(0f)
}

/** Linear blend of two ARGB colours, channel by channel. */
fun lerpArgb(from: Int, to: Int, t: Float): Int {
    val k = t.coerceIn(0f, 1f)
    fun ch(shift: Int): Int {
        val a = (from ushr shift) and 0xFF
        val b = (to ushr shift) and 0xFF
        return (a + (b - a) * k + 0.5f).toInt().coerceIn(0, 255) shl shift
    }
    return ch(24) or ch(16) or ch(8) or ch(0)
}

enum class SlideZone { DICTATE, EDIT, CANCEL }

object SlideZones {
    const val EDIT_DP = 48f
    const val CANCEL_DP = 96f
    const val EDIT_FLOOR_DP = 28f
    const val CANCEL_FLOOR_DP = 56f
    const val HYSTERESIS_DP = 8f

    /**
     * Where the detents sit for one hold. [editPx] is null when the focused
     * field cannot be rewritten, and then the slide runs straight from rest to
     * cancel with nothing in between.
     */
    class Thresholds(val editPx: Float?, val cancelPx: Float, private val hysteresisPx: Float) {

        /**
         * The zone the finger is in, given the one it was in. A zone holds
         * until the finger comes back past [HYSTERESIS_DP], so resting on a
         * boundary cannot flicker between two modes.
         */
        fun zoneFor(pullPx: Float, current: SlideZone): SlideZone {
            if (pullPx >= cancelPx) return SlideZone.CANCEL
            if (current == SlideZone.CANCEL && pullPx >= cancelPx - hysteresisPx) return SlideZone.CANCEL
            val edit = editPx ?: return SlideZone.DICTATE
            if (pullPx >= edit) return SlideZone.EDIT
            if (current == SlideZone.EDIT && pullPx >= edit - hysteresisPx) return SlideZone.EDIT
            return SlideZone.DICTATE
        }

        /** Where the sphere parks: the detent, not wherever the finger is. */
        fun snapPx(zone: SlideZone): Float = when (zone) {
            SlideZone.DICTATE -> 0f
            SlideZone.EDIT -> editPx ?: 0f
            SlideZone.CANCEL -> cancelPx
        }
    }

    /**
     * [track] is the room the open capsule leaves to slide along. A short
     * capsule compresses both distances, but the floors keep the two detents
     * far enough apart to be separate places.
     */
    fun thresholds(density: Float, track: Float, editable: Boolean): Thresholds {
        fun dp(v: Float) = v * density
        val cancel = min(dp(CANCEL_DP), track * 0.7f).coerceAtLeast(dp(CANCEL_FLOOR_DP))
        // Halfway to the cancel detent, so the two stay evenly spaced as they compress.
        val edit = if (editable) min(dp(EDIT_DP), cancel * 0.5f).coerceAtLeast(dp(EDIT_FLOOR_DP)) else null
        return Thresholds(edit, cancel, dp(HYSTERESIS_DP))
    }
}

/**
 * What the capsule says for a session state, or null when the orb stays a
 * circle. Listening shows a timer (and "Edit" for a voice edit); an error
 * shows its message. Pure, so the wording and the clock are unit-tested.
 */
data class PillContent(val label: String?, val timer: String?, val tone: Tone) {

    enum class Tone { DICTATION, EDIT, WARN }

    companion object {
        /** The timer turns to the warning tone this long before the recording cap. */
        const val WARN_BEFORE_CAP_MS = 10_000L

        fun forState(state: SessionState, nowMs: Long): PillContent? = when (state) {
            is SessionState.Listening -> {
                val elapsed = (nowMs - state.startedAt).coerceAtLeast(0)
                val nearCap = elapsed >= Session.MAX_RECORDING_MS - WARN_BEFORE_CAP_MS
                val edit = state.mode == SessionMode.EDIT
                PillContent(
                    label = null,
                    timer = clock(elapsed),
                    tone = when {
                        nearCap -> Tone.WARN
                        edit -> Tone.EDIT
                        else -> Tone.DICTATION
                    },
                )
            }
            is SessionState.Error -> PillContent(state.message, null, Tone.WARN)
            else -> null
        }

        /** Whole seconds, as `m:ss`. */
        fun clock(elapsedMs: Long): String {
            val s = elapsedMs / 1000
            return "${s / 60}:${(s % 60).toString().padStart(2, '0')}"
        }
    }
}
