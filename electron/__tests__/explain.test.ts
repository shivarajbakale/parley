import { afterEach, describe, expect, it, vi } from 'vitest';

import { createExplain, EMPTY_HIDE_MS } from '../explain';
import { RewriteError } from '../rewriter';
import type { ExplainTurnInput } from '../rewriter';
import type { SelectionSnapshot } from '../selection-reader';

const anchor = { x: 1, y: 2, width: 3, height: 4 };

function setup(options: {
  snapshot?: SelectionSnapshot | null;
  explain?: (text: string, turns: ExplainTurnInput[]) => Promise<string>;
}) {
  const view = { show: vi.fn(), update: vi.fn(), hide: vi.fn() };
  const rewriter = { explain: vi.fn(options.explain ?? (async () => 'It means x.')) };
  const snapshot = options.snapshot === undefined ? { text: 'x', anchor } : options.snapshot;
  const selection = { read: vi.fn().mockResolvedValue(snapshot) };
  const explain = createExplain({ selection, rewriter, view });
  return { explain, view, rewriter, selection };
}

afterEach(() => vi.useRealTimers());

describe('explain', () => {
  it('opens the card loading at the selection, then fills it with the answer', async () => {
    const { explain, view, rewriter } = setup({});
    await explain.ask();
    expect(view.show).toHaveBeenCalledWith(anchor, {
      status: 'thread',
      turns: [{ question: undefined, status: 'loading' }],
    });
    expect(rewriter.explain).toHaveBeenCalledWith('x', [{ question: undefined, answer: undefined }]);
    expect(view.update).toHaveBeenLastCalledWith({
      status: 'thread',
      turns: [{ question: undefined, status: 'ready', markdown: 'It means x.' }],
    });
  });

  it('answers a spoken question about the selection and shows it on the card', async () => {
    const { explain, view, rewriter } = setup({});
    await explain.ask('why is this here?');
    expect(view.show).toHaveBeenCalledWith(anchor, {
      status: 'thread',
      turns: [{ question: 'why is this here?', status: 'loading' }],
    });
    expect(rewriter.explain).toHaveBeenCalledWith('x', [
      { question: 'why is this here?', answer: undefined },
    ]);
  });

  it('says so, then hides itself, when nothing is selected', async () => {
    vi.useFakeTimers();
    const { explain, view, rewriter } = setup({ snapshot: null });
    await explain.ask();
    expect(view.show).toHaveBeenCalledWith(null, { status: 'empty' });
    expect(rewriter.explain).not.toHaveBeenCalled();
    vi.advanceTimersByTime(EMPTY_HIDE_MS);
    expect(view.hide).toHaveBeenCalledOnce();
  });

  it('shows the rewriter error kind as the message', async () => {
    const { explain, view } = setup({
      explain: async () => {
        throw new RewriteError('no_key');
      },
    });
    await explain.ask();
    expect(view.update).toHaveBeenLastCalledWith({
      status: 'thread',
      turns: [{ question: undefined, status: 'error', message: 'No MiniMax key' }],
    });
  });

  it('hides a generic message for anything unexpected', async () => {
    const { explain, view } = setup({
      explain: async () => {
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
    expect(view.update).toHaveBeenCalledTimes(1);
    expect(view.update).toHaveBeenCalledWith({
      status: 'thread',
      turns: [{ question: undefined, status: 'ready', markdown: 'new' }],
    });
  });

  describe('follow-up', () => {
    it('appends a second turn on the same selection, with the first as history', async () => {
      const { explain, view, rewriter, selection } = setup({
        explain: async (_text, turns) => (turns.length === 1 ? 'It means x.' : 'That part means y.'),
      });
      await explain.ask('what is x?');
      await explain.ask('what about y?');

      // Only the first ask ever reads the selection.
      expect(selection.read).toHaveBeenCalledOnce();
      expect(view.show).toHaveBeenCalledOnce();
      expect(rewriter.explain).toHaveBeenLastCalledWith('x', [
        { question: 'what is x?', answer: 'It means x.' },
        { question: 'what about y?', answer: undefined },
      ]);
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
      const { explain, view, rewriter, selection } = setup({});
      await explain.ask('what is y?', { text: 'y', anchor });
      expect(selection.read).not.toHaveBeenCalled();
      expect(view.show).toHaveBeenCalledWith(anchor, {
        status: 'thread',
        turns: [{ question: 'what is y?', status: 'loading' }],
      });
      expect(rewriter.explain).toHaveBeenCalledWith('y', [
        { question: 'what is y?', answer: undefined },
      ]);
    });

    it('an explicit null still gives the "nothing selected" card, without reading', async () => {
      vi.useFakeTimers();
      const { explain, view, selection } = setup({});
      await explain.ask(undefined, null);
      expect(selection.read).not.toHaveBeenCalled();
      expect(view.show).toHaveBeenCalledWith(null, { status: 'empty' });
    });

    it('is ignored for a follow-up: the thread keeps its own selection', async () => {
      const { explain, rewriter, selection } = setup({});
      await explain.ask('what is x?');
      await explain.ask('what about y?', { text: 'y', anchor });
      expect(selection.read).toHaveBeenCalledOnce();
      expect(rewriter.explain).toHaveBeenLastCalledWith('x', [
        { question: 'what is x?', answer: 'It means x.' },
        { question: 'what about y?', answer: undefined },
      ]);
    });
  });
});
