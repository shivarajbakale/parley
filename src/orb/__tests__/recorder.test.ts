import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { createRecorder, STOP_TIMEOUT_MS } from '../recorder';

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
  /** When false, `stop()` goes quiet — the wedged recorder this guards against. */
  static firesOnStop = true;
  static last: FakeMediaRecorder | null = null;

  state: 'inactive' | 'recording' = 'recording';
  ondataavailable: ((event: { data: Blob }) => void) | null = null;
  onstop: (() => void) | null = null;
  onerror: (() => void) | null = null;
  start = vi.fn();
  stop = vi.fn(() => {
    this.state = 'inactive';
    if (FakeMediaRecorder.firesOnStop) this.onstop?.();
  });

  constructor() {
    FakeMediaRecorder.last = this;
  }
}

describe('createRecorder race safety (finding 1)', () => {
  let getUserMedia: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    getUserMedia = vi.fn();
    vi.stubGlobal('navigator', { mediaDevices: { getUserMedia } });
    vi.stubGlobal('AudioContext', FakeAudioContext);
    vi.stubGlobal('MediaRecorder', FakeMediaRecorder);
    FakeMediaRecorder.firesOnStop = true;
    FakeMediaRecorder.last = null;
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

/** jsdom's Blob has no `arrayBuffer()`, and the normal stop path awaits one. */
class FakeBlob {
  constructor(
    _parts: unknown[],
    readonly options?: { type?: string }
  ) {}
  arrayBuffer() {
    return Promise.resolve(new ArrayBuffer(3));
  }
}

describe('createRecorder failure paths', () => {
  let getUserMedia: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    vi.useFakeTimers();
    vi.stubGlobal('Blob', FakeBlob);
    getUserMedia = vi.fn();
    vi.stubGlobal('navigator', { mediaDevices: { getUserMedia } });
    vi.stubGlobal('AudioContext', FakeAudioContext);
    vi.stubGlobal('MediaRecorder', FakeMediaRecorder);
    FakeMediaRecorder.firesOnStop = true;
    FakeMediaRecorder.last = null;
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.unstubAllGlobals();
  });

  it('resolves null and closes the mic when onstop never fires', async () => {
    const tracks = [fakeTrack()];
    getUserMedia.mockResolvedValue(fakeStream(tracks));
    FakeMediaRecorder.firesOnStop = false;

    const recorder = createRecorder();
    await recorder.start();
    const stopped = recorder.stop();

    vi.advanceTimersByTime(STOP_TIMEOUT_MS);

    expect(await stopped).toBeNull();
    expect(tracks[0].stop).toHaveBeenCalledTimes(1);
  });

  it('resolves null and closes the mic when the recorder errors', async () => {
    const tracks = [fakeTrack()];
    getUserMedia.mockResolvedValue(fakeStream(tracks));
    FakeMediaRecorder.firesOnStop = false;

    const recorder = createRecorder();
    await recorder.start();
    const active = FakeMediaRecorder.last!;
    const stopped = recorder.stop();

    active.onerror?.();

    expect(await stopped).toBeNull();
    expect(tracks[0].stop).toHaveBeenCalledTimes(1);

    // The fallback timer was cleared, so nothing runs a second release.
    vi.advanceTimersByTime(STOP_TIMEOUT_MS * 2);
    expect(tracks[0].stop).toHaveBeenCalledTimes(1);
  });

  it('clears the fallback timer on the normal path', async () => {
    const tracks = [fakeTrack()];
    getUserMedia.mockResolvedValue(fakeStream(tracks));

    const recorder = createRecorder();
    await recorder.start();
    const result = await recorder.stop();

    expect(result).toMatchObject({ mimeType: 'audio/webm' });
    expect(tracks[0].stop).toHaveBeenCalledTimes(1);

    vi.advanceTimersByTime(STOP_TIMEOUT_MS * 2);
    expect(tracks[0].stop).toHaveBeenCalledTimes(1);
  });
});
