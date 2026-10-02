package com.shivarajbakale.parley

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo
import kotlinx.coroutines.delay

/**
 * Puts text into the captured field: ACTION_SET_TEXT first, then clipboard +
 * ACTION_PASTE, then clipboard only. The string arithmetic is [TextSplicer].
 */
class Injector(context: Context) {

    companion object {
        private const val TAG = "ParleyInjector"
        const val VERIFY_MS = 150L
        const val CLIPBOARD_RESTORE_MS = 1_000L
        private const val CLIP_LABEL = "Parley"
    }

    private val clipboard = context.getSystemService(ClipboardManager::class.java)
    private val main = Handler(Looper.getMainLooper())

    private fun AccessibilityNodeInfo.hint(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && isShowingHintText

    private fun AccessibilityNodeInfo.textString(): String = TextSplicer.effectiveText(text, hint())

    suspend fun insert(target: FieldTarget?, text: String, mode: SessionMode, leadingSpace: Boolean): InsertMethod {
        val node = target?.handle as? AccessibilityNodeInfo
        if (node == null || !safeRefresh(node) || !node.isEditable || node.isPassword) {
            return copyOnly(text)
        }
        val liveText = node.text
        val liveHint = node.hint()
        // The captured selection is authoritative while the field still holds
        // what it held at capture; if the user typed meanwhile, use the live one.
        val sameAsCaptured = TextSplicer.effectiveText(liveText, liveHint) ==
            TextSplicer.effectiveText(target.text, target.isShowingHint)
        val selStart = if (sameAsCaptured) target.selStart else node.textSelectionStart
        val selEnd = if (sameAsCaptured) target.selEnd else node.textSelectionEnd
        val splice = when (mode) {
            SessionMode.DICTATION -> TextSplicer.insert(liveText, liveHint, selStart, selEnd, text, leadingSpace)
            SessionMode.EDIT -> TextSplicer.replace(liveText, liveHint, selStart, selEnd, text)
        }
        return apply(node, TextSplicer.effectiveText(liveText, liveHint), splice)
    }

    /** Undo of an edit: the whole field goes back to [fullText]. */
    suspend fun restore(target: FieldTarget, fullText: String): Boolean {
        val node = target.handle as? AccessibilityNodeInfo ?: return false
        if (!safeRefresh(node) || !node.isEditable) return false
        val before = node.textString()
        val splice = TextSplicer.Splice(fullText, fullText.length, fullText, 0, before.length)
        val method = apply(node, before, splice)
        return method == InsertMethod.SET_TEXT || method == InsertMethod.PASTE
    }

    fun copy(text: String): Boolean = try {
        clipboard.setPrimaryClip(ClipData.newPlainText(CLIP_LABEL, text))
        true
    } catch (e: Exception) {
        Log.w(TAG, "clipboard write failed", e)
        false
    }

    private fun copyOnly(text: String): InsertMethod =
        if (copy(text)) InsertMethod.CLIPBOARD_ONLY else InsertMethod.FAILED

    private suspend fun apply(node: AccessibilityNodeInfo, before: String, splice: TextSplicer.Splice): InsertMethod {
        if (setText(node, before, splice)) return InsertMethod.SET_TEXT
        if (paste(node, before, splice)) return InsertMethod.PASTE
        return copyOnly(splice.inserted)
    }

    private suspend fun setText(node: AccessibilityNodeInfo, before: String, splice: TextSplicer.Splice): Boolean {
        val args = Bundle().apply {
            putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, splice.text)
        }
        val accepted = try {
            node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
        } catch (e: Exception) {
            Log.w(TAG, "SET_TEXT threw", e)
            false
        }
        if (!accepted) return false
        setSelection(node, splice.cursor, splice.cursor)
        delay(VERIFY_MS)
        if (landed(node, before, splice)) return true
        // Some apps apply the change a frame late. Pasting on top of a change
        // that did land would insert the text twice, so look once more.
        delay(VERIFY_MS)
        if (!safeRefresh(node)) return false
        return node.textString() != before
    }

    private suspend fun paste(node: AccessibilityNodeInfo, before: String, splice: TextSplicer.Splice): Boolean {
        val saved = try {
            clipboard.primaryClip // null when Android withholds it from a background app
        } catch (e: Exception) {
            null
        }
        if (!safeRefresh(node)) return false
        setSelection(node, splice.rangeStart, splice.rangeEnd)
        if (!copy(splice.inserted)) return false
        val accepted = try {
            node.performAction(AccessibilityNodeInfo.ACTION_PASTE)
        } catch (e: Exception) {
            Log.w(TAG, "PASTE threw", e)
            false
        }
        if (!accepted) return false // text stays on the clipboard for the copy-only fallback
        delay(VERIFY_MS)
        val ok = safeRefresh(node) && node.textString() != before
        if (ok && saved != null) {
            main.postDelayed({
                try { clipboard.setPrimaryClip(saved) } catch (_: Exception) {}
            }, CLIPBOARD_RESTORE_MS)
        }
        return ok
    }

    private fun landed(node: AccessibilityNodeInfo, before: String, splice: TextSplicer.Splice): Boolean {
        if (!safeRefresh(node)) return false
        val now = node.textString()
        if (now == splice.text) return true
        // Apps that normalise (trim, autocorrect spacing) still count when the words arrived.
        val core = splice.inserted.trim()
        return now != before && (core.isEmpty() || now.contains(core))
    }

    private fun setSelection(node: AccessibilityNodeInfo, start: Int, end: Int) {
        val args = Bundle().apply {
            putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT, start)
            putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT, end)
        }
        try {
            node.performAction(AccessibilityNodeInfo.ACTION_SET_SELECTION, args)
        } catch (e: Exception) {
            Log.w(TAG, "SET_SELECTION threw", e)
        }
    }

    private fun safeRefresh(node: AccessibilityNodeInfo): Boolean = try {
        node.refresh()
    } catch (e: Exception) {
        false
    }
}
