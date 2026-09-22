/**
 * Reads the focused text field through the bundled `parley-ax` helper
 * (`native/parley-ax.swift`). The helper never writes and never sends a key,
 * so a read is invisible to the user and leaves the clipboard alone.
 */

import type { Rect } from './types';

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
  /** A password field: nothing in it is Parley's to read, by any route. */
  secure: boolean;
  /** Screen rectangle of the selection, when the app reports one. */
  selectionBounds: Rect | null;
  /** The frontmost app's key window — the window the user is actually on,
   * which can be on a different display than the mouse. `null` when the
   * helper could not read it (an app that fights Accessibility, no window). */
  frontWindowBounds: Rect | null;
}

export interface FieldReader {
  /** `null` when nothing is focused or the helper could not answer. */
  read(): Promise<FocusedField | null>;
}

export type RunHelper = (
  file: string,
  options: { timeout: number; maxBuffer: number }
) => Promise<string>;

function parseRect(raw: unknown): Rect | null {
  if (typeof raw !== 'object' || raw === null) return null;
  const { x, y, width, height } = raw as Record<string, unknown>;
  const numbers = [x, y, width, height];
  if (!numbers.every((n) => typeof n === 'number' && Number.isFinite(n))) return null;
  // An app that cannot say where the selection is often answers with a zero rect.
  if ((width as number) <= 0 || (height as number) <= 0) return null;
  return { x, y, width, height } as Rect;
}

export function parseFocusedField(stdout: string): FocusedField | null {
  let raw: unknown;
  try {
    raw = JSON.parse(stdout);
  } catch {
    return null;
  }
  if (typeof raw !== 'object' || raw === null || 'error' in raw) return null;
  const { editable, valueKnown, value, selectedText, secure, selectionBounds, frontWindowBounds } =
    raw as Record<string, unknown>;
  if (typeof editable !== 'boolean') return null;
  return {
    editable,
    valueKnown: valueKnown === true,
    value: typeof value === 'string' ? value : '',
    selectedText: typeof selectedText === 'string' ? selectedText : '',
    secure: secure === true,
    selectionBounds: parseRect(selectionBounds),
    frontWindowBounds: parseRect(frontWindowBounds),
  };
}

/**
 * Just the frontmost window's bounds, from the same helper output, even on the
 * "nothing focused" path — the orb needs this when no field has focus at all.
 */
export function parseFrontWindowBounds(stdout: string): Rect | null {
  try {
    const raw = JSON.parse(stdout) as Record<string, unknown>;
    return parseRect(raw.frontWindowBounds);
  } catch {
    return null;
  }
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
