import type { FieldReader, FocusedField } from './field-reader';
import type { Injector } from './injector';
import { isTerminal, paragraphAt, terminalInput, type TextRange } from './terminal-input';

/**
 * What a voice edit acts on: the selection if there is one, otherwise the
 * whole focused field. The user does not have to select or copy anything.
 *
 * The Accessibility read comes first because it is invisible. Keystrokes are
 * the fallback for apps that confirm a text field but hide its value, and they
 * are only ever sent once the focus is known to be a text field.
 */

/** Past this a "field" is a document or a terminal scrollback, not something to rewrite whole. */
export const MAX_EDIT_CHARS = 8000;

export type EditTarget =
  | { text: string; scope: 'selection' | 'field' }
  /** Typed input in a terminal, cleared with `erase` backspaces before the paste. */
  | { text: string; scope: 'terminal'; erase: number }
  /** One paragraph of a long document, selected by `range` before the paste. */
  | { text: string; scope: 'paragraph'; range: TextRange };

export type EditScope = EditTarget['scope'];

export class EditTargetError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'EditTargetError';
  }
}

export interface EditTargets {
  capture(): Promise<EditTarget>;
  apply(target: EditTarget, text: string): Promise<void>;
}

export function createEditTargets(deps: {
  reader: FieldReader;
  injector: Pick<Injector, 'paste' | 'copyAll' | 'erase'>;
  /** Moves the focused field's selection; false when the app would not. */
  select: (range: TextRange) => Promise<boolean>;
}): EditTargets {
  function checked<T extends EditTarget>(target: T): T {
    if (target.text.length > MAX_EDIT_CHARS) throw new EditTargetError('Too much text to edit');
    return target;
  }

  /** The caret's index into the printed part of the value, if it falls inside it. */
  function caretIn(field: FocusedField): number | null {
    if (!field.caret) return null;
    const index = field.caret.location + field.caret.length - field.valueOffset;
    return index >= 0 && index <= field.value.length ? index : null;
  }

  function terminal(field: FocusedField): EditTarget {
    const caret = caretIn(field);
    const input = caret === null ? null : terminalInput(field.value, caret);
    if (!input) throw new EditTargetError('Nothing to edit');
    return checked({ text: input.text, scope: 'terminal', erase: input.erase });
  }

  function paragraph(field: FocusedField): EditTarget {
    const caret = field.caret ? field.caret.location - field.valueOffset : -1;
    if (!field.caret || caret < 0 || caret > field.value.length) {
      throw new EditTargetError('Too much text to edit');
    }
    const range = paragraphAt(field.value, caret);
    if (!range) throw new EditTargetError('Nothing to edit');
    const text = field.value.slice(range.location, range.location + range.length);
    return checked({
      text,
      scope: 'paragraph',
      range: { location: range.location + field.valueOffset, length: range.length },
    });
  }

  return {
    async capture() {
      const field = await deps.reader.read();
      if (!field?.editable) throw new EditTargetError('No text field focused');

      if (field.selectedText.trim()) return checked({ text: field.selectedText, scope: 'selection' });
      // Select-all and paste would rewrite the scrollback into the prompt.
      if (isTerminal(field.bundleId) && field.valueKnown) return terminal(field);
      if (field.valueLength > MAX_EDIT_CHARS) return paragraph(field);
      if (field.value.trim()) return checked({ text: field.value, scope: 'field' });

      // Select-all in a field that is known to be empty lands on whatever is
      // around it: the page, the chat log, the scrollback.
      if (field.valueKnown) throw new EditTargetError('Nothing to edit');

      const copied = await deps.injector.copyAll();
      if (!copied.trim()) throw new EditTargetError('Nothing to edit');
      return checked({ text: copied, scope: 'field' });
    },

    async apply(target, text) {
      if (target.scope === 'terminal') {
        await deps.injector.erase(target.erase);
        await deps.injector.paste(text);
        return;
      }
      if (target.scope === 'paragraph') {
        // Selected now, not at capture: the paragraph stays unhighlighted while
        // the rewrite is in flight.
        if (!(await deps.select(target.range))) {
          throw new EditTargetError('Could not select the paragraph');
        }
        await deps.injector.paste(text);
        return;
      }
      // A paste replaces the live selection, so only the whole-field case
      // needs to select first.
      await deps.injector.paste(text, { selectAll: target.scope === 'field' });
    },
  };
}
