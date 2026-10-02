import { CARD_MIN_HEIGHT, CARD_WIDTH } from './explain-placement';
import { BACKGROUND_DARK, TRAFFIC_LIGHT_POSITION } from './window-options';

/**
 * Options for Parley's two windows, as pure functions — same reason as
 * `window-options.ts`: `main.ts` cannot be imported outside Electron, and
 * `focusable: false` on the orb is the one option that must never regress. A
 * focusable orb steals focus, and the paste lands in the orb instead of the
 * user's text field.
 */

export interface Rect {
  x: number;
  y: number;
  width: number;
  height: number;
}

/** The waveform pill, its glow, and one line of error text above it. */
export const ORB_SIZE = { width: 260, height: 110 };
/** The pill's glow already pads it by 16 px, so the capsule sits about 20 px up. */
const ORB_BOTTOM_MARGIN = 4;

/**
 * Bottom-centred on `windowBounds` when known — the focused window, not just
 * its display, so multiple windows on the same screen still get the orb
 * placed where the user is actually looking. Falls back to `workArea` when no
 * window bounds are known yet (the instant, pre-correction show). Either way
 * the result is clamped inside `workArea`, since a small or partly offscreen
 * window can otherwise push the orb past the display's edge.
 */
export function orbBounds(workArea: Rect, windowBounds: Rect | null = null): Rect {
  const anchor = windowBounds ?? workArea;
  const x = anchor.x + (anchor.width - ORB_SIZE.width) / 2;
  const y = anchor.y + anchor.height - ORB_SIZE.height - ORB_BOTTOM_MARGIN;
  const maxX = workArea.x + workArea.width - ORB_SIZE.width;
  const maxY = workArea.y + workArea.height - ORB_SIZE.height;
  return {
    x: Math.round(Math.min(Math.max(x, workArea.x), maxX)),
    y: Math.round(Math.min(Math.max(y, workArea.y), maxY)),
    ...ORB_SIZE,
  };
}

/** The two calls `floatOverEverything` makes; a `BrowserWindow` has both. */
export interface Floatable {
  setVisibleOnAllWorkspaces(
    visible: boolean,
    options?: { visibleOnFullScreen?: boolean; skipTransformProcessType?: boolean }
  ): void;
  setAlwaysOnTop(flag: boolean, level?: 'screen-saver'): void;
}

/**
 * Puts the orb or the card on every Space, full-screen apps included, above
 * every window. Called at creation and again before every show: a long-running
 * Parley was seen with both windows pinned to one full-screen Space, so they
 * opened where the user could not see them. Re-asserting is cheap.
 * `skipTransformProcessType` after the first call: the dock icon is already
 * hidden, and a transform each show would flicker it.
 */
export function floatOverEverything(win: Floatable, { first = false } = {}) {
  win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true, skipTransformProcessType: !first });
  win.setAlwaysOnTop(true, 'screen-saver');
}

const lockedDown = (preloadPath: string) => ({
  preload: preloadPath,
  contextIsolation: true,
  nodeIntegration: false,
});

export function orbWindowOptions(preloadPath: string) {
  return {
    ...ORB_SIZE,
    show: false,
    frame: false,
    transparent: true,
    hasShadow: false,
    resizable: false,
    movable: false,
    focusable: false,
    alwaysOnTop: true,
    skipTaskbar: true,
    fullscreenable: false,
    webPreferences: {
      ...lockedDown(preloadPath),
      // The orb is hidden most of the time and must still start recording at once.
      backgroundThrottling: false,
    },
  };
}

/** Bounds are set per show, by `placeCard`; the size here is only the first frame. */
export function explainWindowOptions(
  preloadPath: string,
  platform: NodeJS.Platform = process.platform
) {
  const isMac = platform === 'darwin';
  return {
    width: CARD_WIDTH,
    height: CARD_MIN_HEIGHT,
    show: false,
    frame: false,
    transparent: true,
    hasShadow: false,
    resizable: false,
    movable: false,
    // The selection the card explains must stay selected and focused.
    focusable: false,
    // A non-activating panel takes clicks and scrolling without activating
    // Parley; `acceptFirstMouse` stops the first click being spent on focus.
    type: isMac ? ('panel' as const) : undefined,
    acceptFirstMouse: true,
    // Real glass: the desktop blurs through the card. `active` keeps it from
    // greying out, since this window is never the key window.
    vibrancy: isMac ? ('hud' as const) : undefined,
    visualEffectState: isMac ? ('active' as const) : undefined,
    alwaysOnTop: true,
    skipTaskbar: true,
    fullscreenable: false,
    webPreferences: { ...lockedDown(preloadPath), backgroundThrottling: false },
  };
}

export function settingsWindowOptions(
  preloadPath: string,
  platform: NodeJS.Platform = process.platform
) {
  const isMac = platform === 'darwin';
  return {
    width: 760,
    height: 560,
    useContentSize: true,
    resizable: false,
    fullscreenable: false,
    // Shown on `ready-to-show` in main.ts, which also avoids a vibrancy flash.
    show: false,
    title: 'Parley',
    // The first-run scene runs under the titlebar; the renderer declares its
    // own drag strip and clears the lights (`TRAFFIC_LIGHT_INSET`).
    titleBarStyle: (isMac ? 'hiddenInset' : 'default') as 'hiddenInset' | 'default',
    trafficLightPosition: isMac ? TRAFFIC_LIGHT_POSITION : undefined,
    // Glass is real system blur on macOS; elsewhere the window stays solid.
    vibrancy: isMac ? ('under-window' as const) : undefined,
    visualEffectState: isMac ? ('active' as const) : undefined,
    backgroundColor: isMac ? '#00000000' : BACKGROUND_DARK,
    webPreferences: lockedDown(preloadPath),
  };
}
