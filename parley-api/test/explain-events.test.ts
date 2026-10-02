import { describe, expect, it } from 'vitest';
import { MAX_SOURCES, explainEvents, type Chunk } from '../src/explain/events.js';
import { createSourceLineFilter } from '../src/explain/source-filter.js';

async function collect(chunks: Chunk[]) {
  async function* gen() {
    yield* chunks;
  }
  const out = [];
  for await (const event of explainEvents(gen())) out.push(event);
  return out;
}

const text = (t: string): Chunk => ({ type: 'text-delta', payload: { text: t } });
const step = (type: 'step-start' | 'step-finish'): Chunk => ({ type, payload: {} });
const searchStart: Chunk = { type: 'tool-call-input-streaming-start', payload: { toolName: 'webSearch' } };
const searchCall = (query: string, toolCallId = query): Chunk => ({
  type: 'tool-call',
  payload: { toolCallId, toolName: 'webSearch', args: { query } },
});
const searchResult = (results: { title: string; url: string }[]): Chunk => ({
  type: 'tool-result',
  payload: { toolName: 'webSearch', result: { results: results.map((r) => ({ ...r, snippet: '' })) } },
});
const finish: Chunk = { type: 'finish', payload: {} };

describe('explainEvents', () => {
  it('streams a plain answer as deltas, then done with no sources', async () => {
    expect(await collect([step('step-start'), text('Same '), text('result.'), step('step-finish'), finish])).toEqual([
      { event: 'delta', data: { text: 'Same ' } },
      { event: 'delta', data: { text: 'result.' } },
      { event: 'done', data: {} },
    ]);
  });

  it('resets text written before a search, announces the search, and sends real sources', async () => {
    const events = await collect([
      step('step-start'),
      text("I don't know this; I'll search."),
      searchStart,
      searchCall('Mastra 1.67'),
      searchResult([{ title: 'Release', url: 'https://a.dev' }]),
      step('step-finish'),
      step('step-start'),
      text('Mastra 1.67 adds X.'),
      step('step-finish'),
      finish,
    ]);
    expect(events).toEqual([
      { event: 'delta', data: { text: "I don't know this; I'll search." } },
      { event: 'reset', data: {} },
      { event: 'search', data: { query: 'Mastra 1.67' } },
      { event: 'delta', data: { text: 'Mastra 1.67 adds X.' } },
      { event: 'sources', data: [{ title: 'Release', url: 'https://a.dev' }] },
      { event: 'done', data: {} },
    ]);
  });

  it('sends no reset when a step searches before writing anything', async () => {
    const events = await collect([step('step-start'), searchStart, searchCall('q'), searchResult([]), text('A.'), finish]);
    expect(events.map((e) => e.event)).toEqual(['search', 'delta', 'done']);
  });

  it('announces each search once though Mastra repeats the tool-call chunk', async () => {
    const events = await collect([searchCall('q', 'call-1'), searchCall('q', 'call-1'), searchCall('q', 'call-2'), text('A.'), finish]);
    expect(events.filter((e) => e.event === 'search')).toHaveLength(2);
  });

  it('ends in an error, not an empty done, when no answer text ever arrives', async () => {
    const events = await collect([text('Let me search.'), searchStart, searchCall('q'), searchResult([{ title: 'T', url: 'https://t.dev' }]), finish]);
    expect(events.map((e) => e.event)).toEqual(['delta', 'reset', 'search', 'error']);
    expect(events.at(-1)).toEqual({ event: 'error', data: { message: 'No answer came back. Try again.' } });
  });

  it('dedupes sources by url and caps them', async () => {
    const many = Array.from({ length: 5 }, (_, i) => ({ title: `T${i}`, url: `https://s${i}.dev` }));
    const events = await collect([
      searchCall('a'),
      searchResult([many[0]!, many[1]!]),
      searchCall('b'),
      searchResult([many[1]!, ...many.slice(2)]),
      text('A.'),
      finish,
    ]);
    const sources = events.find((e) => e.event === 'sources');
    expect(sources?.data).toEqual(many.slice(0, MAX_SOURCES));
  });

  it('turns a stream error into an error event and stops', async () => {
    const events = await collect([text('Half'), { type: 'error', payload: { error: new Error('model timeout') } }, text('never')]);
    expect(events).toEqual([
      { event: 'delta', data: { text: 'Half' } },
      { event: 'error', data: { message: 'model timeout' } },
    ]);
  });

  it('treats a tool call written as text like a search: resets and never shows the markup', async () => {
    const events = await collect([
      text('Let me look further.'),
      text(']<]minimax[>[<tool_call><invoke name="webSearch"></invoke>]<]minimax[>[</tool_call>'),
      finish,
    ]);
    expect(events).toEqual([
      { event: 'delta', data: { text: 'Let me look further.' } },
      { event: 'reset', data: {} },
      { event: 'error', data: { message: 'No answer came back. Try again.' } },
    ]);
  });

  it('drops a Source: line the model writes itself', async () => {
    const events = await collect([text('Answer.\n\nSour'), text('ce: [x](https://made.up)'), finish]);
    const streamed = events.filter((e) => e.event === 'delta').map((e) => (e.data as { text: string }).text).join('');
    expect(streamed).toBe('Answer.\n\n');
  });
});

describe('createSourceLineFilter', () => {
  const run = (pieces: string[]) => {
    const f = createSourceLineFilter();
    return pieces.map((p) => f.push(p)).join('') + f.end();
  };

  it('passes ordinary text through untouched, even split mid-line', () => {
    expect(run(['Hello wor', 'ld\nSo it ', 'goes.'])).toBe('Hello world\nSo it goes.');
  });

  it('drops Source and Sources lines in any common markdown form', () => {
    expect(run(['A\nSource: [x](u)\nB'])).toBe('A\nB');
    expect(run(['A\n**Sources:** [x](u)'])).toBe('A\n');
    expect(run(['A\n_Source_: x\n'])).toBe('A\n');
  });

  it('keeps a line that only starts like Source', () => {
    expect(run(['A\nSourcing ', 'is hard.'])).toBe('A\nSourcing is hard.');
  });
});
