/**
 * Three voice bands from an `AnalyserNode.getByteFrequencyData` buffer. Low
 * moves the orb's body, mid sets how fast it flows, high adds shimmer.
 */
export interface Bands {
  low: number;
  mid: number;
  high: number;
}

export const SILENT_BANDS: Bands = { low: 0, mid: 0, high: 0 };

const LOW_MAX_HZ = 250;
const MID_MAX_HZ = 2000;
const HIGH_MAX_HZ = 8000;

/** Speech carries less energy the higher you go; these even the bands out. */
const GAIN = { low: 1.4, mid: 1.8, high: 2.6 };

export function bandsFromSpectrum(spectrum: Uint8Array, sampleRate: number): Bands {
  if (spectrum.length === 0) return SILENT_BANDS;
  const hzPerBin = sampleRate / 2 / spectrum.length;
  const sums = { low: 0, mid: 0, high: 0 };
  const counts = { low: 0, mid: 0, high: 0 };

  for (let bin = 0; bin < spectrum.length; bin++) {
    const hz = bin * hzPerBin;
    if (hz >= HIGH_MAX_HZ) break;
    const band = hz < LOW_MAX_HZ ? 'low' : hz < MID_MAX_HZ ? 'mid' : 'high';
    sums[band] += spectrum[bin];
    counts[band]++;
  }

  const scale = (band: keyof Bands) =>
    counts[band] === 0 ? 0 : Math.min(1, (sums[band] / counts[band] / 255) * GAIN[band]);
  return { low: scale('low'), mid: scale('mid'), high: scale('high') };
}
