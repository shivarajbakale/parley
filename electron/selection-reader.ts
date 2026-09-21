import type { FieldReader } from './field-reader';
import type { Injector } from './injector';
import type { Rect } from './types';

/**
 * What Explain acts on: the text selected anywhere on screen, and where it is.
 *
 * The Accessibility read comes first because it is invisible and gives a
 * rectangle. Apps that hide their text (Chrome, Electron) get a copy instead,
 * and then the only anchor left is the pointer.
 */

/** Past this the selection is a document, and the answer would be a summary nobody asked for. */
export const MAX_EXPLAIN_CHARS = 8000;

export interface SelectionSnapshot {
  text: string;
  /** Screen rectangle of the selection; `null` means anchor at the pointer. */
  anchor: Rect | null;
}

export interface SelectionReader {
  /** `null` when nothing is selected, or the focus is a password field. */
  read(): Promise<SelectionSnapshot | null>;
}

export function createSelectionReader(deps: {
  reader: FieldReader;
  injector: Pick<Injector, 'copySelection'>;
}): SelectionReader {
  const clip = (text: string) => text.trim().slice(0, MAX_EXPLAIN_CHARS);

  return {
    async read() {
      const field = await deps.reader.read();
      // A password field must never be read, and Cmd+C is a read.
      if (field?.secure) return null;

      const selected = field?.selectedText.trim();
      if (selected) return { text: clip(selected), anchor: field?.selectionBounds ?? null };

      const copied = (await deps.injector.copySelection()).trim();
      return copied ? { text: clip(copied), anchor: null } : null;
    },
  };
}
