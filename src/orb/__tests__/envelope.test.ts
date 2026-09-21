import { describe, expect, it } from 'vitest';

import { createEnvelope } from '../envelope';

const make = () => createEnvelope({ attackMs: 40, releaseMs: 350 });

describe('createEnvelope', () => {
  it('starts at zero', () => {
    expect(make().next(0, 16)).toBe(0);
  });

  it('reaches about 63 percent of a step input after one attack time', () => {
    expect(make().next(1, 40)).toBeCloseTo(1 - Math.exp(-1), 5);
  });

  it('falls much more slowly than it rises', () => {
    const envelope = make();
    envelope.next(1, 1000);
    const afterRelease = envelope.next(0, 40);
    expect(afterRelease).toBeGreaterThan(0.85);
  });

  it('is frame-rate independent', () => {
    const oneStep = make().next(1, 32);
    const twoSteps = make();
    twoSteps.next(1, 16);
    expect(twoSteps.next(1, 16)).toBeCloseTo(oneStep, 10);
  });

  it('ignores a zero or negative time step', () => {
    const envelope = make();
    envelope.next(1, 40);
    const before = envelope.next(1, 0);
    expect(envelope.next(0, -5)).toBe(before);
  });

  it('resets to zero', () => {
    const envelope = make();
    envelope.next(1, 500);
    envelope.reset();
    expect(envelope.next(0, 16)).toBe(0);
  });
});
