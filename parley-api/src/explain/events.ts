import type { Finding } from '../mastra/agents/screen-explainer.js';
import { createMarkupFilter } from './markup-filter.js';
import { createSourceLineFilter } from './source-filter.js';

/**
 * Turns the agent's chunk stream into the few events the Explain card needs.
 *
 * Text streams as it arrives. When a step that already wrote text then calls
 * a tool, that text was the model talking about searching, not the answer,
 * so `reset` tells the card to drop everything since the last reset. Sources
 * come from what the search tool actually returned, never from the model.
 *
 * A run that ends with nothing shown ends in `empty`, carrying what the
 * searches found, so the route can retry once without tools.
 */

export const MAX_SOURCES = 3;

/** The slice of a Mastra stream chunk read here. */
export interface Chunk {
  type: string;
  payload?: unknown;
}

export interface Source {
  title: string;
  url: string;
}

export type ExplainEvent =
  | { event: 'delta'; data: { text: string } }
  | { event: 'reset'; data: Record<string, never> }
  | { event: 'search'; data: { query: string } }
  | { event: 'sources'; data: Source[] }
  | { event: 'done'; data: Record<string, never> }
  | { event: 'error'; data: { message: string } }
  /** Never sent: the route retries on it, or turns it into `error`. */
  | { event: 'empty'; data: { found: Finding[] } };

const SEARCH_TOOL = 'webSearch';

interface ToolPayload {
  toolCallId?: string;
  toolName?: string;
  args?: { query?: unknown };
  result?: { results?: { title?: unknown; url?: unknown; snippet?: unknown }[] };
}

function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (typeof error === 'string') return error;
  return 'Something went wrong';
}

/** `found` seeds the sources with what an earlier, empty run searched. */
export async function* explainEvents(chunks: AsyncIterable<Chunk>, found: Finding[] = []): AsyncGenerator<ExplainEvent> {
  let markup = createMarkupFilter();
  let filter = createSourceLineFilter();
  let wroteText = false;
  /** Whether anything at all reached the card since the last reset. */
  let answered = false;
  /** Mastra emits each tool-call chunk twice; announce each search once. */
  const announced = new Set<string>();
  const sources = new Map<string, Finding>(found.map((f) => [f.url, f]));

  for await (const chunk of chunks) {
    const payload = (chunk.payload ?? {}) as ToolPayload & { text?: string; error?: unknown };
    switch (chunk.type) {
      case 'text-delta': {
        const cleaned = markup.push(payload.text ?? '');
        const text = filter.push(cleaned.text);
        if (text) {
          wroteText = true;
          answered = true;
          yield { event: 'delta', data: { text } };
        }
        // A tool call written as text: whatever led up to it was talk about searching.
        if (cleaned.sawCall && wroteText) {
          wroteText = false;
          answered = false;
          filter = createSourceLineFilter();
          yield { event: 'reset', data: {} };
        }
        break;
      }
      case 'tool-call-input-streaming-start':
      case 'tool-call':
        if (wroteText) {
          wroteText = false;
          answered = false;
          yield { event: 'reset', data: {} };
        }
        markup = createMarkupFilter();
        filter = createSourceLineFilter();
        if (
          chunk.type === 'tool-call' &&
          payload.toolName === SEARCH_TOOL &&
          typeof payload.args?.query === 'string' &&
          !announced.has(payload.toolCallId ?? payload.args.query)
        ) {
          announced.add(payload.toolCallId ?? payload.args.query);
          yield { event: 'search', data: { query: payload.args.query } };
        }
        break;
      case 'tool-result':
        if (payload.toolName !== SEARCH_TOOL) break;
        for (const r of payload.result?.results ?? []) {
          if (typeof r.url === 'string' && !sources.has(r.url)) {
            sources.set(r.url, {
              title: typeof r.title === 'string' ? r.title : r.url,
              url: r.url,
              snippet: typeof r.snippet === 'string' ? r.snippet : '',
            });
          }
        }
        break;
      case 'error':
        yield { event: 'error', data: { message: errorMessage(payload.error) } };
        return;
      case 'abort':
        return;
    }
  }

  const rest = filter.push(markup.end()) + filter.end();
  if (rest) {
    answered = true;
    yield { event: 'delta', data: { text: rest } };
  }
  if (!answered) {
    yield { event: 'empty', data: { found: [...sources.values()] } };
    return;
  }
  if (sources.size > 0) {
    yield { event: 'sources', data: [...sources.values()].slice(0, MAX_SOURCES).map(({ title, url }) => ({ title, url })) };
  }
  yield { event: 'done', data: {} };
}
