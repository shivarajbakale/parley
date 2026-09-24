import {
  createRequest,
  keyResult,
  readJson,
  TEST_KEY_TIMEOUT_MS,
  TRANSCRIBE_TIMEOUT_MS,
  type TranscriptionProviderClient,
} from './shared';

/**
 * The only file that talks to Deepgram. Nova-3 takes no prose prompt; it
 * takes `keyterm`s, one query parameter per word or phrase to favour.
 */

const BASE = 'https://api.deepgram.com/v1';
const MODEL = 'nova-3';

/**
 * Deepgram caps keyterms at roughly 500 tokens in total. No tokenizer ships
 * with the app, so this is a term count plus a character budget that stays
 * well under it even for jargon that splits into many tokens.
 */
export const MAX_KEYTERMS = 100;
export const MAX_KEYTERM_CHARS = 1000;

/** Split, trim, drop empties and case-insensitive duplicates, then trim to budget. */
export function keyterms(input: string | string[]): string[] {
  const raw = (Array.isArray(input) ? input : [input]).flatMap(part => part.split(/[,\n]/));
  const seen = new Set<string>();
  const picked: string[] = [];
  let chars = 0;
  for (const candidate of raw) {
    const term = candidate.trim().replace(/\s+/g, ' ');
    if (!term) continue;
    const key = term.toLowerCase();
    if (seen.has(key)) continue;
    if (picked.length >= MAX_KEYTERMS || chars + term.length > MAX_KEYTERM_CHARS) break;
    seen.add(key);
    picked.push(term);
    chars += term.length;
  }
  return picked;
}

interface ListenResponse {
  results?: { channels?: { alternatives?: { transcript?: string }[] }[] };
}

export function createDeepgramProvider(fetchFn: typeof fetch): TranscriptionProviderClient {
  const request = createRequest('deepgram', fetchFn);

  return {
    async transcribe(audio, { vocabulary, terms }, key) {
      const params = [`model=${MODEL}`, 'language=en', 'smart_format=true'];
      for (const term of keyterms(terms ?? vocabulary)) {
        params.push(`keyterm=${encodeURIComponent(term)}`);
      }

      const response = await request(
        `${BASE}/listen?${params.join('&')}`,
        {
          method: 'POST',
          headers: { Authorization: `Token ${key}`, 'Content-Type': audio.mimeType },
          body: audio.data,
        },
        TRANSCRIBE_TIMEOUT_MS
      );
      const body = await readJson<ListenResponse>(response, 'deepgram');
      return (body?.results?.channels?.[0]?.alternatives?.[0]?.transcript ?? '').trim();
    },

    testKey: key =>
      keyResult(() =>
        request(
          `${BASE}/projects`,
          { method: 'GET', headers: { Authorization: `Token ${key}` } },
          TEST_KEY_TIMEOUT_MS
        )
      ),
  };
}
