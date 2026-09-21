import path from 'node:path';

/**
 * Window configuration, as a pure function.
 *
 * Kept out of `main.ts` — which calls `app.on(...)` at module scope and so can
 * only be imported inside a running Electron process — so these options can be
 * asserted in a plain unit test. CI has no display, and a window that silently
 * loses its frameless chrome or points at a missing icon is exactly the kind of
 * regression that otherwise only surfaces when a human opens the app.
 */

/** Must match `--background` in `src/App.css` — this is what paints before React does. */
export const BACKGROUND_DARK = '#111113';

/** Matches `TRAFFIC_LIGHT_INSET` in `src/lib/platform.ts`. Change both together. */
export const TRAFFIC_LIGHT_POSITION = { x: 14, y: 12 };

export interface WindowBounds {
  width: number;
  height: number;
  x?: number;
  y?: number;
}

export const DEFAULT_BOUNDS: WindowBounds = { width: 1280, height: 820 };

export function windowOptions({
  platform = process.platform,
  publicDir = process.env.VITE_PUBLIC ?? '',
  preloadPath = '',
  bounds = DEFAULT_BOUNDS,
}: {
  platform?: NodeJS.Platform;
  publicDir?: string;
  preloadPath?: string;
  bounds?: WindowBounds;
} = {}) {
  const isMac = platform === 'darwin';

  return {
    ...bounds,
    minWidth: 900,
    minHeight: 600,
    // Don't paint until the renderer has something to show, otherwise the app
    // opens on a white rectangle before the dark theme loads.
    show: false,
    backgroundColor: BACKGROUND_DARK,
    icon: path.join(publicDir, 'favicon.svg'),
    // macOS keeps its traffic lights and insets them into our own titlebar
    // (`src/components/titlebar.tsx`); other platforms keep the native frame,
    // which is what users expect there.
    titleBarStyle: (isMac ? 'hiddenInset' : 'default') as 'hiddenInset' | 'default',
    trafficLightPosition: isMac ? TRAFFIC_LIGHT_POSITION : undefined,
    webPreferences: {
      preload: preloadPath,
      contextIsolation: true,
      nodeIntegration: false,
    },
  };
}
