import { describe, expect, it } from 'vitest';

import { formatSaved, minutesSaved } from '../usage';

describe('time saved', () => {
  it('is typing time minus speaking time', () => {
    // 600 words: 15 min typed, 4 min spoken.
    expect(minutesSaved(600)).toBeCloseTo(11);
  });

  it('is zero for no words or a bad count', () => {
    expect(minutesSaved(0)).toBe(0);
    expect(minutesSaved(-5)).toBe(0);
    expect(minutesSaved(Number.NaN)).toBe(0);
  });

  it('formats minutes and hours', () => {
    expect(formatSaved(0.4)).toBe('Under a minute');
    expect(formatSaved(26.4)).toBe('26 min');
    expect(formatSaved(59.6)).toBe('1 h');
    expect(formatSaved(185)).toBe('3 h 5 min');
  });
});
