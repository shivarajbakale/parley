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
import kotlin.math.abs
import kotlin.math.hypot

/**
 * Owns the orb's overlay window: adding and removing it, dragging and docking
 * to the nearest side, remembering where it sits, staying above the keyboard,
 * and turning touches into hold / double-tap-hold / tap.
 */
class OrbController(
    private val context: Context,
    private val config: ConfigStore,
    private val listener: Listener,
) {
    interface Listener {
        fun onHoldStart(mode: SessionMode)
        fun onHoldEnd()
        fun onTap()
    }

    companion object {
        private const val TAG = "ParleyOrb"
        const val HOLD_MS = 150L
        const val DOUBLE_TAP_MS = 300L
        private const val EDGE_GAP_DP = 6f
        private const val DOCK_MS = 220L
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
    private var size = OrbSize.MEDIUM
    /** Top of the keyboard in screen pixels, while one is showing. */
    private var imeTop: Int? = null
    private var dockAnimator: ValueAnimator? = null

    init {
        applySize(config.config.value.orbSize)
        view.setOnTouchListener { _, e -> onTouch(e) }
    }

    val isShowing: Boolean get() = attached

    fun setVisible(visible: Boolean) {
        if (visible == attached) return
        try {
            if (visible) {
                placeFromSaved()
                wm.addView(view, params)
                attached = true
            } else {
                cancelGesture()
                wm.removeView(view)
                attached = false
            }
        } catch (e: Exception) {
            Log.w(TAG, "overlay ${if (visible) "add" else "remove"} failed", e)
        }
    }

    fun applySize(orbSize: OrbSize) {
        size = orbSize
        val d = orbSize.dp * density
        view.diameterPx = d
        val px = (d * OrbView.WINDOW_SCALE).toInt()
        params.width = px
        params.height = px
        if (attached) {
            placeFromSaved()
            update()
        }
    }

    fun setImeTop(top: Int?) {
        if (top == imeTop) return
        imeTop = top
        if (attached && !dragging) {
            placeFromSaved()
            update()
        }
    }

    /** Screen size changed (rotation, fold). */
    fun onConfigurationChanged() {
        if (attached) {
            placeFromSaved()
            update()
        }
    }

    fun destroy() {
        handler.removeCallbacksAndMessages(null)
        dockAnimator?.cancel()
        setVisible(false)
    }

    // ---- position -------------------------------------------------------

    private fun screen(): Rect =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            wm.currentWindowMetrics.bounds
        } else {
            val dm = context.resources.displayMetrics
            Rect(0, 0, dm.widthPixels, dm.heightPixels)
        }

    /** The window x that puts the orb's edge [EDGE_GAP_DP] from the screen side. */
    private fun dockX(right: Boolean): Int {
        val s = screen()
        val margin = ((params.width - view.diameterPx) / 2f - EDGE_GAP_DP * density).toInt()
        return if (right) s.width() - params.width + margin else -margin
    }

    private fun yRange(): IntRange {
        val s = screen()
        val top = (24 * density).toInt()
        var bottom = s.height() - params.height - (24 * density).toInt()
        imeTop?.let { bottom = minOf(bottom, it - params.height) }
        return top..maxOf(top, bottom)
    }

    private fun placeFromSaved() {
        val saved = config.orbPosition()
        val s = screen()
        params.x = dockX(saved.dockRight)
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

    private fun dock() {
        val s = screen()
        val right = params.x + params.width / 2 > s.width() / 2
        val full = (s.height() - params.height).coerceAtLeast(1)
        params.y = params.y.coerceIn(yRange().first, yRange().last)
        config.saveOrbPosition(ConfigStore.OrbPosition(right, params.y / full.toFloat()))
        val target = dockX(right)
        dockAnimator?.cancel()
        if (!ValueAnimator.areAnimatorsEnabled()) {
            params.x = target
            update()
            return
        }
        dockAnimator = ValueAnimator.ofInt(params.x, target).apply {
            duration = DOCK_MS
            interpolator = DecelerateInterpolator()
            addUpdateListener {
                params.x = it.animatedValue as Int
                update()
            }
            start()
        }
    }

    // ---- touch ----------------------------------------------------------

    private var downRawX = 0f
    private var downRawY = 0f
    private var downParamX = 0
    private var downParamY = 0
    private var dragging = false
    private var holding = false
    private var secondPress = false
    private var lastTapUpAt = 0L

    private val holdRunnable = Runnable {
        holding = true
        listener.onHoldStart(if (secondPress) SessionMode.EDIT else SessionMode.DICTATION)
    }
    private val tapRunnable = Runnable { listener.onTap() }

    private fun cancelGesture() {
        handler.removeCallbacks(holdRunnable)
        if (holding) {
            holding = false
            listener.onHoldEnd()
        }
        dragging = false
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun onTouch(e: MotionEvent): Boolean {
        val now = SystemClock.uptimeMillis()
        when (e.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                dockAnimator?.cancel()
                downRawX = e.rawX
                downRawY = e.rawY
                downParamX = params.x
                downParamY = params.y
                dragging = false
                holding = false
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
                }
                if (dragging) {
                    params.x = downParamX + dx.toInt()
                    params.y = downParamY + dy.toInt()
                    update()
                }
            }
            MotionEvent.ACTION_UP -> {
                handler.removeCallbacks(holdRunnable)
                when {
                    holding -> {
                        holding = false
                        listener.onHoldEnd()
                    }
                    dragging -> {
                        dragging = false
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
                cancelGesture()
                if (abs(params.x - downParamX) + abs(params.y - downParamY) > 0) dock()
            }
        }
        return true
    }
}
