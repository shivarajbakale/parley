package com.shivarajbakale.parley

/**
 * A node tree, turned into something a model can read.
 *
 * ## Why this exists
 *
 * `rootInActiveWindow` returns the truth about a screen — real text, real
 * bounds, real class names — which is why Parley can read a screen at all
 * where a screenshot tool can only guess. It also returns a tree that is deep,
 * duplicated, and mostly invisible plumbing, and that tree is a bad prompt: it
 * costs tokens, it confuses the model with structure a person never saw, and
 * it spends its budget on `ViewGroup`s with no text in them.
 *
 * So the work of this file is subtraction. Everything it keeps is something a
 * person could have read or a step could act on; everything else is dropped
 * and the drop is *counted*, because an agent that silently answered from half
 * a screen is worse than one that declines.
 *
 * ## No Android types, on purpose
 *
 * Every Android import here would need Robolectric to exercise, and the edges
 * that matter — a node scrolled half off the bottom, a list row that repeats
 * its label at four nesting levels, a tree that overruns the budget — are not
 * Android's behaviour, they are *this* file's behaviour. [SourceNode] is
 * therefore a plain tree, and the adapter that walks a real
 * `AccessibilityNodeInfo` into it is a separate, thin concern (see
 * `AccessibilityTreeSource`). Tests build trees directly.
 *
 * ## What this does not do
 *
 * It does not decide what may be read. Which apps are allowed is
 * `AgentPolicy`'s business, and a per-app rule like "never read the address
 * bar" belongs there too, where it can be configured. What *is* handled here
 * is the one redaction that is true of every app: a password field goes
 * nowhere, along with the subtree it lives in.
 */
object ScreenContextSerializer {

    /** Characters of serialised screen per turn unless the user says otherwise. */
    const val DEFAULT_BUDGET_CHARS = 4000

    /** A label past this is a document, not a label; it is cut and marked. */
    const val MAX_LABEL_CHARS = 200

    /** Below this share of a node on screen, a person would not call it visible. */
    const val MIN_VISIBLE_FRACTION = 0.5f

    /** Under this, a label is dropped before a meaningful one when over budget. */
    private const val MIN_LABEL_CHARS = 24

    // --- the input -----------------------------------------------------------

    /**
     * One node, as the accessibility layer sees it. Deliberately a data class
     * with no framework ancestry: the test suite builds these, and the real
     * adapter fills the same fields.
     */
    data class SourceNode(
        /** Slash-joined child indices from the root, e.g. `0/2/1`. */
        val path: String,
        val className: String,
        val text: String? = null,
        val contentDescription: String? = null,
        val left: Int = 0,
        val top: Int = 0,
        val right: Int = 0,
        val bottom: Int = 0,
        val isVisibleToUser: Boolean = true,
        val isPassword: Boolean = false,
        val isEditable: Boolean = false,
        val isClickable: Boolean = false,
        val isCheckable: Boolean = false,
        val isChecked: Boolean? = null,
        val isScrollable: Boolean = false,
        val isFocused: Boolean = false,
        val children: List<SourceNode> = emptyList(),
    )

    /** The display, for clipping a node that hangs off the edge. */
    data class Display(val width: Int, val height: Int)

    // --- the output ----------------------------------------------------------

    data class Bounds(val left: Int, val top: Int, val right: Int, val bottom: Int)

    /**
     * A node worth sending. [id] is its index in [ScreenContext.nodes] and is
     * the only handle a plan may use — but only for the turn it was built in,
     * which is exactly why it is re-derivable from [path].
     */
    data class ScreenNode(
        val id: Int,
        val path: String,
        val role: String,
        val label: String,
        val bounds: Bounds,
        val visibleFraction: Float,
        val className: String,
        val actionable: Boolean,
        val editable: Boolean = false,
        val scrollable: Boolean = false,
        val checked: Boolean? = null,
        val focused: Boolean = false,
    )

    data class ScreenContext(
        val packageName: String,
        val windowTitle: String?,
        val nodes: List<ScreenNode>,
        val charCount: Int,
        val truncated: Boolean,
        val droppedNodes: Int,
    ) {
        /**
         * The text that actually leaves the phone: one line per node, id first
         * so a plan can refer to it and a reader can check it.
         */
        fun render(): String =
            if (nodes.isEmpty()) {
                "(nothing readable on screen)"
            } else {
                buildString {
                    nodes.forEach { n ->
                        append('[').append(n.id).append("] ").append(n.role)
                        if (n.label.isNotEmpty()) append(" \"").append(n.label).append('"')
                        if (n.editable) append(" field")
                        if (n.scrollable) append(" scrollable")
                        n.checked?.let { append(if (it) " checked" else " unchecked") }
                        if (n.focused) append(" focused")
                        append('\n')
                    }
                }.trimEnd()
            }
    }

    // --- roles ---------------------------------------------------------------

    /** A node is only actionable if its class carries something a step may use. */
    private fun roleOf(className: String): String = when {
        className.contains("EditText") || className.contains("AutoCompleteTextView") -> "field"
        className.contains("Button") || className.contains("ImageButton") -> "button"
        className.contains("CheckBox") || className.contains("Switch") ||
            className.contains("ToggleButton") || className.contains("RadioButton") -> "checkbox"
        className.contains("Image") -> "image"
        className.contains("ScrollView") || className.contains("RecyclerView") ||
            className.contains("ListView") -> "list"
        className.contains("TextView") -> "text"
        className.contains("ViewGroup") || className.contains("FrameLayout") ||
            className.contains("LinearLayout") || className.contains("RelativeLayout") -> "container"
        else -> "node"
    }

    private fun isActionable(n: SourceNode) =
        n.isClickable || n.isEditable || n.isCheckable || n.isScrollable

    /** What a person would have read: the text, or the description if there is no text. */
    private fun labelOf(n: SourceNode): String =
        (n.text?.trim()?.takeIf { it.isNotEmpty() } ?: n.contentDescription?.trim()).orEmpty()

    // --- the pipeline --------------------------------------------------------

    fun serialize(
        root: SourceNode,
        display: Display,
        packageName: String,
        windowTitle: String? = null,
        budgetChars: Int = DEFAULT_BUDGET_CHARS,
    ): ScreenContext {
        val kept = prune(root, display)
        val ordered = kept.sortedWith(compareBy({ it.top }, { it.left }))
        val full = render(ordered, display, packageName, windowTitle, 0)
        if (full.charCount <= budgetChars) return full

        // Over budget, in the order a person would least miss things: structural
        // rows go first, then short decorative labels, then long text is cut, and
        // only then is anything dropped from the bottom of the screen.
        //
        // No pass may empty a screen that had something on it. An agent that
        // answers from nothing is worse than one that answers from too much, so
        // a reduction that would leave nothing is declined, not taken.
        var surviving = ordered

        fun attempt(next: List<SourceNode>, truncated: Boolean = false): ScreenContext? {
            if (next.isEmpty() && surviving.isNotEmpty()) return null
            surviving = next
            val out = render(surviving, display, packageName, windowTitle, 0)
            if (out.charCount > budgetChars) return null
            return out.copy(droppedNodes = kept.size - surviving.size, truncated = truncated)
        }

        attempt(surviving.filterNot { !isActionable(it) && roleOf(it.className) in STRUCTURAL_ROLES })
            ?.let { return it }

        attempt(surviving.filterNot { !isActionable(it) && labelOf(it).length < MIN_LABEL_CHARS })
            ?.let { return it }

        val cut = surviving.any { labelOf(it).length > MAX_LABEL_CHARS }
        attempt(
            surviving.map {
                if (labelOf(it).length > MAX_LABEL_CHARS) {
                    it.copy(text = labelOf(it).take(MAX_LABEL_CHARS) + "…", contentDescription = null)
                } else {
                    it
                }
            },
            truncated = cut,
        )?.let { return it }

        val fitted = fitFromTop(surviving, display, packageName, windowTitle, budgetChars)
        return render(fitted, display, packageName, windowTitle, kept.size - fitted.size)
            .copy(truncated = true)
    }

    /** Rows that describe layout rather than content. */
    private val STRUCTURAL_ROLES = setOf("container", "node", "image")

    /**
     * A password field takes its **descendants** with it. Not its siblings:
     * a container's other children are often the form's real content, and a
     * hint like "at least 8 characters" leaks nothing — dropping every sibling
     * of a password would take out the form around it.
     */
    private fun prune(root: SourceNode, display: Display): List<SourceNode> {
        val out = mutableListOf<SourceNode>()

        fun walk(node: SourceNode) {
            if (!node.isVisibleToUser) return
            if (node.isPassword) return
            val fraction = visibleFraction(node, display)
            if (fraction < MIN_VISIBLE_FRACTION) return

            val label = labelOf(node)
            val role = roleOf(node.className)
            val structural = role in STRUCTURAL_ROLES && !isActionable(node)

            // A structural row that adds nothing is not a row; a node that
            // carries text, an action, or a check is kept even if its parent
            // is a plain container.
            if (label.isNotEmpty() || isActionable(node) || node.isFocused || !structural) {
                out += node
            }
            node.children.forEach(::walk)
        }

        walk(root)

        // Dedupe: a list row repeats its label at every level above the leaf
        // that actually holds it. Keep the deepest and drop the echoes, or the
        // model sees "July invoice" six times and spends its budget on it.
        val echoPaths = out.groupBy { labelOf(it).takeIf(String::isNotEmpty) }
            .filterValues { it.size > 1 }
            .values
            .flatten()
            .filter { n -> !isActionable(n) && n.children.isNotEmpty() && out.any { c -> c.path.startsWith("${n.path}/") && labelOf(c) == labelOf(n) } }
            .map { it.path }
            .toSet()

        return out.filterNot { it.path in echoPaths }
    }

    /** Share of a node that is both on screen and on the display. */
    fun visibleFraction(node: SourceNode, display: Display): Float {
        val area = (node.right - node.left).toLong() * (node.bottom - node.top).toLong()
        if (area <= 0L) return 0f
        val l = maxOf(node.left, 0)
        val t = maxOf(node.top, 0)
        val r = minOf(node.right, display.width)
        val b = minOf(node.bottom, display.height)
        if (r <= l || b <= t) return 0f
        val onScreen = (r - l).toLong() * (b - t).toLong()
        return (onScreen.toDouble() / area.toDouble()).toFloat()
    }

    private fun render(
        nodes: List<SourceNode>,
        display: Display,
        packageName: String,
        windowTitle: String?,
        dropped: Int,
    ): ScreenContext {
        val converted = nodes.mapIndexed { i, n ->
            ScreenNode(
                id = i,
                path = n.path,
                role = roleOf(n.className),
                label = labelOf(n),
                bounds = Bounds(n.left, n.top, n.right, n.bottom),
                visibleFraction = visibleFraction(n, display),
                className = n.className,
                actionable = isActionable(n),
                editable = n.isEditable,
                scrollable = n.isScrollable,
                checked = n.isChecked,
                focused = n.isFocused,
            )
        }
        val ctx = ScreenContext(packageName, windowTitle, converted, 0, false, dropped)
        return ctx.copy(charCount = ctx.render().length)
    }

    /** Takes nodes from the top until the next one would overrun. */
    private fun fitFromTop(
        nodes: List<SourceNode>,
        display: Display,
        packageName: String,
        windowTitle: String?,
        budget: Int,
    ): List<SourceNode> {
        val out = mutableListOf<SourceNode>()
        for (n in nodes) {
            val candidate = out + n
            val cost = render(candidate, display, packageName, windowTitle, 0).charCount
            if (cost > budget && out.isNotEmpty()) break
            out += n
        }
        // A budget too small for even one row still returns that row, for the
        // same reason the other passes decline to empty the screen.
        return if (out.isEmpty() && nodes.isNotEmpty()) listOf(nodes.first()) else out
    }
}
