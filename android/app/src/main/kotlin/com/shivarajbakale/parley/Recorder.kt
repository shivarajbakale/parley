package com.shivarajbakale.parley

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import androidx.core.content.ContextCompat
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * 16 kHz mono PCM16 from the mic into a WAV file in the cache directory,
 * publishing an RMS level about 30 times a second for the orb's ring.
 */
class Recorder(private val context: Context, private val onLevel: (Float) -> Unit) {

    companion object {
        private const val TAG = "ParleyRecorder"
        const val SAMPLE_RATE = 16_000
        /** One read per ~33 ms gives the ~30 Hz level. */
        private const val CHUNK_SAMPLES = SAMPLE_RATE / 30
    }

    @Volatile private var running = false
    private var thread: Thread? = null
    private var record: AudioRecord? = null
    private var file: File? = null
    @Volatile private var dataBytes = 0L

    val isRecording: Boolean get() = running

    /** Returns null once the mic is live, otherwise why it is not. */
    @SuppressLint("MissingPermission")
    fun start(): String? {
        if (running) return null
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            return "Microphone permission needed"
        }
        val minBuf = AudioRecord.getMinBufferSize(SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        if (minBuf <= 0) return "Microphone unavailable"
        val ar = try {
            AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                maxOf(minBuf, CHUNK_SAMPLES * 2 * 4),
            )
        } catch (e: Exception) {
            Log.w(TAG, "AudioRecord construct failed", e)
            return "Microphone unavailable"
        }
        if (ar.state != AudioRecord.STATE_INITIALIZED) {
            ar.release()
            return "Microphone unavailable"
        }
        try {
            ar.startRecording()
        } catch (e: Exception) {
            Log.w(TAG, "startRecording failed", e)
            ar.release()
            return "Microphone blocked"
        }
        if (ar.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
            ar.release()
            return "Microphone in use by another app"
        }
        val out = File(context.cacheDir, "parley-${System.currentTimeMillis()}.wav")
        record = ar
        file = out
        dataBytes = 0
        running = true
        thread = Thread({ pump(ar, out) }, "parley-recorder").also { it.start() }
        return null
    }

    private fun pump(ar: AudioRecord, out: File) {
        val samples = ShortArray(CHUNK_SAMPLES)
        val bytes = ByteBuffer.allocate(CHUNK_SAMPLES * 2).order(ByteOrder.LITTLE_ENDIAN)
        try {
            BufferedOutputStream(FileOutputStream(out)).use { stream ->
                stream.write(Wav.header(0, SAMPLE_RATE))
                while (running) {
                    val n = ar.read(samples, 0, samples.size)
                    if (n <= 0) {
                        if (n < 0) Log.w(TAG, "read error $n")
                        continue
                    }
                    bytes.clear()
                    for (i in 0 until n) bytes.putShort(samples[i])
                    stream.write(bytes.array(), 0, n * 2)
                    dataBytes += n * 2
                    onLevel(Wav.rms(samples, n))
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "recording failed", e)
        }
    }

    /** Stops and returns the finished WAV and how much audio it holds. */
    fun stop(): RecordedAudio {
        if (!running && file == null) return RecordedAudio(null, 0)
        running = false
        thread?.join(1_000)
        thread = null
        record?.let {
            try { it.stop() } catch (_: Exception) {}
            it.release()
        }
        record = null
        onLevel(0f)
        val out = file ?: return RecordedAudio(null, 0)
        file = null
        return try {
            Wav.finalise(out, SAMPLE_RATE)
            RecordedAudio(out, Wav.durationMs(dataBytes, SAMPLE_RATE))
        } catch (e: Exception) {
            Log.w(TAG, "finalise failed", e)
            out.delete()
            RecordedAudio(null, 0)
        }
    }

    fun cancel() {
        stop().file?.delete()
    }
}
