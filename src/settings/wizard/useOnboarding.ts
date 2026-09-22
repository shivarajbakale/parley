import { useSettings, useUpdateSettings } from '../use-parley';

import { clampStep, DONE_STEP, stageFor, type Stage } from './stage';

/**
 * Onboarding navigation over the persisted settings. Every move is a settings
 * mutation, so a quit mid-tour or mid-wizard resumes at the same place — the
 * query cache update flips the stage with no extra state to keep in sync.
 */
export function useOnboarding(): {
  stage: Stage | null;
  step: number;
  isReady: boolean;
  isSaving: boolean;
  saveFailed: boolean;
  next(): void;
  back(): void;
  goTo(step: number): void;
  finishTour(): void;
  finishPractice(): void;
  complete(): void;
  replayTour(): void;
} {
  const settings = useSettings();
  const update = useUpdateSettings();
  const data = settings.data;

  return {
    stage: data ? stageFor(data) : null,
    step: data ? clampStep(data.wizardStep) : 0,
    isReady: !!data,
    isSaving: update.isPending,
    saveFailed: update.isError,
    next: () => {
      if (data) update.mutate({ wizardStep: clampStep(data.wizardStep + 1) });
    },
    back: () => {
      if (data) update.mutate({ wizardStep: clampStep(data.wizardStep - 1) });
    },
    goTo: step => update.mutate({ wizardStep: clampStep(step) }),
    finishTour: () => update.mutate({ tourSeen: true, wizardStep: 0 }),
    finishPractice: () => update.mutate({ wizardStep: DONE_STEP }),
    complete: () => update.mutate({ onboardingComplete: true }),
    replayTour: () => update.mutate({ tourSeen: false }),
  };
}
