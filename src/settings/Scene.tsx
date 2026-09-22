import { Box } from '@mantine/core';

import classes from './Scene.module.css';
import shell from './settings.module.css';

/** The session modes plus two onboarding moods: a quiet ground and the finish. */
export type SceneTone = 'dictate' | 'edit' | 'explain' | 'neutral' | 'done';

/**
 * Full-window backdrop for the first-run stages. Its blooms take the tone's
 * colours from the same tokens the orb wears, so backdrop and orb always agree.
 */
export function Scene({ tone, children }: { tone: SceneTone; children: React.ReactNode }) {
  return (
    <Box className={`${classes.scene} ${classes[tone]}`} data-tone={tone}>
      <div className={shell.drag} aria-hidden="true" />
      {children}
    </Box>
  );
}
