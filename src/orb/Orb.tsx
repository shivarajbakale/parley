import { useCallback, useEffect, useRef, useState } from 'react';
import { Stack, Text } from '@mantine/core';
import { motion } from 'motion/react';

import { SPRING } from '@/lib/motion';

import type { OrbPhase } from '../../electron/types';

import { SILENT_BANDS } from './bands';
import { OrbCanvas } from './OrbCanvas';
import { createPhaseHandler } from './phase-handler';
import { createRecorder, type Recorder } from './recorder';
import { playTick } from './tick';
import classes from './Orb.module.css';

const ORB_CANVAS_SIZE = 240;

export function Orb() {
  const recorderRef = useRef<Recorder | null>(null);
  const phaseRef = useRef<OrbPhase>('cancelled');
  const [visible, setVisible] = useState(false);
  const [message, setMessage] = useState('');

  useEffect(() => {
    const recorder = createRecorder();
    recorderRef.current = recorder;
    const { handlePhase, dispose } = createPhaseHandler({
      recorder,
      sendAudio: window.parley.sendAudio,
      playTick,
      onPhase: (phase) => {
        phaseRef.current = phase;
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
    () => ({ bands: recorderRef.current?.bands() ?? SILENT_BANDS, phase: phaseRef.current }),
    []
  );

  return (
    <Stack className={classes.root} align="center" justify="center" gap={0}>
      <motion.div
        initial={false}
        animate={{ opacity: visible ? 1 : 0, scale: visible ? 1 : 0.85 }}
        transition={SPRING}
      >
        <OrbCanvas size={ORB_CANVAS_SIZE} running={visible} read={read} />
      </motion.div>
      <Text size="xs" c="red.4" fw={500} h={16}>
        {message}
      </Text>
    </Stack>
  );
}
