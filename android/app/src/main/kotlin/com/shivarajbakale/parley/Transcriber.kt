package com.shivarajbakale.parley

import java.io.File

/** Who turns the recording into text. `groq` is the default, so an install from before this existed is unchanged. */
enum class TranscriptionProvider(val wire: String) {
    GROQ("groq"), DEEPGRAM("deepgram");

    /** The provider's own copy for a failure, for the orb and the key screens. */
    fun messageFor(kind: ApiException.Kind): String = when (this) {
        GROQ -> GroqTranscriber.messageFor(kind)
        DEEPGRAM -> DeepgramTranscriber.messageFor(kind)
    }

    companion object {
        val DEFAULT = GROQ

        fun fromWire(value: String?): TranscriptionProvider? = values().firstOrNull { it.wire == value }
    }
}

/**
 * Speech to text. [GroqTranscriber] and [DeepgramTranscriber] implement it;
 * [ParleyRuntime.transcriber] picks one from the configured provider.
 * Failures are [ApiException]s carrying the provider's own message.
 */
interface Transcriber {
    val provider: TranscriptionProvider

    /**
     * Returns the transcript, trimmed; empty when nothing was said.
     * [keyterms] are vocabulary hints; a provider that cannot use them ignores them.
     */
    suspend fun transcribe(wav: File, key: String?, language: String, keyterms: List<String> = emptyList()): String

    /** One cheap authenticated call, without saving anything. */
    suspend fun verify(key: String): VerifyResult
}
