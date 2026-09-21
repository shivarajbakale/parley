import { describe, expect, it } from 'vitest';

import { DURATION, EASE, SPRING } from '../motion';

describe('motion presets', () => {
  it('exposes the one spring the whole app uses', () => {
    expect(SPRING).toEqual({ type: 'spring', stiffness: 380, damping: 30 });
  });

  it('exposes three durations in seconds', () => {
    expect(DURATION).toEqual({ fast: 0.15, base: 0.25, slow: 0.4 });
  });

  it('exposes a four-point cubic bezier', () => {
    expect(EASE).toHaveLength(4);
  });
});
