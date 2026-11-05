import type { EditTargets } from './edit-target';
import type { Injector } from './injector';
import type { Rewriter } from './rewriter';
import { selectionVocabulary } from './selection-vocabulary';
import type { SelectionSnapshot } from './selection-reader';
import type { Transcriber } from './transcriber';
import type {
  OrbPhasePayload,
  PermissionStatus,
  RecordedAudio,
  SessionBlockedReason,
  SessionMode,
  Settings,
} from './types';

/**
 * One dictation session, from the held press to the paste.
 *
 * In `explain` mode the speech is a question about the selected text; the
 * answer opens in the card beside the selection, so nothing is pasted. Saying
 * nothing, or only tapping, asks for a plain explanation. The selection is
 * read the moment the gesture starts, in parallel with the recording, both so
 * the words in it can prime Whisper's spelling of the question and so the
 * card opens on the same read instead of a second, possibly stale one.
 *
 * In `edit` mode the speech is an instruction, not the text: whatever is in
 * the focused field is rewritten by it and pasted back over itself.
 *
 * In `act` mode the speech is a command for the Mastra agent: it is
 * transcribed like a dictation, then handed to main, which runs it, paints
 * its progress on the pill, and settles the result. The session idles the
 * moment the handoff resolves and never touches the pill after it — a
 * cancelled run lands nowhere, and a new session is never clobbered by the
 * stale handoff.
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
  /** Explain mode: what is selected right now, read at the moment the gesture
   * starts. Only ever used to prime Whisper and to hand the card its anchor;
   * `explain.ask` decides on its own whether a thread is already open. */
  selection: { read(): Promise<SelectionSnapshot | null> };
  explain: { ask(question?: string, snapshot?: SelectionSnapshot | null): Promise<void> };
  /** The personal dictionary: words for the transcriber going in, spelling
   * fixes coming out. `prompt` is Whisper's sentence, `terms` the same words
   * as a list for a keyterm provider. */
  dictionary: { prompt(): string; terms(): string[]; apply(text: string): string };
  getSettings(): Settings;
  /** Act mode: run the transcribed command through the agent and settle the
   * pill — progress, approvals, the result or the failure. Never rejects:
   * every failure is a painted error, never a thrown one. */
  runAgent(transcript: string): Promise<void>;
  /** Abort the in-flight run, if any: the stream, the server run, the
   * question on the pill. Safe to call with nothing running. */
  cancelAgent(): void;
  /** The agent answers and has at least one MCP server to act through. */
  isAgentReady(): boolean;
  getPermissions(): PermissionStatus;
  /** The settings window doubles as onboarding. */
  openSettings(): void;
  /** A gesture was refused for a missing permission or key. Opening settings
   * is silent when that window is already in front, so this is the only way
   * the user learns why nothing happened. */
  onBlocked?(reason: SessionBlockedReason): void;
  onTranscript(text: string): void;
  /** A dictation, not an edit, has just been pasted: the text now sits in a field. */
  onDictation?(text: string): void;
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
  /** Each start and each mid-run cancel moves this on, so a stale act handoff
   * can tell it no longer owns the session when it settles. */
  let sequence = 0;
  let maxTimer: ReturnType<typeof setTimeout> | undefined;
  /** Kicked off the instant an explain gesture starts, so it has the whole
   * recording to resolve before anything needs it. */
  let explainSelection: Promise<SelectionSnapshot | null> | null = null;

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
      // A session already in flight swallows the gesture rather than queuing
      // it — nothing to report, the user will see the orb still busy.
      if (state !== 'idle') return;
      const permissions = deps.getPermissions();
      if (!permissions.microphone) {
        deps.onBlocked?.('microphone');
        deps.openSettings();
        return;
      }
      if (requested === 'act') {
        // No keystrokes: the command is transcribed, then the agent — not
        // the pill — does everything else. Keys live in parley-api, so a
        // missing one fails on the pill after the take, not here.
        if (!deps.isAgentReady()) {
          deps.onBlocked?.('agent');
          deps.openSettings();
          return;
        }
      } else {
        if (!permissions.accessibility) {
          deps.onBlocked?.('accessibility');
          deps.openSettings();
          return;
        }
      }
      mode = requested;
      sequence += 1;
      explainSelection = mode === 'explain' ? deps.selection.read() : null;
      state = 'listening';
      deps.orb.show();
      deps.orb.setPhase({
        phase: 'listening',
        tick: deps.getSettings().tickSound,
        ...(mode === 'dictate' ? {} : { mode }),
      });
      maxTimer = setTimeout(stop, MAX_RECORDING_MS);
    },

    stop,

    cancel() {
      if (state === 'listening') {
        clearMaxTimer();
        finish({ phase: 'cancelled' }, 0);
        return;
      }
      // A run in flight belongs to main: aborting it returns the session to
      // idle at once, and the sequence move strands whatever the handoff does
      // when it settles.
      if (state === 'transcribing' && mode === 'act') {
        sequence += 1;
        state = 'idle';
        deps.cancelAgent();
      }
    },

    async receiveAudio(audio) {
      if (state !== 'awaiting_audio') return;
      if (mode === 'explain') {
        // Whichever branch: the read that started at the gesture is what the
        // card is anchored to and answered from, never a second, later one.
        const snapshot = await explainSelection;
        if (audio.durationMs < MIN_AUDIO_MS) {
          finish({ phase: 'done' }, 0);
          void deps.explain.ask(undefined, snapshot);
          return;
        }
        state = 'transcribing';
        try {
          const fromSelection = selectionVocabulary(snapshot?.text ?? '');
          const heard = await deps.transcriber.transcribe(
            { data: audio.data, mimeType: audio.mimeType },
            {
              vocabulary: [deps.dictionary.prompt(), fromSelection].filter(Boolean).join(', '),
              // Words the user is looking at right now lead, as session words do.
              terms: [...fromSelection.split(', ').filter(Boolean), ...deps.dictionary.terms()],
            }
          );
          const spoken = heard && deps.dictionary.apply(heard);
          finish({ phase: 'done' }, 0);
          void deps.explain.ask(spoken || undefined, snapshot);
        } catch (error) {
          const message = error instanceof Error ? error.message : 'Something went wrong';
          finish({ phase: 'error', message }, ERROR_MS);
        }
        return;
      }

      if (audio.durationMs < MIN_AUDIO_MS) {
        finish({ phase: 'cancelled' }, 0);
        return;
      }

      if (mode === 'act') {
        state = 'transcribing';
        const mine = sequence;
        try {
          const heard = await deps.transcriber.transcribe(
            { data: audio.data, mimeType: audio.mimeType },
            { vocabulary: deps.dictionary.prompt(), terms: deps.dictionary.terms() }
          );
          if (mine !== sequence) return;
          const spoken = heard && deps.dictionary.apply(heard);
          if (!spoken) {
            finish({ phase: 'cancelled' }, 0);
            return;
          }
          // From here the pill is main's: progress, the approval question,
          // the result. The session only idles when the handoff resolves —
          // or lands nowhere, if a cancel or a new session moved on first.
          await deps.runAgent(spoken);
        } catch (error) {
          if (mine !== sequence) return;
          const message = error instanceof Error ? error.message : 'Something went wrong';
          finish({ phase: 'error', message }, ERROR_MS);
          return;
        }
        if (mine === sequence) state = 'idle';
        return;
      }

      state = 'transcribing';
      try {
        // The field is read while Whisper works: the gesture key is up by
        // now, so the keystroke fallback cannot collide with a held modifier.
        const [heard, target] = await Promise.all([
          deps.transcriber.transcribe(
            { data: audio.data, mimeType: audio.mimeType },
            { vocabulary: deps.dictionary.prompt(), terms: deps.dictionary.terms() }
          ),
          mode === 'edit' ? deps.editTargets.capture() : null,
        ]);
        // An instruction gets the same fixes: "sound like Shivaraj" names a person too.
        const spoken = heard && deps.dictionary.apply(heard);
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
          deps.onDictation?.(text);
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
