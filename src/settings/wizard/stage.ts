import { WIZARD_STEP_MAX } from '../../../electron/types';

/**
 * First-run stage, as pure functions. The settings window is always in exactly
 * one stage: the first-run flow (at a persisted step), the product tour, or
 * the normal tabbed settings. Quitting mid-flow resumes where it left off
 * because the answers live in the settings store, not in component state.
 */

export type Stage = 'tour' | 'wizard' | 'settings';

/** Steps 0–5 are the six first-run screens; the finale sits at the max. */
export const DONE_STEP = WIZARD_STEP_MAX;

/** The stored step is as untrusted as any other setting: clamp it. */
export function clampStep(step: number): number {
  if (!Number.isInteger(step)) return 0;
  return Math.min(Math.max(step, 0), WIZARD_STEP_MAX);
}

/**
 * First run opens on Welcome, not the tour: the flow teaches by doing. The
 * tour is a replay, shown only once onboarding is complete and the user has
 * asked for it again (which clears `tourSeen`).
 */
export function stageFor(state: { tourSeen: boolean; onboardingComplete: boolean }): Stage {
  if (!state.onboardingComplete) return 'wizard';
  if (!state.tourSeen) return 'tour';
  return 'settings';
}
