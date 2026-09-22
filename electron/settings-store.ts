import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

import {
  DEFAULT_SETTINGS,
  GESTURE_KEYS,
  WIZARD_STEP_MAX,
  type Settings,
  type SettingsView,
} from './types';

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
  view(): SettingsView;
  getApiKey(): string | null;
  setApiKey(key: string): void;
  hasApiKey(): boolean;
  getRewriteKey(): string | null;
  setRewriteKey(key: string): void;
  hasRewriteKey(): boolean;
}

interface FileShape {
  settings?: Partial<Settings>;
  apiKeyEncrypted?: string;
  rewriteKeyEncrypted?: string;
  /** Envelope-only: the renderer can neither read nor write this. */
  schemaVersion?: number;
}

/** Bring an old file forward. v0 to v1 moves nothing: the onboarding fields
 * simply did not exist, so `DEFAULT_SETTINGS` supplies them. Idempotent. */
function migrate(shape: FileShape): FileShape {
  const version = typeof shape.schemaVersion === 'number' ? shape.schemaVersion : 0;
  if (version >= SETTINGS_SCHEMA_VERSION) return shape;
  return { ...shape, schemaVersion: SETTINGS_SCHEMA_VERSION };
}

/** Keep only fields with valid values. The renderer is untrusted input. */
function sanitize(input: Partial<Settings>): Partial<Settings> {
  const out: Partial<Settings> = {};
  if (GESTURE_KEYS.includes(input.gestureKey as never)) out.gestureKey = input.gestureKey;
  if (GESTURE_KEYS.includes(input.editGestureKey as never)) {
    out.editGestureKey = input.editGestureKey;
  }
  if (GESTURE_KEYS.includes(input.explainGestureKey as never)) {
    out.explainGestureKey = input.explainGestureKey;
  }
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

  let settings: Settings = { ...DEFAULT_SETTINGS, ...sanitize(state.settings ?? {}) };
  let apiKeyEncrypted = typeof state.apiKeyEncrypted === 'string' ? state.apiKeyEncrypted : null;
  let rewriteKeyEncrypted =
    typeof state.rewriteKeyEncrypted === 'string' ? state.rewriteKeyEncrypted : null;

  function save() {
    const body: FileShape = {
      settings,
      ...(apiKeyEncrypted ? { apiKeyEncrypted } : {}),
      ...(rewriteKeyEncrypted ? { rewriteKeyEncrypted } : {}),
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

  return {
    get: () => settings,
    update(patch) {
      settings = { ...settings, ...sanitize(patch) };
      save();
      return settings;
    },
    view: () => ({
      ...settings,
      hasApiKey: apiKeyEncrypted !== null,
      hasRewriteKey: rewriteKeyEncrypted !== null,
    }),
    hasApiKey: () => apiKeyEncrypted !== null,
    getApiKey: () => decrypt(apiKeyEncrypted),
    setApiKey(key) {
      apiKeyEncrypted = encrypt(key);
      save();
    },
    hasRewriteKey: () => rewriteKeyEncrypted !== null,
    getRewriteKey: () => decrypt(rewriteKeyEncrypted),
    setRewriteKey(key) {
      rewriteKeyEncrypted = encrypt(key);
      save();
    },
  };
}
