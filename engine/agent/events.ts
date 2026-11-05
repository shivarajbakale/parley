/**
 * The agent talks back over server-sent events. This is the client half: an
 * incremental parser plus a strict decoder. Anything malformed is dropped,
 * never thrown — a poisoned line must not kill the run.
 */

export interface SseRawEvent {
  event: string;
  data: string;
}

export interface SseParser {
  push(chunk: string): void;
}

export function createSseParser(onEvent: (raw: SseRawEvent) => void): SseParser {
  let buffer = '';
  let type = '';
  let data: string[] = [];

  function dispatch() {
    if (type !== '' || data.length > 0) onEvent({ event: type || 'message', data: data.join('\n') });
    type = '';
    data = [];
  }

  return {
    push(chunk: string) {
      buffer += chunk.replace(/\r\n/g, '\n');
      let end: number;
      while ((end = buffer.indexOf('\n')) !== -1) {
        const line = buffer.slice(0, end);
        buffer = buffer.slice(end + 1);
        if (line === '') {
          dispatch();
        } else if (line.startsWith(':')) {
          // Comment or heartbeat: never an event.
        } else if (line.startsWith('event:')) {
          type = line.slice(6).trim();
        } else if (line.startsWith('data:')) {
          data.push(line.slice(5).trimStart());
        }
      }
    },
  };
}

export type AgentEvent =
  | { kind: 'step'; runId: string; seq: number; text: string }
  | {
      kind: 'approval_requested';
      runId: string;
      seq: number;
      callId: string;
      tool: string;
      summary: string;
      transcript: string;
    }
  | { kind: 'completed'; runId: string; seq: number; text: string }
  | { kind: 'failed'; runId: string; seq: number; message: string };

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function textField(body: Record<string, unknown>, name: string): string | null {
  const value = body[name];
  return typeof value === 'string' ? value : null;
}

/** `null` means "drop this line": unknown type, bad JSON, mistyped field. */
export function parseAgentEvent(raw: SseRawEvent): AgentEvent | null {
  let body: unknown;
  try {
    body = JSON.parse(raw.data) as unknown;
  } catch {
    return null;
  }
  if (!isRecord(body)) return null;
  const runId = textField(body, 'runId');
  const seq = body.seq;
  if (runId === null || typeof seq !== 'number' || !Number.isInteger(seq)) return null;
  switch (raw.event) {
    case 'step': {
      const text = textField(body, 'text');
      return text === null ? null : { kind: 'step', runId, seq, text };
    }
    case 'approval_requested': {
      const callId = textField(body, 'callId');
      const tool = textField(body, 'tool');
      const summary = textField(body, 'summary');
      const transcript = textField(body, 'transcript');
      return callId === null || tool === null || summary === null || transcript === null
        ? null
        : { kind: 'approval_requested', runId, seq, callId, tool, summary, transcript };
    }
    case 'completed': {
      const text = textField(body, 'text');
      return text === null ? null : { kind: 'completed', runId, seq, text };
    }
    case 'failed': {
      const message = textField(body, 'message');
      return message === null ? null : { kind: 'failed', runId, seq, message };
    }
    default:
      return null;
  }
}
