import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { NOTICE_ACCEPTED_MS, NOTICE_MS, type RecordedAudio } from '../../../electron/types';
import type { Recorder } from '../recorder';

import { createPhaseHandler } from '../phase-handler';

function fakeRecorder(overrides: Partial<Recorder> = {}): Recorder {
  return {
    start: vi.fn().mockResolvedValue(undefined),
    stop: vi.fn().mockResolvedValue(null),
    discard: vi.fn(),
    level: vi.fn().mockReturnValue(0),
    bands: vi.fn().mockReturnValue({ low: 0, mid: 0, high: 0 }),
    ...overrides,
  };
}

function harness(recorder: Recorder) {
  const sendAudio = vi.fn();
  const playSound = vi.fn();
  const onPhase = vi.fn();
  const onMode = vi.fn();
  const setVisible = vi.fn();
  const setMessage = vi.fn();
  const setNotice = vi.fn();
  const handler = createPhaseHandler({
    recorder,
    sendAudio,
    playSound,
    onPhase,
    onMode,
    setVisible,
    setMessage,
    setNotice,
  });
  return { handler, sendAudio, playSound, onPhase, onMode, setVisible, setMessage, setNotice };
}

describe('createPhaseHandler', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('sends real audio exactly once on transcribing', async () => {
    const audio: RecordedAudio = { data: new ArrayBuffer(4), mimeType: 'audio/webm', durationMs: 500 };
    const recorder = fakeRecorder({ stop: vi.fn().mockResolvedValue(audio) });
    const { handler, sendAudio } = harness(recorder);

    await handler.handlePhase({ phase: 'transcribing' });

    expect(sendAudio).toHaveBeenCalledTimes(1);
    expect(sendAudio).toHaveBeenCalledWith(audio);
  });

  it('sends an empty payload on transcribing when stop() resolves null (finding 4)', async () => {
    const recorder = fakeRecorder({ stop: vi.fn().mockResolvedValue(null) });
    const { handler, sendAudio } = harness(recorder);

    await handler.handlePhase({ phase: 'transcribing' });

    expect(sendAudio).toHaveBeenCalledTimes(1);
    expect(sendAudio).toHaveBeenCalledWith({ data: new ArrayBuffer(0), mimeType: '', durationMs: 0 });
  });

  it('sends an empty payload on transcribing when stop() throws, without leaving an unhandled rejection (findings 2 and 4)', async () => {
    const recorder = fakeRecorder({ stop: vi.fn().mockRejectedValue(new Error('boom')) });
    const { handler, sendAudio } = harness(recorder);

    await expect(handler.handlePhase({ phase: 'transcribing' })).resolves.toBeUndefined();

    expect(sendAudio).toHaveBeenCalledTimes(1);
    expect(sendAudio).toHaveBeenCalledWith({ data: new ArrayBuffer(0), mimeType: '', durationMs: 0 });
  });

  it('does not throw when recorder.start() rejects on listening (finding 2)', async () => {
    const recorder = fakeRecorder({ start: vi.fn().mockRejectedValue(new Error('denied')) });
    const { handler, setMessage } = harness(recorder);

    await expect(handler.handlePhase({ phase: 'listening' })).resolves.toBeUndefined();

    expect(setMessage).toHaveBeenCalledWith(expect.stringContaining('microphone'));
  });

  it('plays the tick only when requested, independent of audio presence', async () => {
    const recorder = fakeRecorder({ stop: vi.fn().mockResolvedValue(null) });
    const { handler, playSound } = harness(recorder);

    await handler.handlePhase({ phase: 'transcribing', tick: true });

    expect(playSound).toHaveBeenCalledTimes(1);
    expect(playSound).toHaveBeenCalledWith('stop', 'dictate');
  });

  it('plays start, stop and done in the voice of the session that began', async () => {
    const { handler, playSound } = harness(fakeRecorder());
    await handler.handlePhase({ phase: 'listening', tick: true, mode: 'edit' });
    await handler.handlePhase({ phase: 'transcribing', tick: true });
    await handler.handlePhase({ phase: 'done' });
    expect(playSound.mock.calls).toEqual([
      ['start', 'edit'],
      ['stop', 'edit'],
      ['done', 'edit'],
    ]);
  });

  it('stays silent for a whole session when sounds are off', async () => {
    const { handler, playSound } = harness(fakeRecorder());
    await handler.handlePhase({ phase: 'listening', tick: false });
    await handler.handlePhase({ phase: 'transcribing', tick: false });
    await handler.handlePhase({ phase: 'done' });
    expect(playSound).not.toHaveBeenCalled();
  });

  it('a later listening cancels a pending done-hide timer (finding 3)', async () => {
    const recorder = fakeRecorder();
    const { handler, setVisible } = harness(recorder);

    await handler.handlePhase({ phase: 'done' });
    setVisible.mockClear();

    await handler.handlePhase({ phase: 'listening' });
    vi.advanceTimersByTime(500);

    // The stale done-hide must not fire once superseded by `listening`.
    expect(setVisible).not.toHaveBeenCalledWith(false);
  });

  it('a later listening cancels a pending error-hide timer (finding 3)', async () => {
    const recorder = fakeRecorder();
    const { handler, setVisible } = harness(recorder);

    await handler.handlePhase({ phase: 'error', message: 'oops' });
    setVisible.mockClear();

    await handler.handlePhase({ phase: 'listening' });
    vi.advanceTimersByTime(5000);

    expect(setVisible).not.toHaveBeenCalledWith(false);
  });

  it('hides after the done delay when nothing supersedes it', async () => {
    const recorder = fakeRecorder();
    const { handler, setVisible } = harness(recorder);

    await handler.handlePhase({ phase: 'done' });
    setVisible.mockClear();
    vi.advanceTimersByTime(300);

    expect(setVisible).toHaveBeenCalledWith(false);
  });

  it('dispose() clears a pending hide timer', async () => {
    const recorder = fakeRecorder();
    const { handler, setVisible } = harness(recorder);

    await handler.handlePhase({ phase: 'done' });
    setVisible.mockClear();
    handler.dispose();
    vi.advanceTimersByTime(1000);

    expect(setVisible).not.toHaveBeenCalled();
  });

  it('takes the hue from the session that is starting, and only then', async () => {
    const { handler, onMode } = harness(fakeRecorder());
    await handler.handlePhase({ phase: 'listening', mode: 'edit' });
    expect(onMode).toHaveBeenLastCalledWith('edit');

    // Later phases carry no mode, and must not knock the orb back to indigo.
    await handler.handlePhase({ phase: 'transcribing' });
    await handler.handlePhase({ phase: 'done' });
    expect(onMode).toHaveBeenCalledTimes(1);

    await handler.handlePhase({ phase: 'listening' });
    expect(onMode).toHaveBeenLastCalledWith('dictate');
  });

  it('shows a notice in place of the waveform, then folds it before main hides the window', async () => {
    const { handler, onPhase, setVisible, setNotice, playSound } = harness(fakeRecorder());
    await handler.handlePhase({ phase: 'notice', message: 'Remember “MiniMax”?', hint: 'Tap Shift' });

    expect(onPhase).toHaveBeenLastCalledWith('cancelled');
    expect(setVisible).toHaveBeenLastCalledWith(false);
    expect(setNotice).toHaveBeenLastCalledWith({
      message: 'Remember “MiniMax”?',
      hint: 'Tap Shift',
      accepted: false,
    });
    expect(playSound).not.toHaveBeenCalled();

    vi.advanceTimersByTime(NOTICE_MS - 201);
    expect(setNotice).not.toHaveBeenLastCalledWith(null);
    vi.advanceTimersByTime(1);
    expect(setNotice).toHaveBeenLastCalledWith(null);
  });

  it('an accepted notice is brief, and chimes when sounds are on', async () => {
    const { handler, setNotice, playSound } = harness(fakeRecorder());
    await handler.handlePhase({ phase: 'listening', tick: true });
    playSound.mockClear();

    await handler.handlePhase({ phase: 'notice', message: 'Added “MiniMax”', accepted: true });
    expect(playSound).toHaveBeenCalledWith('done', 'dictate');
    vi.advanceTimersByTime(NOTICE_ACCEPTED_MS - 200);
    expect(setNotice).toHaveBeenLastCalledWith(null);
  });

  it('a session starting clears a notice at once', async () => {
    const { handler, setNotice } = harness(fakeRecorder());
    await handler.handlePhase({ phase: 'notice', message: 'Remember “MiniMax”?' });
    await handler.handlePhase({ phase: 'listening' });
    expect(setNotice).toHaveBeenLastCalledWith(null);
  });
});
