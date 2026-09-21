import type {
  OrbPhase,
  OrbPhasePayload,
  RecordedAudio,
  SessionMode,
} from '../../electron/types';

import type { Recorder } from './recorder';
import type { SoundName } from './sounds';

/**
 * Sent on `transcribing` when there is no real recording (start failed, or
 * stop() found nothing). The main-process session is waiting on exactly one
 * `sendAudio` call to leave `awaiting_audio`; it already discards anything
 * shorter than 300ms, so this empty payload ends the session cleanly instead
 * of leaving it stuck forever.
 */
const EMPTY_AUDIO: RecordedAudio = { data: new ArrayBuffer(0), mimeType: '', durationMs: 0 };

// Main shows `done` for DONE_MS then hides the window after DONE_MS + FADE_MS
// (see electron/session.ts). This local delay must leave at least 150ms of
// margin before that hide, or the window can vanish mid fade-out; 600ms (the
// originally desired value, to give the done look real dwell time) would
// leave none, so this is clamped to the largest round value that keeps the
// margin: (DONE_MS + FADE_MS) - 150 = 300.
const HIDE_DELAY_DONE_MS = 300;
const HIDE_DELAY_ERROR_MS = 3000;

export interface PhaseHandlerDeps {
  recorder: Recorder;
  sendAudio: (audio: RecordedAudio) => void;
  playSound: (sound: SoundName, mode: SessionMode) => void;
  onPhase: (phase: OrbPhase) => void;
  /** Called as a session starts, so the orb wears that session's hue to the end. */
  onMode: (mode: SessionMode) => void;
  setVisible: (visible: boolean) => void;
  setMessage: (message: string) => void;
}

export interface PhaseHandler {
  handlePhase(payload: OrbPhasePayload): Promise<void>;
  /** Clears any pending hide timer. Call on unmount. */
  dispose(): void;
}

/**
 * Turns `orb:phase` events into recorder calls and visibility/message state.
 * Pulled out of the component so it is testable with a fake recorder and a
 * fake `sendAudio`, with no real media APIs involved.
 */
export function createPhaseHandler(deps: PhaseHandlerDeps): PhaseHandler {
  const { recorder, sendAudio, playSound, onPhase, onMode, setVisible, setMessage } = deps;
  // Both arrive with `listening` and hold until the next one: the later
  // phases of a session do not repeat them.
  let sessionMode: SessionMode = 'dictate';
  let sounds = false;
  let hideTimer: ReturnType<typeof setTimeout> | null = null;

  function clearHideTimer() {
    if (hideTimer !== null) {
      clearTimeout(hideTimer);
      hideTimer = null;
    }
  }

  function scheduleHide(delayMs: number) {
    hideTimer = setTimeout(() => setVisible(false), delayMs);
  }

  async function handlePhase({ phase, message, tick, mode }: OrbPhasePayload) {
    // A new phase always supersedes any pending hide from a previous done/error.
    clearHideTimer();
    onPhase(phase);
    if (phase === 'listening') {
      sessionMode = mode ?? 'dictate';
      sounds = tick ?? false;
      onMode(sessionMode);
    }
    setMessage(phase === 'error' ? (message ?? '') : '');
    setVisible(phase !== 'cancelled');

    if (phase === 'listening') {
      if (sounds) playSound('start', sessionMode);
      try {
        await recorder.start();
      } catch {
        setMessage('Could not access the microphone.');
      }
    } else if (phase === 'transcribing') {
      let audio: RecordedAudio | null = null;
      try {
        audio = await recorder.stop();
      } catch {
        audio = null;
      }
      if (tick) playSound('stop', sessionMode);
      // Exactly one sendAudio per transcribing, real or empty: main is
      // blocked in `awaiting_audio` until this call happens.
      sendAudio(audio ?? EMPTY_AUDIO);
    } else if (phase === 'cancelled') {
      recorder.discard();
    } else if (phase === 'done') {
      if (sounds) playSound('done', sessionMode);
      // Main hides the window after the flash; start the fade just before.
      scheduleHide(HIDE_DELAY_DONE_MS);
    } else if (phase === 'error') {
      scheduleHide(HIDE_DELAY_ERROR_MS);
    }
  }

  return {
    handlePhase,
    dispose: clearHideTimer,
  };
}
