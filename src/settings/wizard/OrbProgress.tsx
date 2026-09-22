import { Box } from '@mantine/core';
import { motion, useReducedMotion } from 'motion/react';

import { SPRING } from '@/lib/motion';

import { SILENT_BANDS } from '../../orb/bands';
import { OrbCanvas } from '../../orb/OrbCanvas';

/**
 * The wizard's only progress indicator: a live orb inside a ring that fills as
 * setup advances. The fraction is spoken through aria-valuetext rather than
 * printed, so sighted users get one calm indicator and screen readers still
 * hear “Step 2 of 6: Accessibility”.
 */

const RING = 104;
const STROKE = 3;
const RADIUS = (RING - STROKE) / 2;
const CIRCUMFERENCE = 2 * Math.PI * RADIUS;
// The badge orb's body is half its canvas, so the canvas overhangs the ring
// and its glow spills past it; the ring is what sets the layout box.
const ORB = 136;

export function OrbProgress({
  step,
  total,
  label,
  pulses,
}: {
  /** Steps finished so far: 0 on the first step, `total` once setup is done. */
  step: number;
  total: number;
  /** Name of the current step, or of the finish when done. */
  label: string;
  /** A running count of key presses from the screen below; each one kicks the orb. */
  pulses?: { current: number };
}) {
  const reduced = useReducedMotion();
  const done = step >= total;
  // The current step counts as begun, so the first step already shows a sliver.
  const fraction = done ? 1 : (step + 1) / (total + 1);
  const read = () => ({
    bands: SILENT_BANDS,
    phase: done ? ('done' as const) : ('listening' as const),
    pulses: pulses?.current,
  });

  return (
    <Box
      role="progressbar"
      aria-label="Setup progress"
      aria-valuemin={0}
      aria-valuemax={total}
      aria-valuenow={Math.min(step, total)}
      aria-valuetext={done ? 'Setup complete' : `Step ${step + 1} of ${total}: ${label}`}
      pos="relative"
      w={RING}
      h={RING}
      mx="auto"
    >
      <svg
        width={RING}
        height={RING}
        viewBox={`0 0 ${RING} ${RING}`}
        aria-hidden="true"
        style={{ position: 'absolute', inset: 0, transform: 'rotate(-90deg)' }}
      >
        <circle
          cx={RING / 2}
          cy={RING / 2}
          r={RADIUS}
          fill="none"
          stroke="var(--app-glass-border)"
          strokeWidth={STROKE}
        />
        <motion.circle
          cx={RING / 2}
          cy={RING / 2}
          r={RADIUS}
          fill="none"
          stroke={done ? 'var(--mantine-color-teal-5)' : 'var(--app-aurora-glow)'}
          strokeWidth={STROKE}
          strokeLinecap="round"
          strokeDasharray={CIRCUMFERENCE}
          initial={false}
          animate={{ strokeDashoffset: CIRCUMFERENCE * (1 - fraction) }}
          transition={reduced ? { duration: 0 } : SPRING}
        />
      </svg>
      <Box pos="absolute" top={(RING - ORB) / 2} left={(RING - ORB) / 2}>
        <OrbCanvas size={ORB} framing="badge" running read={read} />
      </Box>
    </Box>
  );
}
