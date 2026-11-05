import { createDeepgramProvider } from './transcribers/deepgram';
import { createGroqProvider } from './transcribers/groq';
import {
  type TranscribeAudio,
  type TranscribeOptions,
  type TranscriptionProviderClient,
} from './transcribers/shared';
import type { TranscriptionProvider } from './types';

/**
 * The seam between a dictation and whichever speech-to-text service the user
 * picked. Each provider lives in `transcribers/`; this file chooses one per
 * call, so switching providers in settings takes effect on the next gesture.
 * Both go through parley-api, which holds the keys.
 * If a cleanup pass is ever added, it wraps `transcribe` here and nothing else
 * changes.
 */

export { TranscribeError, type TranscribeErrorKind } from './transcribers/shared';

export interface Transcriber {
  transcribe(audio: TranscribeAudio, options: TranscribeOptions): Promise<string>;
}

export function createTranscriber(deps: {
  /** The Parley server address, read per call so a settings change applies at once. */
  serverUrl(): string;
  /** The provider the user picked; Groq when not given. */
  getProvider?(): TranscriptionProvider;
  fetchFn?: typeof fetch;
}): Transcriber {
  const fetchFn = deps.fetchFn ?? fetch;
  const providers: Record<TranscriptionProvider, TranscriptionProviderClient> = {
    groq: createGroqProvider(fetchFn),
    deepgram: createDeepgramProvider(fetchFn),
  };
  const current = () => deps.getProvider?.() ?? 'groq';

  return {
    transcribe: (audio, options) => providers[current()].transcribe(audio, options, deps.serverUrl()),
  };
}
