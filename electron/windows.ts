import { BACKGROUND_DARK } from './window-options';

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

export const ORB_SIZE = { width: 260, height: 260 };
const ORB_BOTTOM_MARGIN = 48;

export function orbBounds(workArea: Rect): Rect {
  return {
    x: Math.round(workArea.x + (workArea.width - ORB_SIZE.width) / 2),
    y: Math.round(workArea.y + workArea.height - ORB_SIZE.height - ORB_BOTTOM_MARGIN),
    ...ORB_SIZE,
  };
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

export function settingsWindowOptions(preloadPath: string) {
  return {
    width: 760,
    height: 560,
    useContentSize: true,
    resizable: false,
    fullscreenable: false,
    show: false,
    title: 'Parley',
    backgroundColor: BACKGROUND_DARK,
    webPreferences: lockedDown(preloadPath),
  };
}
