import { afterEach, describe, expect, it, vi } from 'vitest';

import { createExplain, EMPTY_HIDE_MS } from '../explain';
import { RewriteError } from '../rewriter';
import type { SelectionSnapshot } from '../selection-reader';

const anchor = { x: 1, y: 2, width: 3, height: 4 };

function setup(options: {
  snapshot?: SelectionSnapshot | null;
  explain?: (text: string) => Promise<string>;
}) {
  const view = { show: vi.fn(), update: vi.fn(), hide: vi.fn() };
  const rewriter = { explain: vi.fn(options.explain ?? (async () => 'It means x.')) };
  const selection = {
    read: vi.fn().mockResolvedValue(options.snapshot === undefined ? { text: 'x', anchor } : options.snapshot),
  };
  const explain = createExplain({ selection, rewriter, view });
  return { explain, view, rewriter, selection };
}

afterEach(() => vi.useRealTimers());

describe('explain', () => {
  it('opens the card loading at the selection, then fills it with the answer', async () => {
    const { explain, view, rewriter } = setup({});
    await explain.trigger();
    expect(view.show).toHaveBeenCalledWith(anchor, { status: 'loading' });
    expect(rewriter.explain).toHaveBeenCalledWith('x');
    expect(view.update).toHaveBeenCalledWith({ status: 'ready', markdown: 'It means x.' });
  });

  it('says so, then hides itself, when nothing is selected', async () => {
    vi.useFakeTimers();
    const { explain, view, rewriter } = setup({ snapshot: null });
    await explain.trigger();
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
    await explain.trigger();
    expect(view.update).toHaveBeenCalledWith({ status: 'error', message: 'No MiniMax key' });
  });

  it('hides a generic message for anything unexpected', async () => {
    const { explain, view } = setup({
      explain: async () => {
        throw new Error('boom: secret detail');
      },
    });
    await explain.trigger();
    expect(view.update).toHaveBeenCalledWith({ status: 'error', message: 'Something went wrong' });
  });

  it('drops a slow answer once the card was dismissed', async () => {
    let resolve!: (text: string) => void;
    const { explain, view } = setup({ explain: () => new Promise((r) => (resolve = r)) });
    const pending = explain.trigger();
    await vi.waitFor(() => expect(view.show).toHaveBeenCalled());
    explain.dismiss();
    resolve('late');
    await pending;
    expect(view.update).not.toHaveBeenCalled();
    expect(view.hide).toHaveBeenCalledOnce();
  });

  it('lets a newer trigger supersede an older answer', async () => {
    const resolvers: ((text: string) => void)[] = [];
    const { explain, view } = setup({ explain: () => new Promise((r) => resolvers.push(r)) });
    const first = explain.trigger();
    await vi.waitFor(() => expect(resolvers).toHaveLength(1));
    const second = explain.trigger();
    await vi.waitFor(() => expect(resolvers).toHaveLength(2));
    resolvers[0]('old');
    resolvers[1]('new');
    await Promise.all([first, second]);
    expect(view.update).toHaveBeenCalledOnce();
    expect(view.update).toHaveBeenCalledWith({ status: 'ready', markdown: 'new' });
  });
});
