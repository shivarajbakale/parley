import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

import { beforeEach, describe, expect, it } from 'vitest';

import { createDictionaryStore, MAX_ENTRIES } from '../dictionary-store';

describe('dictionary store', () => {
  let dir: string;
  let now: number;
  const open = () => createDictionaryStore({ dir, now: () => now });

  beforeEach(() => {
    dir = mkdtempSync(path.join(tmpdir(), 'parley-dictionary-'));
    now = 1000;
  });

  it('is empty on first launch and with a corrupted file', () => {
    expect(open().list()).toEqual([]);
    writeFileSync(path.join(dir, 'dictionary.json'), '{nope');
    expect(open().list()).toEqual([]);
  });

  it('adds a word and persists it across instances', () => {
    const added = open().upsert({ word: ' MiniMax ', soundsLike: ['mini max', ' '] });
    expect(added).toMatchObject({
      word: 'MiniMax',
      soundsLike: ['mini max'],
      uses: 0,
      lastUsedAt: 1000,
    });
    expect(open().list()).toEqual([added]);
  });

  it('merges a word it already has instead of adding a twin', () => {
    const store = open();
    const first = store.upsert({ word: 'MiniMax', soundsLike: ['mini max'] });
    const second = store.upsert({ word: 'minimax', soundsLike: ['minmax', 'Mini Max'] });
    expect(second?.id).toBe(first?.id);
    expect(store.list()).toHaveLength(1);
    expect(store.list()[0]).toMatchObject({ word: 'minimax', soundsLike: ['mini max', 'minmax'] });
  });

  it('edits by id, replacing the sounds-like list', () => {
    const store = open();
    const added = store.upsert({ word: 'Shivraj', soundsLike: ['shiv raj'] });
    store.upsert({ id: added?.id, word: 'Shivaraj', soundsLike: [] });
    expect(store.list()).toEqual([{ ...added, word: 'Shivaraj', soundsLike: [] }]);
  });

  it('drops a sounds-like that is only the word again', () => {
    expect(open().upsert({ word: 'Parley', soundsLike: ['parley', 'parlay'] })?.soundsLike).toEqual(
      ['parlay']
    );
  });

  it('refuses an empty or oversized word', () => {
    const store = open();
    expect(store.upsert({ word: '   ', soundsLike: [] })).toBeNull();
    expect(store.upsert({ word: 'x'.repeat(61), soundsLike: [] })).toBeNull();
    expect(store.upsert({ word: 42 as never, soundsLike: 'no' as never })).toBeNull();
    expect(store.list()).toEqual([]);
  });

  it('removes by id', () => {
    const store = open();
    const added = store.upsert({ word: 'Groq', soundsLike: [] });
    store.remove(added?.id ?? '');
    expect(open().list()).toEqual([]);
  });

  it('records uses with the time they happened', () => {
    const store = open();
    const a = store.upsert({ word: 'Groq', soundsLike: [] });
    store.upsert({ word: 'Parley', soundsLike: [] });
    now = 5000;
    store.recordUses([a?.id ?? '', 'unknown']);
    const [groq, parley] = open().list();
    expect(groq).toMatchObject({ uses: 1, lastUsedAt: 5000 });
    expect(parley).toMatchObject({ uses: 0, lastUsedAt: 1000 });
  });

  it('stops growing at the cap', () => {
    const store = open();
    for (let i = 0; i < MAX_ENTRIES; i++) store.upsert({ word: `w${i}`, soundsLike: [] });
    expect(store.upsert({ word: 'one-too-many', soundsLike: [] })).toBeNull();
    expect(store.list()).toHaveLength(MAX_ENTRIES);
  });

  it('keeps only well-formed entries from a hand-edited file', () => {
    writeFileSync(
      path.join(dir, 'dictionary.json'),
      JSON.stringify({
        entries: [
          { id: 'a', word: 'Groq', soundsLike: ['grok', 7], uses: 3, lastUsedAt: 9 },
          { id: 'b', word: '' },
          'junk',
        ],
      })
    );
    expect(open().list()).toEqual([
      { id: 'a', word: 'Groq', soundsLike: ['grok'], uses: 3, lastUsedAt: 9, updatedAt: 9 },
    ]);
  });

  it('stops offering a word that was declined twice, until it is added', () => {
    const store = open();
    store.decline('MiniMax');
    expect(store.isIgnored('minimax')).toBe(false);
    store.decline('minimax');
    expect(open().isIgnored('MiniMax')).toBe(true);

    const reopened = open();
    reopened.upsert({ word: 'MiniMax', soundsLike: [] });
    expect(open().isIgnored('MiniMax')).toBe(false);
  });

  it('writes plain JSON a person can read and export', () => {
    open().upsert({ word: 'Groq', soundsLike: [] });
    const body = JSON.parse(readFileSync(path.join(dir, 'dictionary.json'), 'utf8'));
    expect(body.entries[0].word).toBe('Groq');
  });

  it('stamps updatedAt and reports changes since a time', () => {
    let clock = 100;
    const store = createDictionaryStore({ dir, now: () => clock });
    const a = store.upsert({ word: 'MiniMax', soundsLike: ['mini max'] })!;
    clock = 200;
    const b = store.upsert({ word: 'Groq', soundsLike: [] })!;
    expect(a.updatedAt).toBe(100);
    expect(store.changedSince(150).entries.map(e => e.id)).toEqual([b.id]);
    clock = 300;
    store.remove(a.id);
    expect(store.changedSince(250).removed).toEqual([{ id: a.id, deletedAt: 300 }]);
    expect(store.list().map(e => e.id)).toEqual([b.id]);
  });

  it('applies newer remote rows and ignores older ones', () => {
    const clock = 100;
    const store = createDictionaryStore({ dir, now: () => clock });
    const a = store.upsert({ word: 'MiniMax', soundsLike: [] })!;
    store.applyRemote([
      { id: a.id, word: 'MiniMax', soundsLike: ['mini max'], updatedAt: 150, deletedAt: null },
      { id: 'remote-1', word: 'Deepgram', soundsLike: [], updatedAt: 120, deletedAt: null },
      { id: a.id, word: 'Stale', soundsLike: [], updatedAt: 90, deletedAt: null },
    ]);
    const byId = Object.fromEntries(store.list().map(e => [e.id, e]));
    expect(byId[a.id].soundsLike).toEqual(['mini max']);
    expect(byId['remote-1'].word).toBe('Deepgram');
    store.applyRemote([
      { id: 'remote-1', word: 'Deepgram', soundsLike: [], updatedAt: 130, deletedAt: 130 },
    ]);
    expect(store.list().some(e => e.id === 'remote-1')).toBe(false);
    expect(
      createDictionaryStore({ dir })
        .changedSince(0)
        .removed.some(r => r.id === 'remote-1')
    ).toBe(true);
  });

  it('migrates an entry without updatedAt from lastUsedAt', () => {
    writeFileSync(
      path.join(dir, 'dictionary.json'),
      JSON.stringify({
        entries: [{ id: 'old', word: 'Old', soundsLike: [], uses: 1, lastUsedAt: 42 }],
      })
    );
    expect(createDictionaryStore({ dir }).list()[0].updatedAt).toBe(42);
  });

  it('re-applying the same remote rows changes nothing', () => {
    const store = createDictionaryStore({ dir, now: () => 100 });
    const rows = [
      { id: 'r1', word: 'Deepgram', soundsLike: [], updatedAt: 120, deletedAt: null },
      { id: 'r2', word: 'Gone', soundsLike: [], updatedAt: 130, deletedAt: 130 },
    ];
    store.applyRemote(rows);
    const before = JSON.stringify([store.list(), store.changedSince(0)]);
    store.applyRemote(rows);
    expect(JSON.stringify([store.list(), store.changedSince(0)])).toBe(before);
  });

  it('keeps local uses on a remote update and caps tombstones at 500', () => {
    const store = createDictionaryStore({ dir, now: () => 100 });
    const a = store.upsert({ word: 'Groq', soundsLike: [] })!;
    store.recordUses([a.id]);
    store.applyRemote([
      { id: a.id, word: 'Groq', soundsLike: ['grok'], updatedAt: 500, deletedAt: null },
    ]);
    expect(store.list()[0]).toMatchObject({ uses: 1, lastUsedAt: 100, updatedAt: 500 });
    store.applyRemote(
      Array.from({ length: 510 }, (_, i) => ({
        id: `t${i}`,
        word: 'x',
        soundsLike: [],
        updatedAt: 1000 + i,
        deletedAt: 1000 + i,
      }))
    );
    const removed = store.changedSince(0).removed;
    expect(removed).toHaveLength(500);
    expect(removed.some(r => r.id === 't509')).toBe(true);
    expect(removed.some(r => r.id === 't0')).toBe(false);
  });
});
