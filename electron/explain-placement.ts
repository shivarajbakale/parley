import type { Rect } from './types';

/**
 * Where the explain card goes, as a pure function. It sits just below the
 * selection with its left edges aligned; when the work area has no room below
 * it flips above, and it is always shifted back inside the work area.
 */

/** Gap between the selection and the card. */
export const ANCHOR_GAP = 8;
/** Offset from the pointer, when the app would not say where the selection is. */
export const CURSOR_OFFSET = 12;
/** Never closer than this to a screen edge. */
export const EDGE_MARGIN = 8;

export const CARD_WIDTH = 420;
/** Loading skeleton height, until the rendered card reports its own. */
export const CARD_MIN_HEIGHT = 96;
/** The card scrolls only past this share of the display height. */
export const MAX_HEIGHT_RATIO = 0.6;

export interface Point {
  x: number;
  y: number;
}

export interface PlaceCardInput {
  /** Selection rectangle in screen coordinates, or `null` to use the pointer. */
  anchor: Rect | null;
  cursor: Point;
  workArea: Rect;
  size: { width: number; height: number };
}

export function maxCardHeight(workArea: Rect): number {
  return Math.round(workArea.height * MAX_HEIGHT_RATIO);
}

export function placeCard({ anchor, cursor, workArea, size }: PlaceCardInput): Rect {
  const left = anchor ? anchor.x : cursor.x + CURSOR_OFFSET;
  const below = anchor ? anchor.y + anchor.height + ANCHOR_GAP : cursor.y + CURSOR_OFFSET;
  const above = (anchor ? anchor.y - ANCHOR_GAP : cursor.y - CURSOR_OFFSET) - size.height;

  const bottom = workArea.y + workArea.height - EDGE_MARGIN;
  const top = workArea.y + EDGE_MARGIN;
  let y = below;
  if (below + size.height > bottom) y = above >= top ? above : bottom - size.height;
  y = Math.max(top, y);

  const maxX = workArea.x + workArea.width - size.width - EDGE_MARGIN;
  const x = Math.max(workArea.x + EDGE_MARGIN, Math.min(left, maxX));

  return { x: Math.round(x), y: Math.round(y), width: size.width, height: size.height };
}
