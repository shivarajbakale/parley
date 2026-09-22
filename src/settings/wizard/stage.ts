import { WIZARD_STEP_MAX } from '../../../electron/types';

/**
 * First-run stage, as pure functions. The settings window is always in exactly
 * one stage: the product tour, the setup wizard (at a persisted step), or the
 * normal tabbed settings. Quitting mid-flow resumes where it left off because
 * the answers live in the settings store, not in component state.
 */

export type Stage = 'tour' | 'wizard' | 'settings';

/** Steps 0–5 are the six setup steps; the Done screen sits at the max. */
export const DONE_STEP = WIZARD_STEP_MAX;

/** The stored step is as untrusted as any other setting: clamp it. */
export function clampStep(step: number): number {
  if (!Number.isInteger(step)) return 0;
  return Math.min(Math.max(step, 0), WIZARD_STEP_MAX);
}

export function stageFor(state: { tourSeen: boolean; onboardingComplete: boolean }): Stage {
  if (!state.tourSeen) return 'tour';
  if (!state.onboardingComplete) return 'wizard';
  return 'settings';
}
