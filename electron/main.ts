import { app, BrowserWindow, Menu, shell } from 'electron';
import { DEFAULT_BOUNDS, windowOptions, type WindowBounds } from './window-options';
import { fileURLToPath } from 'node:url';
import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// The built directory structure
//
// ├─┬─┬ dist
// │ │ └── index.html
// │ │
// │ ├─┬ dist-electron
// │ │ ├── main.js
// │ │ └── preload.mjs
// │
process.env.APP_ROOT = path.join(__dirname, '..');

// 🚧 Use ['ENV_NAME'] avoid vite:define plugin - Vite@2.x
export const VITE_DEV_SERVER_URL = process.env['VITE_DEV_SERVER_URL'];
export const MAIN_DIST = path.join(process.env.APP_ROOT, 'dist-electron');
export const RENDERER_DIST = path.join(process.env.APP_ROOT, 'dist');

process.env.VITE_PUBLIC = VITE_DEV_SERVER_URL
  ? path.join(process.env.APP_ROOT, 'public')
  : RENDERER_DIST;

const boundsFile = () => path.join(app.getPath('userData'), 'window-state.json');

function readBounds(): WindowBounds {
  try {
    const saved = JSON.parse(readFileSync(boundsFile(), 'utf8')) as WindowBounds;
    if (typeof saved.width === 'number' && typeof saved.height === 'number') return saved;
  } catch {
    // First launch, or the file was corrupted — either way, defaults are fine.
  }
  return DEFAULT_BOUNDS;
}

function persistBounds(window: BrowserWindow) {
  if (window.isDestroyed() || window.isMinimized()) return;
  try {
    writeFileSync(boundsFile(), JSON.stringify(window.getBounds()));
  } catch {
    // A window that can't remember its size is a nuisance, not a crash.
  }
}

let win: BrowserWindow | null;

function createWindow() {
  win = new BrowserWindow(
    windowOptions({ bounds: readBounds(), preloadPath: path.join(__dirname, 'preload.mjs') })
  );

  win.once('ready-to-show', () => win?.show());
  win.on('close', () => win && persistBounds(win));
  win.on('closed', () => {
    win = null;
  });

  // External links belong in the user's browser, not in an app window with no
  // address bar to show them where they've landed.
  win.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: 'deny' };
  });

  // Test active push message to Renderer-process.
  win.webContents.on('did-finish-load', () => {
    win?.webContents.send('main-process-message', new Date().toLocaleString());
  });

  if (VITE_DEV_SERVER_URL) {
    win.loadURL(VITE_DEV_SERVER_URL);
  } else {
    win.loadFile(path.join(RENDERER_DIST, 'index.html'));
  }
}

/**
 * Application menu.
 *
 * Without this Electron ships its default menu, which names the app "Electron".
 * The roles give us working Cmd+C/V, Cmd+W, and the macOS services menu for free.
 */
function buildMenu() {
  const isMac = process.platform === 'darwin';

  const template: Electron.MenuItemConstructorOptions[] = [
    ...(isMac
      ? ([{ role: 'appMenu' }] as Electron.MenuItemConstructorOptions[])
      : []),
    { role: 'fileMenu' },
    { role: 'editMenu' },
    { role: 'viewMenu' },
    { role: 'windowMenu' },
  ];

  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

// Quit when all windows are closed, except on macOS. There, it's common
// for applications and their menu bar to stay active until the user quits
// explicitly with Cmd + Q.
app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
    win = null;
  }
});

app.on('activate', () => {
  // On OS X it's common to re-create a window in the app when the
  // dock icon is clicked and there are no other windows open.
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});

app.whenReady().then(() => {
  buildMenu();
  createWindow();
});
