import { describe, expect, it, vi } from 'vitest';

import { createTranscriber, TranscribeError } from '../transcriber';

const audio = { data: new Uint8Array([1, 2, 3]).buffer, mimeType: 'audio/webm' };
const SERVER = 'http://localhost:3100';

function respond(status: number, body: unknown) {
  return vi.fn().mockResolvedValue(
    new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } })
  );
}

const make = (fetchFn: typeof fetch) => createTranscriber({ serverUrl: () => SERVER, fetchFn });

describe('transcriber', () => {
  it('posts the audio to Groq through the Parley server, with no key, model, language and prompt', async () => {
    const fetchFn = respond(200, { text: ' hello world ' });
    const text = await make(fetchFn).transcribe(audio, { vocabulary: 'Parley, Groq' });

    expect(text).toBe('hello world');
    const [url, init] = fetchFn.mock.calls[0];
    expect(url).toBe(`${SERVER}/api/providers/groq/openai/v1/audio/transcriptions`);
    expect(init.method).toBe('POST');
    expect(init.headers).toBeUndefined();
    const form = init.body as FormData;
    expect(form.get('model')).toBe('whisper-large-v3-turbo');
    expect(form.get('language')).toBe('en');
    expect(form.get('response_format')).toBe('json');
    expect(form.get('prompt')).toBe('Parley, Groq');
    expect(form.get('file')).toBeInstanceOf(Blob);
  });

  it('reads the server address on every call, trailing slash or not', async () => {
    const fetchFn = vi.fn().mockImplementation(async () => new Response(JSON.stringify({ text: 'hi' })));
    let server = 'http://localhost:3100/';
    const t = createTranscriber({ serverUrl: () => server, fetchFn });
    await t.transcribe(audio, { vocabulary: '' });
    server = 'http://127.0.0.1:4000';
    await t.transcribe(audio, { vocabulary: '' });
    expect(fetchFn.mock.calls[0][0]).toBe('http://localhost:3100/api/providers/groq/openai/v1/audio/transcriptions');
    expect(fetchFn.mock.calls[1][0]).toBe('http://127.0.0.1:4000/api/providers/groq/openai/v1/audio/transcriptions');
  });

  it('omits the prompt when the vocabulary is blank', async () => {
    const fetchFn = respond(200, { text: 'hi' });
    await make(fetchFn).transcribe(audio, { vocabulary: '   ' });
    expect((fetchFn.mock.calls[0][1].body as FormData).has('prompt')).toBe(false);
  });

  it('says the key is missing on the server when the server answers no_key', async () => {
    const fetchFn = respond(503, { error: { code: 'no_key', message: 'GROQ_API_KEY is not set' } });
    await expect(make(fetchFn).transcribe(audio, { vocabulary: '' })).rejects.toMatchObject({
      kind: 'no_key',
      message: 'No Groq key on the Parley server',
    });
  });

  it.each([
    [401, 'auth', 'Invalid Groq key'],
    [429, 'rate_limit', 'Rate limited'],
    [500, 'server', 'Groq error'],
    [502, 'network', 'No connection'],
    [503, 'server', 'Groq error'],
  ])('maps HTTP %i to %s', async (status, kind, message) => {
    const error = await make(respond(status, {})).transcribe(audio, { vocabulary: '' }).catch(e => e);
    expect(error).toBeInstanceOf(TranscribeError);
    expect(error).toMatchObject({ kind, message });
  });

  it('says the Parley server is not running when the connection is refused', async () => {
    const fetchFn = vi.fn().mockRejectedValue(new TypeError('fetch failed'));
    await expect(make(fetchFn).transcribe(audio, { vocabulary: '' })).rejects.toMatchObject({
      kind: 'offline',
      message: 'Parley server not running',
    });
  });

  it('maps a timed-out fetch to network', async () => {
    const fetchFn = vi.fn().mockRejectedValue(new DOMException('aborted', 'TimeoutError'));
    await expect(make(fetchFn).transcribe(audio, { vocabulary: '' })).rejects.toMatchObject({
      kind: 'network',
      message: 'No connection',
    });
  });

  it('gives the transcribe request an abort signal', async () => {
    const fetchFn = respond(200, { text: 'hi' });
    await make(fetchFn).transcribe(audio, { vocabulary: '' });
    expect(fetchFn.mock.calls[0][1].signal).toBeInstanceOf(AbortSignal);
  });

  it('maps a non-JSON 200 body to a server error, not a raw SyntaxError', async () => {
    const fetchFn = vi.fn().mockResolvedValue(new Response('<html>oops</html>', { status: 200 }));
    const error = await make(fetchFn).transcribe(audio, { vocabulary: '' }).catch(e => e);
    expect(error).toBeInstanceOf(TranscribeError);
    expect(error).toMatchObject({ kind: 'server', message: 'Groq error' });
  });
});
