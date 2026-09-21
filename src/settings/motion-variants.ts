import { TAB_ORDER, type TabId } from './tabs';

/** 1 when the new tab is further down the rail, so content slides up to meet it. */
export function tabDirection(from: TabId, to: TabId): 1 | -1 {
  return TAB_ORDER.indexOf(to) >= TAB_ORDER.indexOf(from) ? 1 : -1;
}

/** Tab content fades in with a slide this far, in the direction of travel. See `.panel`. */
export const PANEL_SHIFT_PX = 8;
