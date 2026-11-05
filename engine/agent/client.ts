import type { AgentMcpServer, AgentTestResult } from '../types';

import { createSseParser, parseAgentEvent, type AgentEvent } from './events';

/** Bounded like every Parley request: a hung agent must settle. */
const REQUEST_TIMEOUT_MS = 10_000;
/** A stream with no lines at all — not even a heartbeat — is dead. */
const STREAM_IDLE_MS = 60_000;

export type AgentErrorKind = 'network' | 'server' | 'gone' | 'timeout';

const MESSAGES: Record<AgentErrorKind, string> = {
  network: 'unreachable',
  server: 'agent error',
  gone: 'Run ended',
  timeout: 'timeout',
};

export class AgentError extends Error {
  constructor(
    public readonly kind: AgentErrorKind,
    detail?: string
  ) {
    super(detail ?? MESSAGES[kind]);
    this.name = 'AgentError';
  }
}

export type RunOutcome =
  | { kind: 'completed'; text: string }
  | { kind: 'failed'; message: string }
  | { kind: 'cancelled' };

export interface AgentClient {
  startRun(transcript: string): Promise<{ runId: string }>;
  getRunStatus(runId: string): Promise<{ status: string; lastStep: string }>;
  streamEvents(
    runId: string,
    onEvent: (event: AgentEvent) => void,
    opts?: { signal?: AbortSignal; idleMs?: number }
  ): Promise<RunOutcome>;
  approve(runId: string, approved: boolean): Promise<void>;
  /** Best-effort by design: cancelling what is already gone is success. */
  cancelRun(runId: string): Promise<void>;
  checkHealth(): Promise<AgentTestResult>;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function portOf(baseUrl: string): string {
  try {
    const parsed = new URL(baseUrl);
    return parsed.port || (parsed.protocol === 'https:' ? '443' : '80');
  } catch {
    return '';
  }
}

export function createAgentClient(deps: {
  baseUrl: string;
  fetchFn?: typeof fetch;
  timeoutMs?: number;
  idleMs?: number;
}): AgentClient {
  const fetchFn = deps.fetchFn ?? fetch;
  const timeoutMs = deps.timeoutMs ?? REQUEST_TIMEOUT_MS;
  const idleMs = deps.idleMs ?? STREAM_IDLE_MS;
  const base = deps.baseUrl.replace(/\/+$/, '');
  const refused = `refused on :${portOf(deps.baseUrl)}`;

  async function request(path: string, init: RequestInit): Promise<Response> {
    try {
      return await fetchFn(`${base}${path}`, {
        ...init,
        signal: init.signal ?? AbortSignal.timeout(timeoutMs),
      });
    } catch (error) {
      if ((error as Error)?.name === 'TimeoutError') throw new AgentError('timeout');
      throw new AgentError('network', refused);
    }
  }

  function statusOf(response: Response): void {
    if (response.ok) return;
    if (response.status === 404) throw new AgentError('gone');
    throw new AgentError('server', `agent answered ${response.status}`);
  }

  return {
    async startRun(transcript) {
      const response = await request('/parley/run', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ transcript }),
      });
      statusOf(response);
      const body: unknown = await response.json().catch(() => null);
      const runId = isRecord(body) ? body.runId : null;
      if (typeof runId !== 'string' || !runId) {
        throw new AgentError('server', 'bad run reply');
      }
      return { runId };
    },

    async getRunStatus(runId) {
      const response = await request(`/parley/runs/${runId}`, { method: 'GET' });
      statusOf(response);
      const body: unknown = await response.json().catch(() => null);
      if (!isRecord(body) || typeof body.status !== 'string' || typeof body.lastStep !== 'string') {
        throw new AgentError('server', 'bad run reply');
      }
      return { status: body.status, lastStep: body.lastStep };
    },

    streamEvents(runId, onEvent, opts) {
      if (opts?.signal?.aborted) return Promise.resolve({ kind: 'cancelled' } as const);
      return new Promise<RunOutcome>((resolve, reject) => {
        let settled = false;
        let lastSeq = 0;
        let idleTimer: ReturnType<typeof setTimeout> | undefined;
        let reader: ReadableStreamDefaultReader<Uint8Array> | undefined;

        function cleanup() {
          if (idleTimer) clearTimeout(idleTimer);
          idleTimer = undefined;
          opts?.signal?.removeEventListener('abort', onAbort);
          if (reader) void reader.cancel().catch(() => {});
        }
        function done(outcome: RunOutcome) {
          if (settled) return;
          settled = true;
          cleanup();
          resolve(outcome);
        }
        function fail(error: unknown) {
          if (settled) return;
          settled = true;
          cleanup();
          reject(error);
        }
        function onAbort() {
          done({ kind: 'cancelled' });
        }
        function touch() {
          if (idleTimer) clearTimeout(idleTimer);
          idleTimer = setTimeout(() => fail(new AgentError('timeout')), idleMs);
        }

        opts?.signal?.addEventListener('abort', onAbort, { once: true });
        const parser = createSseParser(raw => {
          const event = parseAgentEvent(raw);
          if (!event || event.runId !== runId || event.seq <= lastSeq) return;
          lastSeq = event.seq;
          touch();
          onEvent(event);
          if (event.kind === 'completed') done({ kind: 'completed', text: event.text });
          if (event.kind === 'failed') done({ kind: 'failed', message: event.message });
        });

        void (async () => {
          touch();
          let response: Response;
          try {
            response = await fetchFn(`${base}/parley/runs/${runId}/events`, {
              method: 'GET',
              headers: { Accept: 'text/event-stream' },
              signal: opts?.signal,
            });
          } catch (error) {
            if ((error as Error)?.name === 'AbortError') return onAbort();
            return fail(new AgentError('network', refused));
          }
          if (!response.ok || !response.body) {
            if (response.status === 404) return fail(new AgentError('gone'));
            return fail(new AgentError('server', `agent answered ${response.status}`));
          }
          reader = response.body.getReader();
          const decoder = new TextDecoder();
          try {
            for (;;) {
              const { done: ended, value } = await reader.read();
              if (ended) return fail(new AgentError('server', 'stream ended early'));
              touch();
              parser.push(decoder.decode(value, { stream: true }));
              if (settled) return;
            }
          } catch (error) {
            if ((error as Error)?.name === 'AbortError') return onAbort();
            fail(new AgentError('network'));
          }
        })();
      });
    },

    async approve(runId, approved) {
      const response = await request(`/parley/runs/${runId}/approve`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ approved }),
      });
      statusOf(response);
    },

    async cancelRun(runId) {
      try {
        await fetchFn(`${base}/parley/runs/${runId}`, {
          method: 'DELETE',
          signal: AbortSignal.timeout(timeoutMs),
        });
      } catch {
        // Gone, refused, broken: a cancelled run needs nothing back.
      }
    },

    async checkHealth() {
      let response: Response;
      try {
        response = await fetchFn(`${base}/parley/health`, {
          method: 'GET',
          signal: AbortSignal.timeout(timeoutMs),
        });
      } catch (error) {
        const message = (error as Error)?.name === 'TimeoutError' ? 'timed out' : refused;
        return { ok: false, message, mcpServers: [] };
      }
      if (!response.ok) {
        return { ok: false, message: `agent answered ${response.status}`, mcpServers: [] };
      }
      const body: unknown = await response.json().catch(() => null);
      if (!isRecord(body) || !Array.isArray(body.mcpServers)) {
        return { ok: false, message: 'bad health reply', mcpServers: [] };
      }
      const mcpServers: AgentMcpServer[] = [];
      for (const entry of body.mcpServers) {
        if (isRecord(entry) && typeof entry.name === 'string' && typeof entry.tools === 'number') {
          mcpServers.push({ name: entry.name, tools: entry.tools });
        }
      }
      if (body.online !== true) {
        const message = typeof body.message === 'string' ? body.message : 'agent not ready';
        return { ok: false, message, mcpServers };
      }
      return { ok: true, message: 'Agent works', mcpServers };
    },
  };
}
