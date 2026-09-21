import { describe, expect, it, vi } from 'vitest';

import { createWebSearch, MAX_RESULTS, parseResults } from '../web-search';

const page = `
<div class="result"><h2><a rel="nofollow" class="result__a" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.com%2Fa&amp;rut=x">Example &amp; <b>One</b></a></h2>
<a class="result__snippet" href="x">First <b>snippet</b> here.</a></div>
<div class="result"><a rel="nofollow" class="result__a" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.org%2Fb">Two</a>
<a class="result__snippet" href="x">Second.</a></div>
<div class="result"><a class="result__a" href="https://duckduckgo.com/y.js?ad=1">Sponsored</a></div>`;

describe('web search', () => {
  it('reads titles, real addresses and snippets, and drops ads', () => {
    expect(parseResults(page)).toEqual([
      { title: 'Example & One', url: 'https://example.com/a', snippet: 'First snippet here.' },
      { title: 'Two', url: 'https://example.org/b', snippet: 'Second.' },
    ]);
  });

  it('keeps at most a handful of results', () => {
    const many = Array.from(
      { length: 12 },
      (_, i) => `<a class="result__a" href="https://e.com/${i}">T${i}</a>`
    ).join('');
    expect(parseResults(many)).toHaveLength(MAX_RESULTS);
  });

  it('posts the query as a form and fails on a bad status', async () => {
    const fetchFn = vi.fn().mockResolvedValue(new Response(page));
    await expect(createWebSearch({ fetchFn })('mini max')).resolves.toHaveLength(2);
    expect(fetchFn.mock.calls[0][1].body).toBe('q=mini+max');

    const failing = vi.fn().mockResolvedValue(new Response('', { status: 429 }));
    await expect(createWebSearch({ fetchFn: failing })('x')).rejects.toThrow('search 429');
  });
});
