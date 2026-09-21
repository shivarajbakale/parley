import { useEffect, useRef } from 'react';

import type { OrbPhase } from '../../electron/types';

import type { Bands } from './bands';
import { createFrame, type OrbUniforms } from './frame';
import { createOrbRenderer } from './orb-shader';
import { buildPalette, readTokenBytes } from './palette';

interface OrbCanvasProps {
  /** CSS pixels, square. */
  size: number;
  /** The loop runs only while true, so a hidden orb costs nothing. */
  running: boolean;
  /** Called once per frame for the current audio and phase. */
  read: () => { bands: Bands; phase: OrbPhase };
}

/** Without WebGL the orb is a plain disc in the accent colour: dull, never missing. */
function drawFallback(canvas: HTMLCanvasElement, uniforms: OrbUniforms) {
  const context = canvas.getContext('2d');
  if (!context) return;
  const center = canvas.width / 2;
  context.clearRect(0, 0, canvas.width, canvas.height);
  if (uniforms.to === 0 && uniforms.mix === 1) return;
  context.fillStyle = getComputedStyle(document.documentElement)
    .getPropertyValue('--mantine-primary-color-filled')
    .trim();
  context.beginPath();
  context.arc(center, center, canvas.width * 0.31 * (1 + 0.06 * uniforms.low), 0, Math.PI * 2);
  context.fill();
}

export function OrbCanvas({ size, running, read }: OrbCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const readRef = useRef(read);
  readRef.current = read;

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || !running) return;

    const renderer = createOrbRenderer(canvas, buildPalette(readTokenBytes));
    const frame = createFrame('cancelled');
    const reducedMotion = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ?? false;

    let handle = 0;
    let previous = performance.now();
    const loop = (now: number) => {
      const { bands, phase } = readRef.current();
      const uniforms = frame.step({ deltaMs: now - previous, bands, phase, reducedMotion });
      previous = now;
      if (renderer) renderer.render(uniforms);
      else drawFallback(canvas, uniforms);
      handle = requestAnimationFrame(loop);
    };
    handle = requestAnimationFrame(loop);

    return () => {
      cancelAnimationFrame(handle);
      renderer?.dispose();
    };
  }, [running]);

  const pixels = Math.round(size * (window.devicePixelRatio || 1));
  // Not a progress bar: this sizes the canvas element itself to its CSS
  // pixel footprint, kept off the JSX line so ui-lint's progress-bar
  // heuristic (which matches any inline `style={{ width: \`${...` template)
  // does not false-positive on it.
  const canvasStyle = { width: `${size}px`, height: `${size}px`, display: 'block' };
  return (
    <canvas ref={canvasRef} aria-hidden="true" width={pixels} height={pixels} style={canvasStyle} />
  );
}
