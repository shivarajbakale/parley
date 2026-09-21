import { describe, expect, it } from 'vitest';

import { ORB_SIZE, orbBounds, orbWindowOptions, settingsWindowOptions } from '../windows';

describe('orb window', () => {
  it('can never take focus or catch the mouse-driven activation that would steal the paste target', () => {
    const options = orbWindowOptions('/app/preload.mjs');
    expect(options.focusable).toBe(false);
    expect(options.transparent).toBe(true);
    expect(options.frame).toBe(false);
    expect(options.alwaysOnTop).toBe(true);
    expect(options.show).toBe(false);
    expect(options.hasShadow).toBe(false);
    expect(options.skipTaskbar).toBe(true);
  });

  it('locks down the renderer', () => {
    const { webPreferences } = orbWindowOptions('/app/preload.mjs');
    expect(webPreferences).toMatchObject({
      preload: '/app/preload.mjs',
      contextIsolation: true,
      nodeIntegration: false,
    });
  });

  it('sits bottom center of the work area, 48 px above its bottom edge', () => {
    const bounds = orbBounds({ x: 100, y: 25, width: 1000, height: 800 });
    expect(bounds).toEqual({
      x: 100 + (1000 - ORB_SIZE.width) / 2,
      y: 25 + 800 - ORB_SIZE.height - 48,
      ...ORB_SIZE,
    });
  });
});

describe('settings window', () => {
  it('is a small fixed-size window that opens hidden', () => {
    const options = settingsWindowOptions('/app/preload.mjs');
    expect(options).toMatchObject({ width: 560, height: 720, resizable: false, show: false });
    expect(options.webPreferences).toMatchObject({ contextIsolation: true, nodeIntegration: false });
  });
});
