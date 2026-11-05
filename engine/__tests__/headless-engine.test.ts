import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { createDictionaryStore } from '../dictionary-store';
import { HOLD_MIN_MS } from '../gesture-detector';
import { AUDIO_WATCHDOG_MS, createEngine, isLocalhostUrl, type EngineDeps } from '../headless/engine';
import { PROTOCOL_VERSION } from '../headless/rpc';
import { createKeyedCrypto } from '../headless/secret';
import { DONE_MS, FADE_MS } from '../session';
import { createSettingsStore } from '../settings-store';
import { DEFAULT_SETTINGS, type Settings } from '../types';
import { uploadName } from '../transcribers/groq';

const GRANTED = { microphone: true, accessibility: true };
const KEY = Buffer.alloc(32, 7).toString('base64');

type Call = { method: string; params?: Record<string, unknown> };

/** A text field as the shell's Accessibility read reports it. */
function field(value: string, extra: Record<string, unknown> = {}) {
  return {
    editable: true,
    valueKnown: true,
    value,
    valueOffset: 0,
    valueLength: value.length,
    caret: { location: value.length, length: 0 },
    bundleId: 'com.apple.TextEdit',
    selectedText: '',
    secure: false,
    selectionBounds: null,
    frontWindowBounds: null,
    ...extra,
  };
}

let dir: string;

function setup(
  overrides: Partial<EngineDeps> = {},
  settings: Partial<Settings> = {},
  shell: Record<string, (params?: Record<string, unknown>) => unknown> = {}
) {
  const notes: Call[] = [];
  const requests: Call[] = [];
  const crypto = createKeyedCrypto();
  const store = createSettingsStore({ dir, crypto });
  if (Object.keys(settings).length) store.update(settings);
  const dictionary = createDictionaryStore({ dir });
  const answers: Record<string, (params?: Record<string, unknown>) => unknown> = {
    'paste.text': () => ({ ok: true }),
    'ax.focusedField': () => ({ error: 'no_focus' }),
    'ax.select': () => ({ selected: true }),
    'inject.copyAll': () => ({ text: '' }),
    'inject.copySelection': () => ({ text: '' }),
    'inject.erase': () => ({ ok: true }),
    ...shell,
  };
  const deps: EngineDeps = {
    rpc: {
      notify: (method, params) => notes.push({ method, params }),
      request: vi.fn(async (method: string, params?: Record<string, unknown>) => {
        requests.push({ method, params });
        const answer = answers[method];
        if (!answer) throw new Error(`no fake for ${method}`);
        return answer(params);
      }) as EngineDeps['rpc']['request'],
    },
    store,
    dictionary,
    transcriber: { transcribe: vi.fn().mockResolvedValue('hello world') },
    rewriter: { rewrite: vi.fn().mockResolvedValue('Hi.') },
    explainClient: {
      stream: vi.fn(async (_input, onEvent) => {
        onEvent({ kind: 'delta', text: 'It means hello.' });
        onEvent({ kind: 'done', sources: [] });
      }) as unknown as EngineDeps['explainClient']['stream'],
    },
    crypto,
    takeAudio: vi.fn().mockResolvedValue(new ArrayBuffer(16)),
    engineVersion: 'test',
    fetchServerStatus: vi.fn().mockResolvedValue({ reachable: true, url: 'x', keys: null }),
    ...overrides,
  };
  const engine = createEngine(deps);
  const phases = () => notes.filter((n) => n.method === 'hud.phase').map((n) => n.params?.phase);
  const calls = (method: string) => requests.filter((r) => r.method === method);
  const hello = (extra: Record<string, unknown> = {}) =>
    engine.onRequest('hello', { protocolVersion: PROTOCOL_VERSION, permissions: GRANTED, secretKey: KEY, ...extra });
  return { engine, deps, notes, requests, phases, calls, hello, store, dictionary, crypto };
}

/** Tap-tap-hold, as the shell forwards it; returns the release. */
function gesture(engine: ReturnType<typeof createEngine>, key: string) {
  let t = 1000;
  const send = (type: 'down' | 'up') => engine.onNotify('key', { type, key, time: t });
  send('down');
  t += 60;
  send('up');
  t += 80;
  send('down');
  t += 60;
  send('up');
  t += 80;
  send('down');
  t += HOLD_MIN_MS + 50;
  vi.advanceTimersByTime(HOLD_MIN_MS + 50);
  return () => {
    t += 1500;
    send('up');
  };
}

const take = { path: '/tmp/take.m4a', mimeType: 'audio/mp4', durationMs: 1500 };

beforeEach(() => {
  dir = mkdtempSync(path.join(tmpdir(), 'parley-engine-'));
  vi.useFakeTimers();
});

afterEach(() => {
  vi.useRealTimers();
  rmSync(dir, { recursive: true, force: true });
});

describe('headless engine: handshake', () => {
  it('hello answers with the protocol, engine version and the live settings view', async () => {
    const { hello } = setup();
    const reply = await hello();
    expect(reply).toMatchObject({
      protocolVersion: PROTOCOL_VERSION,
      engineVersion: 'test',
      settings: { gestureKey: DEFAULT_SETTINGS.gestureKey, hasSyncToken: false, agent: { online: false } },
    });
  });

  it('hello refuses a shell that speaks another protocol version', async () => {
    const { engine } = setup();
    await expect(engine.onRequest('hello', { protocolVersion: 1 })).rejects.toThrow('Protocol mismatch');
  });

  it('hello hands the Keychain key to the token crypto', async () => {
    const { hello, crypto } = setup();
    expect(crypto.isEncryptionAvailable()).toBe(false);
    await hello();
    expect(crypto.isEncryptionAvailable()).toBe(true);
    expect(crypto.decryptString(crypto.encryptString('token-1'))).toBe('token-1');
  });

  it('refuses unknown requests', async () => {
    const { engine } = setup();
    await expect(engine.onRequest('nope', undefined)).rejects.toThrow('Unknown method nope');
  });

  it('hello reports launch at login once, and again only when it changes', async () => {
    const { hello, engine, notes } = setup();
    await hello();
    await engine.onRequest('settings.update', { patch: { tickSound: false } });
    await engine.onRequest('settings.update', { patch: { launchAtLogin: false } });
    expect(notes.filter((n) => n.method === 'app.launchAtLogin').map((n) => n.params?.enabled)).toEqual([true, false]);
  });
});

describe('headless engine: dictation', () => {
  it('gesture, listening, recording, transcribed, pasted, done', async () => {
    const { engine, deps, notes, calls, phases, hello, store } = setup();
    await hello();

    const release = gesture(engine, DEFAULT_SETTINGS.gestureKey);
    expect(notes.some((n) => n.method === 'hud.show')).toBe(true);
    expect(phases()).toEqual(['listening']);

    release();
    expect(phases()).toEqual(['listening', 'transcribing']);

    engine.onNotify('audio.ready', take);
    await vi.waitFor(() => expect(calls('paste.text')).toHaveLength(1));
    expect(deps.takeAudio).toHaveBeenCalledWith('/tmp/take.m4a');
    expect(calls('paste.text')[0].params).toEqual({ text: 'hello world', selectAll: false });

    await vi.waitFor(() => expect(phases()).toContain('done'));
    expect(store.view().wordsDictated).toBe(2);
    expect(notes).toContainEqual({ method: 'transcript', params: { text: 'hello world' } });

    vi.advanceTimersByTime(DONE_MS + FADE_MS);
    expect(notes.filter((n) => n.method === 'hud.hide')).toHaveLength(1);
    expect(engine.session.state()).toBe('idle');
  });

  it('without permissions the gesture is refused and the shell told why', () => {
    const { engine, notes } = setup();
    gesture(engine, DEFAULT_SETTINGS.gestureKey);
    expect(notes).toContainEqual({ method: 'session.blocked', params: { reason: 'microphone' } });
    expect(notes.some((n) => n.method === 'ui.openSettings')).toBe(true);
    expect(engine.session.state()).toBe('idle');
  });

  it('permissions.changed unblocks the next gesture', () => {
    const { engine, phases } = setup();
    engine.onNotify('permissions.changed', GRANTED);
    gesture(engine, DEFAULT_SETTINGS.gestureKey);
    expect(phases()).toEqual(['listening']);
  });

  it('Escape while listening cancels', async () => {
    const { engine, phases, hello } = setup();
    await hello();
    gesture(engine, DEFAULT_SETTINGS.gestureKey);
    engine.onNotify('key', { type: 'down', key: 'Escape', time: 9999 });
    expect(phases()).toEqual(['listening', 'cancelled']);
  });

  it('a recording that never arrives is recovered by the watchdog', async () => {
    const { engine, phases, calls, hello } = setup();
    await hello();
    gesture(engine, DEFAULT_SETTINGS.gestureKey)();
    vi.advanceTimersByTime(AUDIO_WATCHDOG_MS + 1);
    await vi.waitFor(() => expect(phases()).toContain('cancelled'));
    expect(calls('paste.text')).toEqual([]);
  });

  it('an unreadable recording ends as cancelled, nothing pasted', async () => {
    const { engine, phases, calls, hello } = setup({ takeAudio: vi.fn().mockRejectedValue(new Error('ENOENT')) });
    await hello();
    gesture(engine, DEFAULT_SETTINGS.gestureKey)();
    engine.onNotify('audio.ready', take);
    await vi.waitFor(() => expect(phases()).toContain('cancelled'));
    expect(calls('paste.text')).toEqual([]);
  });

  it('an empty audio.ready ends as cancelled without touching the disk', async () => {
    const { engine, deps, phases, hello } = setup();
    await hello();
    gesture(engine, DEFAULT_SETTINGS.gestureKey)();
    engine.onNotify('audio.ready', { path: '', mimeType: 'audio/mp4', durationMs: 0 });
    await vi.waitFor(() => expect(phases()).toContain('cancelled'));
    expect(deps.takeAudio).not.toHaveBeenCalled();
  });

  it('a failed paste paints the error on the pill', async () => {
    const { engine, phases, notes, hello } = setup({}, {}, {
      'paste.text': () => {
        throw new Error('No focused field');
      },
    });
    await hello();
    gesture(engine, DEFAULT_SETTINGS.gestureKey)();
    engine.onNotify('audio.ready', take);
    await vi.waitFor(() => expect(phases()).toContain('error'));
    expect(notes.find((n) => n.params?.phase === 'error')?.params?.message).toBe('No focused field');
  });

  it('malformed key events are dropped', () => {
    const { engine, notes } = setup();
    engine.onNotify('key', { type: 'sideways', key: 'AltRight', time: 1 });
    engine.onNotify('key', undefined);
    expect(notes).toEqual([]);
  });

  it('the dictionary fixes the spelling before the paste', async () => {
    const { engine, calls, hello, dictionary, deps } = setup();
    (deps.transcriber.transcribe as ReturnType<typeof vi.fn>).mockResolvedValue('ask master about it');
    dictionary.upsert({ word: 'Mastra', soundsLike: ['master'] });
    await hello();
    gesture(engine, DEFAULT_SETTINGS.gestureKey)();
    engine.onNotify('audio.ready', take);
    await vi.waitFor(() => expect(calls('paste.text')).toHaveLength(1));
    expect(calls('paste.text')[0].params?.text).toBe('ask Mastra about it');
  });
});

describe('headless engine: voice edit', () => {
  it('reads the focused field, rewrites it through the server and pastes over it', async () => {
    const { engine, deps, calls, phases, hello } = setup({}, {}, {
      'ax.focusedField': () => field('Hello there, how are you doing today?'),
    });
    (deps.transcriber.transcribe as ReturnType<typeof vi.fn>).mockResolvedValue('make it shorter');
    await hello();
    gesture(engine, DEFAULT_SETTINGS.editGestureKey)();
    engine.onNotify('audio.ready', take);
    await vi.waitFor(() => expect(phases()).toContain('done'));
    expect(deps.rewriter.rewrite).toHaveBeenCalledWith('Hello there, how are you doing today?', 'make it shorter');
    expect(calls('paste.text').at(-1)?.params).toEqual({ text: 'Hi.', selectAll: true });
  });

  it('is off while its key is the dictation key', async () => {
    const { engine, phases, hello } = setup({}, { editGestureKey: 'AltRight' });
    await hello();
    gesture(engine, 'MetaRight');
    expect(phases()).toEqual([]);
  });

  it('a new edit key from the settings window takes effect at once', async () => {
    const { engine, phases, hello } = setup();
    await hello();
    await engine.onRequest('settings.update', { patch: { editGestureKey: 'Meta' } });
    gesture(engine, 'Meta');
    expect(phases()).toEqual(['listening']);
  });
});

describe('headless engine: Explain', () => {
  it('answers about the selection in the popover', async () => {
    const { engine, notes, hello, phases } = setup({}, {}, {
      'ax.focusedField': () => field('a b c', { selectedText: 'idempotent', selectionBounds: { x: 10, y: 20, width: 80, height: 16 } }),
    });
    await hello();
    gesture(engine, DEFAULT_SETTINGS.explainGestureKey)();
    engine.onNotify('audio.ready', { path: '', mimeType: 'audio/mp4', durationMs: 0 });
    await vi.waitFor(() => expect(notes.some((n) => n.method === 'explain.show')).toBe(true));
    const shown = notes.find((n) => n.method === 'explain.show')!.params!;
    expect(shown.anchor).toEqual({ x: 10, y: 20, width: 80, height: 16 });
    expect(phases()).toContain('done');
    engine.onNotify('explain.dismiss', undefined);
    expect(notes.some((n) => n.method === 'explain.hide')).toBe(true);
  });
});

describe('headless engine: Act', () => {
  it('without an agent the gesture is refused as "agent"', async () => {
    const { engine, notes, hello } = setup();
    await hello();
    gesture(engine, DEFAULT_SETTINGS.actGestureKey);
    expect(notes).toContainEqual({ method: 'session.blocked', params: { reason: 'agent' } });
  });

  it('agent.status says there is no agent in this build', async () => {
    const { engine } = setup();
    expect(await engine.onRequest('agent.status', undefined)).toMatchObject({ online: false, message: 'No agent in this build' });
  });

  it('treats only loopback URLs as managed', () => {
    expect(isLocalhostUrl('http://localhost:4111')).toBe(true);
    expect(isLocalhostUrl('http://127.0.0.1:4111')).toBe(true);
    expect(isLocalhostUrl('https://agent.example.com')).toBe(false);
    expect(isLocalhostUrl('not a url')).toBe(false);
  });
});

describe('headless engine: settings and dictionary', () => {
  it('settings.update persists and returns the view', async () => {
    const { engine, store } = setup();
    const view = await engine.onRequest('settings.update', { patch: { tapCount: 2, tickSound: false } });
    expect(view).toMatchObject({ tapCount: 2, tickSound: false });
    expect(store.get().tapCount).toBe(2);
  });

  it('settings.setProvider switches the transcriber and ignores unknown names', async () => {
    const { engine, store } = setup();
    await engine.onRequest('settings.setProvider', { provider: 'deepgram' });
    expect(store.get().transcriptionProvider).toBe('deepgram');
    await engine.onRequest('settings.setProvider', { provider: 'whisper-9000' });
    expect(store.get().transcriptionProvider).toBe('deepgram');
  });

  it('dictionary add, list and remove', async () => {
    const { engine } = setup();
    const { entry } = (await engine.onRequest('dictionary.upsert', { word: 'Tailscale', soundsLike: ['tail scale'] })) as {
      entry: { id: string; word: string };
    };
    expect(entry.word).toBe('Tailscale');
    expect(((await engine.onRequest('dictionary.list', undefined)) as { entries: unknown[] }).entries).toHaveLength(1);
    await engine.onRequest('dictionary.remove', { id: entry.id });
    expect(((await engine.onRequest('dictionary.list', undefined)) as { entries: unknown[] }).entries).toHaveLength(0);
  });

  it('dictionary.upsert refuses an empty word', async () => {
    const { engine } = setup();
    await expect(engine.onRequest('dictionary.upsert', { word: '' })).rejects.toThrow('A word is required');
  });

  it('server.status asks the configured server', async () => {
    const { engine, deps } = setup({}, { syncUrl: 'http://127.0.0.1:3100' });
    await engine.onRequest('server.status', undefined);
    expect(deps.fetchServerStatus).toHaveBeenCalledWith('http://127.0.0.1:3100');
  });
});

describe('headless engine: sync', () => {
  it('sign-in stores the token encrypted with the Keychain key, and sign-out forgets it', async () => {
    const signIn = vi.fn().mockResolvedValue({ token: 'tok-123' });
    const client = {
      signIn,
      pull: vi.fn().mockResolvedValue({ rows: [], now: 1, hasMore: false }),
      push: vi.fn().mockResolvedValue({ accepted: 0 }),
    };
    const { engine, hello, store } = setup({ createSyncClient: () => client as never });
    await hello();
    const result = (await engine.onRequest('sync.signIn', { email: 'me@example.com' })) as { message: string };
    expect(signIn).toHaveBeenCalledWith('me@example.com');
    expect(store.getSyncToken()).toBe('tok-123');
    expect(store.get().syncEnabled).toBe(true);
    expect(result.message).toBeTruthy();
    await engine.onRequest('sync.signOut', undefined);
    expect(store.getSyncToken()).toBeNull();
    expect(store.get().syncEnabled).toBe(false);
  });

  it('sign-in without the Keychain key refuses instead of storing a plaintext token', async () => {
    const { engine } = setup();
    expect(await engine.onRequest('sync.signIn', { email: 'me@example.com' })).toEqual({
      ok: false,
      message: 'The Keychain key is not available',
    });
  });

  it('sign-in rejects a malformed email', async () => {
    const { engine, hello } = setup();
    await hello();
    expect(await engine.onRequest('sync.signIn', { email: 'nope' })).toEqual({ ok: false, message: 'Enter an email address' });
  });
});

describe('keyed crypto', () => {
  it('refuses an Electron safeStorage blob instead of misreading it', () => {
    const crypto = createKeyedCrypto();
    crypto.setKey(Buffer.alloc(32, 1));
    expect(() => crypto.decryptString(Buffer.from('v10somethingelse'))).toThrow();
  });

  it('a different key cannot read the token', () => {
    const a = createKeyedCrypto();
    a.setKey(Buffer.alloc(32, 1));
    const b = createKeyedCrypto();
    b.setKey(Buffer.alloc(32, 2));
    expect(() => b.decryptString(a.encryptString('secret'))).toThrow();
  });
});

describe('groq upload name', () => {
  it('names the file after what was recorded', () => {
    expect(uploadName('audio/webm;codecs=opus')).toBe('speech.webm');
    expect(uploadName('audio/mp4')).toBe('speech.m4a');
    expect(uploadName('audio/x-m4a')).toBe('speech.m4a');
    expect(uploadName('audio/wav')).toBe('speech.wav');
    expect(uploadName('application/octet-stream')).toBe('speech.webm');
  });
});
