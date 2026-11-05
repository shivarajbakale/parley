import { GAP_MAX_MS, TAP_MAX_MS } from '../gesture-detector';
import { NOTICE_ACCEPTED_MS, NOTICE_MS, type GestureKey, type KeyEvent, type OrbPhasePayload } from '../types';
import { KEY_LABELS } from '../word-offer';

/**
 * "Delete 3 events?" The pill asks, and one clean tap of the act key says
 * yes — the word offer's motor pattern, with no expiry: a waiting approval
 * sits until it is answered. Esc or a new command is no; the Agent tab's
 * Approve/Decline buttons are the keyboard path to the same tap.
 *
 * A tap only counts once the gap for a second tap has passed, because the
 * act gesture itself begins with taps of the same key.
 */

export interface ActionConfirmCall {
  callId: string;
  summary: string;
  transcript: string;
}

export interface ActionConfirm {
  ask(call: ActionConfirmCall): void;
  handleKey(event: KeyEvent): void;
  /** False when the call is stale — someone else already answered. */
  answerFromTab(callId: string, approved: boolean): Promise<boolean>;
  /** Esc with a question on screen: no, with an acknowledgement. */
  decline(): void;
  /** A new session or quit is taking the pill over. The question is dropped,
   * neither taken nor declined — the run itself is cancelled elsewhere. */
  cancel(): void;
}

export function createActionConfirm(deps: {
  orb: { show(): void; hide(): void; setPhase(payload: OrbPhasePayload): void };
  key(): GestureKey;
  /** Reads the question aloud — the arrival cue, since notices take no tick. */
  speak(text: string): void;
  approve(callId: string): Promise<void>;
  decline(callId: string): Promise<void>;
  /** Repaint the working notice: the question is answered, the run goes on. */
  resume(): void;
  /** The answer never reached the server. The run is stuck suspended, so the
   * caller fails it — resuming would paint progress over a dead run. */
  onDecisionFailed(error: unknown): void;
}): ActionConfirm {
  let pending: ActionConfirmCall | null = null;
  let generation = 0;
  let acceptTimer: ReturnType<typeof setTimeout> | undefined;
  let flashTimer: ReturnType<typeof setTimeout> | undefined;
  let heartbeat: ReturnType<typeof setTimeout> | undefined;
  let flashDone: (() => void) | null = null;
  let downAt: number | null = null;

  function clearTimers() {
    for (const timer of [acceptTimer, flashTimer, heartbeat]) if (timer) clearTimeout(timer);
    acceptTimer = flashTimer = heartbeat = undefined;
    // A cancelled flash resolves at once; the generation guard below decides
    // whether the run still wants what comes after it.
    flashDone?.();
    flashDone = null;
    downAt = null;
  }

  function flash(ms: number): Promise<void> {
    return new Promise(resolve => {
      flashDone = resolve;
      flashTimer = setTimeout(() => {
        flashTimer = undefined;
        flashDone = null;
        resolve();
      }, ms);
    });
  }

  function paintQuestion(call: ActionConfirmCall): void {
    deps.orb.setPhase({
      phase: 'notice',
      message: call.summary,
      hint: `From “${call.transcript}” · Tap ${KEY_LABELS[deps.key()]} to run · Esc cancels`,
    });
  }

  /** The renderer folds any notice after six seconds; a waiting approval
   * repaints itself just before, so the question sits until it is answered. */
  function beat(): void {
    heartbeat = setTimeout(() => {
      heartbeat = undefined;
      if (!pending) return;
      paintQuestion(pending);
      beat();
    }, NOTICE_MS - 1000);
  }

  async function decide(approved: boolean): Promise<void> {
    const call = pending;
    if (!call) return;
    const mine = generation;
    pending = null;
    clearTimers();
    try {
      if (approved) {
        await deps.approve(call.callId);
        if (mine === generation) deps.resume();
      } else {
        await deps.decline(call.callId);
        if (mine !== generation) return;
        deps.orb.setPhase({ phase: 'notice', message: 'Skipped — continuing…' });
        await flash(NOTICE_ACCEPTED_MS);
        if (mine === generation) deps.resume();
      }
    } catch (error) {
      if (mine === generation) deps.onDecisionFailed(error);
    }
  }

  return {
    ask(call) {
      if (pending) return;
      pending = call;
      deps.orb.show();
      paintQuestion(call);
      deps.speak(call.summary);
      beat();
    },

    handleKey(event: KeyEvent) {
      if (!pending) return;
      if (event.type === 'down') {
        // Any key going down ends a tap that was waiting to count: it was the
        // start of a gesture, or the user is simply typing.
        if (acceptTimer) clearTimeout(acceptTimer);
        acceptTimer = undefined;
        downAt = event.key === deps.key() && downAt === null ? event.time : null;
        return;
      }
      if (event.key !== deps.key() || downAt === null) return;
      const held = event.time - downAt;
      downAt = null;
      if (held <= TAP_MAX_MS) acceptTimer = setTimeout(() => void decide(true), GAP_MAX_MS + 50);
    },

    async answerFromTab(callId, approved) {
      if (!pending || pending.callId !== callId) return false;
      await decide(approved);
      return true;
    },

    decline() {
      if (!pending) return;
      void decide(false);
    },

    cancel() {
      generation += 1;
      pending = null;
      clearTimers();
    },
  };
}
