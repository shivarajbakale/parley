import type { RecordedAudio } from '../../electron/types';

import { levelFromSamples } from './level';

/**
 * Microphone capture. The stream is opened on `start` and every track is
 * stopped on `stop` or `discard`, so the macOS microphone indicator is lit
 * only while the key is held.
 */

const MIME_TYPE = 'audio/webm;codecs=opus';

export interface Recorder {
  start(): Promise<void>;
  /** Resolves with the recording, or null if nothing was being recorded. */
  stop(): Promise<RecordedAudio | null>;
  discard(): void;
  /** Current voice level, 0 to 1. */
  level(): number;
}

export function createRecorder(): Recorder {
  let stream: MediaStream | null = null;
  let mediaRecorder: MediaRecorder | null = null;
  let audioContext: AudioContext | null = null;
  let analyser: AnalyserNode | null = null;
  let samples = new Uint8Array(0);
  let chunks: Blob[] = [];
  let startedAt = 0;

  function release() {
    stream?.getTracks().forEach((track) => track.stop());
    void audioContext?.close();
    stream = null;
    mediaRecorder = null;
    audioContext = null;
    analyser = null;
    chunks = [];
  }

  return {
    async start() {
      release();
      stream = await navigator.mediaDevices.getUserMedia({
        audio: { channelCount: 1, sampleRate: 16000, echoCancellation: false },
      });
      audioContext = new AudioContext();
      analyser = audioContext.createAnalyser();
      analyser.fftSize = 512;
      samples = new Uint8Array(analyser.fftSize);
      audioContext.createMediaStreamSource(stream).connect(analyser);

      mediaRecorder = new MediaRecorder(stream, {
        mimeType: MIME_TYPE,
        audioBitsPerSecond: 32000,
      });
      mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) chunks.push(event.data);
      };
      startedAt = performance.now();
      mediaRecorder.start();
    },

    stop() {
      const active = mediaRecorder;
      if (!active || active.state === 'inactive') {
        release();
        return Promise.resolve(null);
      }
      const durationMs = performance.now() - startedAt;
      return new Promise((resolve) => {
        active.onstop = async () => {
          const data = await new Blob(chunks, { type: MIME_TYPE }).arrayBuffer();
          release();
          resolve({ data, mimeType: 'audio/webm', durationMs });
        };
        active.stop();
      });
    },

    discard() {
      if (mediaRecorder && mediaRecorder.state !== 'inactive') {
        mediaRecorder.onstop = null;
        mediaRecorder.stop();
      }
      release();
    },

    level() {
      if (!analyser) return 0;
      analyser.getByteTimeDomainData(samples);
      return levelFromSamples(samples);
    },
  };
}
