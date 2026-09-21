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
}

export interface FrameInput {
  deltaMs: number;
  bands: Bands;
  phase: OrbPhase;
  reducedMotion: boolean;
}

const ATTACK_MS = 40;
const RELEASE_MS = 350;

/** Flow units per second at rest, and how much full mid energy adds. */
const BASE_FLOW = 0.35;
const MID_FLOW = 0.9;
const CALM_FLOW_SCALE = 0.35;

export function createFrame(initial: OrbPhase) {
  const envelopes = {
    low: createEnvelope({ attackMs: ATTACK_MS, releaseMs: RELEASE_MS }),
    mid: createEnvelope({ attackMs: ATTACK_MS, releaseMs: RELEASE_MS }),
    high: createEnvelope({ attackMs: ATTACK_MS, releaseMs: RELEASE_MS }),
  };
  const phaseMix = createPhaseMix(initial);
  let flow = 0;

  return {
    step({ deltaMs, bands, phase, reducedMotion }: FrameInput): OrbUniforms {
      const low = envelopes.low.next(bands.low, deltaMs);
      const mid = envelopes.mid.next(bands.mid, deltaMs);
      const high = envelopes.high.next(bands.high, deltaMs);

      // Flow is integrated, never `time * speed`: multiplying would make the
      // whole field jump every time the speed changed.
      const speed = (BASE_FLOW + mid * MID_FLOW) * (reducedMotion ? CALM_FLOW_SCALE : 1);
      flow += (Math.max(0, deltaMs) / 1000) * speed;

      phaseMix.set(phase);
      const { from, to, mix } = phaseMix.advance(deltaMs);

      return {
        flow,
        low,
        mid,
        high,
        from: PHASE_INDEX[from],
        to: PHASE_INDEX[to],
        mix,
        calm: reducedMotion ? 1 : 0,
      };
    },
  };
}
