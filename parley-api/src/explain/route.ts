import { Router, type Request, type Response } from 'express';
import { z } from 'zod';
import type { Finding } from '../mastra/agents/screen-explainer.js';
import { explainEvents, type Chunk, type ExplainEvent } from './events.js';

/**
 * POST /api/explain: the selection and its turns in, server-sent events out.
 * A POST, not an EventSource GET, because the selection rides in the body.
 * Closing the connection aborts the model run, so a dismissed card stops
 * spending tokens.
 *
 * A run that ends with no answer is retried once without tools, handed what
 * its searches found; only if that is empty too does the card see an error.
 */

const HEARTBEAT_MS = 15_000;
export const NO_ANSWER = 'No answer came back. Try again.';

const bodySchema = z.object({
  text: z.string().min(1),
  turns: z.array(z.object({ question: z.string().optional(), answer: z.string().optional() })).min(1),
});

type Body = z.infer<typeof bodySchema>;

/** A union, not one role field, so it narrows to the model message types the agent takes. */
export type Message = { role: 'user'; content: string } | { role: 'assistant'; content: string };

/** `retry` is set on the second run: answer now, no tools, from these findings. */
export type ExplainStream = (
  messages: Message[],
  signal: AbortSignal,
  retry?: { found: Finding[] },
) => Promise<AsyncIterable<Chunk>>;

/** Only the first turn carries the selection; later turns are follow-ups on it. */
export function buildMessages({ text, turns }: Body): Message[] {
  const messages: Message[] = [];
  turns.forEach((turn, i) => {
    const content =
      i === 0
        ? turn.question
          ? `<text>\n${text}\n</text>\n<question>\n${turn.question}\n</question>`
          : `<text>\n${text}\n</text>`
        : (turn.question ?? '');
    messages.push({ role: 'user', content });
    if (turn.answer !== undefined) messages.push({ role: 'assistant', content: turn.answer });
  });
  return messages;
}

function send(res: Response, { event, data }: ExplainEvent) {
  res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
}

export function createExplainRouter(deps: { stream: ExplainStream }): Router {
  const router = Router();

  router.post('/', async (req: Request, res: Response) => {
    const parsed = bodySchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: 'Expected { text, turns: [{ question?, answer? }, ...] }' });
      return;
    }

    res.writeHead(200, {
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-cache, no-transform',
      Connection: 'keep-alive',
      'X-Accel-Buffering': 'no',
    });
    res.flushHeaders();

    const abort = new AbortController();
    res.on('close', () => {
      if (!res.writableFinished) abort.abort();
    });
    const heartbeat = setInterval(() => res.write(': keep-alive\n\n'), HEARTBEAT_MS);

    try {
      const messages = buildMessages(parsed.data);
      let retry: { found: Finding[] } | undefined;
      for (;;) {
        const chunks = await deps.stream(messages, abort.signal, retry);
        let empty: Finding[] | undefined;
        for await (const event of explainEvents(chunks, retry?.found)) {
          if (abort.signal.aborted) return;
          if (event.event === 'empty') empty = event.data.found;
          else send(res, event);
        }
        if (!empty || abort.signal.aborted) break;
        if (retry) {
          send(res, { event: 'error', data: { message: NO_ANSWER } });
          break;
        }
        retry = { found: empty };
      }
    } catch (error) {
      if (!abort.signal.aborted) {
        send(res, { event: 'error', data: { message: error instanceof Error ? error.message : 'Something went wrong' } });
      }
    } finally {
      clearInterval(heartbeat);
      res.end();
    }
  });

  return router;
}
