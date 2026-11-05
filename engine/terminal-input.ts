/**
 * What a voice edit means in a terminal, and in a document too long to rewrite
 * whole.
 *
 * A terminal hands the Accessibility API its entire scrollback as one text
 * area, so "the whole field" is thousands of lines the user never meant. What
 * they mean is the input they are typing: the text from the prompt to the
 * caret. Writing it back cannot be select-all and paste either — a terminal
 * pastes at the cursor whatever is selected — so the input is erased with
 * backspaces first. A backspace cannot reach printed output, so erasing a few
 * too many stops harmlessly at the start of the input.
 */

export const TERMINAL_BUNDLE_IDS: ReadonlySet<string> = new Set([
  'com.googlecode.iterm2',
  'com.apple.Terminal',
  'com.mitchellh.ghostty',
  'dev.warp.Warp-Stable',
  'net.kovidgoyal.kitty',
  'io.alacritty',
  'org.alacritty',
  'com.github.wez.wezterm',
  'co.zeit.hyper',
  'org.tabby',
]);

export function isTerminal(bundleId: string | null): boolean {
  return bundleId !== null && TERMINAL_BUNDLE_IDS.has(bundleId);
}

/**
 * The prompt markers of Claude Code (`❯`), Codex (`›`), shells (`$ % #`) and
 * the common zsh themes. A marker counts only as its own word, so `$HOME` or
 * `50%` inside a command is not mistaken for a prompt.
 */
const PROMPT_MARKER = /(?:^|\s)[❯›>$%#λ»](?=\s)/g;
/** oh-my-zsh's default theme puts the directory and branch after its arrow: `➜  app git:(main) ✗ `. */
const ROBBYRUSSELL_PROMPT = /➜\s+\S+(?:\s+\w+:\([^)]*\))?(?:\s+✗)?(?=\s)/g;
/** A row of box-drawing characters: the edge of a TUI's input box. */
const RULE_LINE = /^\s*[─━═-]{3,}\s*$/;
/** How far above the caret a wrapped input can start. */
const MAX_INPUT_LINES = 40;

const graphemes = new Intl.Segmenter(undefined, { granularity: 'grapheme' });

function graphemeCount(text: string): number {
  let count = 0;
  for (const _ of graphemes.segment(text)) count++;
  return count;
}

export interface TerminalInput {
  /** The input as the user means it: wrapped lines joined back into one. */
  text: string;
  /** Backspaces that clear it, from the caret back to the prompt. */
  erase: number;
}

/** Where the input starts: just after the prompt marker on or above the caret line. */
function inputStart(value: string, caret: number): number {
  let lineEnd = caret;
  for (let i = 0; i < MAX_INPUT_LINES; i++) {
    const lineStart = value.lastIndexOf('\n', lineEnd - 1) + 1;
    const line = value.slice(lineStart, lineEnd);
    if (RULE_LINE.test(line)) return lineEnd + 1;

    let marker = -1;
    for (const pattern of [PROMPT_MARKER, ROBBYRUSSELL_PROMPT]) {
      for (const match of line.matchAll(pattern)) {
        marker = Math.max(marker, match.index + match[0].length);
      }
    }
    if (marker >= 0) {
      // The space after the marker belongs to the prompt.
      return lineStart + marker + (/\s/.test(line[marker] ?? '') ? 1 : 0);
    }
    if (lineStart === 0) break;
    lineEnd = lineStart - 1;
  }
  // No prompt in sight: the caret's own line is the best guess at the input.
  return value.lastIndexOf('\n', caret - 1) + 1;
}

export function terminalInput(value: string, caret: number): TerminalInput | null {
  const start = Math.min(inputStart(value, caret), caret);
  const raw = value.slice(start, caret);
  const text = raw
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .join(' ');
  if (!text) return null;
  return { text, erase: graphemeCount(raw) };
}

export interface TextRange {
  /** UTF-16 offsets, the unit both JavaScript strings and the Accessibility API count in. */
  location: number;
  length: number;
}

/** The line the caret is on, without its surrounding whitespace. Null on a blank line. */
export function paragraphAt(value: string, caret: number): TextRange | null {
  const lineStart = value.lastIndexOf('\n', caret - 1) + 1;
  const newline = value.indexOf('\n', caret);
  const lineEnd = newline === -1 ? value.length : newline;
  const line = value.slice(lineStart, lineEnd);
  const text = line.trim();
  if (!text) return null;
  return { location: lineStart + line.indexOf(text), length: text.length };
}
