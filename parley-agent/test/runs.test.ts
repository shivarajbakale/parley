import { describe, expect, it, vi } from 'vitest';
import { createRunStore, NO_TOOL_MESSAGE, STREAM_OPTIONS } from '../src/mastra/parley/runs.js';

type Chunk = { type: string; payload?: Record<string, unknown> };

function output(chunks: Chunk[], text: string) {
  return {
    runId: 'mastra-run',
    fullStream: (async function* () {
      yield* chunks;
    })(),
    text: Promise.resolve(text),
  };
}

const toolCall: Chunk = { type: 'tool-call', payload: { toolName: 'notes_list_notes', toolCallId: 'c1' } };

function storeWith(...outputs: ReturnType<typeof output>[]) {
  const stream = vi.fn();
  for (const out of outputs) stream.mockResolvedValueOnce(out);
  const agent = { stream, approveToolCall: vi.fn(), declineToolCall: vi.fn(), abortRunStream: vi.fn() };
  return { store: createRunStore(agent as never, new Map()), stream };
}

async function settled(store: ReturnType<typeof createRunStore>, runId: string) {
  await vi.waitFor(() => expect(['done', 'failed']).toContain(store.status(runId)?.status));
  const events: { event: string; data: Record<string, unknown> }[] = [];
  store.subscribe(runId, (event, data) => events.push({ event, data }));
  return events.find(e => e.event === 'completed' || e.event === 'failed')!;
}

describe('run store: answers must come from a tool', () => {
  it('asks the model to call a tool on the first step only', () => {
    expect(STREAM_OPTIONS.prepareStep({ stepNumber: 0 })).toEqual({ toolChoice: 'required' });
    expect(STREAM_OPTIONS.prepareStep({ stepNumber: 1 })).toBeUndefined();
  });

  it('completes a run that used a tool, in one attempt', async () => {
    const { store, stream } = storeWith(output([toolCall], 'Two notes.'));
    const end = await settled(store, await store.start('what are my notes'));
    expect(end).toMatchObject({ event: 'completed', data: { text: 'Two notes.' } });
    expect(stream).toHaveBeenCalledTimes(1);
    expect(stream).toHaveBeenCalledWith('what are my notes', STREAM_OPTIONS);
  });

  it('retries a tool-less answer once and keeps the retry when it uses a tool', async () => {
    const { store, stream } = storeWith(output([], 'Added — buy milk.'), output([toolCall], 'Two notes.'));
    const end = await settled(store, await store.start('what are my notes'));
    expect(stream).toHaveBeenCalledTimes(2);
    expect(end).toMatchObject({ event: 'completed', data: { text: 'Two notes.' } });
  });

  it('fails honestly instead of showing a second tool-less answer', async () => {
    const { store, stream } = storeWith(output([], 'Added — buy milk.'), output([], 'Added — buy milk.'));
    const end = await settled(store, await store.start('note down buy milk'));
    expect(stream).toHaveBeenCalledTimes(2);
    expect(end).toMatchObject({ event: 'failed', data: { message: NO_TOOL_MESSAGE } });
  });
});
