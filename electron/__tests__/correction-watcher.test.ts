import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { createCorrectionWatcher, POLL_MS, WATCH_MS } from '../correction-watcher';
import type { FocusedField } from '../field-reader';

const field = (value: string, rest: Partial<FocusedField> = {}): FocusedField => ({
  editable: true,
  valueKnown: true,
  value,
  selectedText: '',
  secure: false,
  selectionBounds: null,
    frontWindowBounds: null,
  ...rest,
});

function setup(reads: (FocusedField | null)[]) {
  const read = vi.fn();
  for (const value of reads) read.mockResolvedValueOnce(value);
  read.mockResolvedValue(reads[reads.length - 1] ?? null);
  const detect = vi.fn((_pasted: string, value: string) =>
    value.includes('MiniMax') ? { heard: 'mini max', word: 'MiniMax' } : null
  );
  const onCorrection = vi.fn();
  const watcher = createCorrectionWatcher({ reader: { read }, detect, onCorrection });
  return { watcher, read, detect, onCorrection };
}

describe('correction watcher', () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it('reports a fix once it has held still for two reads', async () => {
    const { watcher, onCorrection, read } = setup([
      field('I tested mini max'),
      field('I tested MiniMax'),
      field('I tested MiniMax'),
    ]);
    watcher.watch('I tested mini max');

    await vi.advanceTimersByTimeAsync(POLL_MS * 2);
    expect(onCorrection).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(POLL_MS);
    expect(onCorrection).toHaveBeenCalledExactlyOnceWith({ heard: 'mini max', word: 'MiniMax' });

    await vi.advanceTimersByTimeAsync(WATCH_MS);
    expect(read).toHaveBeenCalledTimes(3);
  });

  it('stops when focus leaves the field', async () => {
    const { watcher, read, onCorrection } = setup([field('x'), null]);
    watcher.watch('x');
    await vi.advanceTimersByTimeAsync(WATCH_MS);
    expect(read).toHaveBeenCalledTimes(2);
    expect(onCorrection).not.toHaveBeenCalled();
  });

  it('stops at once in an app that hides the value', async () => {
    const { watcher, read } = setup([field('', { valueKnown: false })]);
    watcher.watch('x');
    await vi.advanceTimersByTimeAsync(WATCH_MS);
    expect(read).toHaveBeenCalledTimes(1);
  });

  it('gives up after the watch window', async () => {
    const { watcher, read } = setup([field('I tested mini max')]);
    watcher.watch('I tested mini max');
    await vi.advanceTimersByTimeAsync(WATCH_MS * 3);
    expect(read).toHaveBeenCalledTimes(WATCH_MS / POLL_MS);
  });

  it('cancel stops the reads, even one already in flight', async () => {
    const { watcher, read, onCorrection } = setup([field('I tested MiniMax')]);
    watcher.watch('I tested mini max');
    await vi.advanceTimersByTimeAsync(POLL_MS);
    watcher.cancel();
    await vi.advanceTimersByTimeAsync(WATCH_MS);
    expect(read).toHaveBeenCalledTimes(1);
    expect(onCorrection).not.toHaveBeenCalled();
  });

  it('a new watch replaces the old one', async () => {
    const { watcher, detect } = setup([field('anything')]);
    watcher.watch('first');
    watcher.watch('second');
    await vi.advanceTimersByTimeAsync(POLL_MS);
    expect(detect).toHaveBeenCalledTimes(1);
    expect(detect).toHaveBeenCalledWith('second', 'anything');
  });
});
