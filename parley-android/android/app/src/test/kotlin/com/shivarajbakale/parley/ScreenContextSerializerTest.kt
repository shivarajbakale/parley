package com.shivarajbakale.parley

import com.shivarajbakale.parley.ScreenContextSerializer.Display
import com.shivarajbakale.parley.ScreenContextSerializer.SourceNode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The serializer is subtraction, so almost every test here is a claim about
 * what a person would *not* have seen: an invisible row, an echo of a label
 * four levels up, a password, a decorative icon, a node scrolled half off the
 * bottom. Each of those is a token the model would otherwise spend.
 */
class ScreenContextSerializerTest {

    private val phone = Display(1080, 2400)

    // --- a small DSL, because a screen-shaped fixture reads better than nesting ---

    private fun node(
        path: String,
        cls: String = "android.widget.TextView",
        text: String? = null,
        desc: String? = null,
        top: Int = 0,
        left: Int = 0,
        w: Int = 1080,
        h: Int = 100,
        visible: Boolean = true,
        password: Boolean = false,
        editable: Boolean = false,
        clickable: Boolean = false,
        checkable: Boolean = false,
        checked: Boolean? = null,
        scrollable: Boolean = false,
        focused: Boolean = false,
        children: List<SourceNode> = emptyList(),
    ) = SourceNode(
        path = path, className = cls, text = text, contentDescription = desc,
        left = left, top = top, right = left + w, bottom = top + h,
        isVisibleToUser = visible, isPassword = password, isEditable = editable,
        isClickable = clickable, isCheckable = checkable, isChecked = checked,
        isScrollable = scrollable, isFocused = focused, children = children,
    )

    private fun root(children: List<SourceNode>, cls: String = "android.widget.FrameLayout") =
        node("0", cls = cls, h = 2400, children = children)

    private fun serialize(tree: SourceNode, budget: Int = 4000, title: String? = null) =
        ScreenContextSerializer.serialize(
            root = tree, display = phone, packageName = "com.example.app",
            windowTitle = title, budgetChars = budget,
        )

    // --- pruning -------------------------------------------------------------

    @Test fun `an invisible subtree goes whole, not row by row`() {
        val tree = root(listOf(
            node("0/0", text = "July invoice"),
            node("0/1", cls = "android.widget.LinearLayout", visible = false, h = 400, children = listOf(
                node("0/1/0", text = "Secret heading"),
                node("0/1/1", text = "Secret body", h = 300),
            )),
        ))
        val labels = serialize(tree).nodes.map { it.label }
        assertEquals(listOf("July invoice"), labels)
    }

    @Test fun `a node scrolled half off the bottom is not visible`() {
        val tree = root(listOf(
            node("0/0", text = "Fully in view", top = 100),
            node("0/1", text = "Half off the bottom", top = 2300, h = 400),
        ))
        assertEquals(listOf("Fully in view"), serialize(tree).nodes.map { it.label })
    }

    @Test fun `a sliver of a node is not visible, a mostly-visible one is`() {
        val tree = root(listOf(
            node("0/0", text = "Mostly below the fold", top = 2300, h = 1000),  // 100 of 1000
            node("0/1", text = "Ninety percent", top = 2300, h = 110),           // 100 of 110
        ))
        val labels = serialize(tree).nodes.map { it.label }
        assertEquals(listOf("Ninety percent"), labels)
    }

    @Test fun `an unlabelled container is not a node a person could read`() {
        val tree = root(listOf(
            node("0/0", cls = "android.widget.LinearLayout", h = 500),
        ))
        assertTrue(serialize(tree).nodes.isEmpty())
    }

    @Test fun `a content description is kept when there is no text`() {
        val tree = root(listOf(node("0/0", cls = "android.widget.ImageView", desc = "Back")))
        val kept = serialize(tree).nodes.single()
        assertEquals("Back", kept.label)
        assertEquals("image", kept.role)
    }

    @Test fun `text wins over a content description`() {
        val tree = root(listOf(node("0/0", text = "Save", desc = "floppy disk icon")))
        assertEquals("Save", serialize(tree).nodes.single().label)
    }

    // --- the one redaction that is true of every app ------------------------

    @Test fun `a password goes, and so does anything nested inside it`() {
        val tree = root(listOf(
            node("0/0", text = "Email", top = 100),
            node("0/1", cls = "android.widget.LinearLayout", top = 200, h = 200, children = listOf(
                node("0/1/0", text = "Secret", password = true, top = 200, children = listOf(
                    node("0/1/0/0", text = "A confirmation of it", top = 200),
                )),
            )),
        ))
        val rendered = serialize(tree).render()
        assertTrue(rendered.contains("Email"))
        assertFalse("the password leaked", rendered.contains("Secret"))
        assertFalse("nor did anything nested in it", rendered.contains("A confirmation"))
    }

    @Test fun `a password's siblings survive, because a hint is not a secret`() {
        // Dropping every sibling of a password field would take out the form
        // around it, which is a far larger loss than "at least 8 characters"
        // is a disclosure.
        val tree = root(listOf(
            node("0/1", cls = "android.widget.LinearLayout", top = 200, h = 200, children = listOf(
                node("0/1/0", text = "Password", password = true, top = 200),
                node("0/1/1", text = "At least 8 characters", top = 260),
            )),
        ))
        val labels = serialize(tree).nodes.map { it.label }
        assertEquals(listOf("At least 8 characters"), labels)
    }

    // --- dedupe: the label that repeats at four levels ----------------------

    @Test fun `a list row keeps its label once, at the leaf that holds it`() {
        val row = node("0/0", cls = "android.widget.LinearLayout", top = 100, h = 200, children = listOf(
            node("0/0/0", text = "July invoice", top = 100),
            node("0/0/1", text = "$1,240.00", left = 600, top = 100),
        ))
        val tree = root(listOf(
            node("0", cls = "android.widget.LinearLayout", top = 100, h = 200, text = "July invoice", children = listOf(row)),
        ))
        val labels = serialize(tree).nodes.map { it.label }
        assertEquals(1, labels.count { it == "July invoice" })
    }

    @Test fun `dedupe keeps both when the row itself is clickable`() {
        val row = node("0/0", cls = "android.widget.LinearLayout", top = 100, h = 200, clickable = true, text = "July invoice", children = listOf(
            node("0/0/0", text = "July invoice", top = 100),
        ))
        val labels = serialize(root(listOf(row))).nodes.map { it.label }
        assertEquals(2, labels.count { it == "July invoice" })
    }

    // --- ordering: it should read the way a person reads ---------------------

    @Test fun `nodes come out in reading order, not tree order`() {
        val tree = root(listOf(
            node("0/0", text = "Third", top = 900),
            node("0/1", text = "First", top = 100),
            node("0/2", text = "Second", top = 500),
        ))
        assertEquals(listOf("First", "Second", "Third"), serialize(tree).nodes.map { it.label })
    }

    @Test fun `same row is left to right`() {
        val tree = root(listOf(
            node("0/0", text = "Right", left = 600, w = 400, top = 100),
            node("0/1", text = "Left", left = 40, w = 400, top = 100),
        ))
        assertEquals(listOf("Left", "Right"), serialize(tree).nodes.map { it.label })
    }

    // --- ids: the only handle a plan may use --------------------------------

    @Test fun `ids are indexes into the kept list, and follow reading order`() {
        val tree = root(listOf(
            node("0/0", text = "Later", top = 900),
            node("0/1", text = "Earlier", top = 100),
        ))
        val nodes = serialize(tree).nodes
        assertEquals("Earlier", nodes[0].label)
        assertEquals(0, nodes[0].id)
        assertEquals("Later", nodes[1].label)
        assertEquals(1, nodes[1].id)
    }

    @Test fun `a path is carried so a node can be found again next turn`() {
        val tree = root(listOf(node("0/0/3", text = "Pay now", clickable = true)))
        val kept = serialize(tree).nodes.single()
        assertEquals("0/0/3", kept.path)
        assertTrue(kept.actionable)
    }

    // --- the budget: subtraction, in the order a person least misses ---------

    @Test fun `a small screen is not truncated`() {
        val tree = root(listOf(node("0/0", text = "Short", top = 100)))
        val ctx = serialize(tree)
        assertFalse(ctx.truncated)
        assertEquals(0, ctx.droppedNodes)
        assertEquals(ctx.render().length, ctx.charCount)
    }

    @Test fun `containers go before labels when over budget`() {
        val tree = root(listOf(
            node("0/0", cls = "android.widget.LinearLayout", top = 100, h = 200, children = listOf(
                node("0/0/0", cls = "android.widget.ImageView", desc = "attachment", top = 100),
                node("0/0/1", text = "A meaningful sentence that a person would want to read", top = 140),
            )),
        ))
        val ctx = serialize(tree, budget = 120)
        assertTrue(ctx.nodes.any { it.label.startsWith("A meaningful sentence") })
    }

    @Test fun `a long document is cut and the cut is declared`() {
        val long = "x".repeat(600)
        val tree = root(listOf(node("0/0", text = long, top = 100)))
        val ctx = serialize(tree, budget = 300)
        assertTrue("the label was cut", ctx.nodes.single().label.endsWith("…"))
        assertTrue(ctx.nodes.single().label.length <= ScreenContextSerializer.MAX_LABEL_CHARS + 1)
        assertTrue("and the answer is from part of a screen", ctx.truncated)
    }

    @Test fun `nodes are given up from the bottom of the screen last`() {
        val tree = root(listOf(
            node("0/0", text = "Top " + "a".repeat(200), top = 100),
            node("0/1", text = "Mid " + "b".repeat(200), top = 1000),
            node("0/2", text = "Bottom " + "c".repeat(200), top = 2000),
        ))
        val ctx = serialize(tree, budget = 500)
        val labels = ctx.nodes.map { it.label }
        assertTrue("the top of the screen survives", labels.any { it.startsWith("Top") })
        assertFalse("the bottom is what goes", labels.any { it.startsWith("Bottom") })
        assertTrue(ctx.truncated)
    }

    @Test fun `a tree that never fits still returns the top of the screen`() {
        val tree = root(listOf(
            node("0/0", text = "Only thing here", top = 100),
        ))
        val ctx = serialize(tree, budget = 5)
        assertEquals(1, ctx.nodes.size)
        assertTrue(ctx.truncated)
    }

    @Test fun `an empty screen says so rather than rendering nothing`() {
        assertEquals("(nothing readable on screen)", serialize(root(emptyList())).render())
    }

    // --- what the model is actually handed ----------------------------------

    @Test fun `a render names the id, the role and the label, so a plan can be checked`() {
        val tree = root(listOf(
            node("0/0", cls = "android.widget.Button", text = "Pay now", clickable = true, top = 100),
        ))
        val line = serialize(tree).render().lines().single()
        assertEquals("[0] button \"Pay now\"", line)
    }

    @Test fun `a field renders as a field, and says when it is focused`() {
        val tree = root(listOf(
            node("0/0", cls = "android.widget.EditText", text = "me@example.com", editable = true, focused = true, top = 100),
        ))
        assertEquals("[0] field \"me@example.com\" field focused", serialize(tree).render().lines().single())
    }

    @Test fun `a checkbox renders its state, which is the question half the time`() {
        val tree = root(listOf(
            node("0/0", cls = "android.widget.CheckBox", text = "Remember me", checkable = true, checked = false, top = 100),
        ))
        assertEquals("[0] checkbox \"Remember me\" unchecked", serialize(tree).render().lines().single())
    }

    @Test fun `a scrollable list is marked, because scrolling is a legal action`() {
        val tree = root(listOf(
            node("0/0", cls = "androidx.recyclerview.widget.RecyclerView", scrollable = true, top = 100, h = 500),
        ))
        val ctx = serialize(tree)
        val kept = ctx.nodes.single()
        assertEquals("list", kept.role)
        assertTrue(kept.scrollable)
        assertTrue(ctx.render().contains("scrollable"))
    }

    // --- visibleFraction, stated once ---------------------------------------

    @Test fun `visible fraction is the clipped share of the node`() {
        assertEquals(1f, ScreenContextSerializer.visibleFraction(node("0", top = 100, h = 100), phone), 0.001f)
        assertEquals(0.5f, ScreenContextSerializer.visibleFraction(node("0", top = -50, h = 100), phone), 0.001f)
        assertEquals(0f, ScreenContextSerializer.visibleFraction(node("0", top = 5000, h = 100), phone), 0.001f)
    }

    @Test fun `a zero-area node is invisible rather than dividing by zero`() {
        assertEquals(0f, ScreenContextSerializer.visibleFraction(node("0", w = 0, h = 0), phone), 0.001f)
    }
}
