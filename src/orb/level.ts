/** Speech RMS is small; this gain maps a normal speaking voice to roughly 0.5. */
const GAIN = 4;

/**
 * Voice level from an `AnalyserNode.getByteTimeDomainData` buffer: RMS around
 * the 128 midpoint, scaled and clamped to 0..1.
 */
export function levelFromSamples(samples: Uint8Array): number {
  if (samples.length === 0) return 0;
  let sum = 0;
  for (const sample of samples) {
    const centered = (sample - 128) / 128;
    sum += centered * centered;
  }
  return Math.min(1, Math.sqrt(sum / samples.length) * GAIN);
}
