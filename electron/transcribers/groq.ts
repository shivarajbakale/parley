import {
  createRequest,
  providerUrl,
  readJson,
  TRANSCRIBE_TIMEOUT_MS,
  type TranscriptionProviderClient,
} from './shared';

/** The only file that talks to Groq's Whisper, through parley-api, which adds the key. */

const MODEL = 'whisper-large-v3-turbo';

export function createGroqProvider(fetchFn: typeof fetch): TranscriptionProviderClient {
  const request = createRequest('groq', fetchFn);

  return {
    async transcribe(audio, { vocabulary }, server) {
      const form = new FormData();
      form.set('file', new Blob([audio.data], { type: audio.mimeType }), 'speech.webm');
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
