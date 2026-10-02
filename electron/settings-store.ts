import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

import {
  DEFAULT_SETTINGS,
  GESTURE_KEYS,
  OFFLINE_AGENT_SUMMARY,
  TRANSCRIPTION_PROVIDERS,
  WIZARD_STEP_MAX,
  type AgentSummary,
  type Settings,
  type SettingsView,
  type TranscriptionProvider,
} from './types';

/** Agent URLs longer than this are rejected, never truncated — cutting a URL
 * could produce a valid address the user never meant. */
const AGENT_URL_MAX = 200;

/** First versioned settings shape. v0 files predate the onboarding fields. */
export const SETTINGS_SCHEMA_VERSION = 1;

/** The shape of Electron's `safeStorage`, passed in so tests need no Electron. */
export interface CryptoLike {
  isEncryptionAvailable(): boolean;
  encryptString(plain: string): Buffer;
  decryptString(encrypted: Buffer): string;
}

export interface SettingsStore {
  get(): Settings;
  update(patch: Partial<Settings>): Settings;
  /** `live` is the supervisor's truth, handed over by main — without it the
   * agent reads as offline. */
  view(live?: AgentSummary): SettingsView;
  /** The Groq key. */
  getApiKey(): string | null;
  setApiKey(key: string): void;
  /** The selected transcription provider has a key: what readiness and the
   * gesture block mean by "has a key". */
  hasApiKey(): boolean;
  hasGroqKey(): boolean;
  getDeepgramKey(): string | null;
  setDeepgramKey(key: string): void;
  hasDeepgramKey(): boolean;
  /** The key for `provider`, whichever one is selected or not. */
  getTranscriptionKey(provider: TranscriptionProvider): string | null;
  setTranscriptionProvider(provider: TranscriptionProvider): Settings;
  getRewriteKey(): string | null;
  setRewriteKey(key: string): void;
  hasRewriteKey(): boolean;
  /** Count a pasted dictation toward the Overview's time-saved figure. */
  recordDictation(text: string): void;
  /** The sync token, encrypted at rest like the keys. */
  getSyncToken(): string | null;
  setSyncToken(token: string | null): void;
  /** Envelope-only: the outcome of the last sync attempt. */
  recordSync(result: { at: number; error?: string }): void;
  /** Last-writer-wins apply of a synced blob: sanitized like `update()`, and stamped
   * with the remote `updatedAt`, never the local clock. Device-local keys are
   * ignored; the provider is taken only when this device holds its key. */
  applyRemote(patch: Partial<Settings>, updatedAt: number): Settings;
  /** Epoch ms of the last `update()` that changed a value; 0 on a fresh store. */
  settingsUpdatedAt(): number;
  getSyncCursor(): number;
  setSyncCursor(value: number): void;
}

interface FileShape {
  settings?: Partial<Settings>;
  apiKeyEncrypted?: string;
  deepgramKeyEncrypted?: string;
  rewriteKeyEncrypted?: string;
  /** Envelope-only: the renderer can neither read nor write this. */
  schemaVersion?: number;
  /** Envelope-only as well: main counts it, the renderer only reads it. */
  wordsDictated?: number;
  /** Envelope-only sync state: a renderer patch can set none of it. */
  syncTokenEncrypted?: string;
  syncLastAt?: number;
  syncLastError?: string;
  settingsUpdatedAt?: number;
  syncCursor?: number;
}

/** Bring an old file forward. v0 to v1 moves nothing: the onboarding fields
 * simply did not exist, so `DEFAULT_SETTINGS` supplies them. Idempotent. */
function migrate(shape: FileShape): FileShape {
  const version = typeof shape.schemaVersion === 'number' ? shape.schemaVersion : 0;
  if (version >= SETTINGS_SCHEMA_VERSION) return shape;
  return { ...shape, schemaVersion: SETTINGS_SCHEMA_VERSION };
}

function isProvider(value: unknown): value is TranscriptionProvider {
  return TRANSCRIPTION_PROVIDERS.includes(value as never);
}

const SYNC_EMAIL_MAX = 200;

/** Settings that belong to this device, never to the synced blob: which server,
 * who and whether to sync; where this Mac is in onboarding; its login item; and
 * its own agent process. They neither stamp `settingsUpdatedAt` nor sync, so a
 * freshly onboarded Mac never looks newer than the account. sync/engine.ts
 * imports this list. */
export const DEVICE_LOCAL_KEYS: readonly (keyof Settings)[] = [
  'syncEmail',
  'syncEnabled',
  'syncUrl',
  'wizardStep',
  'tourSeen',
  'onboardingComplete',
  'launchAtLogin',
  'agentUrl',
  'agentAutoStart',
];

/** A trimmed http(s) URL within the length cap, or null. */
function cleanUrl(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const url = value.trim();
  if (url.length === 0 || url.length > AGENT_URL_MAX) return null;
  try {
    const parsed = new URL(url);
    return parsed.protocol === 'http:' || parsed.protocol === 'https:' ? url : null;
  } catch {
    return null;
  }
}

/** Keep only fields with valid values. The renderer is untrusted input.
 * `transcriptionProvider` is never taken from a patch: it has its own setter. */
function sanitize(input: Partial<Settings>): Partial<Settings> {
  const out: Partial<Settings> = {};
  if (GESTURE_KEYS.includes(input.gestureKey as never)) out.gestureKey = input.gestureKey;
  if (GESTURE_KEYS.includes(input.editGestureKey as never)) {
    out.editGestureKey = input.editGestureKey;
  }
  if (GESTURE_KEYS.includes(input.explainGestureKey as never)) {
    out.explainGestureKey = input.explainGestureKey;
  }
  if (GESTURE_KEYS.includes(input.actGestureKey as never)) {
    out.actGestureKey = input.actGestureKey;
  }
  const agentUrl = cleanUrl(input.agentUrl);
  if (agentUrl) out.agentUrl = agentUrl;
  const syncUrl = cleanUrl(input.syncUrl);
  if (syncUrl) out.syncUrl = syncUrl;
  if (typeof input.syncEnabled === 'boolean') out.syncEnabled = input.syncEnabled;
  if (typeof input.syncEmail === 'string' && input.syncEmail.length <= SYNC_EMAIL_MAX) {
    out.syncEmail = input.syncEmail.trim();
  }
  if (typeof input.agentAutoStart === 'boolean') out.agentAutoStart = input.agentAutoStart;
  if (input.tapCount === 2 || input.tapCount === 3 || input.tapCount === 4) {
    out.tapCount = input.tapCount;
  }
  if (typeof input.vocabulary === 'string') out.vocabulary = input.vocabulary.slice(0, 2000);
  if (typeof input.tickSound === 'boolean') out.tickSound = input.tickSound;
  if (typeof input.launchAtLogin === 'boolean') out.launchAtLogin = input.launchAtLogin;
  if (typeof input.tourSeen === 'boolean') out.tourSeen = input.tourSeen;
  if (typeof input.onboardingComplete === 'boolean')
    out.onboardingComplete = input.onboardingComplete;
  if (
    typeof input.wizardStep === 'number' &&
    Number.isInteger(input.wizardStep) &&
    input.wizardStep >= 0 &&
    input.wizardStep <= WIZARD_STEP_MAX
  ) {
    out.wizardStep = input.wizardStep;
  }
  return out;
}

export function createSettingsStore(deps: { dir: string; crypto: CryptoLike }): SettingsStore {
  const file = path.join(deps.dir, 'settings.json');

  let state: FileShape = {};
  try {
    state = migrate(JSON.parse(readFileSync(file, 'utf8')) as FileShape);
  } catch {
    // First launch or a corrupted file: defaults are fine.
  }

  const storedProvider = state.settings?.transcriptionProvider;
  let settings: Settings = {
    ...DEFAULT_SETTINGS,
    ...sanitize(state.settings ?? {}),
    transcriptionProvider: isProvider(storedProvider)
      ? storedProvider
      : DEFAULT_SETTINGS.transcriptionProvider,
  };
  let apiKeyEncrypted = typeof state.apiKeyEncrypted === 'string' ? state.apiKeyEncrypted : null;
  let deepgramKeyEncrypted =
    typeof state.deepgramKeyEncrypted === 'string' ? state.deepgramKeyEncrypted : null;
  let rewriteKeyEncrypted =
    typeof state.rewriteKeyEncrypted === 'string' ? state.rewriteKeyEncrypted : null;
  let wordsDictated =
    typeof state.wordsDictated === 'number' && Number.isFinite(state.wordsDictated)
      ? Math.max(0, Math.floor(state.wordsDictated))
      : 0;
  let syncTokenEncrypted =
    typeof state.syncTokenEncrypted === 'string' ? state.syncTokenEncrypted : null;
  const num = (v: unknown) =>
    typeof v === 'number' && Number.isFinite(v) ? Math.max(0, Math.floor(v)) : 0;
  let syncLastAt = num(state.syncLastAt);
  let syncLastError = typeof state.syncLastError === 'string' ? state.syncLastError : '';
  let settingsUpdatedAt = num(state.settingsUpdatedAt);
  let syncCursor = num(state.syncCursor);

  function save() {
    const body: FileShape = {
      settings,
      ...(apiKeyEncrypted ? { apiKeyEncrypted } : {}),
      ...(deepgramKeyEncrypted ? { deepgramKeyEncrypted } : {}),
      ...(rewriteKeyEncrypted ? { rewriteKeyEncrypted } : {}),
      ...(wordsDictated ? { wordsDictated } : {}),
      ...(syncTokenEncrypted ? { syncTokenEncrypted } : {}),
      ...(syncLastAt ? { syncLastAt } : {}),
      ...(syncLastError ? { syncLastError } : {}),
      ...(settingsUpdatedAt ? { settingsUpdatedAt } : {}),
      ...(syncCursor ? { syncCursor } : {}),
      schemaVersion: SETTINGS_SCHEMA_VERSION,
    };
    writeFileSync(file, JSON.stringify(body, null, 2));
  }

  function decrypt(encrypted: string | null): string | null {
    if (!encrypted) return null;
    try {
      return deps.crypto.decryptString(Buffer.from(encrypted, 'base64'));
    } catch {
      return null;
    }
  }

  function encrypt(key: string): string {
    if (!deps.crypto.isEncryptionAvailable()) throw new Error('Encryption is not available');
    return deps.crypto.encryptString(key).toString('base64');
  }

  const hasGroqKey = () => apiKeyEncrypted !== null;
  const hasDeepgramKey = () => deepgramKeyEncrypted !== null;
  const hasApiKey = () =>
    settings.transcriptionProvider === 'deepgram' ? hasDeepgramKey() : hasGroqKey();

  return {
    get: () => settings,
    update(patch) {
      const clean = sanitize(patch);
      // Device-local sync keys never stamp: signing in on a new device must not
      // make its settings look newer than the account's.
      const changed = (Object.keys(clean) as (keyof Settings)[]).some(
        k => !DEVICE_LOCAL_KEYS.includes(k) && clean[k] !== settings[k]
      );
      settings = { ...settings, ...clean };
      if (changed) settingsUpdatedAt = Date.now();
      save();
      return settings;
    },
    applyRemote(patch, updatedAt) {
      const clean = sanitize(patch);
      for (const key of DEVICE_LOCAL_KEYS) delete clean[key];
      // A provider this Mac has no key for would leave it unable to dictate.
      const remote = patch.transcriptionProvider;
      const hasKeyFor = (p: TranscriptionProvider) => (p === 'deepgram' ? hasDeepgramKey() : hasGroqKey());
      if (isProvider(remote) && hasKeyFor(remote)) clean.transcriptionProvider = remote;
      settings = { ...settings, ...clean };
      settingsUpdatedAt = num(updatedAt);
      save();
      return settings;
    },
    view: (live?: AgentSummary) => ({
      ...settings,
      hasApiKey: hasApiKey(),
      hasRewriteKey: rewriteKeyEncrypted !== null,
      wordsDictated,
      hasSyncToken: syncTokenEncrypted !== null,
      syncLastAt,
      syncLastError,
      agent: live ?? OFFLINE_AGENT_SUMMARY,
    }),
    hasApiKey,
    hasGroqKey,
    getApiKey: () => decrypt(apiKeyEncrypted),
    setApiKey(key) {
      apiKeyEncrypted = encrypt(key);
      save();
    },
    hasDeepgramKey,
    getDeepgramKey: () => decrypt(deepgramKeyEncrypted),
    setDeepgramKey(key) {
      deepgramKeyEncrypted = encrypt(key);
      save();
    },
    getTranscriptionKey: provider =>
      decrypt(provider === 'deepgram' ? deepgramKeyEncrypted : apiKeyEncrypted),
    setTranscriptionProvider(provider) {
      if (!isProvider(provider)) throw new Error('Unknown transcription provider');
      // The provider choice syncs; its key never does.
      if (provider !== settings.transcriptionProvider) settingsUpdatedAt = Date.now();
      settings = { ...settings, transcriptionProvider: provider };
      save();
      return settings;
    },
    hasRewriteKey: () => rewriteKeyEncrypted !== null,
    getRewriteKey: () => decrypt(rewriteKeyEncrypted),
    setRewriteKey(key) {
      rewriteKeyEncrypted = encrypt(key);
      save();
    },
    getSyncToken: () => decrypt(syncTokenEncrypted),
    setSyncToken(token) {
      syncTokenEncrypted = token === null ? null : encrypt(token);
      save();
    },
    recordSync(result) {
      syncLastAt = num(result.at);
      syncLastError = result.error ?? '';
      save();
    },
    settingsUpdatedAt: () => settingsUpdatedAt,
    getSyncCursor: () => syncCursor,
    setSyncCursor(value) {
      syncCursor = num(value);
      save();
    },
    recordDictation(text) {
      const words = text.split(/\s+/).filter(Boolean).length;
      if (words === 0) return;
      wordsDictated += words;
      save();
    },
  };
}
