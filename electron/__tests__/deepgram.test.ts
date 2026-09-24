import { describe, expect, it, vi } from 'vitest';

import { createTranscriber, TranscribeError } from '../transcriber';
import { keyterms, MAX_KEYTERM_CHARS, MAX_KEYTERMS } from '../transcribers/deepgram';
import type { TranscriptionProvider } from '../types';

const audio = { data: new Uint8Array([1, 2, 3]).buffer, mimeType: 'audio/webm;codecs=opus' };

function respond(status: number, body: unknown) {
  return vi.fn().mockResolvedValue(
    new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } })
  );
}

function listen(transcript: string) {
  return { results: { channels: [{ alternatives: [{ transcript, confidence: 0.99 }] }] } };
}

function deepgram(fetchFn: ReturnType<typeof vi.fn>, key: string | null = 'dg_test') {
  return createTranscriber({
    getApiKey: provider => (provider === 'deepgram' ? key : 'gsk_groq'),
    getProvider: () => 'deepgram',
    fetchFn,
  });
}

describe('deepgram transcriber', () => {
  it('posts the raw audio to Nova-3 with model, language and smart formatting', async () => {
    const fetchFn = respond(200, listen(' hello world '));
    const text = await deepgram(fetchFn).transcribe(audio, { vocabulary: '' });

    expect(text).toBe('hello world');
    const [url, init] = fetchFn.mock.calls[0];
    const parsed = new URL(url);
    expect(`${parsed.origin}${parsed.pathname}`).toBe('https://api.deepgram.com/v1/listen');
    expect(parsed.searchParams.get('model')).toBe('nova-3');
    expect(parsed.searchParams.get('language')).toBe('en');
    expect(parsed.searchParams.get('smart_format')).toBe('true');
    expect(parsed.searchParams.has('keyterm')).toBe(false);
    expect(init.method).toBe('POST');
    expect(init.headers.Authorization).toBe('Token dg_test');
    expect(init.headers['Content-Type']).toBe('audio/webm;codecs=opus');
    expect(init.body).toBe(audio.data);
  });

  it('sends one keyterm per term, trimmed, deduplicated and without empties', async () => {
    const fetchFn = respond(200, listen('hi'));
    await deepgram(fetchFn).transcribe(audio, {
      vocabulary: 'Notes about ignored.',
      terms: [' MiniMax ', 'kubectl', '', 'minimax', 'Tailwind CSS', 'kubectl'],
    });
    const parsed = new URL(fetchFn.mock.calls[0][0]);
    expect(parsed.searchParams.getAll('keyterm')).toEqual(['MiniMax', 'kubectl', 'Tailwind CSS']);
    // A phrase is percent-encoded, not joined with a plus.
    expect(fetchFn.mock.calls[0][0]).toContain('keyterm=Tailwind%20CSS');
  });

  it('splits a comma-separated vocabulary when no term list is given', async () => {
    const fetchFn = respond(200, listen('hi'));
    await deepgram(fetchFn).transcribe(audio, { vocabulary: 'Parley, Groq,, Deepgram ,parley' });
    const parsed = new URL(fetchFn.mock.calls[0][0]);
    expect(parsed.searchParams.getAll('keyterm')).toEqual(['Parley', 'Groq', 'Deepgram']);
  });

  it('returns an empty transcript when the response has none', async () => {
    for (const body of [{}, { results: { channels: [] } }, { results: { channels: [{}] } }]) {
      const text = await deepgram(respond(200, body)).transcribe(audio, { vocabulary: '' });
      expect(text).toBe('');
    }
  });

  it('fails with no_key before any request when no Deepgram key is stored', async () => {
    const fetchFn = vi.fn();
    const error = await deepgram(fetchFn, null)
      .transcribe(audio, { vocabulary: '' })
      .catch(e => e);
    expect(error).toMatchObject({ kind: 'no_key', message: 'No API key' });
    expect(fetchFn).not.toHaveBeenCalled();
  });

  it.each([
    [401, 'auth', 'Invalid API key'],
    [403, 'auth', 'Invalid API key'],
    [429, 'rate_limit', 'Rate limited'],
    [500, 'server', 'Deepgram error'],
  ])('maps HTTP %i to %s', async (status, kind, message) => {
    const error = await deepgram(respond(status, {}))
      .transcribe(audio, { vocabulary: '' })
      .catch(e => e);
    expect(error).toBeInstanceOf(TranscribeError);
    expect(error).toMatchObject({ kind, message });
  });

  it('maps a rejected or aborted fetch to network', async () => {
    for (const reason of [new TypeError('fetch failed'), new DOMException('t', 'TimeoutError')]) {
      const fetchFn = vi.fn().mockRejectedValue(reason);
      await expect(deepgram(fetchFn).transcribe(audio, { vocabulary: '' })).rejects.toMatchObject({
        kind: 'network',
        message: 'No connection',
      });
    }
  });

  it('maps a non-JSON 200 body to a Deepgram server error', async () => {
    const fetchFn = vi.fn().mockResolvedValue(new Response('<html>oops</html>', { status: 200 }));
    const error = await deepgram(fetchFn)
      .transcribe(audio, { vocabulary: '' })
      .catch(e => e);
    expect(error).toMatchObject({ kind: 'server', message: 'Deepgram error' });
  });

  it('gives the transcribe request and the key test an abort signal', async () => {
    const fetchFn = respond(200, listen('hi'));
    const t = deepgram(fetchFn);
    await t.transcribe(audio, { vocabulary: '' });
    await t.testKey('dg_new');
    expect(fetchFn.mock.calls[0][1].signal).toBeInstanceOf(AbortSignal);
    expect(fetchFn.mock.calls[1][1].signal).toBeInstanceOf(AbortSignal);
  });

  it('tests a key against the projects endpoint', async () => {
    const fetchFn = respond(200, { projects: [] });
    expect(await deepgram(fetchFn).testKey('dg_new')).toEqual({ ok: true, message: 'Key works' });
    const [url, init] = fetchFn.mock.calls[0];
    expect(url).toBe('https://api.deepgram.com/v1/projects');
    expect(init.method).toBe('GET');
    expect(init.headers.Authorization).toBe('Token dg_new');
  });

  it('reports a rejected key', async () => {
    expect(await deepgram(respond(401, {})).testKey('bad')).toEqual({
      ok: false,
      message: 'Invalid API key',
    });
  });
});

describe('keyterms', () => {
  it(`keeps at most ${MAX_KEYTERMS} terms, in order`, () => {
    const many = Array.from({ length: 150 }, (_, i) => `term${i}`);
    const picked = keyterms(many);
    expect(picked).toHaveLength(MAX_KEYTERMS);
    expect(picked[0]).toBe('term0');
    expect(picked.at(-1)).toBe(`term${MAX_KEYTERMS - 1}`);
  });

  it('stops before the character budget is exceeded', () => {
    const long = Array.from({ length: 60 }, (_, i) => `${'x'.repeat(40)}${i}`);
    const picked = keyterms(long);
    expect(picked.join('').length).toBeLessThanOrEqual(MAX_KEYTERM_CHARS);
    expect(picked.length).toBeLessThan(60);
  });

  it('collapses inner whitespace', () => {
    expect(keyterms(['Tailwind \n  CSS'])).toEqual(['Tailwind', 'CSS']);
    expect(keyterms(['Tailwind    CSS'])).toEqual(['Tailwind CSS']);
  });
});

describe('provider selection', () => {
  it('routes each call to the provider selected at that moment', async () => {
    let provider: TranscriptionProvider = 'groq';
    const fetchFn = vi
      .fn()
      .mockImplementation(async (url: string) =>
        url.includes('groq')
          ? new Response(JSON.stringify({ text: 'from groq' }), { status: 200 })
          : new Response(JSON.stringify(listen('from deepgram')), { status: 200 })
      );
    const getApiKey = vi.fn((p: TranscriptionProvider) => (p === 'groq' ? 'gsk' : 'dg'));
    const t = createTranscriber({ getApiKey, getProvider: () => provider, fetchFn });

    expect(await t.transcribe(audio, { vocabulary: '' })).toBe('from groq');
    provider = 'deepgram';
    expect(await t.transcribe(audio, { vocabulary: '' })).toBe('from deepgram');
    expect(getApiKey).toHaveBeenNthCalledWith(1, 'groq');
    expect(getApiKey).toHaveBeenNthCalledWith(2, 'deepgram');
  });

  it('keeps Groq as the provider when none is given', async () => {
    const fetchFn = respond(200, { text: 'hi' });
    await createTranscriber({ getApiKey: () => 'k', fetchFn }).transcribe(audio, {
      vocabulary: '',
    });
    expect(fetchFn.mock.calls[0][0]).toBe('https://api.groq.com/openai/v1/audio/transcriptions');
  });

  it('gives Groq the prose prompt and ignores the term list', async () => {
    const fetchFn = respond(200, { text: 'hi' });
    await createTranscriber({ getApiKey: () => 'k', getProvider: () => 'groq', fetchFn }).transcribe(
      audio,
      { vocabulary: 'Notes about MiniMax.', terms: ['MiniMax'] }
    );
    expect((fetchFn.mock.calls[0][1].body as FormData).get('prompt')).toBe('Notes about MiniMax.');
  });

  it('tests a key against the named provider, not the selected one', async () => {
    const fetchFn = respond(200, {});
    const t = createTranscriber({ getApiKey: () => null, getProvider: () => 'groq', fetchFn });
    await t.testKey('dg', 'deepgram');
    expect(fetchFn.mock.calls[0][0]).toBe('https://api.deepgram.com/v1/projects');
  });
});
