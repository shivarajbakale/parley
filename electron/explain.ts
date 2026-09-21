import { RewriteError, type Rewriter } from './rewriter';
import type { SelectionSnapshot } from './selection-reader';
import type { ExplainContent, Rect } from './types';

/**
 * The Explain command: given the selection and what the user asked about it,
 * show the card at once and fill it when the answer arrives. The window itself is behind `view`, so this is all
 * testable without Electron.
 *
 * Each answer supersedes the last: a slow answer for an old selection must not
 * land in the card for a new one.
 */

/** How long "select some text first" stays up. */
export const EMPTY_HIDE_MS = 2000;

export interface ExplainView {
  /** Open the card at the selection (or the pointer, when `anchor` is null). */
  show(anchor: Rect | null, content: ExplainContent): void;
  update(content: ExplainContent): void;
  hide(): void;
}

export interface Explain {
  /** `snapshot` is `null` when nothing was selected; `question` is what the user said. */
  answer(snapshot: SelectionSnapshot | null, question?: string): Promise<void>;
  dismiss(): void;
}

export function createExplain(deps: {
  rewriter: Pick<Rewriter, 'explain'>;
  view: ExplainView;
  emptyHideMs?: number;
}): Explain {
  let generation = 0;
  let emptyTimer: ReturnType<typeof setTimeout> | undefined;

  function dismiss() {
    generation += 1;
    if (emptyTimer) clearTimeout(emptyTimer);
    emptyTimer = undefined;
    deps.view.hide();
  }

  return {
    dismiss,

    async answer(snapshot, question) {
      generation += 1;
      const mine = generation;
      if (emptyTimer) clearTimeout(emptyTimer);
      emptyTimer = undefined;

      if (!snapshot) {
        deps.view.show(null, { status: 'empty' });
        emptyTimer = setTimeout(() => {
          if (mine === generation) dismiss();
        }, deps.emptyHideMs ?? EMPTY_HIDE_MS);
        return;
      }

      deps.view.show(snapshot.anchor, { status: 'loading', question });
      let content: ExplainContent;
      try {
        content = { status: 'ready', markdown: await deps.rewriter.explain(snapshot.text, question), question };
      } catch (error) {
        content = {
          status: 'error',
          message: error instanceof RewriteError ? error.message : 'Something went wrong',
        };
      }
      if (mine === generation) deps.view.update(content);
    },
  };
}
