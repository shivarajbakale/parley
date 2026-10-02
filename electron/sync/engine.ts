import type { DictionaryEntry } from '../dictionary';
import type { DictionaryStore } from '../dictionary-store';
import type { SettingsStore } from '../settings-store';
import type { Settings } from '../types';

import { type SyncClient, SyncHttpError } from './client';

/** Device-local: which server, who, and whether to sync are never synced. */
const LOCAL_ONLY: (keyof Settings)[] = ['syncEnabled', 'syncUrl', 'syncEmail'];
/** Mirrors the server's FORBIDDEN_SETTINGS_KEYS. A remote blob is as untrusted as
 * the renderer; the store's patch cleaner drops the rest. */
const FORBIDDEN = /^(api_?key|key)$|apikey|token|secret|password/i;
/** The API's per-request ceiling for a push. */
const PUSH_BATCH = 500;
const SIGNED_OUT = 'Signed out: the server rejected the token';

interface DictionaryWire {
  id: string;
  word: string;
  soundsLike: string[];
  updatedAt: number;
  deletedAt: number | null;
}
interface SettingsWire {
  id: string;
  data: Record<string, unknown>;
  updatedAt: number;
  deletedAt: number | null;
}

export interface SyncDeps {
  client: SyncClient;
  dictionary: Pick<DictionaryStore, 'changedSince' | 'applyRemote' | 'list'>;
  settings: Pick<SettingsStore, 'get' | 'applyRemote' | 'recordSync' | 'settingsUpdatedAt'>;
  /** The server's pull cursor: the last `now` of a successful drain. */
  cursor: { get(): number; set(value: number): void };
  /**
   * Local clock of the last successful sync (the run's start, not its end): what
   * bounds the push window. Main passes `() => store.view().syncLastAt`; the
   * engine only ever advances it on success.
   */
  lastSyncAt: () => number;
  now?: () => number;
}

export interface SyncOutcome {
  ok: boolean;
  pushed: number;
  pulled: number;
  message: string;
  at: number;
}

const toWire = (e: DictionaryEntry): DictionaryWire => ({
  id: e.id,
  word: e.word,
  soundsLike: e.soundsLike,
  updatedAt: e.updatedAt,
  deletedAt: null,
});

function localSettingsBlob(settings: Settings): Record<string, unknown> {
  const data: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(settings)) {
    if (!LOCAL_ONLY.includes(k as keyof Settings)) data[k] = v;
  }
  return data;
}

function remotePatch(data: Record<string, unknown>): Partial<Settings> {
  const patch: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(data)) {
    if (LOCAL_ONLY.includes(k as keyof Settings) || FORBIDDEN.test(k)) continue;
    patch[k] = v;
  }
  return patch as Partial<Settings>;
}

function describe(err: unknown): string {
  if (err instanceof SyncHttpError && err.status === 401) return SIGNED_OUT;
  return err instanceof Error ? err.message : String(err);
}

export function createSyncEngine({ client, dictionary, settings, cursor, lastSyncAt, now = Date.now }: SyncDeps) {
  let running: Promise<SyncOutcome> | null = null;

  /** Follows `hasMore` to the end; pages may overlap, so `onPage` must be idempotent. */
  async function drain<T>(resource: string, from: number, onPage: (rows: T[]) => void): Promise<number> {
    let since = from;
    let page;
    do {
      page = await client.pull<T>(resource, since);
      if (page.hasMore && page.now <= since) throw new Error('Sync server did not advance the cursor');
      onPage(page.rows);
      since = page.now;
    } while (page.hasMore);
    return since;
  }

  async function run(): Promise<SyncOutcome> {
    let pushed = 0;
    let pulled = 0;
    try {
      // Taken before reading local changes: an edit made mid-run lands in the next window.
      const startedAt = now();
      // Push first so the pull that follows returns our own rows only if they lost.
      const pushFrom = lastSyncAt();
      const { entries, removed } = dictionary.changedSince(pushFrom);
      const dictItems: DictionaryWire[] = [
        ...entries.map(toWire),
        ...removed.map(r => ({ id: r.id, word: '', soundsLike: [], updatedAt: r.deletedAt, deletedAt: r.deletedAt })),
      ];
      for (let i = 0; i < dictItems.length; i += PUSH_BATCH) {
        const batch = dictItems.slice(i, i + PUSH_BATCH);
        await client.push('dictionary', batch);
        pushed += batch.length;
      }
      const settingsStamp = settings.settingsUpdatedAt();
      if (settingsStamp > pushFrom) {
        await client.push<SettingsWire>('settings', [
          { id: 'me', data: localSettingsBlob(settings.get()), updatedAt: settingsStamp, deletedAt: null },
        ]);
        pushed += 1;
      }

      const since = cursor.get();
      const dictNow = await drain<DictionaryWire>('dictionary', since, rows => {
        if (rows.length) dictionary.applyRemote(rows);
        pulled += rows.length;
      });

      let newest: SettingsWire | undefined;
      const settingsNow = await drain<SettingsWire>('settings', since, rows => {
        for (const row of rows) if (!newest || row.updatedAt > newest.updatedAt) newest = row;
      });
      // Re-read: the user may have changed a setting while the network was busy.
      if (newest && newest.deletedAt == null && newest.updatedAt > settings.settingsUpdatedAt()) {
        // Keeps the remote stamp, so the blob is neither echoed back nor allowed to
        // outrank a newer edit from a third device.
        settings.applyRemote(remotePatch(newest.data), newest.updatedAt);
        pulled += 1;
      }

      cursor.set(Math.min(dictNow, settingsNow));
      settings.recordSync({ at: startedAt });
      const at = now();
      return { ok: true, pushed, pulled, message: `Synced ${pushed} up, ${pulled} down`, at };
    } catch (err) {
      const message = describe(err);
      const at = now();
      try {
        // The window stays at the last success, so nothing unpushed is skipped next run.
        settings.recordSync({ at: lastSyncAt(), error: message });
      } catch {
        // A disk that cannot record the failure must not turn it into a throw.
      }
      return { ok: false, pushed, pulled, message, at };
    }
  }

  return {
    /** One run at a time; a second caller shares the in-flight result. */
    syncNow(): Promise<SyncOutcome> {
      if (!running) running = run().finally(() => (running = null));
      return running;
    },
  };
}
