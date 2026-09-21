import { describe, expect, it } from 'vitest';

import { levelFromSamples } from '../level';

describe('levelFromSamples', () => {
  it('is 0 for silence (every byte at the 128 midpoint)', () => {
    expect(levelFromSamples(new Uint8Array(256).fill(128))).toBe(0);
  });

  it('is 0 for an empty buffer', () => {
    expect(levelFromSamples(new Uint8Array(0))).toBe(0);
  });

  it('rises with amplitude and is clamped to 1', () => {
    const quiet = levelFromSamples(new Uint8Array([120, 136, 120, 136]));
    const loud = levelFromSamples(new Uint8Array([64, 192, 64, 192]));
    const clipped = levelFromSamples(new Uint8Array([0, 255, 0, 255]));
    expect(quiet).toBeGreaterThan(0);
    expect(loud).toBeGreaterThan(quiet);
    expect(clipped).toBe(1);
  });
});
