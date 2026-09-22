import { RewriteError, type Rewriter } from './rewriter';
import type { SelectionReader, SelectionSnapshot } from './selection-reader';
import type { ExplainContent, ExplainTurn, Rect } from './types';

/**
 * The Explain command: read the selection, show the card at once, fill it
 * when the answer arrives. The window itself is behind `view`, so this is
 * all testable without Electron.
 *
 * A second `ask()` while the card is still open is a follow-up: same
 * selection, same thread, the new question appended and answered with the
 * earlier turns as context. `dismiss()` is what starts a fresh thread next
 * time — closing the card and asking again always reads the selection anew.
 *
 * `snapshot` lets the caller hand over a selection it already read — session
 * starts reading it the moment the gesture begins, in parallel with the
 * recording, both to prime Whisper's spelling of what is asked and so this
 * does not pay for a second Accessibility round trip. Omit it to have this
 * module read the selection itself.
 */

/** How long the card's exit animation runs before its window hides. */
export const EXPLAIN_LEAVE_MS = 420;

/** How long "select some text first" stays up. */
export const EMPTY_HIDE_MS = 2000;

export interface ExplainView {
  /** Open the card at the selection (or the pointer, when `anchor` is null). */
  show(anchor: Rect | null, content: ExplainContent): void;
  update(content: ExplainContent): void;
  hide(): void;
}

export interface Explain {
  /** `question` is what the user said; nothing said means a plain explain. */
  ask(question?: string, snapshot?: SelectionSnapshot | null): Promise<void>;
  dismiss(): void;
}

export function createExplain(deps: {
  selection: SelectionReader;
  rewriter: Pick<Rewriter, 'explain'>;
  view: ExplainView;
  emptyHideMs?: number;
}): Explain {
  let generation = 0;
  let emptyTimer: ReturnType<typeof setTimeout> | undefined;
  /** The open thread: the selected text plus every turn asked of it so far. */
  let thread: { text: string; turns: ExplainTurn[] } | null = null;

  function dismiss() {
    generation += 1;
    thread = null;
    if (emptyTimer) clearTimeout(emptyTimer);
    emptyTimer = undefined;
    deps.view.hide();
  }

  return {
    dismiss,

    async ask(question, prefetched) {
      generation += 1;
      const mine = generation;
      if (emptyTimer) clearTimeout(emptyTimer);
      emptyTimer = undefined;

      let text: string;
      if (thread) {
        // A follow-up: the card is already open, on the same selection.
        text = thread.text;
        thread.turns.push({ question, status: 'loading' });
      } else {
        const snapshot = prefetched !== undefined ? prefetched : await deps.selection.read();
        if (mine !== generation) return;
        if (!snapshot) {
          deps.view.show(null, { status: 'empty' });
          emptyTimer = setTimeout(() => {
            if (mine === generation) dismiss();
          }, deps.emptyHideMs ?? EMPTY_HIDE_MS);
          return;
        }
        text = snapshot.text;
        thread = { text, turns: [{ question, status: 'loading' }] };
        deps.view.show(snapshot.anchor, { status: 'thread', turns: [...thread.turns] });
      }
      if (thread.turns.length > 1) deps.view.update({ status: 'thread', turns: [...thread.turns] });

      const turnIndex = thread.turns.length - 1;
      let turn: ExplainTurn;
      try {
        const markdown = await deps.rewriter.explain(
          text,
          thread.turns.map((t) => ({
            question: t.question,
            answer: t.status === 'ready' ? t.markdown : undefined,
          }))
        );
        turn = { question, status: 'ready', markdown };
      } catch (error) {
        turn = {
          question,
          status: 'error',
          message: error instanceof RewriteError ? error.message : 'Something went wrong',
        };
      }
      if (mine !== generation || !thread) return;
      thread.turns[turnIndex] = turn;
      deps.view.update({ status: 'thread', turns: [...thread.turns] });
    },
  };
}
