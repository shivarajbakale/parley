import type { Injector } from './injector';
import type { Transcriber } from './transcriber';
import type { OrbPhasePayload, PermissionStatus, RecordedAudio, Settings } from './types';

/**
 * One dictation session, from the held press to the paste.
 *
 * Everything it touches is passed in, so the rules that matter — the busy
 * guard, the short-audio discard, "an error never touches the clipboard" — are
 * unit tests rather than things to try by hand.
 */

export const MIN_AUDIO_MS = 300;
export const MAX_RECORDING_MS = 600_000;
export const DONE_MS = 300;
export const ERROR_MS = 3000;
export const FADE_MS = 150;

export type SessionState = 'idle' | 'listening' | 'awaiting_audio' | 'transcribing' | 'finishing';

export interface SessionDeps {
  orb: { show(): void; hide(): void; setPhase(payload: OrbPhasePayload): void };
  transcriber: Pick<Transcriber, 'transcribe'>;
  injector: Injector;
  getSettings(): Settings;
  hasApiKey(): boolean;
  getPermissions(): PermissionStatus;
  /** The settings window doubles as onboarding. */
  openSettings(): void;
  onTranscript(text: string): void;
}

export interface Session {
  start(): void;
  stop(): void;
  cancel(): void;
  receiveAudio(audio: RecordedAudio): Promise<void>;
  state(): SessionState;
}

export function createSession(deps: SessionDeps): Session {
  let state: SessionState = 'idle';
  let maxTimer: ReturnType<typeof setTimeout> | undefined;

  function clearMaxTimer() {
    if (maxTimer) clearTimeout(maxTimer);
    maxTimer = undefined;
  }

  /** Show a final phase for `visibleMs`, let the orb fade, then hide it. */
  function finish(payload: OrbPhasePayload, visibleMs: number) {
    state = 'finishing';
    deps.orb.setPhase(payload);
    setTimeout(() => {
      deps.orb.hide();
      state = 'idle';
    }, visibleMs + FADE_MS);
  }

  function stop() {
    if (state !== 'listening') return;
    clearMaxTimer();
    state = 'awaiting_audio';
    deps.orb.setPhase({ phase: 'transcribing', tick: deps.getSettings().tickSound });
  }

  return {
    state: () => state,

    start() {
      if (state !== 'idle') return;
      const permissions = deps.getPermissions();
      if (!permissions.microphone || !permissions.accessibility || !deps.hasApiKey()) {
        deps.openSettings();
        return;
      }
      state = 'listening';
      deps.orb.show();
      deps.orb.setPhase({ phase: 'listening' });
      maxTimer = setTimeout(stop, MAX_RECORDING_MS);
    },

    stop,

    cancel() {
      if (state !== 'listening') return;
      clearMaxTimer();
      finish({ phase: 'cancelled' }, 0);
    },

    async receiveAudio(audio) {
      if (state !== 'awaiting_audio') return;
      if (audio.durationMs < MIN_AUDIO_MS) {
        finish({ phase: 'cancelled' }, 0);
        return;
      }

      state = 'transcribing';
      try {
        const text = await deps.transcriber.transcribe(
          { data: audio.data, mimeType: audio.mimeType },
          { vocabulary: deps.getSettings().vocabulary }
        );
        if (!text) {
          finish({ phase: 'cancelled' }, 0);
          return;
        }
        await deps.injector.paste(text);
        deps.onTranscript(text);
        finish({ phase: 'done' }, DONE_MS);
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Something went wrong';
        finish({ phase: 'error', message }, ERROR_MS);
      }
    },
  };
}
