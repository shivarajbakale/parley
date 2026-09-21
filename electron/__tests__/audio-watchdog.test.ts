import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { createAudioWatchdog } from '../audio-watchdog';

describe('audio watchdog', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('fires once after the timeout when armed', () => {
    const onTimeout = vi.fn();
    const watchdog = createAudioWatchdog({ timeoutMs: 5000, onTimeout });

    watchdog.arm();
    vi.advanceTimersByTime(4999);
    expect(onTimeout).not.toHaveBeenCalled();

    vi.advanceTimersByTime(1);
    expect(onTimeout).toHaveBeenCalledTimes(1);

    // The timer does not repeat on its own.
    vi.advanceTimersByTime(10000);
    expect(onTimeout).toHaveBeenCalledTimes(1);
  });

  it('is cleared by valid audio, so it never fires', () => {
    const onTimeout = vi.fn();
    const watchdog = createAudioWatchdog({ timeoutMs: 5000, onTimeout });

    watchdog.arm();
    vi.advanceTimersByTime(2000);
    watchdog.clear();
    vi.advanceTimersByTime(10000);

    expect(onTimeout).not.toHaveBeenCalled();
  });

  it('re-arming resets the timer instead of stacking a second one', () => {
    const onTimeout = vi.fn();
    const watchdog = createAudioWatchdog({ timeoutMs: 5000, onTimeout });

    watchdog.arm();
    vi.advanceTimersByTime(3000);
    watchdog.arm();
    vi.advanceTimersByTime(3000);
    expect(onTimeout).not.toHaveBeenCalled();

    vi.advanceTimersByTime(2000);
    expect(onTimeout).toHaveBeenCalledTimes(1);
  });

  it('clearing when never armed is a no-op', () => {
    const onTimeout = vi.fn();
    const watchdog = createAudioWatchdog({ timeoutMs: 5000, onTimeout });

    expect(() => watchdog.clear()).not.toThrow();
    vi.advanceTimersByTime(10000);
    expect(onTimeout).not.toHaveBeenCalled();
  });
});
