import type { FieldReader } from './field-reader';
import type { Injector } from './injector';

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

export type EditScope = 'selection' | 'field';

export interface EditTarget {
  text: string;
  scope: EditScope;
}

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
  injector: Pick<Injector, 'paste' | 'copyAll'>;
}): EditTargets {
  function checked(target: EditTarget): EditTarget {
    if (target.text.length > MAX_EDIT_CHARS) throw new EditTargetError('Too much text to edit');
    return target;
  }

  return {
    async capture() {
      const field = await deps.reader.read();
      if (!field?.editable) throw new EditTargetError('No text field focused');

      if (field.selectedText.trim()) return checked({ text: field.selectedText, scope: 'selection' });
      if (field.value.trim()) return checked({ text: field.value, scope: 'field' });

      // Select-all in a field that is known to be empty lands on whatever is
      // around it: the page, the chat log, the scrollback.
      if (field.valueKnown) throw new EditTargetError('Nothing to edit');

      const copied = await deps.injector.copyAll();
      if (!copied.trim()) throw new EditTargetError('Nothing to edit');
      return checked({ text: copied, scope: 'field' });
    },

    async apply(target, text) {
      // A paste replaces the live selection, so only the whole-field case
      // needs to select first.
      await deps.injector.paste(text, { selectAll: target.scope === 'field' });
    },
  };
}
