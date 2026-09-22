import { Alert, Box, Loader, Stack } from '@mantine/core';
import { useEffect, useRef } from 'react';

import { Scene } from '../Scene';
import shell from '../settings.module.css';

import { OrbProgress } from './OrbProgress';
import { DONE_STEP } from './stage';
import {
  AccessStep,
  FinaleStep,
  MicStep,
  PracticeStep,
  TrainerStep,
  TranscriptionStep,
  WelcomeStep,
} from './steps';
import { useOnboarding } from './useOnboarding';

/**
 * The first-run flow: one centered column on the Scene, with a live orb in a
 * progress ring above it until the finale, which flies its own orb away. The step comes from persisted settings, so
 * this frame holds no navigation state of its own — it draws where the user is
 * and focuses each arriving pane's heading.
 */

const STEP_LABELS = ['Welcome', 'Microphone', 'Accessibility', 'Transcription', 'Gesture', 'First words'];

const PANES = [WelcomeStep, MicStep, AccessStep, TranscriptionStep, TrainerStep, PracticeStep];

export function WizardShell() {
  const { step, isReady, saveFailed } = useOnboarding();
  const paneRef = useRef<HTMLDivElement>(null);
  const done = step >= DONE_STEP;

  useEffect(() => {
    paneRef.current
      ?.querySelector<HTMLElement>('[data-step-heading]')
      ?.focus({ preventScroll: true });
  }, [step]);

  if (!isReady) {
    return (
      <Scene tone="neutral">
        <Stack h="100%" align="center" justify="center" role="status" aria-label="Loading setup">
          <Loader />
        </Stack>
      </Scene>
    );
  }

  const Pane = done ? FinaleStep : PANES[step];

  return (
    <Scene tone={done ? 'done' : 'dictate'}>
      <Box
        h="100%"
        px="xl"
        pt={36}
        pb="xl"
        style={{ overflowY: 'auto', display: 'flex', flexDirection: 'column' }}
      >
        {/* The finale has no ring above it, so it sits in the middle of the window. */}
        <Stack gap="lg" w="100%" maw={520} mx="auto" my={done ? 'auto' : undefined}>
          {!done && <OrbProgress step={step} total={STEP_LABELS.length} label={STEP_LABELS[step]} />}
          {saveFailed && (
            <Alert color="red" variant="light">
              Could not save settings
            </Alert>
          )}
          <Box key={step} ref={paneRef} className={shell.panel}>
            <Pane />
          </Box>
        </Stack>
      </Box>
    </Scene>
  );
}
