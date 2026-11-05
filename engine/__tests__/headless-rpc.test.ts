import { afterEach, describe, expect, it, vi } from 'vitest';

import { createRpc, RPC_ERRORS, RpcError, type RpcDeps } from '../headless/rpc';

function setup(overrides: Partial<RpcDeps> = {}) {
  const written: Record<string, unknown>[] = [];
  const deps: RpcDeps = {
    write: (line) => {
      expect(line.endsWith('\n')).toBe(true);
      expect(line.slice(0, -1)).not.toContain('\n');
      written.push(JSON.parse(line));
    },
    onRequest: vi.fn().mockResolvedValue({ ok: true }),
    onNotify: vi.fn(),
    onProtocolError: vi.fn(),
    ...overrides,
  };
  return { rpc: createRpc(deps), deps, written };
}

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

afterEach(() => {
  vi.useRealTimers();
});

describe('headless rpc', () => {
  it('frames a notification as one JSON line without an id', () => {
    const { rpc, written } = setup();
    rpc.notify('hud.phase', { phase: 'listening' });
    expect(written).toEqual([{ jsonrpc: '2.0', method: 'hud.phase', params: { phase: 'listening' } }]);
  });

  it('keeps a multi-line string inside one frame', () => {
    const { rpc, written } = setup();
    rpc.notify('transcript', { text: 'line one\nline two' });
    expect(written[0]).toMatchObject({ params: { text: 'line one\nline two' } });
  });

  it('matches a response to its request by id', async () => {
    const { rpc, written } = setup();
    const first = rpc.request('paste.text', { text: 'a' });
    const second = rpc.request('paste.text', { text: 'b' });
    const [a, b] = written as { id: number }[];
    rpc.receive(JSON.stringify({ jsonrpc: '2.0', id: b.id, result: 'second' }));
    rpc.receive(JSON.stringify({ jsonrpc: '2.0', id: a.id, result: 'first' }));
    await expect(first).resolves.toBe('first');
    await expect(second).resolves.toBe('second');
  });

  it('rejects a request the other side answered with an error', async () => {
    const { rpc, written } = setup();
    const pending = rpc.request('paste.text', { text: 'a' });
    const { id } = written[0] as { id: number };
    rpc.receive(JSON.stringify({ jsonrpc: '2.0', id, error: { code: -32000, message: 'No focused field' } }));
    await expect(pending).rejects.toThrow('No focused field');
  });

  it('times a request out instead of waiting forever', async () => {
    vi.useFakeTimers();
    const { rpc } = setup({ timeoutMs: 50 });
    const pending = rpc.request('paste.text', { text: 'a' });
    vi.advanceTimersByTime(51);
    await expect(pending).rejects.toThrow('paste.text timed out after 50 ms');
  });

  it('answers an incoming request with the handler result', async () => {
    const onRequest = vi.fn().mockResolvedValue({ engineVersion: 'dev' });
    const { rpc, written } = setup({ onRequest });
    rpc.receive(JSON.stringify({ jsonrpc: '2.0', id: 7, method: 'hello', params: { protocolVersion: 1 } }));
    await flush();
    expect(onRequest).toHaveBeenCalledWith('hello', { protocolVersion: 1 });
    expect(written).toEqual([{ jsonrpc: '2.0', id: 7, result: { engineVersion: 'dev' } }]);
  });

  it('answers a failing handler with its error code and message', async () => {
    const onRequest = vi.fn().mockRejectedValue(new RpcError('Unknown method nope', RPC_ERRORS.methodNotFound));
    const { rpc, written } = setup({ onRequest });
    rpc.receive(JSON.stringify({ jsonrpc: '2.0', id: 3, method: 'nope' }));
    await flush();
    expect(written).toEqual([
      { jsonrpc: '2.0', id: 3, error: { code: RPC_ERRORS.methodNotFound, message: 'Unknown method nope' } },
    ]);
  });

  it('routes a notification to onNotify and sends nothing back', () => {
    const { rpc, deps, written } = setup();
    rpc.receive(JSON.stringify({ jsonrpc: '2.0', method: 'key', params: { type: 'down', key: 'AltRight', time: 1 } }));
    expect(deps.onNotify).toHaveBeenCalledWith('key', { type: 'down', key: 'AltRight', time: 1 });
    expect(written).toEqual([]);
  });

  it('reports garbage and unknown response ids without throwing', () => {
    const { rpc, deps } = setup();
    expect(() => rpc.receive('{not json')).not.toThrow();
    expect(() => rpc.receive(JSON.stringify({ jsonrpc: '2.0', id: 99, result: 1 }))).not.toThrow();
    expect(() => rpc.receive('[1,2]')).not.toThrow();
    expect(deps.onProtocolError).toHaveBeenCalledTimes(3);
  });

  it('ignores blank lines', () => {
    const { rpc, deps } = setup();
    rpc.receive('   ');
    expect(deps.onProtocolError).not.toHaveBeenCalled();
  });

  it('a notification handler that throws is reported, not propagated', () => {
    const { rpc, deps } = setup({
      onNotify: () => {
        throw new Error('boom');
      },
    });
    expect(() => rpc.receive(JSON.stringify({ jsonrpc: '2.0', method: 'key' }))).not.toThrow();
    expect(deps.onProtocolError).toHaveBeenCalledWith('notification key failed: boom');
  });

  it('close rejects every request still waiting', async () => {
    const { rpc } = setup();
    const pending = rpc.request('paste.text', { text: 'a' });
    rpc.close('shell closed the pipe');
    await expect(pending).rejects.toThrow('shell closed the pipe');
  });
});
