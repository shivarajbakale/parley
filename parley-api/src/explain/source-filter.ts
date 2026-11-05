/**
 * Drops "Source:" lines from streamed markdown. The model is told not to
 * write them, because real links are sent separately from the search
 * results, but it sometimes cites a page it never searched. A line is held
 * back only while it could still turn into one; anything else passes
 * straight through so the stream stays live.
 */

const SOURCE_LINE = /^\s*[*_]*sources?[*_]*\s*:/i;
const SOURCE_PREFIX = /^\s*[*_]*(s(o(u(r(c(e(s?[*_]*\s*)?)?)?)?)?)?)?$/i;

type Kind = 'source' | 'pending' | 'text';

function classify(line: string): Kind {
  if (SOURCE_LINE.test(line)) return 'source';
  return SOURCE_PREFIX.test(line) ? 'pending' : 'text';
}

export interface SourceLineFilter {
  /** Text that is safe to show now. */
  push(text: string): string;
  /** Whatever was held back, once the stream is over. */
  end(): string;
}

export function createSourceLineFilter(): SourceLineFilter {
  let mode: 'start' | 'text' | 'drop' = 'start';
  let held = '';

  return {
    push(text) {
      let out = '';
      for (const ch of text) {
        if (mode === 'text') {
          out += ch;
          if (ch === '\n') mode = 'start';
        } else if (mode === 'drop') {
          if (ch === '\n') mode = 'start';
        } else {
          held += ch;
          if (ch === '\n') {
            out += held;
            held = '';
            continue;
          }
          const kind = classify(held);
          if (kind === 'source') {
            held = '';
            mode = 'drop';
          } else if (kind === 'text') {
            out += held;
            held = '';
            mode = 'text';
          }
        }
      }
      return out;
    },
    end() {
      const rest = mode === 'start' && classify(held) !== 'source' ? held : '';
      held = '';
      return rest;
    },
  };
}
