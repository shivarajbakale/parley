import { describe, expect, it } from 'vitest';

import { GAP_MAX_MS, HOLD_MIN_MS, TAP_MAX_MS } from '../../../electron/gesture-detector';
import { TRAINER_START, trainerStep, type TrainerEvent, type TrainerState } from '../wizard/trainer';

function run(events: TrainerEvent[], tapCount = 3): TrainerState {
  return events.reduce((state, event) => trainerStep(state, event, tapCount), TRAINER_START);
}

const tap = (at: number): TrainerEvent[] => [
  { type: 'down', at },
  { type: 'up', at: at + 50 },
];

describe('gesture trainer', () => {
  it('counts quick taps', () => {
    const state = run([...tap(0), ...tap(150)]);
    expect(state.taps).toBe(2);
    expect(state.phase).toBe('tapping');
  });

  it('enters the hold on the final press and completes once held long enough', () => {
    const holding = run([...tap(0), ...tap(150), { type: 'down', at: 300 }]);
    expect(holding.phase).toBe('holding');
    expect(trainerStep(holding, { type: 'tick', at: 300 + HOLD_MIN_MS - 1 }, 3).phase).toBe(
      'holding'
    );
    expect(trainerStep(holding, { type: 'tick', at: 300 + HOLD_MIN_MS }, 3).phase).toBe('done');
  });

  it('completes on release when the hold timer has not fired yet', () => {
    const state = run([...tap(0), ...tap(150), { type: 'down', at: 300 }, { type: 'up', at: 300 + HOLD_MIN_MS }]);
    expect(state.phase).toBe('done');
  });

  it('names a tap held too long', () => {
    const state = run([{ type: 'down', at: 0 }, { type: 'up', at: TAP_MAX_MS }]);
    expect(state).toMatchObject({ phase: 'idle', taps: 0, miss: 'tapTooLong' });
  });

  it('names a gap too long, and counts the late press as a fresh first tap', () => {
    const state = run([...tap(0), ...tap(50 + GAP_MAX_MS + 1)]);
    expect(state).toMatchObject({ taps: 1, miss: 'gapTooLong' });
  });

  it('resets with the gap reason when the next press never comes', () => {
    const tapped = run([...tap(0)]);
    expect(trainerStep(tapped, { type: 'tick', at: 50 + GAP_MAX_MS }, 3).phase).toBe('tapping');
    expect(trainerStep(tapped, { type: 'tick', at: 51 + GAP_MAX_MS }, 3)).toMatchObject({
      phase: 'idle',
      taps: 0,
      miss: 'gapTooLong',
    });
  });

  it('names a hold let go too early', () => {
    const state = run([...tap(0), ...tap(150), { type: 'down', at: 300 }, { type: 'up', at: 340 }]);
    expect(state).toMatchObject({ phase: 'idle', taps: 0, miss: 'releasedEarly' });
  });

  it('ignores auto-repeat downs', () => {
    const state = run([{ type: 'down', at: 0 }, { type: 'down', at: 30 }, { type: 'up', at: 60 }]);
    expect(state.taps).toBe(1);
  });

  it('starts a fresh try after a finished gesture', () => {
    const done = run([...tap(0), { type: 'down', at: 150 }, { type: 'tick', at: 150 + HOLD_MIN_MS }], 2);
    expect(done.phase).toBe('done');
    const again = trainerStep(trainerStep(done, { type: 'up', at: 400 }, 2), { type: 'down', at: 2000 }, 2);
    expect(again).toMatchObject({ phase: 'idle', taps: 0, miss: null });
  });
});
