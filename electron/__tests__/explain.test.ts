import { afterEach, describe, expect, it, vi } from 'vitest';

import { createExplain, EMPTY_HIDE_MS } from '../explain';
import { RewriteError } from '../rewriter';
import type { SelectionSnapshot } from '../selection-reader';

const anchor = { x: 1, y: 2, width: 3, height: 4 };

function setup(options: {
  snapshot?: SelectionSnapshot | null;
  explain?: (text: string, question?: string) => Promise<string>;
}) {
  const view = { show: vi.fn(), update: vi.fn(), hide: vi.fn() };
  const rewriter = { explain: vi.fn(options.explain ?? (async () => 'It means x.')) };
  const snapshot = options.snapshot === undefined ? { text: 'x', anchor } : options.snapshot;
  const explain = createExplain({ rewriter, view });
  return { explain, view, rewriter, snapshot };
}

afterEach(() => vi.useRealTimers());

describe('explain', () => {
  it('opens the card loading at the selection, then fills it with the answer', async () => {
    const { explain, view, rewriter, snapshot } = setup({});
    await explain.answer(snapshot);
    expect(view.show).toHaveBeenCalledWith(anchor, { status: 'loading', question: undefined });
    expect(rewriter.explain).toHaveBeenCalledWith('x', undefined);
    expect(view.update).toHaveBeenCalledWith({
      status: 'ready',
      markdown: 'It means x.',
      question: undefined,
    });
  });

  it('answers a spoken question about the selection and shows it on the card', async () => {
    const { explain, view, rewriter, snapshot } = setup({});
    await explain.answer(snapshot, 'why is this here?');
    expect(view.show).toHaveBeenCalledWith(anchor, { status: 'loading', question: 'why is this here?' });
    expect(rewriter.explain).toHaveBeenCalledWith('x', 'why is this here?');
    expect(view.update).toHaveBeenCalledWith({
      status: 'ready',
      markdown: 'It means x.',
      question: 'why is this here?',
    });
  });

  it('says so, then hides itself, when nothing is selected', async () => {
    vi.useFakeTimers();
    const { explain, view, rewriter, snapshot } = setup({ snapshot: null });
    await explain.answer(snapshot);
    expect(view.show).toHaveBeenCalledWith(null, { status: 'empty' });
    expect(rewriter.explain).not.toHaveBeenCalled();
    vi.advanceTimersByTime(EMPTY_HIDE_MS);
    expect(view.hide).toHaveBeenCalledOnce();
  });

  it('shows the rewriter error kind as the message', async () => {
    const { explain, view, snapshot } = setup({
      explain: async () => {
        throw new RewriteError('no_key');
      },
    });
    await explain.answer(snapshot);
    expect(view.update).toHaveBeenCalledWith({ status: 'error', message: 'No MiniMax key' });
  });

  it('hides a generic message for anything unexpected', async () => {
    const { explain, view, snapshot } = setup({
      explain: async () => {
        throw new Error('boom: secret detail');
      },
    });
    await explain.answer(snapshot);
    expect(view.update).toHaveBeenCalledWith({ status: 'error', message: 'Something went wrong' });
  });

  it('drops a slow answer once the card was dismissed', async () => {
    let resolve!: (text: string) => void;
    const { explain, view, snapshot } = setup({ explain: () => new Promise((r) => (resolve = r)) });
    const pending = explain.answer(snapshot);
    await vi.waitFor(() => expect(view.show).toHaveBeenCalled());
    explain.dismiss();
    resolve('late');
    await pending;
    expect(view.update).not.toHaveBeenCalled();
    expect(view.hide).toHaveBeenCalledOnce();
  });

  it('lets a newer answer supersede an older answer', async () => {
    const resolvers: ((text: string) => void)[] = [];
    const { explain, view, snapshot } = setup({ explain: () => new Promise((r) => resolvers.push(r)) });
    const first = explain.answer(snapshot);
    await vi.waitFor(() => expect(resolvers).toHaveLength(1));
    const second = explain.answer(snapshot);
    await vi.waitFor(() => expect(resolvers).toHaveLength(2));
    resolvers[0]('old');
    resolvers[1]('new');
    await Promise.all([first, second]);
    expect(view.update).toHaveBeenCalledOnce();
    expect(view.update).toHaveBeenCalledWith({ status: 'ready', markdown: 'new', question: undefined });
  });
});
