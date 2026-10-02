package com.shivarajbakale.parley

/**
 * Tap-tap-hold on volume-down, as a pure, time-injected state machine.
 *
 * Ported from the Mac app's gesture-detector.ts. Every volume-down press is
 * consumed while the detector is armed, so the detector also owns the other
 * half of the bargain: presses that turn out not to be the gesture are handed
 * back through [Listener.onReplay] so the caller can apply them to the volume.
 *
 * Times are milliseconds on one monotonic clock (KeyEvent.eventTime is
 * uptimeMillis). The caller drives timeouts by calling [tick] at or after
 * [nextDeadline].
 */
class VolumeGestureDetector(private val listener: Listener) {

    interface Listener {
        fun onStart()
        fun onStop()
        /** `presses` volume-down presses were swallowed and are not the gesture. */
        fun onReplay(presses: Int)
    }

    companion object {
        /** A press held this long is no longer a tap. */
        const val TAP_MAX_MS = 250L
        /** The third press must be held longer than this to start recording. */
        const val HOLD_MIN_MS = 250L
        /** At most this long between one release and the next press. */
        const val GAP_MAX_MS = 350L
        const val TAPS_BEFORE_HOLD = 2
    }

    private var taps = 0
    private var downAt: Long? = null
    private var lastUpAt: Long? = null
    /** A long ordinary press: every auto-repeat is replayed until release. */
    private var passthrough = false
    var recording = false
        private set

    fun onKeyDown(time: Long, repeatCount: Int = 0) {
        if (recording) return
        if (passthrough) {
            if (repeatCount > 0) listener.onReplay(1)
            return
        }
        if (downAt != null) return // auto-repeat while we are still deciding
        val last = lastUpAt
        if (last != null && time - last > GAP_MAX_MS) flush()
        downAt = time
    }

    fun onKeyUp(time: Long) {
        if (recording) {
            recording = false
            reset()
            listener.onStop()
            return
        }
        if (passthrough) {
            passthrough = false
            reset()
            return
        }
        val down = downAt ?: return
        tick(time) // settle a deadline the caller's timer may not have hit yet
        if (recording) {
            // The hold threshold passed exactly at release: a very short recording.
            recording = false
            reset()
            listener.onStop()
            return
        }
        if (passthrough) {
            passthrough = false
            reset()
            return
        }
        downAt = null
        val held = time - down
        if (held >= TAP_MAX_MS) {
            replayAndReset(taps + 1)
            return
        }
        if (taps == TAPS_BEFORE_HOLD) {
            // A third quick tap: not the gesture.
            replayAndReset(taps + 1)
            return
        }
        taps += 1
        lastUpAt = time
    }

    /** The earliest time at which [tick] could change something, or null. */
    fun nextDeadline(): Long? {
        if (recording || passthrough) return null
        val down = downAt
        if (down != null) {
            return if (taps == TAPS_BEFORE_HOLD) down + HOLD_MIN_MS + 1 else down + TAP_MAX_MS
        }
        val last = lastUpAt ?: return null
        return last + GAP_MAX_MS + 1
    }

    fun tick(now: Long) {
        if (recording || passthrough) return
        val down = downAt
        if (down != null) {
            if (taps == TAPS_BEFORE_HOLD) {
                if (now - down > HOLD_MIN_MS) {
                    recording = true
                    listener.onStart()
                }
            } else if (now - down >= TAP_MAX_MS) {
                // An ordinary long press: give back what we held, then pass through.
                val owed = taps + 1
                taps = 0
                lastUpAt = null
                passthrough = true
                listener.onReplay(owed)
            }
            return
        }
        val last = lastUpAt ?: return
        if (now - last > GAP_MAX_MS) flush()
    }

    /**
     * The gesture was switched off, or the service paused. Replays anything
     * held; a live recording is stopped rather than abandoned with the mic open.
     */
    fun disarm() {
        if (recording) {
            recording = false
            reset()
            listener.onStop()
            return
        }
        val owed = taps + if (downAt != null && !passthrough) 1 else 0
        reset()
        if (owed > 0) listener.onReplay(owed)
    }

    private fun flush() {
        val owed = taps
        reset()
        if (owed > 0) listener.onReplay(owed)
    }

    private fun replayAndReset(presses: Int) {
        reset()
        listener.onReplay(presses)
    }

    private fun reset() {
        taps = 0
        downAt = null
        lastUpAt = null
        passthrough = false
    }
}
