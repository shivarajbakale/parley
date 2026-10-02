import { describe, expect, it, vi } from 'vitest';

import {
  explainWindowOptions,
  floatOverEverything,
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

  it('sits bottom center of the work area, 4 px above its bottom edge, with no window to anchor to', () => {
    const bounds = orbBounds({ x: 100, y: 25, width: 1000, height: 800 });
    expect(bounds).toEqual({
      x: 100 + (1000 - ORB_SIZE.width) / 2,
      y: 25 + 800 - ORB_SIZE.height - 4,
      ...ORB_SIZE,
    });
  });

  it('sits bottom center of the focused window, not the whole display, when window bounds are known', () => {
    const workArea = { x: 0, y: 0, width: 2000, height: 1200 };
    const windowBounds = { x: 900, y: 100, width: 600, height: 500 };
    const bounds = orbBounds(workArea, windowBounds);
    expect(bounds).toEqual({
      x: 900 + (600 - ORB_SIZE.width) / 2,
      y: 100 + 500 - ORB_SIZE.height - 4,
      ...ORB_SIZE,
    });
  });

  it('clamps to the work area when the window is too small or sits past its edge', () => {
    const workArea = { x: 0, y: 0, width: 1200, height: 800 };
    const windowBounds = { x: 1100, y: -50, width: 150, height: 80 };
    const bounds = orbBounds(workArea, windowBounds);
    expect(bounds.x).toBeLessThanOrEqual(workArea.width - ORB_SIZE.width);
    expect(bounds.x).toBeGreaterThanOrEqual(0);
    expect(bounds.y).toBeGreaterThanOrEqual(0);
    expect(bounds.y).toBeLessThanOrEqual(workArea.height - ORB_SIZE.height);
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

describe('floatOverEverything', () => {
  const fakeWindow = () => ({ setVisibleOnAllWorkspaces: vi.fn(), setAlwaysOnTop: vi.fn() });

  it('puts a window on every Space, full-screen ones too, above everything', () => {
    const win = fakeWindow();
    floatOverEverything(win, { first: true });
    expect(win.setVisibleOnAllWorkspaces).toHaveBeenCalledWith(true, {
      visibleOnFullScreen: true,
      skipTransformProcessType: false,
    });
    expect(win.setAlwaysOnTop).toHaveBeenCalledWith(true, 'screen-saver');
  });

  it('re-asserts it on each show without touching the dock again', () => {
    const win = fakeWindow();
    floatOverEverything(win);
    expect(win.setVisibleOnAllWorkspaces).toHaveBeenCalledWith(true, {
      visibleOnFullScreen: true,
      skipTransformProcessType: true,
    });
    expect(win.setAlwaysOnTop).toHaveBeenCalledWith(true, 'screen-saver');
  });
});
