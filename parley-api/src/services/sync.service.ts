import prisma from '../config/database';
import { mergeRow, type SyncRow } from './merge';
import type { SyncResource, AnyRow, DictionaryRow, SettingsRow, HistoryRow, TaskRow } from '../types/sync.types';

type DbRow = Record<string, unknown> & { id: string; userId: string; updatedAt: bigint; deletedAt: bigint | null };

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

function table(resource: SyncResource) {
  // Prisma delegates share the findUnique/findMany/upsert shape used below.
  const map = {
    dictionary: prisma.dictionaryEntry,
    settings: prisma.settingsBlob,
    history: prisma.historyItem,
    tasks: prisma.task,
  } as const;
  return map[resource] as unknown as {
    findMany(args: unknown): Promise<DbRow[]>;
    findUnique(args: unknown): Promise<DbRow | null>;
    upsert(args: unknown): Promise<DbRow>;
  };
}

export const pull = async (resource: SyncResource, userId: string, since: number) => {
  const rows = await table(resource).findMany({
    where: { userId, updatedAt: { gt: BigInt(since) } },
    orderBy: { updatedAt: 'asc' },
    take: 1000,
  });
  return rows.map(r => toWire(resource, r));
};

export const push = async (resource: SyncResource, userId: string, items: AnyRow[], now = Date.now()) => {
  const winners: AnyRow[] = [];
  for (const item of items) {
    const data = toDb(resource, userId, item);
    const existing = await table(resource).findUnique({ where: { id: data.id } });
    if (existing && existing.userId !== userId) {
      // An id collision across users: ignore the foreign row, treat as insert under a scoped id.
      continue;
    }
    const current: SyncRow | null = existing
      ? { id: existing.id, updatedAt: Number(existing.updatedAt), deletedAt: num(existing.deletedAt) }
      : null;
    const incoming: SyncRow = { id: data.id, updatedAt: item.updatedAt, deletedAt: item.deletedAt ?? null };
    const { winner, changed } = mergeRow(current, incoming, now);
    if (changed) {
      const clamped = { ...data, updatedAt: BigInt(winner.updatedAt), deletedAt: big(winner.deletedAt) };
      const saved = await table(resource).upsert({ where: { id: data.id }, create: clamped, update: clamped });
      winners.push(toWire(resource, saved));
    } else if (existing) {
      winners.push(toWire(resource, existing));
    }
  }
  return winners;
};
