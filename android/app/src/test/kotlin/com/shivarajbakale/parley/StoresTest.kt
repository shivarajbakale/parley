package com.shivarajbakale.parley

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class HistoryStoreTest {

    private lateinit var store: HistoryStore
    private val now = 1_800_000_000_000L
    private val day = HistoryStore.DAY_MS

    @Before fun setUp() {
        store = HistoryStore(ApplicationProvider.getApplicationContext(), name = null) // in-memory
    }

    @After fun tearDown() = store.close()

    private fun entry(
        text: String,
        at: Long = now,
        mode: SessionMode = SessionMode.DICTATION,
        method: InsertMethod = InsertMethod.SET_TEXT,
        recordingMs: Long = 2_000,
        label: String = "Messages",
    ) = HistoryEntry(
        createdAt = at,
        mode = mode,
        text = text,
        instruction = if (mode == SessionMode.EDIT) "make it formal" else null,
        beforeText = if (mode == SessionMode.EDIT) "before" else null,
        appPackage = "com.example",
        appLabel = label,
        insertMethod = method,
        recordingMs = recordingMs,
    )

    @Test fun `saved time is words at 35 wpm minus the recording`() {
        // 35 words take a minute to type; spoken in 10 s that saves 50 s.
        assertEquals(50_000L, HistoryEntry.savedMs(35, 10_000))
        assertEquals(0L, HistoryEntry.savedMs(1, 10_000)) // never negative
        assertEquals(1_714L, HistoryEntry.savedMs(1, 0))
        val e = entry("one two three four five six seven", recordingMs = 3_000)
        assertEquals(7, e.wordCount)
        assertEquals(7 * 60_000L / 35 - 3_000, e.savedMs)
    }

    @Test fun `insert and read back every field`() {
        val saved = store.insert(entry("hello world", mode = SessionMode.EDIT))
        assertTrue(saved.id > 0)
        assertEquals(saved, store.get(saved.id))
        assertEquals(saved.toMap(), store.get(saved.id)!!.toMap())
        assertNull(store.get(9_999))
    }

    @Test fun `list is newest first with offset and limit`() {
        (1..5).forEach { store.insert(entry("entry $it", at = now + it)) }
        assertEquals(listOf("entry 5", "entry 4"), store.list(0, 2, null, HistoryFilter.ALL).map { it.text })
        assertEquals(listOf("entry 3", "entry 2"), store.list(2, 2, null, HistoryFilter.ALL).map { it.text })
        assertEquals(listOf("entry 1"), store.list(4, 10, null, HistoryFilter.ALL).map { it.text })
    }

    @Test fun `filters by mode and by not inserted`() {
        store.insert(entry("dictated", method = InsertMethod.SET_TEXT))
        store.insert(entry("pasted", method = InsertMethod.PASTE))
        store.insert(entry("copied", method = InsertMethod.CLIPBOARD_ONLY))
        store.insert(entry("failed", method = InsertMethod.FAILED))
        store.insert(entry("edited", mode = SessionMode.EDIT))
        fun texts(f: HistoryFilter) = store.list(0, 50, null, f).map { it.text }.toSet()
        assertEquals(5, texts(HistoryFilter.ALL).size)
        assertEquals(setOf("dictated", "pasted", "copied", "failed"), texts(HistoryFilter.DICTATION))
        assertEquals(setOf("edited"), texts(HistoryFilter.EDIT))
        assertEquals(setOf("copied", "failed"), texts(HistoryFilter.NOT_INSERTED))
    }

    @Test fun `query matches text, instruction and app, case-insensitively, with wildcards escaped`() {
        store.insert(entry("Lunch at noon"))
        store.insert(entry("100% sure"))
        store.insert(entry("rewritten", mode = SessionMode.EDIT))
        store.insert(entry("from gmail", label = "Gmail"))
        fun q(s: String) = store.list(0, 50, s, HistoryFilter.ALL).map { it.text }
        assertEquals(listOf("Lunch at noon"), q("lunch"))
        assertEquals(listOf("100% sure"), q("%"))
        assertEquals(listOf("rewritten"), q("formal"))
        assertEquals(listOf("from gmail"), q("GMAIL"))
        assertEquals(4, q("  ").size)
        assertEquals(listOf("100% sure"), store.list(0, 50, "sure", HistoryFilter.DICTATION).map { it.text })
    }

    @Test fun `retention prunes older entries and 0 keeps everything`() {
        store.insert(entry("old", at = now - 31 * day))
        store.insert(entry("week", at = now - 8 * day))
        store.insert(entry("new", at = now - day))
        assertEquals(0, store.prune(0, now))
        assertEquals(1, store.prune(30, now))
        assertEquals(1, store.prune(7, now))
        assertEquals(listOf("new"), store.list(0, 10, null, HistoryFilter.ALL).map { it.text })
    }

    @Test fun `delete one, delete all`() {
        val a = store.insert(entry("a"))
        store.insert(entry("b"))
        store.insert(entry("c"))
        assertEquals(1, store.delete(a.id))
        assertEquals(0, store.delete(a.id))
        assertEquals(2, store.delete(null))
        assertTrue(store.list(0, 10, null, HistoryFilter.ALL).isEmpty())
    }

    @Test fun `restore puts a deleted entry back under its id`() {
        val a = store.insert(entry("keep me"))
        store.delete(a.id)
        assertEquals(a.id, store.restore(a))
        assertEquals(a, store.get(a.id))
        // Restoring over a live id gets a fresh one instead of overwriting.
        val again = store.restore(a)
        assertTrue(again != a.id)
    }

    @Test fun `usage summary covers the last 7 days`() {
        store.insert(entry("one two three", at = now - 8 * day, recordingMs = 0))
        store.insert(entry("four five", at = now - 2 * day, recordingMs = 0))
        val last = store.insert(entry("six seven eight nine", at = now - 1_000, recordingMs = 1_000))
        val s = store.usageSummary(now)
        assertEquals(6, s.weekWords)
        assertEquals(HistoryEntry.savedMs(2, 0) + HistoryEntry.savedMs(4, 1_000), s.weekSavedMs)
        assertEquals(last, s.lastEntry)
        val empty = HistoryStore(ApplicationProvider.getApplicationContext(), null)
        assertEquals(UsageSummary(0, 0, null), empty.usageSummary(now))
        empty.close()
    }

    @Test fun `entry map round trips through fromMap`() {
        val saved = store.insert(entry("round trip", mode = SessionMode.EDIT, method = InsertMethod.PASTE))
        assertEquals(saved, HistoryEntry.fromMap(saved.toMap()))
        try {
            HistoryEntry.fromMap(saved.toMap() + ("mode" to "shout"))
            fail("bad mode accepted")
        } catch (e: IllegalArgumentException) {
            // expected
        }
    }
}

@RunWith(RobolectricTestRunner::class)
class ConfigStoreTest {

    private lateinit var config: ConfigStore

    @Before fun setUp() {
        val prefs = ApplicationProvider.getApplicationContext<Context>()
            .getSharedPreferences("config-test", Context.MODE_PRIVATE)
        prefs.edit().clear().commit()
        config = ConfigStore(prefs)
    }

    @Test fun `defaults match the contract`() {
        assertEquals(
            mapOf(
                "orbEnabled" to true,
                "orbSize" to "medium",
                "hideOrbWithoutField" to true,
                "volumeGestureEnabled" to true,
                "language" to "auto",
                "leadingSpace" to true,
                "haptics" to true,
                "historyRetentionDays" to 30,
                "groqKeyLast4" to null,
                "minimaxKeyLast4" to null,
            ),
            config.config.value.toMap(),
        )
        assertFalse(config.paused.value)
    }

    @Test fun `set applies live through the flow`() {
        config.set("orbSize", "large")
        config.set("haptics", false)
        config.set("language", "DE")
        config.set("historyRetentionDays", 90)
        val c = config.config.value
        assertEquals(OrbSize.LARGE, c.orbSize)
        assertFalse(c.haptics)
        assertEquals("de", c.language)
        assertEquals(90, c.historyRetentionDays)
    }

    @Test fun `invalid values are rejected`() {
        for ((key, value) in listOf(
            "orbSize" to "huge",
            "haptics" to "yes",
            "language" to "english",
            "historyRetentionDays" to 14,
            "groqKeyLast4" to "abcd",
            "nope" to true,
        )) {
            try {
                config.set(key, value)
                fail("$key=$value accepted")
            } catch (e: IllegalArgumentException) {
                // expected
            }
        }
    }

    @Test fun `keys cross only as last 4 and empty removes`() {
        config.setKeys("gsk_1234567890abcd", "mm_secretWXYZ")
        assertEquals("abcd", config.config.value.groqKeyLast4)
        assertEquals("WXYZ", config.config.value.minimaxKeyLast4)
        assertEquals("gsk_1234567890abcd", config.groqKey)
        assertFalse(config.config.value.toMap().values.any { it == "gsk_1234567890abcd" })
        config.setKeys(null, "")
        assertNull(config.minimaxKey)
        assertNull(config.config.value.minimaxKeyLast4)
        assertEquals("abcd", config.config.value.groqKeyLast4)
    }

    @Test fun `pause and orb position persist`() {
        config.setPaused(true)
        assertTrue(config.paused.value)
        config.saveOrbPosition(ConfigStore.OrbPosition(dockRight = false, yFraction = 0.2f))
        assertEquals(ConfigStore.OrbPosition(false, 0.2f), config.orbPosition())
    }
}
