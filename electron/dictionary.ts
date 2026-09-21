/**
 * The personal dictionary, as pure functions. It acts twice on a dictation:
 * its words ride along with the audio so Whisper leans toward the user's
 * spelling, and its rules fix what Whisper still got wrong before the paste.
 */

export interface DictionaryEntry {
  id: string;
  /** Exactly as it should be written: "MiniMax", "kubectl". */
  word: string;
  /** What Whisper writes instead: "mini max". Each becomes a replacement rule. */
  soundsLike: string[];
  uses: number;
  /** Milliseconds since the epoch; a new entry starts at its creation time. */
  lastUsedAt: number;
}

/**
 * Whisper reads only the last 224 tokens of a prompt. No tokenizer ships with
 * the app, so this is a character budget that stays under it for English.
 */
export const MAX_PROMPT_CHARS = 700;

const PROMPT_LEAD = 'Notes about ';

function sentence(words: string[]): string {
  if (words.length === 0) return '';
  if (words.length === 1) return `${PROMPT_LEAD}${words[0]}.`;
  return `${PROMPT_LEAD}${words.slice(0, -1).join(', ')} and ${words[words.length - 1]}.`;
}

/**
 * The `prompt` for one transcription. `sessionWords` are words that matter
 * right now and are not stored; they go first. Whisper treats a prompt as
 * earlier text rather than as an instruction, so this is a plain sentence that
 * happens to contain the words.
 */
export function whisperPrompt(entries: DictionaryEntry[], sessionWords: string[] = []): string {
  const ranked = [...entries]
    .sort((a, b) => b.lastUsedAt - a.lastUsedAt || b.uses - a.uses)
    .map((entry) => entry.word);

  // A session word the dictionary knows keeps its place but takes the stored spelling.
  const stored = new Map(ranked.map((word) => [word.toLowerCase(), word]));
  const seen = new Set<string>();
  const picked: string[] = [];
  for (const candidate of [...sessionWords, ...ranked]) {
    const key = candidate.toLowerCase();
    if (seen.has(key)) continue;
    const word = stored.get(key) ?? candidate;
    if (sentence([...picked, word]).length > MAX_PROMPT_CHARS) break;
    seen.add(key);
    picked.push(word);
  }
  return sentence(picked);
}

function normalize(phrase: string): string {
  return phrase.trim().toLowerCase().replace(/\s+/g, ' ');
}

function escapeRegExp(text: string): string {
  return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Rewrite every sounds-like phrase, and every miscased copy of a word, into
 * the word. Whole phrases only, in one pass so a replacement is never matched
 * again. `hits` holds the id of each entry found, right or wrong: both are uses.
 */
export function applyReplacements(
  text: string,
  entries: DictionaryEntry[]
): { text: string; hits: string[] } {
  const byPhrase = new Map<string, DictionaryEntry>();
  for (const entry of entries) {
    for (const phrase of [entry.word, ...entry.soundsLike]) {
      const key = normalize(phrase);
      if (key && !byPhrase.has(key)) byPhrase.set(key, entry);
    }
  }
  if (byPhrase.size === 0) return { text, hits: [] };

  // Longest first, so "mini max" wins over a separate rule for "max".
  const alternatives = [...byPhrase.keys()]
    .sort((a, b) => b.length - a.length)
    .map((phrase) => phrase.split(' ').map(escapeRegExp).join('\\s+'));
  const pattern = new RegExp(
    `(?<![\\p{L}\\p{N}])(?:${alternatives.join('|')})(?![\\p{L}\\p{N}])`,
    'giu'
  );

  const hits = new Set<string>();
  const replaced = text.replace(pattern, (match) => {
    const entry = byPhrase.get(normalize(match));
    if (!entry) return match;
    hits.add(entry.id);
    return entry.word;
  });
  return { text: replaced, hits: [...hits] };
}

/** The pre-dictionary `vocabulary` setting: free text, comma or newline separated. */
export function splitVocabulary(vocabulary: string): string[] {
  return vocabulary
    .split(/[,\n]/)
    .map((word) => word.trim())
    .filter(Boolean);
}
