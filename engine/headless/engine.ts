import { createActionConfirm } from '../agent/confirm';
import { createAgentClient, type AgentClient } from '../agent/client';
import { buildAgentEnv } from '../agent/env';
import { createSupervisor, type AgentSupervisor, type SupervisorChild } from '../agent/supervisor';
import { createAudioWatchdog } from '../audio-watchdog';
import { detectCorrection } from '../correction-detect';
import { createCorrectionWatcher } from '../correction-watcher';
import { applyReplacements, splitVocabulary, vocabularyTerms, whisperPrompt } from '../dictionary';
import type { DictionaryStore } from '../dictionary-store';
import { createEditTargets } from '../edit-target';
import { createExplain } from '../explain';
import type { ExplainClient } from '../explain-client';
import { createGestureDetector } from '../gesture-detector';
import type { Rewriter } from '../rewriter';
import { createSelectionReader } from '../selection-reader';
import { createWordOffer } from '../word-offer';
import { isServerKeyId, removeServerKey, setServerKey } from '../server-keys';
import { fetchServerStatus as defaultFetchServerStatus } from '../server-status';
import { createSession, ERROR_MS, type Session } from '../session';
import type { SettingsStore } from '../settings-store';
import { createSyncClient as defaultCreateSyncClient, type SyncClient } from '../sync/client';
import { createSyncEngine, type SyncOutcome } from '../sync/engine';
import type { Transcriber } from '../transcriber';
import {
  GESTURE_KEYS,
  NOTICE_MS,
  TRANSCRIPTION_PROVIDERS,
  type AgentSummary,
  type AgentTestResult,
  type KeyEvent,
  type KeyName,
  type PermissionStatus,
  type ServerStatus,
  type SessionMode,
  type Settings,
  type SettingsView,
  type TranscriptionProvider,
} from '../types';
import { createPlatform, type Platform } from './platform';
import { PROTOCOL_VERSION, RPC_ERRORS, RpcError, type Rpc } from './rpc';
import type { KeyedCrypto } from './secret';

/**
 * The engine's composition root: every mode of Parley — dictate, voice edit,
 * Explain, Act — plus learning words, sync and the agent, wired the way the
 * Electron main process wired them, with every OS effect sent to the native
 * shell through `Platform`.
 */

/** How long `awaiting_audio` may wait for the shell's recording. */
export const AUDIO_WATCHDOG_MS = 5000;
/** Agent answers longer than this go to the clipboard; the pill only says so. */
export const RESULT_CHARS = 120;
/** Quitting mid-run waits this long for the run's DELETE before giving up. */
export const QUIT_GRACE_MS = 500;

export const SYNC_FIRST_MS = 10_000;
export const SYNC_EVERY_MS = 5 * 60_000;
export const SYNC_SOON_MS = 30_000;
/** How recent a copy Explain falls back to when nothing is selected. */
export const RECENT_COPY_MS = 30_000;

type Params = Record<string, unknown> | undefined;

export interface AgentHost {
  /** Starts a child process; the engine never runs a shell. */
  spawn(command: string, args: string[], opts: { cwd: string; env: Record<string, string> }): SupervisorChild;
  processEnv: Record<string, string | undefined>;
  /** This Node binary: it runs the bundled agent and its MCP servers. */
  execPath: string;
}

export interface EngineDeps {
  rpc: Pick<Rpc, 'request' | 'notify'>;
  store: SettingsStore;
  dictionary: DictionaryStore;
  transcriber: Pick<Transcriber, 'transcribe'>;
  rewriter: Pick<Rewriter, 'rewrite'>;
  explainClient: Pick<ExplainClient, 'stream'>;
  /** Reads the shell's temp recording, then removes it. */
  takeAudio(path: string): Promise<ArrayBuffer>;
  engineVersion: string;
  crypto?: KeyedCrypto;
  /** Without it Act reports the agent offline. */
  agentHost?: AgentHost;
  isCommonWord?(word: string): boolean;
  platform?: Platform;
  fetchServerStatus?(url: string): Promise<ServerStatus>;
  createAgentClient?(baseUrl: string): AgentClient;
  createSyncClient?(options: { baseUrl: string; token: string | null }): SyncClient;
  fetch?: typeof fetch;
}

export interface Engine {
  onRequest(method: string, params: Params): Promise<unknown>;
  onNotify(method: string, params: Params): void;
  /** Stops timers and the agent child; the process is about to exit. */
  shutdown(): Promise<void>;
  session: Session;
}

const KEY_NAMES = new Set<string>([...GESTURE_KEYS, 'Escape', 'Other']);

function parseKeyEvent(params: Params): KeyEvent | null {
  if (!params) return null;
  const { type, key, time } = params;
  if (type !== 'down' && type !== 'up') return null;
  if (typeof time !== 'number' || !Number.isFinite(time)) return null;
  const name = typeof key === 'string' && KEY_NAMES.has(key) ? (key as KeyName) : 'Other';
  return { type, key: name, time };
}

function parsePermissions(value: unknown): PermissionStatus | null {
  if (!value || typeof value !== 'object') return null;
  const { microphone, accessibility } = value as Record<string, unknown>;
  if (typeof microphone !== 'boolean' || typeof accessibility !== 'boolean') return null;
  return { microphone, accessibility };
}

export function isLocalhostUrl(url: string): boolean {
  try {
    const host = new URL(url).hostname;
    return host === 'localhost' || host === '127.0.0.1' || host === '::1' || host === '[::1]';
  } catch {
    return false;
  }
}

const string = (value: unknown) => (typeof value === 'string' ? value : undefined);

export function createEngine(deps: EngineDeps): Engine {
  const { rpc, store, dictionary } = deps;
  const platform = deps.platform ?? createPlatform(rpc);
  const fetchStatus = deps.fetchServerStatus ?? defaultFetchServerStatus;
  const newAgentClient = deps.createAgentClient ?? ((baseUrl: string) => createAgentClient({ baseUrl }));
  const newSyncClient = deps.createSyncClient ?? defaultCreateSyncClient;
  const serverUrl = () => store.get().syncUrl;
  const log = (level: string, message: string) => rpc.notify('log', { level, message });

  /** Nothing is granted until the shell says so in `hello`. */
  let permissions: PermissionStatus = { microphone: false, accessibility: false };
  /** Where the bundled agent lives in the app; null without one. */
  let agentDir: string | null = null;
  let launchAtLoginSent: boolean | null = null;

  // eslint-disable-next-line prefer-const
  let session: Session;

  // ------------------------------------------------------------ the pill ---
  const audioWatchdog = createAudioWatchdog({
    timeoutMs: AUDIO_WATCHDOG_MS,
    onTimeout: () => {
      log('warn', 'no recording arrived; session recovered');
      void session.receiveAudio({ data: new ArrayBuffer(0), mimeType: 'audio/mp4', durationMs: 0 });
    },
  });
  const orb = {
    show: () => platform.orb.show(),
    hide: () => platform.orb.hide(),
    setPhase: (payload: Parameters<Platform['orb']['setPhase']>[0]) => {
      platform.orb.setPhase(payload);
      // `transcribing` is set on entering `awaiting_audio`; any other phase
      // means the wait is over.
      if (payload.phase === 'transcribing') audioWatchdog.arm();
      else audioWatchdog.clear();
    },
  };

  // ------------------------------------------------- fields and selection ---
  const fieldReader = { read: () => platform.readField() };
  const editTargets = createEditTargets({
    reader: fieldReader,
    injector: platform.injector,
    select: (range) => platform.selectRange(range),
  });
  // Explain's two routes to the selection, each logged (sizes and app only,
  // never the text) so a "nothing selected" can be traced to which one failed.
  const selectionReader = createSelectionReader({
    reader: {
      read: async () => {
        const field = await platform.readField();
        log(
          'info',
          field
            ? `explain: AX read app=${field.bundleId ?? '?'} editable=${field.editable} selected=${field.selectedText.length} chars`
            : 'explain: AX read returned no field'
        );
        return field;
      },
    },
    injector: {
      copySelection: async () => {
        const text = await platform.injector.copySelection();
        log('info', `explain: ⌘C fallback copied ${text.length} chars`);
        return text;
      },
    },
    recentCopy: async () => {
      const text = await platform.recentCopy(RECENT_COPY_MS);
      log('info', `explain: recent copy ${text.length} chars`);
      return text;
    },
  });
  /** Whether the open card answers a recent copy rather than a selection. */
  let explainingCopy = false;
  const explainView: Platform['explainView'] = {
    show: (anchor, content) => {
      platform.notify('explain.show', { anchor, content, fromClipboard: explainingCopy });
    },
    update: (content) => platform.explainView.update(content),
    hide: () => platform.explainView.hide(),
  };
  const readSelection = async () => {
    const snapshot = await selectionReader.read();
    explainingCopy = snapshot?.fromClipboard === true;
    return snapshot;
  };
  const explain = createExplain({
    selection: { read: readSelection },
    client: deps.explainClient,
    view: explainView,
  });

  const isCommonWord = deps.isCommonWord ?? (() => false);

  // ------------------------------------------------------------- the agent ---
  let agentClient = newAgentClient(store.get().agentUrl);
  const agentPort = () => {
    try {
      return Number(new URL(store.get().agentUrl).port) || 4111;
    } catch {
      return 4111;
    }
  };
  const supervisor: AgentSupervisor | null = deps.agentHost
    ? createSupervisor({
        getConfig: () => {
          const host = deps.agentHost!;
          const port = agentPort();
          const env = buildAgentEnv({
            processEnv: host.processEnv,
            port,
            serverUrl: serverUrl(),
            packaged: true,
            execPath: host.execPath,
          });
          // The bundled server runs under this same Node; MCP servers that
          // need `node` find it through PARLEY_NODE_BIN.
          delete env.ELECTRON_RUN_AS_NODE;
          const dir = agentDir ?? '';
          return {
            autoStart: store.get().agentAutoStart && agentDir !== null,
            managed: isLocalhostUrl(store.get().agentUrl),
            spawn: {
              command: host.execPath,
              args: [`${dir}/index.mjs`],
              cwd: dir,
              env,
              description: agentDir ? 'the bundled agent server' : 'no agent in this build',
            },
            port,
          };
        },
        spawn: (command, args, opts) => deps.agentHost!.spawn(command, args, opts),
        checkHealth: () => agentClient.checkHealth(),
        onLog: (line) => log('info', `[agent] ${line}`),
      })
    : null;

  let liveRun: { runId: string; abort: AbortController; lastStep: string } | null = null;
  let awaitingApproval = false;
  let approvalSummary: string | null = null;
  let approvalCallId: string | null = null;
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
      platform.writeClipboard(text);
      orb.setPhase({ phase: 'notice', message: 'Copied — paste anywhere' });
    }
    hideResultSoon(NOTICE_MS);
  }

  function showRunError(message: string) {
    orb.setPhase({ phase: 'error', message: `Agent failed · ${message}` });
    hideResultSoon(ERROR_MS);
  }

  function clearApproval() {
    awaitingApproval = false;
    approvalSummary = null;
    approvalCallId = null;
  }

  const actionConfirm = createActionConfirm({
    orb,
    key: () => store.get().actGestureKey,
    speak: (text) => {
      if (store.get().tickSound) platform.speak(text);
    },
    approve: () => (liveRun ? agentClient.approve(liveRun.runId, true) : Promise.resolve()),
    decline: () => (liveRun ? agentClient.approve(liveRun.runId, false) : Promise.resolve()),
    resume: () => {
      clearApproval();
      if (liveRun) paintWorking(liveRun.lastStep);
    },
    onDecisionFailed: (error) => {
      runToken += 1;
      const run = liveRun;
      liveRun = null;
      clearApproval();
      if (run) {
        run.abort.abort();
        void agentClient.cancelRun(run.runId);
      }
      showRunError(error instanceof Error ? error.message : 'Something went wrong');
    },
  });

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
            if (!awaitingApproval) paintWorking(event.text);
          } else if (event.kind === 'approval_requested') {
            awaitingApproval = true;
            approvalSummary = event.summary;
            approvalCallId = event.callId;
            actionConfirm.ask({ callId: event.callId, summary: event.summary, transcript: event.transcript });
          }
        },
        { signal: abort.signal }
      );
      if (mine !== runToken) return;
      liveRun = null;
      clearApproval();
      actionConfirm.cancel();
      if (outcome.kind === 'completed') showResult(outcome.text);
      else if (outcome.kind === 'failed') showRunError(outcome.message);
      else orb.hide();
    } catch (error) {
      if (runId) void agentClient.cancelRun(runId);
      if (mine !== runToken) return;
      liveRun = null;
      clearApproval();
      actionConfirm.cancel();
      showRunError(error instanceof Error ? error.message : 'Something went wrong');
    }
  }

  function cancelAgent(): void {
    runToken += 1;
    const run = liveRun;
    liveRun = null;
    clearApproval();
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

  async function agentSummary(): Promise<AgentSummary> {
    if (!supervisor) {
      return {
        online: false,
        managed: false,
        serverState: 'offline',
        message: 'No agent in this build',
        currentRun: null,
        mcpServers: [],
      };
    }
    const live = await supervisor.refresh();
    return { ...live, currentRun: currentRunSummary() };
  }

  async function liveView(): Promise<SettingsView> {
    return store.view(await agentSummary());
  }

  // ------------------------------------------------------- learning words ---
  const offer = createWordOffer({
    orb,
    isIdle: () => session.state() === 'idle',
    key: () => store.get().gestureKey,
    onAccept: ({ heard, word }) => {
      const saved = dictionary.upsert({ word, soundsLike: [heard] });
      if (saved) scheduleSyncSoon();
      return saved;
    },
    onDecline: ({ word }) => dictionary.decline(word),
  });
  const correctionWatcher = createCorrectionWatcher({
    reader: fieldReader,
    detect: (pasted, value) => detectCorrection(pasted, value, { isCommonWord }),
    onCorrection: (correction) => {
      if (!dictionary.isIgnored(correction.word)) offer.offer(correction);
    },
  });

  // ------------------------------------------------------------- session ---
  function startSession(mode: SessionMode) {
    correctionWatcher.cancel();
    offer.cancel();
    if (session.state() === 'transcribing') session.cancel();
    if (mode === 'act' && supervisor) {
      void supervisor.refresh();
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
    transcriber: deps.transcriber,
    injector: platform.injector,
    rewriter: deps.rewriter,
    editTargets,
    selection: { read: readSelection },
    explain,
    dictionary: {
      prompt: () => whisperPrompt(dictionary.list(), splitVocabulary(store.get().vocabulary)),
      terms: () => vocabularyTerms(dictionary.list(), splitVocabulary(store.get().vocabulary)),
      apply: (text) => {
        const { text: fixed, hits } = applyReplacements(text, dictionary.list());
        dictionary.recordUses(hits);
        return fixed;
      },
    },
    getSettings: () => store.get(),
    runAgent,
    cancelAgent,
    isAgentReady: () => {
      if (!supervisor) return false;
      const status = supervisor.status();
      return status.state === 'online' && status.mcpServers.length > 0;
    },
    getPermissions: () => permissions,
    openSettings: () => platform.openSettings(),
    onBlocked: (reason) => {
      rpc.notify('session.blocked', { reason });
    },
    onDictation: (text) => {
      store.recordDictation(text);
      correctionWatcher.watch(text);
    },
    onTranscript: (text) => rpc.notify('transcript', { text }),
  });

  // ------------------------------------------------------------- gestures ---
  const make = (mode: SessionMode, key: keyof Settings) =>
    createGestureDetector({
      key: store.get()[key] as Settings['gestureKey'],
      tapCount: store.get().tapCount,
      onStart: () => startSession(mode),
      onStop: () => session.stop(),
      onCancel: () => session.cancel(),
    });
  const detector = make('dictate', 'gestureKey');
  const editDetector = make('edit', 'editGestureKey');
  const explainDetector = make('explain', 'explainGestureKey');
  const actDetector = make('act', 'actGestureKey');
  let editEnabled = false;
  let explainEnabled = false;
  let actEnabled = false;

  function applySettings(settings: Settings) {
    detector.configure({ key: settings.gestureKey, tapCount: settings.tapCount });
    editDetector.configure({ key: settings.editGestureKey, tapCount: settings.tapCount });
    explainDetector.configure({ key: settings.explainGestureKey, tapCount: settings.tapCount });
    actDetector.configure({ key: settings.actGestureKey, tapCount: settings.tapCount });
    // One key cannot mean two modes; the earlier mode keeps it.
    editEnabled = settings.editGestureKey !== settings.gestureKey;
    explainEnabled =
      settings.explainGestureKey !== settings.gestureKey && settings.explainGestureKey !== settings.editGestureKey;
    actEnabled =
      settings.actGestureKey !== settings.gestureKey &&
      settings.actGestureKey !== settings.editGestureKey &&
      settings.actGestureKey !== settings.explainGestureKey;
    if (launchAtLoginSent !== settings.launchAtLogin) {
      launchAtLoginSent = settings.launchAtLogin;
      platform.setLaunchAtLogin(settings.launchAtLogin);
    }
  }

  function handleKey(event: KeyEvent) {
    offer.handleKey(event);
    actionConfirm.handleKey(event);
    detector.handle(event);
    if (editEnabled) editDetector.handle(event);
    if (explainEnabled) explainDetector.handle(event);
    if (actEnabled) actDetector.handle(event);
    if (event.type === 'down' && event.key === 'Escape') {
      if (awaitingApproval) actionConfirm.decline();
      else session.cancel();
      explain.dismiss();
    }
  }

  // ----------------------------------------------------------------- sync ---
  let syncEngine: ReturnType<typeof createSyncEngine> | null = null;
  let syncFirst: ReturnType<typeof setTimeout> | null = null;
  let syncEvery: ReturnType<typeof setInterval> | null = null;
  let syncSoon: ReturnType<typeof setTimeout> | null = null;

  function clearSyncTimers() {
    if (syncFirst) clearTimeout(syncFirst);
    if (syncEvery) clearInterval(syncEvery);
    if (syncSoon) clearTimeout(syncSoon);
    syncFirst = syncEvery = syncSoon = null;
  }

  function rebuildSync() {
    clearSyncTimers();
    const token = store.getSyncToken();
    const settings = store.get();
    if (!token || !settings.syncEnabled) {
      syncEngine = null;
      return;
    }
    syncEngine = createSyncEngine({
      client: newSyncClient({ baseUrl: settings.syncUrl, token }),
      dictionary,
      settings: store,
      cursor: { get: () => store.getSyncCursor(), set: (value) => store.setSyncCursor(value) },
      lastSyncAt: () => store.view().syncLastAt,
    });
    syncFirst = setTimeout(() => {
      syncFirst = null;
      syncInBackground();
    }, SYNC_FIRST_MS);
    syncEvery = setInterval(syncInBackground, SYNC_EVERY_MS);
  }

  function resetSyncWindow() {
    store.setSyncCursor(0);
    store.recordSync({ at: 0 });
  }

  async function runSync(): Promise<SyncOutcome> {
    if (!syncEngine) return { ok: false, pushed: 0, pulled: 0, message: 'Sign in to sync', at: Date.now() };
    const outcome = await syncEngine.syncNow();
    if (outcome.ok) applySettings(store.get());
    // The settings window, if open, repaints from this.
    rpc.notify('settings.changed', { view: store.view() });
    return outcome;
  }

  function syncInBackground() {
    runSync().catch((err) => log('warn', `sync run failed: ${err instanceof Error ? err.message : String(err)}`));
  }

  function scheduleSyncSoon() {
    if (!syncEngine) return;
    if (syncSoon) clearTimeout(syncSoon);
    syncSoon = setTimeout(() => {
      syncSoon = null;
      syncInBackground();
    }, SYNC_SOON_MS);
  }

  // --------------------------------------------------------------- audio ---
  async function receiveAudio(params: Params) {
    const path = params?.path;
    const mimeType = params?.mimeType;
    const durationMs = params?.durationMs;
    if (typeof path !== 'string' || typeof mimeType !== 'string' || typeof durationMs !== 'number') {
      log('error', 'audio.ready with a malformed payload');
      return;
    }
    let data: ArrayBuffer;
    try {
      // The shell answers every `transcribing` with an `audio.ready`; when
      // the recording failed or never started, the path is empty.
      data = path ? await deps.takeAudio(path) : new ArrayBuffer(0);
    } catch (error) {
      log('error', `could not read the recording: ${error instanceof Error ? error.message : String(error)}`);
      data = new ArrayBuffer(0);
    }
    audioWatchdog.clear();
    await session.receiveAudio({ data, mimeType, durationMs: data.byteLength === 0 ? 0 : durationMs });
  }

  // ------------------------------------------------------------ requests ---
  async function updateSettings(patch: Partial<Settings>): Promise<SettingsView> {
    const before = store.get();
    const stampBefore = store.settingsUpdatedAt();
    const next = store.update(patch);
    applySettings(next);
    if (before.syncUrl !== next.syncUrl) resetSyncWindow();
    if (before.syncUrl !== next.syncUrl || before.syncEnabled !== next.syncEnabled) rebuildSync();
    if (store.settingsUpdatedAt() !== stampBefore) scheduleSyncSoon();
    if (supervisor && (before.agentUrl !== next.agentUrl || before.agentAutoStart !== next.agentAutoStart)) {
      cancelAgent();
      agentClient = newAgentClient(next.agentUrl);
      supervisor.stop();
      supervisor.start();
    }
    return liveView();
  }

  async function setAgentUrl(url: unknown): Promise<AgentTestResult> {
    if (typeof url !== 'string' || url.trim() === '') return { ok: false, message: 'Enter a URL', mcpServers: [] };
    const trimmed = url.trim();
    if (!isLocalhostUrl(trimmed)) {
      const checked = await newAgentClient(trimmed).checkHealth();
      if (!checked.ok) return checked;
    }
    cancelAgent();
    agentClient = newAgentClient(trimmed);
    store.update({ agentUrl: trimmed });
    if (!supervisor) return { ok: true, message: 'Saved', mcpServers: [] };
    supervisor.stop();
    supervisor.start();
    const live = await supervisor.refresh();
    return { ok: true, message: live.online ? 'Agent works' : 'Starting…', mcpServers: live.mcpServers };
  }

  async function signIn(email: unknown) {
    if (typeof email !== 'string' || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.trim())) {
      return { ok: false, message: 'Enter an email address' };
    }
    if (!deps.crypto?.isEncryptionAvailable()) {
      return { ok: false, message: 'The Keychain key is not available' };
    }
    const address = email.trim();
    try {
      const { token } = await newSyncClient({ baseUrl: store.get().syncUrl, token: null }).signIn(address);
      store.setSyncToken(token);
      store.update({ syncEmail: address, syncEnabled: true });
      resetSyncWindow();
      rebuildSync();
      const outcome = await runSync();
      return { ok: outcome.ok, message: outcome.ok ? 'Signed in and synced' : outcome.message };
    } catch (err) {
      return { ok: false, message: err instanceof Error ? err.message : 'Sign-in failed' };
    }
  }

  async function hello(params: Params) {
    if (params?.protocolVersion !== PROTOCOL_VERSION) {
      throw new RpcError(
        `Protocol mismatch: shell speaks ${String(params?.protocolVersion)}, engine speaks ${PROTOCOL_VERSION}`,
        RPC_ERRORS.invalidRequest
      );
    }
    const granted = parsePermissions(params.permissions);
    if (granted) permissions = granted;
    const secret = string(params.secretKey);
    if (secret && deps.crypto) deps.crypto.setKey(Buffer.from(secret, 'base64'));
    agentDir = string(params.agentDir) ?? null;
    applySettings(store.get());
    rebuildSync();
    supervisor?.start();
    return { protocolVersion: PROTOCOL_VERSION, engineVersion: deps.engineVersion, settings: await liveView() };
  }

  const handlers: Record<string, (params: Params) => unknown> = {
    hello,
    'settings.get': () => liveView(),
    'settings.update': (params) => {
      const patch = params?.patch;
      return updateSettings(patch && typeof patch === 'object' ? (patch as Partial<Settings>) : {});
    },
    'settings.setProvider': async (params) => {
      const provider = params?.provider;
      if (TRANSCRIPTION_PROVIDERS.includes(provider as never)) {
        const stampBefore = store.settingsUpdatedAt();
        store.setTranscriptionProvider(provider as TranscriptionProvider);
        if (store.settingsUpdatedAt() !== stampBefore) scheduleSyncSoon();
      }
      return liveView();
    },
    'dictionary.list': () => ({ entries: dictionary.list() }),
    'dictionary.upsert': (params) => {
      const word = string(params?.word);
      const soundsLike = Array.isArray(params?.soundsLike)
        ? (params.soundsLike as unknown[]).filter((s): s is string => typeof s === 'string')
        : [];
      if (!word) throw new RpcError('A word is required', RPC_ERRORS.invalidRequest);
      const entry = dictionary.upsert({ id: string(params?.id), word, soundsLike });
      if (entry) scheduleSyncSoon();
      return { entry };
    },
    'dictionary.remove': (params) => {
      const id = string(params?.id);
      if (id) {
        dictionary.remove(id);
        scheduleSyncSoon();
      }
      return { entries: dictionary.list() };
    },
    'server.status': () => fetchStatus(serverUrl()),
    // The key is passed straight to the server: never stored, never logged.
    'server.setKey': async (params) => {
      const provider = params?.provider;
      const key = string(params?.key);
      if (!isServerKeyId(provider)) throw new RpcError('Unknown provider', RPC_ERRORS.invalidRequest);
      if (!key?.trim()) throw new RpcError('Paste a key first', RPC_ERRORS.invalidRequest);
      await setServerKey(serverUrl(), provider, key, deps.fetch);
      return fetchStatus(serverUrl());
    },
    'server.removeKey': async (params) => {
      const provider = params?.provider;
      if (!isServerKeyId(provider)) throw new RpcError('Unknown provider', RPC_ERRORS.invalidRequest);
      await removeServerKey(serverUrl(), provider, deps.fetch);
      return fetchStatus(serverUrl());
    },
    'agent.status': () => agentSummary(),
    'agent.setUrl': (params) => setAgentUrl(params?.url),
    'agent.test': async (): Promise<AgentTestResult> => {
      const live = await agentSummary();
      return { ok: live.online, message: live.online ? 'Agent works' : live.message, mcpServers: live.mcpServers };
    },
    'agent.restart': (): AgentTestResult => {
      if (!supervisor) return { ok: false, message: 'No agent in this build', mcpServers: [] };
      supervisor.restart();
      return { ok: true, message: 'Restarting…', mcpServers: supervisor.status().mcpServers };
    },
    'agent.decide': (params) => {
      const callId = string(params?.callId);
      if (!callId || typeof params?.approved !== 'boolean') return false;
      return actionConfirm.answerFromTab(callId, params.approved);
    },
    'sync.signIn': (params) => signIn(params?.email),
    'sync.signOut': () => {
      store.setSyncToken(null);
      store.update({ syncEnabled: false });
      resetSyncWindow();
      rebuildSync();
      return liveView();
    },
    'sync.now': () => runSync(),
  };

  async function shutdown() {
    clearSyncTimers();
    const run = liveRun;
    cancelAgent();
    if (run) {
      await Promise.race([
        agentClient.cancelRun(run.runId),
        new Promise((resolve) => setTimeout(resolve, QUIT_GRACE_MS)),
      ]);
    }
    supervisor?.stop();
  }

  return {
    session,
    shutdown,

    async onRequest(method, params) {
      const handler = handlers[method];
      if (!handler) throw new RpcError(`Unknown method ${method}`, RPC_ERRORS.methodNotFound);
      return handler(params);
    },

    onNotify(method, params) {
      switch (method) {
        case 'key': {
          const event = parseKeyEvent(params);
          if (event) handleKey(event);
          return;
        }
        case 'audio.ready':
          void receiveAudio(params);
          return;
        case 'permissions.changed': {
          const granted = parsePermissions(params);
          if (granted) permissions = granted;
          return;
        }
        case 'explain.dismiss':
          explain.dismiss();
          return;
        default:
          log('warn', `ignored notification ${method}`);
      }
    },
  };
}
