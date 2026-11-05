import { readFileSync } from 'node:fs';

/**
 * "Is this a word any English speaker writes without help?" Answered from the
 * word list macOS ships, read on first use: it is 2.5 MB, and most sessions
 * never see a correction.
 */

const SYSTEM_WORD_LIST = '/usr/share/dict/words';

export function createCommonWords(
  deps: { read?: () => string } = {}
): (word: string) => boolean {
  const read = deps.read ?? (() => readFileSync(SYSTEM_WORD_LIST, 'utf8'));
  let known: Set<string> | null | undefined;

  return (word) => {
    if (known === undefined) {
      try {
        known = new Set(read().toLowerCase().split('\n'));
      } catch {
        known = null;
      }
    }
    // Without the list, plain lowercase letters are assumed ordinary, so only
    // names and mixed-case jargon are ever offered. Strict beats noisy.
    if (known === null) return /^[a-z']+$/.test(word);
    return known.has(word);
  };
}
