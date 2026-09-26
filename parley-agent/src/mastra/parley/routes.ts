import { registerApiRoute } from '@mastra/core/server';
import type { MCPClient } from '@mastra/mcp';

import { listCatalog } from './mcp';
import type { RunStore } from './runs';

/**
 * Parley's half of the server, at the root — Mastra reserves `/api/` for
 * itself, so these live at `/parley/*`:
 *
 *   POST   /parley/run            {transcript} -> {runId}
 *   GET    /parley/runs/:id       -> {status, lastStep}, 404 when the run is gone
 *   GET    /parley/runs/:id/events  SSE: step, approval_requested, completed, failed
 *   POST   /parley/runs/:id/approve {approved} -> 200, 404 when the run is gone
 *   DELETE /parley/runs/:id       cancel; always 200, a gone run is already cancelled
 *   GET    /parley/health         -> {online, mcpServers[]}
 */

const HEARTBEAT_MS = 15_000;

function sseResponse(runId: string, store: RunStore): Response {
  const encoder = new TextEncoder();
  let heartbeat: ReturnType<typeof setInterval> | undefined;
  let unsubscribe: (() => void) | null = null;

  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      const send = (event: string, data: Record<string, unknown>): void => {
        if (event === 'close') {
          if (heartbeat) clearInterval(heartbeat);
          unsubscribe?.();
          try {
            controller.close();
          } catch {
            // Already gone.
          }
          return;
        }
        controller.enqueue(encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`));
      };
      unsubscribe = store.subscribe(runId, send);
      if (!unsubscribe) {
        try {
          controller.close();
        } catch {
          // Already gone.
        }
        return;
      }
      heartbeat = setInterval(() => {
        try {
          controller.enqueue(encoder.encode(': ping\n\n'));
        } catch {
          if (heartbeat) clearInterval(heartbeat);
        }
      }, HEARTBEAT_MS);
    },
    cancel() {
      if (heartbeat) clearInterval(heartbeat);
      unsubscribe?.();
    },
  });

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
    },
  });
}

export function createParleyRoutes(store: RunStore, mcp: MCPClient) {
  const startRun = registerApiRoute('/parley/run', {
    method: 'POST',
    handler: async c => {
      const body = (await c.req.json().catch(() => null)) as { transcript?: unknown } | null;
      const transcript = typeof body?.transcript === 'string' ? body.transcript.trim() : '';
      if (!transcript) return c.json({ error: 'transcript is required' }, 400);
      const runId = await store.start(transcript.slice(0, 2000));
      return c.json({ runId });
    },
  });

  const runStatus = registerApiRoute('/parley/runs/:id', {
    method: 'GET',
    handler: async c => {
      const found = store.status(c.req.param('id'));
      if (!found) return c.json({ error: 'run gone' }, 404);
      return c.json(found);
    },
  });

  const runEvents = registerApiRoute('/parley/runs/:id/events', {
    method: 'GET',
    handler: async c => {
      const id = c.req.param('id');
      if (!store.status(id)) return c.json({ error: 'run gone' }, 404);
      return sseResponse(id, store);
    },
  });

  const approveRun = registerApiRoute('/parley/runs/:id/approve', {
    method: 'POST',
    handler: async c => {
      const body = (await c.req.json().catch(() => null)) as { approved?: unknown } | null;
      if (typeof body?.approved !== 'boolean') {
        return c.json({ error: 'approved must be a boolean' }, 400);
      }
      const result = await store.decide(c.req.param('id'), body.approved);
      if (result === 'gone') return c.json({ error: 'run gone' }, 404);
      return c.json({ ok: true });
    },
  });

  const cancelRun = registerApiRoute('/parley/runs/:id', {
    method: 'DELETE',
    handler: async c => {
      await store.cancel(c.req.param('id'));
      return c.json({ cancelled: true });
    },
  });

  const health = registerApiRoute('/parley/health', {
    method: 'GET',
    handler: async c => {
      const mcpServers = await listCatalog(mcp);
      return c.json({ online: true, mcpServers });
    },
  });

  return [startRun, runStatus, runEvents, approveRun, cancelRun, health];
}
