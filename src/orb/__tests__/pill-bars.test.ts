import { describe, expect, it } from 'vitest';

import type { OrbUniforms } from '../frame';
import { PHASE_INDEX } from '../phase-mix';
import { BAR_COUNT, pillBars, pillOpacity } from '../pill-bars';

const uniforms = (patch: Partial<OrbUniforms> = {}): OrbUniforms => ({
  flow: 1,
  low: 0,
  mid: 0,
  high: 0,
  from: PHASE_INDEX.listening,
  to: PHASE_INDEX.listening,
  mix: 1,
  calm: 0,
  age: 0,
  pulse: 0,
  ...patch,
});

const sum = (values: number[]) => values.reduce((total, value) => total + value, 0);

describe('pill bars', () => {
  it('always gives one height per bar, within the pill', () => {
    for (const to of Object.values(PHASE_INDEX)) {
      const bars = pillBars(uniforms({ to, from: to, low: 1, mid: 1, high: 1, flow: 12.3 }));
      expect(bars).toHaveLength(BAR_COUNT);
      for (const bar of bars) {
        expect(bar).toBeGreaterThanOrEqual(0);
        expect(bar).toBeLessThanOrEqual(1);
      }
    }
  });

  it('keeps breathing in silence instead of going flat', () => {
    const bars = pillBars(uniforms());
    expect(Math.min(...bars)).toBeGreaterThan(0.1);
    expect(Math.max(...bars)).toBeLessThan(0.3);
  });

  it('grows with the voice: low in the middle, high at the ends', () => {
    const quiet = pillBars(uniforms());
    const bass = pillBars(uniforms({ low: 1 }));
    const hiss = pillBars(uniforms({ high: 1 }));
    expect(sum(bass)).toBeGreaterThan(sum(quiet));
    const middle = (BAR_COUNT - 1) / 2;
    expect(bass[middle]).toBeGreaterThan(bass[0]);
    expect(hiss[0]).toBeGreaterThan(hiss[middle]);
  });

  it('ignores the microphone while transcribing, and moves a crest along', () => {
    const phase = { from: PHASE_INDEX.transcribing, to: PHASE_INDEX.transcribing };
    expect(pillBars(uniforms({ ...phase, low: 1 }))).toEqual(pillBars(uniforms(phase)));
    const early = pillBars(uniforms({ ...phase, flow: 0.5 }));
    const later = pillBars(uniforms({ ...phase, flow: 1.2 }));
    expect(later.indexOf(Math.max(...later))).toBeGreaterThan(early.indexOf(Math.max(...early)));
  });

  it('crossfades between phases, and fades the whole pill in from nothing', () => {
    const halfway = uniforms({ from: PHASE_INDEX.cancelled, to: PHASE_INDEX.done, mix: 0.5 });
    const done = pillBars(uniforms({ from: PHASE_INDEX.done, to: PHASE_INDEX.done }));
    expect(pillBars(halfway)[3]).toBeCloseTo(done[3] / 2, 6);
    expect(pillOpacity(halfway)).toBeCloseTo(0.5, 6);
    expect(pillOpacity(uniforms())).toBe(1);
  });
});
