import type { RecordedAudio } from './types';

/**
 * Validation for the one message the orb renderer pushes into the main
 * process. It is pure so the rules are unit-tested rather than reasoned about
 * in `main.ts`, and it is deliberately strict: everything here is untrusted
 * input from a renderer.
 */

/**
 * Groq's transcription endpoint rejects uploads past 25 MB, and a webm/opus
 * recording that large is far longer than the 10-minute auto-stop allows — so
 * anything bigger is a bug or an attack, not a dictation.
 */
export const MAX_AUDIO_BYTES = 25 * 1024 * 1024;

/** The orb records webm/opus; the renderer's own `mimeType` is never trusted. */
const MIME_TYPE = 'audio/webm';

function toArrayBuffer(data: unknown): ArrayBuffer | null {
  if (data instanceof ArrayBuffer) return data;
  // A structured-cloned Uint8Array/DataView may be a window onto a larger
  // buffer, so copy exactly its own bytes rather than passing the backing
  // buffer on.
  if (ArrayBuffer.isView(data)) {
    return data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength) as ArrayBuffer;
  }
  return null;
}

export function parseOrbAudio(raw: unknown): RecordedAudio | null {
  if (typeof raw !== 'object' || raw === null) return null;
  const { data, durationMs } = raw as { data?: unknown; durationMs?: unknown };

  const buffer = toArrayBuffer(data);
  if (!buffer) return null;
  if (buffer.byteLength > MAX_AUDIO_BYTES) return null;

  if (typeof durationMs !== 'number' || !Number.isFinite(durationMs) || durationMs < 0) return null;

  return {
    data: buffer,
    mimeType: MIME_TYPE,
    // No bytes means nothing was recorded, whatever the renderer timed: the
    // session treats a zero duration as the cancelled path.
    durationMs: buffer.byteLength === 0 ? 0 : durationMs,
  };
}
