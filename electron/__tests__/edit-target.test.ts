import { describe, expect, it, vi } from 'vitest';

import { createEditTargets, MAX_EDIT_CHARS } from '../edit-target';
import type { FocusedField } from '../field-reader';

function setup(field: FocusedField | null, copied = '') {
  const injector = {
    paste: vi.fn().mockResolvedValue(undefined),
    copyAll: vi.fn().mockResolvedValue(copied),
  };
  const targets = createEditTargets({ reader: { read: async () => field }, injector });
  return { injector, targets };
}

const field = (patch: Partial<FocusedField> = {}): FocusedField => ({
  editable: true,
  valueKnown: false,
  value: '',
  selectedText: '',
  ...patch,
});

describe('edit targets', () => {
  it('prefers the selection over the whole field', async () => {
    const { targets, injector } = setup(field({ value: 'one two three', selectedText: 'two' }));
    await expect(targets.capture()).resolves.toEqual({ text: 'two', scope: 'selection' });
    expect(injector.copyAll).not.toHaveBeenCalled();
  });

  it('takes the whole field when nothing is selected, without touching the keyboard', async () => {
    const { targets, injector } = setup(field({ value: 'one two three' }));
    await expect(targets.capture()).resolves.toEqual({ text: 'one two three', scope: 'field' });
    expect(injector.copyAll).not.toHaveBeenCalled();
  });

  it('falls back to select-all and copy when a text field hides its value', async () => {
    const { targets } = setup(field(), 'from the clipboard');
    await expect(targets.capture()).resolves.toEqual({
      text: 'from the clipboard',
      scope: 'field',
    });
  });

  it('never sends a keystroke unless the focus is a text field', async () => {
    for (const focused of [null, field({ editable: false, value: 'a web page' })]) {
      const { targets, injector } = setup(focused, 'would be the whole page');
      await expect(targets.capture()).rejects.toThrow('No text field focused');
      expect(injector.copyAll).not.toHaveBeenCalled();
    }
  });

  it('never selects all in a field the app says is empty', async () => {
    const { targets, injector } = setup(field({ valueKnown: true }), 'the page around it');
    await expect(targets.capture()).rejects.toThrow('Nothing to edit');
    expect(injector.copyAll).not.toHaveBeenCalled();
  });

  it('refuses an empty field', async () => {
    const { targets } = setup(field(), '  ');
    await expect(targets.capture()).rejects.toThrow('Nothing to edit');
  });

  it('refuses a field too large to rewrite whole', async () => {
    const { targets } = setup(field({ value: 'x'.repeat(MAX_EDIT_CHARS + 1) }));
    await expect(targets.capture()).rejects.toThrow('Too much text to edit');
  });

  it('pastes over a selection, and selects everything first for a whole field', async () => {
    const { targets, injector } = setup(field());
    await targets.apply({ text: 'two', scope: 'selection' }, '2');
    expect(injector.paste).toHaveBeenLastCalledWith('2', { selectAll: false });
    await targets.apply({ text: 'one two', scope: 'field' }, '1 2');
    expect(injector.paste).toHaveBeenLastCalledWith('1 2', { selectAll: true });
  });
});
