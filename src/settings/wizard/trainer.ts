import { GAP_MAX_MS, HOLD_MIN_MS, TAP_MAX_MS } from '../../../electron/gesture-detector';

/**
 * The gesture trainer as a pure reducer. It mirrors `electron/gesture-detector`
 * — same three constants, same order of checks — but where the detector only
 * starts or stays quiet, this one also says why a try reset, so the trainer
 * can name the mistake. Time is passed in, so tests need no fake timers.
 */

export type TrainerMiss = 'tapTooLong' | 'gapTooLong' | 'releasedEarly';

export interface TrainerState {
  /** Quick presses completed so far. */
  taps: number;
  phase: 'idle' | 'tapping' | 'holding' | 'done';
  /** Why the last try reset. It stays up while the next try is under way,
   * so the hint does not blink away on the first good tap. */
  miss: TrainerMiss | null;
  downAt: number | null;
  lastUpAt: number | null;
}

export type TrainerEvent =
  | { type: 'down'; at: number }
  | { type: 'up'; at: number }
  /** A timer fired: the final press may be held long enough, or the gap
   * after a tap may have run out with no next press. */
  | { type: 'tick'; at: number };

export const TRAINER_START: TrainerState = {
  taps: 0,
  phase: 'idle',
  miss: null,
  downAt: null,
  lastUpAt: null,
};

function missed(miss: TrainerMiss): TrainerState {
  return { ...TRAINER_START, miss };
}

export function trainerStep(
  state: TrainerState,
  event: TrainerEvent,
  tapCount: number
): TrainerState {
  if (event.type === 'tick') {
    if (state.phase === 'holding' && state.downAt !== null && event.at - state.downAt >= HOLD_MIN_MS) {
      return { ...state, phase: 'done', miss: null };
    }
    if (
      state.phase === 'tapping' &&
      state.downAt === null &&
      state.lastUpAt !== null &&
      event.at - state.lastUpAt > GAP_MAX_MS
    ) {
      return missed('gapTooLong');
    }
    return state;
  }

  if (event.type === 'down') {
    // A finished gesture: the next press starts a fresh try.
    const from = state.phase === 'done' ? TRAINER_START : state;
    if (from.downAt !== null) return from; // auto-repeat
    let next = from;
    if (from.lastUpAt !== null && event.at - from.lastUpAt > GAP_MAX_MS) next = missed('gapTooLong');
    const holding = next.taps === tapCount - 1;
    return {
      ...next,
      downAt: event.at,
      phase: holding ? 'holding' : next.taps > 0 ? 'tapping' : next.phase,
    };
  }

  // up
  if (state.phase === 'done') return { ...state, downAt: null };
  if (state.downAt === null) return state;
  const heldFor = event.at - state.downAt;
  if (state.phase === 'holding') {
    return heldFor >= HOLD_MIN_MS ? { ...state, phase: 'done', downAt: null, miss: null } : missed('releasedEarly');
  }
  if (heldFor >= TAP_MAX_MS) return missed('tapTooLong');
  return { ...state, taps: state.taps + 1, phase: 'tapping', downAt: null, lastUpAt: event.at };
}

const seconds = (ms: number) => `${ms / 1000} s`;

export const MISS_COPY: Record<TrainerMiss, string> = {
  tapTooLong: `That tap was a hold — keep taps quick, under ${seconds(TAP_MAX_MS)}.`,
  gapTooLong: `Too slow between taps — keep them within ${seconds(GAP_MAX_MS)}.`,
  releasedEarly: 'Hold the last press a moment longer.',
};
