import type { KeyTestResult } from './types';

/**
 * The only file that talks to Groq. If a cleanup pass is ever added, it wraps
 * `transcribe` here and nothing else changes.
 */

const BASE = 'https://api.groq.com/openai/v1';
const MODEL = 'whisper-large-v3-turbo';

export type TranscribeErrorKind = 'no_key' | 'network' | 'auth' | 'rate_limit' | 'server';

const MESSAGES: Record<TranscribeErrorKind, string> = {
  no_key: 'No API key',
  network: 'No connection',
  auth: 'Invalid API key',
  rate_limit: 'Rate limited',
  server: 'Groq error',
};

export class TranscribeError extends Error {
  constructor(public readonly kind: TranscribeErrorKind) {
    super(MESSAGES[kind]);
    this.name = 'TranscribeError';
  }
}

function kindForStatus(status: number): TranscribeErrorKind {
  if (status === 401 || status === 403) return 'auth';
  if (status === 429) return 'rate_limit';
  return 'server';
}

export interface Transcriber {
  transcribe(
    audio: { data: ArrayBuffer; mimeType: string },
    options: { vocabulary: string }
  ): Promise<string>;
  testKey(key: string): Promise<KeyTestResult>;
}

export function createTranscriber(deps: {
  getApiKey(): string | null;
  fetchFn?: typeof fetch;
}): Transcriber {
  const fetchFn = deps.fetchFn ?? fetch;

  async function request(url: string, init: RequestInit): Promise<Response> {
    let response: Response;
    try {
      response = await fetchFn(url, init);
    } catch {
      throw new TranscribeError('network');
    }
    if (!response.ok) throw new TranscribeError(kindForStatus(response.status));
    return response;
  }

  return {
    async transcribe(audio, { vocabulary }) {
      const key = deps.getApiKey();
      if (!key) throw new TranscribeError('no_key');

      const form = new FormData();
      form.set('file', new Blob([audio.data], { type: audio.mimeType }), 'speech.webm');
      form.set('model', MODEL);
      form.set('language', 'en');
      form.set('response_format', 'json');
      if (vocabulary.trim()) form.set('prompt', vocabulary.trim());

      const response = await request(`${BASE}/audio/transcriptions`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${key}` },
        body: form,
      });
      const body = (await response.json()) as { text?: string };
      return (body.text ?? '').trim();
    },

    async testKey(key) {
      try {
        await request(`${BASE}/models`, {
          method: 'GET',
          headers: { Authorization: `Bearer ${key}` },
        });
        return { ok: true, message: 'Key works' };
      } catch (error) {
        return { ok: false, message: (error as Error).message };
      }
    },
  };
}
