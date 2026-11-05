import express from 'express';
import request from 'supertest';
import { describe, expect, it, vi } from 'vitest';
import { createProvidersRouter } from '../src/providers/route.js';

function appWith(env: Record<string, string | undefined>, fetchFn: typeof fetch = vi.fn()) {
  const app = express();
  app.use('/api/providers', createProvidersRouter({ env, fetch: fetchFn }));
  return app;
}

const ok = (body: string, type = 'application/json') =>
  vi.fn().mockResolvedValue(new Response(body, { status: 200, headers: { 'Content-Type': type } }));

describe('/api/providers', () => {
  it('says which keys it has, never the keys', async () => {
    const res = await request(appWith({ GROQ_API_KEY: 'gsk_secret', MINIMAX_API_KEY: ' ' })).get('/api/providers/status');
    expect(res.body).toEqual({ groq: true, deepgram: false, minimax: false, exa: false });
    expect(res.text).not.toContain('gsk_secret');
  });

  it('adds the Groq key, drops the caller Authorization, and passes the body and answer through', async () => {
    const fetchFn = ok('{"text":"hello"}');
    const res = await request(appWith({ GROQ_API_KEY: 'gsk_secret' }, fetchFn))
      .post('/api/providers/groq/openai/v1/audio/transcriptions')
      .set('Authorization', 'Bearer from-the-app')
      .set('Content-Type', 'multipart/form-data; boundary=x')
      .send('--x\r\nbody\r\n--x--');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ text: 'hello' });
    const [url, init] = fetchFn.mock.calls[0]!;
    expect(url).toBe('https://api.groq.com/openai/v1/audio/transcriptions');
    expect(init.headers).toEqual({ Authorization: 'Bearer gsk_secret', 'content-type': 'multipart/form-data; boundary=x' });
    expect(await new Response(init.body).text()).toBe('--x\r\nbody\r\n--x--');
  });

  it('keeps the query on Deepgram calls and uses its Token scheme', async () => {
    const fetchFn = ok('{}');
    await request(appWith({ DEEPGRAM_API_KEY: 'dg' }, fetchFn))
      .post('/api/providers/deepgram/v1/listen?model=nova-3&keyterm=Kubernetes')
      .set('Content-Type', 'audio/webm')
      .send(Buffer.from('audio'));
    const [url, init] = fetchFn.mock.calls[0]!;
    expect(url).toBe('https://api.deepgram.com/v1/listen?model=nova-3&keyterm=Kubernetes');
    expect(init.headers.Authorization).toBe('Token dg');
  });

  it('passes the provider status through, so the app still sees a 401 or 429', async () => {
    const fetchFn = vi.fn().mockResolvedValue(new Response('{"error":"rate"}', { status: 429 }));
    const res = await request(appWith({ MINIMAX_API_KEY: 'mm' }, fetchFn)).post('/api/providers/minimax/v1/chat/completions').send({ a: 1 });
    expect(res.status).toBe(429);
  });

  it('passes the Act agent Anthropic-style MiniMax call on with its version header', async () => {
    const fetchFn = ok('{}');
    await request(appWith({ MINIMAX_API_KEY: 'mm' }, fetchFn))
      .post('/api/providers/minimax/anthropic/v1/messages')
      .set('anthropic-version', '2023-06-01')
      .set('x-api-key', 'placeholder')
      .send({ a: 1 });
    const [url, init] = fetchFn.mock.calls[0]!;
    expect(url).toBe('https://api.minimax.io/anthropic/v1/messages');
    expect(init.headers).toMatchObject({ Authorization: 'Bearer mm', 'anthropic-version': '2023-06-01' });
    expect(init.headers['x-api-key']).toBeUndefined();
  });

  it('answers 503 no_key, naming the variable, when the key is not set', async () => {
    const fetchFn = vi.fn();
    const res = await request(appWith({}, fetchFn)).post('/api/providers/groq/openai/v1/audio/transcriptions').send('x');
    expect(res.status).toBe(503);
    expect(res.body.error.code).toBe('no_key');
    expect(res.body.error.message).toContain('GROQ_API_KEY');
    expect(fetchFn).not.toHaveBeenCalled();
  });

  it('refuses any provider or path it was not built to pass on', async () => {
    const fetchFn = vi.fn();
    const app = appWith({ GROQ_API_KEY: 'g', MINIMAX_API_KEY: 'm' }, fetchFn);
    for (const path of ['/api/providers/groq/openai/v1/models', '/api/providers/openai/v1/chat/completions', '/api/providers/minimax/v1/files']) {
      expect((await request(app).post(path).send('x')).status).toBe(404);
    }
    expect(fetchFn).not.toHaveBeenCalled();
  });

  it('answers 502 when the provider cannot be reached', async () => {
    const res = await request(appWith({ GROQ_API_KEY: 'g' }, vi.fn().mockRejectedValue(new TypeError('fetch failed'))))
      .post('/api/providers/groq/openai/v1/audio/transcriptions')
      .send('x');
    expect(res.status).toBe(502);
    expect(res.body.error.code).toBe('unreachable');
  });
});
