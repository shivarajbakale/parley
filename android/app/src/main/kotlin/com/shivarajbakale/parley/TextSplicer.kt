package com.shivarajbakale.parley

/**
 * The string arithmetic behind insertion, kept free of Android types so every
 * edge (hint text, reversed or missing selection, surrogate pairs, the
 * leading-space rule) is a plain unit test.
 */
object TextSplicer {

    data class Splice(
        /** The whole field after the change. */
        val text: String,
        /** Where the cursor goes: the end of the inserted text. */
        val cursor: Int,
        /** Exactly what went in, including any leading space. */
        val inserted: String,
        val rangeStart: Int,
        val rangeEnd: Int,
    )

    /** Past this, a "field" is a document or a page, not something to rewrite whole. */
    const val MAX_EDIT_CHARS = 8000

    /** A whole-field rewrite of a document-sized field is not what the gesture is for. */
    fun tooLongToEdit(source: String): Boolean = source.length > MAX_EDIT_CHARS

    /** Characters after which a dictated word should not get a space. */
    private const val NO_SPACE_AFTER = "([{\"'“‘/-\n\t "
    /** A dictation that starts with one of these attaches to the previous word. */
    private const val NO_SPACE_BEFORE = ".,;:!?)]}%…'’\""

    /** The field's real text: a hint is shown, not typed, so it counts as empty. */
    fun effectiveText(text: CharSequence?, isShowingHint: Boolean): String =
        if (isShowingHint || text == null) "" else text.toString()

    /**
     * Normalises a reported selection against [text]: -1 (unknown) means the
     * end, a reversed range is swapped, both ends are clamped, and an end that
     * falls between the halves of a surrogate pair is moved so an emoji is never
     * split: a selection widens to cover it, a bare cursor moves past it.
     */
    fun normalise(text: String, selStart: Int, selEnd: Int): Pair<Int, Int> {
        val len = text.length
        var start = if (selStart < 0) len else selStart.coerceAtMost(len)
        var end = if (selEnd < 0) start else selEnd.coerceAtMost(len)
        if (start > end) start = end.also { end = start }
        if (start == end) {
            // A bare cursor inside an emoji goes after it, rather than widening
            // into a selection that would replace the emoji.
            if (splitsPair(text, start)) { start += 1; end += 1 }
            return start to end
        }
        if (splitsPair(text, start)) start -= 1
        if (splitsPair(text, end)) end += 1
        return start to end
    }

    private fun splitsPair(text: String, index: Int): Boolean =
        index > 0 && index < text.length &&
            Character.isHighSurrogate(text[index - 1]) && Character.isLowSurrogate(text[index])

    /** Should a space be put between [before] and a dictation starting [dictated]? */
    fun needsLeadingSpace(before: String, dictated: String): Boolean {
        if (before.isEmpty() || dictated.isEmpty()) return false
        val prev = before.last()
        val first = dictated.first()
        if (prev.isWhitespace() || prev in NO_SPACE_AFTER) return false
        if (first.isWhitespace() || first in NO_SPACE_BEFORE) return false
        return true
    }

    /** Dictation: replace the selection (or insert at the cursor) with [dictated]. */
    fun insert(
        current: CharSequence?,
        isShowingHint: Boolean,
        selStart: Int,
        selEnd: Int,
        dictated: String,
        leadingSpace: Boolean,
    ): Splice {
        val text = effectiveText(current, isShowingHint)
        val (start, end) = normalise(text, selStart, selEnd)
        val before = text.substring(0, start)
        val lead = if (leadingSpace && needsLeadingSpace(before, dictated)) " " else ""
        val inserted = lead + dictated
        return Splice(before + inserted + text.substring(end), start + inserted.length, inserted, start, end)
    }

    /**
     * Voice edit: the captured selection, or the whole field when nothing is
     * selected, is what the instruction applies to.
     */
    fun editRange(current: CharSequence?, isShowingHint: Boolean, selStart: Int, selEnd: Int): Pair<Int, Int> {
        val text = effectiveText(current, isShowingHint)
        val (start, end) = normalise(text, selStart, selEnd)
        return if (start == end) 0 to text.length else start to end
    }

    /** Does the edit act on a selection, or on the whole field? */
    fun editsSelection(
        current: CharSequence?,
        isShowingHint: Boolean,
        selStart: Int,
        selEnd: Int,
    ): Boolean {
        val text = effectiveText(current, isShowingHint)
        val (start, end) = normalise(text, selStart, selEnd)
        return start != end
    }

    fun editSource(current: CharSequence?, isShowingHint: Boolean, selStart: Int, selEnd: Int): String {
        val text = effectiveText(current, isShowingHint)
        val (start, end) = editRange(current, isShowingHint, selStart, selEnd)
        return text.substring(start, end)
    }

    fun replace(
        current: CharSequence?,
        isShowingHint: Boolean,
        selStart: Int,
        selEnd: Int,
        replacement: String,
    ): Splice {
        val text = effectiveText(current, isShowingHint)
        val (start, end) = editRange(current, isShowingHint, selStart, selEnd)
        return Splice(
            text.substring(0, start) + replacement + text.substring(end),
            start + replacement.length,
            replacement,
            start,
            end,
        )
    }

    /** Whitespace-split word count, as stored on every history entry. */
    fun wordCount(text: String): Int = text.trim().split(Regex("\\s+")).count { it.isNotEmpty() }
}
