import { describe, expect, it, vi } from 'vitest';
import { MAX_RESULTS, SNIPPET_CHARS, searchWeb } from '../src/mastra/tools/exa-search.js';

const hit = (n: number, highlights: string[] = [`highlight ${n}`]) => ({
  id: `id-${n}`,
  title: `Title ${n}`,
  url: `https://example.com/${n}`,
  highlights,
});

describe('searchWeb', () => {
  it('asks Exa for highlights and shapes results into title, url, snippet', async () => {
    const search = vi.fn().mockResolvedValue({ results: [hit(1, ['a', 'b'])] });
    const out = await searchWeb('idempotent', { search });
    expect(search).toHaveBeenCalledWith('idempotent', {
      numResults: MAX_RESULTS,
      contents: { highlights: true },
    });
    expect(out).toEqual({
      results: [{ title: 'Title 1', url: 'https://example.com/1', snippet: 'a … b' }],
    });
  });

  it('caps snippets and tolerates missing titles and highlights', async () => {
    const search = vi.fn().mockResolvedValue({
      results: [{ id: 'x', title: null, url: 'https://x.dev', highlights: ['z'.repeat(SNIPPET_CHARS + 50)] }, { id: 'y', title: 'Y', url: 'https://y.dev' }],
    });
    const { results } = await searchWeb('q', { search });
    expect(results[0]).toEqual({ title: 'https://x.dev', url: 'https://x.dev', snippet: `${'z'.repeat(SNIPPET_CHARS)}…` });
    expect(results[1]).toEqual({ title: 'Y', url: 'https://y.dev', snippet: '' });
  });

  it('never throws: a failed search comes back as an error the model can read', async () => {
    const search = vi.fn().mockRejectedValue(new Error('401 invalid key'));
    expect(await searchWeb('q', { search })).toEqual({ results: [], error: 'Search failed: 401 invalid key' });
  });

  it('reports a missing key without calling Exa', async () => {
    expect(await searchWeb('q', null)).toEqual({ results: [], error: 'Search unavailable: EXA_API_KEY is not set' });
  });
});
