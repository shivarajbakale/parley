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
import android.graphics.Typeface
import android.os.SystemClock
import android.text.TextPaint
import android.text.TextUtils
import android.util.Log
import android.view.View
import kotlin.math.PI
import kotlin.math.ceil
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/**
 * The orb, drawn on a Canvas in the "Aurora" look, as one shape that morphs.
 *
 * At rest it is a small lit sphere whose highlight slowly drifts. Held, it
 * stretches into a capsule toward the middle of the screen with a live
 * waveform and a timer beside the sphere; an error stretches it the same way
 * to say what went wrong. Released, the capsule springs back into the sphere,
 * a colour sweep turns inside it while it works, and it pops green when the
 * text lands. Every size change runs on a [Spring], so motion that is
 * interrupted keeps its momentum instead of snapping.
 *
 * The view fills its overlay window. The window is only as wide as the shape
 * needs (plus [marginPx] of glow room), so it never blocks touches beside the
 * orb; the view asks its [host] to widen the window before the capsule grows
 * and to narrow it once the capsule has closed.
 */
@SuppressLint("ViewConstructor")
class OrbView(context: Context) : View(context) {

    enum class Visual { IDLE, LISTENING_DICTATION, LISTENING_EDIT, WORKING_DICTATION, WORKING_EDIT, DONE, COPIED, ERROR }

    interface Host {
        /** The window should now be [px] wide, keeping the sphere where it is. */
        fun onWidthNeeded(px: Int)
    }

    companion object {
        private const val TAG = "ParleyOrb"
        private const val MARGIN_DP = 10f

        private val STOPS = floatArrayOf(0f, 0.24f, 0.6f, 1f)
        private val INDIGO = intArrayOf(0xFFE4E4FF.toInt(), 0xFF9C9CFF.toInt(), 0xFF5B4FE0.toInt(), 0xFF231A6E.toInt())
        private val AMBER = intArrayOf(0xFFFFF4D6.toInt(), 0xFFF7C35C.toInt(), 0xFFD2811A.toInt(), 0xFF6B3706.toInt())
        private val GREEN = intArrayOf(0xFFDDFBEA.toInt(), 0xFF7FE3AE.toInt(), 0xFF2FA86A.toInt(), 0xFF0D4A2B.toInt())
        private val RED = intArrayOf(0xFFFFE0E0.toInt(), 0xFFFF9C9C.toInt(), 0xFFD94848.toInt(), 0xFF5E1414.toInt())

        private const val GLASS = 0xF014141C.toInt()
        private const val TEXT = 0xFFF1F1F6.toInt()
        private const val TIMER = 0xC7F1F1F6.toInt()
        private const val WARN = 0xFFFF6E6E.toInt()
        private const val WAVE_DICTATION = 0xFFA9A9FF.toInt()
        private const val WAVE_EDIT = 0xFFF7C35C.toInt()

        /** Highlight centre as a fraction of the sphere's bounding box. */
        private const val HIGHLIGHT_X = 0.34f
        private const val HIGHLIGHT_Y = 0.28f

        private const val WAVE_BARS = 18
        private const val WAVE_PUSH_MS = 70L
        private const val DRIFT_MS = 7_000L
        private const val DRIFT_DEGREES = 16f
        private const val SWEEP_MS = 1_100L
        private const val TICK_MS = 260L
        private const val POP_MS = 140L
        private const val SHAKE_MS = 450L
        private const val FADE_MS = 250L
        private const val IDLE_FRAME_MS = 16L
        /** Finger travel toward the middle that arms a cancel. */
        private const val CANCEL_DP = 96f
        /** Past the capsule's end the sphere only stretches this much further. */
        private const val OVERPULL_DP = 12f
        private const val DISCARD_FADE_MS = 480L
        /** The discarded sphere shrinks away where it was let go... */
        private const val GHOST_MS = 220L
        /** ...then a fresh one pops in at home from this scale. */
        private const val POP_FROM = 0.35f
        private const val GLASS_CANCEL = 0xF0321218.toInt()
        private const val HINT = 0xB3F1F1F6.toInt()
        /** Working lights: phase offset in turns, radius in sphere radii, alpha. */
        private val LIGHTS = listOf(Triple(0f, 0.62f, 255), Triple(0.5f, 0.42f, 150))

        private fun face(context: Context, file: String, fallback: Typeface): Typeface = try {
            Typeface.createFromAsset(context.assets, "flutter_assets/assets/fonts/$file")
        } catch (e: Exception) {
            Log.w(TAG, "font $file unavailable, using the system face")
            fallback
        }
    }

    var host: Host? = null

    private val density = resources.displayMetrics.density
    private fun dp(v: Float) = v * density

    /** Glow room on every side of the shape. */
    val marginPx = dp(MARGIN_DP)

    var diameterPx: Float = dp(44f)
        set(value) {
            field = value
            requestedWidth = 0
            requestWidth(widthFor(max(extra.target, extra.value)))
            invalidate()
        }

    /** Which end of the window the sphere sits at; the capsule grows away from it. */
    var dockRight = true
        set(value) { if (field != value) { field = value; invalidate() } }

    /** The widest the window may get, so a long error still fits the screen. */
    var maxWidthPx = Int.MAX_VALUE

    /** A finger is down: squash. */
    var squashed = false
        set(value) { if (field != value) { field = value; invalidate() } }

    /** Being dragged: lift. */
    var lifted = false
        set(value) { if (field != value) { field = value; invalidate() } }

    /** Tucked into the edge: dim. */
    var dimmed = false
        set(value) { if (field != value) { field = value; invalidate() } }

    var visual: Visual = Visual.IDLE
        set(value) {
            if (field == value) return
            val now = SystemClock.uptimeMillis()
            val stops = displayedStops(now)
            field = value
            visualSince = now
            fadeFrom = stops
            fadeTo = paletteFor(value)
            fadeStart = now
            // Right after a discard, keep the slow drain rather than a quick fade.
            fadeMs = if (now - discardAt < 200) DISCARD_FADE_MS else FADE_MS
            if (value == Visual.LISTENING_DICTATION || value == Visual.LISTENING_EDIT) wave.clear()
            invalidate()
        }

    /**
     * How far the finger has slid toward the middle while holding, in px.
     * Everything blends toward red as it grows; at [CANCEL_DP] it is armed.
     */
    var cancelPullPx = 0f
        set(value) {
            val v = value.coerceAtLeast(0f)
            if (field == v) return
            field = v
            invalidate()
        }

    /** Letting go now would throw the recording away. */
    val cancelArmed: Boolean get() = cancelPullPx > 0f && cancelPullPx >= armDistance()

    /** Finger travel that arms a cancel: [CANCEL_DP], or less on a short capsule. */
    private fun armDistance(): Float = min(dp(CANCEL_DP), lastOpenExtra * 0.7f).coerceAtLeast(dp(24f))

    /**
     * The recording was thrown away: shake, and let the red drain back to the
     * resting colour instead of snapping.
     */
    fun discard() {
        val now = SystemClock.uptimeMillis()
        val shown = displayedStops(now)
        discardAt = now
        ghostOffset = slide.value
        ghostStops = shown
        popPending = true
        cancelPullPx = 0f
        cancel.target = 0f
        cancel.snap()
        slide.target = 0f
        slide.snap() // the sphere does not travel home; a new one appears there
        fadeFrom = shown
        fadeStart = now
        fadeMs = DISCARD_FADE_MS
        invalidate()
    }

    var content: PillContent? = null
        set(value) {
            if (field == value) return
            field = value
            val target = extraFor(value)
            extra.target = target
            if (target > 0f) lastOpenExtra = target
            // Widen first, then grow into the room.
            if (widthFor(target) > requestedWidth) requestWidth(widthFor(target))
            invalidate()
        }

    // ---- motion state ---------------------------------------------------

    private val scale = Spring(1f, 700f, 0.5f)
    private val extra = Spring(0f, 420f, 0.82f)
    private val dim = Spring(1f, 260f, 1f)
    /** 0..1: how red things are, following the finger without its jitter. */
    private val cancel = Spring(0f, 900f, 1f)
    /** px the sphere has slid along the capsule. */
    private val slide = Spring(0f, 900f, 0.75f)
    private var discardAt = 0L
    private var ghostOffset = 0f
    private var ghostStops = RED
    private var popPending = false
    private var fadeMs = FADE_MS
    private var lastOpenExtra = 1f
    private var requestedWidth = 0
    private var lastFrame = 0L

    private var visualSince = SystemClock.uptimeMillis()
    private var fadeFrom = INDIGO
    private var fadeTo = INDIGO
    private var fadeStart = 0L

    private var level = 0f
    private val wave = WaveHistory(WAVE_BARS)
    private var lastWavePush = 0L

    /** Mic RMS, 0..1. Smoothed so the shape follows speech, not every sample. */
    fun setLevel(rms: Float) {
        // Speech RMS is small, and a voice across the room smaller still: a square
        // root lifts quiet speech into view without pinning loud speech at the top.
        val target = kotlin.math.sqrt((rms * 4f).coerceIn(0f, 1f))
        level += (target - level) * 0.45f
    }

    fun compactWidth(): Int = widthFor(0f)
    fun windowHeight(): Int = ceil(diameterPx + 2 * marginPx).toInt()
    private fun widthFor(extraPx: Float): Int = min(ceil(diameterPx + extraPx + 2 * marginPx).toInt(), maxWidthPx)

    private fun requestWidth(px: Int) {
        if (px == requestedWidth) return
        requestedWidth = px
        host?.onWidthNeeded(px)
    }

    // ---- paints ---------------------------------------------------------

    private val shaderMatrix = Matrix()
    private val bodyShaders = HashMap<IntArray, Shader>()
    private val glowShaders = HashMap<Int, Shader>()
    private val bodyPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val rimPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dp(1f)
        color = Color.argb(46, 255, 255, 255)
    }
    private val glassPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = GLASS }
    private val edgePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dp(1f)
    }
    private val haloPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val barPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val lightPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    /** A soft white spot, unit radius, for the light that circles inside while working. */
    private val lightShader = RadialGradient(
        0f, 0f, 1f,
        intArrayOf(0xA6FFFFFF.toInt(), 0x40FFFFFF, 0x00FFFFFF),
        floatArrayOf(0f, 0.45f, 1f),
        Shader.TileMode.CLAMP,
    )
    private val markPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
        color = Color.WHITE
    }
    private val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
    private val labelPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        color = TEXT
        textSize = 13f * resources.displayMetrics.scaledDensity
        typeface = face(context, "NunitoSans-600.ttf", Typeface.DEFAULT_BOLD)
    }
    private val timerPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        textSize = 13f * resources.displayMetrics.scaledDensity
        typeface = face(context, "Nunito-600.ttf", Typeface.MONOSPACE)
        fontFeatureSettings = "'tnum'"
    }
    private val rect = RectF()
    private val tickPath = Path()
    private val tickPart = Path()
    private val tickMeasure = PathMeasure()
    private val clipCircle = Path()

    private val barW = dp(3f)
    private val barGap = dp(2.5f)
    private val orbGap = dp(9f)
    private val labelGap = dp(5f)
    private val waveGap = dp(10f)
    private val outerPad = dp(14f)
    private val wavesW = WAVE_BARS * barW + (WAVE_BARS - 1) * barGap

    /** Animator duration scale 0 is the system's reduce-motion switch. */
    private fun reduceMotion(): Boolean = !ValueAnimator.areAnimatorsEnabled()

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        setMeasuredDimension(MeasureSpec.getSize(widthMeasureSpec), MeasureSpec.getSize(heightMeasureSpec))
    }

    // ---- layout of the capsule's contents -------------------------------

    private fun textWidth(c: PillContent): Float {
        var w = 0f
        c.label?.let { w += labelPaint.measureText(it) }
        c.timer?.let {
            if (c.label != null) w += labelGap
            w += timerPaint.measureText(if (it.length > 4) it else "0:00")
        }
        return w
    }

    /** Room the capsule needs beyond the sphere for [c]. */
    private fun extraFor(c: PillContent?): Float {
        if (c == null) return 0f
        val budget = maxWidthPx - 2 * marginPx - diameterPx
        val content = if (c.timer != null) textWidth(c) + waveGap + wavesW else textWidth(c)
        return min(orbGap + content + outerPad, budget).coerceAtLeast(0f)
    }

    // ---- palette --------------------------------------------------------

    private fun paletteFor(v: Visual): IntArray = when (v) {
        Visual.IDLE, Visual.LISTENING_DICTATION, Visual.WORKING_DICTATION -> INDIGO
        Visual.LISTENING_EDIT, Visual.WORKING_EDIT -> AMBER
        Visual.DONE, Visual.COPIED -> GREEN
        Visual.ERROR -> RED
    }

    private fun fading(now: Long) = now - fadeStart < fadeMs && !reduceMotion()

    /** The stops right now: the target palette, or a fresh blend while crossfading. */
    private fun currentStops(now: Long): IntArray {
        if (!fading(now)) return fadeTo
        val t = (now - fadeStart) / fadeMs.toFloat()
        return IntArray(4) { lerpArgb(fadeFrom[it], fadeTo[it], t) }
    }

    /** [currentStops], pulled toward red by a slide-to-cancel in progress. */
    private fun displayedStops(now: Long): IntArray {
        val base = currentStops(now)
        val c = cancel.value.coerceIn(0f, 1f)
        if (c <= 0f) return base
        return IntArray(4) { lerpArgb(base[it], RED[it], c) }
    }

    /** Shaders are cached per palette; a blend mid-fade is built for its one frame. */
    private fun bodyShader(stops: IntArray, cacheable: Boolean): Shader {
        fun make(): Shader {
            // Highlight offset from the centre, in radii: box fraction * 2 - 1.
            val hx = HIGHLIGHT_X * 2 - 1
            val hy = HIGHLIGHT_Y * 2 - 1
            val reach = 1f + kotlin.math.sqrt(hx * hx + hy * hy)
            return RadialGradient(hx, hy, reach, stops, STOPS, Shader.TileMode.CLAMP)
        }
        return if (cacheable) bodyShaders.getOrPut(stops) { make() } else make()
    }

    private fun glowShader(color: Int, cacheable: Boolean): Shader {
        fun make(): Shader = RadialGradient(
            0f, 0f, 1f,
            intArrayOf(withAlpha(color, 120), withAlpha(color, 120), withAlpha(color, 36), withAlpha(color, 0)),
            floatArrayOf(0f, 0.62f, 0.8f, 1f),
            Shader.TileMode.CLAMP,
        )
        return if (cacheable) glowShaders.getOrPut(color) { make() } else make()
    }

    private fun withAlpha(color: Int, alpha: Int) =
        Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))

    // ---- drawing --------------------------------------------------------

    override fun onDraw(canvas: Canvas) {
        val now = SystemClock.uptimeMillis()
        val dt = if (lastFrame == 0L) 0f else (now - lastFrame).coerceIn(0, 48) / 1000f
        lastFrame = now
        val still = reduceMotion()
        val t = now - visualSince
        val listening = visual == Visual.LISTENING_DICTATION || visual == Visual.LISTENING_EDIT
        val working = visual == Visual.WORKING_DICTATION || visual == Visual.WORKING_EDIT

        // Targets.
        var s = when {
            lifted -> 1.08f
            squashed -> 0.92f
            else -> 1f
        }
        if ((visual == Visual.DONE || visual == Visual.COPIED) && t < POP_MS) s = 1.12f
        if (listening) s += level * 0.04f
        scale.target = s
        dim.target = if (dimmed) 0.55f else 1f
        // Slide to cancel: the sphere stays under the finger along the capsule
        // (stretching only a little past its end), and the colour follows.
        val pull = if (listening) cancelPullPx else 0f
        cancel.target = (pull / armDistance()).coerceIn(0f, 1f)
        val track = (extra.value - dp(4f)).coerceAtLeast(0f)
        slide.target = if (pull <= track) pull else track + dp(OVERPULL_DP) * (1f - exp(-(pull - track) / dp(40f)))
        val following = pull > 0f

        var moving = false
        if (still) {
            scale.snap(); extra.snap(); dim.snap(); cancel.snap(); slide.snap()
        } else {
            moving = scale.step(dt) or extra.step(dt) or dim.step(dt) or cancel.step(dt)
            // Under the finger: exactly where it is. Let go: spring home.
            if (following) slide.snap() else moving = slide.step(dt) or moving
        }
        // The capsule has closed: give the room back.
        if (extra.settled && extra.value == 0f && requestedWidth > compactWidth()) {
            post { if (extra.settled && extra.value == 0f) requestWidth(compactWidth()) }
        }

        if (listening && now - lastWavePush >= WAVE_PUSH_MS) {
            wave.push(level)
            lastWavePush = now
        }

        val fadingNow = fading(now)
        val stops = displayedStops(now)
        val c = cancel.value.coerceIn(0f, 1f)
        val r = diameterPx / 2f
        val cy = height / 2f
        val home = if (dockRight) width - marginPx - r else marginPx + r
        val cx = home + if (dockRight) -slide.value else slide.value

        var shake = 0f
        val shaking = visual == Visual.ERROR && !still && t < SHAKE_MS
        if (shaking) {
            val decay = exp(-3.0 * t / SHAKE_MS).toFloat()
            shake = sin(t / 1000f * 2 * PI.toFloat() * 11f) * dp(5f) * decay
        }

        // After a discard: the old sphere shrinks away where it was let go, and
        // only then does a fresh one pop in at home.
        val sinceDiscard = now - discardAt
        val ghosting = popPending && !still && sinceDiscard < GHOST_MS
        if (popPending && (still || sinceDiscard >= GHOST_MS)) {
            popPending = false
            if (!still) scale.jumpTo(POP_FROM)
        }

        canvas.save()
        canvas.translate(shake, 0f)
        canvas.scale(scale.value, scale.value, cx, cy)

        val ex = extra.value.coerceAtLeast(0f)
        if (ex > 0.5f) drawCapsule(canvas, home, cx, cy, r, ex, stops, c)
        if (ghosting) {
            canvas.restore()
            drawGhost(canvas, home + if (dockRight) -ghostOffset else ghostOffset, cy, r, sinceDiscard / GHOST_MS.toFloat())
            postInvalidateOnAnimation()
            return
        }
        drawSphere(canvas, cx, cy, r, stops, !fadingNow && c == 0f, now, still)
        if (c > 0.55f) drawCross(canvas, cx, cy, r, ((c - 0.55f) / 0.45f).coerceIn(0f, 1f))

        when (visual) {
            Visual.WORKING_DICTATION, Visual.WORKING_EDIT -> drawSweep(canvas, cx, cy, r, t, still)
            Visual.DONE -> drawTick(canvas, cx, cy, r, t, still)
            Visual.COPIED -> drawCopied(canvas, cx, cy, r)
            Visual.ERROR -> drawBang(canvas, cx, cy, r)
            else -> Unit
        }
        canvas.restore()

        val drifting = visual == Visual.IDLE && !dimmed && !still
        val ticking = (visual == Visual.DONE || visual == Visual.COPIED) && t < TICK_MS
        val continuous = listening || (working && !still) || fadingNow || shaking || ticking
        if (isAttachedToWindow) {
            when {
                moving || continuous -> postInvalidateOnAnimation()
                drifting -> postInvalidateDelayed(IDLE_FRAME_MS)
            }
        }
    }

    private fun drawSphere(canvas: Canvas, cx: Float, cy: Float, r: Float, stops: IntArray, cacheable: Boolean, now: Long, still: Boolean) {
        val idle = visual == Visual.IDLE
        val alpha = dim.value

        // Glow, tight to the sphere.
        val glowR = min(r * 1.38f, r + marginPx)
        shaderMatrix.setScale(glowR, glowR)
        shaderMatrix.postTranslate(cx, cy)
        glowPaint.shader = glowShader(stops[2], cacheable).also { it.setLocalMatrix(shaderMatrix) }
        glowPaint.alpha = ((if (idle) 120 else 230) * alpha).toInt()
        canvas.drawCircle(cx, cy, glowR, glowPaint)

        // Body, with the light slowly swinging round it at rest.
        val drift = if (idle && !dimmed && !still) {
            DRIFT_DEGREES * sin(2 * PI * (now % DRIFT_MS) / DRIFT_MS).toFloat()
        } else 0f
        shaderMatrix.setScale(r, r)
        shaderMatrix.postRotate(drift)
        shaderMatrix.postTranslate(cx, cy)
        bodyPaint.shader = bodyShader(stops, cacheable).also { it.setLocalMatrix(shaderMatrix) }
        bodyPaint.alpha = ((if (idle) 215 else 255) * alpha).toInt()
        canvas.drawCircle(cx, cy, r, bodyPaint)
        rimPaint.alpha = (46 * alpha).toInt()
        canvas.drawCircle(cx, cy, r - rimPaint.strokeWidth / 2, rimPaint)
    }

    private fun toneColor(c: PillContent?): Int = when (c?.tone) {
        PillContent.Tone.EDIT -> WAVE_EDIT
        PillContent.Tone.WARN -> WARN
        else -> WAVE_DICTATION
    }

    /**
     * [home] is where the sphere rests; [cx] is where it is now, slid toward
     * the middle during a slide-to-cancel. [c] is how far toward red (0..1).
     */
    private fun drawCapsule(canvas: Canvas, home: Float, cx: Float, cy: Float, r: Float, ex: Float, stops: IntArray, c: Float) {
        val w = diameterPx + ex
        if (dockRight) rect.set(home + r - w, cy - r, home + r, cy + r) else rect.set(home - r, cy - r, home - r + w, cy + r)

        // Soft halo in the mode colour, two layers deep.
        val halo = dp(5f)
        rect.inset(-halo, -halo)
        haloPaint.color = withAlpha(stops[2], 26)
        canvas.drawRoundRect(rect, r + halo, r + halo, haloPaint)
        rect.inset(halo / 2, halo / 2)
        haloPaint.color = withAlpha(stops[2], 30)
        canvas.drawRoundRect(rect, r + halo / 2, r + halo / 2, haloPaint)
        rect.inset(halo / 2, halo / 2)

        glassPaint.color = lerpArgb(GLASS, GLASS_CANCEL, c)
        canvas.drawRoundRect(rect, r, r, glassPaint)
        val content = this.content
        val edge = if (content == null) stops[1] else lerpArgb(toneColor(content), WARN, c)
        edgePaint.color = withAlpha(edge, (70 + 90 * c).toInt())
        canvas.drawRoundRect(rect, r, r, edgePaint)

        // Contents fade in over the end of the opening and out at the start of the close.
        if (content == null) return
        val open = (ex / lastOpenExtra.coerceAtLeast(1f)).coerceIn(0f, 1f)
        val shown = ((open - 0.45f) / 0.55f).coerceIn(0f, 1f)
        if (shown <= 0f) return

        canvas.save()
        canvas.clipRect(rect)
        val baseline = cy - (labelPaint.descent() + labelPaint.ascent()) / 2

        // Sliding to cancel: the waveform and timer give way to the hint.
        val hintA = shown * smooth(0.12f, 0.45f, c)
        val a = shown * (1f - smooth(0f, 0.35f, c))
        if (hintA > 0f) drawCancelHint(canvas, cx, baseline, r, c, shown)
        if (a <= 0f) {
            canvas.restore()
            return
        }
        val cc = content

        if (cc.timer == null) {
            // A message: beside the sphere, cut short if the screen is too narrow.
            val room = extraFor(cc) - orbGap - outerPad
            val message = TextUtils.ellipsize(cc.label ?: "", labelPaint, room, TextUtils.TruncateAt.END).toString()
            val lw = labelPaint.measureText(message)
            labelPaint.alpha = (255 * a).toInt()
            canvas.drawText(message, if (dockRight) cx - r - orbGap - lw else cx + r + orbGap, baseline, labelPaint)
            canvas.restore()
            return
        }

        // Listening: [label] timer beside the sphere, the waveform beyond it.
        val textW = textWidth(cc)
        val textLeft = if (dockRight) cx - r - orbGap - textW else cx + r + orbGap
        var x = textLeft
        cc.label?.let {
            labelPaint.alpha = (255 * a).toInt()
            canvas.drawText(it, x, baseline, labelPaint)
            x += labelPaint.measureText(it) + labelGap
        }
        timerPaint.color = if (cc.tone == PillContent.Tone.WARN) WARN else TIMER
        timerPaint.alpha = (Color.alpha(timerPaint.color) * a).toInt()
        canvas.drawText(cc.timer, x, baseline, timerPaint)

        // Newest bar nearest the text, older ones trailing off.
        barPaint.color = toneColor(cc)
        val minH = dp(3f)
        val maxH = diameterPx * 0.52f
        val rr = barW / 2
        for (age in 0 until WAVE_BARS) {
            val h = max(minH, wave[age] * maxH)
            val step = age * (barW + barGap)
            val left = if (dockRight) textLeft - waveGap - step - barW else textLeft + textW + waveGap + step
            barPaint.alpha = ((255 - age * 8) * a).toInt().coerceAtLeast(0)
            canvas.drawRoundRect(left, cy - h / 2, left + barW, cy + h / 2, rr, rr, barPaint)
        }
        canvas.restore()
    }

    private fun smooth(from: Float, to: Float, x: Float): Float {
        val t = ((x - from) / (to - from)).coerceIn(0f, 1f)
        return t * t * (3 - 2 * t)
    }

    /**
     * "‹ Slide to cancel" waits at the far end of the capsule and fades as the
     * sphere comes to it; once armed, "Cancel" shows in the room the sphere
     * has left behind. [rect] is the capsule.
     */
    private fun drawCancelHint(canvas: Canvas, cx: Float, baseline: Float, r: Float, c: Float, shown: Float) {
        val armed = cancelArmed
        val color = lerpArgb(HINT, WARN, c)

        val hint = if (dockRight) "‹  Slide to cancel" else "Slide to cancel  ›"
        val hw = labelPaint.measureText(hint)
        val hx = if (dockRight) rect.left + outerPad else rect.right - outerPad - hw
        val gap = if (dockRight) (cx - r) - (hx + hw) else hx - (cx + r)
        val near = smooth(0f, dp(28f), gap)
        val hintA = shown * smooth(0.08f, 0.35f, c) * near * (if (armed) 0f else 1f)
        if (hintA > 0f) {
            labelPaint.color = color
            labelPaint.alpha = (Color.alpha(color) * hintA).toInt()
            canvas.drawText(hint, hx, baseline, labelPaint)
        }

        if (armed) {
            val label = "Cancel"
            val lw = labelPaint.measureText(label)
            val lx = if (dockRight) cx + r + orbGap else cx - r - orbGap - lw
            labelPaint.color = WARN
            labelPaint.alpha = (255 * shown).toInt()
            canvas.drawText(label, lx, baseline, labelPaint)
        }
        labelPaint.color = TEXT
    }

    /** The thrown-away sphere, shrinking and fading where it was let go. [g] 0..1. */
    private fun drawGhost(canvas: Canvas, gx: Float, cy: Float, r: Float, g: Float) {
        val k = g * g // ease in: it lingers, then goes
        val gr = r * (1f - 0.75f * k)
        val a = 1f - k
        shaderMatrix.setScale(gr, gr)
        shaderMatrix.postTranslate(gx, cy)
        bodyPaint.shader = bodyShader(ghostStops, false).also { it.setLocalMatrix(shaderMatrix) }
        bodyPaint.alpha = (255 * a).toInt()
        canvas.drawCircle(gx, cy, gr, bodyPaint)
        drawCross(canvas, gx, cy, gr, a)
    }

    /** The ✕ that fades onto the sphere as a cancel arms. */
    private fun drawCross(canvas: Canvas, cx: Float, cy: Float, r: Float, alpha: Float) {
        markPaint.strokeWidth = dp(2.5f)
        markPaint.alpha = (255 * alpha).toInt()
        val k = r * 0.3f * (0.8f + 0.2f * alpha)
        canvas.drawLine(cx - k, cy - k, cx + k, cy + k, markPaint)
        canvas.drawLine(cx - k, cy + k, cx + k, cy - k, markPaint)
        markPaint.alpha = 255
    }

    /** Working: two soft lights chase each other round inside the sphere. */
    private fun drawSweep(canvas: Canvas, cx: Float, cy: Float, r: Float, t: Long, still: Boolean) {
        val turn = if (still) -0.25f else (t % SWEEP_MS) / SWEEP_MS.toFloat()
        canvas.save()
        clipCircle.reset()
        clipCircle.addCircle(cx, cy, r - dp(0.5f), Path.Direction.CW)
        canvas.clipPath(clipCircle)
        for ((offset, size, alpha) in LIGHTS) {
            val a = 2 * PI * (turn + offset)
            val lx = cx + kotlin.math.cos(a).toFloat() * r * 0.48f
            val ly = cy + sin(a).toFloat() * r * 0.48f
            val lr = r * size
            shaderMatrix.setScale(lr, lr)
            shaderMatrix.postTranslate(lx, ly)
            lightShader.setLocalMatrix(shaderMatrix)
            lightPaint.shader = lightShader
            lightPaint.alpha = alpha
            canvas.drawCircle(lx, ly, lr, lightPaint)
        }
        canvas.restore()
    }

    private fun drawTick(canvas: Canvas, cx: Float, cy: Float, r: Float, t: Long, still: Boolean) {
        tickPath.reset()
        tickPath.moveTo(cx - 0.34f * r, cy + 0.02f * r)
        tickPath.lineTo(cx - 0.1f * r, cy + 0.26f * r)
        tickPath.lineTo(cx + 0.36f * r, cy - 0.24f * r)
        markPaint.strokeWidth = dp(2.5f)
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
        markPaint.strokeWidth = dp(1.75f)
        markPaint.alpha = 255
        val w = r * 0.32f
        val h = r * 0.42f
        val rad = dp(2f)
        rect.set(cx - w - r * 0.08f, cy - h - r * 0.08f, cx + w - r * 0.08f, cy + h - r * 0.08f)
        canvas.drawRoundRect(rect, rad, rad, markPaint)
        rect.offset(r * 0.18f, r * 0.18f)
        canvas.drawRoundRect(rect, rad, rad, markPaint)
    }

    private fun drawBang(canvas: Canvas, cx: Float, cy: Float, r: Float) {
        markPaint.strokeWidth = dp(2.5f)
        markPaint.alpha = 255
        canvas.drawLine(cx, cy - 0.34f * r, cx, cy + 0.1f * r, markPaint)
        canvas.drawCircle(cx, cy + 0.32f * r, dp(1.6f), dotPaint)
    }
}
