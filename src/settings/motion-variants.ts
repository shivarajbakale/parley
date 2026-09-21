import { DURATION, EASE } from '@/lib/motion';

import { TAB_ORDER, type TabId } from './tabs';

/** 1 when the new tab is further down the rail, so content slides up to meet it. */
export function tabDirection(from: TabId, to: TabId): 1 | -1 {
  return TAB_ORDER.indexOf(to) >= TAB_ORDER.indexOf(from) ? 1 : -1;
}

/** Tab content: crossfade with an 8 px slide in the direction of travel. */
export const panelVariants = {
  enter: (direction: number) => ({ opacity: 0, y: 8 * direction }),
  center: { opacity: 1, y: 0, transition: { duration: DURATION.base, ease: EASE } },
  exit: (direction: number) => ({
    opacity: 0,
    y: -8 * direction,
    transition: { duration: DURATION.fast, ease: EASE },
  }),
};
