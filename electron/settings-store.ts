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
  if (typeof input.agentUrl === 'string') {
    const url = input.agentUrl.trim();
    if (url.length > 0 && url.length <= AGENT_URL_MAX) {
      try {
        const parsed = new URL(url);
        if (parsed.protocol === 'http:' || parsed.protocol === 'https:') out.agentUrl = url;
      } catch {
        // Not a URL at all: dropped below.
      }
    }
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

  function save() {
    const body: FileShape = {
      settings,
      ...(apiKeyEncrypted ? { apiKeyEncrypted } : {}),
      ...(deepgramKeyEncrypted ? { deepgramKeyEncrypted } : {}),
      ...(rewriteKeyEncrypted ? { rewriteKeyEncrypted } : {}),
      ...(wordsDictated ? { wordsDictated } : {}),
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
      settings = { ...settings, ...sanitize(patch) };
      save();
      return settings;
    },
    view: (live?: AgentSummary) => ({
      ...settings,
      hasApiKey: hasApiKey(),
      hasRewriteKey: rewriteKeyEncrypted !== null,
      wordsDictated,
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
    recordDictation(text) {
      const words = text.split(/\s+/).filter(Boolean).length;
      if (words === 0) return;
      wordsDictated += words;
      save();
    },
  };
}
