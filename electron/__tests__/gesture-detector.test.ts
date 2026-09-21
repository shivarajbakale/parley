import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { createGestureDetector, HOLD_MIN_MS } from '../gesture-detector';
import type { GestureKey, KeyName, TapCount } from '../types';

function setup(key: GestureKey = 'AltRight', tapCount: TapCount = 3) {
  const onStart = vi.fn();
  const onStop = vi.fn();
  const onCancel = vi.fn();
  const detector = createGestureDetector({ key, tapCount, onStart, onStop, onCancel });
  let time = 0;
  const down = (k: KeyName = key) => detector.handle({ type: 'down', key: k, time });
  const up = (k: KeyName = key) => detector.handle({ type: 'up', key: k, time });
  const wait = (ms: number) => {
    time += ms;
    vi.advanceTimersByTime(ms);
  };
  const tap = (k: KeyName = key) => {
    down(k);
    wait(80);
    up(k);
    wait(100);
  };
  return { detector, onStart, onStop, onCancel, down, up, wait, tap };
}

describe('gesture detector', () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it('emits start after two taps and a held third press, then stop on release', () => {
    const g = setup();
    g.tap();
    g.tap();
    g.down();
    g.wait(HOLD_MIN_MS - 1);
    expect(g.onStart).not.toHaveBeenCalled();
    g.wait(1);
    expect(g.onStart).toHaveBeenCalledTimes(1);
    g.wait(2000);
    g.up();
    expect(g.onStop).toHaveBeenCalledTimes(1);
    expect(g.onCancel).not.toHaveBeenCalled();
  });

  it('ignores a third press released before the hold threshold', () => {
    const g = setup();
    g.tap();
    g.tap();
    g.tap();
    g.wait(1000);
    expect(g.onStart).not.toHaveBeenCalled();
  });

  it('resets when a tap is held too long', () => {
    const g = setup();
    g.down();
    g.wait(260);
    g.up();
    g.wait(100);
    g.tap();
    g.down();
    g.wait(500);
    expect(g.onStart).not.toHaveBeenCalled();
  });

  it('resets when the gap between taps is too long', () => {
    const g = setup();
    g.tap();
    g.wait(400);
    g.tap();
    g.down();
    g.wait(500);
    expect(g.onStart).not.toHaveBeenCalled();
  });

  it('resets when another key is pressed between taps', () => {
    const g = setup();
    g.tap();
    g.tap('Other');
    g.tap();
    g.down();
    g.wait(500);
    expect(g.onStart).not.toHaveBeenCalled();
  });

  it('cancels on Escape while held, and the later release does not stop', () => {
    const g = setup();
    g.tap();
    g.tap();
    g.down();
    g.wait(500);
    g.down('Escape');
    expect(g.onCancel).toHaveBeenCalledTimes(1);
    g.up();
    expect(g.onStop).not.toHaveBeenCalled();
  });

  it('ignores other keys while recording', () => {
    const g = setup();
    g.tap();
    g.tap();
    g.down();
    g.wait(500);
    g.tap('Other');
    g.up();
    expect(g.onStop).toHaveBeenCalledTimes(1);
  });

  it('ignores auto-repeat keydown events', () => {
    const g = setup();
    g.tap();
    g.tap();
    g.down();
    g.wait(50);
    g.down();
    g.wait(200);
    expect(g.onStart).toHaveBeenCalledTimes(1);
  });

  it('honours a configured key and tap count', () => {
    const g = setup('CtrlRight', 2);
    g.tap();
    g.down();
    g.wait(200);
    expect(g.onStart).toHaveBeenCalledTimes(1);
  });

  it('applies configure() and drops any half-finished gesture', () => {
    const g = setup();
    g.tap();
    g.detector.configure({ key: 'Shift', tapCount: 2 });
    g.tap('Shift');
    g.down('Shift');
    g.wait(200);
    expect(g.onStart).toHaveBeenCalledTimes(1);
  });

  it('can run the gesture again after a completed one', () => {
    const g = setup();
    for (let i = 0; i < 2; i += 1) {
      g.tap();
      g.tap();
      g.down();
      g.wait(300);
      g.up();
      g.wait(500);
    }
    expect(g.onStart).toHaveBeenCalledTimes(2);
    expect(g.onStop).toHaveBeenCalledTimes(2);
  });
});
