import { afterEach, describe, expect, it, vi } from 'vitest';

import { createExplain, createUpdateThrottle, EMPTY_HIDE_MS } from '../explain';
import type { ExplainStreamEvent, ExplainTurnInput } from '../explain-client';
import type { SelectionSnapshot } from '../selection-reader';

const anchor = { x: 1, y: 2, width: 3, height: 4 };

type Answer = (text: string, turns: ExplainTurnInput[]) => Promise<string>;

/**
 * A fake client. `answer` resolves to the whole reply, which arrives as one
 * delta and a done, or rejects with an Error whose message the server sent;
 * `script` replays exact events instead.
 */
function setup(options: {
  snapshot?: SelectionSnapshot | null;
  explain?: Answer;
  script?: (onEvent: (e: ExplainStreamEvent) => void, signal: AbortSignal) => Promise<void>;
}) {
  const view = { show: vi.fn(), update: vi.fn(), hide: vi.fn() };
  const answer = options.explain ?? (async () => 'It means x.');
  const signals: AbortSignal[] = [];
  const client = {
    stream: vi.fn(async (text: string, turns: ExplainTurnInput[], onEvent: (e: ExplainStreamEvent) => void, signal: AbortSignal) => {
      signals.push(signal);
      if (options.script) return options.script(onEvent, signal);
      try {
        const markdown = await answer(text, turns);
        onEvent({ type: 'delta', text: markdown });
        onEvent({ type: 'done' });
      } catch (error) {
        onEvent({ type: 'error', message: (error as Error).message });
      }
    }),
  };
  const snapshot = options.snapshot === undefined ? { text: 'x', anchor } : options.snapshot;
  const selection = { read: vi.fn().mockResolvedValue(snapshot) };
  const explain = createExplain({ selection, client, view });
  return { explain, view, client, selection, signals };
}

afterEach(() => vi.useRealTimers());

describe('explain', () => {
  it('opens the card loading at the selection, then fills it with the answer', async () => {
    const { explain, view, client } = setup({});
    await explain.ask();
    expect(view.show).toHaveBeenCalledWith(anchor, {
      status: 'thread',
      turns: [{ question: undefined, status: 'loading' }],
    });
    expect(client.stream).toHaveBeenCalledWith('x', [{ question: undefined, answer: undefined }], expect.any(Function), expect.any(AbortSignal));
    expect(view.update).toHaveBeenLastCalledWith({
      status: 'thread',
      turns: [{ question: undefined, status: 'ready', markdown: 'It means x.' }],
    });
  });

  it('answers a spoken question about the selection and shows it on the card', async () => {
    const { explain, view, client } = setup({});
    await explain.ask('why is this here?');
    expect(view.show).toHaveBeenCalledWith(anchor, {
      status: 'thread',
      turns: [{ question: 'why is this here?', status: 'loading' }],
    });
    expect(client.stream).toHaveBeenCalledWith('x', [
      { question: 'why is this here?', answer: undefined },
    ], expect.any(Function), expect.any(AbortSignal));
  });

  it('says so, then hides itself, when nothing is selected', async () => {
    vi.useFakeTimers();
    const { explain, view, client } = setup({ snapshot: null });
    await explain.ask();
    expect(view.show).toHaveBeenCalledWith(null, { status: 'empty' });
    expect(client.stream).not.toHaveBeenCalled();
    vi.advanceTimersByTime(EMPTY_HIDE_MS);
    expect(view.hide).toHaveBeenCalledOnce();
  });

  it("shows the server's message as the error", async () => {
    const { explain, view } = setup({
      explain: async () => {
        throw new Error("Can't reach the Parley server at http://localhost:3100");
      },
    });
    await explain.ask();
    expect(view.update).toHaveBeenLastCalledWith({
      status: 'thread',
      turns: [{ question: undefined, status: 'error', message: "Can't reach the Parley server at http://localhost:3100" }],
    });
  });

  it('hides a generic message for anything unexpected', async () => {
    const { explain, view } = setup({
      script: async () => {
        throw new Error('boom: secret detail');
      },
    });
    await explain.ask();
    expect(view.update).toHaveBeenLastCalledWith({
      status: 'thread',
      turns: [{ question: undefined, status: 'error', message: 'Something went wrong' }],
    });
  });

  it('drops a slow answer once the card was dismissed', async () => {
    let resolve!: (text: string) => void;
    const { explain, view } = setup({ explain: () => new Promise((r) => (resolve = r)) });
    const pending = explain.ask();
    await vi.waitFor(() => expect(view.show).toHaveBeenCalled());
    explain.dismiss();
    resolve('late');
    await pending;
    expect(view.update).not.toHaveBeenCalled();
    expect(view.hide).toHaveBeenCalledOnce();
  });

  it('lets a newer selection supersede a slow older one', async () => {
    const resolvers: ((text: string) => void)[] = [];
    const { explain, view, selection } = setup({
      explain: () => new Promise((r) => resolvers.push(r)),
    });
    const first = explain.ask();
    await vi.waitFor(() => expect(resolvers).toHaveLength(1));
    // A fresh gesture with the card already closed reads the selection again.
    explain.dismiss();
    selection.read.mockResolvedValue({ text: 'y', anchor });
    const second = explain.ask();
    await vi.waitFor(() => expect(resolvers).toHaveLength(2));
    resolvers[0]('old');
    resolvers[1]('new');
    await Promise.all([first, second]);
    // Nothing of the superseded answer ever reaches the card.
    expect(JSON.stringify(view.update.mock.calls)).not.toContain('old');
    expect(view.update).toHaveBeenLastCalledWith({
      status: 'thread',
      turns: [{ question: undefined, status: 'ready', markdown: 'new' }],
    });
  });

  describe('follow-up', () => {
    it('appends a second turn on the same selection, with the first as history', async () => {
      const { explain, view, client, selection } = setup({
        explain: async (_text, turns) => (turns.length === 1 ? 'It means x.' : 'That part means y.'),
      });
      await explain.ask('what is x?');
      await explain.ask('what about y?');

      // Only the first ask ever reads the selection.
      expect(selection.read).toHaveBeenCalledOnce();
      expect(view.show).toHaveBeenCalledOnce();
      expect(client.stream).toHaveBeenLastCalledWith('x', [
        { question: 'what is x?', answer: 'It means x.' },
        { question: 'what about y?', answer: undefined },
      ], expect.any(Function), expect.any(AbortSignal));
      expect(view.update).toHaveBeenLastCalledWith({
        status: 'thread',
        turns: [
          { question: 'what is x?', status: 'ready', markdown: 'It means x.' },
          { question: 'what about y?', status: 'ready', markdown: 'That part means y.' },
        ],
      });
    });

    it('shows the follow-up loading beside the first answer before it resolves', async () => {
      let resolve!: (text: string) => void;
      const { explain, view } = setup({
        explain: vi
          .fn()
          .mockResolvedValueOnce('It means x.')
          .mockImplementationOnce(() => new Promise((r) => (resolve = r))),
      });
      await explain.ask('what is x?');
      const pending = explain.ask('and?');
      await vi.waitFor(() =>
        expect(view.update).toHaveBeenLastCalledWith({
          status: 'thread',
          turns: [
            { question: 'what is x?', status: 'ready', markdown: 'It means x.' },
            { question: 'and?', status: 'loading' },
          ],
        })
      );
      resolve('More.');
      await pending;
    });

    it('a dismiss ends the thread: the next ask reads the selection fresh', async () => {
      const { explain, selection } = setup({});
      await explain.ask('what is x?');
      explain.dismiss();
      await explain.ask('again?');
      expect(selection.read).toHaveBeenCalledTimes(2);
    });
  });

  describe('a prefetched snapshot', () => {
    it('is used as-is, with no second Accessibility read', async () => {
      const { explain, view, client, selection } = setup({});
      await explain.ask('what is y?', { text: 'y', anchor });
      expect(selection.read).not.toHaveBeenCalled();
      expect(view.show).toHaveBeenCalledWith(anchor, {
        status: 'thread',
        turns: [{ question: 'what is y?', status: 'loading' }],
      });
      expect(client.stream).toHaveBeenCalledWith('y', [
        { question: 'what is y?', answer: undefined },
      ], expect.any(Function), expect.any(AbortSignal));
    });

    it('an explicit null still gives the "nothing selected" card, without reading', async () => {
      vi.useFakeTimers();
      const { explain, view, selection } = setup({});
      await explain.ask(undefined, null);
      expect(selection.read).not.toHaveBeenCalled();
      expect(view.show).toHaveBeenCalledWith(null, { status: 'empty' });
    });

    it('is ignored for a follow-up: the thread keeps its own selection', async () => {
      const { explain, client, selection } = setup({});
      await explain.ask('what is x?');
      await explain.ask('what about y?', { text: 'y', anchor });
      expect(selection.read).toHaveBeenCalledOnce();
      expect(client.stream).toHaveBeenLastCalledWith('x', [
        { question: 'what is x?', answer: 'It means x.' },
        { question: 'what about y?', answer: undefined },
      ], expect.any(Function), expect.any(AbortSignal));
    });
  });

  describe('streaming', () => {
    function scripted(events: ExplainStreamEvent[]) {
      return async (onEvent: (e: ExplainStreamEvent) => void) => {
        for (const event of events) onEvent(event);
      };
    }
    const lastTurn = (view: { update: { mock: { calls: unknown[][] } } }) =>
      (view.update.mock.calls.at(-1)![0] as { turns: unknown[] }).turns.at(-1);

    it('grows a streaming turn delta by delta, then finishes it with its sources', async () => {
      const sources = [{ title: 'Spec', url: 'https://spec.dev' }];
      const { explain, view } = setup({
        script: scripted([
          { type: 'delta', text: 'Same ' },
          { type: 'delta', text: 'result.' },
          { type: 'sources', sources },
          { type: 'done' },
        ]),
      });
      await explain.ask();
      const turns = view.update.mock.calls.map((c) => (c[0] as { turns: unknown[] }).turns[0]);
      expect(turns).toEqual([
        { question: undefined, status: 'streaming', markdown: 'Same ' },
        { question: undefined, status: 'streaming', markdown: 'Same result.' },
        { question: undefined, status: 'ready', markdown: 'Same result.', sources },
      ]);
    });

    it('shows what it is searching, and the next text clears the line', async () => {
      const seen: unknown[] = [];
      const { explain, view } = setup({
        script: async (onEvent) => {
          onEvent({ type: 'search', query: 'Mastra 1.67' });
          seen.push(lastTurn(view));
          onEvent({ type: 'delta', text: 'It adds X.' });
          seen.push(lastTurn(view));
          onEvent({ type: 'done' });
        },
      });
      await explain.ask();
      expect(seen).toEqual([
        { question: undefined, status: 'loading', searching: 'Mastra 1.67' },
        { question: undefined, status: 'streaming', markdown: 'It adds X.' },
      ]);
      expect(lastTurn(view)).toEqual({ question: undefined, status: 'ready', markdown: 'It adds X.' });
    });

    it('a reset drops the text so far, so talk about searching never stays', async () => {
      const seen: unknown[] = [];
      const { explain, view } = setup({
        script: async (onEvent) => {
          onEvent({ type: 'delta', text: "I'll search." });
          onEvent({ type: 'reset' });
          seen.push(lastTurn(view));
          onEvent({ type: 'search', query: 'q' });
          seen.push(lastTurn(view));
          onEvent({ type: 'delta', text: 'Answer.' });
          onEvent({ type: 'done' });
        },
      });
      await explain.ask();
      expect(seen).toEqual([
        { question: undefined, status: 'loading' },
        { question: undefined, status: 'loading', searching: 'q' },
      ]);
      expect(lastTurn(view)).toEqual({ question: undefined, status: 'ready', markdown: 'Answer.' });
    });

    it('keeps the text that arrived before an error', async () => {
      const { explain, view } = setup({
        script: scripted([
          { type: 'delta', text: 'Half an answer' },
          { type: 'error', message: 'The answer stopped early' },
        ]),
      });
      await explain.ask();
      expect(lastTurn(view)).toEqual({
        question: undefined,
        status: 'error',
        message: 'The answer stopped early',
        markdown: 'Half an answer',
      });
    });

    it('dismissing aborts the request, so a closed card stops the answer', async () => {
      const { explain, signals } = setup({ script: () => new Promise(() => {}) });
      void explain.ask();
      await vi.waitFor(() => expect(signals).toHaveLength(1));
      explain.dismiss();
      expect(signals[0]!.aborted).toBe(true);
    });

    it('a follow-up during a stream stops it and keeps what had arrived', async () => {
      let first = true;
      const { explain, view, signals } = setup({
        script: async (onEvent, signal) => {
          if (first) {
            first = false;
            onEvent({ type: 'delta', text: 'Partial.' });
            await new Promise((resolve) => signal.addEventListener('abort', resolve));
            return;
          }
          onEvent({ type: 'delta', text: 'Next.' });
          onEvent({ type: 'done' });
        },
      });
      const pending = explain.ask('what is x?');
      await vi.waitFor(() => expect(signals).toHaveLength(1));
      await explain.ask('and y?');
      await pending;
      expect(signals[0]!.aborted).toBe(true);
      expect(view.update).toHaveBeenLastCalledWith({
        status: 'thread',
        turns: [
          { question: 'what is x?', status: 'ready', markdown: 'Partial.' },
          { question: 'and y?', status: 'ready', markdown: 'Next.' },
        ],
      });
    });
  });
});

describe('createUpdateThrottle', () => {
  const streaming = { status: 'thread' as const, turns: [{ status: 'streaming' as const, markdown: 'a' }] };
  const ready = { status: 'thread' as const, turns: [{ status: 'ready' as const, markdown: 'ab' }] };

  it('coalesces streaming updates to the latest one per interval', () => {
    vi.useFakeTimers();
    const update = vi.fn();
    const throttled = createUpdateThrottle(update, 32);
    throttled(streaming);
    throttled({ ...streaming, turns: [{ status: 'streaming', markdown: 'ab' }] });
    throttled({ ...streaming, turns: [{ status: 'streaming', markdown: 'abc' }] });
    expect(update).toHaveBeenCalledTimes(1);
    vi.advanceTimersByTime(32);
    expect(update).toHaveBeenCalledTimes(2);
    expect(update).toHaveBeenLastCalledWith({ ...streaming, turns: [{ status: 'streaming', markdown: 'abc' }] });
  });

  it('sends a finished state at once and drops the pending streaming one', () => {
    vi.useFakeTimers();
    const update = vi.fn();
    const throttled = createUpdateThrottle(update, 32);
    throttled(streaming);
    throttled({ ...streaming, turns: [{ status: 'streaming', markdown: 'ab' }] });
    throttled(ready);
    expect(update).toHaveBeenLastCalledWith(ready);
    vi.advanceTimersByTime(100);
    expect(update).toHaveBeenCalledTimes(2);
  });
});
