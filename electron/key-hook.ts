import { GESTURE_KEYS, type KeyEvent, type KeyName } from './types';

/**
 * Adapter between `uiohook-napi` and the gesture detector. The hook and its
 * keycode table are passed in, so this file never imports the native module
 * and can be tested anywhere.
 */

export interface HookLike {
  on(event: 'keydown' | 'keyup', listener: (e: { keycode: number }) => void): unknown;
  start(): void;
  stop(): void;
}

export function createKeyHook(
  hook: HookLike,
  keycodes: Record<string, number>,
  onEvent: (event: KeyEvent) => void,
  now: () => number = () => performance.now()
) {
  const names = new Map<number, KeyName>();
  for (const name of [...GESTURE_KEYS, 'Escape'] as const) {
    const code = keycodes[name];
    if (typeof code === 'number') names.set(code, name);
  }

  const forward = (type: KeyEvent['type']) => (e: { keycode: number }) =>
    onEvent({ type, key: names.get(e.keycode) ?? 'Other', time: now() });

  hook.on('keydown', forward('down'));
  hook.on('keyup', forward('up'));

  return {
    start: () => hook.start(),
    stop: () => hook.stop(),
  };
}
