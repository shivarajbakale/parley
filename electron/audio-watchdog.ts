/**
 * Guards against a dropped `orb:audio` message wedging a session forever in
 * `awaiting_audio`. `main.ts` arms this when the session enters that wait
 * (the orb's `transcribing` phase) and clears it the moment audio actually
 * arrives or the session leaves the wait some other way. If it fires, the
 * caller recovers by feeding the session an empty, zero-duration audio
 * payload — the same path a too-short recording already takes.
 *
 * Kept pure and Electron-free so the timing logic is unit-testable with fake
 * timers.
 */

export interface AudioWatchdogDeps {
  timeoutMs: number;
  onTimeout(): void;
}

export interface AudioWatchdog {
  /** (Re-)start the timer, replacing any timer already running. */
  arm(): void;
  /** Cancel a pending timer. Safe to call when nothing is armed. */
  clear(): void;
}

export function createAudioWatchdog(deps: AudioWatchdogDeps): AudioWatchdog {
  let timer: ReturnType<typeof setTimeout> | undefined;

  function clear() {
    if (timer) clearTimeout(timer);
    timer = undefined;
  }

  function arm() {
    clear();
    timer = setTimeout(() => {
      timer = undefined;
      deps.onTimeout();
    }, deps.timeoutMs);
  }

  return { arm, clear };
}
