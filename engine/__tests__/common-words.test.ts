import { describe, expect, it, vi } from 'vitest';

import { createCommonWords } from '../common-words';

describe('common words', () => {
  it('answers from the list, ignoring its casing, and reads it once', () => {
    const read = vi.fn().mockReturnValue('Today\ntest\n');
    const isCommonWord = createCommonWords({ read });
    expect(isCommonWord('today')).toBe(true);
    expect(isCommonWord('kubectl')).toBe(false);
    expect(read).toHaveBeenCalledTimes(1);
  });

  it('does not read the list until asked', () => {
    const read = vi.fn().mockReturnValue('');
    createCommonWords({ read });
    expect(read).not.toHaveBeenCalled();
  });

  it('without the list, treats plain lowercase as ordinary', () => {
    const isCommonWord = createCommonWords({
      read: () => {
        throw new Error('ENOENT');
      },
    });
    expect(isCommonWord('kubectl')).toBe(true);
    expect(isCommonWord('k8s')).toBe(false);
  });
});
