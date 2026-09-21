import { describe, expect, it } from 'vitest';

import { detectCorrection, soundsAlike } from '../correction-detect';

const COMMON = new Set(
  'i test tested today tomorrow there their the a male mail monday max mini parlay shorter short it is was with and for meeting sent to email on at we use'.split(
    ' '
  )
);
const isCommonWord = (word: string) => COMMON.has(word);
const detect = (pasted: string, field: string) => detectCorrection(pasted, field, { isCommonWord });

describe('detectCorrection', () => {
  it('finds a name fixed in place', () => {
    expect(detect('I tested mini max today', 'I tested MiniMax today')).toEqual({
      heard: 'mini max',
      word: 'MiniMax',
    });
  });

  it('finds the dictation inside a longer field, whatever the line breaks', () => {
    const field = 'Hi team,\n\nI tested MiniMax\ntoday and it was fast.\n\nThanks';
    expect(detect('I tested mini max today', field)).toEqual({ heard: 'mini max', word: 'MiniMax' });
  });

  it('keeps punctuation out of the learned word', () => {
    expect(detect('It was sent to shivraj, today', 'It was sent to Shivaraj, today')).toEqual({
      heard: 'shivraj',
      word: 'Shivaraj',
    });
  });

  it('handles a fix at the start and at the end', () => {
    expect(detect('shivraj was there today', 'Shivaraj was there today')?.word).toBe('Shivaraj');
    expect(detect('the meeting is with shivraj', 'the meeting is with Shivaraj')?.word).toBe(
      'Shivaraj'
    );
  });

  it('learns lowercase jargon that is not an ordinary word', () => {
    expect(detect('we use cube cuddle for it', 'we use kubectl for it')).toEqual({
      heard: 'cube cuddle',
      word: 'kubectl',
    });
  });

  it('learns a proper noun even when its lowercase is a word', () => {
    expect(detect('I tested parlay today', 'I tested Parley today')).toEqual({
      heard: 'parlay',
      word: 'Parley',
    });
  });

  it('sees nothing while the text is untouched', () => {
    expect(detect('I tested mini max today', 'I tested mini max today')).toBeNull();
    expect(detect('I tested mini max today', 'Before. I tested mini max today and more')).toBeNull();
  });

  it('ignores a change of meaning', () => {
    expect(detect('the meeting is today with max', 'the meeting is tomorrow with max')).toBeNull();
  });

  it('ignores one ordinary word swapped for another', () => {
    expect(detect('it was there today', 'it was their today')).toBeNull();
    expect(detect('the male was sent', 'the mail was sent')).toBeNull();
  });

  it('ignores a capital added to an ordinary word', () => {
    expect(detect('the meeting is on monday', 'the meeting is on Monday')).toBeNull();
    expect(detect('it is shorter today', 'It is shorter today')).toBeNull();
  });

  it('ignores an inflection of an ordinary word', () => {
    expect(detect('I tested it today', 'I testing it today')).toBeNull();
  });

  it('ignores a rewrite: two changes, or one big one', () => {
    expect(detect('I tested mini max today', 'I tried MiniMax yesterday')).toBeNull();
    expect(
      detect('I tested mini max today', 'I tested the MiniMax model family at length today')
    ).toBeNull();
  });

  it('ignores a deletion and an insertion', () => {
    expect(detect('I tested mini max today', 'I tested today')).toBeNull();
    expect(detect('I tested it today', 'I tested it Shivaraj today')).toBeNull();
  });

  it('needs context around the change to know where it is', () => {
    expect(detect('shivraj', 'Shivaraj')).toBeNull();
    expect(detect('hi shivraj', 'hi Shivaraj')).toBeNull();
  });

  it('gives up when the dictation is gone from the field', () => {
    expect(detect('I tested mini max today', 'Something else entirely')).toBeNull();
    expect(detect('I tested mini max today', '')).toBeNull();
  });
});

describe('soundsAlike', () => {
  it('passes respellings and fails different words', () => {
    expect(soundsAlike('mini max', 'MiniMax')).toBe(true);
    expect(soundsAlike('shivraj', 'Shivaraj')).toBe(true);
    expect(soundsAlike('cube cuddle', 'kubectl')).toBe(true);
    expect(soundsAlike('today', 'tomorrow')).toBe(false);
    expect(soundsAlike('she drives', 'Shivaraj')).toBe(false);
  });
});
