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
      agent: {
        online: false,
        managed: false,
        serverState: 'offline',
        message: '',
        currentRun: null,
        mcpServers: [],
      },
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
  describe('transcription provider', () => {
    it('defaults to Groq, so an existing user sees no change', () => {
      const store = createSettingsStore({ dir, crypto });
      store.setApiKey('gsk_secret');
      expect(store.get().transcriptionProvider).toBe('groq');
      expect(store.hasApiKey()).toBe(true);
    });

    it('round-trips the Deepgram key encrypted, apart from the Groq key', () => {
      const store = createSettingsStore({ dir, crypto });
      store.setApiKey('gsk_secret');
      store.setDeepgramKey('dg_secret');
      const raw = readFileSync(path.join(dir, 'settings.json'), 'utf8');
      expect(raw).not.toContain('dg_secret');
      expect(JSON.parse(raw)).toHaveProperty('deepgramKeyEncrypted');

      const reopened = createSettingsStore({ dir, crypto });
      expect(reopened.getDeepgramKey()).toBe('dg_secret');
      expect(reopened.getApiKey()).toBe('gsk_secret');
      expect(reopened.hasDeepgramKey()).toBe(true);
      expect(reopened.getTranscriptionKey('deepgram')).toBe('dg_secret');
      expect(reopened.getTranscriptionKey('groq')).toBe('gsk_secret');
    });

    it('persists the selected provider across instances', () => {
      createSettingsStore({ dir, crypto }).setTranscriptionProvider('deepgram');
      expect(createSettingsStore({ dir, crypto }).get()).toEqual({
        ...DEFAULT_SETTINGS,
        transcriptionProvider: 'deepgram',
      });
    });

    it('means "the selected provider has a key" by hasApiKey', () => {
      const store = createSettingsStore({ dir, crypto });
      store.setApiKey('gsk_secret');
      store.setTranscriptionProvider('deepgram');
      expect(store.hasApiKey()).toBe(false);
      expect(store.view().hasApiKey).toBe(false);
      expect(store.hasGroqKey()).toBe(true);

      store.setDeepgramKey('dg_secret');
      expect(store.hasApiKey()).toBe(true);
      expect(store.view().hasApiKey).toBe(true);

      const groqless = createSettingsStore({
        dir: mkdtempSync(path.join(tmpdir(), 'parley-settings-')),
        crypto,
      });
      groqless.setDeepgramKey('dg_secret');
      expect(groqless.hasApiKey()).toBe(false);
      groqless.setTranscriptionProvider('groq');
      expect(groqless.view().hasApiKey).toBe(false);
    });

    it('refuses to take the provider from a settings patch', () => {
      const store = createSettingsStore({ dir, crypto });
      store.update({ transcriptionProvider: 'deepgram' });
      expect(store.get().transcriptionProvider).toBe('groq');
      store.setTranscriptionProvider('deepgram');
      store.update({ transcriptionProvider: 'groq', tickSound: false });
      expect(store.get()).toMatchObject({ transcriptionProvider: 'deepgram', tickSound: false });
    });

    it('rejects an unknown provider and falls back from a corrupt stored one', () => {
      const store = createSettingsStore({ dir, crypto });
      expect(() => store.setTranscriptionProvider('openai' as never)).toThrow();
      expect(store.get().transcriptionProvider).toBe('groq');

      writeFileSync(
        path.join(dir, 'settings.json'),
        JSON.stringify({ schemaVersion: 1, settings: { transcriptionProvider: 'openai' } })
      );
      expect(createSettingsStore({ dir, crypto }).get().transcriptionProvider).toBe('groq');
    });
  });

  describe('agent settings', () => {
    it('defaults to a managed local agent on Right Shift', () => {
      const store = createSettingsStore({ dir, crypto });
      expect(store.get().agentUrl).toBe('http://localhost:4111');
      expect(store.get().agentAutoStart).toBe(true);
      expect(store.get().actGestureKey).toBe('ShiftRight');
    });

    it('stores a valid agent URL and auto-start across instances', () => {
      const store = createSettingsStore({ dir, crypto });
      store.update({ agentUrl: 'http://127.0.0.1:4222', agentAutoStart: false });
      expect(createSettingsStore({ dir, crypto }).get()).toMatchObject({
        agentUrl: 'http://127.0.0.1:4222',
        agentAutoStart: false,
      });
    });

    it('rejects non-http URLs and overlong URLs instead of storing them', () => {
      const store = createSettingsStore({ dir, crypto });
      store.update({ agentUrl: 'http://127.0.0.1:4222' });
      store.update({ agentUrl: 'ftp://evil/x' });
      store.update({ agentUrl: `http://x/${'y'.repeat(300)}` });
      store.update({ agentUrl: 'not a url' });
      store.update({ agentUrl: 42 as never });
      expect(store.get().agentUrl).toBe('http://127.0.0.1:4222');
    });

    it('drops a non-boolean auto-start instead of storing it', () => {
      const store = createSettingsStore({ dir, crypto });
      store.update({ agentAutoStart: 'yes' as never });
      expect(store.get().agentAutoStart).toBe(true);
    });

    it('stores a valid act key and drops an invalid one', () => {
      const store = createSettingsStore({ dir, crypto });
      store.update({ actGestureKey: 'Shift' });
      store.update({ actGestureKey: 'Space' as never });
      expect(store.get().actGestureKey).toBe('Shift');
    });

    it('falls back to the agent defaults from a corrupt file', () => {
      writeFileSync(
        path.join(dir, 'settings.json'),
        JSON.stringify({
          schemaVersion: 1,
          settings: { actGestureKey: 'Space', agentUrl: 'gopher://x', agentAutoStart: 'yes' },
        })
      );
      const store = createSettingsStore({ dir, crypto });
      expect(store.get()).toMatchObject({
        actGestureKey: 'ShiftRight',
        agentUrl: 'http://localhost:4111',
        agentAutoStart: true,
      });
    });

    it('reports the agent as offline until main hands it live state', () => {
      const store = createSettingsStore({ dir, crypto });
      expect(store.view().agent).toEqual({
        online: false,
        managed: false,
        serverState: 'offline',
        message: '',
        currentRun: null,
        mcpServers: [],
      });
      expect(
        store.view({
          online: true,
          managed: true,
          serverState: 'online',
          message: '',
          currentRun: null,
          mcpServers: [{ name: 'Files', tools: 12 }],
        }).agent.mcpServers
      ).toEqual([{ name: 'Files', tools: 12 }]);
    });
  });
});
