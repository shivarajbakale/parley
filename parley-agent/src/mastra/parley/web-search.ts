import { createTool } from '@mastra/core/tools';
import { z } from 'zod';

import type { McpCatalogEntry } from './mcp';

/**
 * Web search, the agent's one built-in tool. It asks the Parley server
 * (`PARLEY_SERVER_URL`, set by the desktop app at spawn), which holds the
 * Exa key — the agent never sees it. A read, so it runs without a tap.
 * Every failure is soft: the model gets an `error` it can say out loud.
 */

/** Underscore-prefixed so the pill's step reads "Using Web search…". */
export const WEB_SEARCH_TOOL = 'parley_web_search';
/** The Agent tab's row for it, next to the MCP servers. */
export const WEB_SEARCH_CATALOG: McpCatalogEntry = { name: 'web search', tools: 1 };

const TIMEOUT_MS = 15_000;

const resultSchema = z.object({ title: z.string(), url: z.string(), snippet: z.string() });
const outputSchema = z.object({ results: z.array(resultSchema), error: z.string().optional() });
type SearchOutput = z.infer<typeof outputSchema>;

export async function searchViaServer(
  serverUrl: string,
  query: string,
  fetchFn: typeof fetch = fetch
): Promise<SearchOutput> {
  try {
    const response = await fetchFn(`${serverUrl.replace(/\/+$/, '')}/api/search`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ query }),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    if (!response.ok) return { results: [], error: `Search failed: Parley server answered ${response.status}` };
    const body = (await response.json()) as SearchOutput;
    return { results: body.results ?? [], ...(body.error ? { error: body.error } : {}) };
  } catch {
    return { results: [], error: 'Search failed: the Parley server is not running' };
  }
}

export function createWebSearchTool(serverUrl: string) {
  return createTool({
    id: WEB_SEARCH_TOOL,
    description:
      'Search the web for current facts: news, weather, prices, scores, people, places, how-tos. Returns the top results as title, url and snippet.',
    inputSchema: z.object({ query: z.string().describe('A short search query.') }),
    outputSchema,
    execute: async ({ query }) => searchViaServer(serverUrl, query),
  });
}
