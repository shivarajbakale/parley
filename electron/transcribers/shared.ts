import type { KeyTestResult, TranscriptionProvider } from '../types';

/**
 * What every provider shares: the error type the orb shows, the request
 * wrapper that bounds and maps each call, and the per-provider contract.
 */

/**
 * Every request is bounded. Without a signal a hung connection never settles,
 * so the session would sit in `transcribing` with the orb up forever.
 */
export const TRANSCRIBE_TIMEOUT_MS = 30_000;
export const TEST_KEY_TIMEOUT_MS = 10_000;

export type TranscribeErrorKind = 'no_key' | 'network' | 'auth' | 'rate_limit' | 'server';

/** The name a `server` error puts on the pill, so the user knows whose fault it was. */
export const PROVIDER_NAMES: Record<TranscriptionProvider, string> = {
  groq: 'Groq',
  deepgram: 'Deepgram',
};

function messageFor(kind: TranscribeErrorKind, provider: TranscriptionProvider): string {
  switch (kind) {
    case 'no_key':
      return 'No API key';
    case 'network':
      return 'No connection';
    case 'auth':
      return 'Invalid API key';
    case 'rate_limit':
      return 'Rate limited';
    case 'server':
      return `${PROVIDER_NAMES[provider]} error`;
  }
}

export class TranscribeError extends Error {
  constructor(
    public readonly kind: TranscribeErrorKind,
    public readonly provider: TranscriptionProvider = 'groq'
  ) {
    super(messageFor(kind, provider));
    this.name = 'TranscribeError';
  }
}

function kindForStatus(status: number): TranscribeErrorKind {
  if (status === 401 || status === 403) return 'auth';
  if (status === 429) return 'rate_limit';
  return 'server';
}

export interface TranscribeAudio {
  data: ArrayBuffer;
  mimeType: string;
}

export interface TranscribeOptions {
  /** Whisper's `prompt`: a sentence that happens to contain the words. */
  vocabulary: string;
  /** The same words as a plain list, for providers that take keyterms. When
   * absent, a provider that needs a list splits `vocabulary` on commas. */
  terms?: string[];
}

/** One speech-to-text service. `createTranscriber` picks one per call. */
export interface TranscriptionProviderClient {
  transcribe(audio: TranscribeAudio, options: TranscribeOptions, key: string): Promise<string>;
  testKey(key: string): Promise<KeyTestResult>;
}

/** A bounded fetch that turns every failure into a `TranscribeError`. */
export function createRequest(provider: TranscriptionProvider, fetchFn: typeof fetch) {
  return async function request(
    url: string,
    init: RequestInit,
    timeoutMs: number
  ): Promise<Response> {
    let response: Response;
    try {
      // A timed-out request rejects with an AbortError, which the catch below
      // maps to `network` along with every other transport failure.
      response = await fetchFn(url, { ...init, signal: AbortSignal.timeout(timeoutMs) });
    } catch {
      throw new TranscribeError('network', provider);
    }
    if (!response.ok) throw new TranscribeError(kindForStatus(response.status), provider);
    return response;
  };
}

/** A 200 that is not JSON is a provider-side failure, not a bug to surface
 * raw: the orb shows this message. */
export async function readJson<T>(response: Response, provider: TranscriptionProvider): Promise<T> {
  try {
    return (await response.json()) as T;
  } catch {
    throw new TranscribeError('server', provider);
  }
}

/** Run a key check, reporting its failure the way the settings window shows it. */
export async function keyResult(check: () => Promise<unknown>): Promise<KeyTestResult> {
  try {
    await check();
    return { ok: true, message: 'Key works' };
  } catch (error) {
    return { ok: false, message: (error as Error).message };
  }
}
