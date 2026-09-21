import { describe, expect, it } from 'vitest';

import { BACKGROUND_DARK, DEFAULT_BOUNDS, windowOptions } from '../window-options';

/**
 * The window is the first thing a user sees, and none of it is exercised by the
 * renderer tests. These assertions are cheap insurance against the two failures
 * that are invisible in CI: losing the frameless chrome, and pointing `icon` at
 * a file that isn't shipped.
 */
describe('windowOptions', () => {
  it('insets the traffic lights into our own titlebar on macOS', () => {
    const options = windowOptions({ platform: 'darwin' });

    expect(options.titleBarStyle).toBe('hiddenInset');
    expect(options.trafficLightPosition).toEqual({ x: 14, y: 12 });
  });

  it('keeps the native frame everywhere else', () => {
    for (const platform of ['win32', 'linux'] as const) {
      const options = windowOptions({ platform });
      expect(options.titleBarStyle).toBe('default');
      expect(options.trafficLightPosition).toBeUndefined();
    }
  });

  it('points the icon at a file the app actually ships', () => {
    // `public/favicon.svg` is copied into the renderer output; the template
    // previously referenced `electron-vite.svg`, which does not exist.
    expect(windowOptions({ publicDir: '/app/public' }).icon).toBe('/app/public/favicon.svg');
  });

  it('opens hidden on the themed background so there is no white flash', () => {
    const options = windowOptions();
    expect(options.show).toBe(false);
    expect(options.backgroundColor).toBe(BACKGROUND_DARK);
  });

  it('locks down the renderer', () => {
    const { webPreferences } = windowOptions({ preloadPath: '/app/preload.mjs' });
    expect(webPreferences.contextIsolation).toBe(true);
    expect(webPreferences.nodeIntegration).toBe(false);
    expect(webPreferences.preload).toBe('/app/preload.mjs');
  });

  it('restores saved bounds and enforces a usable minimum', () => {
    const restored = windowOptions({ bounds: { width: 1000, height: 700, x: 20, y: 40 } });
    expect(restored).toMatchObject({ width: 1000, height: 700, x: 20, y: 40 });

    const fresh = windowOptions();
    expect(fresh.width).toBe(DEFAULT_BOUNDS.width);
    expect(fresh.minWidth).toBeLessThanOrEqual(fresh.width);
    expect(fresh.minHeight).toBeLessThanOrEqual(fresh.height);
  });
});
