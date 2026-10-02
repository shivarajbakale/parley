package com.shivarajbakale.parley

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/** Every dictation and edit, one row each, matching the contract's HistoryEntry. */
class HistoryStore(context: Context, name: String? = DB_NAME) :
    SQLiteOpenHelper(context, name, null, VERSION) {

    companion object {
        const val DB_NAME = "parley_history.db"
        const val VERSION = 1
        const val DAY_MS = 86_400_000L
        const val WEEK_MS = 7 * DAY_MS
        private const val T = "history"
        private val NOT_INSERTED = listOf(InsertMethod.CLIPBOARD_ONLY.wire, InsertMethod.FAILED.wire)
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE $T (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              created_at INTEGER NOT NULL,
              mode TEXT NOT NULL,
              text TEXT NOT NULL,
              instruction TEXT,
              before_text TEXT,
              app_package TEXT NOT NULL,
              app_label TEXT NOT NULL,
              insert_method TEXT NOT NULL,
              recording_ms INTEGER NOT NULL,
              word_count INTEGER NOT NULL,
              saved_ms INTEGER NOT NULL
            )
            """.trimIndent()
        )
        db.execSQL("CREATE INDEX history_created ON $T(created_at)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit

    private fun values(entry: HistoryEntry, withId: Boolean) = ContentValues().apply {
        if (withId && entry.id > 0) put("id", entry.id)
        put("created_at", entry.createdAt)
        put("mode", entry.mode.wire)
        put("text", entry.text)
        put("instruction", entry.instruction)
        put("before_text", entry.beforeText)
        put("app_package", entry.appPackage)
        put("app_label", entry.appLabel)
        put("insert_method", entry.insertMethod.wire)
        put("recording_ms", entry.recordingMs)
        put("word_count", entry.wordCount)
        put("saved_ms", entry.savedMs)
    }

    /** Writes a new entry and returns it with its id. */
    fun insert(entry: HistoryEntry): HistoryEntry {
        val id = writableDatabase.insertOrThrow(T, null, values(entry, withId = false))
        return entry.copy(id = id)
    }

    /**
     * Undo of a delete: the entry goes back under its old id when that id is
     * free, so the Flutter list can put it back in place; otherwise a new one.
     */
    fun restore(entry: HistoryEntry): Long {
        val db = writableDatabase
        if (entry.id > 0 && get(entry.id) == null) {
            val id = db.insertWithOnConflict(T, null, values(entry, withId = true), SQLiteDatabase.CONFLICT_IGNORE)
            if (id != -1L) return id
        }
        return db.insertOrThrow(T, null, values(entry, withId = false))
    }

    fun get(id: Long): HistoryEntry? =
        readableDatabase.query(T, null, "id = ?", arrayOf(id.toString()), null, null, null).use { c ->
            if (c.moveToFirst()) read(c) else null
        }

    /** Newest first. `query` matches text, instruction or app label. */
    fun list(offset: Int, limit: Int, query: String?, filter: HistoryFilter): List<HistoryEntry> {
        val where = mutableListOf<String>()
        val args = mutableListOf<String>()
        when (filter) {
            HistoryFilter.ALL -> Unit
            HistoryFilter.DICTATION -> { where += "mode = ?"; args += SessionMode.DICTATION.wire }
            HistoryFilter.EDIT -> { where += "mode = ?"; args += SessionMode.EDIT.wire }
            HistoryFilter.NOT_INSERTED -> {
                where += "insert_method IN (${NOT_INSERTED.joinToString { "?" }})"
                args += NOT_INSERTED
            }
        }
        val q = query?.trim().orEmpty()
        if (q.isNotEmpty()) {
            val like = "%" + q.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%"
            where += "(text LIKE ? ESCAPE '\\' OR instruction LIKE ? ESCAPE '\\' OR app_label LIKE ? ESCAPE '\\')"
            args += listOf(like, like, like)
        }
        val sql = buildString {
            append("SELECT * FROM $T")
            if (where.isNotEmpty()) append(" WHERE ").append(where.joinToString(" AND "))
            append(" ORDER BY created_at DESC, id DESC LIMIT ? OFFSET ?")
        }
        args += limit.coerceAtLeast(0).toString()
        args += offset.coerceAtLeast(0).toString()
        return readableDatabase.rawQuery(sql, args.toTypedArray()).use { c ->
            buildList { while (c.moveToNext()) add(read(c)) }
        }
    }

    /** Deletes one entry, or all of them when [id] is null. Returns rows deleted. */
    fun delete(id: Long?): Int =
        if (id == null) writableDatabase.delete(T, null, null)
        else writableDatabase.delete(T, "id = ?", arrayOf(id.toString()))

    /** Drops entries older than the retention window; 0 days keeps everything. */
    fun prune(retentionDays: Int, now: Long): Int {
        if (retentionDays <= 0) return 0
        val cutoff = now - retentionDays * DAY_MS
        return writableDatabase.delete(T, "created_at < ?", arrayOf(cutoff.toString()))
    }

    fun usageSummary(now: Long): UsageSummary {
        val since = now - WEEK_MS
        val (words, saved) = readableDatabase.rawQuery(
            "SELECT COALESCE(SUM(word_count), 0), COALESCE(SUM(saved_ms), 0) FROM $T WHERE created_at >= ?",
            arrayOf(since.toString()),
        ).use { c -> if (c.moveToFirst()) c.getLong(0) to c.getLong(1) else 0L to 0L }
        val last = list(0, 1, null, HistoryFilter.ALL).firstOrNull()
        return UsageSummary(words, saved, last)
    }

    private fun read(c: Cursor): HistoryEntry {
        fun col(name: String) = c.getColumnIndexOrThrow(name)
        fun strOrNull(name: String) = col(name).let { if (c.isNull(it)) null else c.getString(it) }
        return HistoryEntry(
            id = c.getLong(col("id")),
            createdAt = c.getLong(col("created_at")),
            mode = SessionMode.fromWire(c.getString(col("mode"))) ?: SessionMode.DICTATION,
            text = c.getString(col("text")),
            instruction = strOrNull("instruction"),
            beforeText = strOrNull("before_text"),
            appPackage = c.getString(col("app_package")),
            appLabel = c.getString(col("app_label")),
            insertMethod = InsertMethod.fromWire(c.getString(col("insert_method"))) ?: InsertMethod.FAILED,
            recordingMs = c.getLong(col("recording_ms")),
            wordCount = c.getInt(col("word_count")),
            savedMs = c.getLong(col("saved_ms")),
        )
    }
}
