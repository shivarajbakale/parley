import type { EditTargets } from './edit-target';
import type { Injector } from './injector';
import type { Rewriter } from './rewriter';
import type { Transcriber } from './transcriber';
import type {
  OrbPhasePayload,
  PermissionStatus,
  RecordedAudio,
  SessionMode,
  Settings,
} from './types';

/**
 * One dictation session, from the held press to the paste.
 *
 * In `edit` mode the speech is an instruction, not the text: whatever is in
 * the focused field is rewritten by it and pasted back over itself.
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
  injector: Pick<Injector, 'paste'>;
  rewriter: Pick<Rewriter, 'rewrite'>;
  editTargets: EditTargets;
  getSettings(): Settings;
  hasApiKey(): boolean;
  hasRewriteKey(): boolean;
  getPermissions(): PermissionStatus;
  /** The settings window doubles as onboarding. */
  openSettings(): void;
  onTranscript(text: string): void;
}

export interface Session {
  start(mode?: SessionMode): void;
  stop(): void;
  cancel(): void;
  receiveAudio(audio: RecordedAudio): Promise<void>;
  state(): SessionState;
}

export function createSession(deps: SessionDeps): Session {
  let state: SessionState = 'idle';
  let mode: SessionMode = 'dictate';
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

    start(requested = 'dictate') {
      if (state !== 'idle') return;
      const permissions = deps.getPermissions();
      const hasKeys = deps.hasApiKey() && (requested === 'dictate' || deps.hasRewriteKey());
      if (!permissions.microphone || !permissions.accessibility || !hasKeys) {
        deps.openSettings();
        return;
      }
      mode = requested;
      state = 'listening';
      deps.orb.show();
      deps.orb.setPhase({
        phase: 'listening',
        tick: deps.getSettings().tickSound,
        ...(mode === 'edit' ? { mode } : {}),
      });
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
        // The field is read while Whisper works: the gesture key is up by
        // now, so the keystroke fallback cannot collide with a held modifier.
        const [spoken, target] = await Promise.all([
          deps.transcriber.transcribe(
            { data: audio.data, mimeType: audio.mimeType },
            { vocabulary: deps.getSettings().vocabulary }
          ),
          mode === 'edit' ? deps.editTargets.capture() : null,
        ]);
        if (!spoken) {
          finish({ phase: 'cancelled' }, 0);
          return;
        }
        let text = spoken;
        if (target) {
          text = await deps.rewriter.rewrite(target.text, spoken);
          await deps.editTargets.apply(target, text);
        } else {
          await deps.injector.paste(text);
        }
        deps.onTranscript(text);
        finish({ phase: 'done' }, DONE_MS);
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Something went wrong';
        finish({ phase: 'error', message }, ERROR_MS);
      }
    },
  };
}
