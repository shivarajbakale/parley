/**
 * Did the user just fix a word Parley got wrong? Pure functions: the text
 * Parley pasted and the field as it is now go in, and at most one
 * `heard -> word` pair comes out.
 *
 * It is strict on purpose. A miss costs nothing, since the word can still be
 * added by hand. A false alarm is a pill popping up over ordinary editing.
 */

export interface Correction {
  /** What Whisper wrote: "mini max". */
  heard: string;
  /** What the user turned it into: "MiniMax". */
  word: string;
}

export interface DetectOptions {
  /** Lowercase in. True for a word any English speaker writes without help. */
  isCommonWord(word: string): boolean;
}

/** The longest run of words one correction may replace, and may become. */
const MAX_HEARD_WORDS = 3;
const MAX_WORD_WORDS = 2;
/** Unchanged words needed around the change, so its place in the field is certain. */
const MIN_CONTEXT_WORDS = 3;
/** Share of letters two spellings must have in common. */
const MIN_SIMILARITY = 0.5;

const EDGE_PUNCTUATION = /^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$/gu;

function words(text: string): string[] {
  return text.trim().split(/\s+/).filter(Boolean);
}

function bare(phrase: string): string {
  return phrase.replace(EDGE_PUNCTUATION, '');
}

function escapeRegExp(text: string): string {
  return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function editDistance(a: string, b: string): number {
  let previous = Array.from({ length: b.length + 1 }, (_, i) => i);
  for (let i = 1; i <= a.length; i++) {
    const current = [i];
    for (let j = 1; j <= b.length; j++) {
      current[j] = Math.min(
        previous[j] + 1,
        current[j - 1] + 1,
        previous[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1)
      );
    }
    previous = current;
  }
  return previous[b.length];
}

/** Letters only, with the spellings English uses for one sound folded together. */
function soundKey(phrase: string): string {
  return phrase
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]/gu, '')
    .replace(/ph/g, 'f')
    .replace(/ck|c(?![eiy])|q/g, 'k')
    .replace(/(.)\1+/g, '$1');
}

/** A respelling of the same sounds, as opposed to a different word. */
export function soundsAlike(heard: string, word: string): boolean {
  const a = soundKey(heard);
  const b = soundKey(word);
  if (!a || !b) return false;
  return 1 - editDistance(a, b) / Math.max(a.length, b.length) >= MIN_SIMILARITY;
}

/** "tested", "testing" and "tests" are as ordinary as "test". */
function isOrdinary(word: string, isCommonWord: (word: string) => boolean): boolean {
  const lower = word.toLowerCase();
  if (isCommonWord(lower)) return true;
  for (const suffix of ["'s", 'ing', 'ed', 'es', 'ly', 's', 'd']) {
    if (!lower.endsWith(suffix)) continue;
    const stem = lower.slice(0, -suffix.length);
    if (stem.length >= 2 && (isCommonWord(stem) || isCommonWord(`${stem}e`))) return true;
  }
  return false;
}

/**
 * Worth a dictionary entry: either not an ordinary word at all ("kubectl"), or
 * an ordinary word the user capitalised as a name, which only counts when the
 * letters changed too and it does not simply open the sentence.
 */
function isDictionaryWord(
  heard: string,
  word: string,
  opensSentence: boolean,
  isCommonWord: (word: string) => boolean
): boolean {
  const tokens = words(word).map(bare).filter(Boolean);
  if (tokens.some((token) => !isOrdinary(token, isCommonWord))) return true;
  const respelled = heard.toLowerCase() !== word.toLowerCase();
  return respelled && !opensSentence && tokens.some((token) => /^\p{Lu}/u.test(token));
}

export function detectCorrection(
  pasted: string,
  fieldValue: string,
  options: DetectOptions
): Correction | null {
  const spoken = words(pasted);
  const field = words(fieldValue).join(' ');
  if (spoken.length < MIN_CONTEXT_WORDS + 1 || !field) return null;
  if (field.includes(spoken.join(' '))) return null;

  // One change means the field still holds everything before it and everything
  // after it, with something new in between. Try the smallest change first.
  for (let size = 1; size <= MAX_HEARD_WORDS; size++) {
    for (let start = 0; start + size <= spoken.length; start++) {
      const before = spoken.slice(0, start);
      const after = spoken.slice(start + size);
      if (before.length + after.length < MIN_CONTEXT_WORDS) continue;

      const pattern = new RegExp(
        (before.length ? `(?:^| )${escapeRegExp(before.join(' '))} ` : '(?:^| )') +
          `(\\S+(?: \\S+){0,${MAX_WORD_WORDS - 1}}?)` +
          (after.length ? ` ${escapeRegExp(after.join(' '))}(?: |$)` : '(?: |$)')
      );
      const match = pattern.exec(field);
      if (!match) continue;

      const heard = bare(spoken.slice(start, start + size).join(' '));
      const word = bare(match[1]);
      if (!heard || word.length < 2 || heard === word) return null;
      if (!soundsAlike(heard, word)) return null;
      const opensSentence = start === 0 || /[.!?]$/.test(spoken[start - 1]);
      if (!isDictionaryWord(heard, word, opensSentence, options.isCommonWord)) return null;
      return { heard, word };
    }
  }
  return null;
}
