import { createDeepgramProvider } from './transcribers/deepgram';
import { createGroqProvider } from './transcribers/groq';
import {
  TranscribeError,
  type TranscribeAudio,
  type TranscribeOptions,
  type TranscriptionProviderClient,
} from './transcribers/shared';
import type { KeyTestResult, TranscriptionProvider } from './types';

/**
 * The seam between a dictation and whichever speech-to-text service the user
 * picked. Each provider lives in `transcribers/`; this file chooses one per
 * call, so switching providers in settings takes effect on the next gesture.
 * If a cleanup pass is ever added, it wraps `transcribe` here and nothing else
 * changes.
 */

export { TranscribeError, type TranscribeErrorKind } from './transcribers/shared';

export interface Transcriber {
  transcribe(audio: TranscribeAudio, options: TranscribeOptions): Promise<string>;
  /** Tests `key` against `provider`, the selected one when omitted. */
  testKey(key: string, provider?: TranscriptionProvider): Promise<KeyTestResult>;
}

export function createTranscriber(deps: {
  /** The stored key for `provider`. */
  getApiKey(provider: TranscriptionProvider): string | null;
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
    async transcribe(audio, options) {
      const provider = current();
      const key = deps.getApiKey(provider);
      if (!key) throw new TranscribeError('no_key', provider);
      return providers[provider].transcribe(audio, options, key);
    },
    testKey: (key, provider = current()) => providers[provider].testKey(key),
  };
}
