import type { ServerStatus, TranscriptionProvider } from '../../electron/types';

/** Dictation can run: the Parley server answers and holds the selected provider's key. */
export function transcriptionReady(status: ServerStatus | undefined, provider: TranscriptionProvider) {
  return Boolean(status?.reachable && status.keys?.[provider]);
}
