package com.shivarajbakale.parley

import kotlinx.coroutines.runBlocking
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.json.JSONArray
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import java.io.File

/** Mirrors ProviderClientsTest's Groq cases for Deepgram Nova-3. */
class DeepgramTranscriberTest {

    private lateinit var server: MockWebServer
    private lateinit var wav: File

    @Before fun setUp() {
        server = MockWebServer()
        server.start()
        wav = File.createTempFile("speech", ".wav")
        wav.writeBytes(Wav.header(3200) + ByteArray(3200) { (it % 7).toByte() })
    }

    @After fun tearDown() {
        server.shutdown()
        wav.delete()
    }

    private fun deepgram() = DeepgramTranscriber(server.url("/v1").toString())

    private fun listen(transcript: String) = MockResponse().setBody(
        JSONObject().put(
            "results",
            JSONObject().put(
                "channels",
                JSONArray().put(
                    JSONObject().put(
                        "alternatives",
                        JSONArray().put(JSONObject().put("transcript", transcript).put("confidence", 0.98)),
                    ),
                ),
            ),
        ).toString(),
    )

    private inline fun expectApiError(kind: ApiException.Kind, message: String, block: () -> Unit) {
        try {
            block()
            fail("expected $kind")
        } catch (e: ApiException) {
            assertEquals(kind, e.kind)
            assertEquals(message, e.message)
        }
    }

    @Test fun `posts the raw wav to listen with nova-3, language and smart format`() = runBlocking {
        server.enqueue(listen("  Hello there.\n"))
        val text = deepgram().transcribe(wav, "dg_test", "en")
        assertEquals("Hello there.", text)

        val req = server.takeRequest()
        assertEquals("POST", req.method)
        val url = req.requestUrl!!
        assertEquals("/v1/listen", url.encodedPath)
        assertEquals("nova-3", url.queryParameter("model"))
        assertEquals("en", url.queryParameter("language"))
        assertEquals("true", url.queryParameter("smart_format"))
        assertTrue(url.queryParameterValues("keyterm").isEmpty())
        assertEquals("Token dg_test", req.getHeader("Authorization"))
        assertTrue(req.getHeader("Content-Type")!!.startsWith("audio/wav"))
        // The body is the file itself, byte for byte — not a multipart form.
        assertArrayEquals(wav.readBytes(), req.body.readByteArray())
    }

    @Test fun `auto language falls back to english, a chosen one is passed through`() = runBlocking {
        server.enqueue(listen("hi"))
        deepgram().transcribe(wav, "k", "auto")
        assertEquals("en", server.takeRequest().requestUrl!!.queryParameter("language"))

        server.enqueue(listen("hola"))
        deepgram().transcribe(wav, "k", "es")
        assertEquals("es", server.takeRequest().requestUrl!!.queryParameter("language"))
    }

    @Test fun `one keyterm parameter per term, trimmed, empties and duplicates dropped`() = runBlocking {
        server.enqueue(listen("Parley on Kotlin"))
        deepgram().transcribe(wav, "k", "en", listOf(" Parley ", "", "   ", "Kotlin", "parley", "MiniMax M3"))
        val url = server.takeRequest().requestUrl!!
        assertEquals(listOf("Parley", "Kotlin", "MiniMax M3"), url.queryParameterValues("keyterm"))
        assertTrue(url.encodedQuery!!.contains("keyterm=MiniMax%20M3"))
    }

    @Test fun `keyterms are capped by count and by total length`() {
        val many = (1..150).map { "term$it" }
        val capped = DeepgramTranscriber.keytermsOf(many)
        assertEquals(DeepgramTranscriber.MAX_KEYTERMS, capped.size)
        assertEquals("term1", capped.first())

        val long = (1..40).map { "x".repeat(60) + it }
        val byLength = DeepgramTranscriber.keytermsOf(long)
        assertTrue(byLength.sumOf { it.length } <= DeepgramTranscriber.MAX_KEYTERM_CHARS)
        assertTrue(byLength.size < long.size)
    }

    @Test fun `a response without a transcript is empty, not an error`() = runBlocking {
        server.enqueue(MockResponse().setBody("{\"results\":{\"channels\":[]}}"))
        assertEquals("", deepgram().transcribe(wav, "k", "en"))
        server.enqueue(MockResponse().setBody("{}"))
        assertEquals("", deepgram().transcribe(wav, "k", "en"))
        server.enqueue(listen("   "))
        assertEquals("", deepgram().transcribe(wav, "k", "en"))
    }

    @Test fun `a body that is not json is a deepgram error`() {
        server.enqueue(MockResponse().setBody("<html>oops</html>"))
        expectApiError(ApiException.Kind.SERVER, "Deepgram error") {
            runBlocking { deepgram().transcribe(wav, "k", "en") }
        }
    }

    @Test fun `retries once on 5xx`() = runBlocking {
        server.enqueue(MockResponse().setResponseCode(503))
        server.enqueue(listen("second time"))
        assertEquals("second time", deepgram().transcribe(wav, "k", "en"))
        assertEquals(2, server.requestCount)
    }

    @Test fun `gives up after the retry with the deepgram message`() {
        server.enqueue(MockResponse().setResponseCode(500))
        server.enqueue(MockResponse().setResponseCode(502))
        expectApiError(ApiException.Kind.SERVER, "Deepgram error") {
            runBlocking { deepgram().transcribe(wav, "k", "en") }
        }
        assertEquals(2, server.requestCount)
    }

    @Test fun `a rejected key is not retried`() {
        server.enqueue(MockResponse().setResponseCode(401))
        expectApiError(ApiException.Kind.AUTH, "Invalid Deepgram key") {
            runBlocking { deepgram().transcribe(wav, "bad", "en") }
        }
        assertEquals(1, server.requestCount)
    }

    @Test fun `a bad request is a deepgram error`() {
        server.enqueue(MockResponse().setResponseCode(400).setBody("{\"err_code\":\"Bad Request\"}"))
        expectApiError(ApiException.Kind.SERVER, "Deepgram error") {
            runBlocking { deepgram().transcribe(wav, "k", "xx") }
        }
    }

    @Test fun `rate limit`() {
        server.enqueue(MockResponse().setResponseCode(429))
        expectApiError(ApiException.Kind.RATE_LIMIT, "Rate limited") {
            runBlocking { deepgram().transcribe(wav, "k", "en") }
        }
    }

    @Test fun `without a key never calls out`() {
        expectApiError(ApiException.Kind.NO_KEY, "No Deepgram key") {
            runBlocking { deepgram().transcribe(wav, null, "en") }
        }
        assertEquals(0, server.requestCount)
    }

    @Test fun `network failure`() {
        server.shutdown()
        expectApiError(ApiException.Kind.NETWORK, "No connection") {
            runBlocking { deepgram().transcribe(wav, "k", "en") }
        }
    }

    @Test fun `verify lists projects with the token header`() = runBlocking {
        server.enqueue(MockResponse().setBody("{\"projects\":[]}"))
        assertEquals(VerifyResult(true, "Key works"), deepgram().verify(" dg_good "))
        val req = server.takeRequest()
        assertEquals("GET", req.method)
        assertEquals("/v1/projects", req.path)
        assertEquals("Token dg_good", req.getHeader("Authorization"))

        server.enqueue(MockResponse().setResponseCode(403))
        assertEquals(VerifyResult(false, "Invalid Deepgram key"), deepgram().verify("dg_bad"))
    }

    @Test fun `verify without a key or a connection`() = runBlocking {
        assertEquals(VerifyResult(false, "No Deepgram key"), deepgram().verify("  "))
        assertEquals(0, server.requestCount)
        server.shutdown()
        assertEquals(VerifyResult(false, "No connection"), deepgram().verify("dg"))
    }

    @Test fun `provider enum maps wire names and messages`() {
        assertEquals(TranscriptionProvider.DEEPGRAM, TranscriptionProvider.fromWire("deepgram"))
        assertEquals(TranscriptionProvider.GROQ, TranscriptionProvider.fromWire("groq"))
        assertNull(TranscriptionProvider.fromWire("whisper"))
        assertEquals(TranscriptionProvider.GROQ, TranscriptionProvider.DEFAULT)
        assertEquals("No Groq key", TranscriptionProvider.GROQ.messageFor(ApiException.Kind.NO_KEY))
        assertEquals("Deepgram error", TranscriptionProvider.DEEPGRAM.messageFor(ApiException.Kind.SERVER))
    }

    @Test fun `groq ignores keyterms, so its request is unchanged`() = runBlocking {
        server.enqueue(MockResponse().setBody("hi"))
        GroqTranscriber(server.url("/openai/v1").toString())
            .transcribe(wav, "gsk", "en", listOf("Parley"))
        val req = server.takeRequest()
        assertEquals("/openai/v1/audio/transcriptions", req.path)
        val body = req.body.readUtf8()
        assertFalse(body.contains("Parley"))
        assertFalse(body.contains("name=\"prompt\""))
    }
}
