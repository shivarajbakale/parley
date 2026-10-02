import express from 'express';
import request from 'supertest';
import { describe, expect, it, vi } from 'vitest';
import type { Chunk } from '../src/explain/events.js';
import { createExplainRouter } from '../src/explain/route.js';

function appWith(stream: (messages: unknown, signal: AbortSignal) => Promise<AsyncIterable<Chunk>>) {
  const app = express();
  app.use(express.json());
  app.use('/api/explain', createExplainRouter({ stream }));
  return app;
}

async function* chunks(...items: Chunk[]) {
  yield* items;
}

describe('POST /api/explain', () => {
  it('streams server-sent events built from the agent stream', async () => {
    const stream = vi.fn().mockResolvedValue(chunks({ type: 'text-delta', payload: { text: 'Hi' } }, { type: 'finish', payload: {} }));
    const res = await request(appWith(stream)).post('/api/explain').send({ text: 'idempotent', turns: [{}] });
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toMatch(/^text\/event-stream/);
    expect(res.text).toBe('event: delta\ndata: {"text":"Hi"}\n\nevent: done\ndata: {}\n\n');
  });

  it('wraps the selection and questions in the tags the agent expects, follow-ups as plain turns', async () => {
    const stream = vi.fn().mockResolvedValue(chunks({ type: 'finish', payload: {} }));
    await request(appWith(stream))
      .post('/api/explain')
      .send({ text: 'x = 1', turns: [{ question: 'why?', answer: 'Because.' }, { question: 'and then?' }] });
    expect(stream.mock.calls[0]![0]).toEqual([
      { role: 'user', content: '<text>\nx = 1\n</text>\n<question>\nwhy?\n</question>' },
      { role: 'assistant', content: 'Because.' },
      { role: 'user', content: 'and then?' },
    ]);
  });

  it('rejects a body without text before opening a stream', async () => {
    const stream = vi.fn();
    const res = await request(appWith(stream)).post('/api/explain').send({ turns: [{}] });
    expect(res.status).toBe(400);
    expect(stream).not.toHaveBeenCalled();
  });

  it('reports a failure to start the agent as an error event', async () => {
    const stream = vi.fn().mockRejectedValue(new Error('MINIMAX_API_KEY missing'));
    const res = await request(appWith(stream)).post('/api/explain').send({ text: 'x', turns: [{}] });
    expect(res.text).toBe('event: error\ndata: {"message":"MINIMAX_API_KEY missing"}\n\n');
  });
});
