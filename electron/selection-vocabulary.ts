/**
 * Turns the selected text into a short Whisper vocabulary hint, so a spoken
 * question that names something inside the selection ("what does useMemo do
 * here?") is transcribed with the right spelling instead of a guess. Whisper's
 * `prompt` only biases pronunciation and spelling toward words it contains —
 * it is not shown to the user and does not change what gets explained.
 */

const MAX_WORDS = 40;
const MAX_CHARS = 300;

export function selectionVocabulary(text: string): string {
  const words: string[] = [];
  const seen = new Set<string>();
  for (const raw of text.match(/[\p{L}\p{N}][\p{L}\p{N}'-]*/gu) ?? []) {
    if (raw.length < 2) continue;
    const key = raw.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    words.push(raw);
    if (words.length >= MAX_WORDS) break;
  }
  return words.join(', ').slice(0, MAX_CHARS);
}
