/**
 * Reads the focused text field through the bundled `parley-ax` helper
 * (`native/parley-ax.swift`). The helper never writes and never sends a key,
 * so a read is invisible to the user and leaves the clipboard alone.
 */

/** A scrollback-sized value is not a field anyone wants rewritten. */
const MAX_OUTPUT_BYTES = 1024 * 1024;
const READ_TIMEOUT_MS = 2000;

export interface FocusedField {
  /** The focused element takes text, and is not a password field. */
  editable: boolean;
  /**
   * The app answered for the value. False is "would not say", which Chrome and
   * Electron often do; true with an empty `value` is a field that is empty.
   */
  valueKnown: boolean;
  value: string;
  selectedText: string;
}

export interface FieldReader {
  /** `null` when nothing is focused or the helper could not answer. */
  read(): Promise<FocusedField | null>;
}

export type RunHelper = (
  file: string,
  options: { timeout: number; maxBuffer: number }
) => Promise<string>;

export function parseFocusedField(stdout: string): FocusedField | null {
  let raw: unknown;
  try {
    raw = JSON.parse(stdout);
  } catch {
    return null;
  }
  if (typeof raw !== 'object' || raw === null || 'error' in raw) return null;
  const { editable, valueKnown, value, selectedText } = raw as Record<string, unknown>;
  if (typeof editable !== 'boolean') return null;
  return {
    editable,
    valueKnown: valueKnown === true,
    value: typeof value === 'string' ? value : '',
    selectedText: typeof selectedText === 'string' ? selectedText : '',
  };
}

export function createFieldReader(deps: { helperPath: string; run: RunHelper }): FieldReader {
  return {
    async read() {
      try {
        const stdout = await deps.run(deps.helperPath, {
          timeout: READ_TIMEOUT_MS,
          maxBuffer: MAX_OUTPUT_BYTES,
        });
        return parseFocusedField(stdout);
      } catch {
        // A missing helper, a timeout or an oversized value all mean the same
        // thing to the caller: there is no field to edit.
        return null;
      }
    },
  };
}
