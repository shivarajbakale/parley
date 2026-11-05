import { randomUUID } from 'node:crypto';

import type { Agent } from '@mastra/core/agent';

/**
 * Parley's runs, server-side. One run per voice command: the transcript
 * streams through the agent, tool activity becomes `step` events, a
 * write-class tool suspends into `approval_requested`, and the run settles
 * with `completed` or `failed`. Events buffer per run, so the SSE subscriber
 * that connects a beat after POST still sees the whole run from seq 1.
 *
 * Runs live in memory for v1 — a restart orphans them, and Parley folds the
 * pill with "Run ended" when the run it holds is gone.
 */

export type RunStatus = 'working' | 'awaiting_approval' | 'done' | 'failed' | 'cancelled';

/** A Mastra stream chunk, read defensively: only `type` and the payload
 * fields below are trusted, everything else is ignored. */
interface StreamChunk {
  type: string;
  payload?: Record<string, unknown>;
}

interface BufferedEvent {
  event: string;
  data: Record<string, unknown>;
}

type SendEvent = (event: string, data: Record<string, unknown>) => void;

interface PendingApproval {
  callId: string;
  tool: string;
  summary: string;
}

interface RunRecord {
  runId: string;
  transcript: string;
  status: RunStatus;
  lastStep: string;
  seq: number;
  events: BufferedEvent[];
  subscribers: Set<SendEvent>;
  mastraRunId: string | null;
  pending: PendingApproval | null;
  /** A tool was called in this run — an answer without one is not trusted. */
  toolUsed: boolean;
  /** The one fresh attempt a tool-less answer gets has been spent. */
  retried: boolean;
}

const DECLINE_REASON =
  'The user declined this tool call — say what was skipped in one line and carry on with the rest.';

/** A run that answered twice without calling any tool. Its words may be
 * invented ("Added — buy milk" with nothing added), so they are not shown. */
export const NO_TOOL_MESSAGE = 'Nothing was done — no tool ran. Try saying it another way.';

/** Step one must call a tool: left free, MiniMax sometimes answers "Added —
 * buy milk" having called nothing. Later steps are free, so the run can
 * still end in words once a tool has spoken. MiniMax ignores this now and
 * then too, which is what the no-tool retry in `pump` is for. */
export const STREAM_OPTIONS = {
  prepareStep: ({ stepNumber }: { stepNumber: number }) =>
    stepNumber === 0 ? { toolChoice: 'required' as const } : undefined,
};

/** Terminal runs kept for late status polls; working runs are never pruned. */
const MAX_KEPT_RUNS = 100;

function text(value: unknown): string | null {
  return typeof value === 'string' ? value : null;
}

function safeJson(value: unknown): string | null {
  if (value === null || value === undefined) return null;
  try {
    const rendered = JSON.stringify(value);
    return rendered === undefined ? null : rendered;
  } catch {
    return null;
  }
}

/** Provider errors arrive as objects — the pill wants the message, not the stack. */
function errorDetail(value: unknown): string | null {
  if (typeof value === 'string') return value;
  if (typeof value === 'object' && value !== null) {
    const message = (value as Record<string, unknown>).message;
    if (typeof message === 'string' && message) return message;
  }
  return safeJson(value);
}

/** `calendar_delete_event` reads as "Delete event" on the pill. */
function shortToolName(toolName: string): string {
  const bare = toolName.includes('_') ? toolName.slice(toolName.indexOf('_') + 1) : toolName;
  const words = bare.replace(/_/g, ' ').trim() || toolName;
  return words.charAt(0).toUpperCase() + words.slice(1);
}

function flatArgs(args: unknown): string {
  if (typeof args !== 'object' || args === null) return '';
  const parts: string[] = [];
  for (const value of Object.values(args as Record<string, unknown>)) {
    if (value === null || value === undefined || typeof value === 'object') continue;
    const word = String(value).trim();
    if (word) parts.push(word.length > 28 ? `${word.slice(0, 27)}…` : word);
    if (parts.length >= 3) break;
  }
  return parts.join(' · ');
}

function oneLine(value: string, max: number): string {
  const single = value.replace(/\s+/g, ' ').trim();
  return single.length > max ? `${single.slice(0, max - 1)}…` : single;
}

function errorMessage(error: unknown): string {
  const message = error instanceof Error ? error.message : String(error);
  return oneLine(message || 'Something went wrong', 160);
}

export function summarizeCall(
  toolName: string,
  args: unknown,
  descriptions: Map<string, string>
): string {
  const description = descriptions.get(toolName);
  const head =
    description && description.length <= 90 ? oneLine(description, 90) : shortToolName(toolName);
  const tail = flatArgs(args);
  return tail ? oneLine(`${head} — ${tail}`, 140) : head;
}

type Pumpable = Pick<Agent, 'stream' | 'approveToolCall' | 'declineToolCall' | 'abortRunStream'>;

export interface RunStore {
  start(transcript: string): Promise<string>;
  status(runId: string): { status: RunStatus; lastStep: string } | null;
  subscribe(runId: string, send: SendEvent): (() => void) | null;
  decide(runId: string, approved: boolean): Promise<'ok' | 'gone'>;
  cancel(runId: string): Promise<void>;
}

export function createRunStore(agent: Pumpable, toolDescriptions: Map<string, string>): RunStore {
  const runs = new Map<string, RunRecord>();

  function get(runId: string): RunRecord | null {
    return runs.get(runId) ?? null;
  }

  function emit(run: RunRecord, event: string, data: Record<string, unknown>): void {
    run.seq += 1;
    const full = { runId: run.runId, seq: run.seq, ...data };
    run.events.push({ event, data: full });
    for (const send of run.subscribers) send(event, full);
  }

  function step(run: RunRecord, text: string): void {
    run.lastStep = text;
    emit(run, 'step', { text });
  }

  function isTerminal(status: RunStatus): boolean {
    return status === 'done' || status === 'failed' || status === 'cancelled';
  }

  function prune(): void {
    if (runs.size <= MAX_KEPT_RUNS) return;
    for (const [id, run] of runs) {
      if (runs.size <= MAX_KEPT_RUNS) return;
      if (isTerminal(run.status)) runs.delete(id);
    }
  }

  function settle(run: RunRecord, status: RunStatus): void {
    run.status = status;
    run.pending = null;
    prune();
  }

  async function pump(run: RunRecord, output: { fullStream: unknown }): Promise<void> {
    let settled = false;
    try {
      const fullStream = output.fullStream as AsyncIterable<StreamChunk>;
      for await (const chunk of fullStream) {
        if (run.status === 'cancelled') return;
        if (process.env.PARLEY_DEBUG === '1') {
          console.log(`[parley:chunk] ${chunk.type} ${JSON.stringify(chunk.payload ?? {}).slice(0, 300)}`);
        }
        const payload = chunk.payload ?? {};
        switch (chunk.type) {
          case 'tool-call': {
            run.toolUsed = true;
            const tool = text(payload.toolName);
            if (tool) step(run, `Using ${shortToolName(tool)}…`);
            break;
          }
          case 'tool-call-approval': {
            const callId = text(payload.toolCallId);
            const tool = text(payload.toolName);
            if (!callId || !tool) break;
            run.mastraRunId =
              (output as unknown as { runId?: unknown }).runId !== undefined
                ? String((output as unknown as { runId: unknown }).runId)
                : run.mastraRunId;
            run.status = 'awaiting_approval';
            run.pending = {
              callId,
              tool,
              summary: summarizeCall(tool, payload.args, toolDescriptions),
            };
            emit(run, 'approval_requested', {
              callId,
              tool,
              summary: run.pending.summary,
              transcript: run.transcript,
            });
            return;
          }
          case 'error': {
            throw new Error(errorDetail(payload.error) || 'model stream failed');
          }
          default:
            break;
        }
      }
      if (run.status === 'cancelled') return;
      if (!run.toolUsed) {
        if (!run.retried) {
          run.retried = true;
          await begin(run);
          return;
        }
        throw new Error(NO_TOOL_MESSAGE);
      }
      const answer = await (output as unknown as { text: Promise<string> }).text;
      const line = oneLine(answer, 2000) || 'Done.';
      settle(run, 'done');
      settled = true;
      emit(run, 'completed', { text: line });
    } catch (error) {
      if (run.status === 'cancelled') return;
      settle(run, 'failed');
      settled = true;
      emit(run, 'failed', { message: errorMessage(error) });
    } finally {
      if (settled) {
        // Terminal events flush, then the SSE closes; late subscribers
        // replay the buffer instead of hanging on a dead run.
        for (const send of [...run.subscribers]) send('close', {});
        run.subscribers.clear();
      }
    }
  }

  /** Open the agent stream for a run and pump it; a failure to open settles
   * the run as failed. */
  async function begin(run: RunRecord): Promise<void> {
    try {
      const output = await agent.stream(run.transcript, STREAM_OPTIONS);
      run.mastraRunId = output.runId;
      void pump(run, output);
    } catch (error) {
      settle(run, 'failed');
      emit(run, 'failed', { message: errorMessage(error) });
      for (const send of [...run.subscribers]) send('close', {});
      run.subscribers.clear();
    }
  }

  return {
    async start(transcript: string): Promise<string> {
      const run: RunRecord = {
        runId: randomUUID(),
        transcript,
        status: 'working',
        lastStep: 'Working…',
        seq: 0,
        events: [],
        subscribers: new Set(),
        mastraRunId: null,
        pending: null,
        toolUsed: false,
        retried: false,
      };
      runs.set(run.runId, run);
      await begin(run);
      return run.runId;
    },

    status(runId: string) {
      const run = get(runId);
      return run ? { status: run.status, lastStep: run.lastStep } : null;
    },

    subscribe(runId: string, send: SendEvent) {
      const run = get(runId);
      if (!run) return null;
      for (const buffered of run.events) send(buffered.event, buffered.data);
      if (isTerminal(run.status)) {
        send('close', {});
        return () => {};
      }
      run.subscribers.add(send);
      return () => {
        run.subscribers.delete(send);
      };
    },

    async decide(runId: string, approved: boolean): Promise<'ok' | 'gone'> {
      const run = get(runId);
      if (!run || isTerminal(run.status) || !run.mastraRunId) return 'gone';
      const pending = run.pending;
      run.pending = null;
      if (!pending) return 'ok';
      run.status = 'working';
      if (!approved) step(run, 'Skipped — continuing…');
      try {
        const output = approved
          ? await agent.approveToolCall({ runId: run.mastraRunId, toolCallId: pending.callId })
          : await agent.declineToolCall({
              runId: run.mastraRunId,
              toolCallId: pending.callId,
              reason: DECLINE_REASON,
            });
        void pump(run, output);
      } catch (error) {
        settle(run, 'failed');
        emit(run, 'failed', { message: errorMessage(error) });
        for (const send of [...run.subscribers]) send('close', {});
        run.subscribers.clear();
      }
      return 'ok';
    },

    async cancel(runId: string): Promise<void> {
      const run = get(runId);
      if (!run || isTerminal(run.status)) return;
      const mastraRunId = run.mastraRunId;
      const pending = run.pending;
      settle(run, 'cancelled');
      for (const send of [...run.subscribers]) send('close', {});
      run.subscribers.clear();
      // The pill is already gone; settle the Mastra side so nothing keeps
      // working for a run nobody holds.
      try {
        if (!mastraRunId) return;
        if (pending) {
          await agent.declineToolCall({
            runId: mastraRunId,
            toolCallId: pending.callId,
            reason: 'The user cancelled the run.',
          });
        } else {
          agent.abortRunStream(mastraRunId);
        }
      } catch {
        // A cancelled run needs nothing back.
      }
    },
  };
}
