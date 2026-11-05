import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { HOLD_MIN_MS } from '../gesture-detector';
import { AUDIO_WATCHDOG_MS, createEngine, type EngineDeps } from '../headless/engine';
import { PROTOCOL_VERSION } from '../headless/rpc';
import { DONE_MS, FADE_MS } from '../session';
import { DEFAULT_SETTINGS, type Settings } from '../types';
import { uploadName } from '../transcribers/groq';

const GRANTED = { microphone: true, accessibility: true };

function setup(overrides: Partial<EngineDeps> = {}, settings: Partial<Settings> = {}) {
  const notes: { method: string; params?: Record<string, unknown> }[] = [];
  const requests: { method: string; params?: Record<string, unknown> }[] = [];
  const deps: EngineDeps = {
    rpc: {
      notify: (method, params) => notes.push({ method, params }),
      request: vi.fn(async (method: string, params?: Record<string, unknown>) => {
        requests.push({ method, params });
        return { ok: true };
      }) as EngineDeps['rpc']['request'],
    },
    store: {
      get: () => ({ ...DEFAULT_SETTINGS, ...settings }),
      recordDictation: vi.fn(),
    },
    dictionary: { list: () => [], recordUses: vi.fn() },
    transcriber: { transcribe: vi.fn().mockResolvedValue('hello world') },
    takeAudio: vi.fn().mockResolvedValue(new ArrayBuffer(16)),
    engineVersion: 'test',
    ...overrides,
  };
  const engine = createEngine(deps);
  const phases = () => notes.filter((n) => n.method === 'hud.phase').map((n) => n.params?.phase);
  return { engine, deps, notes, requests, phases };
}

/** Tap-tap-hold on the dictation key, as the shell forwards it. */
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

beforeEach(() => {
  vi.useFakeTimers();
});

afterEach(() => {
  vi.useRealTimers();
});

describe('headless engine', () => {
  it('hello answers with the protocol, engine version and the settings the shell needs', async () => {
    const { engine } = setup();
    const reply = await engine.onRequest('hello', { protocolVersion: PROTOCOL_VERSION, permissions: GRANTED });
    expect(reply).toMatchObject({
      protocolVersion: PROTOCOL_VERSION,
      engineVersion: 'test',
      settings: { gestureKey: DEFAULT_SETTINGS.gestureKey, tapCount: DEFAULT_SETTINGS.tapCount },
    });
  });

  it('hello refuses a shell that speaks another protocol version', async () => {
    const { engine } = setup();
    await expect(engine.onRequest('hello', { protocolVersion: 99 })).rejects.toThrow('Protocol mismatch');
  });

  it('refuses unknown requests', async () => {
    const { engine } = setup();
    await expect(engine.onRequest('nope', undefined)).rejects.toThrow('Unknown method nope');
  });

  it('a full dictation: gesture, listening, recording, transcribed, pasted, done', async () => {
    const { engine, deps, notes, requests, phases } = setup();
    await engine.onRequest('hello', { protocolVersion: PROTOCOL_VERSION, permissions: GRANTED });

    const release = gesture(engine, DEFAULT_SETTINGS.gestureKey);
    expect(notes.some((n) => n.method === 'hud.show')).toBe(true);
    expect(phases()).toEqual(['listening']);

    release();
    expect(phases()).toEqual(['listening', 'transcribing']);

    engine.onNotify('audio.ready', { path: '/tmp/take.m4a', mimeType: 'audio/mp4', durationMs: 1500 });
    await vi.waitFor(() => expect(requests).toHaveLength(1));
    expect(deps.takeAudio).toHaveBeenCalledWith('/tmp/take.m4a');
    expect(deps.transcriber.transcribe).toHaveBeenCalledWith(
      expect.objectContaining({ mimeType: 'audio/mp4' }),
      expect.any(Object)
    );
    expect(requests[0]).toEqual({ method: 'paste.text', params: { text: 'hello world' } });

    await vi.waitFor(() => expect(phases()).toContain('done'));
    expect(deps.store.recordDictation).toHaveBeenCalledWith('hello world');
    expect(notes).toContainEqual({ method: 'transcript', params: { text: 'hello world' } });

    vi.advanceTimersByTime(DONE_MS + FADE_MS);
    expect(notes.at(-1)?.method).toBe('hud.hide');
    expect(engine.session.state()).toBe('idle');
  });

  it('without permissions from the shell, the gesture is refused and the shell told why', () => {
    const { engine, notes } = setup();
    gesture(engine, DEFAULT_SETTINGS.gestureKey);
    expect(notes).toContainEqual({ method: 'session.blocked', params: { reason: 'microphone' } });
    expect(notes).toContainEqual({ method: 'ui.openSettings', params: undefined });
    expect(engine.session.state()).toBe('idle');
  });

  it('permissions.changed unblocks the next gesture', () => {
    const { engine, phases } = setup();
    engine.onNotify('permissions.changed', GRANTED);
    gesture(engine, DEFAULT_SETTINGS.gestureKey);
    expect(phases()).toEqual(['listening']);
  });

  it('a gesture on another key does nothing in this build', async () => {
    const { engine, phases } = setup();
    await engine.onRequest('hello', { protocolVersion: PROTOCOL_VERSION, permissions: GRANTED });
    gesture(engine, DEFAULT_SETTINGS.editGestureKey);
    expect(phases()).toEqual([]);
  });

  it('Escape while listening cancels', async () => {
    const { engine, phases } = setup();
    await engine.onRequest('hello', { protocolVersion: PROTOCOL_VERSION, permissions: GRANTED });
    gesture(engine, DEFAULT_SETTINGS.gestureKey);
    engine.onNotify('key', { type: 'down', key: 'Escape', time: 9999 });
    expect(phases()).toEqual(['listening', 'cancelled']);
  });

  it('a recording that never arrives is recovered by the watchdog', async () => {
    const { engine, phases, requests } = setup();
    await engine.onRequest('hello', { protocolVersion: PROTOCOL_VERSION, permissions: GRANTED });
    gesture(engine, DEFAULT_SETTINGS.gestureKey)();
    vi.advanceTimersByTime(AUDIO_WATCHDOG_MS + 1);
    await vi.waitFor(() => expect(phases()).toContain('cancelled'));
    expect(requests).toEqual([]);
  });

  it('an unreadable recording ends as cancelled, nothing pasted', async () => {
    const { engine, phases, requests } = setup({
      takeAudio: vi.fn().mockRejectedValue(new Error('ENOENT')),
    });
    await engine.onRequest('hello', { protocolVersion: PROTOCOL_VERSION, permissions: GRANTED });
    gesture(engine, DEFAULT_SETTINGS.gestureKey)();
    engine.onNotify('audio.ready', { path: '/tmp/gone.m4a', mimeType: 'audio/mp4', durationMs: 1500 });
    await vi.waitFor(() => expect(phases()).toContain('cancelled'));
    expect(requests).toEqual([]);
  });

  it('an empty audio.ready (recording failed) ends as cancelled without touching the disk', async () => {
    const { engine, deps, phases, requests } = setup();
    await engine.onRequest('hello', { protocolVersion: PROTOCOL_VERSION, permissions: GRANTED });
    gesture(engine, DEFAULT_SETTINGS.gestureKey)();
    engine.onNotify('audio.ready', { path: '', mimeType: 'audio/mp4', durationMs: 0 });
    await vi.waitFor(() => expect(phases()).toContain('cancelled'));
    expect(deps.takeAudio).not.toHaveBeenCalled();
    expect(requests).toEqual([]);
  });

  it('a failed paste paints the error on the pill', async () => {
    const { engine, deps, phases, notes } = setup();
    (deps.rpc.request as ReturnType<typeof vi.fn>).mockRejectedValueOnce(new Error('No focused field'));
    await engine.onRequest('hello', { protocolVersion: PROTOCOL_VERSION, permissions: GRANTED });
    gesture(engine, DEFAULT_SETTINGS.gestureKey)();
    engine.onNotify('audio.ready', { path: '/tmp/take.m4a', mimeType: 'audio/mp4', durationMs: 1500 });
    await vi.waitFor(() => expect(phases()).toContain('error'));
    expect(notes.find((n) => n.params?.phase === 'error')?.params?.message).toBe('No focused field');
  });

  it('malformed key events are dropped', () => {
    const { engine, notes } = setup();
    engine.onNotify('key', { type: 'sideways', key: 'AltRight', time: 1 });
    engine.onNotify('key', undefined);
    expect(notes).toEqual([]);
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
