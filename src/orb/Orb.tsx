import { useCallback, useEffect, useRef, useState } from 'react';
import { Stack, Text } from '@mantine/core';
import { motion } from 'motion/react';

import { SPRING } from '@/lib/motion';

import type { OrbPhase, SessionMode } from '../../electron/types';

import { SILENT_BANDS } from './bands';
import { Pill } from './Pill';
import { createPhaseHandler } from './phase-handler';
import { createRecorder, type Recorder } from './recorder';
import { playSound } from './sounds';
import classes from './Orb.module.css';

export function Orb() {
  const recorderRef = useRef<Recorder | null>(null);
  const phaseRef = useRef<OrbPhase>('cancelled');
  const modeRef = useRef<SessionMode>('dictate');
  const [visible, setVisible] = useState(false);
  const [message, setMessage] = useState('');
  // Keeps the canvas loop alive through the exit animation: `visible` turning
  // false starts the fade-out immediately, but the done/error look must stay
  // rendered while it plays rather than freezing the instant it begins.
  const [exiting, setExiting] = useState(false);
  const wasVisibleRef = useRef(visible);

  if (wasVisibleRef.current && !visible) {
    setExiting(true);
  }
  wasVisibleRef.current = visible;

  useEffect(() => {
    const recorder = createRecorder();
    recorderRef.current = recorder;
    const { handlePhase, dispose } = createPhaseHandler({
      recorder,
      sendAudio: window.parley.sendAudio,
      playSound,
      onPhase: (phase) => {
        phaseRef.current = phase;
      },
      onMode: (mode) => {
        modeRef.current = mode;
      },
      setVisible,
      setMessage,
    });
    const unsubscribe = window.parley.onOrbPhase(handlePhase);

    return () => {
      unsubscribe();
      dispose();
      recorder.discard();
      recorderRef.current = null;
    };
  }, []);

  const read = useCallback(
    () => ({
      bands: recorderRef.current?.bands() ?? SILENT_BANDS,
      phase: phaseRef.current,
      mode: modeRef.current,
    }),
    []
  );

  return (
    <Stack className={classes.root} align="center" justify="flex-end" gap={0}>
      <Text size="xs" c="red.4" fw={500} h={16}>
        {message}
      </Text>
      <motion.div
        initial={false}
        // Only the fade lives here; the pill opens and folds itself on the canvas.
        animate={{ opacity: visible ? 1 : 0 }}
        transition={SPRING}
        onAnimationComplete={() => {
          if (!visible) setExiting(false);
        }}
      >
        <Pill running={visible || exiting} shown={visible} read={read} />
      </motion.div>
    </Stack>
  );
}
