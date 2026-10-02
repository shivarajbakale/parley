export interface SyncRow {
  id: string;
  updatedAt: number;
  deletedAt?: number | null;
}

/** A client clock may run ahead; beyond this it would freeze the row for every other client. */
export const MAX_FUTURE_MS = 5 * 60 * 1000;

export function clampClock<T extends SyncRow>(row: T, now: number): T {
  const ceiling = now + MAX_FUTURE_MS;
  const updatedAt = Math.min(row.updatedAt, ceiling);
  const deletedAt = row.deletedAt == null ? row.deletedAt : Math.min(row.deletedAt, ceiling);
  return { ...row, updatedAt, deletedAt };
}

/** Last writer wins by `updatedAt`. Ties keep what the server has. */
export function mergeRow<T extends SyncRow>(
  existing: T | null,
  incoming: T,
  now: number,
): { winner: T; changed: boolean } {
  const candidate = clampClock(incoming, now);
  if (!existing) return { winner: candidate, changed: true };
  if (candidate.updatedAt > existing.updatedAt) return { winner: candidate, changed: true };
  return { winner: existing, changed: false };
}
