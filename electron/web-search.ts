/**
 * The web search tool Explain hands to the model. DuckDuckGo's HTML endpoint
 * needs no key; it is unofficial, so every failure here is soft: the model is
 * told the search failed and answers from what it knows.
 */

const ENDPOINT = 'https://html.duckduckgo.com/html/';
const SEARCH_TIMEOUT_MS = 8000;
export const MAX_RESULTS = 5;

export interface SearchResult {
  title: string;
  url: string;
  snippet: string;
}

export type WebSearch = (query: string) => Promise<SearchResult[]>;

const ENTITIES: Record<string, string> = {
  '&amp;': '&',
  '&lt;': '<',
  '&gt;': '>',
  '&quot;': '"',
  '&#x27;': "'",
  '&#39;': "'",
};

function text(html: string): string {
  return html
    .replace(/<[^>]*>/g, '')
    .replace(/&(amp|lt|gt|quot|#x27|#39);/g, entity => ENTITIES[entity] ?? entity)
    .replace(/\s+/g, ' ')
    .trim();
}

/** Result links go through a redirector whose `uddg` parameter is the real address. */
function realUrl(href: string): string {
  try {
    const url = new URL(href, 'https://duckduckgo.com');
    return url.searchParams.get('uddg') ?? url.toString();
  } catch {
    return href;
  }
}

export function parseResults(html: string): SearchResult[] {
  const results: SearchResult[] = [];
  const blocks = html.split(/class="result__a"/).slice(1);
  for (const block of blocks) {
    const href = /href="([^"]+)"/.exec(block)?.[1];
    const title = /^[^>]*>([\s\S]*?)<\/a>/.exec(block)?.[1];
    const snippet = /class="result__snippet"[^>]*>([\s\S]*?)<\/a>/.exec(block)?.[1] ?? '';
    if (!href || !title) continue;
    const url = realUrl(href);
    // Sponsored results carry a tracking address, not a page.
    if (!/^https?:\/\//.test(url) || url.includes('duckduckgo.com/y.js')) continue;
    results.push({ title: text(title), url, snippet: text(snippet) });
    if (results.length === MAX_RESULTS) break;
  }
  return results;
}

export function createWebSearch(deps: { fetchFn?: typeof fetch } = {}): WebSearch {
  const fetchFn = deps.fetchFn ?? fetch;
  return async query => {
    const response = await fetchFn(ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': 'Mozilla/5.0 (Macintosh) Parley',
      },
      body: new URLSearchParams({ q: query }).toString(),
      signal: AbortSignal.timeout(SEARCH_TIMEOUT_MS),
    });
    if (!response.ok) throw new Error(`search ${response.status}`);
    return parseResults(await response.text());
  };
}
