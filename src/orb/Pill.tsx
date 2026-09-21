import { useEffect, useRef } from 'react';

import type { OrbPhase, SessionMode } from '../../electron/types';

import type { Bands } from './bands';
import { createFrame, type OrbUniforms } from './frame';
import { PHASE_INDEX } from './phase-mix';
import { BAR_COUNT, pillBars, pillOpacity } from './pill-bars';

const PILL_SIZE = { width: 148, height: 40 };
/** Room around the capsule for its glow, inside the canvas. */
const GLOW_PAD = 24;

const BAR_WIDTH = 5;
const BAR_GAP = 7;
const BAR_ROOM = 22;

/**
 * The pill grows on a spring. Underdamped on the way in, so it overshoots and
 * bounces back into place; critically damped on the way out, so it just folds.
 */
const SPRING_STIFFNESS = 320;
const SPRING_DAMPING_IN = 20;
const SPRING_DAMPING_OUT = 2 * Math.sqrt(SPRING_STIFFNESS);

interface PillProps {
  /** The loop runs only while true, so a hidden pill costs nothing. */
  running: boolean;
  /** Opens from a dot when true, folds back into one when false. */
  shown: boolean;
  /** Called once per frame for the current audio, phase and session mode. */
  read: () => { bands: Bands; phase: OrbPhase; mode?: SessionMode };
}

/** Colours are theme tokens, resolved once per frame: a theme switch just shows up. */
function token(name: string): string {
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
}

function barTokens(uniforms: OrbUniforms, mode: SessionMode): [string, string] {
  if (uniforms.to === PHASE_INDEX.done) {
    return ['--mantine-color-teal-6', '--mantine-color-teal-4'];
  }
  if (uniforms.to === PHASE_INDEX.error) return ['--mantine-color-red-7', '--mantine-color-red-5'];
  return mode === 'edit'
    ? ['--app-lilac-core', '--app-lilac-glow']
    : ['--app-aurora-core', '--app-aurora-glow'];
}

function draw(
  canvas: HTMLCanvasElement,
  uniforms: OrbUniforms,
  mode: SessionMode,
  presence: number
) {
  const context = canvas.getContext('2d');
  if (!context) return;
  const scale = canvas.width / (PILL_SIZE.width + GLOW_PAD * 2);
  context.setTransform(scale, 0, 0, scale, 0, 0);
  context.clearRect(0, 0, canvas.width, canvas.height);

  if (presence <= 0.001 || pillOpacity(uniforms) <= 0) return;

  const [deep, glow] = barTokens(uniforms, mode).map(token);
  // Mantine writes its variables a moment after mount; a gradient stop of ''
  // throws, so wait for them rather than crash the frame loop.
  if (!deep || !glow) return;

  // Grows from a speck: first a dot that swells, then the dot stretches into
  // the capsule. `presence` passes 1 while the spring overshoots, so both the
  // height and the stretch bounce.
  const height = PILL_SIZE.height * presence;
  const width = height + (PILL_SIZE.width - PILL_SIZE.height) * presence ** 1.8;
  const x = GLOW_PAD + (PILL_SIZE.width - width) / 2;
  const y = GLOW_PAD + (PILL_SIZE.height - height) / 2;
  const capsule = () => {
    context.beginPath();
    context.roundRect(x, y, width, height, height / 2);
  };
  context.globalAlpha = Math.min(1, presence * 2.5);

  // Tinted glass, not a black slug: a thin dark base so the bars stay legible
  // over any wallpaper, washed with the session's own colour.
  capsule();
  context.shadowColor = deep;
  context.shadowBlur = 16 + 12 * uniforms.low;
  context.fillStyle = token('--mantine-color-dark-7');
  context.globalAlpha *= 0.74;
  context.fill();
  context.shadowBlur = 0;
  context.globalAlpha = Math.min(1, presence * 2.5);

  const tint = context.createLinearGradient(0, y, 0, y + height);
  tint.addColorStop(0, deep);
  tint.addColorStop(1, 'transparent');
  capsule();
  context.fillStyle = tint;
  context.globalAlpha *= 0.4;
  context.fill();
  context.globalAlpha = Math.min(1, presence * 2.5);

  context.lineWidth = 1;
  context.strokeStyle = glow;
  context.globalAlpha *= 0.35;
  capsule();
  context.stroke();

  // The bars arrive once the capsule has mostly opened.
  const barsIn = Math.min(1, Math.max(0, (presence - 0.55) / 0.45));
  context.globalAlpha = barsIn * pillOpacity(uniforms);

  const gradient = context.createLinearGradient(0, y, 0, y + height);
  gradient.addColorStop(0, glow);
  gradient.addColorStop(1, deep);
  context.fillStyle = gradient;

  const span = BAR_COUNT * BAR_WIDTH + (BAR_COUNT - 1) * BAR_GAP;
  const left = GLOW_PAD + (PILL_SIZE.width - span) / 2;
  const middle = GLOW_PAD + PILL_SIZE.height / 2;
  pillBars(uniforms).forEach((level, index) => {
    const barHeight = Math.max(BAR_WIDTH, level * BAR_ROOM * barsIn);
    context.beginPath();
    context.roundRect(
      left + index * (BAR_WIDTH + BAR_GAP),
      middle - barHeight / 2,
      BAR_WIDTH,
      barHeight,
      BAR_WIDTH / 2
    );
    context.fill();
  });
  context.globalAlpha = 1;
}

export function Pill({ running, shown, read }: PillProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const readRef = useRef(read);
  readRef.current = read;
  const frameRef = useRef<ReturnType<typeof createFrame> | null>(null);
  const shownRef = useRef(shown);
  shownRef.current = shown;
  const presenceRef = useRef({ value: 0, velocity: 0 });

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || !running) return;
    frameRef.current ??= createFrame('cancelled');
    const media = window.matchMedia?.('(prefers-reduced-motion: reduce)');

    let handle = 0;
    let previous = performance.now();
    const loop = (now: number) => {
      const { bands, phase, mode } = readRef.current();
      const uniforms = frameRef.current?.step({
        deltaMs: now - previous,
        bands,
        phase,
        reducedMotion: media?.matches ?? false,
      });
      // Small fixed steps: a spring integrated over one long frame blows up.
      const spring = presenceRef.current;
      const target = shownRef.current ? 1 : 0;
      const damping = target === 1 ? SPRING_DAMPING_IN : SPRING_DAMPING_OUT;
      let remaining = Math.min(64, Math.max(0, now - previous)) / 1000;
      while (remaining > 0) {
        const dt = Math.min(remaining, 1 / 240);
        spring.velocity +=
          (SPRING_STIFFNESS * (target - spring.value) - damping * spring.velocity) * dt;
        spring.value = Math.max(0, spring.value + spring.velocity * dt);
        remaining -= dt;
      }
      previous = now;
      if (uniforms) draw(canvas, uniforms, mode ?? 'dictate', spring.value);
      handle = requestAnimationFrame(loop);
    };
    handle = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(handle);
  }, [running]);

  const cssWidth = PILL_SIZE.width + GLOW_PAD * 2;
  const cssHeight = PILL_SIZE.height + GLOW_PAD * 2;
  const ratio = window.devicePixelRatio || 1;
  // Kept off the JSX line for the same reason as in OrbCanvas: ui-lint's
  // progress-bar heuristic matches an inline width template.
  const canvasStyle = { width: `${cssWidth}px`, height: `${cssHeight}px`, display: 'block' };
  return (
    <canvas
      ref={canvasRef}
      aria-hidden="true"
      width={Math.round(cssWidth * ratio)}
      height={Math.round(cssHeight * ratio)}
      style={canvasStyle}
    />
  );
}
