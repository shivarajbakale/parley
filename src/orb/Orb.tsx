import { useEffect, useRef, useState } from 'react';
import { Stack, Text } from '@mantine/core';

import type { OrbPhase } from '../../electron/types';

import { createRecorder } from './recorder';
import { playTick } from './tick';
import classes from './Orb.module.css';

const CANVAS_SIZE = 180;
const BASE_RADIUS = 34;

/** Colours come from the theme, never a literal (see `make ui-lint`). */
function themeColor(name: string) {
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
}

function draw(
  context: CanvasRenderingContext2D,
  phase: OrbPhase,
  level: number,
  timeMs: number
) {
  const center = CANVAS_SIZE / 2;
  const color = themeColor(
    phase === 'error'
      ? '--mantine-color-red-6'
      : phase === 'done'
        ? '--mantine-color-teal-5'
        : '--mantine-primary-color-filled'
  );

  // Listening swells with the voice; transcribing breathes on a slow sine.
  const pulse =
    phase === 'listening'
      ? level * 30
      : phase === 'transcribing'
        ? 4 + Math.sin(timeMs / 180) * 4
        : 0;
  const radius = BASE_RADIUS + pulse;

  context.clearRect(0, 0, CANVAS_SIZE, CANVAS_SIZE);

  const glow = context.createRadialGradient(center, center, radius * 0.4, center, center, radius * 1.9);
  glow.addColorStop(0, color);
  glow.addColorStop(1, 'transparent');
  context.globalAlpha = 0.35 + level * 0.4;
  context.fillStyle = glow;
  context.beginPath();
  context.arc(center, center, radius * 1.9, 0, Math.PI * 2);
  context.fill();

  context.globalAlpha = 1;
  context.fillStyle = color;
  context.beginPath();
  context.arc(center, center, radius, 0, Math.PI * 2);
  context.fill();
}

export function Orb() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const phaseRef = useRef<OrbPhase>('cancelled');
  const [visible, setVisible] = useState(false);
  const [message, setMessage] = useState('');

  useEffect(() => {
    const recorder = createRecorder();

    const unsubscribe = window.parley.onOrbPhase(async ({ phase, message: text, tick }) => {
      phaseRef.current = phase;
      setMessage(phase === 'error' ? (text ?? '') : '');
      setVisible(phase !== 'cancelled');

      if (phase === 'listening') {
        await recorder.start();
      } else if (phase === 'transcribing') {
        const audio = await recorder.stop();
        if (tick) playTick();
        if (audio) window.parley.sendAudio(audio);
      } else if (phase === 'cancelled') {
        recorder.discard();
      } else if (phase === 'done') {
        // Main hides the window after the flash; start the fade just before.
        setTimeout(() => setVisible(false), 300);
      } else if (phase === 'error') {
        setTimeout(() => setVisible(false), 3000);
      }
    });

    let frame = 0;
    const loop = (timeMs: number) => {
      const context = canvasRef.current?.getContext('2d');
      if (context) draw(context, phaseRef.current, recorder.level(), timeMs);
      frame = requestAnimationFrame(loop);
    };
    frame = requestAnimationFrame(loop);

    return () => {
      unsubscribe();
      cancelAnimationFrame(frame);
      recorder.discard();
    };
  }, []);

  return (
    <Stack className={classes.root} data-visible={visible} align="center" justify="center" gap={0}>
      <canvas ref={canvasRef} width={CANVAS_SIZE} height={CANVAS_SIZE} />
      <Text size="xs" c="red.4" fw={500} h={16}>
        {message}
      </Text>
    </Stack>
  );
}
