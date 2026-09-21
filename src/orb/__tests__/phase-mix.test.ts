import { describe, expect, it } from 'vitest';

import { createPhaseMix, PHASE_FADE_MS } from '../phase-mix';

describe('createPhaseMix', () => {
  it('starts settled on the initial phase', () => {
    expect(createPhaseMix('cancelled').advance(16)).toEqual({
      from: 'cancelled',
      to: 'cancelled',
      mix: 1,
    });
  });

  it('fades linearly to a new phase over the fade time', () => {
    const phaseMix = createPhaseMix('cancelled');
    phaseMix.set('listening');
    expect(phaseMix.advance(PHASE_FADE_MS / 2)).toEqual({
      from: 'cancelled',
      to: 'listening',
      mix: 0.5,
    });
    expect(phaseMix.advance(PHASE_FADE_MS).mix).toBe(1);
  });

  it('ignores a repeat of the current target', () => {
    const phaseMix = createPhaseMix('cancelled');
    phaseMix.set('listening');
    phaseMix.advance(150);
    phaseMix.set('listening');
    expect(phaseMix.advance(0).mix).toBe(0.5);
  });

  it('fades on from the previous target when interrupted', () => {
    const phaseMix = createPhaseMix('cancelled');
    phaseMix.set('listening');
    phaseMix.advance(100);
    phaseMix.set('transcribing');
    expect(phaseMix.advance(0)).toEqual({ from: 'listening', to: 'transcribing', mix: 0 });
  });
});
