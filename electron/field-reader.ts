/**
 * Reads the focused text field through the bundled `parley-ax` helper
 * (`native/parley-ax.swift`). The helper never writes and never sends a key,
 * so a read is invisible to the user and leaves the clipboard alone.
 */

import type { TextRange } from './terminal-input';
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
  /**
   * The value, or for a very long one (a terminal's scrollback) only the part
   * around the caret: it starts at `valueOffset` in a whole `valueLength` long.
   */
  value: string;
  valueOffset: number;
  valueLength: number;
  /** The caret or selection in the whole value, when the app reports it. */
  caret: TextRange | null;
  /** The frontmost app, which tells a terminal from a text field. */
  bundleId: string | null;
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

function parseRange(raw: unknown): TextRange | null {
  if (typeof raw !== 'object' || raw === null) return null;
  const { location, length } = raw as Record<string, unknown>;
  if (!Number.isInteger(location) || !Number.isInteger(length)) return null;
  if ((location as number) < 0 || (length as number) < 0) return null;
  return { location, length } as TextRange;
}

export function parseFocusedField(stdout: string): FocusedField | null {
  let raw: unknown;
  try {
    raw = JSON.parse(stdout);
  } catch {
    return null;
  }
  if (typeof raw !== 'object' || raw === null || 'error' in raw) return null;
  const {
    editable,
    valueKnown,
    value,
    valueOffset,
    valueLength,
    caret,
    bundleId,
    selectedText,
    secure,
    selectionBounds,
    frontWindowBounds,
  } = raw as Record<string, unknown>;
  if (typeof editable !== 'boolean') return null;
  const text = typeof value === 'string' ? value : '';
  const offset = Number.isInteger(valueOffset) ? (valueOffset as number) : 0;
  return {
    editable,
    valueKnown: valueKnown === true,
    value: text,
    valueOffset: offset,
    valueLength: Number.isInteger(valueLength) ? (valueLength as number) : offset + text.length,
    caret: parseRange(caret),
    bundleId: typeof bundleId === 'string' && bundleId ? bundleId : null,
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

export type RunHelperWithArgs = (
  file: string,
  args: string[],
  options: { timeout: number; maxBuffer: number }
) => Promise<string>;

/**
 * The helper's AX messaging timeout is 1000ms, tuned for apps that build their
 * accessibility tree lazily (Electron apps); the extra 500ms covers spawning
 * the process, so the read is not killed just before it answers.
 */
const WINDOW_READ_TIMEOUT_MS = 1500;
/** `--window-only` prints four numbers; this is generous headroom, not a cap on text. */
const WINDOW_OUTPUT_BYTES = 16 * 1024;
/**
 * macOS checks a freshly installed binary before its first run (measured
 * past 1.5s), and a run killed before that check ends does not finish it.
 */
const WARM_UP_TIMEOUT_MS = 10_000;

export interface WindowLocator {
  /** The frontmost window's bounds, or `null` when the helper could not say. */
  frontWindowBounds(): Promise<Rect | null>;
  /** One unhurried run at launch, so the first orb's read is not the slow one. */
  warmUp(): Promise<void>;
}

/**
 * Where the user's window is, for placing the orb. Runs the helper with
 * `--window-only` so the focused field's value is never read: a field full of
 * text (a terminal, a long document) used to overflow the output cap, which
 * dropped the correction and left the orb on the cursor's display.
 */
export function createWindowLocator(deps: {
  helperPath: string;
  run: RunHelperWithArgs;
  onError?: (error: unknown) => void;
}): WindowLocator {
  return {
    async frontWindowBounds() {
      try {
        const stdout = await deps.run(deps.helperPath, ['--window-only'], {
          timeout: WINDOW_READ_TIMEOUT_MS,
          maxBuffer: WINDOW_OUTPUT_BYTES,
        });
        return parseFrontWindowBounds(stdout);
      } catch (error) {
        deps.onError?.(error);
        return null;
      }
    },
    async warmUp() {
      try {
        await deps.run(deps.helperPath, ['--window-only'], {
          timeout: WARM_UP_TIMEOUT_MS,
          maxBuffer: WINDOW_OUTPUT_BYTES,
        });
      } catch {
        // Nothing to place yet; a real read reports its own failure.
      }
    },
  };
}

const SELECT_TIMEOUT_MS = 2000;

/**
 * Moves the focused field's selection to `range`, so a paste replaces just
 * that part of a long document. False when the app would not take it.
 */
export function createRangeSelector(deps: {
  helperPath: string;
  run: RunHelperWithArgs;
}): (range: TextRange) => Promise<boolean> {
  return async (range) => {
    try {
      const stdout = await deps.run(
        deps.helperPath,
        ['--select', String(range.location), String(range.length)],
        { timeout: SELECT_TIMEOUT_MS, maxBuffer: WINDOW_OUTPUT_BYTES }
      );
      return (JSON.parse(stdout) as { selected?: unknown }).selected === true;
    } catch {
      return false;
    }
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
