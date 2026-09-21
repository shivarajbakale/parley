import { RewriteError, type Rewriter } from './rewriter';
import type { SelectionReader } from './selection-reader';
import type { ExplainContent, Rect } from './types';

/**
 * The Explain command: read the selection, show the card at once, fill it when
 * the answer arrives. The window itself is behind `view`, so this is all
 * testable without Electron.
 *
 * Each trigger supersedes the last: a slow answer for an old selection must not
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
  trigger(): Promise<void>;
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

  function dismiss() {
    generation += 1;
    if (emptyTimer) clearTimeout(emptyTimer);
    emptyTimer = undefined;
    deps.view.hide();
  }

  return {
    dismiss,

    async trigger() {
      generation += 1;
      const mine = generation;
      if (emptyTimer) clearTimeout(emptyTimer);
      emptyTimer = undefined;

      const snapshot = await deps.selection.read();
      if (mine !== generation) return;

      if (!snapshot) {
        deps.view.show(null, { status: 'empty' });
        emptyTimer = setTimeout(() => {
          if (mine === generation) dismiss();
        }, deps.emptyHideMs ?? EMPTY_HIDE_MS);
        return;
      }

      deps.view.show(snapshot.anchor, { status: 'loading' });
      let content: ExplainContent;
      try {
        content = { status: 'ready', markdown: await deps.rewriter.explain(snapshot.text) };
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
