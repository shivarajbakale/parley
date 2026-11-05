import { describe, expect, it, vi } from 'vitest';

import { AgentError, createAgentClient } from '../client';
import type { AgentEvent } from '../events';

const BASE = 'http://localhost:4111';

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status });
}

function sseResponse(chunks: string[]): Response {
  const stream = new ReadableStream({
    start(controller) {
      for (const chunk of chunks) controller.enqueue(new TextEncoder().encode(chunk));
      controller.close();
    },
  });
  return new Response(stream, { headers: { 'Content-Type': 'text/event-stream' } });
}

/** A stream that stays open and says nothing, until cancelled. */
function silentResponse(): Response {
  const stream = new ReadableStream({
    start() {
      // Nothing, ever.
    },
  });
  return new Response(stream);
}

describe('agent client', () => {
  it('starts a run by POSTing the transcript', async () => {
    const fetchFn = vi.fn().mockResolvedValue(jsonResponse({ runId: 'r1' }));
    const client = createAgentClient({ baseUrl: BASE, fetchFn });
    await expect(client.startRun('book dentist tuesday')).resolves.toEqual({ runId: 'r1' });
    expect(fetchFn).toHaveBeenCalledTimes(1);
    const [url, init] = fetchFn.mock.calls[0] as [string, RequestInit];
    expect(url).toBe(`${BASE}/parley/run`);
    expect(init.method).toBe('POST');
    expect(JSON.parse(init.body as string)).toEqual({ transcript: 'book dentist tuesday' });
  });

  it('names start failures: refused port, bad status, missing run id', async () => {
    const refused = createAgentClient({
      baseUrl: BASE,
      fetchFn: vi.fn().mockRejectedValue(new Error('fetch failed')),
    });
    await expect(refused.startRun('hi')).rejects.toMatchObject({
      kind: 'network',
      message: 'refused on :4111',
    } satisfies Partial<AgentError>);

    const server = createAgentClient({ baseUrl: BASE, fetchFn: vi.fn().mockResolvedValue(jsonResponse({}, 500)) });
    await expect(server.startRun('hi')).rejects.toMatchObject({
      kind: 'server',
      message: 'agent answered 500',
    } satisfies Partial<AgentError>);

    const empty = createAgentClient({ baseUrl: BASE, fetchFn: vi.fn().mockResolvedValue(jsonResponse({})) });
    await expect(empty.startRun('hi')).rejects.toMatchObject({
      kind: 'server',
      message: 'bad run reply',
    } satisfies Partial<AgentError>);
  });

  it('reads run status, and treats 404 as a run that is gone', async () => {
    const fetchFn = vi.fn().mockResolvedValue(jsonResponse({ status: 'working', lastStep: 'Thinking…' }));
    const client = createAgentClient({ baseUrl: BASE, fetchFn });
    await expect(client.getRunStatus('r1')).resolves.toEqual({
      status: 'working',
      lastStep: 'Thinking…',
    });
    expect(fetchFn.mock.calls[0][0]).toBe(`${BASE}/parley/runs/r1`);

    const gone = createAgentClient({
      baseUrl: BASE,
      fetchFn: vi.fn().mockResolvedValue(jsonResponse({}, 404)),
    });
    await expect(gone.getRunStatus('r1')).rejects.toMatchObject({
      kind: 'gone',
      message: 'Run ended',
    } satisfies Partial<AgentError>);
  });

  it('approves with the decision, and treats 404 as a run that is gone', async () => {
    const fetchFn = vi.fn().mockResolvedValue(jsonResponse({}));
    const client = createAgentClient({ baseUrl: BASE, fetchFn });
    await client.approve('r1', true);
    const [url, init] = fetchFn.mock.calls[0] as [string, RequestInit];
    expect(url).toBe(`${BASE}/parley/runs/r1/approve`);
    expect(JSON.parse(init.body as string)).toEqual({ approved: true });

    const gone = createAgentClient({
      baseUrl: BASE,
      fetchFn: vi.fn().mockResolvedValue(jsonResponse({}, 404)),
    });
    await expect(gone.approve('r1', false)).rejects.toMatchObject({ kind: 'gone' });
  });

  it('cancels best-effort: gone, refused and broken all resolve', async () => {
    for (const fetchFn of [
      vi.fn().mockResolvedValue(jsonResponse({}, 404)),
      vi.fn().mockRejectedValue(new Error('fetch failed')),
      vi.fn().mockResolvedValue(jsonResponse({}, 500)),
    ]) {
      const client = createAgentClient({ baseUrl: BASE, fetchFn });
      await expect(client.cancelRun('r1')).resolves.toBeUndefined();
    }
    const fetchFn = vi.fn().mockResolvedValue(jsonResponse({}));
    await createAgentClient({ baseUrl: BASE, fetchFn }).cancelRun('r1');
    const [url, init] = fetchFn.mock.calls[0] as [string, RequestInit];
    expect(url).toBe(`${BASE}/parley/runs/r1`);
    expect(init.method).toBe('DELETE');
  });

  it('streams events in order and resolves the terminal one', async () => {
    const seen: AgentEvent[] = [];
    const fetchFn = vi.fn().mockResolvedValue(
      sseResponse([
        'event: step\ndata: {"runId":"r1","seq":1,"text":"One"}\n\n',
        'event: step\ndata: {"runId":"r1","seq":2,"text":"Two"}\n\n',
        'event: completed\ndata: {"runId":"r1","seq":3,"text":"Done"}\n\n',
      ])
    );
    const client = createAgentClient({ baseUrl: BASE, fetchFn });
    await expect(client.streamEvents('r1', event => seen.push(event))).resolves.toEqual({
      kind: 'completed',
      text: 'Done',
    });
    expect(seen.map(event => event.kind)).toEqual(['step', 'step', 'completed']);
    expect(fetchFn.mock.calls[0][0]).toBe(`${BASE}/parley/runs/r1/events`);
  });

  it('drops events for other runs, replays and malformed lines', async () => {
    const seen: AgentEvent[] = [];
    const fetchFn = vi.fn().mockResolvedValue(
      sseResponse([
        'event: step\ndata: {"runId":"r1","seq":1,"text":"One"}\n\n',
        'event: step\ndata: {"runId":"r2","seq":9,"text":"Stranger"}\n\n',
        'event: step\ndata: {"runId":"r1","seq":1,"text":"Replay"}\n\n',
        'event: step\ndata: nope\n\n',
        'event: completed\ndata: {"runId":"r1","seq":2,"text":"Done"}\n\n',
      ])
    );
    const client = createAgentClient({ baseUrl: BASE, fetchFn });
    await expect(client.streamEvents('r1', event => seen.push(event))).resolves.toEqual({
      kind: 'completed',
      text: 'Done',
    });
    expect(seen.map(event => (event.kind === 'step' ? event.text : event.kind))).toEqual([
      'One',
      'completed',
    ]);
  });

  it('fails a silent stream once the idle budget runs out', async () => {
    const fetchFn = vi.fn().mockResolvedValue(silentResponse());
    const client = createAgentClient({ baseUrl: BASE, fetchFn, idleMs: 20 });
    await expect(client.streamEvents('r1', () => {})).rejects.toMatchObject({
      kind: 'timeout',
      message: 'timeout',
    } satisfies Partial<AgentError>);
  });

  it('resolves cancelled when the caller aborts the stream', async () => {
    const controller = new AbortController();
    const fetchFn = vi.fn().mockResolvedValue(silentResponse());
    const client = createAgentClient({ baseUrl: BASE, fetchFn, idleMs: 5000 });
    const outcome = client.streamEvents('r1', () => {}, { signal: controller.signal });
    controller.abort();
    await expect(outcome).resolves.toEqual({ kind: 'cancelled' });
  });

  it('checks health: reachable with servers is ok', async () => {
    const fetchFn = vi.fn().mockResolvedValue(
      jsonResponse({ online: true, mcpServers: [{ name: 'Files', tools: 12 }] })
    );
    const client = createAgentClient({ baseUrl: BASE, fetchFn });
    await expect(client.checkHealth()).resolves.toEqual({
      ok: true,
      message: 'Agent works',
      mcpServers: [{ name: 'Files', tools: 12 }],
    });
    expect(fetchFn.mock.calls[0][0]).toBe(`${BASE}/parley/health`);
  });

  it('checks health: refused, broken and bad bodies name themselves', async () => {
    const refused = createAgentClient({
      baseUrl: BASE,
      fetchFn: vi.fn().mockRejectedValue(new Error('fetch failed')),
    });
    await expect(refused.checkHealth()).resolves.toEqual({
      ok: false,
      message: 'refused on :4111',
      mcpServers: [],
    });

    const broken = createAgentClient({
      baseUrl: BASE,
      fetchFn: vi.fn().mockResolvedValue(jsonResponse({}, 500)),
    });
    await expect(broken.checkHealth()).resolves.toEqual({
      ok: false,
      message: 'agent answered 500',
      mcpServers: [],
    });

    const bad = createAgentClient({
      baseUrl: BASE,
      fetchFn: vi.fn().mockResolvedValue(jsonResponse({ online: true })),
    });
    await expect(bad.checkHealth()).resolves.toEqual({
      ok: false,
      message: 'bad health reply',
      mcpServers: [],
    });
  });

  it('checks health: keeps good servers and drops malformed entries', async () => {
    const fetchFn = vi.fn().mockResolvedValue(
      jsonResponse({
        online: true,
        mcpServers: [{ name: 'Files', tools: 12 }, { name: 'Broken' }, 'nope'],
      })
    );
    const client = createAgentClient({ baseUrl: BASE, fetchFn });
    await expect(client.checkHealth()).resolves.toEqual({
      ok: true,
      message: 'Agent works',
      mcpServers: [{ name: 'Files', tools: 12 }],
    });
  });
});
