import { describe, expect, it } from 'vitest';

import { MAX_AUDIO_BYTES, parseOrbAudio } from '../orb-audio';

describe('parseOrbAudio', () => {
  it('accepts an ArrayBuffer and pins the mime type to the constant', () => {
    const data = new Uint8Array([1, 2, 3]).buffer;
    const parsed = parseOrbAudio({ data, durationMs: 1200, mimeType: 'text/html' });

    expect(parsed).toEqual({ data, mimeType: 'audio/webm', durationMs: 1200 });
  });

  it('copies a typed-array view into a fresh ArrayBuffer, honouring the offset', () => {
    const backing = new Uint8Array([9, 9, 1, 2, 3, 9]);
    const view = backing.subarray(2, 5);

    const parsed = parseOrbAudio({ data: view, durationMs: 50 });

    expect(parsed).not.toBeNull();
    expect(parsed!.data).toBeInstanceOf(ArrayBuffer);
    expect(parsed!.data.byteLength).toBe(3);
    expect([...new Uint8Array(parsed!.data)]).toEqual([1, 2, 3]);
    // A copy, not a window onto the sender's buffer.
    expect(parsed!.data).not.toBe(backing.buffer);
  });

  it('accepts a DataView too', () => {
    const parsed = parseOrbAudio({
      data: new DataView(new Uint8Array([7, 8]).buffer),
      durationMs: 10,
    });
    expect([...new Uint8Array(parsed!.data)]).toEqual([7, 8]);
  });

  it('treats an empty buffer as a zero-duration recording', () => {
    const parsed = parseOrbAudio({ data: new ArrayBuffer(0), durationMs: 4000 });
    expect(parsed).toEqual({ data: expect.any(ArrayBuffer), mimeType: 'audio/webm', durationMs: 0 });
    expect(parsed!.data.byteLength).toBe(0);
  });

  it('rejects a payload that is not audio at all', () => {
    expect(parseOrbAudio(null)).toBeNull();
    expect(parseOrbAudio(undefined)).toBeNull();
    expect(parseOrbAudio('audio')).toBeNull();
    expect(parseOrbAudio({ durationMs: 10 })).toBeNull();
    expect(parseOrbAudio({ data: 'nope', durationMs: 10 })).toBeNull();
  });

  it.each([
    ['not a number', 'x'],
    ['NaN', Number.NaN],
    ['Infinity', Number.POSITIVE_INFINITY],
    ['negative', -1],
    ['missing', undefined],
  ])('rejects a %s duration', (_label, durationMs) => {
    expect(parseOrbAudio({ data: new ArrayBuffer(4), durationMs })).toBeNull();
  });

  it('rejects a buffer larger than the cap and accepts one at the cap', () => {
    expect(parseOrbAudio({ data: new ArrayBuffer(MAX_AUDIO_BYTES + 1), durationMs: 1 })).toBeNull();
    expect(parseOrbAudio({ data: new ArrayBuffer(MAX_AUDIO_BYTES), durationMs: 1 })).not.toBeNull();
  });

  it('caps at 25 MB', () => {
    expect(MAX_AUDIO_BYTES).toBe(25 * 1024 * 1024);
  });
});
