import { describe, it, expect } from 'vitest';
import { cutPage, PAGE, CURSOR_LAG_MS } from '../src/services/sync.service';

const rows = (n: number, ms: (i: number) => number) =>
  Array.from({ length: n }, (_, i) => ({ id: i, syncedAt: BigInt(ms(i)) }));

describe('cutPage', () => {
  it('999 rows: no more, cursor trails now', () => {
    const r = cutPage(rows(999, i => 1000 + i), 50_000);
    expect(r.rows).toHaveLength(999);
    expect(r.hasMore).toBe(false);
    expect(r.cursor).toBe(50_000 - CURSOR_LAG_MS);
  });
  it('clamps the cursor at 0', () => {
    expect(cutPage(rows(1, () => 1), 5).cursor).toBe(0);
  });
  it('1001 distinct ms: 1000 rows, cursor is the 1000th syncedAt', () => {
    const r = cutPage(rows(PAGE + 1, i => 1000 + i), 99_999);
    expect(r.rows).toHaveLength(PAGE);
    expect(r.hasMore).toBe(true);
    expect(r.cursor).toBe(1000 + PAGE - 1);
  });
  it('a tie across the boundary is dropped and re-fetched next call', () => {
    const r = cutPage(rows(PAGE + 1, i => (i >= 995 ? 5000 : 1000 + i)), 99_999);
    expect(r.rows).toHaveLength(995);
    expect(r.hasMore).toBe(true);
    expect(r.cursor).toBe(5000);
  });
  it('a whole page in one ms asks for all of that ms', () => {
    const r = cutPage(rows(PAGE + 1, () => 7000), 99_999);
    expect(r.rows).toEqual([]);
    expect(r.hasMore).toBe(true);
    expect(r.fetchAll).toBe(7000);
    expect(r.cursor).toBe(7001);
  });
  it('exactly one page in one ms with a later row still advances', () => {
    const r = cutPage(rows(PAGE + 1, i => (i < PAGE ? 7000 : 7001)), 99_999);
    expect(r.rows).toEqual([]);
    expect(r.hasMore).toBe(true);
    expect(r.fetchAll).toBe(7000);
    expect(r.cursor).toBe(7001);
  });
});
