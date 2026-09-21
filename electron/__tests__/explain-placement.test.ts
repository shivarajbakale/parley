import { describe, expect, it } from 'vitest';

import {
  ANCHOR_GAP,
  CURSOR_OFFSET,
  EDGE_MARGIN,
  maxCardHeight,
  placeCard,
} from '../explain-placement';

const workArea = { x: 0, y: 25, width: 1440, height: 875 };
const size = { width: 420, height: 200 };
const cursor = { x: 700, y: 400 };

describe('placeCard', () => {
  it('sits below the selection with the left edges aligned', () => {
    const anchor = { x: 300, y: 200, width: 90, height: 16 };
    expect(placeCard({ anchor, cursor, workArea, size })).toEqual({
      x: 300,
      y: 200 + 16 + ANCHOR_GAP,
      ...size,
    });
  });

  it('flips above when there is no room below', () => {
    const anchor = { x: 300, y: 800, width: 90, height: 16 };
    const placed = placeCard({ anchor, cursor, workArea, size });
    expect(placed.y).toBe(800 - ANCHOR_GAP - size.height);
  });

  it('stays inside the work area when it fits neither above nor below', () => {
    const tiny = { x: 0, y: 0, width: 800, height: 300 };
    const anchor = { x: 100, y: 150, width: 50, height: 16 };
    const placed = placeCard({ anchor, cursor, workArea: tiny, size: { width: 420, height: 280 } });
    expect(placed.y).toBe(300 - EDGE_MARGIN - 280);
    expect(placed.y).toBeGreaterThanOrEqual(EDGE_MARGIN);
  });

  it('shifts left when it would run past the right edge', () => {
    const anchor = { x: 1350, y: 200, width: 60, height: 16 };
    const placed = placeCard({ anchor, cursor, workArea, size });
    expect(placed.x).toBe(1440 - size.width - EDGE_MARGIN);
  });

  it('never leaves the left edge of a display that does not start at zero', () => {
    const second = { x: 1440, y: 0, width: 1920, height: 1080 };
    const anchor = { x: 1442, y: 200, width: 60, height: 16 };
    expect(placeCard({ anchor, cursor, workArea: second, size }).x).toBe(1440 + EDGE_MARGIN);
  });

  it('falls back to the pointer, offset down and right', () => {
    expect(placeCard({ anchor: null, cursor, workArea, size })).toEqual({
      x: 700 + CURSOR_OFFSET,
      y: 400 + CURSOR_OFFSET,
      ...size,
    });
  });

  it('flips above the pointer near the bottom edge', () => {
    const placed = placeCard({ anchor: null, cursor: { x: 700, y: 850 }, workArea, size });
    expect(placed.y).toBe(850 - CURSOR_OFFSET - size.height);
  });
});

describe('maxCardHeight', () => {
  it('is 60% of the display height', () => {
    expect(maxCardHeight(workArea)).toBe(525);
  });
});
