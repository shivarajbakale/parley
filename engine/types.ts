import type { SyncOutcome } from './sync/engine';

/** Names match the property names of `UiohookKey` in `uiohook-napi`. */
export const GESTURE_KEYS = [
  'AltRight',
  'Alt',
  'CtrlRight',
  'Ctrl',
  'ShiftRight',
  'Shift',
  'MetaRight',
  'Meta',
] as const;

export type GestureKey = (typeof GESTURE_KEYS)[number];

/** Who turns speech into text. Groq's Whisper is the default. */
export const TRANSCRIPTION_PROVIDERS = ['groq', 'deepgram'] as const;
export type TranscriptionProvider = (typeof TRANSCRIPTION_PROVIDERS)[number];
export type TapCount = 2 | 3 | 4;

/** A key as the detector sees it: a gesture key, Escape, or anything else. */
export type KeyName = GestureKey | 'Escape' | 'Other';

export interface KeyEvent {
  type: 'down' | 'up';
  key: KeyName;
  /** Milliseconds, monotonic. */
  time: number;
}

export interface Settings {
  gestureKey: GestureKey;
  tapCount: TapCount;
  /**
   * Same taps, different key: the speech becomes an instruction that rewrites
   * the focused field. Voice edit is off while it equals `gestureKey`.
   */
  editGestureKey: GestureKey;
  /**
   * Same taps, third key: explains the selected text in a popover. Off while it
   * equals the dictate or the voice edit key.
   */
  explainGestureKey: GestureKey;
  /**
   * Same taps, fourth key: hands the speech to the Mastra agent as a command.
   * Off while it equals any other mode's key.
   */
  actGestureKey: GestureKey;
  /** Where the Mastra agent answers. Localhost URLs are managed (spawned by
   * Parley); anything else is attach-only. */
  agentUrl: string;
  /** Start the managed server with the app. Off means attach-only, for
   * debugging a toxic server. */
  agentAutoStart: boolean;
  /** Push the dictionary and settings to a Parley API and pull what other devices wrote. */
  syncEnabled: boolean;
  /** Where the sync API answers. http(s) only. */
  syncUrl: string;
  /** The account the token was issued to. Shown, never used as a secret. */
  syncEmail: string;
  /** Free text, comma separated. Sent to Whisper as `prompt`, to Deepgram as keyterms. */
  vocabulary: string;
  /** Which service transcribes. Set only through `setTranscriptionProvider`,
   * never through an `updateSettings` patch. */
  transcriptionProvider: TranscriptionProvider;
  tickSound: boolean;
  launchAtLogin: boolean;
  /** First-run tour seen. Reset alone to replay the tour without redoing setup. */
  tourSeen: boolean;
  /** Wizard resume index: steps 0-5, then the Done screen at `WIZARD_STEP_MAX`. */
  wizardStep: number;
  /** Setup finished. Flips the settings window from the wizard to its tabs. */
  onboardingComplete: boolean;
}

/** Wizard steps 0-5 are the six setup steps; the Done screen sits at 6. */
export const WIZARD_STEP_MAX = 6;

/** Mastra's default serve port. The supervisor passes the URL's own port
 * to the child when it differs. */
export const DEFAULT_AGENT_URL = 'http://localhost:4111';

export const DEFAULT_SETTINGS: Settings = {
  gestureKey: 'AltRight',
  tapCount: 3,
  editGestureKey: 'MetaRight',
  explainGestureKey: 'CtrlRight',
  actGestureKey: 'ShiftRight',
  agentUrl: DEFAULT_AGENT_URL,
  agentAutoStart: true,
  syncEnabled: false,
  syncUrl: 'http://localhost:3100',
  syncEmail: '',
  vocabulary: '',
  transcriptionProvider: 'groq',
  tickSound: true,
  launchAtLogin: true,
  tourSeen: false,
  wizardStep: 0,
  onboardingComplete: false,
};

/** `dictate` pastes what was said; `edit` applies it to the focused field;
 * `explain` answers about the selection; `act` hands it to the agent. */
export type SessionMode = 'dictate' | 'edit' | 'explain' | 'act';

/** Why `session.start()` refused the gesture — sent to the settings window
 * since opening it again is a no-op when it's already the window in front. */
export type SessionBlockedReason =
  | 'microphone'
  | 'accessibility'
  | 'agent';

/** `notice` is the pill speaking outside a session: an offer to remember a word. */
export type OrbPhase = 'listening' | 'transcribing' | 'done' | 'error' | 'cancelled' | 'notice';

/** How long an unanswered notice stays up, and how long its "yes" does. */
export const NOTICE_MS = 6000;
export const NOTICE_ACCEPTED_MS = 900;

export interface OrbPhasePayload {
  phase: OrbPhase;
  /** With `error`, and with `notice` where it is the text on the pill. */
  message?: string;
  /** Only with `notice`: the smaller line that says how to answer. */
  hint?: string;
  /** Only with `notice`: the answer was yes, so the pill wears the done colour. */
  accepted?: boolean;
  /** With `listening` and `transcribing`: sounds are on, so play this phase's. */
  tick?: boolean;
  /** Only with `listening`, and only for a voice edit: the orb changes hue. */
  mode?: SessionMode;
}

export interface RecordedAudio {
  data: ArrayBuffer;
  mimeType: string;
  durationMs: number;
}

export interface PermissionStatus {
  microphone: boolean;
  accessibility: boolean;
}

export type PermissionKind = keyof PermissionStatus;

/** One MCP server the agent can reach, as the Agent tab shows it. */
export interface AgentMcpServer {
  name: string;
  tools: number;
}

export type AgentServerState = 'starting' | 'online' | 'offline';

/** The live run or waiting approval, read-only. The tab pairs a wait with
 * Approve/Decline buttons. */
export interface AgentCurrentRun {
  status: 'working' | 'awaiting_approval';
  summary: string;
  /** The waiting call, for answering from the tab. Null while working. */
  callId: string | null;
}

/** Live agent state. The store reports the offline default; main overwrites
 * it with the supervisor's truth at `settings:get` time — the store never
 * holds process state. */
export interface AgentSummary {
  online: boolean;
  /** True while Parley owns the process — restart applies; false when attached. */
  managed: boolean;
  serverState: AgentServerState;
  /** The last named failure, persisted until the next run starts. */
  message: string;
  currentRun: AgentCurrentRun | null;
  mcpServers: AgentMcpServer[];
}

/** The agent before main hands over the supervisor's truth. */
export const OFFLINE_AGENT_SUMMARY: AgentSummary = {
  online: false,
  managed: false,
  serverState: 'offline',
  message: '',
  currentRun: null,
  mcpServers: [],
};

/** Which provider keys parley-api holds; never the keys. */
export interface ServerKeys {
  groq: boolean;
  deepgram: boolean;
  minimax: boolean;
}

/** What `server:status` reports: whether the Parley server answers at `url`,
 * and if so which keys it has. `keys` is null when it did not answer. */
export interface ServerStatus {
  reachable: boolean;
  url: string;
  keys: ServerKeys | null;
}

/** What the settings window may see. Tokens never leave main. */
export interface SettingsView extends Settings {
  /** Words pasted by dictation, all time. Counted in main; the renderer can
   * read it here but no patch can set it. */
  wordsDictated: number;
  /** A sync token is stored. The token itself never leaves main. */
  hasSyncToken: boolean;
  /** Epoch ms of the last sync attempt; 0 is never. */
  syncLastAt: number;
  /** Why the last sync failed; empty when it did not. */
  syncLastError: string;
  agent: AgentSummary;
}

export interface AgentTestResult {
  ok: boolean;
  message: string;
  mcpServers: AgentMcpServer[];
}

export interface KeyTestResult {
  ok: boolean;
  message: string;
}

export interface Rect {
  x: number;
  y: number;
  width: number;
  height: number;
}

/** A page the explainer's web search returned, shown as a link under the answer. */
export interface ExplainSource {
  title: string;
  url: string;
}

/** One question-and-answer round in the card. The first turn's `question` is
 * optional: a plain explain with nothing said. A later turn is a follow-up
 * asked on the same selection, same thread, same context.
 *
 * `loading` and `streaming` both carry `searching` while the agent searches
 * the web; `streaming` is the answer so far, still arriving. An `error` keeps
 * whatever `markdown` arrived before the failure. */
export type ExplainTurn =
  | { question?: string; status: 'loading'; searching?: string }
  | { question?: string; status: 'streaming'; markdown: string; searching?: string }
  | { question?: string; status: 'ready'; markdown: string; sources?: ExplainSource[] }
  | { question?: string; status: 'error'; message: string; markdown?: string };

/** What main tells the explain popover to show. */
export type ExplainContent = { status: 'empty' } | { status: 'thread'; turns: ExplainTurn[] };

/**
 * `opening` marks a fresh thread (play the entrance animation, scroll to top);
 * without it, a `thread` update is a follow-up turn appended to what is
 * already open (no remount, just scroll to the new turn). `closing` plays the
 * exit animation; the window hides once it has finished.
 */
export type ExplainState = ExplainContent & {
  maxHeight: number;
  opening?: boolean;
  closing?: boolean;
};

/** What `sync:signIn` tells the Sync tab: the token request and the first run. */
export interface SyncSignInResult {
  ok: boolean;
  message: string;
}
export type { SyncOutcome };
