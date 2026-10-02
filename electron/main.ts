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
import { execFile, spawn as spawnProcess } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { promisify } from 'node:util';
import { uIOhook, UiohookKey } from 'uiohook-napi';

import { createActionConfirm } from './agent/confirm';
import { createAgentClient } from './agent/client';
import { buildAgentEnv } from './agent/env';
import { createSupervisor } from './agent/supervisor';
import { createAudioWatchdog } from './audio-watchdog';
import { createCommonWords } from './common-words';
import { detectCorrection } from './correction-detect';
import { createCorrectionWatcher } from './correction-watcher';
import { applyReplacements, splitVocabulary, vocabularyTerms, whisperPrompt } from './dictionary';
import { createDictionaryStore } from './dictionary-store';
import { createEditTargets } from './edit-target';
import { createExplain, EXPLAIN_LEAVE_MS } from './explain';
import { CARD_MIN_HEIGHT, CARD_WIDTH, maxCardHeight, placeCard } from './explain-placement';
import { createFieldReader, createWindowLocator } from './field-reader';
import { createGestureDetector } from './gesture-detector';
import { createInjector } from './injector';
import { createKeyHook } from './key-hook';
import { parseOrbAudio } from './orb-audio';
import { getPermissions, requestPermission } from './permissions';
import { createRewriter } from './rewriter';
import { createSelectionReader } from './selection-reader';
import { createSession, ERROR_MS, type Session } from './session';
import { createSettingsStore } from './settings-store';
import { createSyncClient } from './sync/client';
import { createSyncEngine } from './sync/engine';
import { createTranscriber } from './transcriber';
import { trayMenuTemplate } from './tray';
import { createWebSearch } from './web-search';
import { createWordOffer } from './word-offer';
import type {
  AgentSummary,
  AgentTestResult,
  ExplainContent,
  KeyTestResult,
  OrbPhasePayload,
  PermissionKind,
  Rect,
  SessionBlockedReason,
  SessionMode,
  Settings,
  SyncOutcome,
  SyncSignInResult,
  TranscriptionProvider,
} from './types';
import { NOTICE_MS, TRANSCRIPTION_PROVIDERS } from './types';
import { explainWindowOptions, orbBounds, orbWindowOptions, settingsWindowOptions } from './windows';

/**
 * How long the session may sit in `awaiting_audio` before the watchdog
 * assumes the `orb:audio` message is never coming (a crashed or reloaded orb
 * renderer) and recovers it with an empty, zero-duration payload.
 */
const AUDIO_WATCHDOG_MS = 5000;

/** Agent answers longer than this go to the clipboard; the pill only says so. */
const RESULT_CHARS = 120;
/** Quitting mid-run waits this long for the run's DELETE before giving up. */
const QUIT_GRACE_MS = 500;

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

/**
 * The Mastra agent Parley hands commands to. In dev it is the in-repo
 * project, run with its own `mastra` CLI; packaged it is the bundle laid
 * down by `scripts/build-agent.sh`, run by the app binary itself with
 * ELECTRON_RUN_AS_NODE — a shipped Electron app has no `node` otherwise.
 */
const AGENT_DEV_DIR = path.join(process.env.APP_ROOT, 'parley-agent');
const AGENT_MASTRA_BIN = path.join(AGENT_DEV_DIR, 'node_modules', '.bin', 'mastra');
const AGENT_BUNDLE_DIR = app.isPackaged
  ? path.join(process.resourcesPath, 'parley-agent')
  : path.join(process.env.APP_ROOT, 'resources', 'parley-agent');
/** The build script's side of the contract: the bundled server's entry. */
const AGENT_ENTRY = 'index.mjs';

const execFileAsync = promisify(execFile);

/** Parley's own pages. `index.html` (the scaffold demo) is never loaded — see DECISIONS.md. */
function loadPage(window: BrowserWindow, page: 'orb' | 'settings' | 'explain') {
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
let explainWindow: BrowserWindow | null = null;
/** A refusal the settings window was not loaded to hear; see `takeBlockedReason`. */
let pendingBlocked: SessionBlockedReason | null = null;
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

function createExplainWindow() {
  explainWindow = new BrowserWindow(explainWindowOptions(PRELOAD));
  explainWindow.setAlwaysOnTop(true, 'screen-saver');
  explainWindow.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
  loadPage(explainWindow, 'explain');
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
  const dictionary = createDictionaryStore({ dir: app.getPath('userData') });
  const transcriber = createTranscriber({
    getApiKey: (provider) => store.getTranscriptionKey(provider),
    getProvider: () => store.get().transcriptionProvider,
  });

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

  const rewriter = createRewriter({
    getApiKey: () => store.getRewriteKey(),
    webSearch: createWebSearch(),
  });
  const editTargets = createEditTargets({
    reader: createFieldReader({
      helperPath: AX_HELPER,
      run: async (file, options) => (await execFileAsync(file, [], options)).stdout,
    }),
    injector,
  });

  const selectionReader = createSelectionReader({
    reader: createFieldReader({
      helperPath: AX_HELPER,
      run: async (file, options) => (await execFileAsync(file, [], options)).stdout,
    }),
    injector,
  });

  /** Where the card is now, so a later height report can re-place it in the same spot. */
  let explainAnchor: Rect | null = null;
  let explainHeight = CARD_MIN_HEIGHT;
  let explainMaxHeight = maxCardHeight(screen.getPrimaryDisplay().workArea);

  function explainDisplay() {
    const point = explainAnchor
      ? { x: explainAnchor.x, y: explainAnchor.y }
      : screen.getCursorScreenPoint();
    return screen.getDisplayNearestPoint(point);
  }

  function placeExplain() {
    explainWindow?.setBounds(
      placeCard({
        anchor: explainAnchor,
        cursor: screen.getCursorScreenPoint(),
        workArea: explainDisplay().workArea,
        size: { width: CARD_WIDTH, height: explainHeight },
      })
    );
  }

  let lastExplain: ExplainContent = { status: 'empty' };
  let explainHideTimer: ReturnType<typeof setTimeout> | undefined;
  let explainLeaving = false;

  function pushExplain(content: ExplainContent, extra: { opening?: boolean; closing?: boolean } = {}) {
    lastExplain = content;
    explainWindow?.webContents.send('explain:state', {
      ...content,
      maxHeight: explainMaxHeight,
      ...extra,
    });
  }

  const explain = createExplain({
    selection: selectionReader,
    rewriter,
    view: {
      show: (anchor, content) => {
        clearTimeout(explainHideTimer);
        explainLeaving = false;
        explainAnchor = anchor;
        explainHeight = CARD_MIN_HEIGHT;
        explainMaxHeight = maxCardHeight(explainDisplay().workArea);
        placeExplain();
        pushExplain(content, { opening: true });
        // `showInactive`, never `show`: the selection must keep focus.
        explainWindow?.showInactive();
      },
      update: (content) => pushExplain(content),
      // Let the card melt away before the window goes.
      hide: () => {
        if (!explainWindow?.isVisible() || explainLeaving) return;
        explainLeaving = true;
        pushExplain(lastExplain, { closing: true });
        explainHideTimer = setTimeout(() => {
          explainLeaving = false;
          explainWindow?.hide();
        }, EXPLAIN_LEAVE_MS);
      },
    },
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
  createExplainWindow();

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

  // A dedicated, un-shared run of the helper: this must never wait behind a
  // correction-watcher read, and it only ever needs `frontWindowBounds`.
  const windowLocator = createWindowLocator({
    helperPath: AX_HELPER,
    run: async (file, args, options) => (await execFileAsync(file, args, options)).stdout,
    onError: (error) =>
      console.warn('[orb] window read failed:', (error as { code?: unknown }).code ?? error),
  });
  // The first run of a freshly installed helper is slow enough to time out
  // the first orb's read; pay it once at launch, not on the first dictation.
  void windowLocator.warmUp();

  const orb = {
    show: () => {
      // Shown at once, at the cursor's display, so there is no lag: most of
      // the time this is already right. If the user is on another display
      // entirely — hands on the keyboard, mouse resting elsewhere — the
      // Accessibility read a moment later corrects it to the real window.
      const cursorDisplay = screen.getDisplayNearestPoint(screen.getCursorScreenPoint());
      orbWindow?.setBounds(orbBounds(cursorDisplay.workArea));
      // `showInactive`, never `show`: the user's text field must keep focus.
      orbWindow?.showInactive();
      const shownFor = orbWindow;
      void windowLocator.frontWindowBounds().then((bounds) => {
        if (!shownFor || orbWindow !== shownFor || !shownFor.isVisible()) return;
        if (!bounds) {
          // Untrusted, timed out, or an app that never reports a focused
          // window — the orb is left at the cursor's display; not fatal, but
          // worth a trace since it means the fallback fired.
          console.warn('[orb] frontWindowBounds unavailable, orb stays at cursor display');
          return;
        }
        // Always reposition onto the actual window, even when it shares the
        // cursor's display: orbBounds(workArea) alone only ever bottom-centers
        // on the whole screen, never on the window the user is looking at.
        const windowDisplay = screen.getDisplayMatching(bounds);
        shownFor.setBounds(orbBounds(windowDisplay.workArea, bounds));
      });
    },
    hide: () => orbWindow?.hide(),
    setPhase: (payload: OrbPhasePayload) => {
      orbWindow?.webContents.send('orb:phase', payload);
      // `transcribing` is the phase set on entering `awaiting_audio`
      // (`session.stop()`); every other phase means the wait is over.
      if (payload.phase === 'transcribing') audioWatchdog.arm();
      else audioWatchdog.clear();
    },
  };

  // Learning from corrections: after a dictation, watch the field for a fixed
  // word, offer to remember it, and take one tap of the dictation key as yes.
  const fieldReader = createFieldReader({
    helperPath: AX_HELPER,
    run: async (file, options) => (await execFileAsync(file, [], options)).stdout,
  });
  const isCommonWord = createCommonWords();
  const wordOffer = createWordOffer({
    orb,
    isIdle: () => session.state() === 'idle',
    key: () => store.get().gestureKey,
    onAccept: ({ heard, word }) => {
      const saved = dictionary.upsert({ word, soundsLike: [heard] });
      // A taught word is a dictionary change the other devices should see soon.
      if (saved) scheduleSyncSoon();
      return saved;
    },
    onDecline: ({ word }) => dictionary.decline(word),
  });
  const correctionWatcher = createCorrectionWatcher({
    reader: fieldReader,
    detect: (pasted, value) => detectCorrection(pasted, value, { isCommonWord }),
    onCorrection: (correction) => {
      if (!dictionary.isIgnored(correction.word)) wordOffer.offer(correction);
    },
  });
  // The Mastra agent behind act mode: Parley starts its server on launch,
  // hands it transcribed commands, and paints what comes back on the pill.
  function isLocalhostUrl(url: string): boolean {
    try {
      const host = new URL(url).hostname;
      return host === 'localhost' || host === '127.0.0.1' || host === '::1' || host === '[::1]';
    } catch {
      return false;
    }
  }

  function agentPort(): number {
    try {
      return Number(new URL(store.get().agentUrl).port) || 4111;
    } catch {
      return 4111;
    }
  }

  let agentClient = createAgentClient({ baseUrl: store.get().agentUrl });

  const supervisor = createSupervisor({
    getConfig: () => {
      const port = agentPort();
      const env = buildAgentEnv({
        processEnv: process.env,
        port,
        rewriteKey: store.getRewriteKey(),
        packaged: app.isPackaged,
        execPath: process.execPath,
      });
      return {
        autoStart: store.get().agentAutoStart,
        managed: isLocalhostUrl(store.get().agentUrl),
        spawn: app.isPackaged
          ? {
              command: process.execPath,
              args: [path.join(AGENT_BUNDLE_DIR, AGENT_ENTRY)],
              cwd: AGENT_BUNDLE_DIR,
              env,
              description: 'the bundled agent server',
            }
          : {
              // The checkout's own CLI by absolute path: main's PATH comes
              // from wherever Parley was launched, not from that project.
              command: AGENT_MASTRA_BIN,
              args: ['dev'],
              cwd: AGENT_DEV_DIR,
              env,
              description: `mastra dev (${AGENT_DEV_DIR})`,
            },
        port,
      };
    },
    spawn: (command, args, opts) => {
      // argv, never a shell string: the command and cwd are constants above.
      // The cast is the augmented ProcessEnv (APP_ROOT, VITE_PUBLIC): the
      // supervisor only promises string values, which is all spawn needs.
      const child = spawnProcess(command, args, {
        cwd: opts.cwd,
        env: opts.env as NodeJS.ProcessEnv,
        shell: false,
        windowsHide: true,
      });
      return {
        on: (event, listener) => void child.on(event, listener),
        kill: (signal?: string) => void child.kill(signal as NodeJS.Signals),
        get exitCode() {
          return child.exitCode;
        },
        stdout: child.stdout,
        stderr: child.stderr,
      };
    },
    checkHealth: () => agentClient.checkHealth(),
    onLog: (line) => console.log(`[agent] ${line}`),
  });
  supervisor.start();

  let liveRun: { runId: string; abort: AbortController; lastStep: string } | null = null;
  let awaitingApproval = false;
  let approvalSummary: string | null = null;
  let approvalCallId: string | null = null;
  /** Every run and every cancel moves this on; a stale handoff lands nowhere. */
  let runToken = 0;
  let resultHideTimer: ReturnType<typeof setTimeout> | undefined;
  let resultToken = 0;

  function paintWorking(text: string) {
    if (liveRun) liveRun.lastStep = text;
    orb.setPhase({ phase: 'notice', message: text });
  }

  function hideResultSoon(visibleMs: number) {
    const mine = ++resultToken;
    if (resultHideTimer) clearTimeout(resultHideTimer);
    resultHideTimer = setTimeout(() => {
      if (mine === resultToken) orb.hide();
    }, visibleMs);
  }

  function showResult(text: string) {
    if (text.length <= RESULT_CHARS) {
      orb.setPhase({ phase: 'notice', message: text });
    } else {
      clipboard.writeText(text);
      orb.setPhase({ phase: 'notice', message: 'Copied — paste anywhere' });
    }
    hideResultSoon(NOTICE_MS);
  }

  function showRunError(message: string) {
    orb.setPhase({ phase: 'error', message: `Agent failed · ${message}` });
    hideResultSoon(ERROR_MS);
  }

  const actionConfirm = createActionConfirm({
    orb,
    key: () => store.get().actGestureKey,
    speak: (text) => {
      if (process.platform !== 'darwin' || !store.get().tickSound) return;
      execFile('say', [text], () => {});
    },
    // The call was already matched before this runs; the POST needs the run.
    approve: (_callId) =>
      liveRun ? agentClient.approve(liveRun.runId, true) : Promise.resolve(),
    decline: (_callId) =>
      liveRun ? agentClient.approve(liveRun.runId, false) : Promise.resolve(),
    resume: () => {
      awaitingApproval = false;
      approvalSummary = null;
      approvalCallId = null;
      if (liveRun) paintWorking(liveRun.lastStep);
    },
    onDecisionFailed: (error) => {
      runToken += 1;
      const run = liveRun;
      liveRun = null;
      awaitingApproval = false;
      approvalSummary = null;
      approvalCallId = null;
      if (run) {
        run.abort.abort();
        void agentClient.cancelRun(run.runId);
      }
      showRunError(error instanceof Error ? error.message : 'Something went wrong');
    },
  });

  /** The session's half of act mode: run the command, settle the pill, never throw. */
  async function runAgent(transcript: string): Promise<void> {
    const mine = ++runToken;
    resultToken += 1;
    if (resultHideTimer) clearTimeout(resultHideTimer);
    let runId: string | null = null;
    try {
      runId = (await agentClient.startRun(transcript)).runId;
      if (mine !== runToken) {
        void agentClient.cancelRun(runId);
        return;
      }
      const abort = new AbortController();
      liveRun = { runId, abort, lastStep: 'Working…' };
      paintWorking(liveRun.lastStep);
      const outcome = await agentClient.streamEvents(
        runId,
        (event) => {
          if (!liveRun) return;
          if (event.kind === 'step') {
            // Steps stop while a tool is suspended, but a trailing one must
            // never paint over the question.
            if (!awaitingApproval) paintWorking(event.text);
          } else if (event.kind === 'approval_requested') {
            awaitingApproval = true;
            approvalSummary = event.summary;
            approvalCallId = event.callId;
            actionConfirm.ask({
              callId: event.callId,
              summary: event.summary,
              transcript: event.transcript,
            });
          }
        },
        { signal: abort.signal }
      );
      if (mine !== runToken) return;
      liveRun = null;
      awaitingApproval = false;
      approvalSummary = null;
      approvalCallId = null;
      // A question still on screen belongs to this run: drop it before the
      // result paints, or a later tap would approve a settled run.
      actionConfirm.cancel();
      if (outcome.kind === 'completed') showResult(outcome.text);
      else if (outcome.kind === 'failed') showRunError(outcome.message);
      else orb.hide();
    } catch (error) {
      if (runId) void agentClient.cancelRun(runId);
      if (mine !== runToken) return;
      liveRun = null;
      awaitingApproval = false;
      approvalSummary = null;
      approvalCallId = null;
      actionConfirm.cancel();
      showRunError(error instanceof Error ? error.message : 'Something went wrong');
    }
  }

  function cancelAgent(): void {
    runToken += 1;
    const run = liveRun;
    liveRun = null;
    awaitingApproval = false;
    approvalSummary = null;
    approvalCallId = null;
    actionConfirm.cancel();
    resultToken += 1;
    if (resultHideTimer) clearTimeout(resultHideTimer);
    if (run) {
      run.abort.abort();
      void agentClient.cancelRun(run.runId);
    }
    orb.hide();
  }

  function currentRunSummary(): AgentSummary['currentRun'] {
    if (!liveRun) return null;
    return {
      status: awaitingApproval ? 'awaiting_approval' : 'working',
      summary: awaitingApproval && approvalSummary ? approvalSummary : liveRun.lastStep,
      callId: awaitingApproval ? approvalCallId : null,
    };
  }

  async function liveView() {
    const live = await supervisor.refresh();
    return store.view({ ...live, currentRun: currentRunSummary() });
  }

  /** A new gesture owns the pill and the field; anything still learning lets go. */
  function startSession(mode: SessionMode) {
    correctionWatcher.cancel();
    wordOffer.cancel();
    // A run in flight ends here: cancelling first returns the session to idle
    // synchronously, so the start below is never swallowed by the busy guard.
    // (In a dictation the cancel is a no-op and the guard still holds.)
    if (session.state() === 'transcribing') session.cancel();
    if (mode === 'act') {
      void supervisor.refresh();
      // Warmup is a pill, not a settings trip: the server is seconds away,
      // and the Agent tab would strand the user after it lands.
      if (supervisor.status().state === 'starting') {
        orb.show();
        orb.setPhase({ phase: 'notice', message: 'Agent starting — a few seconds' });
        hideResultSoon(NOTICE_MS);
        return;
      }
    }
    session.start(mode);
  }

  session = createSession({
    orb,
    transcriber,
    injector,
    rewriter,
    editTargets,
    selection: selectionReader,
    explain,
    dictionary: {
      // The old free-text vocabulary setting still counts until the
      // Dictionary tab replaces it.
      prompt: () => whisperPrompt(dictionary.list(), splitVocabulary(store.get().vocabulary)),
      // Deepgram takes the same words as a list rather than a sentence.
      terms: () => vocabularyTerms(dictionary.list(), splitVocabulary(store.get().vocabulary)),
      apply: (text) => {
        const { text: fixed, hits } = applyReplacements(text, dictionary.list());
        dictionary.recordUses(hits);
        return fixed;
      },
    },
    getSettings: () => store.get(),
    hasApiKey: () => store.hasApiKey(),
    hasRewriteKey: () => store.hasRewriteKey(),
    runAgent,
    cancelAgent,
    isAgentReady: () => {
      const status = supervisor.status();
      return status.state === 'online' && status.mcpServers.length > 0;
    },
    isAgentManaged: () => supervisor.status().managed,
    getPermissions,
    openSettings,
    onBlocked: (reason) => {
      // A loaded window hears it live; otherwise the refusal is about to
      // create or finish loading it, and the page takes the reason on mount.
      const contents = settingsWindow?.webContents;
      if (contents && !contents.isLoading()) contents.send('session:blocked', reason);
      else pendingBlocked = reason;
    },
    onDictation: (text) => {
      store.recordDictation(text);
      correctionWatcher.watch(text);
    },
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
    onStart: () => startSession('dictate'),
    onStop: () => session.stop(),
    onCancel: () => session.cancel(),
  });
  // Voice edit is the same gesture on a second key. Each detector resets on
  // any key but its own, and the session's busy guard covers the rest.
  const editDetector = createGestureDetector({
    key: store.get().editGestureKey,
    tapCount: store.get().tapCount,
    onStart: () => startSession('edit'),
    onStop: () => session.stop(),
    onCancel: () => session.cancel(),
  });
  let editEnabled = false;
  // Explain is voice edit's sibling: the speech is a question about the selection.
  const explainDetector = createGestureDetector({
    key: store.get().explainGestureKey,
    tapCount: store.get().tapCount,
    // No dismiss here: a gesture while the card is open is a follow-up on
    // the same thread, decided inside explain.ask() itself.
    onStart: () => startSession('explain'),
    onStop: () => session.stop(),
    onCancel: () => session.cancel(),
  });
  let explainEnabled = false;
  // Act is the fourth sibling: the speech after the gesture is a command.
  const actDetector = createGestureDetector({
    key: store.get().actGestureKey,
    tapCount: store.get().tapCount,
    onStart: () => startSession('act'),
    onStop: () => session.stop(),
    onCancel: () => session.cancel(),
  });
  let actEnabled = false;
  const keyHook = createKeyHook(
    uIOhook,
    UiohookKey as unknown as Record<string, number>,
    (event) => {
      wordOffer.handleKey(event);
      actionConfirm.handleKey(event);
      detector.handle(event);
      if (editEnabled) editDetector.handle(event);
      if (explainEnabled) explainDetector.handle(event);
      if (actEnabled) actDetector.handle(event);
      if (event.type === 'down' && event.key === 'Escape') {
        // A waiting approval takes Esc as no; anywhere else in a run it is a
        // cancel, and outside a run the session ignores it as before.
        if (awaitingApproval) actionConfirm.decline();
        else session.cancel();
        explain.dismiss();
      }
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
    explainDetector.configure({ key: settings.explainGestureKey, tapCount: settings.tapCount });
    actDetector.configure({ key: settings.actGestureKey, tapCount: settings.tapCount });
    explainEnabled =
      settings.explainGestureKey !== settings.gestureKey &&
      settings.explainGestureKey !== settings.editGestureKey;
    // One key cannot mean both, and dictation is the one that keeps it.
    editEnabled = settings.editGestureKey !== settings.gestureKey;
    actEnabled =
      settings.actGestureKey !== settings.gestureKey &&
      settings.actGestureKey !== settings.editGestureKey &&
      settings.actGestureKey !== settings.explainGestureKey;
    // Only the packaged app: in dev this would register the bare Electron
    // binary from node_modules as a login item.
    if (app.isPackaged) app.setLoginItemSettings({ openAtLogin: settings.launchAtLogin });
  }
  applySettings(store.get());

  // Sync with parley-api: only while switched on and signed in. The engine
  // never throws and never blocks dictation; a failure lands in the view.
  const SYNC_FIRST_MS = 10_000;
  const SYNC_EVERY_MS = 5 * 60_000;
  const SYNC_SOON_MS = 30_000;
  let syncEngine: ReturnType<typeof createSyncEngine> | null = null;
  let syncFirst: NodeJS.Timeout | null = null;
  let syncEvery: NodeJS.Timeout | null = null;
  let syncSoon: NodeJS.Timeout | null = null;
  function clearSyncTimers() {
    if (syncFirst) clearTimeout(syncFirst);
    if (syncEvery) clearInterval(syncEvery);
    if (syncSoon) clearTimeout(syncSoon);
    syncFirst = syncEvery = syncSoon = null;
  }
  /** Called whenever the URL, the switch or the token changes. */
  function rebuildSync() {
    clearSyncTimers();
    const token = store.getSyncToken();
    const settings = store.get();
    if (!token || !settings.syncEnabled) {
      syncEngine = null;
      return;
    }
    syncEngine = createSyncEngine({
      client: createSyncClient({ baseUrl: settings.syncUrl, token }),
      dictionary,
      settings: store,
      cursor: { get: () => store.getSyncCursor(), set: value => store.setSyncCursor(value) },
      lastSyncAt: () => store.view().syncLastAt,
    });
    syncFirst = setTimeout(() => {
      syncFirst = null;
      syncInBackground();
    }, SYNC_FIRST_MS);
    syncEvery = setInterval(syncInBackground, SYNC_EVERY_MS);
  }
  /** One run; a pulled gesture key or tap count takes effect straight away. */
  /** A new account or server starts from zero: no cursor, no push window, no stale outcome. */
  function resetSyncWindow() {
    store.setSyncCursor(0);
    store.recordSync({ at: 0 });
  }
  async function runSync(): Promise<SyncOutcome> {
    if (!syncEngine) return { ok: false, pushed: 0, pulled: 0, message: 'Sign in to sync', at: Date.now() };
    const outcome = await syncEngine.syncNow();
    if (outcome.ok) applySettings(store.get());
    return outcome;
  }
  /** Timer runs have no caller to hand a failure to; the view already records it. */
  function syncInBackground() {
    runSync().catch(err => console.warn('sync run failed', err instanceof Error ? err.message : err));
  }
  /** Debounced: a burst of edits becomes one run, 30 s after the last. */
  function scheduleSyncSoon() {
    if (!syncEngine) return;
    if (syncSoon) clearTimeout(syncSoon);
    syncSoon = setTimeout(() => {
      syncSoon = null;
      syncInBackground();
    }, SYNC_SOON_MS);
  }
  rebuildSync();

  // Clicking anywhere outside the card dismisses it. The window never has focus,
  // so there is no blur event to listen for.
  uIOhook.on('mousedown', () => {
    if (!explainWindow?.isVisible()) return;
    const point = screen.getCursorScreenPoint();
    const bounds = explainWindow.getBounds();
    const inside =
      point.x >= bounds.x &&
      point.x <= bounds.x + bounds.width &&
      point.y >= bounds.y &&
      point.y <= bounds.y + bounds.height;
    if (!inside) explain.dismiss();
  });

  const fromExplainWindow = (event: Electron.IpcMainEvent) =>
    event.sender === explainWindow?.webContents;
  ipcMain.on('explain:height', (event, height: unknown) => {
    if (!fromExplainWindow(event) || typeof height !== 'number' || !Number.isFinite(height)) return;
    explainHeight = Math.round(Math.min(Math.max(height, CARD_MIN_HEIGHT / 2), explainMaxHeight));
    if (explainWindow?.isVisible()) placeExplain();
  });
  ipcMain.on('explain:copy', (event, text: unknown) => {
    if (fromExplainWindow(event) && typeof text === 'string') clipboard.writeText(text);
  });
  ipcMain.on('explain:dismiss', (event) => {
    if (fromExplainWindow(event)) explain.dismiss();
  });

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

  ipcMain.handle('settings:get', async (event) => {
    onlySettingsWindow(event);
    return liveView();
  });
  ipcMain.handle('settings:update', async (event, patch: Partial<Settings>) => {
    onlySettingsWindow(event);
    const before = store.get();
    const stampBefore = store.settingsUpdatedAt();
    const next = store.update(typeof patch === 'object' && patch ? patch : {});
    applySettings(next);
    if (before.syncUrl !== next.syncUrl) resetSyncWindow();
    if (before.syncUrl !== next.syncUrl || before.syncEnabled !== next.syncEnabled) rebuildSync();
    // Only a patch that changed a value is worth pushing.
    if (store.settingsUpdatedAt() !== stampBefore) scheduleSyncSoon();
    if (before.agentUrl !== next.agentUrl || before.agentAutoStart !== next.agentAutoStart) {
      // A new address or a flipped switch: the live run belongs to the old
      // one, and the child belongs to the old config. Stop everything, then
      // let the supervisor attach or spawn fresh.
      cancelAgent();
      agentClient = createAgentClient({ baseUrl: next.agentUrl });
      supervisor.stop();
      supervisor.start();
    }
    return liveView();
  });
  ipcMain.handle('settings:setApiKey', async (event, key: unknown): Promise<KeyTestResult> => {
    onlySettingsWindow(event);
    if (typeof key !== 'string' || key.trim() === '') return { ok: false, message: 'Enter a key' };
    const result = await transcriber.testKey(key.trim(), 'groq');
    if (result.ok) {
      store.setApiKey(key.trim());
      refreshTray();
    }
    return result;
  });
  ipcMain.handle('settings:setDeepgramKey', async (event, key: unknown): Promise<KeyTestResult> => {
    onlySettingsWindow(event);
    if (typeof key !== 'string' || key.trim() === '') return { ok: false, message: 'Enter a key' };
    const result = await transcriber.testKey(key.trim(), 'deepgram');
    if (result.ok) {
      store.setDeepgramKey(key.trim());
      refreshTray();
    }
    return result;
  });
  ipcMain.handle('settings:setTranscriptionProvider', async (event, provider: unknown) => {
    onlySettingsWindow(event);
    if (!TRANSCRIPTION_PROVIDERS.includes(provider as never)) return liveView();
    store.setTranscriptionProvider(provider as TranscriptionProvider);
    // Readiness is "the selected provider has a key", so the tray may flip.
    refreshTray();
    return liveView();
  });
  ipcMain.handle('settings:setRewriteKey', async (event, key: unknown): Promise<KeyTestResult> => {
    onlySettingsWindow(event);
    if (typeof key !== 'string' || key.trim() === '') return { ok: false, message: 'Enter a key' };
    const result = await rewriter.testKey(key.trim());
    if (result.ok) store.setRewriteKey(key.trim());
    return result;
  });
  ipcMain.handle('agent:setUrl', async (event, url: unknown): Promise<AgentTestResult> => {
    onlySettingsWindow(event);
    if (typeof url !== 'string' || url.trim() === '') {
      return { ok: false, message: 'Enter a URL', mcpServers: [] };
    }
    const trimmed = url.trim();
    if (!isLocalhostUrl(trimmed)) {
      // A remote agent must answer before it is saved. A local one cannot be
      // tested first — nothing answers until Parley spawns it — so it saves
      // optimistically and the supervisor proves it, out loud, in the tab.
      const checked = await createAgentClient({ baseUrl: trimmed }).checkHealth();
      if (!checked.ok) return checked;
    }
    cancelAgent();
    agentClient = createAgentClient({ baseUrl: trimmed });
    store.update({ agentUrl: trimmed });
    supervisor.stop();
    supervisor.start();
    const live = await supervisor.refresh();
    return {
      ok: true,
      message: live.online ? 'Agent works' : 'Starting…',
      mcpServers: live.mcpServers,
    };
  });
  ipcMain.handle('agent:test', async (event): Promise<AgentTestResult> => {
    onlySettingsWindow(event);
    const live = await supervisor.refresh();
    return {
      ok: live.online,
      message: live.online ? 'Agent works' : live.message,
      mcpServers: live.mcpServers,
    };
  });
  ipcMain.handle('agent:restart', async (event): Promise<AgentTestResult> => {
    onlySettingsWindow(event);
    supervisor.restart();
    // The Agent tab polls `agent:status`, so this returns while the Restart
    // is still warming up instead of blocking the button for thirty seconds.
    return { ok: true, message: 'Restarting…', mcpServers: supervisor.status().mcpServers };
  });
  ipcMain.handle('agent:decideApproval', async (event, callId: unknown, approved: unknown) => {
    onlySettingsWindow(event);
    if (typeof callId !== 'string' || typeof approved !== 'boolean') return false;
    return actionConfirm.answerFromTab(callId, approved);
  });
  ipcMain.handle('agent:status', async (event): Promise<AgentSummary> => {
    onlySettingsWindow(event);
    const live = await supervisor.refresh();
    return { ...live, currentRun: currentRunSummary() };
  });
  ipcMain.handle('sync:signIn', async (event, email: unknown): Promise<SyncSignInResult> => {
    onlySettingsWindow(event);
    if (typeof email !== 'string' || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.trim())) {
      return { ok: false, message: 'Enter an email address' };
    }
    const address = email.trim();
    try {
      // No token yet: this client only asks for one.
      const { token } = await createSyncClient({ baseUrl: store.get().syncUrl, token: null }).signIn(address);
      store.setSyncToken(token);
      store.update({ syncEmail: address, syncEnabled: true });
      resetSyncWindow();
      rebuildSync();
      const outcome = await runSync();
      return { ok: outcome.ok, message: outcome.ok ? 'Signed in and synced' : outcome.message };
    } catch (err) {
      return { ok: false, message: err instanceof Error ? err.message : 'Sign-in failed' };
    }
  });
  ipcMain.handle('sync:signOut', async (event) => {
    onlySettingsWindow(event);
    store.setSyncToken(null);
    store.update({ syncEnabled: false });
    resetSyncWindow();
    rebuildSync();
    return liveView();
  });
  ipcMain.handle('sync:now', async (event): Promise<SyncOutcome> => {
    onlySettingsWindow(event);
    return runSync();
  });
  ipcMain.handle('session:take-blocked', (event) => {
    onlySettingsWindow(event);
    const reason = pendingBlocked;
    pendingBlocked = null;
    return reason;
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

  // Quitting mid-run waits for the run's DELETE (or the grace, whichever
  // is first) so the agent does not keep working for an app that is gone.
  // Any other quit goes straight through; a second quit during the grace
  // finds no live run and likewise goes through.
  let quitting = false;
  app.on('before-quit', event => {
    if (quitting || !liveRun) return;
    event.preventDefault();
    const run = liveRun;
    cancelAgent();
    supervisor.stop();
    void Promise.race([
      agentClient.cancelRun(run.runId),
      new Promise(resolve => setTimeout(resolve, QUIT_GRACE_MS)),
    ]).then(() => {
      quitting = true;
      app.quit();
    });
  });

  app.on('will-quit', () => {
    clearInterval(trustPoll);
    clearSyncTimers();
    if (hookRunning) keyHook.stop();
    // Best-effort: the DELETE may not land before the process is gone, but
    // the child must never outlive the app.
    cancelAgent();
    supervisor.stop();
  });
}

// A menu bar app outlives its windows.
app.on('window-all-closed', () => {});
