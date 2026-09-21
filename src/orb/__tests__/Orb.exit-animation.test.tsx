import { act, render } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { ThemeProvider } from '@/components/theme-provider';

import type { OrbPhasePayload, ParleyApi } from '../../../electron/types';
import { Orb } from '../Orb';

describe('Orb keeps rendering through the exit animation', () => {
  let emit: (payload: OrbPhasePayload) => void;

  beforeEach(() => {
    vi.useFakeTimers();
    vi.spyOn(HTMLCanvasElement.prototype, 'getContext').mockReturnValue(
      null as unknown as CanvasRenderingContext2D
    );
    window.parley = {
      onOrbPhase: (listener: (payload: OrbPhasePayload) => void) => {
        emit = listener;
        return () => {};
      },
      sendAudio: vi.fn(),
    } as unknown as ParleyApi;
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('does not cancel the animation frame the instant `visible` goes false', async () => {
    render(
      <ThemeProvider defaultTheme="dark" storageKey="test-color-scheme">
        <Orb />
      </ThemeProvider>
    );

    await act(async () => emit({ phase: 'done' }));

    const raf = vi.spyOn(window, 'requestAnimationFrame');
    const caf = vi.spyOn(window, 'cancelAnimationFrame');

    // The done-hide delay fires setVisible(false). The `exiting` flag must
    // keep the loop alive (it must not simply freeze on the last frame), and
    // it must not get stuck forever once the exit animation reports done —
    // even with MotionGlobalConfig.skipAnimations true, as it is under test.
    await act(async () => vi.advanceTimersByTime(300));
    expect(raf).toHaveBeenCalled();
    // The `exiting` flag must not get stuck forever: once the exit animation
    // reports complete (synchronous here, since skipAnimations is true under
    // test), the loop is allowed to stop.
    expect(caf).toHaveBeenCalled();
  });
});
