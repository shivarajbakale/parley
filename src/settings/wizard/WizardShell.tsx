import { Alert, Box, Loader, Stack } from '@mantine/core';
import { useEffect, useRef } from 'react';

import { Scene } from '../Scene';
import shell from '../settings.module.css';

import { OrbProgress } from './OrbProgress';
import { DONE_STEP } from './stage';
import {
  AccessStep,
  DoneStep,
  GroqKeyStep,
  HotkeysStep,
  MicStep,
  MinimaxStep,
  PracticeStep,
} from './steps';
import { useOnboarding } from './useOnboarding';

/**
 * The setup wizard: one centered column on the first-run Scene, with a live
 * orb in a progress ring above it. The step comes from persisted settings, so
 * this frame holds no navigation state of its own — it draws where the user is
 * and focuses each arriving pane's heading.
 */

const STEP_LABELS = ['Microphone', 'Accessibility', 'Groq key', 'MiniMax', 'Hotkeys', 'Practice'];

const PANES = [MicStep, AccessStep, GroqKeyStep, MinimaxStep, HotkeysStep, PracticeStep];

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

  const Pane = done ? DoneStep : PANES[step];

  return (
    <Scene tone={done ? 'done' : 'dictate'}>
      <Box h="100%" px="xl" pt={36} pb="xl" style={{ overflowY: 'auto' }}>
        <Stack gap="lg" maw={520} mx="auto">
          <OrbProgress
            step={done ? STEP_LABELS.length : step}
            total={STEP_LABELS.length}
            label={done ? 'Done' : STEP_LABELS[step]}
          />
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
