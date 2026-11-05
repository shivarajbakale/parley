/**
 * Removes tool calls MiniMax writes as plain text. Now and then it emits
 * `]<]minimax[>[<tool_call>…</tool_call>` in the answer instead of a real
 * tool call, which Mastra passes through as text. Only a possible start of
 * the marker is held back; everything else streams straight on.
 */

const MARKER = ']<]minimax[>[';
const CLOSE = '</tool_call>';

export interface MarkupFilter {
  /** `text` is safe to show; `sawCall` is true when a fake tool call began in this piece. */
  push(text: string): { text: string; sawCall: boolean };
  end(): string;
}

/** Length of the longest suffix of `s` that is a proper prefix of `MARKER`. */
function partialMarker(s: string): number {
  for (let n = Math.min(MARKER.length - 1, s.length); n > 0; n -= 1) {
    if (MARKER.startsWith(s.slice(-n))) return n;
  }
  return 0;
}

export function createMarkupFilter(): MarkupFilter {
  let held = '';
  let inCall = false;
  /** Whitespace right after a removed call is part of it, even when it arrives later. */
  let trimLead = false;

  return {
    push(piece) {
      let rest = held + piece;
      held = '';
      let out = '';
      let sawCall = false;
      while (rest) {
        if (inCall) {
          const close = rest.indexOf(CLOSE);
          if (close === -1) {
            // Keep only enough to spot a close tag split across pieces.
            held = rest.slice(-(CLOSE.length - 1));
            return { text: out, sawCall };
          }
          rest = rest.slice(close + CLOSE.length);
          inCall = false;
          trimLead = true;
          continue;
        }
        if (trimLead) {
          rest = rest.replace(/^\s+/, '');
          if (!rest) break;
          trimLead = false;
        }
        const start = rest.indexOf(MARKER);
        if (start !== -1) {
          out += rest.slice(0, start);
          rest = rest.slice(start + MARKER.length);
          inCall = true;
          sawCall = true;
          continue;
        }
        const partial = partialMarker(rest);
        out += rest.slice(0, rest.length - partial);
        held = rest.slice(rest.length - partial);
        rest = '';
      }
      return { text: out, sawCall };
    },
    end() {
      const rest = inCall ? '' : held;
      held = '';
      return rest;
    },
  };
}
