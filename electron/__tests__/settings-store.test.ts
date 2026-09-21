import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

import { beforeEach, describe, expect, it } from 'vitest';

import { createSettingsStore, type CryptoLike } from '../settings-store';
import { DEFAULT_SETTINGS } from '../types';

const crypto: CryptoLike = {
  isEncryptionAvailable: () => true,
  encryptString: (plain) => Buffer.from(`enc(${plain})`),
  decryptString: (encrypted) => encrypted.toString().slice(4, -1),
};

describe('settings store', () => {
  let dir: string;
  beforeEach(() => {
    dir = mkdtempSync(path.join(tmpdir(), 'parley-settings-'));
  });

  it('returns the defaults on first launch', () => {
    const store = createSettingsStore({ dir, crypto });
    expect(store.get()).toEqual(DEFAULT_SETTINGS);
    expect(store.hasApiKey()).toBe(false);
    expect(store.getApiKey()).toBeNull();
  });

  it('persists an update across instances', () => {
    createSettingsStore({ dir, crypto }).update({ tapCount: 2, vocabulary: 'Groq' });
    const reopened = createSettingsStore({ dir, crypto });
    expect(reopened.get()).toEqual({ ...DEFAULT_SETTINGS, tapCount: 2, vocabulary: 'Groq' });
  });

  it('drops invalid values instead of storing them', () => {
    const store = createSettingsStore({ dir, crypto });
    store.update({ tapCount: 9 as never, gestureKey: 'Space' as never, tickSound: false });
    expect(store.get()).toEqual({ ...DEFAULT_SETTINGS, tickSound: false });
  });

  it('round-trips the API key through encryption and never writes it in plain text', () => {
    createSettingsStore({ dir, crypto }).setApiKey('gsk_secret');
    const raw = readFileSync(path.join(dir, 'settings.json'), 'utf8');
    expect(raw).not.toContain('gsk_secret');

    const reopened = createSettingsStore({ dir, crypto });
    expect(reopened.getApiKey()).toBe('gsk_secret');
    expect(reopened.view()).toEqual({ ...DEFAULT_SETTINGS, hasApiKey: true });
  });

  it('refuses to store a key when encryption is unavailable', () => {
    const store = createSettingsStore({
      dir,
      crypto: { ...crypto, isEncryptionAvailable: () => false },
    });
    expect(() => store.setApiKey('gsk_secret')).toThrow('Encryption is not available');
  });

  it('falls back to the defaults when the file is corrupted', () => {
    writeFileSync(path.join(dir, 'settings.json'), '{not json');
    expect(createSettingsStore({ dir, crypto }).get()).toEqual(DEFAULT_SETTINGS);
  });
});
