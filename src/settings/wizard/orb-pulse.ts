import { createContext, useContext } from 'react';

/**
 * Lets a screen inside the first-run flow kick the ring orb above it — the
 * gesture trainer pulses it on each key press. The flow shell provides it; any
 * other tree gets a no-op.
 */
export const OrbPulseContext = createContext<() => void>(() => {});

export function useOrbPulse() {
  return useContext(OrbPulseContext);
}
