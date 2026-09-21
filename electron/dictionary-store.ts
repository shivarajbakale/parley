import { randomUUID } from 'node:crypto';
import { readFileSync, renameSync, writeFileSync } from 'node:fs';
import path from 'node:path';

import type { DictionaryEntry } from './dictionary';

/**
 * The personal dictionary on disk: `dictionary.json` beside `settings.json`.
 * Plain JSON on purpose. It holds spellings, not secrets, and a file the user
 * can read is a file they can back up, share and trust.
 */

export const MAX_ENTRIES = 500;
const MAX_WORD_CHARS = 60;
const MAX_SOUNDS_LIKE = 8;
/** Offers to remember a word stop after this many go unanswered. */
export const MAX_DECLINES = 2;

export interface DictionaryInput {
  /** Present to edit that entry; absent to add, or to merge into the same word. */
  id?: string;
  word: string;
  soundsLike: string[];
}

export interface DictionaryStore {
  list(): DictionaryEntry[];
  /** `null` when the input is not a usable word, or the dictionary is full. */
  upsert(input: DictionaryInput): DictionaryEntry | null;
  remove(id: string): void;
  recordUses(ids: string[]): void;
  /** The user let an offer to remember this word pass. */
  decline(word: string): void;
  /** Declined often enough that offering again would be nagging. */
  isIgnored(word: string): boolean;
}

function cleanPhrase(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const phrase = value.trim().replace(/\s+/g, ' ');
  return phrase && phrase.length <= MAX_WORD_CHARS ? phrase : null;
}

/** Distinct phrases, ignoring case, that are not just the word itself. */
function cleanSoundsLike(value: unknown, word: string): string[] {
  if (!Array.isArray(value)) return [];
  const seen = new Set([word.toLowerCase()]);
  const out: string[] = [];
  for (const item of value) {
    const phrase = cleanPhrase(item);
    if (!phrase || seen.has(phrase.toLowerCase())) continue;
    seen.add(phrase.toLowerCase());
    out.push(phrase);
  }
  return out.slice(0, MAX_SOUNDS_LIKE);
}

/** The file is as untrusted as the renderer: a person may have edited it. */
function cleanEntry(value: unknown): DictionaryEntry | null {
  if (typeof value !== 'object' || value === null) return null;
  const raw = value as Record<string, unknown>;
  const word = cleanPhrase(raw.word);
  if (!word || typeof raw.id !== 'string' || !raw.id) return null;
  return {
    id: raw.id,
    word,
    soundsLike: cleanSoundsLike(raw.soundsLike, word),
    uses: typeof raw.uses === 'number' && raw.uses >= 0 ? Math.floor(raw.uses) : 0,
    lastUsedAt: typeof raw.lastUsedAt === 'number' ? raw.lastUsedAt : 0,
  };
}

export function createDictionaryStore(deps: { dir: string; now?: () => number }): DictionaryStore {
  const file = path.join(deps.dir, 'dictionary.json');
  const now = deps.now ?? Date.now;

  let entries: DictionaryEntry[] = [];
  /** Lowercase word to the number of offers declined. */
  let declined: Record<string, number> = {};
  try {
    const body = JSON.parse(readFileSync(file, 'utf8')) as {
      entries?: unknown;
      declined?: unknown;
    };
    if (typeof body.declined === 'object' && body.declined !== null) {
      declined = Object.fromEntries(
        Object.entries(body.declined).filter(([, count]) => typeof count === 'number')
      ) as Record<string, number>;
    }
    if (Array.isArray(body.entries)) {
      entries = body.entries
        .map(cleanEntry)
        .filter((entry): entry is DictionaryEntry => entry !== null)
        .slice(0, MAX_ENTRIES);
    }
  } catch {
    // First launch or a corrupted file: an empty dictionary is fine.
  }

  function save() {
    // Rename is atomic, so a crash mid-write cannot leave half a dictionary.
    const temporary = `${file}.tmp`;
    writeFileSync(temporary, JSON.stringify({ entries, declined }, null, 2));
    renameSync(temporary, file);
  }

  return {
    list: () => entries,

    upsert(input) {
      const word = cleanPhrase(input?.word);
      if (!word) return null;
      const soundsLike = cleanSoundsLike(input.soundsLike, word);

      const edited = input.id ? entries.find((entry) => entry.id === input.id) : undefined;
      const twin = entries.find((entry) => entry.word.toLowerCase() === word.toLowerCase());
      const existing = edited ?? twin;

      let next: DictionaryEntry;
      if (existing) {
        next = {
          ...existing,
          word,
          // An edit states the whole list; a re-add only ever teaches more.
          soundsLike: edited
            ? soundsLike
            : cleanSoundsLike([...existing.soundsLike, ...soundsLike], word),
        };
        entries = entries.map((entry) => (entry.id === existing.id ? next : entry));
      } else {
        if (entries.length >= MAX_ENTRIES) return null;
        next = { id: randomUUID(), word, soundsLike, uses: 0, lastUsedAt: now() };
        entries = [...entries, next];
      }
      // Adding a word by any route is a change of mind about declining it.
      delete declined[word.toLowerCase()];
      save();
      return next;
    },

    remove(id) {
      const kept = entries.filter((entry) => entry.id !== id);
      if (kept.length === entries.length) return;
      entries = kept;
      save();
    },

    recordUses(ids) {
      const hit = new Set(ids);
      let changed = false;
      entries = entries.map((entry) => {
        if (!hit.has(entry.id)) return entry;
        changed = true;
        return { ...entry, uses: entry.uses + 1, lastUsedAt: now() };
      });
      if (changed) save();
    },

    decline(word) {
      const key = word.toLowerCase();
      declined = { ...declined, [key]: (declined[key] ?? 0) + 1 };
      save();
    },

    isIgnored: (word) => (declined[word.toLowerCase()] ?? 0) >= MAX_DECLINES,
  };
}
