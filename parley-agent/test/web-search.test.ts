import { describe, expect, it, vi } from 'vitest';
import { searchViaServer } from '../src/mastra/parley/web-search.js';

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });

describe('searchViaServer', () => {
  it('posts the query to the Parley server and returns its results', async () => {
    const fetchFn = vi.fn().mockResolvedValue(json(200, { results: [{ title: 'T', url: 'https://t.dev', snippet: 's' }] }));
    const out = await searchViaServer('http://localhost:3100/', 'pune weather', fetchFn);
    expect(fetchFn.mock.calls[0]![0]).toBe('http://localhost:3100/api/search');
    expect(JSON.parse(fetchFn.mock.calls[0]![1].body)).toEqual({ query: 'pune weather' });
    expect(out).toEqual({ results: [{ title: 'T', url: 'https://t.dev', snippet: 's' }] });
  });

  it('keeps the server soft error for the model to read', async () => {
    const fetchFn = vi.fn().mockResolvedValue(json(200, { results: [], error: 'Search unavailable: EXA_API_KEY is not set' }));
    expect(await searchViaServer('http://x', 'q', fetchFn)).toEqual({ results: [], error: 'Search unavailable: EXA_API_KEY is not set' });
  });

  it('turns a bad status or a dead server into a soft error, never a throw', async () => {
    expect((await searchViaServer('http://x', 'q', vi.fn().mockResolvedValue(json(404, {})))).error).toMatch(/answered 404/);
    expect((await searchViaServer('http://x', 'q', vi.fn().mockRejectedValue(new TypeError('fetch failed')))).error).toMatch(/not running/);
  });
});
