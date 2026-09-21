import { render } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { OrbCanvas } from '../OrbCanvas';
import * as orbShader from '../orb-shader';

const read = () => ({ bands: { low: 0, mid: 0, high: 0 }, phase: 'listening' as const });

describe('OrbCanvas WebGL fallback and recovery', () => {
  afterEach(() => vi.restoreAllMocks());

  it('requests a fresh canvas for the 2D fallback when the renderer fails to build', () => {
    vi.spyOn(orbShader, 'createOrbRenderer').mockReturnValue(null);
    const getContext = vi.fn().mockReturnValue({});
    vi.spyOn(HTMLCanvasElement.prototype, 'getContext').mockImplementation(getContext);

    const { container } = render(<OrbCanvas size={240} running read={read} />);

    // The mount tries WebGL once; createOrbRenderer (mocked) reports failure,
    // so the component swaps in a brand-new canvas keyed for the '2d' mode.
    // That new canvas must never have had getContext('webgl') called on it.
    const finalCanvas = container.querySelector('canvas')!;
    const callsOnFinalCanvas = getContext.mock.calls.filter(
      (_, index) => getContext.mock.instances[index] === finalCanvas
    );
    expect(callsOnFinalCanvas.some(([type]) => type === 'webgl')).toBe(false);
  });

  it('recovers from a lost WebGL context without disposing the dead context', () => {
    let lostHandler: EventListenerOrEventListenerObject | undefined;
    const addEventListener = vi.fn((event: string, handler: EventListenerOrEventListenerObject) => {
      if (event === 'webglcontextlost') lostHandler = handler;
    });
    vi.spyOn(HTMLCanvasElement.prototype, 'addEventListener').mockImplementation(addEventListener);

    const dispose = vi.fn();
    const createSpy = vi
      .spyOn(orbShader, 'createOrbRenderer')
      .mockReturnValue({ render: vi.fn(), dispose });

    render(<OrbCanvas size={240} running read={read} />);
    expect(lostHandler).toBeDefined();

    const preventDefault = vi.fn();
    (lostHandler as EventListener)({ preventDefault } as unknown as Event);

    expect(preventDefault).toHaveBeenCalled();
    // The dead context is never disposed.
    expect(dispose).not.toHaveBeenCalled();
    expect(createSpy).toHaveBeenCalledTimes(1);
  });
});
