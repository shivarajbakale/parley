import type { ExplainSource } from './types';

/**
 * Streams an explanation from parley-api's `POST /api/explain`. The body
 * carries the selection, which an EventSource GET cannot, so this reads the
 * server-sent events off a plain fetch. Every failure arrives as one `error`
 * event in words the card can show; an abort (the card closed) is silent.
 */

export type ExplainStreamEvent =
  | { type: 'delta'; text: string }
  | { type: 'search'; query: string }
  | { type: 'reset' }
  | { type: 'sources'; sources: ExplainSource[] }
  | { type: 'done' }
  | { type: 'error'; message: string };

/** One round of the thread: earlier turns carry their `answer`, the pending one does not. */
export interface ExplainTurnInput {
  question?: string;
  answer?: string;
}

export interface ExplainClient {
  stream(
    text: string,
    turns: ExplainTurnInput[],
    onEvent: (event: ExplainStreamEvent) => void,
    signal: AbortSignal
  ): Promise<void>;
}

/** Parses one SSE frame's event name and JSON data into a typed event, or null. */
function toEvent(name: string, raw: string): ExplainStreamEvent | null {
  let data: unknown;
  try {
    data = JSON.parse(raw);
  } catch {
    return null;
  }
  const record = (data ?? {}) as Record<string, unknown>;
  switch (name) {
    case 'delta':
      return typeof record.text === 'string' ? { type: 'delta', text: record.text } : null;
    case 'search':
      return typeof record.query === 'string' ? { type: 'search', query: record.query } : null;
    case 'reset':
      return { type: 'reset' };
    case 'sources':
      return Array.isArray(data)
        ? {
            type: 'sources',
            sources: data.filter(
              (s): s is ExplainSource => typeof s?.title === 'string' && typeof s?.url === 'string'
            ),
          }
        : null;
    case 'done':
      return { type: 'done' };
    case 'error':
      return { type: 'error', message: typeof record.message === 'string' ? record.message : 'Something went wrong' };
    default:
      return null;
  }
}

function parseFrame(frame: string): ExplainStreamEvent | null {
  let name = 'message';
  const data: string[] = [];
  for (const line of frame.split('\n')) {
    if (line.startsWith('event:')) name = line.slice(6).trim();
    else if (line.startsWith('data:')) data.push(line.slice(5).trimStart());
  }
  return data.length ? toEvent(name, data.join('\n')) : null;
}

async function errorMessage(response: Response): Promise<string> {
  try {
    const body = (await response.json()) as { error?: unknown };
    if (typeof body.error === 'string') return body.error;
  } catch {
    // Not JSON: fall through to the status line.
  }
  return `The Parley server answered ${response.status}`;
}

export function createExplainClient(deps: { baseUrl: () => string; fetch?: typeof fetch }): ExplainClient {
  const fetchFn = deps.fetch ?? fetch;

  return {
    async stream(text, turns, onEvent, signal) {
      const root = deps.baseUrl().replace(/\/+$/, '');
      const emit = (event: ExplainStreamEvent) => {
        if (!signal.aborted) onEvent(event);
      };

      let response: Response;
      try {
        response = await fetchFn(`${root}/api/explain`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Accept: 'text/event-stream' },
          body: JSON.stringify({ text, turns }),
          signal,
        });
      } catch {
        emit({ type: 'error', message: `Can't reach the Parley server at ${root}` });
        return;
      }
      if (!response.ok || !response.body) {
        emit({ type: 'error', message: await errorMessage(response) });
        return;
      }

      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      let buffer = '';
      let finished = false;
      try {
        for (;;) {
          const { value, done } = await reader.read();
          if (done) break;
          buffer += decoder.decode(value, { stream: true }).replace(/\r\n/g, '\n');
          let boundary: number;
          while ((boundary = buffer.indexOf('\n\n')) !== -1) {
            const event = parseFrame(buffer.slice(0, boundary));
            buffer = buffer.slice(boundary + 2);
            if (!event) continue;
            emit(event);
            if (event.type === 'done' || event.type === 'error') finished = true;
          }
        }
      } catch {
        // The connection dropped, or the card closed and aborted it.
      }
      if (!finished) emit({ type: 'error', message: 'The answer stopped early' });
    },
  };
}
