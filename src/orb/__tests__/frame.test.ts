import { describe, expect, it } from 'vitest';

import { createFrame } from '../frame';

const LOUD = { low: 1, mid: 1, high: 1 };
const SILENT = { low: 0, mid: 0, high: 0 };

describe('createFrame', () => {
  it('smooths the bands instead of passing them straight through', () => {
    const frame = createFrame('listening');
    const first = frame.step({ deltaMs: 16, bands: LOUD, phase: 'listening', reducedMotion: false });
    expect(first.low).toBeGreaterThan(0);
    expect(first.low).toBeLessThan(0.5);
  });

  it('lets the bands fall slowly after the voice stops', () => {
    const frame = createFrame('listening');
    frame.step({ deltaMs: 1000, bands: LOUD, phase: 'listening', reducedMotion: false });
    const after = frame.step({ deltaMs: 16, bands: SILENT, phase: 'listening', reducedMotion: false });
    expect(after.low).toBeGreaterThan(0.9);
  });

  it('advances flow every frame and faster with mid energy, never backwards', () => {
    const quiet = createFrame('listening');
    const loud = createFrame('listening');
    const quietFlow = quiet.step({ deltaMs: 1000, bands: SILENT, phase: 'listening', reducedMotion: false }).flow;
    const loudFlow = loud.step({ deltaMs: 1000, bands: LOUD, phase: 'listening', reducedMotion: false }).flow;
    expect(quietFlow).toBeGreaterThan(0);
    expect(loudFlow).toBeGreaterThan(quietFlow);
  });

  it('slows flow and reports calm under reduced motion', () => {
    const normal = createFrame('listening');
    const reduced = createFrame('listening');
    const input = { deltaMs: 1000, bands: SILENT, phase: 'listening' as const };
    const normalStep = normal.step({ ...input, reducedMotion: false });
    const reducedStep = reduced.step({ ...input, reducedMotion: true });
    expect(reducedStep.flow).toBeLessThan(normalStep.flow);
    expect(reducedStep.calm).toBe(1);
    expect(normalStep.calm).toBe(0);
  });

  it('reports the phase crossfade as shader indices', () => {
    const frame = createFrame('cancelled');
    const step = frame.step({ deltaMs: 150, bands: SILENT, phase: 'listening', reducedMotion: false });
    expect(step).toMatchObject({ from: 0, to: 1, mix: 0.5 });
  });

  it('counts the age of the current phase and restarts it on a change', () => {
    const frame = createFrame('listening');
    const input = { bands: SILENT, reducedMotion: false };
    frame.step({ ...input, deltaMs: 100, phase: 'listening' });
    expect(frame.step({ ...input, deltaMs: 100, phase: 'listening' }).age).toBe(200);
    expect(frame.step({ ...input, deltaMs: 16, phase: 'done' }).age).toBe(0);
    expect(frame.step({ ...input, deltaMs: 50, phase: 'done' }).age).toBe(50);
  });

  it('kicks a pulse when the count rises, then eases it off', () => {
    const frame = createFrame('listening');
    const input = { bands: SILENT, phase: 'listening' as const, reducedMotion: false };
    expect(frame.step({ ...input, deltaMs: 16, pulses: 3 }).pulse).toBe(0);
    expect(frame.step({ ...input, deltaMs: 16, pulses: 4 }).pulse).toBe(1);
    const later = frame.step({ ...input, deltaMs: 200, pulses: 4 }).pulse;
    expect(later).toBeGreaterThan(0);
    expect(later).toBeLessThan(0.2);
  });

  it('never pulses under reduced motion', () => {
    const frame = createFrame('listening');
    const input = { bands: SILENT, phase: 'listening' as const, reducedMotion: true };
    frame.step({ ...input, deltaMs: 16, pulses: 0 });
    expect(frame.step({ ...input, deltaMs: 16, pulses: 1 }).pulse).toBe(0);
  });
});
