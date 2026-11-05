import type { ExplainClient, ExplainStreamEvent } from './explain-client';
import type { SelectionReader, SelectionSnapshot } from './selection-reader';
import type { ExplainContent, ExplainSource, ExplainTurn, Rect } from './types';

/**
 * The Explain command: read the selection, show the card at once, then grow
 * the answer as parley-api streams it. The window itself is behind `view`,
 * so this is all testable without Electron.
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

/** How often a streaming answer repaints: about two frames, well under reading speed. */
export const STREAM_UPDATE_MS = 32;

/**
 * Wraps `view.update` so a streaming answer repaints at most once per
 * `intervalMs`, always with the latest text. A state with nothing streaming
 * (an answer finished, an error) goes out at once and drops anything pending,
 * so the last paint is never a stale partial one.
 */
export function createUpdateThrottle(
  update: (content: ExplainContent) => void,
  intervalMs: number
): (content: ExplainContent) => void {
  let timer: ReturnType<typeof setTimeout> | undefined;
  let pending: ExplainContent | undefined;

  return (content) => {
    const streaming = content.status === 'thread' && content.turns.some((t) => t.status === 'streaming');
    if (!streaming) {
      if (timer) clearTimeout(timer);
      timer = undefined;
      pending = undefined;
      update(content);
      return;
    }
    if (timer) {
      pending = content;
      return;
    }
    update(content);
    timer = setTimeout(function flush() {
      timer = undefined;
      if (!pending) return;
      const next = pending;
      pending = undefined;
      update(next);
      timer = setTimeout(flush, intervalMs);
    }, intervalMs);
  };
}

/** A turn cut short by a newer question keeps what had arrived. */
function interrupted(turn: ExplainTurn): ExplainTurn {
  if (turn.status === 'streaming') return { question: turn.question, status: 'ready', markdown: turn.markdown };
  if (turn.status === 'loading') return { question: turn.question, status: 'error', message: 'Stopped' };
  return turn;
}

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
  client: Pick<ExplainClient, 'stream'>;
  view: ExplainView;
  emptyHideMs?: number;
}): Explain {
  let generation = 0;
  let emptyTimer: ReturnType<typeof setTimeout> | undefined;
  /** The open thread: the selected text plus every turn asked of it so far. */
  let thread: { text: string; turns: ExplainTurn[] } | null = null;
  /** The request in flight; aborting it stops the model run on the server. */
  let current: AbortController | null = null;

  function stopCurrent() {
    current?.abort();
    current = null;
  }

  function dismiss() {
    generation += 1;
    stopCurrent();
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
      stopCurrent();
      if (emptyTimer) clearTimeout(emptyTimer);
      emptyTimer = undefined;

      let text: string;
      if (thread) {
        // A follow-up: the card is already open, on the same selection. An
        // answer still streaming stops where it is.
        text = thread.text;
        thread.turns = thread.turns.map(interrupted);
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
      const history = thread.turns.map((t) => ({
        question: t.question,
        answer: t.status === 'ready' ? t.markdown : undefined,
      }));
      const controller = new AbortController();
      current = controller;

      let markdown = '';
      let searching: string | undefined;
      let sources: ExplainSource[] = [];
      const setTurn = (turn: ExplainTurn) => {
        if (mine !== generation || !thread) return;
        thread.turns[turnIndex] = turn;
        deps.view.update({ status: 'thread', turns: [...thread.turns] });
      };
      const onEvent = (event: ExplainStreamEvent) => {
        switch (event.type) {
          case 'delta':
            markdown += event.text;
            searching = undefined;
            setTurn({ question, status: 'streaming', markdown });
            break;
          case 'reset':
            // What came before a search was the model talking about searching.
            markdown = '';
            setTurn({ question, status: 'loading', ...(searching ? { searching } : {}) });
            break;
          case 'search':
            searching = event.query;
            setTurn(
              markdown
                ? { question, status: 'streaming', markdown, searching }
                : { question, status: 'loading', searching }
            );
            break;
          case 'sources':
            sources = event.sources;
            break;
          case 'done':
            setTurn({ question, status: 'ready', markdown, ...(sources.length ? { sources } : {}) });
            break;
          case 'error':
            setTurn({ question, status: 'error', message: event.message, ...(markdown ? { markdown } : {}) });
            break;
        }
      };

      try {
        await deps.client.stream(text, history, onEvent, controller.signal);
      } catch {
        setTurn({ question, status: 'error', message: 'Something went wrong', ...(markdown ? { markdown } : {}) });
      } finally {
        if (current === controller) current = null;
      }
    },
  };
}
