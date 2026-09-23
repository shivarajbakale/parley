package com.shivarajbakale.parley

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.util.Log
import android.view.View

/**
 * What the pill says for a session state, or null when it should not show.
 * Pure, so the wording and the clock are unit-tested without a device.
 */
data class PillContent(val label: String, val timer: String?, val tone: Tone) {

    enum class Tone { DICTATION, EDIT, WARN }

    companion object {
        /** The timer turns to the warning tone this long before the recording cap. */
        const val WARN_BEFORE_CAP_MS = 10_000L

        fun forState(state: SessionState, nowMs: Long): PillContent? = when (state) {
            is SessionState.Listening -> {
                val elapsed = (nowMs - state.startedAt).coerceAtLeast(0)
                val nearCap = elapsed >= Session.MAX_RECORDING_MS - WARN_BEFORE_CAP_MS
                PillContent(
                    label = if (state.mode == SessionMode.EDIT) "Editing" else "Listening",
                    timer = clock(elapsed),
                    tone = when {
                        nearCap -> Tone.WARN
                        state.mode == SessionMode.EDIT -> Tone.EDIT
                        else -> Tone.DICTATION
                    },
                )
            }
            is SessionState.Transcribing -> PillContent("Transcribing", null, toneOf(state.mode))
            SessionState.Rewriting -> PillContent("Rewriting", null, Tone.EDIT)
            else -> null
        }

        /** Whole seconds, as `m:ss`. */
        fun clock(elapsedMs: Long): String {
            val s = elapsedMs / 1000
            return "${s / 60}:${(s % 60).toString().padStart(2, '0')}"
        }

        private fun toneOf(mode: SessionMode) = if (mode == SessionMode.EDIT) Tone.EDIT else Tone.DICTATION
    }
}

/**
 * The small glass pill beside the orb: a mode dot, a label, and while
 * listening a tabular `m:ss` timer. Drawn on a Canvas like the orb, in the
 * app's own faces (Nunito Sans, Nunito) read from the Flutter asset bundle.
 */
@SuppressLint("ViewConstructor")
class PillView(context: Context) : View(context) {

    companion object {
        private const val TAG = "ParleyPill"
        private const val FILL = 0xEB14141C.toInt()
        private const val BORDER = 0x1FFFFFFF
        private const val LABEL = 0xFFF1F1F6.toInt()
        private const val TIMER = 0xB3F1F1F6.toInt()
        private const val DOT_DICTATION = 0xFF8B8BFF.toInt()
        private const val DOT_EDIT = 0xFFF4B942.toInt()
        private const val DOT_WARN = 0xFFFF6E6E.toInt()

        private fun face(context: Context, file: String, fallback: Typeface): Typeface = try {
            Typeface.createFromAsset(context.assets, "flutter_assets/assets/fonts/$file")
        } catch (e: Exception) {
            Log.w(TAG, "font $file unavailable, using the system face")
            fallback
        }
    }

    private val density = resources.displayMetrics.density
    private val scaled = resources.displayMetrics.scaledDensity

    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = FILL }
    private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 1f * density
        color = BORDER
    }
    private val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = LABEL
        textSize = 13f * scaled
        typeface = face(context, "NunitoSans-600.ttf", Typeface.DEFAULT_BOLD)
    }
    private val timerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = TIMER
        textSize = 13f * scaled
        typeface = face(context, "Nunito-600.ttf", Typeface.MONOSPACE)
        fontFeatureSettings = "'tnum'"
    }
    private val rect = RectF()

    private val padX = 12f * density
    private val dotR = 3.5f * density
    private val gap = 8f * density
    private val pillH = 32f * density

    var content: PillContent? = null
        set(value) {
            if (field == value) return
            val resize = field?.label != value?.label || (field?.timer == null) != (value?.timer == null)
            field = value
            if (resize) requestLayout()
            invalidate()
        }

    /** Width reserves `0:00` for the timer so the pill never twitches as seconds tick. */
    private fun contentWidth(c: PillContent): Float {
        var w = dotR * 2 + gap + labelPaint.measureText(c.label)
        if (c.timer != null) w += gap + timerPaint.measureText(if (c.timer.length > 4) c.timer else "0:00")
        return w
    }

    fun measuredWidthFor(c: PillContent): Int = (contentWidth(c) + padX * 2).toInt() + 1
    fun pillHeight(): Int = pillH.toInt()

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val c = content
        setMeasuredDimension(if (c == null) 0 else measuredWidthFor(c), pillHeight())
    }

    override fun onDraw(canvas: Canvas) {
        val c = content ?: return
        val inset = borderPaint.strokeWidth / 2
        rect.set(inset, inset, width - inset, height - inset)
        val radius = rect.height() / 2
        canvas.drawRoundRect(rect, radius, radius, fillPaint)
        canvas.drawRoundRect(rect, radius, radius, borderPaint)

        val cy = height / 2f
        var x = padX
        dotPaint.color = when (c.tone) {
            PillContent.Tone.DICTATION -> DOT_DICTATION
            PillContent.Tone.EDIT -> DOT_EDIT
            PillContent.Tone.WARN -> DOT_WARN
        }
        canvas.drawCircle(x + dotR, cy, dotR, dotPaint)
        x += dotR * 2 + gap

        val baseline = cy - (labelPaint.descent() + labelPaint.ascent()) / 2
        canvas.drawText(c.label, x, baseline, labelPaint)
        x += labelPaint.measureText(c.label) + gap

        c.timer?.let {
            timerPaint.color = if (c.tone == PillContent.Tone.WARN) DOT_WARN else TIMER
            canvas.drawText(it, x, baseline, timerPaint)
        }
    }
}
