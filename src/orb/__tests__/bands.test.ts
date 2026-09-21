import { describe, expect, it } from 'vitest';

import { bandsFromSpectrum, SILENT_BANDS } from '../bands';

/** 256 bins at 48 kHz: each bin spans 93.75 Hz. */
const SAMPLE_RATE = 48000;
const BINS = 256;

function spectrumWith(fromHz: number, toHz: number, value: number) {
  const spectrum = new Uint8Array(BINS);
  const hzPerBin = SAMPLE_RATE / 2 / BINS;
  for (let bin = 0; bin < BINS; bin++) {
    const hz = bin * hzPerBin;
    if (hz >= fromHz && hz < toHz) spectrum[bin] = value;
  }
  return spectrum;
}

describe('bandsFromSpectrum', () => {
  it('is silent for an empty or all-zero spectrum', () => {
    expect(bandsFromSpectrum(new Uint8Array(0), SAMPLE_RATE)).toEqual(SILENT_BANDS);
    expect(bandsFromSpectrum(new Uint8Array(BINS), SAMPLE_RATE)).toEqual(SILENT_BANDS);
  });

  it('puts energy below 250 Hz in low only', () => {
    const bands = bandsFromSpectrum(spectrumWith(0, 250, 255), SAMPLE_RATE);
    expect(bands.low).toBeGreaterThan(0.9);
    expect(bands.mid).toBe(0);
    expect(bands.high).toBe(0);
  });

  it('puts energy between 250 Hz and 2 kHz in mid only', () => {
    const bands = bandsFromSpectrum(spectrumWith(250, 2000, 255), SAMPLE_RATE);
    expect(bands.low).toBe(0);
    expect(bands.mid).toBeGreaterThan(0.9);
    expect(bands.high).toBe(0);
  });

  it('puts energy between 2 kHz and 8 kHz in high only, and ignores everything above', () => {
    expect(bandsFromSpectrum(spectrumWith(2000, 8000, 255), SAMPLE_RATE).high).toBeGreaterThan(0.9);
    expect(bandsFromSpectrum(spectrumWith(8000, 24000, 255), SAMPLE_RATE)).toEqual(SILENT_BANDS);
  });

  it('clamps to 1', () => {
    const bands = bandsFromSpectrum(new Uint8Array(BINS).fill(255), SAMPLE_RATE);
    expect(bands).toEqual({ low: 1, mid: 1, high: 1 });
  });
});
