import { describe, it, expect } from 'vitest';
import { mergeRow, clampClock, MAX_FUTURE_MS } from '../src/services/merge';

const now = 1_000_000;
const row = (updatedAt: number, extra: Record<string, unknown> = {}) =>
  ({ id: 'r1', updatedAt, deletedAt: null, ...extra });

describe('mergeRow', () => {
  it('inserts when nothing exists', () => {
    const r = mergeRow(null, row(10), now);
    expect(r).toEqual({ winner: row(10), changed: true });
  });
  it('newer incoming wins', () => {
    const r = mergeRow(row(10, { v: 'old' }), row(20, { v: 'new' }), now);
    expect(r.winner).toMatchObject({ v: 'new' });
    expect(r.changed).toBe(true);
  });
  it('older incoming loses and reports no change', () => {
    const r = mergeRow(row(20, { v: 'kept' }), row(10, { v: 'stale' }), now);
    expect(r.winner).toMatchObject({ v: 'kept' });
    expect(r.changed).toBe(false);
  });
  it('equal timestamps keep the existing row', () => {
    const r = mergeRow(row(10, { v: 'a' }), row(10, { v: 'b' }), now);
    expect(r.winner).toMatchObject({ v: 'a' });
    expect(r.changed).toBe(false);
  });
  it('a newer tombstone beats a live row', () => {
    const r = mergeRow(row(10), row(20, { deletedAt: 20 }), now);
    expect(r.winner.deletedAt).toBe(20);
  });
  it('clamps a clock far in the future', () => {
    const r = clampClock(row(now + MAX_FUTURE_MS * 10), now);
    expect(r.updatedAt).toBe(now + MAX_FUTURE_MS);
  });
});
