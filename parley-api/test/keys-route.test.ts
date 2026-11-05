import { mkdtempSync, readFileSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import express from 'express';
import request from 'supertest';
import { beforeEach, describe, expect, it } from 'vitest';
import { createKeysRouter, loadKeyFile, validKey } from '../src/providers/keys.js';
import { createProvidersRouter } from '../src/providers/route.js';

let file: string;
let env: Record<string, string | undefined>;

function app() {
  const server = express();
  server.use('/api/providers/keys', express.json({ limit: '4kb' }), createKeysRouter({ env, file }));
  server.use('/api/providers', createProvidersRouter({ env }));
  return server;
}

beforeEach(() => {
  file = path.join(mkdtempSync(path.join(tmpdir(), 'keys-')), 'data', 'provider-keys.json');
  env = { GROQ_API_KEY: 'gsk_from_env_file' };
});

describe('/api/providers/keys', () => {
  it('saves a key, uses it at once, and never echoes it', async () => {
    const res = await request(app()).put('/api/providers/keys/deepgram').send({ key: '  dg_secret_123456  ' });
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ deepgram: true });
    expect(res.text).not.toContain('dg_secret');
    expect(env.DEEPGRAM_API_KEY).toBe('dg_secret_123456');
    const status = await request(app()).get('/api/providers/status');
    expect(status.body).toMatchObject({ groq: true, deepgram: true });
  });

  it('writes the file readable only by the server user', async () => {
    await request(app()).put('/api/providers/keys/minimax').send({ key: 'sk-cp-abcdefgh' });
    expect(JSON.parse(readFileSync(file, 'utf8'))).toEqual({ MINIMAX_API_KEY: 'sk-cp-abcdefgh' });
    expect(statSync(file).mode & 0o777).toBe(0o600);
  });

  it('a saved key wins over .env after a restart', async () => {
    await request(app()).put('/api/providers/keys/groq').send({ key: 'gsk_from_the_app' });
    const fresh: Record<string, string | undefined> = { GROQ_API_KEY: 'gsk_from_env_file' };
    expect(loadKeyFile(file, fresh)).toBe(1);
    expect(fresh.GROQ_API_KEY).toBe('gsk_from_the_app');
  });

  it('remove stays removed across a restart, even with the key in .env', async () => {
    const res = await request(app()).delete('/api/providers/keys/groq');
    expect(res.body).toEqual({ groq: false });
    const fresh: Record<string, string | undefined> = { GROQ_API_KEY: 'gsk_from_env_file' };
    loadKeyFile(file, fresh);
    expect(fresh.GROQ_API_KEY).toBe('');
    const status = await request(app()).get('/api/providers/status');
    expect(status.body.groq).toBe(false);
  });

  it('refuses unknown providers and things that are not keys', async () => {
    expect((await request(app()).put('/api/providers/keys/openai').send({ key: 'sk-abcdefghijk' })).status).toBe(404);
    expect((await request(app()).put('/api/providers/keys/groq').send({ key: 'has spaces in it' })).status).toBe(400);
    expect((await request(app()).put('/api/providers/keys/groq').send({ key: 'short' })).status).toBe(400);
    expect((await request(app()).put('/api/providers/keys/groq').send({})).status).toBe(400);
    expect(env.GROQ_API_KEY).toBe('gsk_from_env_file');
  });

  it('a missing or broken file loads nothing', () => {
    expect(loadKeyFile(path.join(path.dirname(file), 'nope.json'), {})).toBe(0);
  });

  it('validKey', () => {
    expect(validKey('gsk_abcdefgh')).toBe(true);
    expect(validKey('line\nbreak123')).toBe(false);
    expect(validKey(42)).toBe(false);
  });
});
