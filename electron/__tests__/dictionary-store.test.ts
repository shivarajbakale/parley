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
    expect(open().upsert({ word: 'Parley', soundsLike: ['parley', 'parlay'] })?.soundsLike).toEqual([
      'parlay',
    ]);
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
      { id: 'a', word: 'Groq', soundsLike: ['grok'], uses: 3, lastUsedAt: 9 },
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
});
