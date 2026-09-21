import { describe, expect, it } from 'vitest';

import { buildPalette, PALETTE_TOKENS, srgbByteToLinear } from '../palette';

describe('srgbByteToLinear', () => {
  it('maps the ends of the range', () => {
    expect(srgbByteToLinear(0)).toBe(0);
    expect(srgbByteToLinear(255)).toBeCloseTo(1, 6);
  });

  it('applies the sRGB curve, not a straight divide', () => {
    expect(srgbByteToLinear(128)).toBeCloseTo(0.2158, 3);
  });
});

describe('buildPalette', () => {
  it('reads each token once and converts it to linear floats', () => {
    const seen: string[] = [];
    const palette = buildPalette((token) => {
      seen.push(token);
      return [255, 0, 128];
    });
    expect(seen).toEqual([...PALETTE_TOKENS.aurora, PALETTE_TOKENS.done, PALETTE_TOKENS.error]);
    expect(palette.aurora).toHaveLength(3);
    expect(palette.done[0]).toBeCloseTo(1, 6);
    expect(palette.done[1]).toBe(0);
    expect(palette.error[2]).toBeCloseTo(0.2158, 3);
  });
});
