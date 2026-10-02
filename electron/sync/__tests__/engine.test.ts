import { describe, expect, it, vi } from 'vitest';

import { DEFAULT_SETTINGS } from '../../types';
import { type SyncClient, SyncHttpError } from '../client';
import { createSyncEngine } from '../engine';

function fakeClient() {
  return {
    signIn: vi.fn(),
    pull: vi.fn(async (resource: string, _since: number) =>
      resource === 'dictionary'
        ? {
            rows: [{ id: 'r1', word: 'Remote', soundsLike: [], updatedAt: 50, deletedAt: null }] as unknown[],
            now: 1000,
            hasMore: false,
          }
        : { rows: [] as unknown[], now: 1000, hasMore: false }),
    push: vi.fn(async (_r: string, items: unknown[]) => ({ rows: items, now: 1000 })),
  };
}

/** The fakes return plain rows; the client's generics are the caller's promise, not checkable here. */
const asClient = (c: ReturnType<typeof fakeClient>) => c as unknown as SyncClient;

function fakeDictionary() {
  const applied: unknown[] = [];
  return {
    applied,
    list: () => [],
    changedSince: vi.fn((_since: number) => ({
      entries: [{ id: 'l1', word: 'Local', soundsLike: ['lo cal'], uses: 0, lastUsedAt: 0, updatedAt: 70 }],
      removed: [{ id: 'gone', deletedAt: 80 }],
    })),
    applyRemote: vi.fn((rows: unknown[]) => {
      applied.push(...rows);
    }),
  };
}

function fakeSettings() {
  let current = { ...DEFAULT_SETTINGS, syncEnabled: true, syncUrl: 'http://x', syncEmail: 'a@b.c', tickSound: false };
  const recorded: unknown[] = [];
  let stamp = 60;
  return {
    recorded,
    get: () => current,
    update: vi.fn((patch: object) => (current = { ...current, ...patch })),
    applyRemote: vi.fn((patch: object, updatedAt: number) => {
      stamp = updatedAt;
      return (current = { ...current, ...patch });
    }),
    recordSync: vi.fn((r: { at: number; error?: string }) => {
      recorded.push(r);
    }),
    settingsUpdatedAt: vi.fn(() => stamp),
  };
}

const fixedCursor = (value: number) => ({ get: () => value, set: () => {} });

describe('sync engine', () => {
  it('pushes local changes since the cursor, pulls remote ones, advances the cursor', async () => {
    const client = fakeClient();
    const dictionary = fakeDictionary();
    const settings = fakeSettings();
    let cursor = 10;
    let clock = 998;
    let clockAtChangedSince = 0;
    dictionary.changedSince.mockImplementation((since: number) => {
      clockAtChangedSince = clock;
      return fakeDictionary().changedSince(since);
    });
    const engine = createSyncEngine({
      client: asClient(client),
      dictionary,
      settings,
      cursor: { get: () => cursor, set: v => (cursor = v) },
      lastSyncAt: () => 10,
      now: vi.fn(() => {
        clock += 1;
        return clock;
      }),
    });
    const outcome = await engine.syncNow();

    expect(outcome.ok).toBe(true);
    expect(dictionary.changedSince).toHaveBeenCalledWith(10);
    const dictPush = client.push.mock.calls.find(c => c[0] === 'dictionary')!;
    expect(dictPush[1]).toEqual([
      { id: 'l1', word: 'Local', soundsLike: ['lo cal'], updatedAt: 70, deletedAt: null },
      { id: 'gone', word: '', soundsLike: [], updatedAt: 80, deletedAt: 80 },
    ]);
    const settingsPush = client.push.mock.calls.find(c => c[0] === 'settings')!;
    expect(settingsPush[1][0]).toMatchObject({ updatedAt: 60, data: { tickSound: false } });
    expect((settingsPush[1][0] as { data: object }).data).not.toHaveProperty('syncUrl');
    expect((settingsPush[1][0] as { data: object }).data).not.toHaveProperty('syncEnabled');
    expect((settingsPush[1][0] as { data: object }).data).not.toHaveProperty('syncEmail');
    expect(dictionary.applied).toEqual([{ id: 'r1', word: 'Remote', soundsLike: [], updatedAt: 50, deletedAt: null }]);
    expect(cursor).toBe(1000);
    // The run's start, taken before changedSince, so edits made mid-run fall in the next window.
    expect(clockAtChangedSince).toBe(999);
    expect(settings.recordSync).toHaveBeenCalledWith({ at: 999 });
    expect(outcome.at).toBeGreaterThan(999);
  });

  it('pushes before it pulls', async () => {
    const order: string[] = [];
    const client = fakeClient();
    client.push.mockImplementation(async (r: string, items: unknown[]) => {
      order.push(`push:${r}`);
      return { rows: items, now: 1 };
    });
    client.pull.mockImplementation(async (r: string) => {
      order.push(`pull:${r}`);
      return { rows: [], now: 1, hasMore: false };
    });
    const engine = createSyncEngine({
      client: asClient(client), dictionary: fakeDictionary(), settings: fakeSettings(), cursor: fixedCursor(0), lastSyncAt: () => 0,
    });
    await engine.syncNow();
    expect(order).toEqual(['push:dictionary', 'push:settings', 'pull:dictionary', 'pull:settings']);
  });

  it('applies a newer remote settings blob and ignores an older one', async () => {
    const client = fakeClient();
    client.pull.mockImplementation(async (resource: string) =>
      resource === 'settings'
        ? {
            rows: [{ id: 'u', data: { tickSound: true, apiKey: 'x', syncUrl: 'evil' }, updatedAt: 90, deletedAt: null }],
            now: 1,
            hasMore: false,
          }
        : { rows: [], now: 1, hasMore: false });
    const settings = fakeSettings();
    const engine = createSyncEngine({
      client: asClient(client), dictionary: fakeDictionary(), settings, cursor: fixedCursor(0), lastSyncAt: () => 0,
    });
    await engine.syncNow();
    expect(settings.applyRemote).toHaveBeenCalledWith({ tickSound: true }, 90);
    expect(settings.update).not.toHaveBeenCalled();

    settings.applyRemote.mockClear();
    client.pull.mockImplementation(async (resource: string) =>
      resource === 'settings'
        ? { rows: [{ id: 'u', data: { tickSound: true }, updatedAt: 40, deletedAt: null }], now: 1, hasMore: false }
        : { rows: [], now: 1, hasMore: false });
    await engine.syncNow();
    expect(settings.applyRemote).not.toHaveBeenCalled();
  });

  it('keeps the remote stamp, so the applied blob is not echoed back next run', async () => {
    const client = fakeClient();
    client.pull.mockImplementation(async (resource: string) =>
      resource === 'settings'
        ? { rows: [{ id: 'u', data: { tickSound: true }, updatedAt: 90, deletedAt: null }], now: 1, hasMore: false }
        : { rows: [], now: 1, hasMore: false });
    const settings = fakeSettings();
    let last = 70;
    settings.recordSync.mockImplementation((r: { at: number }) => {
      last = r.at;
    });
    const dictionary = fakeDictionary();
    dictionary.changedSince.mockReturnValue({ entries: [], removed: [] });
    // The window opens at 70 (local stamp 60 is older, so nothing is pushed) and the
    // run records its start at 100, after the remote blob's 90.
    const engine = createSyncEngine({
      client: asClient(client), dictionary, settings, cursor: fixedCursor(0), lastSyncAt: () => last, now: () => 100,
    });
    await engine.syncNow();
    expect(settings.settingsUpdatedAt()).toBe(90);
    client.push.mockClear();
    await engine.syncNow();
    expect(client.push.mock.calls.filter(c => c[0] === 'settings')).toHaveLength(0);
  });

  it('does not overwrite a setting the user changed while the run was in flight', async () => {
    const client = fakeClient();
    client.pull.mockImplementation(async (resource: string) =>
      resource === 'settings'
        ? { rows: [{ id: 'u', data: { tickSound: true }, updatedAt: 90, deletedAt: null }], now: 1, hasMore: false }
        : { rows: [], now: 1, hasMore: false });
    const settings = fakeSettings();
    settings.settingsUpdatedAt.mockReturnValueOnce(60).mockReturnValue(95);
    const engine = createSyncEngine({
      client: asClient(client), dictionary: fakeDictionary(), settings, cursor: fixedCursor(0), lastSyncAt: () => 0,
    });
    const outcome = await engine.syncNow();
    expect(outcome.ok).toBe(true);
    expect(settings.applyRemote).not.toHaveBeenCalled();
  });

  it('pushes a settings blob the server accepts, gesture keys included', async () => {
    const SERVER_FORBIDDEN = /^(api_?key|key)$|apikey|token|secret|password/i;
    const client = fakeClient();
    const settings = fakeSettings();
    const engine = createSyncEngine({
      client: asClient(client), dictionary: fakeDictionary(), settings, cursor: fixedCursor(0), lastSyncAt: () => 0,
    });
    await engine.syncNow();
    const data = (client.push.mock.calls.find(c => c[0] === 'settings')![1][0] as { data: Record<string, unknown> }).data;
    expect(Object.keys(data).filter(k => SERVER_FORBIDDEN.test(k))).toEqual([]);
    expect(data).toHaveProperty('gestureKey', DEFAULT_SETTINGS.gestureKey);
  });

  it('fails instead of looping when the server does not advance the cursor', async () => {
    const client = fakeClient();
    client.pull.mockResolvedValue({ rows: [], now: 0, hasMore: true });
    const engine = createSyncEngine({
      client: asClient(client), dictionary: fakeDictionary(), settings: fakeSettings(), cursor: fixedCursor(0), lastSyncAt: () => 0,
    });
    const outcome = await engine.syncNow();
    expect(outcome).toMatchObject({ ok: false, message: 'Sync server did not advance the cursor' });
    expect(client.pull).toHaveBeenCalledTimes(1);
  });

  it('never throws: a down server becomes a recorded error and the cursor stays', async () => {
    const client = fakeClient();
    client.pull.mockRejectedValue(new TypeError('fetch failed'));
    const settings = fakeSettings();
    const set = vi.fn();
    const engine = createSyncEngine({
      client: asClient(client), dictionary: fakeDictionary(), settings, cursor: { get: () => 0, set }, lastSyncAt: () => 10,
      now: () => 999,
    });
    const outcome = await engine.syncNow();
    expect(outcome.ok).toBe(false);
    expect(outcome.message).toContain('fetch failed');
    expect(outcome.at).toBe(999);
    // A failed run leaves the push window where the last success put it.
    expect(settings.recordSync).toHaveBeenCalledWith({ at: 10, error: expect.stringContaining('fetch failed') });
    expect(set).not.toHaveBeenCalled();
  });

  it('never throws on a rejecting push either', async () => {
    const client = fakeClient();
    client.push.mockRejectedValue(new Error('boom'));
    const settings = fakeSettings();
    const engine = createSyncEngine({
      client: asClient(client), dictionary: fakeDictionary(), settings, cursor: fixedCursor(0), lastSyncAt: () => 0,
    });
    const outcome = await engine.syncNow();
    expect(outcome).toMatchObject({ ok: false, message: 'boom' });
    expect(client.pull).not.toHaveBeenCalled();
  });

  it('a 401 tells the user they are signed out', async () => {
    const client = fakeClient();
    client.push.mockRejectedValue(new SyncHttpError(401, 'Invalid token'));
    const settings = fakeSettings();
    const engine = createSyncEngine({
      client: asClient(client), dictionary: fakeDictionary(), settings, cursor: fixedCursor(0), lastSyncAt: () => 0,
    });
    const outcome = await engine.syncNow();
    expect(outcome.ok).toBe(false);
    expect(outcome.message).toBe('Signed out: the server rejected the token');
    expect(settings.recordSync).toHaveBeenCalledWith(
      expect.objectContaining({ error: 'Signed out: the server rejected the token' }),
    );
  });

  it('drains every page while hasMore is true', async () => {
    const client = fakeClient();
    client.pull.mockImplementation(async (resource: string, since: number) => {
      if (resource === 'dictionary' && since === 0) return { rows: [{ id: 'a' }], now: 500, hasMore: true };
      if (resource === 'dictionary') return { rows: [{ id: 'b' }], now: 700, hasMore: false };
      return { rows: [], now: 900, hasMore: false };
    });
    const dictionary = fakeDictionary();
    let cursor = 0;
    const engine = createSyncEngine({
      client: asClient(client), dictionary, settings: fakeSettings(), cursor: { get: () => cursor, set: v => (cursor = v) }, lastSyncAt: () => 0,
    });
    const outcome = await engine.syncNow();
    expect(outcome.ok).toBe(true);
    const dictPulls = client.pull.mock.calls.filter(c => c[0] === 'dictionary');
    expect(dictPulls.map(c => c[1])).toEqual([0, 500]);
    expect(dictionary.applied).toEqual([{ id: 'a' }, { id: 'b' }]);
    expect(cursor).toBe(700);
  });

  it('splits a large dictionary push into requests of 500', async () => {
    const client = fakeClient();
    const dictionary = fakeDictionary();
    dictionary.changedSince.mockReturnValue({
      entries: Array.from({ length: 1201 }, (_, i) => ({
        id: `e${i}`, word: `w${i}`, soundsLike: [], uses: 0, lastUsedAt: 0, updatedAt: 70,
      })),
      removed: [],
    });
    const engine = createSyncEngine({
      client: asClient(client), dictionary, settings: fakeSettings(), cursor: fixedCursor(0), lastSyncAt: () => 0,
    });
    const outcome = await engine.syncNow();
    const sizes = client.push.mock.calls.filter(c => c[0] === 'dictionary').map(c => c[1].length);
    expect(sizes).toEqual([500, 500, 201]);
    expect(outcome.pushed).toBe(1202);
  });

  it('runs one sync at a time', async () => {
    const client = fakeClient();
    const engine = createSyncEngine({
      client: asClient(client), dictionary: fakeDictionary(), settings: fakeSettings(), cursor: fixedCursor(0), lastSyncAt: () => 0,
    });
    const [a, b] = await Promise.all([engine.syncNow(), engine.syncNow()]);
    expect(a).toBe(b);
    expect(client.pull.mock.calls.filter(c => c[0] === 'dictionary')).toHaveLength(1);
  });
});
