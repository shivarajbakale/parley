import { render } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { OrbCanvas } from '../OrbCanvas';

const read = () => ({ bands: { low: 0, mid: 0, high: 0 }, phase: 'listening' as const });

describe('OrbCanvas', () => {
  let getContext: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    // jsdom has no WebGL: this is the fallback path every test machine takes.
    getContext = vi.fn().mockReturnValue(null);
    vi.spyOn(HTMLCanvasElement.prototype, 'getContext').mockImplementation(getContext);
  });

  afterEach(() => vi.restoreAllMocks());

  it('renders a canvas at device-pixel resolution and CSS size', () => {
    vi.stubGlobal('devicePixelRatio', 2);
    const { container } = render(<OrbCanvas size={240} running read={read} />);
    const canvas = container.querySelector('canvas')!;
    expect(canvas.width).toBe(480);
    expect(canvas.style.width).toBe('240px');
    vi.unstubAllGlobals();
  });

  it('is decorative to assistive technology', () => {
    const { container } = render(<OrbCanvas size={48} running read={read} />);
    expect(container.querySelector('canvas')).toHaveAttribute('aria-hidden', 'true');
  });

  it('asks for WebGL first and survives not getting it', () => {
    render(<OrbCanvas size={240} running read={read} />);
    expect(getContext).toHaveBeenCalledWith('webgl', expect.anything());
  });

  it('does not animate while not running', () => {
    const raf = vi.spyOn(window, 'requestAnimationFrame');
    render(<OrbCanvas size={240} running={false} read={read} />);
    expect(raf).not.toHaveBeenCalled();
  });
});
