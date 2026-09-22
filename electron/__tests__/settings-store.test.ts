import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

import { beforeEach, describe, expect, it } from 'vitest';

import { createSettingsStore, type CryptoLike } from '../settings-store';
import { DEFAULT_SETTINGS } from '../types';

const crypto: CryptoLike = {
  isEncryptionAvailable: () => true,
  encryptString: plain => Buffer.from(`enc(${plain})`),
  decryptString: encrypted => encrypted.toString().slice(4, -1),
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
    expect(reopened.view()).toEqual({
      ...DEFAULT_SETTINGS,
      hasApiKey: true,
      hasRewriteKey: false,
      wordsDictated: 0,
    });
  });

  it('keeps the MiniMax key apart from the Groq key, encrypted the same way', () => {
    const store = createSettingsStore({ dir, crypto });
    store.setApiKey('gsk_secret');
    store.setRewriteKey('mm_secret');
    const raw = readFileSync(path.join(dir, 'settings.json'), 'utf8');
    expect(raw).not.toContain('mm_secret');

    const reopened = createSettingsStore({ dir, crypto });
    expect(reopened.getApiKey()).toBe('gsk_secret');
    expect(reopened.getRewriteKey()).toBe('mm_secret');
    expect(reopened.view().hasRewriteKey).toBe(true);
  });

  it('stores a valid voice edit key and drops an invalid one', () => {
    const store = createSettingsStore({ dir, crypto });
    store.update({ editGestureKey: 'CtrlRight' });
    store.update({ editGestureKey: 'Space' as never });
    expect(store.get().editGestureKey).toBe('CtrlRight');
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

  it('migrates a v0 file forward, keeping settings and keys', () => {
    writeFileSync(
      path.join(dir, 'settings.json'),
      JSON.stringify({
        settings: { tapCount: 2 },
        apiKeyEncrypted: Buffer.from('enc(gsk_old)').toString('base64'),
      })
    );
    const store = createSettingsStore({ dir, crypto });
    expect(store.get()).toEqual({ ...DEFAULT_SETTINGS, tapCount: 2 });
    expect(store.get().tourSeen).toBe(false);
    expect(store.getApiKey()).toBe('gsk_old');

    store.update({ vocabulary: 'MiniMax' });
    const saved = JSON.parse(readFileSync(path.join(dir, 'settings.json'), 'utf8')) as {
      schemaVersion?: number;
    };
    expect(saved.schemaVersion).toBe(1);
  });

  it('round-trips the onboarding fields', () => {
    const store = createSettingsStore({ dir, crypto });
    store.update({ tourSeen: true, wizardStep: 4, onboardingComplete: true });
    expect(createSettingsStore({ dir, crypto }).get()).toEqual({
      ...DEFAULT_SETTINGS,
      tourSeen: true,
      wizardStep: 4,
      onboardingComplete: true,
    });
  });

  it('drops an out-of-range wizard step and non-boolean flags', () => {
    const store = createSettingsStore({ dir, crypto });
    store.update({ wizardStep: 9 as never, tourSeen: 'yes' as never });
    store.update({ wizardStep: -1 as never });
    store.update({ wizardStep: 1.5 as never });
    expect(store.get().wizardStep).toBe(0);
    expect(store.get().tourSeen).toBe(false);
  });

  it('keeps the envelope version out of the renderer’s reach', () => {
    const store = createSettingsStore({ dir, crypto });
    store.update({ schemaVersion: 99 } as never);
    expect((store.get() as unknown as Record<string, unknown>).schemaVersion).toBeUndefined();
    const saved = JSON.parse(readFileSync(path.join(dir, 'settings.json'), 'utf8')) as {
      schemaVersion?: number;
    };
    expect(saved.schemaVersion).toBe(1);
  });

  it('counts dictated words across instances, ignoring empty text', () => {
    const store = createSettingsStore({ dir, crypto });
    store.recordDictation('Hello there, Parley');
    store.recordDictation('   ');
    store.recordDictation('two\nwords');
    expect(store.view().wordsDictated).toBe(5);
    expect(createSettingsStore({ dir, crypto }).view().wordsDictated).toBe(5);
  });

  it('keeps the word count out of the renderer’s reach', () => {
    const store = createSettingsStore({ dir, crypto });
    store.update({ wordsDictated: 9000 } as never);
    expect(store.view().wordsDictated).toBe(0);
    expect(store.get()).not.toHaveProperty('wordsDictated');
  });

  it('treats a corrupt word count as zero', () => {
    writeFileSync(
      path.join(dir, 'settings.json'),
      JSON.stringify({ schemaVersion: 1, wordsDictated: 'lots' })
    );
    expect(createSettingsStore({ dir, crypto }).view().wordsDictated).toBe(0);
  });
});
