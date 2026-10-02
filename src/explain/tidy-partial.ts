/**
 * Text cut off mid-stream can end on the opening marker of bold, italics or
 * code, which markdown prints as raw asterisks until the closing one arrives.
 * A trailing marker is dropped only when it is unmatched (it appears an odd
 * number of times), so the closing marker of finished emphasis stays.
 */
export function tidyPartial(markdown: string): string {
  const text = markdown.trimEnd();
  const marker = /(\*{1,3}|_{1,3}|`+)$/.exec(text)?.[1];
  if (!marker) return markdown;
  const count = text.split(marker).length - 1;
  return count % 2 === 1 ? text.slice(0, -marker.length).trimEnd() : markdown;
}
