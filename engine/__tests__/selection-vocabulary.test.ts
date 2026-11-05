import { describe, expect, it } from 'vitest';

import { selectionVocabulary } from '../selection-vocabulary';

describe('selection vocabulary', () => {
  it('lists the distinct words in the selection, in order', () => {
    expect(selectionVocabulary('useMemo caches a value, and useMemo is lazy')).toBe(
      'useMemo, caches, value, and, is, lazy'
    );
  });

  it('drops single-character noise and keeps hyphens and apostrophes inside a word', () => {
    expect(selectionVocabulary("a mini-max isn't x")).toBe("mini-max, isn't");
  });

  it('is empty for empty text, and caps a very long selection', () => {
    expect(selectionVocabulary('')).toBe('');
    const long = Array.from({ length: 80 }, (_, i) => `word${i}`).join(' ');
    const result = selectionVocabulary(long);
    expect(result.split(', ').length).toBeLessThanOrEqual(40);
    expect(result.length).toBeLessThanOrEqual(300);
  });
});
