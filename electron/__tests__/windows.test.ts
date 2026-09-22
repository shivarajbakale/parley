import { describe, expect, it } from 'vitest';

import {
  explainWindowOptions,
  ORB_SIZE,
  orbBounds,
  orbWindowOptions,
  settingsWindowOptions,
} from '../windows';
import { BACKGROUND_DARK } from '../window-options';

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

  it('is 260 by 110 px: the pill, its glow and bounce, and a line of error text', () => {
    expect(ORB_SIZE).toEqual({ width: 260, height: 110 });
  });

  it('sits bottom center of the work area, 4 px above its bottom edge', () => {
    const bounds = orbBounds({ x: 100, y: 25, width: 1000, height: 800 });
    expect(bounds).toEqual({
      x: 100 + (1000 - ORB_SIZE.width) / 2,
      y: 25 + 800 - ORB_SIZE.height - 4,
      ...ORB_SIZE,
    });
  });
});

describe('settings window', () => {
  it('is a small fixed-size window that opens hidden', () => {
    const options = settingsWindowOptions('/app/preload.mjs', 'darwin');
    expect(options).toMatchObject({ width: 760, height: 560, resizable: false, show: false });
    expect(options.webPreferences).toMatchObject({ contextIsolation: true, nodeIntegration: false });
  });

  it('uses real macOS blur behind a transparent background', () => {
    const options = settingsWindowOptions('/app/preload.mjs', 'darwin');
    expect(options.vibrancy).toBe('under-window');
    expect(options.visualEffectState).toBe('active');
    expect(options.backgroundColor).toBe('#00000000');
  });

  it('insets the traffic lights into a hidden titlebar on macOS only', () => {
    const mac = settingsWindowOptions('/app/preload.mjs', 'darwin');
    expect(mac.titleBarStyle).toBe('hiddenInset');
    expect(mac.trafficLightPosition).toEqual({ x: 14, y: 12 });
    const win = settingsWindowOptions('/app/preload.mjs', 'win32');
    expect(win.titleBarStyle).toBe('default');
    expect(win.trafficLightPosition).toBeUndefined();
  });

  it('keeps a solid dark background where vibrancy does not exist', () => {
    const options = settingsWindowOptions('/app/preload.mjs', 'win32');
    expect(options.vibrancy).toBeUndefined();
    expect(options.backgroundColor).toBe(BACKGROUND_DARK);
  });
});

describe('explain window', () => {
  it('can never take focus, so the selection it explains stays selected', () => {
    const options = explainWindowOptions('/app/preload.mjs');
    expect(options.focusable).toBe(false);
    expect(options.transparent).toBe(true);
    expect(options.frame).toBe(false);
    expect(options.alwaysOnTop).toBe(true);
    expect(options.show).toBe(false);
  });

  it('is a clickable, scrollable glass panel on macOS', () => {
    const options = explainWindowOptions('/app/preload.mjs', 'darwin');
    expect(options.type).toBe('panel');
    expect(options.acceptFirstMouse).toBe(true);
    expect(options.vibrancy).toBe('hud');
    expect(options.visualEffectState).toBe('active');
    expect(explainWindowOptions('/app/preload.mjs', 'linux').vibrancy).toBeUndefined();
  });

  it('locks down the renderer', () => {
    expect(explainWindowOptions('/app/preload.mjs').webPreferences).toMatchObject({
      preload: '/app/preload.mjs',
      contextIsolation: true,
      nodeIntegration: false,
    });
  });
});
