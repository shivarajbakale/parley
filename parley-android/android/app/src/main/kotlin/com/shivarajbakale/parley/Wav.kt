package com.shivarajbakale.parley

import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder

/** A canonical 44-byte PCM WAV header. */
object Wav {
    const val HEADER_BYTES = 44

    fun header(dataBytes: Int, sampleRate: Int = 16_000, channels: Int = 1, bitsPerSample: Int = 16): ByteArray {
        val byteRate = sampleRate * channels * bitsPerSample / 8
        val blockAlign = channels * bitsPerSample / 8
        return ByteBuffer.allocate(HEADER_BYTES).order(ByteOrder.LITTLE_ENDIAN).apply {
            put("RIFF".toByteArray(Charsets.US_ASCII))
            putInt(36 + dataBytes)
            put("WAVE".toByteArray(Charsets.US_ASCII))
            put("fmt ".toByteArray(Charsets.US_ASCII))
            putInt(16) // PCM fmt chunk size
            putShort(1) // PCM
            putShort(channels.toShort())
            putInt(sampleRate)
            putInt(byteRate)
            putShort(blockAlign.toShort())
            putShort(bitsPerSample.toShort())
            put("data".toByteArray(Charsets.US_ASCII))
            putInt(dataBytes)
        }.array()
    }

    /** Rewrites the header of a file whose PCM data follows a placeholder header. */
    fun finalise(file: File, sampleRate: Int = 16_000) {
        RandomAccessFile(file, "rw").use { raf ->
            val data = (raf.length() - HEADER_BYTES).coerceAtLeast(0).toInt()
            raf.seek(0)
            raf.write(header(data, sampleRate))
        }
    }

    /** Duration of [dataBytes] of 16-bit mono PCM. */
    fun durationMs(dataBytes: Long, sampleRate: Int = 16_000): Long = dataBytes * 1000 / (sampleRate * 2L)

    /** Root-mean-square level of 16-bit samples, 0..1. */
    fun rms(samples: ShortArray, count: Int): Float {
        if (count <= 0) return 0f
        var sum = 0.0
        for (i in 0 until count) {
            val s = samples[i] / 32768.0
            sum += s * s
        }
        return Math.sqrt(sum / count).toFloat().coerceIn(0f, 1f)
    }
}
