/**
 * Host detection for the renderer.
 *
 * The same components run in a browser during `vite dev` and inside Electron in
 * the packaged app, so anything that depends on native window chrome has to ask
 * rather than assume.
 */

/** True when the preload bridge is present — i.e. we're inside Electron. */
export const isElectron = typeof window !== 'undefined' && 'ipcRenderer' in window;

/** True on macOS, where the traffic lights need horizontal room in the titlebar. */
export const isMac =
  typeof navigator !== 'undefined' && /Mac|iPhone|iPad|iPod/.test(navigator.platform);

/**
 * Width to reserve at the left of the titlebar for the macOS traffic lights.
 * Mirrors `trafficLightPosition` in `electron/main.ts` — change both together.
 */
export const TRAFFIC_LIGHT_INSET = isMac && isElectron ? 78 : 0;
