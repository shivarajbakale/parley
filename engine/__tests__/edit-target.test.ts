import { describe, expect, it, vi } from 'vitest';

import { createEditTargets, MAX_EDIT_CHARS } from '../edit-target';
import type { FocusedField } from '../field-reader';
import type { TextRange } from '../terminal-input';

function setup(field: FocusedField | null, copied = '', selected = true) {
  const log: string[] = [];
  const injector = {
    paste: vi.fn(async (text: string) => void log.push(`paste:${text}`)),
    copyAll: vi.fn().mockResolvedValue(copied),
    erase: vi.fn(async (count: number) => void log.push(`erase:${count}`)),
  };
  const select = vi.fn(async (range: TextRange) => {
    log.push(`select:${range.location}+${range.length}`);
    return selected;
  });
  const targets = createEditTargets({ reader: { read: async () => field }, injector, select });
  return { injector, select, targets, log };
}

const field = (patch: Partial<FocusedField> = {}): FocusedField => ({
  editable: true,
  valueKnown: false,
  value: '',
  valueOffset: 0,
  valueLength: (patch.value ?? '').length,
  caret: null,
  bundleId: null,
  selectedText: '',
  secure: false,
  selectionBounds: null,
  frontWindowBounds: null,
  ...patch,
});

const ITERM = 'com.googlecode.iterm2';
const RULE = '─'.repeat(30);
const scrollback = 'a line of earlier output\n'.repeat(1000);

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

  it('refuses a field too large to rewrite whole when it cannot say where the caret is', async () => {
    const { targets } = setup(field({ value: 'x'.repeat(MAX_EDIT_CHARS + 1) }));
    await expect(targets.capture()).rejects.toThrow('Too much text to edit');
  });

  it('edits only the typed input in a terminal, however long the scrollback', async () => {
    const value = `${scrollback}${RULE}\n❯ make this shorter\n${RULE}\n  status line`;
    const caret = value.indexOf('shorter') + 'shorter'.length;
    const { targets, injector } = setup(
      field({ value, valueKnown: true, bundleId: ITERM, caret: { location: caret, length: 0 } })
    );
    await expect(targets.capture()).resolves.toEqual({
      text: 'make this shorter',
      scope: 'terminal',
      erase: 17,
    });
    expect(injector.copyAll).not.toHaveBeenCalled();
  });

  it('finds the terminal caret inside the part of a huge value the helper printed', async () => {
    const value = `old output\n$ git comit -m wip`;
    const offset = 500_000;
    const { targets } = setup(
      field({
        value,
        valueOffset: offset,
        valueLength: offset + value.length + 40_000,
        valueKnown: true,
        bundleId: ITERM,
        caret: { location: offset + value.length, length: 0 },
      })
    );
    await expect(targets.capture()).resolves.toMatchObject({ text: 'git comit -m wip' });
  });

  it('says there is nothing to edit at an empty terminal prompt', async () => {
    const value = `${scrollback}❯ `;
    const { targets } = setup(
      field({ value, valueKnown: true, bundleId: ITERM, caret: { location: value.length, length: 0 } })
    );
    await expect(targets.capture()).rejects.toThrow('Nothing to edit');
  });

  it('still rewrites a terminal selection as a selection', async () => {
    const { targets } = setup(
      field({ value: scrollback, valueKnown: true, bundleId: ITERM, selectedText: 'earlier' })
    );
    await expect(targets.capture()).resolves.toEqual({ text: 'earlier', scope: 'selection' });
  });

  it('edits the paragraph at the caret in a document too long to rewrite whole', async () => {
    const value = `${'filler paragraph.\n'.repeat(1000)}The one I mean.\nAfter it.`;
    const caret = value.indexOf('one I');
    const { targets } = setup(
      field({ value, valueKnown: true, caret: { location: caret, length: 0 } })
    );
    await expect(targets.capture()).resolves.toEqual({
      text: 'The one I mean.',
      scope: 'paragraph',
      range: { location: value.indexOf('The one'), length: 'The one I mean.'.length },
    });
  });

  it('reports the paragraph in whole-value offsets when only part was printed', async () => {
    const value = 'before\nthe paragraph\nafter';
    const offset = 30_000;
    const { targets } = setup(
      field({
        value,
        valueOffset: offset,
        valueLength: 90_000,
        valueKnown: true,
        caret: { location: offset + value.indexOf('para'), length: 0 },
      })
    );
    await expect(targets.capture()).resolves.toMatchObject({
      text: 'the paragraph',
      range: { location: offset + value.indexOf('the paragraph'), length: 13 },
    });
  });

  it('says there is nothing to edit on a blank line of a long document', async () => {
    const value = `${'x'.repeat(MAX_EDIT_CHARS)}\n\nmore`;
    const { targets } = setup(
      field({ value, valueKnown: true, caret: { location: MAX_EDIT_CHARS + 1, length: 0 } })
    );
    await expect(targets.capture()).rejects.toThrow('Nothing to edit');
  });

  it('erases the terminal input before pasting the rewrite after the prompt', async () => {
    const { targets, log } = setup(field());
    await targets.apply({ text: 'make this shorter', scope: 'terminal', erase: 17 }, 'shorter');
    expect(log).toEqual(['erase:17', 'paste:shorter']);
  });

  it('selects the paragraph, then pastes over it', async () => {
    const { targets, log, injector } = setup(field());
    await targets.apply(
      { text: 'The one I mean.', scope: 'paragraph', range: { location: 40, length: 15 } },
      'This one.'
    );
    expect(log).toEqual(['select:40+15', 'paste:This one.']);
    expect(injector.paste).toHaveBeenLastCalledWith('This one.');
  });

  it('pastes nothing when the app would not select the paragraph', async () => {
    const { targets, injector } = setup(field(), '', false);
    await expect(
      targets.apply({ text: 'p', scope: 'paragraph', range: { location: 0, length: 1 } }, 'q')
    ).rejects.toThrow('Could not select the paragraph');
    expect(injector.paste).not.toHaveBeenCalled();
  });

  it('pastes over a selection, and selects everything first for a whole field', async () => {
    const { targets, injector } = setup(field());
    await targets.apply({ text: 'two', scope: 'selection' }, '2');
    expect(injector.paste).toHaveBeenLastCalledWith('2', { selectAll: false });
    await targets.apply({ text: 'one two', scope: 'field' }, '1 2');
    expect(injector.paste).toHaveBeenLastCalledWith('1 2', { selectAll: true });
  });
});
