import type { Prisma } from '@prisma/client';
import prisma from '../config/database';
import { mergeRow, type SyncRow } from './merge';
import type { SyncResource, AnyRow, DictionaryRow, SettingsRow, HistoryRow, TaskRow } from '../types/sync.types';

type DbRow = Record<string, unknown> & { id: string; userId: string; updatedAt: bigint; deletedAt: bigint | null; syncedAt: bigint };

const big = (n: number | null | undefined) => (n == null ? null : BigInt(n));
const num = (b: bigint | null | undefined) => (b == null ? null : Number(b));

/** Wire row -> columns. Strips `id` for settings (one row per user). */
function toDb(resource: SyncResource, userId: string, row: AnyRow) {
  const common = { userId, updatedAt: BigInt(row.updatedAt), deletedAt: big(row.deletedAt) };
  switch (resource) {
    case 'dictionary': {
      const r = row as DictionaryRow;
      return { id: r.id, ...common, word: r.word, soundsLike: JSON.stringify(r.soundsLike) };
    }
    case 'settings': {
      const r = row as SettingsRow;
      return { id: userId, ...common, data: JSON.stringify(r.data) };
    }
    case 'history': {
      const r = row as HistoryRow;
      return { id: r.id, ...common, mode: r.mode, text: r.text, app: r.app, createdAt: BigInt(r.createdAt) };
    }
    case 'tasks': {
      const r = row as TaskRow;
      return {
        id: r.id, ...common, title: r.title, notes: r.notes, dueAt: big(r.dueAt), rrule: r.rrule ?? null,
        priority: r.priority, status: r.status, sourceText: r.sourceText,
      };
    }
  }
}

/** Columns -> wire row. */
function toWire(resource: SyncResource, row: DbRow): AnyRow {
  const common = { id: row.id, updatedAt: Number(row.updatedAt), deletedAt: num(row.deletedAt) };
  switch (resource) {
    case 'dictionary':
      return { ...common, word: row.word as string, soundsLike: JSON.parse(row.soundsLike as string) };
    case 'settings':
      return { ...common, data: JSON.parse(row.data as string) };
    case 'history':
      return {
        ...common, mode: row.mode as HistoryRow['mode'], text: row.text as string,
        app: row.app as string, createdAt: Number(row.createdAt),
      };
    case 'tasks':
      return {
        ...common, title: row.title as string, notes: row.notes as string, dueAt: num(row.dueAt as bigint | null),
        rrule: (row.rrule as string | null) ?? null, priority: row.priority as TaskRow['priority'],
        status: row.status as TaskRow['status'], sourceText: row.sourceText as string,
      };
  }
}

type Delegate = {
  findMany(args: unknown): Promise<DbRow[]>;
  findUnique(args: unknown): Promise<DbRow | null>;
  upsert(args: unknown): Promise<DbRow>;
};

function table(resource: SyncResource, client: Prisma.TransactionClient | typeof prisma = prisma): Delegate {
  // Prisma delegates share the findUnique/findMany/upsert shape used below.
  const map = {
    dictionary: client.dictionaryEntry,
    settings: client.settingsBlob,
    history: client.historyItem,
    tasks: client.task,
  } as const;
  return map[resource] as unknown as Delegate;
}

export const PAGE = 1000;
/** Pulls overlap the tail by this much: a row stamped before its commit lands late. */
export const CURSOR_LAG_MS = 2000;

/**
 * Cut a pull's rows (ordered by syncedAt asc, at most PAGE + 1) into a page and
 * the next cursor. The next pull uses `syncedAt >= cursor`, so overlap is by
 * design (re-delivery is idempotent under last-writer-wins) and loss is not.
 * `fetchAll` means one millisecond holds a whole page: the caller must load
 * every row at that millisecond.
 */
export function cutPage<T extends { syncedAt: bigint }>(rows: T[], now: number) {
  if (rows.length <= PAGE) {
    return { rows, hasMore: false, cursor: Math.max(0, now - CURSOR_LAG_MS), fetchAll: undefined as number | undefined };
  }
  const first = rows.slice(0, PAGE);
  const lastMs = first[PAGE - 1].syncedAt;
  if (rows[PAGE].syncedAt !== lastMs) {
    // No tie across the boundary: keep the full page; gte re-sends only the last row.
    return { rows: first, hasMore: true, cursor: Number(lastMs), fetchAll: undefined as number | undefined };
  }
  let end = PAGE;
  while (end > 0 && first[end - 1].syncedAt === lastMs) end--;
  if (end > 0) {
    return { rows: first.slice(0, end), hasMore: true, cursor: Number(lastMs), fetchAll: undefined as number | undefined };
  }
  return { rows: [] as T[], hasMore: true, cursor: Number(lastMs) + 1, fetchAll: Number(lastMs) as number | undefined };
}

/**
 * Delivery cursor is `syncedAt`, a server clock stamped on every write, so an
 * offline edit with an old client `updatedAt` is still delivered.
 */
export const pull = async (resource: SyncResource, userId: string, since: number) => {
  const now = Date.now();
  const rows = await table(resource).findMany({
    where: { userId, syncedAt: { gte: BigInt(since) } },
    orderBy: { syncedAt: 'asc' },
    take: PAGE + 1,
  });
  const cut = cutPage<DbRow>(rows, now);
  let out: DbRow[] = cut.rows;
  if (cut.fetchAll !== undefined) {
    out = await table(resource).findMany({ where: { userId, syncedAt: BigInt(cut.fetchAll) } });
  }
  return { rows: out.map(r => toWire(resource, r)), hasMore: cut.hasMore, cursor: cut.cursor };
};

export const push = async (resource: SyncResource, userId: string, items: AnyRow[], now = Date.now()) => {
  const winners: AnyRow[] = [];
  for (const item of items) {
    const data = toDb(resource, userId, item);
    const key = { userId_id: { userId, id: data.id } };
    const winner = await prisma.$transaction(async tx => {
      const t = table(resource, tx);
      const existing = await t.findUnique({ where: key });
      const current: SyncRow | null = existing
        ? { id: existing.id, updatedAt: Number(existing.updatedAt), deletedAt: num(existing.deletedAt) }
        : null;
      const incoming: SyncRow = { id: data.id, updatedAt: item.updatedAt, deletedAt: item.deletedAt ?? null };
      const merged = mergeRow(current, incoming, now);
      if (!merged.changed) return existing ? toWire(resource, existing) : null;
      const clamped = {
        ...data,
        updatedAt: BigInt(merged.winner.updatedAt),
        deletedAt: big(merged.winner.deletedAt),
        syncedAt: BigInt(Date.now()),
      };
      const saved = await t.upsert({ where: key, create: clamped, update: clamped });
      return toWire(resource, saved);
    });
    if (winner) winners.push(winner);
  }
  return winners;
};
