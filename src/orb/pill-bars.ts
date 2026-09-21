import type { OrbUniforms } from './frame';
import { PHASE_INDEX } from './phase-mix';

/**
 * Bar heights for the waveform pill, 0 to 1 of the room inside it. Pure, so
 * what each phase looks like is a unit test and the canvas only paints.
 */

export const BAR_COUNT = 7;

/** A bar is never shorter than this: a flat pill reads as a dead one. */
const REST = 0.14;

const clamp01 = (value: number) => Math.min(1, Math.max(0, value));

function phaseBars(phase: number, uniforms: OrbUniforms): number[] {
  const { flow, low, mid, high } = uniforms;
  const centre = (BAR_COUNT - 1) / 2;

  return Array.from({ length: BAR_COUNT }, (_, index) => {
    // 0 at the middle bar, 1 at the two ends.
    const spread = Math.abs(index - centre) / centre;

    if (phase === PHASE_INDEX.listening) {
      // The body of a voice sits in the middle bars and its sibilance at the
      // ends, the way a spectrum folded around its centre would look.
      const level = low * (1 - spread) + mid * (1 - Math.abs(spread - 0.5) * 2) * 0.9 + high * spread;
      // Bars never move in lockstep: each rides its own slow wobble.
      const wobble = 0.75 + 0.25 * Math.sin(flow * 5 + index * 1.7);
      const breath = 0.05 * (1 + Math.sin(flow * 2 + index * 0.9));
      return clamp01(REST + breath + level * wobble * 0.9);
    }
    if (phase === PHASE_INDEX.transcribing) {
      // One soft crest sweeping left to right, then wrapping round.
      const position = ((flow * 4) % (BAR_COUNT + 3)) - 1.5;
      const distance = index - position;
      return clamp01(REST + 0.1 + 0.55 * Math.exp(-(distance * distance) / 1.6));
    }
    if (phase === PHASE_INDEX.done) return 0.34 + 0.22 * (1 - spread);
    if (phase === PHASE_INDEX.error) return 0.22 + 0.06 * Math.sin(flow * 4);
    return 0;
  });
}

export function pillBars(uniforms: OrbUniforms): number[] {
  const from = phaseBars(uniforms.from, uniforms);
  const to = phaseBars(uniforms.to, uniforms);
  return to.map((height, index) => from[index] + (height - from[index]) * uniforms.mix);
}

/** How visible the whole pill is: it fades with the phase crossfade, like the bars. */
export function pillOpacity(uniforms: OrbUniforms): number {
  const shown = (phase: number) => (phase === PHASE_INDEX.cancelled ? 0 : 1);
  return shown(uniforms.from) + (shown(uniforms.to) - shown(uniforms.from)) * uniforms.mix;
}
