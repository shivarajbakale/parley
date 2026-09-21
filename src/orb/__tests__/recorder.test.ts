import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { createRecorder } from '../recorder';

/** A MediaStreamTrack fake that just records whether it was stopped. */
function fakeTrack() {
  return { stop: vi.fn() };
}

function fakeStream(tracks: ReturnType<typeof fakeTrack>[]) {
  return { getTracks: () => tracks } as unknown as MediaStream;
}

class FakeAnalyser {
  fftSize = 0;
  getByteTimeDomainData() {}
}

class FakeAudioContext {
  close = vi.fn().mockResolvedValue(undefined);
  createAnalyser() {
    return new FakeAnalyser() as unknown as AnalyserNode;
  }
  createMediaStreamSource() {
    return { connect: vi.fn() };
  }
}

class FakeMediaRecorder {
  state: 'inactive' | 'recording' = 'recording';
  ondataavailable: ((event: { data: Blob }) => void) | null = null;
  onstop: (() => void) | null = null;
  start = vi.fn();
  stop = vi.fn(() => {
    this.state = 'inactive';
    this.onstop?.();
  });
}

describe('createRecorder race safety (finding 1)', () => {
  let getUserMedia: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    getUserMedia = vi.fn();
    vi.stubGlobal('navigator', { mediaDevices: { getUserMedia } });
    vi.stubGlobal('AudioContext', FakeAudioContext);
    vi.stubGlobal('MediaRecorder', FakeMediaRecorder);
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('releases the stream if discard() runs before getUserMedia resolves', async () => {
    let resolveStream: (stream: MediaStream) => void = () => {};
    getUserMedia.mockReturnValue(
      new Promise((resolve) => {
        resolveStream = resolve;
      })
    );

    const recorder = createRecorder();
    const startPromise = recorder.start();

    // Superseded while getUserMedia is still pending.
    recorder.discard();

    const tracks = [fakeTrack(), fakeTrack()];
    resolveStream(fakeStream(tracks));
    await startPromise;

    expect(tracks.every((track) => track.stop.mock.calls.length === 1)).toBe(true);
    // No MediaRecorder was ever set up on the superseded stream, so the
    // level meter stays inert.
    expect(recorder.level()).toBe(0);
  });

  it('releases the stream if stop() runs before getUserMedia resolves', async () => {
    let resolveStream: (stream: MediaStream) => void = () => {};
    getUserMedia.mockReturnValue(
      new Promise((resolve) => {
        resolveStream = resolve;
      })
    );

    const recorder = createRecorder();
    const startPromise = recorder.start();

    const stopResult = recorder.stop();

    const tracks = [fakeTrack()];
    resolveStream(fakeStream(tracks));
    await startPromise;

    expect(await stopResult).toBeNull();
    expect(tracks[0].stop).toHaveBeenCalledTimes(1);
  });

  it('a normal start still records when nothing supersedes it', async () => {
    getUserMedia.mockResolvedValue(fakeStream([fakeTrack()]));

    const recorder = createRecorder();
    await recorder.start();

    expect(() => recorder.level()).not.toThrow();
    recorder.discard();
  });
});
