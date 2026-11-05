import { describe, expect, it, vi } from 'vitest';

import { fetchServerStatus } from '../server-status';

const URL_ = 'http://localhost:3100';

describe('fetchServerStatus', () => {
  it('reports the keys the server holds', async () => {
    const fetchFn = vi
      .fn()
      .mockResolvedValue(new Response(JSON.stringify({ groq: true, deepgram: false, minimax: true })));
    expect(await fetchServerStatus(`${URL_}/`, fetchFn)).toEqual({
      reachable: true,
      url: `${URL_}/`,
      keys: { groq: true, deepgram: false, minimax: true },
    });
    expect(fetchFn.mock.calls[0][0]).toBe(`${URL_}/api/providers/status`);
    expect(fetchFn.mock.calls[0][1].signal).toBeInstanceOf(AbortSignal);
  });

  it('reads a refused connection, an error status or a foreign answer as not reachable', async () => {
    const down = { reachable: false, url: URL_, keys: null };
    expect(await fetchServerStatus(URL_, vi.fn().mockRejectedValue(new TypeError('fetch failed')))).toEqual(down);
    expect(await fetchServerStatus(URL_, vi.fn().mockResolvedValue(new Response('{}', { status: 404 })))).toEqual(down);
    expect(await fetchServerStatus(URL_, vi.fn().mockResolvedValue(new Response('{"groq":"yes"}')))).toEqual(down);
    expect(await fetchServerStatus(URL_, vi.fn().mockResolvedValue(new Response('<html>')))).toEqual(down);
  });
});
