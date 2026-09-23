package com.shivarajbakale.parley

import kotlinx.coroutines.runBlocking
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import java.io.File

class ProviderClientsTest {

    private lateinit var server: MockWebServer
    private lateinit var wav: File

    @Before fun setUp() {
        server = MockWebServer()
        server.start()
        wav = File.createTempFile("speech", ".wav")
        wav.writeBytes(Wav.header(3200) + ByteArray(3200))
    }

    @After fun tearDown() {
        server.shutdown()
        wav.delete()
    }

    private fun groq() = GroqTranscriber(server.url("/openai/v1").toString())
    private fun minimax() = MiniMaxRewriter(server.url("/v1").toString())

    private inline fun expectApiError(kind: ApiException.Kind, message: String, block: () -> Unit) {
        try {
            block()
            fail("expected $kind")
        } catch (e: ApiException) {
            assertEquals(kind, e.kind)
            assertEquals(message, e.message)
        }
    }

    // ---- Groq -----------------------------------------------------------

    @Test fun `groq posts multipart with model, text format and language`() = runBlocking {
        server.enqueue(MockResponse().setBody("  Hello there.\n"))
        val text = groq().transcribe(wav, "gsk_test", "en")
        assertEquals("Hello there.", text)

        val req = server.takeRequest()
        assertEquals("POST", req.method)
        assertEquals("/openai/v1/audio/transcriptions", req.path)
        assertEquals("Bearer gsk_test", req.getHeader("Authorization"))
        assertTrue(req.getHeader("Content-Type")!!.startsWith("multipart/form-data"))
        val body = req.body.readUtf8()
        fun part(name: String) = Regex("name=\"$name\"\r\n(?:[^\r\n]+\r\n)*\r\n([^\r\n]*)").find(body)?.groupValues?.get(1)
        assertEquals("whisper-large-v3-turbo", part("model"))
        assertEquals("text", part("response_format"))
        assertEquals("en", part("language"))
        assertTrue(body.contains("filename=\"speech.wav\""))
    }

    @Test fun `groq omits language when auto`() = runBlocking {
        server.enqueue(MockResponse().setBody("hola"))
        groq().transcribe(wav, "k", "auto")
        assertFalse(server.takeRequest().body.readUtf8().contains("name=\"language\""))
    }

    @Test fun `groq retries once on 5xx`() = runBlocking {
        server.enqueue(MockResponse().setResponseCode(503))
        server.enqueue(MockResponse().setBody("second time"))
        assertEquals("second time", groq().transcribe(wav, "k", "auto"))
        assertEquals(2, server.requestCount)
    }

    @Test fun `groq gives up after the retry`() {
        server.enqueue(MockResponse().setResponseCode(500))
        server.enqueue(MockResponse().setResponseCode(502))
        expectApiError(ApiException.Kind.SERVER, "Groq error") {
            runBlocking { groq().transcribe(wav, "k", "auto") }
        }
        assertEquals(2, server.requestCount)
    }

    @Test fun `groq does not retry 4xx`() {
        server.enqueue(MockResponse().setResponseCode(401))
        expectApiError(ApiException.Kind.AUTH, "Invalid Groq key") {
            runBlocking { groq().transcribe(wav, "bad", "auto") }
        }
        assertEquals(1, server.requestCount)
    }

    @Test fun `groq rate limit`() {
        server.enqueue(MockResponse().setResponseCode(429))
        expectApiError(ApiException.Kind.RATE_LIMIT, "Rate limited") {
            runBlocking { groq().transcribe(wav, "k", "auto") }
        }
    }

    @Test fun `groq without a key never calls out`() {
        expectApiError(ApiException.Kind.NO_KEY, "No Groq key") {
            runBlocking { groq().transcribe(wav, null, "auto") }
        }
        assertEquals(0, server.requestCount)
    }

    @Test fun `groq network failure`() {
        server.shutdown()
        expectApiError(ApiException.Kind.NETWORK, "No connection") {
            runBlocking { groq().transcribe(wav, "k", "auto") }
        }
    }

    @Test fun `groq verify lists models`() = runBlocking {
        server.enqueue(MockResponse().setBody("{\"data\":[]}"))
        val ok = groq().verify("gsk_good")
        assertEquals(VerifyResult(true, "Key works"), ok)
        val req = server.takeRequest()
        assertEquals("GET", req.method)
        assertEquals("/openai/v1/models", req.path)
        assertEquals("Bearer gsk_good", req.getHeader("Authorization"))

        server.enqueue(MockResponse().setResponseCode(401))
        assertEquals(VerifyResult(false, "Invalid Groq key"), groq().verify("gsk_bad"))
    }

    // ---- MiniMax --------------------------------------------------------

    private fun completion(content: String) =
        MockResponse().setBody(JSONObject().put("choices", org.json.JSONArray().put(
            JSONObject().put("message", JSONObject().put("role", "assistant").put("content", content))
        )).toString())

    @Test fun `minimax sends the mac request shape`() = runBlocking {
        server.enqueue(completion("Hi Sam, thanks!"))
        val out = minimax().rewrite("hey sam thx", "make it polite", "mm_key")
        assertEquals("Hi Sam, thanks!", out)

        val req = server.takeRequest()
        assertEquals("/v1/chat/completions", req.path)
        assertEquals("Bearer mm_key", req.getHeader("Authorization"))
        val json = JSONObject(req.body.readUtf8())
        assertEquals("MiniMax-M3", json.getString("model"))
        assertEquals(0.3, json.getDouble("temperature"), 0.0)
        assertEquals("disabled", json.getJSONObject("thinking").getString("type"))
        assertTrue(json.getBoolean("reasoning_split"))
        assertFalse(json.has("max_completion_tokens"))
        val messages = json.getJSONArray("messages")
        assertEquals("system", messages.getJSONObject(0).getString("role"))
        assertEquals(MiniMaxRewriter.SYSTEM_PROMPT, messages.getJSONObject(0).getString("content"))
        assertEquals(
            "<text>\nhey sam thx\n</text>\n<instruction>\nmake it polite\n</instruction>",
            messages.getJSONObject(1).getString("content"),
        )
    }

    @Test fun `minimax strips inline thinking`() = runBlocking {
        server.enqueue(completion("<think>plan the edit</think>\nFinal text"))
        assertEquals("Final text", minimax().rewrite("a", "b", "k"))
    }

    @Test fun `minimax empty reply is an error, never a blank paste`() {
        server.enqueue(completion("   "))
        expectApiError(ApiException.Kind.EMPTY, "MiniMax returned nothing") {
            runBlocking { minimax().rewrite("a", "b", "k") }
        }
    }

    @Test fun `minimax non json is a server error`() {
        server.enqueue(MockResponse().setBody("<html>oops</html>"))
        expectApiError(ApiException.Kind.SERVER, "MiniMax error") {
            runBlocking { minimax().rewrite("a", "b", "k") }
        }
    }

    @Test fun `minimax auth and retry`() {
        server.enqueue(MockResponse().setResponseCode(403))
        expectApiError(ApiException.Kind.AUTH, "Invalid MiniMax key") {
            runBlocking { minimax().rewrite("a", "b", "k") }
        }
        server.enqueue(MockResponse().setResponseCode(500))
        server.enqueue(completion("fixed"))
        assertEquals("fixed", runBlocking { minimax().rewrite("a", "b", "k") })
    }

    @Test fun `minimax verify is a one token request`() = runBlocking {
        server.enqueue(completion("ok"))
        assertEquals(VerifyResult(true, "Key works"), minimax().verify("mm_good"))
        val json = JSONObject(server.takeRequest().body.readUtf8())
        assertEquals(1, json.getInt("max_completion_tokens"))
        assertEquals("ok", json.getJSONArray("messages").getJSONObject(0).getString("content"))

        server.enqueue(MockResponse().setResponseCode(401))
        assertEquals(VerifyResult(false, "Invalid MiniMax key"), minimax().verify("mm_bad"))
    }

    @Test fun `verify refuses a blank key without a request`() = runBlocking {
        assertFalse(groq().verify("  ").ok)
        assertFalse(minimax().verify("").ok)
        assertEquals(0, server.requestCount)
    }
}
