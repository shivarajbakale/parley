import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { GAP_MAX_MS } from '../../gesture-detector';
import type { KeyEvent, OrbPhasePayload } from '../../types';
import { createActionConfirm, type ActionConfirmCall } from '../confirm';

const CALL: ActionConfirmCall = {
  callId: 'c9',
  summary: 'Delete 3 events?',
  transcript: 'clear my tuesday',
};

function deps(over: Record<string, unknown> = {}) {
  const phases: OrbPhasePayload[] = [];
  return {
    phases,
    ...( {
      orb: {
        show: vi.fn(),
        hide: vi.fn(),
        setPhase: vi.fn((payload: OrbPhasePayload) => phases.push(payload)),
      },
      key: () => 'ShiftRight' as const,
      speak: vi.fn(),
      approve: vi.fn(async (_callId: string) => {}),
      decline: vi.fn(async (_callId: string) => {}),
      resume: vi.fn(),
      onDecisionFailed: vi.fn(),
    } ),
    ...over,
  };
}

function tap(downAt: number, heldMs = 100): KeyEvent[] {
  return [
    { type: 'down', key: 'ShiftRight', time: downAt },
    { type: 'up', key: 'ShiftRight', time: downAt + heldMs },
  ];
}

describe('action confirm', () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it('asks with the summary, the transcript, the key and the way out', () => {
    const d = deps();
    const confirm = createActionConfirm(d);
    confirm.ask(CALL);
    expect(d.orb.show).toHaveBeenCalledTimes(1);
    expect(d.phases).toEqual([
      {
        phase: 'notice',
        message: 'Delete 3 events?',
        hint: 'From “clear my tuesday” · Tap Right Shift to run · Esc cancels',
      },
    ]);
    expect(d.speak).toHaveBeenCalledWith('Delete 3 events?');
  });

  it('repaints the question before the renderer folds it, until answered', async () => {
    const d = deps();
    const confirm = createActionConfirm(d);
    confirm.ask(CALL);
    await vi.advanceTimersByTimeAsync(5000);
    expect(d.orb.setPhase).toHaveBeenCalledTimes(2);
    await expect(confirm.answerFromTab('c9', true)).resolves.toBe(true);
    await vi.advanceTimersByTimeAsync(20000);
    expect(d.orb.setPhase).toHaveBeenCalledTimes(2);
  });

  it('runs on one clean tap of the act key, then resumes the run', async () => {
    const d = deps();
    const confirm = createActionConfirm(d);
    confirm.ask(CALL);
    for (const event of tap(1000)) confirm.handleKey(event);
    await vi.advanceTimersByTimeAsync(GAP_MAX_MS + 50);
    expect(d.approve).toHaveBeenCalledWith('c9');
    expect(d.decline).not.toHaveBeenCalled();
    expect(d.resume).toHaveBeenCalledTimes(1);
  });

  it('ignores a tap that turns into typing or a gesture', async () => {
    const d = deps();
    const confirm = createActionConfirm(d);
    confirm.ask(CALL);
    confirm.handleKey({ type: 'down', key: 'ShiftRight', time: 1000 });
    confirm.handleKey({ type: 'down', key: 'Other', time: 1050 });
    confirm.handleKey({ type: 'up', key: 'ShiftRight', time: 1100 });
    await vi.advanceTimersByTimeAsync(GAP_MAX_MS + 50);
    expect(d.approve).not.toHaveBeenCalled();
    expect(d.resume).not.toHaveBeenCalled();
  });

  it('declines with a Skipped flash before resuming', async () => {
    const d = deps();
    const confirm = createActionConfirm(d);
    confirm.ask(CALL);
    confirm.decline();
    await vi.advanceTimersByTimeAsync(0);
    expect(d.decline).toHaveBeenCalledWith('c9');
    expect(d.phases.at(-1)).toMatchObject({
      phase: 'notice',
      message: 'Skipped — continuing…',
    });
    expect(d.resume).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(900);
    expect(d.resume).toHaveBeenCalledTimes(1);
  });

  it('answers from the tab only when the call still matches', async () => {
    const d = deps();
    const confirm = createActionConfirm(d);
    confirm.ask(CALL);
    await expect(confirm.answerFromTab('stale', true)).resolves.toBe(false);
    expect(d.approve).not.toHaveBeenCalled();
    await expect(confirm.answerFromTab('c9', true)).resolves.toBe(true);
    expect(d.approve).toHaveBeenCalledWith('c9');
    expect(d.resume).toHaveBeenCalledTimes(1);
  });

  it('keeps the first question when a second arrives', async () => {
    const d = deps();
    const confirm = createActionConfirm(d);
    confirm.ask(CALL);
    confirm.ask({ callId: 'c10', summary: 'Wipe everything?', transcript: 'wipe' });
    await expect(confirm.answerFromTab('c10', true)).resolves.toBe(false);
    await expect(confirm.answerFromTab('c9', true)).resolves.toBe(true);
    expect(d.approve).toHaveBeenCalledWith('c9');
  });

  it('drops silently on cancel: a later tap answers nothing', async () => {
    const d = deps();
    const confirm = createActionConfirm(d);
    confirm.ask(CALL);
    confirm.cancel();
    for (const event of tap(1000)) confirm.handleKey(event);
    await vi.advanceTimersByTimeAsync(GAP_MAX_MS + 50);
    expect(d.approve).not.toHaveBeenCalled();
    expect(d.decline).not.toHaveBeenCalled();
    expect(d.resume).not.toHaveBeenCalled();
  });

  it('reports a failed decision instead of resuming into a stuck run', async () => {
    const failure = new Error('refused on :4111');
    const d = deps({ approve: vi.fn(async () => { throw failure; }) });
    const confirm = createActionConfirm(d);
    confirm.ask(CALL);
    await expect(confirm.answerFromTab('c9', true)).resolves.toBe(true);
    expect(d.onDecisionFailed).toHaveBeenCalledWith(failure);
    expect(d.resume).not.toHaveBeenCalled();
  });
});
