import { describe, expect, it, vi } from 'vitest';

import { createFieldReader, parseFocusedField } from '../field-reader';

describe('field reader', () => {
  it('parses what the helper prints', () => {
    const stdout = JSON.stringify({
      role: 'AXTextArea',
      subrole: '',
      editable: true,
      valueKnown: true,
      value: 'hello',
      selectedText: 'he',
    });
    expect(parseFocusedField(stdout)).toEqual({
      editable: true,
      valueKnown: true,
      value: 'hello',
      selectedText: 'he',
    });
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
    });
    expect(run).toHaveBeenCalledWith('/x/parley-ax', {
      timeout: expect.any(Number),
      maxBuffer: expect.any(Number),
    });
  });

  it('reports no field when the helper is missing, slow or too chatty', async () => {
    const reader = createFieldReader({
      helperPath: '/x/parley-ax',
      run: vi.fn().mockRejectedValue(new Error('ENOENT')),
    });
    await expect(reader.read()).resolves.toBeNull();
  });
});
