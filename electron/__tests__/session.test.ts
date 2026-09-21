import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { createSession, ERROR_MS, MAX_RECORDING_MS, type SessionDeps } from '../session';
import { TranscribeError } from '../transcriber';
import { DEFAULT_SETTINGS, type RecordedAudio } from '../types';

const audio = (durationMs = 2000): RecordedAudio => ({
  data: new ArrayBuffer(8),
  mimeType: 'audio/webm',
  durationMs,
});

function setup(overrides: Partial<SessionDeps> = {}) {
  const deps: SessionDeps = {
    orb: { show: vi.fn(), hide: vi.fn(), setPhase: vi.fn() },
    transcriber: { transcribe: vi.fn().mockResolvedValue('hello world') },
    injector: { paste: vi.fn().mockResolvedValue(undefined) },
    getSettings: () => DEFAULT_SETTINGS,
    hasApiKey: () => true,
    getPermissions: () => ({ microphone: true, accessibility: true }),
    openSettings: vi.fn(),
    onTranscript: vi.fn(),
    ...overrides,
  };
  return { deps, session: createSession(deps) };
}

describe('session', () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it('runs a full dictation: show, record, transcribe, paste, hide', async () => {
    const { deps, session } = setup();

    session.start();
    expect(deps.orb.show).toHaveBeenCalled();
    expect(deps.orb.setPhase).toHaveBeenLastCalledWith({ phase: 'listening' });

    session.stop();
    expect(deps.orb.setPhase).toHaveBeenLastCalledWith({ phase: 'transcribing', tick: true });

    await session.receiveAudio(audio());
    expect(deps.transcriber.transcribe).toHaveBeenCalledWith(
      { data: expect.any(ArrayBuffer), mimeType: 'audio/webm' },
      { vocabulary: '' }
    );
    expect(deps.injector.paste).toHaveBeenCalledWith('hello world');
    expect(deps.onTranscript).toHaveBeenCalledWith('hello world');
    expect(deps.orb.setPhase).toHaveBeenLastCalledWith({ phase: 'done' });

    await vi.runAllTimersAsync();
    expect(deps.orb.hide).toHaveBeenCalled();
    expect(session.state()).toBe('idle');
  });

  it('opens settings instead of recording when a permission is missing', () => {
    const { deps, session } = setup({
      getPermissions: () => ({ microphone: false, accessibility: true }),
    });
    session.start();
    expect(deps.openSettings).toHaveBeenCalled();
    expect(deps.orb.show).not.toHaveBeenCalled();
    expect(session.state()).toBe('idle');
  });

  it('opens settings instead of recording when there is no API key', () => {
    const { deps, session } = setup({ hasApiKey: () => false });
    session.start();
    expect(deps.openSettings).toHaveBeenCalled();
    expect(session.state()).toBe('idle');
  });

  it('discards audio shorter than 300 ms without calling Groq', async () => {
    const { deps, session } = setup();
    session.start();
    session.stop();
    await session.receiveAudio(audio(299));
    expect(deps.transcriber.transcribe).not.toHaveBeenCalled();
    expect(deps.orb.setPhase).toHaveBeenLastCalledWith({ phase: 'cancelled' });
    await vi.runAllTimersAsync();
    expect(session.state()).toBe('idle');
  });

  it('pastes nothing for an empty transcript', async () => {
    const { deps, session } = setup({
      transcriber: { transcribe: vi.fn().mockResolvedValue('') },
    });
    session.start();
    session.stop();
    await session.receiveAudio(audio());
    expect(deps.injector.paste).not.toHaveBeenCalled();
    expect(deps.onTranscript).not.toHaveBeenCalled();
    expect(deps.orb.setPhase).toHaveBeenLastCalledWith({ phase: 'cancelled' });
  });

  it('shows the error for 3 s and leaves the clipboard alone when Groq fails', async () => {
    const { deps, session } = setup({
      transcriber: { transcribe: vi.fn().mockRejectedValue(new TranscribeError('network')) },
    });
    session.start();
    session.stop();
    await session.receiveAudio(audio());

    expect(deps.injector.paste).not.toHaveBeenCalled();
    expect(deps.orb.setPhase).toHaveBeenLastCalledWith({
      phase: 'error',
      message: 'No connection',
    });
    await vi.advanceTimersByTimeAsync(ERROR_MS - 1);
    expect(deps.orb.hide).not.toHaveBeenCalled();
    await vi.runAllTimersAsync();
    expect(deps.orb.hide).toHaveBeenCalled();
    expect(session.state()).toBe('idle');
  });

  it('ignores a second gesture while a session is busy', async () => {
    const { deps, session } = setup();
    session.start();
    session.stop();
    session.start();
    expect(deps.orb.show).toHaveBeenCalledTimes(1);
    expect(session.state()).toBe('awaiting_audio');
  });

  it('cancels while listening and ignores the audio that arrives afterwards', async () => {
    const { deps, session } = setup();
    session.start();
    session.cancel();
    expect(deps.orb.setPhase).toHaveBeenLastCalledWith({ phase: 'cancelled' });
    await session.receiveAudio(audio());
    expect(deps.transcriber.transcribe).not.toHaveBeenCalled();
  });

  it('auto-stops after 10 minutes', () => {
    const { deps, session } = setup();
    session.start();
    vi.advanceTimersByTime(MAX_RECORDING_MS);
    expect(deps.orb.setPhase).toHaveBeenLastCalledWith({ phase: 'transcribing', tick: true });
    expect(session.state()).toBe('awaiting_audio');
  });

  it('passes the tick setting through', () => {
    const { deps, session } = setup({
      getSettings: () => ({ ...DEFAULT_SETTINGS, tickSound: false }),
    });
    session.start();
    session.stop();
    expect(deps.orb.setPhase).toHaveBeenLastCalledWith({ phase: 'transcribing', tick: false });
  });
});
