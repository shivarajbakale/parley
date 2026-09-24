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

export const DEFAULT_SETTINGS: Settings = {
  gestureKey: 'AltRight',
  tapCount: 3,
  editGestureKey: 'MetaRight',
  explainGestureKey: 'CtrlRight',
  vocabulary: '',
  transcriptionProvider: 'groq',
  tickSound: true,
  launchAtLogin: true,
  tourSeen: false,
  wizardStep: 0,
  onboardingComplete: false,
};

/** `dictate` pastes what was said; `edit` applies it to the focused field. */
export type SessionMode = 'dictate' | 'edit' | 'explain';

/** Why `session.start()` refused the gesture — sent to the settings window
 * since opening it again is a no-op when it's already the window in front. */
export type SessionBlockedReason = 'microphone' | 'accessibility' | 'apiKey' | 'rewriteKey';

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

/** What the settings window may see. The API key itself never leaves main. */
export interface SettingsView extends Settings {
  /** The selected transcription provider has a key stored. */
  hasApiKey: boolean;
  /** The MiniMax key that voice edit rewrites with. */
  hasRewriteKey: boolean;
  /** Words pasted by dictation, all time. Counted in main; the renderer can
   * read it here but no patch can set it. */
  wordsDictated: number;
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

/** One question-and-answer round in the card. The first turn's `question` is
 * optional: a plain explain with nothing said. A later turn is a follow-up
 * asked on the same selection, same thread, same context. */
export type ExplainTurn =
  | { question?: string; status: 'loading' }
  | { question?: string; status: 'ready'; markdown: string }
  | { question?: string; status: 'error'; message: string };

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

/** `window.parley`, exposed by `electron/preload.ts`. */
export interface ParleyApi {
  onOrbPhase(listener: (payload: OrbPhasePayload) => void): () => void;
  sendAudio(audio: RecordedAudio): void;
  getSettings(): Promise<SettingsView>;
  updateSettings(patch: Partial<Settings>): Promise<SettingsView>;
  /** The Groq key: tested, then stored if it works. */
  setApiKey(key: string): Promise<KeyTestResult>;
  /** The Deepgram key: tested, then stored if it works. */
  setDeepgramKey(key: string): Promise<KeyTestResult>;
  setTranscriptionProvider(provider: TranscriptionProvider): Promise<SettingsView>;
  setRewriteKey(key: string): Promise<KeyTestResult>;
  getPermissions(): Promise<PermissionStatus>;
  requestPermission(kind: PermissionKind): Promise<PermissionStatus>;
  onExplain(listener: (state: ExplainState) => void): () => void;
  /** The card's rendered height, so main can size the window to fit. */
  reportExplainHeight(height: number): void;
  copyExplain(text: string): void;
  dismissExplain(): void;
  /** Fired when a gesture is refused for a missing permission or key —
   * `openSettings()` is silent when this window is already the one in front. */
  onSessionBlocked(listener: (reason: SessionBlockedReason) => void): () => void;
  /** A refusal that happened while this window was closed or still loading —
   * the refusal is what opened it, so the push above had no one to reach.
   * Taken once: a second call returns null. */
  takeBlockedReason(): Promise<SessionBlockedReason | null>;
}
