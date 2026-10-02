import { createTool } from '@mastra/core/tools';
import Exa from 'exa-js';
import { z } from 'zod';

/**
 * The web search the screen explainer reaches for when an answer depends on
 * current or obscure facts. Every failure is soft: the model gets an `error`
 * it can read and answers from what it knows instead.
 */

export const MAX_RESULTS = 5;
/** Per result: enough for the model to ground a sentence, not a page of tokens. */
export const SNIPPET_CHARS = 600;

const resultSchema = z.object({ title: z.string(), url: z.string(), snippet: z.string() });
const outputSchema = z.object({ results: z.array(resultSchema), error: z.string().optional() });

type SearchOutput = z.infer<typeof outputSchema>;

/** The slice of the Exa client this tool uses, so tests can hand in a fake. */
export interface ExaSearcher {
  search(
    query: string,
    options: { numResults: number; contents: { highlights: true } },
  ): Promise<{ results: { title: string | null; url: string; highlights?: string[] }[] }>;
}

function snippet(highlights: string[] | undefined): string {
  const joined = (highlights ?? []).join(' … ').trim();
  return joined.length > SNIPPET_CHARS ? `${joined.slice(0, SNIPPET_CHARS)}…` : joined;
}

export async function searchWeb(query: string, exa: ExaSearcher | null): Promise<SearchOutput> {
  if (!exa) return { results: [], error: 'Search unavailable: EXA_API_KEY is not set' };
  try {
    const response = await exa.search(query, { numResults: MAX_RESULTS, contents: { highlights: true } });
    return {
      results: response.results.map((r) => ({
        title: r.title || r.url,
        url: r.url,
        snippet: snippet(r.highlights),
      })),
    };
  } catch (error) {
    return { results: [], error: `Search failed: ${(error as Error).message}` };
  }
}

function exaFromEnv(): ExaSearcher | null {
  const key = process.env.EXA_API_KEY?.trim();
  return key ? new Exa(key) : null;
}

export const exaSearchTool = createTool({
  id: 'web-search',
  description:
    'Search the web with Exa. Returns the top results as title, url and a relevant snippet.',
  inputSchema: z.object({ query: z.string().describe('A short search query.') }),
  outputSchema,
  execute: async ({ query }) => searchWeb(query, exaFromEnv()),
});
