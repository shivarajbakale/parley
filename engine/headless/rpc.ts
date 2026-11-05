/**
 * Newline-delimited JSON-RPC 2.0, the wire between the native shell and the
 * headless engine. Either side may send requests and notifications; request
 * ids are per sender, so this end only ever matches responses to the ids it
 * issued itself.
 *
 * Transport-free: `write` takes one framed line, `receive` takes one line read
 * from the other side. That keeps the whole protocol testable without a pipe.
 */

export const PROTOCOL_VERSION = 2;
export const REQUEST_TIMEOUT_MS = 10_000;

/** JSON-RPC's own error codes, plus one for a handler that threw. */
export const RPC_ERRORS = {
  parse: -32700,
  invalidRequest: -32600,
  methodNotFound: -32601,
  handlerFailed: -32000,
} as const;

export class RpcError extends Error {
  constructor(
    message: string,
    readonly code: number
  ) {
    super(message);
    this.name = 'RpcError';
  }
}

type Params = Record<string, unknown> | undefined;

export interface RpcDeps {
  write(line: string): void;
  /** A request from the other side; the resolved value is the result. */
  onRequest(method: string, params: Params): Promise<unknown> | unknown;
  /** A notification from the other side; nothing is sent back. */
  onNotify(method: string, params: Params): void;
  /** A line that could not be handled — logged, never thrown. */
  onProtocolError?(message: string): void;
  timeoutMs?: number;
}

export interface Rpc {
  receive(line: string): void;
  request<T = unknown>(method: string, params?: Params): Promise<T>;
  notify(method: string, params?: Params): void;
  /** Rejects every request still waiting, e.g. when the pipe closes. */
  close(reason: string): void;
}

interface Pending {
  resolve(value: unknown): void;
  reject(error: Error): void;
  timer: ReturnType<typeof setTimeout>;
}

export function createRpc(deps: RpcDeps): Rpc {
  let nextId = 1;
  const pending = new Map<number, Pending>();
  const timeoutMs = deps.timeoutMs ?? REQUEST_TIMEOUT_MS;

  const send = (message: Record<string, unknown>) =>
    deps.write(JSON.stringify({ jsonrpc: '2.0', ...message }) + '\n');

  const protocolError = (message: string) => deps.onProtocolError?.(message);

  async function answer(id: unknown, method: string, params: Params) {
    try {
      const result = await deps.onRequest(method, params);
      send({ id, result: result ?? null });
    } catch (error) {
      const code = error instanceof RpcError ? error.code : RPC_ERRORS.handlerFailed;
      const message = error instanceof Error ? error.message : String(error);
      send({ id, error: { code, message } });
    }
  }

  function settle(message: Record<string, unknown>) {
    const id = message.id;
    const waiting = typeof id === 'number' ? pending.get(id) : undefined;
    if (!waiting) {
      protocolError(`response for unknown id ${String(id)}`);
      return;
    }
    pending.delete(id as number);
    clearTimeout(waiting.timer);
    const error = message.error as { code?: unknown; message?: unknown } | undefined;
    if (error) {
      waiting.reject(
        new RpcError(
          typeof error.message === 'string' ? error.message : 'Request failed',
          typeof error.code === 'number' ? error.code : RPC_ERRORS.handlerFailed
        )
      );
    } else {
      waiting.resolve(message.result);
    }
  }

  return {
    receive(line) {
      const trimmed = line.trim();
      if (!trimmed) return;
      let message: Record<string, unknown>;
      try {
        const parsed: unknown = JSON.parse(trimmed);
        if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
          throw new Error('not an object');
        }
        message = parsed as Record<string, unknown>;
      } catch {
        protocolError(`unparseable line: ${trimmed.slice(0, 120)}`);
        return;
      }

      const params =
        message.params && typeof message.params === 'object' && !Array.isArray(message.params)
          ? (message.params as Record<string, unknown>)
          : undefined;

      if (typeof message.method === 'string') {
        if ('id' in message && message.id !== null && message.id !== undefined) {
          void answer(message.id, message.method, params);
        } else {
          try {
            deps.onNotify(message.method, params);
          } catch (error) {
            protocolError(
              `notification ${message.method} failed: ${error instanceof Error ? error.message : String(error)}`
            );
          }
        }
        return;
      }

      if ('result' in message || 'error' in message) {
        settle(message);
        return;
      }

      protocolError(`neither request nor response: ${trimmed.slice(0, 120)}`);
    },

    request<T>(method: string, params?: Params) {
      const id = nextId++;
      return new Promise<T>((resolve, reject) => {
        const timer = setTimeout(() => {
          pending.delete(id);
          reject(new RpcError(`${method} timed out after ${timeoutMs} ms`, RPC_ERRORS.handlerFailed));
        }, timeoutMs);
        pending.set(id, { resolve: resolve as (value: unknown) => void, reject, timer });
        send({ id, method, ...(params ? { params } : {}) });
      });
    },

    notify(method, params) {
      send({ method, ...(params ? { params } : {}) });
    },

    close(reason) {
      for (const [id, waiting] of pending) {
        clearTimeout(waiting.timer);
        waiting.reject(new RpcError(reason, RPC_ERRORS.handlerFailed));
        pending.delete(id);
      }
    },
  };
}
