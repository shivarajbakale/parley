import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

import { beforeEach, describe, expect, it } from 'vitest';

import { createSettingsStore, DEVICE_LOCAL_KEYS, type CryptoLike } from '../settings-store';
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
  });

  it('persists an update across instances', () => {
    createSettingsStore({ dir, crypto }).update({ tapCount: 2, vocabulary: 'Groq' });
    const reopened = createSettingsStore({ dir, crypto });
    expect(reopened.get()).toEqual({ ...DEFAULT_SETTINGS, vocabulary: 'Groq' }); // tap count is always 3
  });

  it('drops invalid values instead of storing them', () => {
    const store = createSettingsStore({ dir, crypto });
    store.update({ tapCount: 9 as never, gestureKey: 'Space' as never, tickSound: false });
    expect(store.get()).toEqual({ ...DEFAULT_SETTINGS, tickSound: false });
  });

  it('shows the settings window no provider key: they live in parley-api', () => {
    expect(createSettingsStore({ dir, crypto }).view()).toEqual({
      ...DEFAULT_SETTINGS,
      wordsDictated: 0,
      hasSyncToken: false,
      syncLastAt: 0,
      syncLastError: '',
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
    expect(() => store.setSyncToken('tok_secret')).toThrow('Encryption is not available');
  });

  it('falls back to the defaults when the file is corrupted', () => {
    writeFileSync(path.join(dir, 'settings.json'), '{not json');
    expect(createSettingsStore({ dir, crypto }).get()).toEqual(DEFAULT_SETTINGS);
  });

  it('migrates a v0 file forward, keeping settings and dropping the provider keys', () => {
    writeFileSync(
      path.join(dir, 'settings.json'),
      JSON.stringify({
        settings: { tapCount: 2 },
        apiKeyEncrypted: Buffer.from('enc(gsk_old)').toString('base64'),
      })
    );
    const store = createSettingsStore({ dir, crypto });
    expect(store.get()).toEqual(DEFAULT_SETTINGS);
    expect(store.get().tourSeen).toBe(false);
    const saved = JSON.parse(readFileSync(path.join(dir, 'settings.json'), 'utf8')) as Record<string, unknown>;
    expect(saved.schemaVersion).toBe(2);
    expect(saved).not.toHaveProperty('apiKeyEncrypted');
  });

  it('migrates a v1 file to v2, deleting every stored provider key from disk at once', () => {
    const enc = (plain: string) => Buffer.from(`enc(${plain})`).toString('base64');
    writeFileSync(
      path.join(dir, 'settings.json'),
      JSON.stringify({
        schemaVersion: 1,
        settings: { tapCount: 4, transcriptionProvider: 'deepgram' },
        apiKeyEncrypted: enc('gsk_old'),
        deepgramKeyEncrypted: enc('dg_old'),
        rewriteKeyEncrypted: enc('mm_old'),
        syncTokenEncrypted: enc('tok'),
        wordsDictated: 12,
      })
    );
    const store = createSettingsStore({ dir, crypto });
    const raw = readFileSync(path.join(dir, 'settings.json'), 'utf8');
    const saved = JSON.parse(raw) as Record<string, unknown>;
    expect(saved.schemaVersion).toBe(2);
    for (const field of ['apiKeyEncrypted', 'deepgramKeyEncrypted', 'rewriteKeyEncrypted']) {
      expect(saved).not.toHaveProperty(field);
    }
    expect(store.get()).toMatchObject({ tapCount: 3, transcriptionProvider: 'deepgram' });
    expect(store.getSyncToken()).toBe('tok');
    expect(store.view().wordsDictated).toBe(12);
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
    expect(saved.schemaVersion).toBe(2);
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
      expect(createSettingsStore({ dir, crypto }).get().transcriptionProvider).toBe('groq');
    });

    it('persists the selected provider across instances', () => {
      createSettingsStore({ dir, crypto }).setTranscriptionProvider('deepgram');
      expect(createSettingsStore({ dir, crypto }).get()).toEqual({
        ...DEFAULT_SETTINGS,
        transcriptionProvider: 'deepgram',
      });
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

  it('stores the sync token encrypted and reports it in the view', () => {
    const store = createSettingsStore({ dir, crypto });
    expect(store.view().hasSyncToken).toBe(false);
    store.setSyncToken('tok_1');
    expect(store.getSyncToken()).toBe('tok_1');
    expect(readFileSync(path.join(dir, 'settings.json'), 'utf8')).not.toContain('tok_1');
    expect(createSettingsStore({ dir, crypto }).view().hasSyncToken).toBe(true);
    store.setSyncToken(null);
    expect(store.getSyncToken()).toBeNull();
  });

  it('keeps sync url, email and enabled, and drops a bad url', () => {
    const store = createSettingsStore({ dir, crypto });
    store.update({
      syncUrl: 'https://sync.example.com',
      syncEmail: 'me@example.com',
      syncEnabled: true,
    });
    expect(store.get()).toMatchObject({
      syncUrl: 'https://sync.example.com',
      syncEmail: 'me@example.com',
      syncEnabled: true,
    });
    store.update({ syncUrl: 'ftp://nope' as never });
    expect(store.get().syncUrl).toBe('https://sync.example.com');
  });

  it('records the last sync outcome outside any patch', () => {
    const store = createSettingsStore({ dir, crypto });
    store.recordSync({ at: 1234, error: 'offline' });
    const view = createSettingsStore({ dir, crypto }).view();
    expect(view.syncLastAt).toBe(1234);
    expect(view.syncLastError).toBe('offline');
    store.update({ syncLastAt: 9 } as never);
    expect(store.view().syncLastAt).toBe(1234);
  });

  it('stamps settingsUpdatedAt on a real change and persists the sync cursor', () => {
    const store = createSettingsStore({ dir, crypto });
    expect(store.settingsUpdatedAt()).toBe(0);
    const before = Date.now();
    store.update({ tickSound: false });
    expect(store.settingsUpdatedAt()).toBeGreaterThanOrEqual(before);
    store.setSyncCursor(5);
    expect(createSettingsStore({ dir, crypto }).getSyncCursor()).toBe(5);
  });

  it('device-local sync keys never move settingsUpdatedAt; a mixed patch still stamps', () => {
    const store = createSettingsStore({ dir, crypto });
    store.update({ syncEmail: 'a@b.co', syncEnabled: true, syncUrl: 'https://sync.example.com' });
    expect(store.settingsUpdatedAt()).toBe(0);
    expect(store.get().syncEmail).toBe('a@b.co');
    store.update({ syncEmail: 'c@d.co', tickSound: false });
    expect(store.settingsUpdatedAt()).toBeGreaterThan(0);
  });

  it('applies a remote patch under the remote stamp, sanitized like update', () => {
    const store = createSettingsStore({ dir, crypto });
    store.applyRemote({ tickSound: false, tapCount: 9 as never }, 100);
    expect(store.settingsUpdatedAt()).toBe(100);
    expect(store.get()).toEqual({ ...DEFAULT_SETTINGS, tickSound: false });
    expect(createSettingsStore({ dir, crypto }).settingsUpdatedAt()).toBe(100);
  });
  it('onboarding, login-item and agent settings are device-local: no stamp, no remote apply', () => {
    expect([...DEVICE_LOCAL_KEYS].sort()).toEqual(
      [
        'agentAutoStart', 'agentUrl', 'launchAtLogin', 'onboardingComplete', 'syncEmail', 'syncEnabled',
        'syncUrl', 'tourSeen', 'wizardStep',
      ].sort()
    );
    const store = createSettingsStore({ dir, crypto });
    store.update({
      wizardStep: 3,
      tourSeen: true,
      onboardingComplete: true,
      launchAtLogin: true,
      agentUrl: 'http://127.0.0.1:9999',
      agentAutoStart: false,
    });
    expect(store.settingsUpdatedAt()).toBe(0);
    expect(store.get()).toMatchObject({ wizardStep: 3, tourSeen: true, agentUrl: 'http://127.0.0.1:9999' });
    store.applyRemote(
      { agentUrl: 'https://evil.example.com', agentAutoStart: true, syncUrl: 'https://other.example.com', tickSound: false },
      100
    );
    expect(store.get()).toMatchObject({
      agentUrl: 'http://127.0.0.1:9999',
      agentAutoStart: false,
      syncUrl: DEFAULT_SETTINGS.syncUrl,
      tickSound: false,
    });
  });

  it('a provider change stamps settingsUpdatedAt, so it syncs', () => {
    const store = createSettingsStore({ dir, crypto });
    store.setTranscriptionProvider('deepgram');
    expect(store.settingsUpdatedAt()).toBeGreaterThan(0);
  });

  it('takes a remote provider: the server, not this device, decides whether it has the key', () => {
    const store = createSettingsStore({ dir, crypto });
    store.applyRemote({ transcriptionProvider: 'deepgram' }, 200);
    expect(store.get().transcriptionProvider).toBe('deepgram');
    expect(createSettingsStore({ dir, crypto }).get().transcriptionProvider).toBe('deepgram');
  });
});
