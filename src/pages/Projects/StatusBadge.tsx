import { Badge } from '@mantine/core';

import type { ProjectStatus } from '@/api/types';

/**
 * A project's status, as a Badge.
 *
 * This component owns one thing: the status → colour mapping. The pill itself
 * is Mantine's `Badge`, so padding, radius and type scale stay in the theme —
 * a hand-rolled pill drifts from it the first time the theme changes.
 *
 * `variant="light"` is the muted pill: a tint of the colour rather than a fill,
 * which is what a status marker should be beside a project name it must not
 * outrank.
 *
 * `tt="capitalize"` overrides Mantine's default uppercase. The statuses are
 * ordinary words, and `ACTIVE` beside a sentence-case project name reads as a
 * shout rather than a label.
 */
const colours = {
  active: 'green',
  paused: 'yellow',
  archived: 'gray',
} as const satisfies Record<ProjectStatus, string>;

export function StatusBadge({ status }: { status: ProjectStatus }) {
  return (
    <Badge variant="light" color={colours[status]} tt="capitalize">
      {status}
    </Badge>
  );
}
