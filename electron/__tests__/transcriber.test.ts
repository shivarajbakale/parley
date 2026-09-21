import { describe, expect, it, vi } from 'vitest';

import { createTranscriber, TranscribeError } from '../transcriber';

const audio = { data: new Uint8Array([1, 2, 3]).buffer, mimeType: 'audio/webm' };

function respond(status: number, body: unknown) {
  return vi.fn().mockResolvedValue(
    new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } })
  );
}

describe('transcriber', () => {
  it('posts the audio to Groq with model, language and prompt', async () => {
    const fetchFn = respond(200, { text: ' hello world ' });
    const t = createTranscriber({ getApiKey: () => 'gsk_test', fetchFn });

    const text = await t.transcribe(audio, { vocabulary: 'Parley, Groq' });

    expect(text).toBe('hello world');
    const [url, init] = fetchFn.mock.calls[0];
    expect(url).toBe('https://api.groq.com/openai/v1/audio/transcriptions');
    expect(init.method).toBe('POST');
    expect(init.headers.Authorization).toBe('Bearer gsk_test');
    const form = init.body as FormData;
    expect(form.get('model')).toBe('whisper-large-v3-turbo');
    expect(form.get('language')).toBe('en');
    expect(form.get('response_format')).toBe('json');
    expect(form.get('prompt')).toBe('Parley, Groq');
    expect(form.get('file')).toBeInstanceOf(Blob);
  });

  it('omits the prompt when the vocabulary is blank', async () => {
    const fetchFn = respond(200, { text: 'hi' });
    const t = createTranscriber({ getApiKey: () => 'k', fetchFn });
    await t.transcribe(audio, { vocabulary: '   ' });
    expect((fetchFn.mock.calls[0][1].body as FormData).has('prompt')).toBe(false);
  });

  it('fails with no_key before any request when no key is stored', async () => {
    const fetchFn = vi.fn();
    const t = createTranscriber({ getApiKey: () => null, fetchFn });
    await expect(t.transcribe(audio, { vocabulary: '' })).rejects.toMatchObject({ kind: 'no_key' });
    expect(fetchFn).not.toHaveBeenCalled();
  });

  it.each([
    [401, 'auth', 'Invalid API key'],
    [429, 'rate_limit', 'Rate limited'],
    [500, 'server', 'Groq error'],
  ])('maps HTTP %i to %s', async (status, kind, message) => {
    const t = createTranscriber({ getApiKey: () => 'k', fetchFn: respond(status, {}) });
    const error = await t.transcribe(audio, { vocabulary: '' }).catch((e) => e);
    expect(error).toBeInstanceOf(TranscribeError);
    expect(error).toMatchObject({ kind, message });
  });

  it('maps a rejected fetch to network', async () => {
    const fetchFn = vi.fn().mockRejectedValue(new TypeError('fetch failed'));
    const t = createTranscriber({ getApiKey: () => 'k', fetchFn });
    await expect(t.transcribe(audio, { vocabulary: '' })).rejects.toMatchObject({
      kind: 'network',
      message: 'No connection',
    });
  });

  it('tests a key against the models endpoint', async () => {
    const fetchFn = respond(200, { data: [] });
    const t = createTranscriber({ getApiKey: () => null, fetchFn });
    expect(await t.testKey('gsk_new')).toEqual({ ok: true, message: 'Key works' });
    const [url, init] = fetchFn.mock.calls[0];
    expect(url).toBe('https://api.groq.com/openai/v1/models');
    expect(init.headers.Authorization).toBe('Bearer gsk_new');
  });

  it('reports a rejected key', async () => {
    const t = createTranscriber({ getApiKey: () => null, fetchFn: respond(401, {}) });
    expect(await t.testKey('bad')).toEqual({ ok: false, message: 'Invalid API key' });
  });
});
