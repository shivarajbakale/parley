import type { GestureKey, KeyEvent, TapCount } from './types';

/**
 * Tap-tap-hold, as a pure state machine.
 *
 * No Electron imports, so the whole gesture is covered by unit tests. It only
 * observes events; nothing here can swallow a key.
 */

export const TAP_MAX_MS = 250;
export const GAP_MAX_MS = 300;
export const HOLD_MIN_MS = 150;

export interface GestureDetectorOptions {
  key: GestureKey;
  tapCount: TapCount;
  onStart(): void;
  onStop(): void;
  onCancel(): void;
}

export interface GestureDetector {
  handle(event: KeyEvent): void;
  configure(config: { key: GestureKey; tapCount: TapCount }): void;
}

export function createGestureDetector(options: GestureDetectorOptions): GestureDetector {
  let key = options.key;
  let tapCount = options.tapCount;

  let taps = 0;
  let downAt: number | null = null;
  let lastUpAt: number | null = null;
  let holdTimer: ReturnType<typeof setTimeout> | undefined;
  let recording = false;

  function reset() {
    taps = 0;
    downAt = null;
    lastUpAt = null;
    if (holdTimer) clearTimeout(holdTimer);
    holdTimer = undefined;
  }

  function handle(event: KeyEvent) {
    if (recording) {
      if (event.key === 'Escape' && event.type === 'down') {
        recording = false;
        reset();
        options.onCancel();
      } else if (event.key === key && event.type === 'up') {
        recording = false;
        reset();
        options.onStop();
      }
      return;
    }

    if (event.key !== key) {
      // Option+letter and friends must never look like a tap.
      if (event.type === 'down') reset();
      return;
    }

    if (event.type === 'down') {
      if (downAt !== null) return; // auto-repeat
      if (lastUpAt !== null && event.time - lastUpAt > GAP_MAX_MS) reset();
      downAt = event.time;
      if (taps === tapCount - 1) {
        holdTimer = setTimeout(() => {
          holdTimer = undefined;
          recording = true;
          options.onStart();
        }, HOLD_MIN_MS);
      }
      return;
    }

    if (downAt === null) return;
    const heldFor = event.time - downAt;
    downAt = null;

    // Released the final press before it became a hold, or held a tap too long.
    if (holdTimer || heldFor >= TAP_MAX_MS) {
      reset();
      return;
    }

    taps += 1;
    lastUpAt = event.time;
  }

  function configure(config: { key: GestureKey; tapCount: TapCount }) {
    // Every settings update calls this, including a vocabulary or tick-sound
    // change. Resetting then would make an in-progress hold forget it is
    // recording, so no `stop` would ever be emitted and the mic would stay
    // live until the auto-stop.
    if (config.key === key && config.tapCount === tapCount) return;
    // The gesture really did change under a live recording: end the session
    // rather than abandon it with the mic open.
    if (recording) options.onCancel();
    key = config.key;
    tapCount = config.tapCount;
    recording = false;
    reset();
  }

  return { handle, configure };
}
