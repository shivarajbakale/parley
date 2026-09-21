import { describe, expect, it } from 'vitest';

import {
  applyReplacements,
  MAX_PROMPT_CHARS,
  splitVocabulary,
  whisperPrompt,
  type DictionaryEntry,
} from '../dictionary';

function entry(word: string, soundsLike: string[] = [], rest: Partial<DictionaryEntry> = {}) {
  return { id: word, word, soundsLike, uses: 0, lastUsedAt: 0, ...rest };
}

describe('whisperPrompt', () => {
  it('is empty with nothing to say', () => {
    expect(whisperPrompt([])).toBe('');
  });

  it('is a sentence, because Whisper copies the style of its prompt', () => {
    expect(whisperPrompt([entry('MiniMax')])).toBe('Notes about MiniMax.');
    expect(whisperPrompt([entry('MiniMax'), entry('Parley')])).toBe(
      'Notes about MiniMax and Parley.'
    );
    expect(whisperPrompt([entry('A1'), entry('B2'), entry('C3')])).toBe(
      'Notes about A1, B2 and C3.'
    );
  });

  it('never sends what a word sounds like, only how it is spelled', () => {
    expect(whisperPrompt([entry('MiniMax', ['mini max'])])).not.toContain('mini max');
  });

  it('ranks the most recently used first, then the most used', () => {
    const prompt = whisperPrompt([
      entry('Old', [], { lastUsedAt: 1, uses: 90 }),
      entry('Busy', [], { lastUsedAt: 5, uses: 9 }),
      entry('Quiet', [], { lastUsedAt: 5, uses: 1 }),
    ]);
    expect(prompt).toBe('Notes about Busy, Quiet and Old.');
  });

  it('puts session words ahead of stored ones and drops repeats', () => {
    const prompt = whisperPrompt([entry('Parley'), entry('Groq')], ['Priyanka', 'parley']);
    expect(prompt).toBe('Notes about Priyanka, Parley and Groq.');
  });

  it('stays inside the part of a prompt Whisper reads', () => {
    const many = Array.from({ length: 400 }, (_, i) => entry(`Word${i}`, [], { lastUsedAt: 400 - i }));
    const prompt = whisperPrompt(many);
    expect(prompt.length).toBeLessThanOrEqual(MAX_PROMPT_CHARS);
    expect(prompt).toContain('Word0');
    expect(prompt).not.toContain('Word399');
    expect(prompt.endsWith('.')).toBe(true);
  });
});

describe('applyReplacements', () => {
  const entries = [entry('MiniMax', ['mini max', 'minmax']), entry('kubectl', ['cube control'])];

  it('rewrites what Whisper heard into what the user spells', () => {
    expect(applyReplacements('I tested mini max today', entries)).toEqual({
      text: 'I tested MiniMax today',
      hits: ['MiniMax'],
    });
  });

  it('ignores case and the width of the gap', () => {
    expect(applyReplacements('Mini  Max and Cube Control', entries).text).toBe(
      'MiniMax and kubectl'
    );
  });

  it('enforces the casing of the word itself', () => {
    expect(applyReplacements('minimax is fast', entries)).toEqual({
      text: 'MiniMax is fast',
      hits: ['MiniMax'],
    });
  });

  it('counts a word Whisper already got right as a use', () => {
    expect(applyReplacements('MiniMax is fast', entries).hits).toEqual(['MiniMax']);
  });

  it('never reaches inside another word', () => {
    const text = 'minmaxing the minimaxes';
    expect(applyReplacements(text, entries)).toEqual({ text, hits: [] });
  });

  it('keeps the punctuation around a match', () => {
    expect(applyReplacements('Is it mini max? (minmax!)', entries).text).toBe(
      'Is it MiniMax? (MiniMax!)'
    );
  });

  it('prefers the longest phrase when two could match', () => {
    const overlapping = [entry('Max', ['max']), entry('MiniMax', ['mini max'])];
    expect(applyReplacements('mini max', overlapping).text).toBe('MiniMax');
  });

  it('treats regex characters in a word as text', () => {
    const odd = [entry('C++', ['c plus plus']), entry('node.js', ['node js'])];
    expect(applyReplacements('c plus plus and node js, not nodexjs', odd).text).toBe(
      'C++ and node.js, not nodexjs'
    );
  });

  it('reports each hit entry once', () => {
    expect(applyReplacements('minmax minmax mini max', entries).hits).toEqual(['MiniMax']);
  });

  it('leaves text alone with an empty dictionary', () => {
    expect(applyReplacements('hello', [])).toEqual({ text: 'hello', hits: [] });
  });
});

describe('splitVocabulary', () => {
  it('reads the old comma or newline separated setting', () => {
    expect(splitVocabulary(' Groq, MiniMax\nParley ,, ')).toEqual(['Groq', 'MiniMax', 'Parley']);
    expect(splitVocabulary('')).toEqual([]);
  });
});
