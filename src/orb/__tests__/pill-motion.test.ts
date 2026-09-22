import { describe, expect, it } from 'vitest';

import type { OrbUniforms } from '../frame';
import { PHASE_INDEX } from '../phase-mix';
import { pillMotion, POP_MS, SHUDDER_MS } from '../pill-motion';

const at = (patch: Partial<OrbUniforms>): OrbUniforms => ({
  flow: 0,
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

describe('pill endings', () => {
  it('holds still while listening', () => {
    expect(pillMotion(at({ age: 500 }))).toEqual({ scale: 1, offsetX: 0 });
  });

  it('pops on done, peaking mid-way and settling before the pill hides', () => {
    const done = (age: number) => pillMotion(at({ to: PHASE_INDEX.done, age })).scale;
    expect(done(POP_MS / 2)).toBeGreaterThan(1.05);
    expect(done(POP_MS)).toBe(1);
    expect(done(0)).toBe(1);
  });

  it('shudders sideways on error and dies out', () => {
    const shake = (age: number) => pillMotion(at({ to: PHASE_INDEX.error, age })).offsetX;
    const early = Math.max(...[10, 20, 30, 40].map(age => Math.abs(shake(age))));
    expect(early).toBeGreaterThan(2);
    expect(shake(SHUDDER_MS)).toBe(0);
  });

  it('shrinks away on a cancel as it fades', () => {
    const cancel = (mix: number) =>
      pillMotion(at({ from: PHASE_INDEX.listening, to: PHASE_INDEX.cancelled, mix })).scale;
    expect(cancel(0)).toBe(1);
    expect(cancel(1)).toBeLessThan(0.9);
  });

  it('moves nothing under reduced motion', () => {
    for (const to of [PHASE_INDEX.done, PHASE_INDEX.error, PHASE_INDEX.cancelled]) {
      expect(pillMotion(at({ to, age: 50, mix: 0.5, calm: 1 }))).toEqual({ scale: 1, offsetX: 0 });
    }
  });
});
