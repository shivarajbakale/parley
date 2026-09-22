import type { OrbUniforms } from './frame';
import { PHASE_INDEX } from './phase-mix';

/**
 * How each ending moves the whole pill, as a pure function of the frame so the
 * choreography is a unit test and the canvas only applies it. Each outcome
 * reads differently at a glance, not only by colour: text landed pops, an
 * error shudders, a cancel shrinks away. Reduced motion keeps all three still.
 */

export interface PillMotion {
  /** Scale about the pill's centre. */
  scale: number;
  /** Sideways offset in CSS pixels. */
  offsetX: number;
}

/** The done pop has to finish inside the 300 ms the session shows done for. */
export const POP_MS = 240;
const POP = 0.09;

export const SHUDDER_MS = 420;
const SHUDDER_PX = 5;
const SHUDDER_HZ = 11;

const SHRINK = 0.18;

const STILL: PillMotion = { scale: 1, offsetX: 0 };

export function pillMotion(uniforms: OrbUniforms): PillMotion {
  if (uniforms.calm) return STILL;
  const { to, from, age, mix } = uniforms;

  if (to === PHASE_INDEX.done && age < POP_MS) {
    return { scale: 1 + POP * Math.sin((Math.PI * age) / POP_MS), offsetX: 0 };
  }
  if (to === PHASE_INDEX.error && age < SHUDDER_MS) {
    const left = 1 - age / SHUDDER_MS;
    const wave = Math.sin((age / 1000) * 2 * Math.PI * SHUDDER_HZ);
    return { scale: 1, offsetX: SHUDDER_PX * wave * left * left };
  }
  if (to === PHASE_INDEX.cancelled && from !== PHASE_INDEX.cancelled) {
    return { scale: 1 - SHRINK * mix, offsetX: 0 };
  }
  return STILL;
}
