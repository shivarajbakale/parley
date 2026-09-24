package com.shivarajbakale.parley

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TextSplicerTest {

    private fun insert(text: String?, start: Int, end: Int, dictated: String, hint: Boolean = false, lead: Boolean = true) =
        TextSplicer.insert(text, hint, start, end, dictated, lead)

    @Test fun `inserts into an empty field without a space`() {
        val s = insert("", 0, 0, "Hello there")
        assertEquals("Hello there", s.text)
        assertEquals(11, s.cursor)
    }

    @Test fun `hint text counts as empty`() {
        val s = insert("Type a message", 0, 0, "Hi", hint = true)
        assertEquals("Hi", s.text)
        assertEquals(2, s.cursor)
    }

    @Test fun `null text is empty`() {
        assertEquals("Hi", insert(null, -1, -1, "Hi").text)
    }

    @Test fun `appends with a leading space after a word`() {
        val s = insert("Hello", 5, 5, "world")
        assertEquals("Hello world", s.text)
        assertEquals(" world", s.inserted)
        assertEquals(11, s.cursor)
    }

    @Test fun `no leading space when the setting is off`() {
        assertEquals("Helloworld", insert("Hello", 5, 5, "world", lead = false).text)
    }

    @Test fun `no leading space after whitespace or an opening bracket`() {
        assertEquals("Hello world", insert("Hello ", 6, 6, "world").text)
        assertEquals("(world", insert("(", 1, 1, "world").text)
        assertEquals("a\nb", insert("a\n", 2, 2, "b").text)
    }

    @Test fun `no leading space before punctuation`() {
        assertEquals("Hello.", insert("Hello", 5, 5, ".").text)
        assertEquals("Hello, there", insert("Hello", 5, 5, ", there").text)
    }

    @Test fun `inserts in the middle at the cursor`() {
        val s = insert("Hello world", 5, 5, "big")
        assertEquals("Hello big world", s.text)
        assertEquals(9, s.cursor)
    }

    @Test fun `replaces the selection`() {
        val s = insert("Hello cruel world", 6, 11, "kind")
        assertEquals("Hello kind world", s.text)
        assertEquals(10, s.cursor)
        assertEquals(6, s.rangeStart)
        assertEquals(11, s.rangeEnd)
    }

    @Test fun `a reversed selection is swapped`() {
        assertEquals("Hello kind world", insert("Hello cruel world", 11, 6, "kind").text)
    }

    @Test fun `unknown selection means the end`() {
        assertEquals("Hello world", insert("Hello", -1, -1, "world").text)
    }

    @Test fun `out of range selection is clamped`() {
        assertEquals("Hello world", insert("Hello", 99, 120, "world").text)
    }

    @Test fun `never splits an emoji surrogate pair`() {
        val text = "a😀b" // a😀b
        // Cursor reported between the two halves of the emoji.
        assertEquals(3 to 3, TextSplicer.normalise(text, 2, 2))
        assertEquals("a\uD83D\uDE00xb", insert(text, 2, 2, "x", lead = false).text)
        // A selection ending inside the emoji widens to take all of it.
        assertEquals(0 to 3, TextSplicer.normalise(text, 0, 2))
        assertEquals("xb", insert(text, 0, 2, "x", lead = false).text)
        assertEquals(1 to 4, TextSplicer.normalise(text, 2, 4))
    }

    @Test fun `inserts after an emoji with a space`() {
        val text = "hi 😀"
        val s = insert(text, text.length, text.length, "yes")
        assertEquals("hi 😀 yes", s.text)
    }

    @Test fun `dictation containing emoji keeps the cursor after it`() {
        val s = insert("", 0, 0, "ok 👍")
        assertEquals(5, s.cursor)
    }

    @Test fun `edit replaces the selection when there is one`() {
        val s = TextSplicer.replace("one two three", false, 4, 7, "TWO")
        assertEquals("one TWO three", s.text)
        assertEquals(7, s.cursor)
        assertEquals("two", TextSplicer.editSource("one two three", false, 4, 7))
    }

    @Test fun `edit with no selection replaces everything`() {
        val s = TextSplicer.replace("one two", false, 3, 3, "Uno dos")
        assertEquals("Uno dos", s.text)
        assertEquals("one two", TextSplicer.editSource("one two", false, 3, 3))
    }

    @Test fun `edit on a hint-only field sees empty text`() {
        assertEquals("", TextSplicer.editSource("Search", true, 0, 0))
        assertEquals("new", TextSplicer.replace("Search", true, 0, 0, "new").text)
    }

    @Test fun `leading space rule`() {
        assertTrue(TextSplicer.needsLeadingSpace("word", "next"))
        assertFalse(TextSplicer.needsLeadingSpace("", "next"))
        assertFalse(TextSplicer.needsLeadingSpace("word ", "next"))
        assertFalse(TextSplicer.needsLeadingSpace("word", " next"))
        assertFalse(TextSplicer.needsLeadingSpace("word", "?"))
        assertFalse(TextSplicer.needsLeadingSpace("\"", "quote"))
    }

    @Test fun `word count splits on whitespace`() {
        assertEquals(0, TextSplicer.wordCount(""))
        assertEquals(0, TextSplicer.wordCount("   \n "))
        assertEquals(3, TextSplicer.wordCount(" one  two\nthree "))
        assertEquals(2, TextSplicer.wordCount("don't stop."))
    }

    @Test fun `the edit cap is a ceiling, not a limit on ordinary fields`() {
        assertFalse(TextSplicer.tooLongToEdit(""))
        assertFalse(TextSplicer.tooLongToEdit("a".repeat(TextSplicer.MAX_EDIT_CHARS)))
        assertTrue(TextSplicer.tooLongToEdit("a".repeat(TextSplicer.MAX_EDIT_CHARS + 1)))
    }

    @Test fun `an edit knows whether it has a selection or the whole field`() {
        assertTrue(TextSplicer.editsSelection("hey sam", false, 4, 7))
        assertFalse(TextSplicer.editsSelection("hey sam", false, 4, 4))
        assertFalse(TextSplicer.editsSelection("hey sam", false, -1, -1))
        assertFalse(TextSplicer.editsSelection("Search", true, 0, 0))
    }
}
