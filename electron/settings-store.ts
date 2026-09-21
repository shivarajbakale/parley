import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

import { DEFAULT_SETTINGS, GESTURE_KEYS, type Settings, type SettingsView } from './types';

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
}

interface FileShape {
  settings?: Partial<Settings>;
  apiKeyEncrypted?: string;
}

/** Keep only fields with valid values. The renderer is untrusted input. */
function sanitize(input: Partial<Settings>): Partial<Settings> {
  const out: Partial<Settings> = {};
  if (GESTURE_KEYS.includes(input.gestureKey as never)) out.gestureKey = input.gestureKey;
  if (input.tapCount === 2 || input.tapCount === 3 || input.tapCount === 4) {
    out.tapCount = input.tapCount;
  }
  if (typeof input.vocabulary === 'string') out.vocabulary = input.vocabulary.slice(0, 2000);
  if (typeof input.tickSound === 'boolean') out.tickSound = input.tickSound;
  if (typeof input.launchAtLogin === 'boolean') out.launchAtLogin = input.launchAtLogin;
  return out;
}

export function createSettingsStore(deps: { dir: string; crypto: CryptoLike }): SettingsStore {
  const file = path.join(deps.dir, 'settings.json');

  let state: FileShape = {};
  try {
    state = JSON.parse(readFileSync(file, 'utf8')) as FileShape;
  } catch {
    // First launch or a corrupted file: defaults are fine.
  }

  let settings: Settings = { ...DEFAULT_SETTINGS, ...sanitize(state.settings ?? {}) };
  let apiKeyEncrypted = typeof state.apiKeyEncrypted === 'string' ? state.apiKeyEncrypted : null;

  function save() {
    const body: FileShape = { settings, ...(apiKeyEncrypted ? { apiKeyEncrypted } : {}) };
    writeFileSync(file, JSON.stringify(body, null, 2));
  }

  return {
    get: () => settings,
    update(patch) {
      settings = { ...settings, ...sanitize(patch) };
      save();
      return settings;
    },
    view: () => ({ ...settings, hasApiKey: apiKeyEncrypted !== null }),
    hasApiKey: () => apiKeyEncrypted !== null,
    getApiKey() {
      if (!apiKeyEncrypted) return null;
      try {
        return deps.crypto.decryptString(Buffer.from(apiKeyEncrypted, 'base64'));
      } catch {
        return null;
      }
    },
    setApiKey(key) {
      if (!deps.crypto.isEncryptionAvailable()) throw new Error('Encryption is not available');
      apiKeyEncrypted = deps.crypto.encryptString(key).toString('base64');
      save();
    },
  };
}
