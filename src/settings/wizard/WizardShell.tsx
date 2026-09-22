import { Alert, Box, Group, Loader, Progress, Stack, Stepper, Text, Title } from '@mantine/core';
import { useEffect, useRef } from 'react';

import shell from '../settings.module.css';

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
 * The setup wizard: a step rail on the left, one step pane on the right. The
 * step comes from persisted settings, so this frame holds no navigation state
 * of its own — it draws where the user is and focuses each arriving pane's
 * heading. The pane scrolls exactly like the settings content beside it.
 */

const RAIL_STEPS = [
  { label: 'Microphone', description: 'Let Parley hear you' },
  { label: 'Accessibility', description: 'Keys + paste' },
  { label: 'Groq key', description: 'Transcription' },
  { label: 'MiniMax', description: 'Optional' },
  { label: 'Hotkeys', description: 'Gesture keys' },
  { label: 'Practice', description: 'First dictation' },
];

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
      <Box className={shell.shell}>
        <Stack h="100%" align="center" justify="center" role="status" aria-label="Loading setup">
          <Loader />
        </Stack>
      </Box>
    );
  }

  const Pane = done ? DoneStep : PANES[step];

  return (
    <Box className={shell.shell}>
      <Group h="100%" gap={0} wrap="nowrap" align="stretch">
        <Box w={200} className={shell.rail}>
          <Stack gap="md">
            <Box px="xs">
              <Title order={5}>Setup</Title>
              <Text size="xs" c="dimmed" mt={2}>
                {done ? 'Complete' : `Step ${step + 1} of ${RAIL_STEPS.length}`}
              </Text>
            </Box>
            <Stepper
              active={done ? RAIL_STEPS.length : step}
              orientation="vertical"
              allowNextStepsSelect={false}
            >
              {RAIL_STEPS.map(rail => (
                <Stepper.Step key={rail.label} label={rail.label} description={rail.description} />
              ))}
            </Stepper>
          </Stack>
        </Box>
        <Box flex={1} miw={0} p="xl" style={{ overflowY: 'auto' }}>
          <Group justify="space-between" align="center" mb="md">
            <Text size="sm" fw={500}>
              {done ? 'Done' : `Step ${step + 1} of ${RAIL_STEPS.length}`}
            </Text>
            <Progress
              value={done ? 100 : Math.round(((step + 1) / (RAIL_STEPS.length + 1)) * 100)}
              w={160}
              aria-label="Setup progress"
            />
          </Group>
          {saveFailed && (
            <Alert color="red" variant="light" mb="md">
              Could not save settings
            </Alert>
          )}
          <Box key={step} ref={paneRef} className={shell.panel}>
            <Pane />
          </Box>
        </Box>
      </Group>
    </Box>
  );
}
