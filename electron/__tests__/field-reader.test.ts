import { describe, expect, it, vi } from 'vitest';

import { createFieldReader, parseFocusedField, parseFrontWindowBounds } from '../field-reader';

describe('field reader', () => {
  it('parses what the helper prints', () => {
    const stdout = JSON.stringify({
      role: 'AXTextArea',
      subrole: '',
      editable: true,
      valueKnown: true,
      value: 'hello',
      selectedText: 'he',
      secure: false,
      selectionBounds: { x: 10, y: 20, width: 30, height: 16 },
      frontWindowBounds: { x: 0, y: 0, width: 1440, height: 900 },
    });
    expect(parseFocusedField(stdout)).toEqual({
      editable: true,
      valueKnown: true,
      value: 'hello',
      selectedText: 'he',
      secure: false,
      selectionBounds: { x: 10, y: 20, width: 30, height: 16 },
      frontWindowBounds: { x: 0, y: 0, width: 1440, height: 900 },
    });
  });

  it('drops bounds the app cannot vouch for', () => {
    const parse = (selectionBounds: unknown) =>
      parseFocusedField(JSON.stringify({ editable: false, selectionBounds }))?.selectionBounds;
    expect(parse({ x: 0, y: 0, width: 0, height: 0 })).toBeNull();
    expect(parse({ x: 'a', y: 0, width: 4, height: 4 })).toBeNull();
    expect(parse(null)).toBeNull();
  });

  it('treats a helper error, junk output and a missing flag as no field', () => {
    expect(parseFocusedField('{"error":"no_focus"}')).toBeNull();
    expect(parseFocusedField('not json')).toBeNull();
    expect(parseFocusedField('{"value":"x"}')).toBeNull();
    expect(parseFocusedField('null')).toBeNull();
  });

  it('runs the helper with a timeout and an output cap', async () => {
    const run = vi.fn().mockResolvedValue('{"editable":true,"value":"v","selectedText":""}');
    const reader = createFieldReader({ helperPath: '/x/parley-ax', run });
    await expect(reader.read()).resolves.toEqual({
      editable: true,
      valueKnown: false,
      value: 'v',
      selectedText: '',
      secure: false,
      selectionBounds: null,
      frontWindowBounds: null,
    });
    expect(run).toHaveBeenCalledWith('/x/parley-ax', {
      timeout: expect.any(Number),
      maxBuffer: expect.any(Number),
    });
  });

  it('reads the frontmost window\'s bounds even on the no-field path', () => {
    expect(parseFrontWindowBounds(JSON.stringify({ error: 'no_focus' }))).toBeNull();
    expect(
      parseFrontWindowBounds(
        JSON.stringify({ error: 'no_focus', frontWindowBounds: { x: 1, y: 2, width: 3, height: 4 } })
      )
    ).toEqual({ x: 1, y: 2, width: 3, height: 4 });
    expect(parseFrontWindowBounds('not json')).toBeNull();
  });

  it('reports no field when the helper is missing, slow or too chatty', async () => {
    const reader = createFieldReader({
      helperPath: '/x/parley-ax',
      run: vi.fn().mockRejectedValue(new Error('ENOENT')),
    });
    await expect(reader.read()).resolves.toBeNull();
  });
});
