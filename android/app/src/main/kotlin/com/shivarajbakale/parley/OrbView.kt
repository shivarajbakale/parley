package com.shivarajbakale.parley

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PathMeasure
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.os.SystemClock
import android.view.View
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.min
import kotlin.math.sin

/**
 * The orb, drawn on a Canvas in the "Aurora" look: a layered radial gradient
 * per mode, lit from the upper left, with a soft glow in the mode colour.
 *
 * The view is larger than the orb ([windowScale]) so the glow and the
 * listening ring have room; the orb itself is [diameterPx] across.
 */
@SuppressLint("ViewConstructor")
class OrbView(context: Context) : View(context) {

    enum class Visual { IDLE, LISTENING_DICTATION, LISTENING_EDIT, WORKING_DICTATION, WORKING_EDIT, DONE, COPIED, ERROR }

    private class Palette(val stops: IntArray) {
        val glow: Int get() = stops[2]
    }

    companion object {
        /** View size relative to the orb, to leave room for glow and ring. */
        const val WINDOW_SCALE = 1.6f
        private val STOPS = floatArrayOf(0f, 0.24f, 0.6f, 1f)
        private val INDIGO = Palette(intArrayOf(0xFFE4E4FF.toInt(), 0xFF9C9CFF.toInt(), 0xFF5B4FE0.toInt(), 0xFF231A6E.toInt()))
        private val AMBER = Palette(intArrayOf(0xFFFFF4D6.toInt(), 0xFFF7C35C.toInt(), 0xFFD2811A.toInt(), 0xFF6B3706.toInt()))
        private val GREEN = Palette(intArrayOf(0xFFDDFBEA.toInt(), 0xFF7FE3AE.toInt(), 0xFF2FA86A.toInt(), 0xFF0D4A2B.toInt()))
        private val RED = Palette(intArrayOf(0xFFFFE0E0.toInt(), 0xFFFF9C9C.toInt(), 0xFFD94848.toInt(), 0xFF5E1414.toInt()))
        private const val RING_DICTATION = 0xFF8B8BFF.toInt()

        /** Highlight centre as a fraction of the orb's bounding box. */
        private const val HIGHLIGHT_X = 0.34f
        private const val HIGHLIGHT_Y = 0.28f

        private const val BREATHE_MS = 4_200L
        private const val PULSE_MS = 1_100L
        private const val RING_MS = 1_400L
        private const val SPIN_MS = 900L
        private const val TICK_MS = 260L
        private const val SHAKE_MS = 450L
        private const val IDLE_FRAME_MS = 33L
    }

    var diameterPx: Float = 64f * resources.displayMetrics.density
        set(value) { field = value; requestLayout(); invalidate() }

    var visual: Visual = Visual.IDLE
        set(value) {
            if (field == value) return
            field = value
            visualSince = SystemClock.uptimeMillis()
            invalidate()
        }

    private var visualSince = SystemClock.uptimeMillis()
    private val born = SystemClock.uptimeMillis()
    private var level = 0f

    /** Mic RMS, 0..1. Smoothed so the ring follows speech, not every sample. */
    fun setLevel(rms: Float) {
        // Speech RMS rarely passes 0.3; stretch it so the ring visibly moves.
        val target = (rms * 3.2f).coerceIn(0f, 1f)
        level += (target - level) * 0.45f
    }

    private val density = resources.displayMetrics.density
    private val shaderMatrix = Matrix()
    private val bodyShaders = HashMap<Palette, Shader>()
    private val glowShaders = HashMap<Palette, Shader>()
    private val bodyPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val rimPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 1f * density
        color = Color.argb(40, 255, 255, 255)
    }
    private val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 2f * density
    }
    private val markPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
        color = Color.WHITE
    }
    private val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
    private val arcRect = RectF()
    private val tickPath = Path()
    private val tickPart = Path()
    private val tickMeasure = PathMeasure()

    /** Animator duration scale 0 is the system's reduce-motion switch. */
    private fun reduceMotion(): Boolean = !ValueAnimator.areAnimatorsEnabled()

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val size = (diameterPx * WINDOW_SCALE).toInt()
        setMeasuredDimension(size, size)
    }

    private fun palette(): Palette = when (visual) {
        Visual.IDLE, Visual.LISTENING_DICTATION, Visual.WORKING_DICTATION -> INDIGO
        Visual.LISTENING_EDIT, Visual.WORKING_EDIT -> AMBER
        Visual.DONE, Visual.COPIED -> GREEN
        Visual.ERROR -> RED
    }

    /** Unit-radius shaders, placed each frame with a matrix so drawing allocates nothing. */
    private fun bodyShader(p: Palette): Shader = bodyShaders.getOrPut(p) {
        // Highlight offset from the centre, in radii: box fraction * 2 - 1.
        val hx = HIGHLIGHT_X * 2 - 1
        val hy = HIGHLIGHT_Y * 2 - 1
        // Far enough that the last stop lands on the opposite edge.
        val reach = 1f + kotlin.math.sqrt(hx * hx + hy * hy)
        RadialGradient(hx, hy, reach, p.stops, STOPS, Shader.TileMode.CLAMP)
    }

    private fun glowShader(p: Palette): Shader = glowShaders.getOrPut(p) {
        val c = p.glow
        RadialGradient(
            0f, 0f, 1f,
            intArrayOf(withAlpha(c, 110), withAlpha(c, 110), withAlpha(c, 40), withAlpha(c, 0)),
            floatArrayOf(0f, 0.6f, 0.78f, 1f),
            Shader.TileMode.CLAMP,
        )
    }

    private fun withAlpha(color: Int, alpha: Int) = Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))

    override fun onDraw(canvas: Canvas) {
        val now = SystemClock.uptimeMillis()
        val t = now - visualSince
        val still = reduceMotion()
        val p = palette()
        val baseR = diameterPx / 2f
        val maxR = min(width, height) / 2f - ringPaint.strokeWidth

        var cx = width / 2f
        val cy = height / 2f
        var scale = 1f
        var animating = false

        when (visual) {
            Visual.IDLE -> if (!still) {
                val phase = ((now - born) % BREATHE_MS) / BREATHE_MS.toFloat()
                scale = 1f + 0.05f * (0.5f - 0.5f * cos(2 * PI * phase).toFloat())
                animating = true
            }
            Visual.LISTENING_DICTATION, Visual.LISTENING_EDIT -> {
                if (!still) {
                    val phase = (t % PULSE_MS) / PULSE_MS.toFloat()
                    scale = 1f + 0.04f * (0.5f - 0.5f * cos(2 * PI * phase).toFloat())
                }
                scale += level * 0.05f
                animating = true // the level ring follows the mic even without motion
            }
            Visual.ERROR -> if (!still && t < SHAKE_MS) {
                val decay = exp(-3.0 * t / SHAKE_MS).toFloat()
                cx += sin(t / 1000f * 2 * PI.toFloat() * 11f) * 6f * density * decay
                animating = true
            }
            Visual.WORKING_DICTATION, Visual.WORKING_EDIT -> animating = !still
            Visual.DONE, Visual.COPIED -> animating = !still && t < TICK_MS
        }
        val r = baseR * scale

        // Glow.
        val glowR = min(r * 1.42f, maxR + ringPaint.strokeWidth)
        shaderMatrix.setScale(glowR, glowR)
        shaderMatrix.postTranslate(cx, cy)
        glowPaint.shader = glowShader(p).also { it.setLocalMatrix(shaderMatrix) }
        glowPaint.alpha = if (visual == Visual.IDLE) 150 else 255
        canvas.drawCircle(cx, cy, glowR, glowPaint)

        // Body.
        shaderMatrix.setScale(r, r)
        shaderMatrix.postTranslate(cx, cy)
        bodyPaint.shader = bodyShader(p).also { it.setLocalMatrix(shaderMatrix) }
        bodyPaint.alpha = if (visual == Visual.IDLE) 179 else 255 // idle: 70 %
        canvas.drawCircle(cx, cy, r, bodyPaint)
        canvas.drawCircle(cx, cy, r - rimPaint.strokeWidth / 2, rimPaint)

        when (visual) {
            Visual.LISTENING_DICTATION, Visual.LISTENING_EDIT -> drawRing(canvas, cx, cy, r, maxR, t, still)
            Visual.WORKING_DICTATION, Visual.WORKING_EDIT -> drawSpinner(canvas, cx, cy, r, t, still)
            Visual.DONE -> drawTick(canvas, cx, cy, r, t, still)
            Visual.COPIED -> drawCopied(canvas, cx, cy, r)
            Visual.ERROR -> drawBang(canvas, cx, cy, r)
            Visual.IDLE -> Unit
        }

        if (animating && isAttachedToWindow) {
            if (visual == Visual.IDLE) postInvalidateDelayed(IDLE_FRAME_MS) else postInvalidateOnAnimation()
        }
    }

    private fun drawRing(canvas: Canvas, cx: Float, cy: Float, r: Float, maxR: Float, t: Long, still: Boolean) {
        val color = if (visual == Visual.LISTENING_EDIT) AMBER.stops[1] else RING_DICTATION
        val levelPush = level * r * 0.22f
        if (still) {
            ringPaint.color = withAlpha(color, 160)
            canvas.drawCircle(cx, cy, min(r * 1.1f + levelPush, maxR), ringPaint)
            return
        }
        val phase = (t % RING_MS) / RING_MS.toFloat()
        ringPaint.color = withAlpha(color, ((1f - phase) * 230).toInt())
        canvas.drawCircle(cx, cy, min(r * (1.02f + 0.4f * phase) + levelPush, maxR), ringPaint)
    }

    private fun drawSpinner(canvas: Canvas, cx: Float, cy: Float, r: Float, t: Long, still: Boolean) {
        val inset = r * 0.5f
        arcRect.set(cx - inset, cy - inset, cx + inset, cy + inset)
        markPaint.strokeWidth = 2.5f * density
        markPaint.alpha = 220
        val start = if (still) -90f else (t % SPIN_MS) / SPIN_MS.toFloat() * 360f
        canvas.drawArc(arcRect, start, 100f, false, markPaint)
    }

    private fun drawTick(canvas: Canvas, cx: Float, cy: Float, r: Float, t: Long, still: Boolean) {
        tickPath.reset()
        tickPath.moveTo(cx - 0.34f * r, cy + 0.02f * r)
        tickPath.lineTo(cx - 0.1f * r, cy + 0.26f * r)
        tickPath.lineTo(cx + 0.36f * r, cy - 0.24f * r)
        markPaint.strokeWidth = 3f * density
        markPaint.alpha = 255
        val progress = if (still) 1f else (t / TICK_MS.toFloat()).coerceIn(0f, 1f)
        if (progress >= 1f) {
            canvas.drawPath(tickPath, markPaint)
        } else {
            tickMeasure.setPath(tickPath, false)
            tickPart.reset()
            tickMeasure.getSegment(0f, tickMeasure.length * progress, tickPart, true)
            canvas.drawPath(tickPart, markPaint)
        }
    }

    /** "Copied": two overlapping sheets, for the clipboard-only fallback. */
    private fun drawCopied(canvas: Canvas, cx: Float, cy: Float, r: Float) {
        markPaint.strokeWidth = 2f * density
        markPaint.alpha = 255
        val w = r * 0.34f
        val h = r * 0.44f
        val rad = 2.5f * density
        arcRect.set(cx - w - r * 0.08f, cy - h - r * 0.08f, cx + w - r * 0.08f, cy + h - r * 0.08f)
        canvas.drawRoundRect(arcRect, rad, rad, markPaint)
        arcRect.offset(r * 0.18f, r * 0.18f)
        canvas.drawRoundRect(arcRect, rad, rad, markPaint)
    }

    private fun drawBang(canvas: Canvas, cx: Float, cy: Float, r: Float) {
        markPaint.strokeWidth = 3f * density
        markPaint.alpha = 255
        canvas.drawLine(cx, cy - 0.34f * r, cx, cy + 0.1f * r, markPaint)
        canvas.drawCircle(cx, cy + 0.3f * r, 1.9f * density, dotPaint)
    }
}
