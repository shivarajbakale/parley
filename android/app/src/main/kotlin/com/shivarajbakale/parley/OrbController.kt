package com.shivarajbakale.parley

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.PixelFormat
import android.graphics.Rect
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.ViewConfiguration
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.view.animation.OvershootInterpolator
import android.view.animation.PathInterpolator
import kotlin.math.abs
import kotlin.math.hypot

/**
 * Owns the orb's overlay window: adding and removing it, dragging and docking
 * to the nearest side, remembering where it sits, staying above the keyboard,
 * tucking into the edge when there is nothing to type into, and turning
 * touches into hold / double-tap-hold / tap.
 *
 * The window is as wide as the orb's current shape: the view asks for more
 * room before its capsule grows, and the window is anchored on the docked
 * side so the sphere never moves while it does.
 */
class OrbController(
    private val context: Context,
    private val config: ConfigStore,
    private val listener: Listener,
) : OrbView.Host {
    interface Listener {
        fun onHoldStart(mode: SessionMode)
        fun onHoldEnd()
        /** Released after sliding toward the middle: throw the recording away. */
        fun onHoldCancel()
        /** A slide-to-cancel crossed the line, either way. */
        fun onCancelArmed(armed: Boolean)
        fun onTap()
    }

    companion object {
        private const val TAG = "ParleyOrb"
        const val HOLD_MS = 150L
        const val DOUBLE_TAP_MS = 300L
        private const val EDGE_GAP_DP = 8f
        /** How much of a tucked orb shows at the edge. */
        private const val PEEK_DP = 14f
        /** A tap on the tucked orb brings it out for this long. */
        private const val PEEK_HOLD_MS = 3_000L
        private const val DOCK_MS = 380L
        private const val TUCK_MS = 280L
        /** Riding up or down with the keyboard: the IME's own duration and curve. */
        private const val IME_MS = 300L
        private val IME_EASE = PathInterpolator(0.2f, 0f, 0f, 1f)
    }

    private val wm = context.getSystemService(WindowManager::class.java)
    private val handler = Handler(Looper.getMainLooper())
    val view = OrbView(context)
    private val density = context.resources.displayMetrics.density
    private val touchSlop = ViewConfiguration.get(context).scaledTouchSlop

    private val params = WindowManager.LayoutParams(
        0, 0,
        WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
        PixelFormat.TRANSLUCENT,
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        title = "Parley orb"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
    }

    private var attached = false
    /** Top of the keyboard in screen pixels, while one is showing. */
    private var imeTop: Int? = null
    private var dockAnimator: ValueAnimator? = null
    private var yAnimator: ValueAnimator? = null

    private var dockRight = true
    /** 0 out, 1 tucked into the edge. */
    private var tuck = 0f
    private var tuckAnimator: ValueAnimator? = null
    private var tuckRequested = false
    private var peekUntil = 0L

    private var downRawX = 0f
    private var downRawY = 0f
    private var downParamX = 0
    private var downParamY = 0
    private var dragging = false
    private var holding = false
    private var secondPress = false
    private var lastTapUpAt = 0L
    /** The press landed on a tucked orb: it only brings the orb out. */
    private var peeking = false
    private var cancelArmed = false

    init {
        dockRight = config.orbPosition().dockRight
        view.dockRight = dockRight
        applySize(config.config.value.orbSize)
        view.host = this
        view.setOnTouchListener { _, e -> onTouch(e) }
    }

    val isShowing: Boolean get() = attached

    fun setVisible(visible: Boolean) {
        if (visible == attached) return
        try {
            if (visible) {
                tuck = if (wantTucked()) 1f else 0f
                view.dimmed = tuck == 1f
                placeFromSaved()
                wm.addView(view, params)
                attached = true
            } else {
                cancelGesture()
                tuckAnimator?.cancel()
                wm.removeView(view)
                attached = false
            }
        } catch (e: Exception) {
            Log.w(TAG, "overlay ${if (visible) "add" else "remove"} failed", e)
        }
    }

    fun applySize(orbSize: OrbSize) {
        view.maxWidthPx = maxWindowWidth()
        val d = orbSize.dp * density
        if (view.diameterPx != d || params.width == 0) {
            view.diameterPx = d
            params.width = view.compactWidth()
        }
        params.height = view.windowHeight()
        if (attached) {
            placeFromSaved()
            update()
        }
    }

    /** What the capsule says, or null to keep the orb a circle. */
    fun setPill(content: PillContent?) {
        view.content = content
        applyTuck()
    }

    /** Tuck into the edge (nothing to type into) or come out. */
    fun setTucked(tucked: Boolean) {
        tuckRequested = tucked
        applyTuck()
    }

    fun setImeTop(top: Int?) {
        if (top == imeTop) return
        imeTop = top
        if (!attached || dragging) return
        // Glide to the new height rather than jumping as the keyboard comes and goes.
        val from = params.y
        placeFromSaved()
        val to = params.y
        params.y = from
        animateY(to)
    }

    private fun animateY(to: Int) {
        yAnimator?.cancel()
        if (params.y == to) return
        yAnimator = ValueAnimator.ofInt(params.y, to).apply {
            duration = IME_MS
            interpolator = IME_EASE
            addUpdateListener {
                params.y = it.animatedValue as Int
                update()
            }
            start()
        }
    }

    /** Screen size changed (rotation, fold). */
    fun onConfigurationChanged() {
        view.maxWidthPx = maxWindowWidth()
        if (attached) {
            placeFromSaved()
            update()
        }
    }

    fun destroy() {
        handler.removeCallbacksAndMessages(null)
        dockAnimator?.cancel()
        tuckAnimator?.cancel()
        yAnimator?.cancel()
        setVisible(false)
    }

    // ---- OrbView.Host ---------------------------------------------------

    override fun onWidthNeeded(px: Int) {
        if (params.width == px) return
        params.width = px
        if (!dragging) params.x = xFor(dockRight, tuck)
        update()
    }

    // ---- position -------------------------------------------------------

    private fun screen(): Rect =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            wm.currentWindowMetrics.bounds
        } else {
            val dm = context.resources.displayMetrics
            Rect(0, 0, dm.widthPixels, dm.heightPixels)
        }

    private fun maxWindowWidth(): Int = (screen().width() * 0.86f + 2 * view.marginPx).toInt()

    /**
     * Window x that puts the sphere [EDGE_GAP_DP] from the screen side when
     * out, or leaves only [PEEK_DP] of it showing when tucked.
     */
    private fun xFor(right: Boolean, tuckAmount: Float): Int {
        val w = screen().width()
        val m = view.marginPx
        val d = view.diameterPx
        val gap = EDGE_GAP_DP * density
        val peek = PEEK_DP * density
        return if (right) {
            val out = w - gap - params.width + m
            val tucked = w - peek - params.width + m + d
            (out + (tucked - out) * tuckAmount).toInt()
        } else {
            val out = gap - m
            val tucked = peek - m - d
            (out + (tucked - out) * tuckAmount).toInt()
        }
    }

    private fun yRange(): IntRange {
        val s = screen()
        val top = (24 * density).toInt()
        var bottom = s.height() - params.height - (24 * density).toInt()
        imeTop?.let { bottom = minOf(bottom, it - params.height) }
        return top..maxOf(top, bottom)
    }

    private fun placeFromSaved() {
        yAnimator?.cancel()
        val saved = config.orbPosition()
        dockRight = saved.dockRight
        view.dockRight = dockRight
        val s = screen()
        params.x = xFor(dockRight, tuck)
        val full = (s.height() - params.height).coerceAtLeast(1)
        val range = yRange()
        params.y = (saved.yFraction * full).toInt().coerceIn(range.first, range.last)
    }

    private fun update() {
        if (!attached) return
        try {
            wm.updateViewLayout(view, params)
        } catch (e: Exception) {
            Log.w(TAG, "updateViewLayout failed", e)
        }
    }

    /** Snap to the nearer side with a little overshoot, and remember it. */
    private fun dock() {
        val s = screen()
        val centre = params.x + params.width / 2
        val right = centre > s.width() / 2
        val full = (s.height() - params.height).coerceAtLeast(1)
        params.y = params.y.coerceIn(yRange().first, yRange().last)
        config.saveOrbPosition(ConfigStore.OrbPosition(right, params.y / full.toFloat()))
        dockRight = right
        view.dockRight = right // the compact window is symmetric, so this moves nothing
        val target = xFor(right, tuck)
        dockAnimator?.cancel()
        dockAnimator = ValueAnimator.ofInt(params.x, target).apply {
            duration = DOCK_MS
            interpolator = OvershootInterpolator(1.1f)
            addUpdateListener {
                params.x = it.animatedValue as Int
                update()
            }
            start()
        }
    }

    // ---- tuck -----------------------------------------------------------

    private fun wantTucked(): Boolean =
        tuckRequested && SystemClock.uptimeMillis() >= peekUntil && !dragging && !holding && view.content == null

    private val retuck = Runnable { applyTuck() }

    private fun applyTuck() {
        val target = if (wantTucked()) 1f else 0f
        view.dimmed = target == 1f
        if (!attached) {
            tuck = target
            return
        }
        if (tuck == target && tuckAnimator?.isRunning != true) return
        tuckAnimator?.cancel()
        tuckAnimator = ValueAnimator.ofFloat(tuck, target).apply {
            duration = TUCK_MS
            interpolator = DecelerateInterpolator(1.6f)
            addUpdateListener {
                tuck = it.animatedValue as Float
                params.x = xFor(dockRight, tuck)
                update()
            }
            start()
        }
    }

    /** Bring a tucked orb out for a moment, then let it slide back. */
    private fun keepOut(now: Long) {
        peekUntil = now + PEEK_HOLD_MS
        handler.removeCallbacks(retuck)
        handler.postDelayed(retuck, PEEK_HOLD_MS + 16)
    }

    // ---- touch ----------------------------------------------------------

    private val holdRunnable = Runnable {
        holding = true
        view.squashed = false // spring back out as the capsule opens
        listener.onHoldStart(if (secondPress) SessionMode.EDIT else SessionMode.DICTATION)
    }
    private val tapRunnable = Runnable { listener.onTap() }

    private fun cancelGesture() {
        handler.removeCallbacks(holdRunnable)
        view.squashed = false
        view.lifted = false
        view.cancelPullPx = 0f
        cancelArmed = false
        if (holding) {
            holding = false
            listener.onHoldEnd()
        }
        dragging = false
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun onTouch(e: MotionEvent): Boolean {
        val now = SystemClock.uptimeMillis()
        if (e.actionMasked == MotionEvent.ACTION_DOWN) peeking = tuck > 0.5f
        if (peeking) {
            // A press on the tucked sliver only brings the orb out.
            if (e.actionMasked == MotionEvent.ACTION_DOWN) {
                keepOut(now)
                applyTuck()
            }
            if (e.actionMasked == MotionEvent.ACTION_UP || e.actionMasked == MotionEvent.ACTION_CANCEL) peeking = false
            return true
        }
        // Any touch on an out orb keeps it out a little longer.
        if (tuckRequested) keepOut(now)

        when (e.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                dockAnimator?.cancel()
                yAnimator?.cancel()
                downRawX = e.rawX
                downRawY = e.rawY
                downParamX = params.x
                downParamY = params.y
                dragging = false
                holding = false
                cancelArmed = false
                view.cancelPullPx = 0f
                view.squashed = true
                secondPress = now - lastTapUpAt <= DOUBLE_TAP_MS
                if (secondPress) handler.removeCallbacks(tapRunnable) // part of a double tap, not a tap
                handler.postDelayed(holdRunnable, HOLD_MS)
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = e.rawX - downRawX
                val dy = e.rawY - downRawY
                if (!holding && !dragging && hypot(dx, dy) > touchSlop) {
                    dragging = true
                    handler.removeCallbacks(holdRunnable)
                    view.squashed = false
                    view.lifted = true
                }
                if (dragging) {
                    params.x = downParamX + dx.toInt()
                    params.y = downParamY + dy.toInt()
                    update()
                } else if (holding) {
                    // Slide toward the middle of the screen to cancel.
                    view.cancelPullPx = if (dockRight) -dx else dx
                    if (view.cancelArmed != cancelArmed) {
                        cancelArmed = view.cancelArmed
                        listener.onCancelArmed(cancelArmed)
                    }
                }
            }
            MotionEvent.ACTION_UP -> {
                handler.removeCallbacks(holdRunnable)
                view.squashed = false
                when {
                    holding -> {
                        holding = false
                        if (cancelArmed) {
                            cancelArmed = false
                            view.discard()
                            listener.onHoldCancel()
                        } else {
                            view.cancelPullPx = 0f
                            listener.onHoldEnd()
                        }
                    }
                    dragging -> {
                        dragging = false
                        view.lifted = false
                        dock()
                    }
                    secondPress -> lastTapUpAt = 0 // a double tap without a hold does nothing
                    else -> {
                        lastTapUpAt = now
                        // Wait out the double-tap window before calling it a single tap.
                        handler.postDelayed(tapRunnable, DOUBLE_TAP_MS)
                    }
                }
            }
            MotionEvent.ACTION_CANCEL -> {
                val moved = abs(params.x - downParamX) + abs(params.y - downParamY) > 0
                cancelGesture()
                if (moved) dock()
            }
        }
        return true
    }
}
