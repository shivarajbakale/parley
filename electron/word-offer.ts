import type { Correction } from './correction-detect';
import { GAP_MAX_MS, TAP_MAX_MS } from './gesture-detector';
import {
  NOTICE_ACCEPTED_MS,
  NOTICE_MS,
  type GestureKey, type KeyEvent, type OrbPhasePayload,
} from './types';

/**
 * "Remember MiniMax?" The pill asks, and one clean tap of the dictation key
 * says yes. Nothing else can: Parley never takes a key away from the app the
 * user is typing in, so Enter is not available to it.
 *
 * A tap only counts once the gap for a second tap has passed, because the
 * dictation gesture itself begins with a tap of the same key.
 */

export const KEY_LABELS: Record<GestureKey, string> = {
  AltRight: 'Right Option',
  Alt: 'Option',
  CtrlRight: 'Right Control',
  Ctrl: 'Control',
  ShiftRight: 'Right Shift',
  Shift: 'Shift',
  MetaRight: 'Right Command',
  Meta: 'Command',
};

export interface WordOffer {
  offer(correction: Correction): void;
  handleKey(event: KeyEvent): void;
  /** A session is taking the pill over. The offer is dropped, neither taken nor declined. */
  cancel(): void;
}

export function createWordOffer(deps: {
  orb: { show(): void; hide(): void; setPhase(payload: OrbPhasePayload): void };
  /** No offer may cover a dictation. */
  isIdle(): boolean;
  key(): GestureKey;
  onAccept(correction: Correction): void;
  onDecline(correction: Correction): void;
}): WordOffer {
  let pending: Correction | null = null;
  let expiry: ReturnType<typeof setTimeout> | undefined;
  let acceptTimer: ReturnType<typeof setTimeout> | undefined;
  let hideTimer: ReturnType<typeof setTimeout> | undefined;
  let downAt: number | null = null;

  function clearTimers() {
    for (const timer of [expiry, acceptTimer, hideTimer]) if (timer) clearTimeout(timer);
    expiry = acceptTimer = hideTimer = undefined;
    downAt = null;
  }

  function accept() {
    const correction = pending;
    if (!correction) return;
    pending = null;
    clearTimers();
    deps.onAccept(correction);
    deps.orb.setPhase({ phase: 'notice', message: `Added “${correction.word}”`, accepted: true });
    hideTimer = setTimeout(() => deps.orb.hide(), NOTICE_ACCEPTED_MS);
  }

  return {
    offer(correction) {
      if (!deps.isIdle() || pending) return;
      clearTimers();
      pending = correction;
      deps.orb.show();
      deps.orb.setPhase({
        phase: 'notice',
        message: `Remember “${correction.word}”?`,
        hint: `Tap ${KEY_LABELS[deps.key()]} to save`,
      });
      expiry = setTimeout(() => {
        pending = null;
        clearTimers();
        deps.orb.hide();
        deps.onDecline(correction);
      }, NOTICE_MS);
    },

    handleKey(event) {
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
      if (held <= TAP_MAX_MS) acceptTimer = setTimeout(accept, GAP_MAX_MS + 50);
    },

    cancel() {
      if (!pending && !hideTimer) return;
      pending = null;
      clearTimers();
    },
  };
}
