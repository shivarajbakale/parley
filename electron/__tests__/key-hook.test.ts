import { describe, expect, it, vi } from 'vitest';

import { createKeyHook, type HookLike } from '../key-hook';

const KEYCODES = { AltRight: 3640, Alt: 56, Escape: 1, A: 30 };

function fakeHook() {
  const listeners: Record<string, (e: { keycode: number }) => void> = {};
  const hook: HookLike = {
    on: (event, listener) => {
      listeners[event] = listener;
    },
    start: vi.fn(),
    stop: vi.fn(),
  };
  return { hook, listeners };
}

describe('key hook', () => {
  it('names gesture keys and Escape, and calls everything else Other', () => {
    const { hook, listeners } = fakeHook();
    const onEvent = vi.fn();
    createKeyHook(hook, KEYCODES, onEvent, () => 42);

    listeners.keydown({ keycode: 3640 });
    listeners.keyup({ keycode: 1 });
    listeners.keydown({ keycode: 30 });

    expect(onEvent.mock.calls.map(([e]) => e)).toEqual([
      { type: 'down', key: 'AltRight', time: 42 },
      { type: 'up', key: 'Escape', time: 42 },
      { type: 'down', key: 'Other', time: 42 },
    ]);
  });

  it('starts and stops the underlying hook', () => {
    const { hook } = fakeHook();
    const keyHook = createKeyHook(hook, KEYCODES, vi.fn());
    keyHook.start();
    keyHook.stop();
    expect(hook.start).toHaveBeenCalledTimes(1);
    expect(hook.stop).toHaveBeenCalledTimes(1);
  });
});
