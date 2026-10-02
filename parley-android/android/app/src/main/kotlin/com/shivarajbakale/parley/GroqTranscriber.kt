package com.shivarajbakale.parley

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.Response
import java.io.File
import java.io.IOException
import java.util.concurrent.TimeUnit

/** A provider call failed. [message] is short enough for the orb and the Setup screen. */
class ApiException(val kind: Kind, message: String) : Exception(message) {
    enum class Kind { NO_KEY, NETWORK, AUTH, RATE_LIMIT, SERVER, EMPTY }
}

internal object Http {
    fun client(): OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    /**
     * Runs [request]; a 5xx is tried once more. A timeout is not: retrying a
     * 30 s read would leave the orb spinning for a minute.
     */
    fun execute(client: OkHttpClient, request: Request, retries: Int = 1): Response {
        var attempt = 0
        while (true) {
            val response = client.newCall(request).execute()
            if (response.code >= 500 && attempt < retries) {
                response.close()
                attempt++
                continue
            }
            return response
        }
    }
}

/**
 * The only class that talks to Groq. Ported from the Mac app's transcriber.ts,
 * with `response_format=text` and the language from config.
 */
class GroqTranscriber(
    private val baseUrl: String = DEFAULT_BASE,
    private val client: OkHttpClient = Http.client(),
) : Transcriber {
    override val provider = TranscriptionProvider.GROQ

    companion object {
        const val DEFAULT_BASE = "https://api.groq.com/openai/v1"
        const val MODEL = "whisper-large-v3-turbo"
        private val WAV = "audio/wav".toMediaType()

        fun messageFor(kind: ApiException.Kind): String = when (kind) {
            ApiException.Kind.NO_KEY -> "No Groq key"
            ApiException.Kind.NETWORK -> "No connection"
            ApiException.Kind.AUTH -> "Invalid Groq key"
            ApiException.Kind.RATE_LIMIT -> "Rate limited"
            ApiException.Kind.SERVER -> "Groq error"
            ApiException.Kind.EMPTY -> "Nothing heard"
        }

        internal fun kindForStatus(status: Int) = when (status) {
            401, 403 -> ApiException.Kind.AUTH
            429 -> ApiException.Kind.RATE_LIMIT
            else -> ApiException.Kind.SERVER
        }

        private fun fail(kind: ApiException.Kind): Nothing = throw ApiException(kind, messageFor(kind))
    }

    private val base = baseUrl.trimEnd('/')

    /**
     * Returns the transcript, trimmed; empty when nothing was said. The request
     * carries no Whisper `prompt`, so [keyterms] are not sent.
     */
    override suspend fun transcribe(wav: File, key: String?, language: String, keyterms: List<String>): String = withContext(Dispatchers.IO) {
        if (key.isNullOrEmpty()) fail(ApiException.Kind.NO_KEY)
        val form = MultipartBody.Builder().setType(MultipartBody.FORM)
            .addFormDataPart("file", "speech.wav", wav.asRequestBody(WAV))
            .addFormDataPart("model", MODEL)
            .addFormDataPart("response_format", "text")
            .apply { if (language.isNotEmpty() && language != "auto") addFormDataPart("language", language) }
            .build()
        val request = Request.Builder()
            .url("$base/audio/transcriptions")
            .header("Authorization", "Bearer $key")
            .post(form)
            .build()
        val response = try {
            Http.execute(client, request)
        } catch (e: IOException) {
            fail(ApiException.Kind.NETWORK)
        }
        response.use {
            if (!it.isSuccessful) fail(kindForStatus(it.code))
            try {
                it.body?.string().orEmpty().trim()
            } catch (e: IOException) {
                fail(ApiException.Kind.NETWORK)
            }
        }
    }

    /** The cheapest authenticated call: list models. */
    override suspend fun verify(key: String): VerifyResult = withContext(Dispatchers.IO) {
        if (key.isBlank()) return@withContext VerifyResult(false, messageFor(ApiException.Kind.NO_KEY))
        val request = Request.Builder().url("$base/models").header("Authorization", "Bearer ${key.trim()}").get().build()
        try {
            Http.execute(client, request).use {
                if (it.isSuccessful) VerifyResult(true, "Key works")
                else VerifyResult(false, messageFor(kindForStatus(it.code)))
            }
        } catch (e: IOException) {
            VerifyResult(false, messageFor(ApiException.Kind.NETWORK))
        }
    }
}
