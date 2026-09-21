/**
 * Attack/release envelope follower. Raw voice level jitters every buffer, and
 * anything drawn straight from it bounces. This rises fast, falls slowly, and
 * uses the real time step so it behaves the same at 60 and 120 Hz.
 */
export interface Envelope {
  next(input: number, deltaMs: number): number;
  reset(): void;
}

export function createEnvelope({
  attackMs,
  releaseMs,
}: {
  attackMs: number;
  releaseMs: number;
}): Envelope {
  let value = 0;
  return {
    next(input, deltaMs) {
      if (deltaMs <= 0) return value;
      const timeConstant = input > value ? attackMs : releaseMs;
      value += (input - value) * (1 - Math.exp(-deltaMs / timeConstant));
      return value;
    },
    reset() {
      value = 0;
    },
  };
}
