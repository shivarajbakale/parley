import {
  createRequest,
  keyResult,
  readJson,
  TEST_KEY_TIMEOUT_MS,
  TRANSCRIBE_TIMEOUT_MS,
  type TranscriptionProviderClient,
} from './shared';

/** The only file that talks to Groq's Whisper. */

const BASE = 'https://api.groq.com/openai/v1';
const MODEL = 'whisper-large-v3-turbo';

export function createGroqProvider(fetchFn: typeof fetch): TranscriptionProviderClient {
  const request = createRequest('groq', fetchFn);

  return {
    async transcribe(audio, { vocabulary }, key) {
      const form = new FormData();
      form.set('file', new Blob([audio.data], { type: audio.mimeType }), 'speech.webm');
      form.set('model', MODEL);
      form.set('language', 'en');
      form.set('response_format', 'json');
      if (vocabulary.trim()) form.set('prompt', vocabulary.trim());

      const response = await request(
        `${BASE}/audio/transcriptions`,
        {
          method: 'POST',
          headers: { Authorization: `Bearer ${key}` },
          body: form,
        },
        TRANSCRIBE_TIMEOUT_MS
      );
      const body = await readJson<{ text?: string }>(response, 'groq');
      return (body.text ?? '').trim();
    },

    testKey: key =>
      keyResult(() =>
        request(
          `${BASE}/models`,
          { method: 'GET', headers: { Authorization: `Bearer ${key}` } },
          TEST_KEY_TIMEOUT_MS
        )
      ),
  };
}
