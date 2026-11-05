import { describe, expect, it, vi } from 'vitest';

import { createExplainClient, type ExplainStreamEvent } from '../explain-client';

const BASE = 'http://localhost:3100';

/** A streamed body split exactly at the given boundaries. */
function sseResponse(pieces: string[], init: ResponseInit = {}) {
  const encoder = new TextEncoder();
  const body = new ReadableStream<Uint8Array>({
    start(controller) {
      for (const piece of pieces) controller.enqueue(encoder.encode(piece));
      controller.close();
    },
  });
  return new Response(body, { status: 200, headers: { 'Content-Type': 'text/event-stream' }, ...init });
}

async function run(fetchFn: typeof fetch, signal = new AbortController().signal) {
  const client = createExplainClient({ baseUrl: () => BASE, fetch: fetchFn });
  const events: ExplainStreamEvent[] = [];
  await client.stream('x', [{ question: 'why?' }], (e) => events.push(e), signal);
  return events;
}

describe('explain client', () => {
  it('posts the selection and turns as JSON to /api/explain', async () => {
    const fetchFn = vi.fn().mockResolvedValue(sseResponse(['event: done\ndata: {}\n\n']));
    const client = createExplainClient({ baseUrl: () => `${BASE}/`, fetch: fetchFn });
    const signal = new AbortController().signal;
    await client.stream('x = 1', [{ question: 'why?', answer: 'Because.' }, { question: 'and?' }], () => {}, signal);
    expect(fetchFn).toHaveBeenCalledWith(`${BASE}/api/explain`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'text/event-stream' },
      body: JSON.stringify({ text: 'x = 1', turns: [{ question: 'why?', answer: 'Because.' }, { question: 'and?' }] }),
      signal,
    });
  });

  it('turns every event kind into a typed event, even split mid-frame', async () => {
    const stream = [
      'event: delta\ndata: {"text":"I will se',
      'arch."}\n\nevent: reset\ndata: {}\n\n: keep-alive\n\nevent: search\ndata: {"query":"q"}\n',
      '\nevent: delta\ndata: {"text":"Answer."}\n\nevent: sources\ndata: [{"title":"T","url":"https://t.dev"}]\n\n',
      'event: done\ndata: {}\n\n',
    ];
    expect(await run(vi.fn().mockResolvedValue(sseResponse(stream)))).toEqual([
      { type: 'delta', text: 'I will search.' },
      { type: 'reset' },
      { type: 'search', query: 'q' },
      { type: 'delta', text: 'Answer.' },
      { type: 'sources', sources: [{ title: 'T', url: 'https://t.dev' }] },
      { type: 'done' },
    ]);
  });

  it('passes the server error message through', async () => {
    const events = await run(vi.fn().mockResolvedValue(sseResponse(['event: error\ndata: {"message":"No answer came back. Try again."}\n\n'])));
    expect(events).toEqual([{ type: 'error', message: 'No answer came back. Try again.' }]);
  });

  it('says it cannot reach the server when the request fails', async () => {
    const events = await run(vi.fn().mockRejectedValue(new TypeError('fetch failed')));
    expect(events).toEqual([{ type: 'error', message: `Can't reach the Parley server at ${BASE}` }]);
  });

  it('reports a non-2xx answer with the server message when there is one', async () => {
    const bad = new Response(JSON.stringify({ error: 'Expected { text, turns }' }), { status: 400 });
    expect(await run(vi.fn().mockResolvedValue(bad))).toEqual([{ type: 'error', message: 'Expected { text, turns }' }]);
    const html = new Response('<h1>Bad gateway</h1>', { status: 502 });
    expect(await run(vi.fn().mockResolvedValue(html))).toEqual([{ type: 'error', message: 'The Parley server answered 502' }]);
  });

  it('reports a stream that ends before done', async () => {
    const events = await run(vi.fn().mockResolvedValue(sseResponse(['event: delta\ndata: {"text":"Half"}\n\n'])));
    expect(events).toEqual([
      { type: 'delta', text: 'Half' },
      { type: 'error', message: 'The answer stopped early' },
    ]);
  });

  it('skips unknown events and malformed data instead of failing the answer', async () => {
    const stream = ['event: mystery\ndata: {}\n\nevent: delta\ndata: not json\n\nevent: delta\ndata: {"text":"ok"}\n\nevent: done\ndata: {}\n\n'];
    expect(await run(vi.fn().mockResolvedValue(sseResponse(stream)))).toEqual([
      { type: 'delta', text: 'ok' },
      { type: 'done' },
    ]);
  });

  it('stays silent when aborted, before or during the stream', async () => {
    const abort = new AbortController();
    abort.abort();
    const rejectsOnAbort = vi.fn().mockRejectedValue(new DOMException('aborted', 'AbortError'));
    expect(await run(rejectsOnAbort, abort.signal)).toEqual([]);

    const midway = new AbortController();
    const body = new ReadableStream<Uint8Array>({
      start(controller) {
        controller.enqueue(new TextEncoder().encode('event: delta\ndata: {"text":"Hi"}\n\n'));
        midway.abort();
        controller.error(new DOMException('aborted', 'AbortError'));
      },
    });
    const events = await run(vi.fn().mockResolvedValue(new Response(body, { status: 200 })), midway.signal);
    expect(events).toEqual([]);
  });
});

