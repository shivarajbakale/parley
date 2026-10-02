package com.shivarajbakale.parley

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

class WavTest {

    private fun le(bytes: ByteArray) = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)

    @Test fun `header is canonical 16 kHz mono PCM16`() {
        val h = Wav.header(dataBytes = 32_000)
        assertEquals(44, h.size)
        assertEquals("RIFF", String(h, 0, 4, Charsets.US_ASCII))
        assertEquals("WAVE", String(h, 8, 4, Charsets.US_ASCII))
        assertEquals("fmt ", String(h, 12, 4, Charsets.US_ASCII))
        assertEquals("data", String(h, 36, 4, Charsets.US_ASCII))
        val b = le(h)
        assertEquals(36 + 32_000, b.getInt(4))
        assertEquals(16, b.getInt(16))
        assertEquals(1, b.getShort(20).toInt()) // PCM
        assertEquals(1, b.getShort(22).toInt()) // mono
        assertEquals(16_000, b.getInt(24))
        assertEquals(32_000, b.getInt(28)) // byte rate
        assertEquals(2, b.getShort(32).toInt()) // block align
        assertEquals(16, b.getShort(34).toInt())
        assertEquals(32_000, b.getInt(40))
    }

    @Test fun `finalise patches the sizes after recording`() {
        val f = File.createTempFile("parley", ".wav")
        try {
            val pcm = ByteArray(16_000) { (it % 7).toByte() }
            f.writeBytes(Wav.header(0) + pcm)
            Wav.finalise(f)
            val bytes = f.readBytes()
            assertEquals(16_000, le(bytes).getInt(40))
            assertEquals(36 + 16_000, le(bytes).getInt(4))
            assertArrayEquals(pcm, bytes.copyOfRange(44, bytes.size))
        } finally {
            f.delete()
        }
    }

    @Test fun `duration of 16 kHz mono PCM16`() {
        assertEquals(1_000L, Wav.durationMs(32_000))
        assertEquals(250L, Wav.durationMs(8_000))
        assertEquals(120_000L, Wav.durationMs(3_840_000))
    }

    @Test fun `rms of silence and full scale`() {
        assertEquals(0f, Wav.rms(ShortArray(100), 100), 0f)
        val loud = ShortArray(100) { if (it % 2 == 0) Short.MAX_VALUE else Short.MIN_VALUE }
        assertEquals(1f, Wav.rms(loud, 100), 0.001f)
        assertEquals(0f, Wav.rms(loud, 0), 0f)
    }
}
