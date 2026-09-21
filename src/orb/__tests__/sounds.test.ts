import { describe, expect, it } from 'vitest';

import { notesFor } from '../sounds';

describe('sounds', () => {
  it('rises to start and falls to stop, on the same two notes', () => {
    const start = notesFor('start').map((note) => note.hz);
    const stop = notesFor('stop').map((note) => note.hz);
    expect(start[1]).toBeGreaterThan(start[0]);
    expect(stop).toEqual([...start].reverse());
  });

  it('keeps the start sound the quietest and shortest, because the microphone is opening', () => {
    const loudest = (name: Parameters<typeof notesFor>[0]) =>
      Math.max(...notesFor(name).map((note) => note.peak));
    const length = (name: Parameters<typeof notesFor>[0]) =>
      Math.max(...notesFor(name).map((note) => note.at + note.decay));
    expect(loudest('start')).toBeLessThan(loudest('stop'));
    expect(length('start')).toBeLessThan(0.3);
    expect(length('start')).toBeLessThan(length('stop'));
  });
});
