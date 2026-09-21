import type { OrbPhase } from '../../electron/types';

/** No hard cuts: every phase change crossfades in the shader over this long. */
export const PHASE_FADE_MS = 300;

/** What the shader receives. `cancelled` draws nothing, and a `notice` is not drawn here at all. */
export const PHASE_INDEX: Record<OrbPhase, number> = {
  cancelled: 0,
  listening: 1,
  transcribing: 2,
  done: 3,
  error: 4,
  notice: 0,
};

export function createPhaseMix(initial: OrbPhase) {
  let from = initial;
  let to = initial;
  let mix = 1;
  return {
    set(phase: OrbPhase) {
      if (phase === to) return;
      from = to;
      to = phase;
      mix = 0;
    },
    advance(deltaMs: number) {
      mix = Math.min(1, mix + Math.max(0, deltaMs) / PHASE_FADE_MS);
      return { from, to, mix };
    },
  };
}
