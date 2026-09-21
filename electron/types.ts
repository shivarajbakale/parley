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
  /** Free text, comma separated. Sent to Whisper as `prompt`. */
  vocabulary: string;
  tickSound: boolean;
  launchAtLogin: boolean;
}

export const DEFAULT_SETTINGS: Settings = {
  gestureKey: 'AltRight',
  tapCount: 3,
  vocabulary: '',
  tickSound: true,
  launchAtLogin: true,
};

export type OrbPhase = 'listening' | 'transcribing' | 'done' | 'error' | 'cancelled';

export interface OrbPhasePayload {
  phase: OrbPhase;
  /** Only with `error`. */
  message?: string;
  /** Only with `transcribing`: play the stop tick. */
  tick?: boolean;
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
  hasApiKey: boolean;
}

export interface KeyTestResult {
  ok: boolean;
  message: string;
}

/** `window.parley`, exposed by `electron/preload.ts`. */
export interface ParleyApi {
  onOrbPhase(listener: (payload: OrbPhasePayload) => void): () => void;
  sendAudio(audio: RecordedAudio): void;
  getSettings(): Promise<SettingsView>;
  updateSettings(patch: Partial<Settings>): Promise<SettingsView>;
  setApiKey(key: string): Promise<KeyTestResult>;
  getPermissions(): Promise<PermissionStatus>;
  requestPermission(kind: PermissionKind): Promise<PermissionStatus>;
}
