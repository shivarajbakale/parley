package com.shivarajbakale.parley

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import org.json.JSONException
import org.json.JSONObject
import java.io.File
import java.io.IOException

/**
 * The only class that talks to Deepgram: Nova-3 over the pre-recorded
 * `/v1/listen` endpoint. The body is the WAV itself, not a form, and
 * vocabulary goes as one `keyterm` query parameter per term.
 */
class DeepgramTranscriber(
    private val baseUrl: String = DEFAULT_BASE,
    private val client: OkHttpClient = Http.client(),
) : Transcriber {
    override val provider = TranscriptionProvider.DEEPGRAM

    companion object {
        const val DEFAULT_BASE = "https://api.deepgram.com/v1"
        const val MODEL = "nova-3"

        /** Deepgram's own default; `auto` has no Nova-3 equivalent that keeps keyterms. */
        const val FALLBACK_LANGUAGE = "en"

        /** Deepgram caps keyterms at about 500 tokens in total; these keep well under it. */
        const val MAX_KEYTERMS = 100
        const val MAX_KEYTERM_CHARS = 1_500

        private val WAV = "audio/wav".toMediaType()

        fun messageFor(kind: ApiException.Kind): String = when (kind) {
            ApiException.Kind.NO_KEY -> "No Deepgram key"
            ApiException.Kind.NETWORK -> "No connection"
            ApiException.Kind.AUTH -> "Invalid Deepgram key"
            ApiException.Kind.RATE_LIMIT -> "Rate limited"
            ApiException.Kind.SERVER -> "Deepgram error"
            ApiException.Kind.EMPTY -> "Nothing heard"
        }

        /**
         * Trimmed, empties dropped, duplicates (ignoring case) dropped, first
         * spelling kept, then capped by count and by total length.
         */
        fun keytermsOf(terms: List<String>): List<String> {
            val seen = HashSet<String>()
            val out = ArrayList<String>()
            var chars = 0
            for (raw in terms) {
                val term = raw.trim()
                if (term.isEmpty() || !seen.add(term.lowercase())) continue
                if (out.size == MAX_KEYTERMS || chars + term.length > MAX_KEYTERM_CHARS) break
                out += term
                chars += term.length
            }
            return out
        }

        /** `results.channels[0].alternatives[0].transcript`, trimmed; '' when any step is missing. */
        internal fun transcriptOf(body: String): String {
            val json = try {
                JSONObject(body)
            } catch (e: JSONException) {
                fail(ApiException.Kind.SERVER)
            }
            return json.optJSONObject("results")
                ?.optJSONArray("channels")?.optJSONObject(0)
                ?.optJSONArray("alternatives")?.optJSONObject(0)
                ?.optString("transcript", "")
                .orEmpty()
                .trim()
        }

        private fun fail(kind: ApiException.Kind): Nothing = throw ApiException(kind, messageFor(kind))
    }

    private val base = baseUrl.trimEnd('/')

    override suspend fun transcribe(wav: File, key: String?, language: String, keyterms: List<String>): String = withContext(Dispatchers.IO) {
        if (key.isNullOrEmpty()) fail(ApiException.Kind.NO_KEY)
        val url = "$base/listen".toHttpUrl().newBuilder()
            .addQueryParameter("model", MODEL)
            .addQueryParameter("language", if (language.isEmpty() || language == "auto") FALLBACK_LANGUAGE else language)
            .addQueryParameter("smart_format", "true")
            .apply { keytermsOf(keyterms).forEach { addQueryParameter("keyterm", it) } }
            .build()
        val request = Request.Builder()
            .url(url)
            .header("Authorization", "Token $key")
            .post(wav.asRequestBody(WAV))
            .build()
        val response = try {
            Http.execute(client, request)
        } catch (e: IOException) {
            fail(ApiException.Kind.NETWORK)
        }
        response.use {
            if (!it.isSuccessful) fail(GroqTranscriber.kindForStatus(it.code))
            val body = try {
                it.body?.string().orEmpty()
            } catch (e: IOException) {
                fail(ApiException.Kind.NETWORK)
            }
            transcriptOf(body)
        }
    }

    /** The cheapest authenticated call: list the key's projects. */
    override suspend fun verify(key: String): VerifyResult = withContext(Dispatchers.IO) {
        if (key.isBlank()) return@withContext VerifyResult(false, messageFor(ApiException.Kind.NO_KEY))
        val request = Request.Builder().url("$base/projects").header("Authorization", "Token ${key.trim()}").get().build()
        try {
            Http.execute(client, request).use {
                if (it.isSuccessful) VerifyResult(true, "Key works")
                else VerifyResult(false, messageFor(GroqTranscriber.kindForStatus(it.code)))
            }
        } catch (e: IOException) {
            VerifyResult(false, messageFor(ApiException.Kind.NETWORK))
        }
    }
}
