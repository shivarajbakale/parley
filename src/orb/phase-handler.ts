import type { OrbPhase, OrbPhasePayload, RecordedAudio } from '../../electron/types';

import type { Recorder } from './recorder';

/**
 * Sent on `transcribing` when there is no real recording (start failed, or
 * stop() found nothing). The main-process session is waiting on exactly one
 * `sendAudio` call to leave `awaiting_audio`; it already discards anything
 * shorter than 300ms, so this empty payload ends the session cleanly instead
 * of leaving it stuck forever.
 */
const EMPTY_AUDIO: RecordedAudio = { data: new ArrayBuffer(0), mimeType: '', durationMs: 0 };

const HIDE_DELAY_DONE_MS = 300;
const HIDE_DELAY_ERROR_MS = 3000;

export interface PhaseHandlerDeps {
  recorder: Recorder;
  sendAudio: (audio: RecordedAudio) => void;
  playTick: () => void;
  onPhase: (phase: OrbPhase) => void;
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
  const { recorder, sendAudio, playTick, onPhase, setVisible, setMessage } = deps;
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

  async function handlePhase({ phase, message, tick }: OrbPhasePayload) {
    // A new phase always supersedes any pending hide from a previous done/error.
    clearHideTimer();
    onPhase(phase);
    setMessage(phase === 'error' ? (message ?? '') : '');
    setVisible(phase !== 'cancelled');

    if (phase === 'listening') {
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
      if (tick) playTick();
      // Exactly one sendAudio per transcribing, real or empty: main is
      // blocked in `awaiting_audio` until this call happens.
      sendAudio(audio ?? EMPTY_AUDIO);
    } else if (phase === 'cancelled') {
      recorder.discard();
    } else if (phase === 'done') {
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
