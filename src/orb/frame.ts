import type { OrbPhase } from '../../electron/types';

import type { Bands } from './bands';
import { createEnvelope } from './envelope';
import { createPhaseMix, PHASE_INDEX } from './phase-mix';

/**
 * One frame of orb state. Everything that decides how the orb looks, short of
 * the pixels, happens here so it can be tested without a GPU.
 */
export interface OrbUniforms {
  flow: number;
  low: number;
  mid: number;
  high: number;
  from: number;
  to: number;
  mix: number;
  calm: number;
  /** Milliseconds since the current phase began: endings play against it. */
  age: number;
  /** 1 the frame a pulse lands, easing back to 0. Always 0 under reduced motion. */
  pulse: number;
}

export interface FrameInput {
  deltaMs: number;
  bands: Bands;
  phase: OrbPhase;
  reducedMotion: boolean;
  /** A running count of pulses, such as key presses. Each increase kicks once. */
  pulses?: number;
}

const ATTACK_MS = 40;
const RELEASE_MS = 350;

/** Flow units per second at rest, and how much full mid energy adds. */
const BASE_FLOW = 0.35;
const MID_FLOW = 0.9;
const CALM_FLOW_SCALE = 0.35;

/** How fast a pulse eases off: about a quarter second to fade out. */
const PULSE_DECAY_MS = 90;

export function createFrame(initial: OrbPhase) {
  const envelopes = {
    low: createEnvelope({ attackMs: ATTACK_MS, releaseMs: RELEASE_MS }),
    mid: createEnvelope({ attackMs: ATTACK_MS, releaseMs: RELEASE_MS }),
    high: createEnvelope({ attackMs: ATTACK_MS, releaseMs: RELEASE_MS }),
  };
  const phaseMix = createPhaseMix(initial);
  let flow = 0;
  let current = initial;
  let age = 0;
  let pulse = 0;
  let seenPulses: number | null = null;

  return {
    step({ deltaMs, bands, phase, reducedMotion, pulses }: FrameInput): OrbUniforms {
      const dt = Math.max(0, deltaMs);
      const low = envelopes.low.next(bands.low, deltaMs);
      const mid = envelopes.mid.next(bands.mid, deltaMs);
      const high = envelopes.high.next(bands.high, deltaMs);

      // Flow is integrated, never `time * speed`: multiplying would make the
      // whole field jump every time the speed changed.
      const speed = (BASE_FLOW + mid * MID_FLOW) * (reducedMotion ? CALM_FLOW_SCALE : 1);
      flow += (dt / 1000) * speed;

      phaseMix.set(phase);
      const { from, to, mix } = phaseMix.advance(deltaMs);
      age = phase === current ? age + dt : 0;
      current = phase;

      // The first count only sets the baseline, so mounting mid-count never kicks.
      pulse *= Math.exp(-dt / PULSE_DECAY_MS);
      if (pulses !== undefined) {
        if (seenPulses !== null && pulses > seenPulses) pulse = 1;
        seenPulses = pulses;
      }
      if (reducedMotion) pulse = 0;

      return {
        flow,
        low,
        mid,
        high,
        from: PHASE_INDEX[from],
        to: PHASE_INDEX[to],
        mix,
        calm: reducedMotion ? 1 : 0,
        age,
        pulse,
      };
    },
  };
}
