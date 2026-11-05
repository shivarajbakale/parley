import { describe, expect, it, vi } from 'vitest';

import type { FocusedField } from '../field-reader';
import { createSelectionReader, MAX_EXPLAIN_CHARS } from '../selection-reader';

const field = (patch: Partial<FocusedField> = {}): FocusedField => ({
  editable: false,
  valueKnown: false,
  value: '',
  selectedText: '',
  secure: false,
  selectionBounds: null,
    frontWindowBounds: null,
    valueOffset: 0,
    valueLength: 0,
    caret: null,
    bundleId: null,
  ...patch,
});

function setup(read: FocusedField | null, copied = '') {
  const injector = { copySelection: vi.fn().mockResolvedValue(copied) };
  const reader = createSelectionReader({ reader: { read: async () => read }, injector });
  return { reader, injector };
}

describe('selection reader', () => {
  it('uses the Accessibility selection and its rectangle without touching the clipboard', async () => {
    const bounds = { x: 5, y: 6, width: 70, height: 16 };
    const { reader, injector } = setup(
      field({ selectedText: ' idempotent ', selectionBounds: bounds })
    );
    await expect(reader.read()).resolves.toEqual({ text: 'idempotent', anchor: bounds });
    expect(injector.copySelection).not.toHaveBeenCalled();
  });

  it('reads a selection in a field the user cannot edit', async () => {
    const { reader } = setup(field({ editable: false, selectedText: 'read-only' }));
    await expect(reader.read()).resolves.toMatchObject({ text: 'read-only' });
  });

  it('falls back to a copy, anchored at the pointer, when the app hides its selection', async () => {
    const { reader, injector } = setup(field(), 'copied words');
    await expect(reader.read()).resolves.toEqual({ text: 'copied words', anchor: null });
    expect(injector.copySelection).toHaveBeenCalledOnce();
  });

  it('falls back to a copy when the helper could not answer at all', async () => {
    const { reader } = setup(null, 'copied words');
    await expect(reader.read()).resolves.toEqual({ text: 'copied words', anchor: null });
  });

  it('never reads a password field, by either route', async () => {
    const { reader, injector } = setup(field({ secure: true }), 'hunter2');
    await expect(reader.read()).resolves.toBeNull();
    expect(injector.copySelection).not.toHaveBeenCalled();
  });

  it('returns nothing when nothing is selected', async () => {
    const { reader } = setup(field(), '   ');
    await expect(reader.read()).resolves.toBeNull();
  });

  it('caps what is sent for explaining', async () => {
    const { reader } = setup(field({ selectedText: 'a'.repeat(MAX_EXPLAIN_CHARS + 50) }));
    expect((await reader.read())?.text).toHaveLength(MAX_EXPLAIN_CHARS);
  });
});
