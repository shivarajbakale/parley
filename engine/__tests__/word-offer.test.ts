import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { GAP_MAX_MS } from '../gesture-detector';
import { NOTICE_ACCEPTED_MS, NOTICE_MS, type KeyEvent, type KeyName } from '../types';
import { createWordOffer } from '../word-offer';

const correction = { heard: 'mini max', word: 'MiniMax' };

function setup(idle = true) {
  const orb = { show: vi.fn(), hide: vi.fn(), setPhase: vi.fn() };
  const onAccept = vi.fn();
  const onDecline = vi.fn();
  const offer = createWordOffer({
    orb,
    isIdle: () => idle,
    key: () => 'Shift',
    onAccept,
    onDecline,
  });
  let time = 0;
  const key = (type: KeyEvent['type'], name: KeyName, after = 10) => {
    time += after;
    offer.handleKey({ type, key: name, time });
  };
  const tap = (name: KeyName = 'Shift') => {
    key('down', name);
    key('up', name, 80);
  };
  return { offer, orb, onAccept, onDecline, key, tap };
}

describe('word offer', () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it('asks on the pill, naming the key that says yes', () => {
    const { offer, orb } = setup();
    offer.offer(correction);
    expect(orb.show).toHaveBeenCalled();
    expect(orb.setPhase).toHaveBeenCalledWith({
      phase: 'notice',
      message: 'Remember “MiniMax”?',
      hint: 'Tap Shift to save',
    });
  });

  it('a clean tap accepts, once a second tap can no longer follow', () => {
    const { offer, orb, onAccept, tap } = setup();
    offer.offer(correction);
    tap();
    expect(onAccept).not.toHaveBeenCalled();
    vi.advanceTimersByTime(GAP_MAX_MS + 50);
    expect(onAccept).toHaveBeenCalledExactlyOnceWith(correction);
    expect(orb.setPhase).toHaveBeenLastCalledWith({
      phase: 'notice',
      message: 'Added “MiniMax”',
      accepted: true,
    });
    vi.advanceTimersByTime(NOTICE_ACCEPTED_MS);
    expect(orb.hide).toHaveBeenCalledTimes(1);
  });

  it('the first tap of a dictation gesture is not a yes', () => {
    const { offer, onAccept, tap, key } = setup();
    offer.offer(correction);
    tap();
    key('down', 'Shift', 120);
    vi.advanceTimersByTime(NOTICE_MS);
    expect(onAccept).not.toHaveBeenCalled();
  });

  it('Shift held to type a capital is not a yes', () => {
    const { offer, onAccept, key } = setup();
    offer.offer(correction);
    key('down', 'Shift');
    key('down', 'Other', 40);
    key('up', 'Other', 40);
    key('up', 'Shift', 40);
    vi.advanceTimersByTime(GAP_MAX_MS + 50);
    expect(onAccept).not.toHaveBeenCalled();
  });

  it('a long press is not a yes', () => {
    const { offer, onAccept, key } = setup();
    offer.offer(correction);
    key('down', 'Shift');
    key('up', 'Shift', 600);
    vi.advanceTimersByTime(GAP_MAX_MS + 50);
    expect(onAccept).not.toHaveBeenCalled();
  });

  it('ignored, it declines and hides', () => {
    const { offer, orb, onDecline, onAccept, tap } = setup();
    offer.offer(correction);
    vi.advanceTimersByTime(NOTICE_MS);
    expect(onDecline).toHaveBeenCalledExactlyOnceWith(correction);
    expect(orb.hide).toHaveBeenCalledTimes(1);
    tap();
    vi.advanceTimersByTime(GAP_MAX_MS + 50);
    expect(onAccept).not.toHaveBeenCalled();
  });

  it('never covers a dictation', () => {
    const { offer, orb } = setup(false);
    offer.offer(correction);
    expect(orb.show).not.toHaveBeenCalled();
  });

  it('cancel hands the pill to a session without hiding it or declining', () => {
    const { offer, orb, onDecline } = setup();
    offer.offer(correction);
    offer.cancel();
    vi.advanceTimersByTime(NOTICE_MS);
    expect(orb.hide).not.toHaveBeenCalled();
    expect(onDecline).not.toHaveBeenCalled();
  });

  it('cancel also stops the hide that follows an accept', () => {
    const { offer, orb, tap } = setup();
    offer.offer(correction);
    tap();
    vi.advanceTimersByTime(GAP_MAX_MS + 50);
    offer.cancel();
    vi.advanceTimersByTime(NOTICE_ACCEPTED_MS);
    expect(orb.hide).not.toHaveBeenCalled();
  });
});
