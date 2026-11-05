import {
  createRequest,
  providerUrl,
  readJson,
  TRANSCRIBE_TIMEOUT_MS,
  type TranscriptionProviderClient,
} from './shared';

/** The only file that talks to Groq's Whisper, through parley-api, which adds the key. */

const MODEL = 'whisper-large-v3-turbo';

/**
 * Groq picks the decoder from the upload's file name, not its content type,
 * so the name has to match what was recorded: webm/opus from the Electron
 * orb, AAC in an MP4 container from the native shell.
 */
export function uploadName(mimeType: string): string {
  const base = mimeType.split(';')[0].trim().toLowerCase();
  if (base === 'audio/mp4' || base === 'audio/m4a' || base === 'audio/x-m4a') return 'speech.m4a';
  if (base === 'audio/wav' || base === 'audio/x-wav' || base === 'audio/wave') return 'speech.wav';
  return 'speech.webm';
}

export function createGroqProvider(fetchFn: typeof fetch): TranscriptionProviderClient {
  const request = createRequest('groq', fetchFn);

  return {
    async transcribe(audio, { vocabulary }, server) {
      const form = new FormData();
      form.set('file', new Blob([audio.data], { type: audio.mimeType }), uploadName(audio.mimeType));
      form.set('model', MODEL);
      form.set('language', 'en');
      form.set('response_format', 'json');
      if (vocabulary.trim()) form.set('prompt', vocabulary.trim());

      const response = await request(
        providerUrl(server, '/groq/openai/v1/audio/transcriptions'),
        { method: 'POST', body: form },
        TRANSCRIBE_TIMEOUT_MS
      );
      const body = await readJson<{ text?: string }>(response, 'groq');
      return (body.text ?? '').trim();
    },

  };
}
