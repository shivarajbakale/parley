package com.shivarajbakale.parley

/**
 * The shapes in docs/plans/bridge-contract.md. Every `toMap` here is what
 * crosses the MethodChannel, so the key names are the contract's.
 */

enum class OrbSize(val wire: String, val dp: Int) {
    SMALL("small", 36), MEDIUM("medium", 44), LARGE("large", 52);

    companion object {
        fun fromWire(value: String): OrbSize? = values().firstOrNull { it.wire == value }
    }
}

data class Config(
    val orbEnabled: Boolean = true,
    val orbSize: OrbSize = OrbSize.MEDIUM,
    val hideOrbWithoutField: Boolean = true,
    val volumeGestureEnabled: Boolean = true,
    val language: String = "auto",
    val leadingSpace: Boolean = true,
    val haptics: Boolean = true,
    val historyRetentionDays: Int = 30,
    val groqKeyLast4: String? = null,
    val minimaxKeyLast4: String? = null,
    val transcriptionProvider: TranscriptionProvider = TranscriptionProvider.DEFAULT,
    val deepgramKeyLast4: String? = null,
) {
    /** The chosen provider's key, last four; null when it has none. */
    val transcriptionKeyLast4: String?
        get() = when (transcriptionProvider) {
            TranscriptionProvider.GROQ -> groqKeyLast4
            TranscriptionProvider.DEEPGRAM -> deepgramKeyLast4
        }

    fun toMap(): Map<String, Any?> = mapOf(
        "orbEnabled" to orbEnabled,
        "orbSize" to orbSize.wire,
        "hideOrbWithoutField" to hideOrbWithoutField,
        "volumeGestureEnabled" to volumeGestureEnabled,
        "language" to language,
        "leadingSpace" to leadingSpace,
        "haptics" to haptics,
        "historyRetentionDays" to historyRetentionDays,
        "groqKeyLast4" to groqKeyLast4,
        "minimaxKeyLast4" to minimaxKeyLast4,
        "transcriptionProvider" to transcriptionProvider.wire,
        "deepgramKeyLast4" to deepgramKeyLast4,
    )

    companion object {
        val RETENTION_CHOICES = setOf(7, 30, 90, 0)
    }
}

data class Status(
    val serviceBound: Boolean,
    val paused: Boolean,
    val micGranted: Boolean,
    val batteryUnrestricted: Boolean,
    val groqKeySet: Boolean,
    val minimaxKeySet: Boolean,
    val orbEnabled: Boolean,
    val volumeGestureEnabled: Boolean,
    val deepgramKeySet: Boolean = false,
    val transcriptionProvider: TranscriptionProvider = TranscriptionProvider.DEFAULT,
) {
    /** The chosen provider has a key: what "ready" means. */
    val transcriptionKeySet: Boolean
        get() = when (transcriptionProvider) {
            TranscriptionProvider.GROQ -> groqKeySet
            TranscriptionProvider.DEEPGRAM -> deepgramKeySet
        }

    fun toMap(): Map<String, Any?> = mapOf(
        "serviceBound" to serviceBound,
        "paused" to paused,
        "micGranted" to micGranted,
        "batteryUnrestricted" to batteryUnrestricted,
        "groqKeySet" to groqKeySet,
        "minimaxKeySet" to minimaxKeySet,
        "orbEnabled" to orbEnabled,
        "volumeGestureEnabled" to volumeGestureEnabled,
        "deepgramKeySet" to deepgramKeySet,
        "transcriptionProvider" to transcriptionProvider.wire,
        "transcriptionKeySet" to transcriptionKeySet,
    )
}

enum class SessionMode(val wire: String) {
    DICTATION("dictation"), EDIT("edit");

    companion object {
        fun fromWire(value: String?): SessionMode? = values().firstOrNull { it.wire == value }
    }
}

enum class InsertMethod(val wire: String) {
    SET_TEXT("setText"), PASTE("paste"), CLIPBOARD_ONLY("clipboardOnly"), FAILED("failed");

    companion object {
        fun fromWire(value: String?): InsertMethod? = values().firstOrNull { it.wire == value }
    }
}

data class HistoryEntry(
    val id: Long = 0,
    val createdAt: Long,
    val mode: SessionMode,
    val text: String,
    val instruction: String? = null,
    val beforeText: String? = null,
    val appPackage: String,
    val appLabel: String,
    val insertMethod: InsertMethod,
    val recordingMs: Long,
    val wordCount: Int = TextSplicer.wordCount(text),
    val savedMs: Long = savedMs(wordCount, recordingMs),
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "id" to id,
        "createdAt" to createdAt,
        "mode" to mode.wire,
        "text" to text,
        "instruction" to instruction,
        "beforeText" to beforeText,
        "appPackage" to appPackage,
        "appLabel" to appLabel,
        "insertMethod" to insertMethod.wire,
        "recordingMs" to recordingMs,
        "wordCount" to wordCount,
        "savedMs" to savedMs,
    )

    companion object {
        const val TYPING_WPM = 35

        /** `max(0, wordCount / 35 * 60000 − recordingMs)`: typing time the dictation replaced. */
        fun savedMs(wordCount: Int, recordingMs: Long): Long =
            maxOf(0L, wordCount.toLong() * 60_000L / TYPING_WPM - recordingMs)

        /** Rebuilds an entry the Flutter side handed back (restoreHistory). */
        fun fromMap(map: Map<*, *>): HistoryEntry {
            fun long(key: String): Long = (map[key] as? Number)?.toLong()
                ?: throw IllegalArgumentException("entry.$key must be an int")
            fun str(key: String): String = map[key] as? String
                ?: throw IllegalArgumentException("entry.$key must be a string")
            val text = str("text")
            val recordingMs = long("recordingMs")
            val words = (map["wordCount"] as? Number)?.toInt() ?: TextSplicer.wordCount(text)
            return HistoryEntry(
                id = (map["id"] as? Number)?.toLong() ?: 0,
                createdAt = long("createdAt"),
                mode = SessionMode.fromWire(map["mode"] as? String)
                    ?: throw IllegalArgumentException("entry.mode must be dictation or edit"),
                text = text,
                instruction = map["instruction"] as? String,
                beforeText = map["beforeText"] as? String,
                appPackage = str("appPackage"),
                appLabel = str("appLabel"),
                insertMethod = InsertMethod.fromWire(map["insertMethod"] as? String)
                    ?: throw IllegalArgumentException("entry.insertMethod is not a known method"),
                recordingMs = recordingMs,
                wordCount = words,
                savedMs = (map["savedMs"] as? Number)?.toLong() ?: savedMs(words, recordingMs),
            )
        }
    }
}

data class UsageSummary(val weekWords: Long, val weekSavedMs: Long, val lastEntry: HistoryEntry?) {
    fun toMap(): Map<String, Any?> = mapOf(
        "weekWords" to weekWords,
        "weekSavedMs" to weekSavedMs,
        "lastEntry" to lastEntry?.toMap(),
    )
}

enum class HistoryFilter(val wire: String) {
    ALL("all"), DICTATION("dictation"), EDIT("edit"), NOT_INSERTED("notInserted");

    companion object {
        fun fromWire(value: String?): HistoryFilter? =
            if (value == null) ALL else values().firstOrNull { it.wire == value }
    }
}

data class VerifyResult(val ok: Boolean, val message: String?) {
    fun toMap(): Map<String, Any?> = mapOf("ok" to ok, "message" to message)
}
