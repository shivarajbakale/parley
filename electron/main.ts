import {
  app,
  BrowserWindow,
  clipboard,
  ipcMain,
  Menu,
  nativeImage,
  safeStorage,
  screen,
  shell,
  Tray,
} from 'electron';
import { execFile } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { promisify } from 'node:util';
import { uIOhook, UiohookKey } from 'uiohook-napi';

import { createAudioWatchdog } from './audio-watchdog';
import { createEditTargets } from './edit-target';
import { createFieldReader } from './field-reader';
import { createGestureDetector } from './gesture-detector';
import { createInjector } from './injector';
import { createKeyHook } from './key-hook';
import { parseOrbAudio } from './orb-audio';
import { getPermissions, requestPermission } from './permissions';
import { createRewriter } from './rewriter';
import { createSession, type Session } from './session';
import { createSettingsStore } from './settings-store';
import { createTranscriber } from './transcriber';
import { trayMenuTemplate } from './tray';
import type { KeyTestResult, PermissionKind, Settings } from './types';
import { orbBounds, orbWindowOptions, settingsWindowOptions } from './windows';

/**
 * How long the session may sit in `awaiting_audio` before the watchdog
 * assumes the `orb:audio` message is never coming (a crashed or reloaded orb
 * renderer) and recovers it with an empty, zero-duration payload.
 */
const AUDIO_WATCHDOG_MS = 5000;

/** Only ever hand `shell.openExternal` a web URL, never a custom scheme. */
function isExternalHttpUrl(url: string): boolean {
  try {
    const parsed = new URL(url);
    return parsed.protocol === 'http:' || parsed.protocol === 'https:';
  } catch {
    return false;
  }
}

const __dirname = path.dirname(fileURLToPath(import.meta.url));

process.env.APP_ROOT = path.join(__dirname, '..');

// 🚧 Use ['ENV_NAME'] avoid vite:define plugin - Vite@2.x
export const VITE_DEV_SERVER_URL = process.env['VITE_DEV_SERVER_URL'];
export const MAIN_DIST = path.join(process.env.APP_ROOT, 'dist-electron');
export const RENDERER_DIST = path.join(process.env.APP_ROOT, 'dist');

process.env.VITE_PUBLIC = VITE_DEV_SERVER_URL
  ? path.join(process.env.APP_ROOT, 'public')
  : RENDERER_DIST;

const PRELOAD = path.join(__dirname, 'preload.mjs');

/** Built by `scripts/build-ax-helper.sh`; electron-builder copies it into Resources. */
const AX_HELPER = app.isPackaged
  ? path.join(process.resourcesPath, 'parley-ax')
  : path.join(process.env.APP_ROOT, 'resources', 'parley-ax');

const execFileAsync = promisify(execFile);

/** Parley's own pages. `index.html` (the scaffold demo) is never loaded — see DECISIONS.md. */
function loadPage(window: BrowserWindow, page: 'orb' | 'settings') {
  if (VITE_DEV_SERVER_URL) window.loadURL(`${VITE_DEV_SERVER_URL}${page}.html`);
  else window.loadFile(path.join(RENDERER_DIST, `${page}.html`));
}

/**
 * A second launch would install a second global key hook and a second tray
 * icon, so one gesture would paste twice. Only the first instance runs; a
 * second one quits immediately.
 */
const gotSingleInstanceLock = app.requestSingleInstanceLock();
if (!gotSingleInstanceLock) {
  app.quit();
}

// With no dock icon, relaunching the app is how a user asks for the settings
// window; the second instance quits, so the first one has to answer.
app.on('second-instance', () => openSettings());

let orbWindow: BrowserWindow | null = null;
let settingsWindow: BrowserWindow | null = null;
let tray: Tray | null = null;
let lastTranscript: string | null = null;
let hookRunning = false;

function createOrbWindow() {
  orbWindow = new BrowserWindow(orbWindowOptions(PRELOAD));
  orbWindow.setIgnoreMouseEvents(true);
  orbWindow.setAlwaysOnTop(true, 'screen-saver');
  orbWindow.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
  loadPage(orbWindow, 'orb');
}

function openSettings() {
  if (settingsWindow) {
    settingsWindow.show();
    settingsWindow.focus();
    return;
  }
  settingsWindow = new BrowserWindow(settingsWindowOptions(PRELOAD));
  settingsWindow.once('ready-to-show', () => settingsWindow?.show());
  settingsWindow.on('closed', () => {
    settingsWindow = null;
  });
  settingsWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (isExternalHttpUrl(url)) shell.openExternal(url);
    return { action: 'deny' };
  });
  loadPage(settingsWindow, 'settings');
}

if (gotSingleInstanceLock) {
  startApp().catch((error) => {
    console.error('Parley failed to start', error);
    app.quit();
  });
}

/** Wraps startup so a failure is logged and the app quits instead of hanging half-initialized. */
async function startApp() {
  await app.whenReady();
  app.dock?.hide();
  // Cmd+C / Cmd+V in the settings window need an Edit menu, dock icon or not.
  Menu.setApplicationMenu(Menu.buildFromTemplate([{ role: 'appMenu' }, { role: 'editMenu' }]));

  const store = createSettingsStore({ dir: app.getPath('userData'), crypto: safeStorage });
  const transcriber = createTranscriber({ getApiKey: () => store.getApiKey() });

  const injector = createInjector({
    snapshot: () => ({
      text: clipboard.readText(),
      html: clipboard.readHTML(),
      rtf: clipboard.readRTF(),
      image: clipboard.readImage(),
    }),
    restore: (saved) => {
      clipboard.clear();
      clipboard.write({
        ...(saved.text ? { text: saved.text } : {}),
        ...(saved.html ? { html: saved.html } : {}),
        ...(saved.rtf ? { rtf: saved.rtf } : {}),
        ...(saved.image.isEmpty() ? {} : { image: saved.image }),
      });
    },
    writeText: (text) => clipboard.writeText(text),
    readText: () => clipboard.readText(),
    sendPaste: () => uIOhook.keyTap(UiohookKey.V, [UiohookKey.Meta]),
    sendCopy: () => uIOhook.keyTap(UiohookKey.C, [UiohookKey.Meta]),
    sendSelectAll: () => uIOhook.keyTap(UiohookKey.A, [UiohookKey.Meta]),
  });

  const rewriter = createRewriter({ getApiKey: () => store.getRewriteKey() });
  const editTargets = createEditTargets({
    reader: createFieldReader({
      helperPath: AX_HELPER,
      run: async (file, options) => (await execFileAsync(file, [], options)).stdout,
    }),
    injector,
  });

  const isReady = () => {
    const permissions = getPermissions();
    return permissions.microphone && permissions.accessibility && store.hasApiKey();
  };

  function refreshTray() {
    const template = trayMenuTemplate(
      { ready: isReady(), lastTranscript },
      {
        copyLast: () => lastTranscript && clipboard.writeText(lastTranscript),
        openSettings,
        quit: () => app.quit(),
      }
    );
    tray?.setContextMenu(Menu.buildFromTemplate(template));
  }

  createOrbWindow();

  /**
   * A dropped `orb:audio` message otherwise wedges the session in
   * `awaiting_audio` forever: the orb stays visible and every later
   * `start()` returns early. `session.receiveAudio` treats a zero-duration
   * payload the same as a too-short recording — the cancelled path, nothing
   * pasted, clipboard untouched — so it is a safe recovery from any of this
   * function's callers. `session` is assigned just below; every caller of
   * this function only runs after that assignment.
   */
  // Declared before its initializer (below) so `recoverStuckSession` and the
  // watchdog it feeds can close over it ahead of `createSession` — both are
  // only ever called after the assignment on the next few lines runs.
  // eslint-disable-next-line prefer-const
  let session: Session;
  function recoverStuckSession() {
    audioWatchdog.clear();
    void session.receiveAudio({ data: new ArrayBuffer(0), mimeType: 'audio/webm', durationMs: 0 });
  }
  const audioWatchdog = createAudioWatchdog({
    timeoutMs: AUDIO_WATCHDOG_MS,
    onTimeout: recoverStuckSession,
  });

  session = createSession({
    orb: {
      show: () => {
        const display = screen.getDisplayNearestPoint(screen.getCursorScreenPoint());
        orbWindow?.setBounds(orbBounds(display.workArea));
        // `showInactive`, never `show`: the user's text field must keep focus.
        orbWindow?.showInactive();
      },
      hide: () => orbWindow?.hide(),
      setPhase: (payload) => {
        orbWindow?.webContents.send('orb:phase', payload);
        // `transcribing` is the phase set on entering `awaiting_audio`
        // (`session.stop()`); every other phase means the wait is over.
        if (payload.phase === 'transcribing') audioWatchdog.arm();
        else audioWatchdog.clear();
      },
    },
    transcriber,
    injector,
    rewriter,
    editTargets,
    getSettings: () => store.get(),
    hasApiKey: () => store.hasApiKey(),
    hasRewriteKey: () => store.hasRewriteKey(),
    getPermissions,
    openSettings,
    onTranscript: (text) => {
      lastTranscript = text;
      refreshTray();
    },
  });

  // A crashed or reloaded orb renderer can never send the audio it was
  // asked for. Recover the wedged session and reload the orb so later
  // gestures still work.
  orbWindow?.webContents.on('render-process-gone', () => {
    recoverStuckSession();
    if (orbWindow) loadPage(orbWindow, 'orb');
  });

  const detector = createGestureDetector({
    key: store.get().gestureKey,
    tapCount: store.get().tapCount,
    onStart: () => session.start(),
    onStop: () => session.stop(),
    onCancel: () => session.cancel(),
  });
  // Voice edit is the same gesture on a second key. Each detector resets on
  // any key but its own, and the session's busy guard covers the rest.
  const editDetector = createGestureDetector({
    key: store.get().editGestureKey,
    tapCount: store.get().tapCount,
    onStart: () => session.start('edit'),
    onStop: () => session.stop(),
    onCancel: () => session.cancel(),
  });
  let editEnabled = false;
  const keyHook = createKeyHook(
    uIOhook,
    UiohookKey as unknown as Record<string, number>,
    (event) => {
      detector.handle(event);
      if (editEnabled) editDetector.handle(event);
    }
  );

  /** The hook sees nothing until Accessibility is granted, so start it only then. */
  function startHookWhenTrusted() {
    if (hookRunning || !getPermissions().accessibility) return;
    keyHook.start();
    hookRunning = true;
    refreshTray();
  }
  startHookWhenTrusted();
  const trustPoll = setInterval(() => {
    startHookWhenTrusted();
    if (hookRunning) clearInterval(trustPoll);
  }, 2000);

  function applySettings(settings: Settings) {
    detector.configure({ key: settings.gestureKey, tapCount: settings.tapCount });
    editDetector.configure({ key: settings.editGestureKey, tapCount: settings.tapCount });
    // One key cannot mean both, and dictation is the one that keeps it.
    editEnabled = settings.editGestureKey !== settings.gestureKey;
    // Only the packaged app: in dev this would register the bare Electron
    // binary from node_modules as a login item.
    if (app.isPackaged) app.setLoginItemSettings({ openAtLogin: settings.launchAtLogin });
  }
  applySettings(store.get());

  ipcMain.on('orb:audio', (event, raw: unknown) => {
    // A message from anyone but the orb is silently ignored, not recovered:
    // it never armed the watchdog, so there is nothing to unstick.
    if (event.sender !== orbWindow?.webContents) return;
    const audio = parseOrbAudio(raw);
    if (!audio) {
      // Never the payload itself — it is audio of whatever the user said.
      console.warn('orb:audio rejected', 'malformed, oversized or negative-duration payload');
      recoverStuckSession();
      return;
    }
    audioWatchdog.clear();
    void session.receiveAudio(audio);
  });

  /**
   * Settings and permissions are the settings window's alone. The preload
   * bridge is loaded into the orb too, so without this check a compromised orb
   * renderer could read the settings or trigger a permission prompt.
   */
  function onlySettingsWindow(event: Electron.IpcMainInvokeEvent) {
    if (event.sender !== settingsWindow?.webContents) {
      throw new Error('Refused: this channel is the settings window only');
    }
  }

  ipcMain.handle('settings:get', (event) => {
    onlySettingsWindow(event);
    return store.view();
  });
  ipcMain.handle('settings:update', (event, patch: Partial<Settings>) => {
    onlySettingsWindow(event);
    applySettings(store.update(typeof patch === 'object' && patch ? patch : {}));
    return store.view();
  });
  ipcMain.handle('settings:setApiKey', async (event, key: unknown): Promise<KeyTestResult> => {
    onlySettingsWindow(event);
    if (typeof key !== 'string' || key.trim() === '') return { ok: false, message: 'Enter a key' };
    const result = await transcriber.testKey(key.trim());
    if (result.ok) {
      store.setApiKey(key.trim());
      refreshTray();
    }
    return result;
  });
  ipcMain.handle('settings:setRewriteKey', async (event, key: unknown): Promise<KeyTestResult> => {
    onlySettingsWindow(event);
    if (typeof key !== 'string' || key.trim() === '') return { ok: false, message: 'Enter a key' };
    const result = await rewriter.testKey(key.trim());
    if (result.ok) store.setRewriteKey(key.trim());
    return result;
  });
  ipcMain.handle('permissions:get', (event) => {
    onlySettingsWindow(event);
    return getPermissions();
  });
  ipcMain.handle('permissions:request', async (event, kind: PermissionKind) => {
    onlySettingsWindow(event);
    if (kind !== 'microphone' && kind !== 'accessibility') return getPermissions();
    const status = await requestPermission(kind);
    startHookWhenTrusted();
    refreshTray();
    return status;
  });

  tray = new Tray(nativeImage.createEmpty());
  tray.setTitle('◉');
  tray.setToolTip('Parley');
  refreshTray();

  // Onboarding: without Accessibility the hook is blind, so a gesture can never open this.
  if (!isReady()) openSettings();

  app.on('will-quit', () => {
    clearInterval(trustPoll);
    if (hookRunning) keyHook.stop();
  });
}

// A menu bar app outlives its windows.
app.on('window-all-closed', () => {});
