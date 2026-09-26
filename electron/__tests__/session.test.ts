import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { createSession, ERROR_MS, MAX_RECORDING_MS, type SessionDeps } from '../session';
import { EditTargetError } from '../edit-target';
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
    rewriter: { rewrite: vi.fn().mockResolvedValue('Hi.') },
    editTargets: {
      capture: vi.fn().mockResolvedValue({ text: 'Hello there, friend.', scope: 'field' }),
      apply: vi.fn().mockResolvedValue(undefined),
    },
    selection: { read: vi.fn().mockResolvedValue({ text: 'const x = useMemo(() => 1)', anchor: null }) },
    explain: { ask: vi.fn().mockResolvedValue(undefined) },
    dictionary: {
      prompt: vi.fn().mockReturnValue(''),
      terms: vi.fn().mockReturnValue([]),
      apply: vi.fn((text: string) => text),
    },
    getSettings: () => DEFAULT_SETTINGS,
    hasApiKey: () => true,
    hasRewriteKey: () => true,
    isAgentReady: () => true,
    isAgentManaged: () => false,
    runAgent: vi.fn().mockResolvedValue(undefined),
    cancelAgent: vi.fn(),
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
    expect(deps.orb.setPhase).toHaveBeenLastCalledWith({ phase: 'listening', tick: true });

    session.stop();
    expect(deps.orb.setPhase).toHaveBeenLastCalledWith({ phase: 'transcribing', tick: true });

    await session.receiveAudio(audio());
    expect(deps.transcriber.transcribe).toHaveBeenCalledWith(
      { data: expect.any(ArrayBuffer), mimeType: 'audio/webm' },
      { vocabulary: '', terms: [] }
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

  describe('personal dictionary', () => {
    it('sends the dictionary prompt with the audio and pastes the fixed text', async () => {
      const { deps, session } = setup({
        transcriber: { transcribe: vi.fn().mockResolvedValue('I tested mini max') },
        dictionary: {
          prompt: () => 'Notes about MiniMax.',
          terms: () => ['MiniMax'],
          apply: vi.fn().mockReturnValue('I tested MiniMax'),
        },
      });

      session.start();
      session.stop();
      await session.receiveAudio(audio());

      expect(deps.transcriber.transcribe).toHaveBeenCalledWith(expect.anything(), {
        vocabulary: 'Notes about MiniMax.',
        terms: ['MiniMax'],
      });
      expect(deps.dictionary.apply).toHaveBeenCalledWith('I tested mini max');
      expect(deps.injector.paste).toHaveBeenCalledWith('I tested MiniMax');
      expect(deps.onTranscript).toHaveBeenCalledWith('I tested MiniMax');
    });

    it('fixes a spoken instruction before the rewrite sees it', async () => {
      const { deps, session } = setup({
        transcriber: { transcribe: vi.fn().mockResolvedValue('sign it as shiv raj') },
        dictionary: { prompt: () => '', terms: () => [], apply: () => 'sign it as Shivaraj' },
      });

      session.start('edit');
      session.stop();
      await session.receiveAudio(audio());

      expect(deps.rewriter.rewrite).toHaveBeenCalledWith(
        'Hello there, friend.',
        'sign it as Shivaraj'
      );
    });

    it('reports a pasted dictation, and never a voice edit', async () => {
      const onDictation = vi.fn();
      const { session } = setup({ onDictation });

      session.start();
      session.stop();
      await session.receiveAudio(audio());
      expect(onDictation).toHaveBeenCalledExactlyOnceWith('hello world');

      await vi.runAllTimersAsync();
      session.start('edit');
      session.stop();
      await session.receiveAudio(audio());
      expect(onDictation).toHaveBeenCalledTimes(1);
    });

    it('does not consult the dictionary when nothing was heard', async () => {
      const apply = vi.fn();
      const { deps, session } = setup({
        transcriber: { transcribe: vi.fn().mockResolvedValue('') },
        dictionary: { prompt: () => '', terms: () => [], apply },
      });

      session.start();
      session.stop();
      await session.receiveAudio(audio());

      expect(apply).not.toHaveBeenCalled();
      expect(deps.injector.paste).not.toHaveBeenCalled();
    });
  });

  describe('explain', () => {
    it('asks the spoken question, with the selection as its anchor, and pastes nothing', async () => {
      const { deps, session } = setup({
        transcriber: { transcribe: vi.fn().mockResolvedValue('is this thread safe?') },
      });

      session.start('explain');
      expect(deps.orb.setPhase).toHaveBeenLastCalledWith({
        phase: 'listening',
        tick: true,
        mode: 'explain',
      });
      // The selection is read the instant the gesture starts, not after speech.
      expect(deps.selection.read).toHaveBeenCalledOnce();
      session.stop();
      await session.receiveAudio(audio());

      expect(deps.explain.ask).toHaveBeenCalledWith('is this thread safe?', {
        text: 'const x = useMemo(() => 1)',
        anchor: null,
      });
      expect(deps.injector.paste).not.toHaveBeenCalled();
      expect(deps.orb.setPhase).toHaveBeenLastCalledWith({ phase: 'done' });
    });

    it("primes Whisper with the selection's own words, so it hears them spelled right", async () => {
      const { deps, session } = setup();
      session.start('explain');
      session.stop();
      await session.receiveAudio(audio());
      expect(deps.transcriber.transcribe).toHaveBeenCalledWith(expect.anything(), {
        vocabulary: expect.stringContaining('useMemo'),
        terms: expect.arrayContaining(['useMemo']),
      });
    });

    it('puts the selection words ahead of the dictionary terms for a keyterm provider', async () => {
      const { deps, session } = setup({
        dictionary: { prompt: () => '', terms: () => ['MiniMax'], apply: (text: string) => text },
      });
      session.start('explain');
      session.stop();
      await session.receiveAudio(audio());
      const [, options] = vi.mocked(deps.transcriber.transcribe).mock.calls[0];
      expect(options.terms?.[0]).toBe('const');
      expect(options.terms?.at(-1)).toBe('MiniMax');
    });

    it('falls back to a plain explanation when nothing was said', async () => {
      const { deps, session } = setup({
        transcriber: { transcribe: vi.fn().mockResolvedValue('') },
      });
      session.start('explain');
      session.stop();
      await session.receiveAudio(audio());
      expect(deps.explain.ask).toHaveBeenCalledWith(undefined, {
        text: 'const x = useMemo(() => 1)',
        anchor: null,
      });
    });

    it('explains plainly on a tap too short to hold a question, without transcribing', async () => {
      const { deps, session } = setup();
      session.start('explain');
      session.stop();
      await session.receiveAudio(audio(100));
      expect(deps.transcriber.transcribe).not.toHaveBeenCalled();
      expect(deps.explain.ask).toHaveBeenCalledWith(undefined, {
        text: 'const x = useMemo(() => 1)',
        anchor: null,
      });
    });

    it('never touches explain or reads the selection during plain dictation', async () => {
      const { deps, session } = setup();
      session.start();
      session.stop();
      await session.receiveAudio(audio());
      expect(deps.explain.ask).not.toHaveBeenCalled();
      expect(deps.selection.read).not.toHaveBeenCalled();
    });

    it('turns a Groq failure into the orb error state, same as dictation', async () => {
      const { deps, session } = setup({
        transcriber: { transcribe: vi.fn().mockRejectedValue(new TranscribeError('rate_limit')) },
      });
      session.start('explain');
      session.stop();
      await session.receiveAudio(audio());
      expect(deps.orb.setPhase).toHaveBeenLastCalledWith({ phase: 'error', message: 'Rate limited' });
      expect(deps.explain.ask).not.toHaveBeenCalled();
    });
  });

  describe('voice edit', () => {
    it('rewrites the focused field with the spoken instruction', async () => {
      const { deps, session } = setup({
        transcriber: { transcribe: vi.fn().mockResolvedValue('make it shorter') },
      });

      session.start('edit');
      expect(deps.orb.setPhase).toHaveBeenLastCalledWith({
        phase: 'listening',
        tick: true,
        mode: 'edit',
      });
      session.stop();
      await session.receiveAudio(audio());

      expect(deps.rewriter.rewrite).toHaveBeenCalledWith('Hello there, friend.', 'make it shorter');
      expect(deps.editTargets.apply).toHaveBeenCalledWith(
        { text: 'Hello there, friend.', scope: 'field' },
        'Hi.'
      );
      expect(deps.injector.paste).not.toHaveBeenCalled();
      expect(deps.onTranscript).toHaveBeenCalledWith('Hi.');
      expect(deps.orb.setPhase).toHaveBeenLastCalledWith({ phase: 'done' });
    });

    it('never reads the field during plain dictation', async () => {
      const { deps, session } = setup();
      session.start();
      session.stop();
      await session.receiveAudio(audio());
      expect(deps.editTargets.capture).not.toHaveBeenCalled();
      expect(deps.rewriter.rewrite).not.toHaveBeenCalled();
    });

    it('opens settings when the MiniMax key is missing', () => {
      const { deps, session } = setup({ hasRewriteKey: () => false });
      session.start('edit');
      expect(deps.openSettings).toHaveBeenCalled();
      expect(session.state()).toBe('idle');
    });

    it('dictation still works without a MiniMax key', () => {
      const { deps, session } = setup({ hasRewriteKey: () => false });
      session.start();
      expect(deps.openSettings).not.toHaveBeenCalled();
      expect(session.state()).toBe('listening');
    });

    it('shows the reason and changes nothing when there is no field to edit', async () => {
      const { deps, session } = setup({
        editTargets: {
          capture: vi.fn().mockRejectedValue(new EditTargetError('No text field focused')),
          apply: vi.fn(),
        },
      });
      session.start('edit');
      session.stop();
      await session.receiveAudio(audio());
      expect(deps.orb.setPhase).toHaveBeenLastCalledWith({
        phase: 'error',
        message: 'No text field focused',
      });
      expect(deps.editTargets.apply).not.toHaveBeenCalled();
      expect(deps.injector.paste).not.toHaveBeenCalled();
    });

    it('leaves the field alone when the rewrite fails', async () => {
      const { deps, session } = setup({
        rewriter: { rewrite: vi.fn().mockRejectedValue(new Error('MiniMax error')) },
      });
      session.start('edit');
      session.stop();
      await session.receiveAudio(audio());
      expect(deps.editTargets.apply).not.toHaveBeenCalled();
      expect(deps.orb.setPhase).toHaveBeenLastCalledWith({ phase: 'error', message: 'MiniMax error' });
    });

    it('a second edit does not inherit the mode of the first', async () => {
      const { deps, session } = setup();
      session.start('edit');
      session.stop();
      await session.receiveAudio(audio());
      await vi.runAllTimersAsync();

      session.start();
      session.stop();
      await session.receiveAudio(audio());
      expect(deps.editTargets.capture).toHaveBeenCalledTimes(1);
      expect(deps.injector.paste).toHaveBeenCalledWith('hello world');
    });
  });

  describe('act mode', () => {
    it('is blocked with the agent reason when the agent is not ready', async () => {
      const onBlocked = vi.fn();
      const { deps, session } = setup({ isAgentReady: () => false, onBlocked });
      session.start('act');
      expect(onBlocked).toHaveBeenCalledWith('agent');
      expect(deps.openSettings).toHaveBeenCalled();
      expect(deps.orb.show).not.toHaveBeenCalled();
      expect(session.state()).toBe('idle');
    });

    it('needs no accessibility permission, and no rewrite key when attached', () => {
      const { session } = setup({
        getPermissions: () => ({ microphone: true, accessibility: false }),
        hasRewriteKey: () => false,
        isAgentManaged: () => false,
      });
      session.start('act');
      expect(session.state()).toBe('listening');
    });

    it('is blocked with the rewrite-key reason when managed with no MiniMax key', () => {
      const onBlocked = vi.fn();
      const { deps, session } = setup({
        hasRewriteKey: () => false,
        isAgentManaged: () => true,
        onBlocked,
      });
      session.start('act');
      expect(onBlocked).toHaveBeenCalledWith('rewriteKey');
      expect(deps.openSettings).toHaveBeenCalled();
      expect(deps.orb.show).not.toHaveBeenCalled();
      expect(session.state()).toBe('idle');
    });

    it('runs managed with a MiniMax key', () => {
      const { session } = setup({ hasRewriteKey: () => true, isAgentManaged: () => true });
      session.start('act');
      expect(session.state()).toBe('listening');
    });

    it('still needs the microphone and a transcription key', () => {
      const blocked: string[] = [];
      const micless = setup({
        getPermissions: () => ({ microphone: false, accessibility: true }),
        onBlocked: reason => void blocked.push(reason),
      });
      micless.session.start('act');
      const keyless = setup({
        hasApiKey: () => false,
        onBlocked: reason => void blocked.push(reason),
      });
      keyless.session.start('act');
      expect(blocked).toEqual(['microphone', 'apiKey']);
    });

    it('hands the transcribed words to the agent and pastes nothing', async () => {
      const { deps, session } = setup();
      session.start('act');
      session.stop();
      await session.receiveAudio(audio());
      expect(deps.runAgent).toHaveBeenCalledWith('hello world');
      expect(deps.injector.paste).not.toHaveBeenCalled();
      expect(deps.onTranscript).not.toHaveBeenCalled();
      expect(session.state()).toBe('idle');
      expect(deps.orb.hide).not.toHaveBeenCalled();
    });

    it('runs nothing on short audio or an empty transcript', async () => {
      const short = setup();
      short.session.start('act');
      short.session.stop();
      await short.session.receiveAudio(audio(100));
      expect(short.deps.runAgent).not.toHaveBeenCalled();

      const empty = setup({ transcriber: { transcribe: vi.fn().mockResolvedValue('') } });
      empty.session.start('act');
      empty.session.stop();
      await empty.session.receiveAudio(audio());
      expect(empty.deps.runAgent).not.toHaveBeenCalled();
    });

    it('cancel during the run aborts at once; the late handoff lands nowhere', async () => {
      let release!: () => void;
      const gate = new Promise<void>(resolve => (release = resolve));
      const { deps, session } = setup({ runAgent: vi.fn().mockReturnValue(gate) });
      session.start('act');
      session.stop();
      const flight = session.receiveAudio(audio());
      await Promise.resolve();
      session.cancel();
      expect(deps.cancelAgent).toHaveBeenCalledTimes(1);
      expect(session.state()).toBe('idle');
      release();
      await flight;
      expect(session.state()).toBe('idle');
      expect(deps.orb.hide).not.toHaveBeenCalled();
    });

    it('a rejected handoff still lands the pill on an error', async () => {
      const { deps, session } = setup({
        runAgent: vi.fn().mockRejectedValue(new Error('Agent unreachable')),
      });
      session.start('act');
      session.stop();
      await session.receiveAudio(audio());
      expect(deps.orb.setPhase).toHaveBeenLastCalledWith({
        phase: 'error',
        message: 'Agent unreachable',
      });
    });

    it('a new session after cancel is not clobbered by the stale run', async () => {
      let release!: () => void;
      const gate = new Promise<void>(resolve => (release = resolve));
      const { session } = setup({ runAgent: vi.fn().mockReturnValue(gate) });
      session.start('act');
      session.stop();
      const flight = session.receiveAudio(audio());
      await Promise.resolve();
      session.cancel();
      session.start();
      release();
      await flight;
      expect(session.state()).toBe('listening');
    });
  });
});
