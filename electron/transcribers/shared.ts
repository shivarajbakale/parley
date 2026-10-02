import type { TranscriptionProvider } from '../types';

/**
 * What every provider shares: the error type the orb shows, the request
 * wrapper that bounds and maps each call, and the per-provider contract.
 *
 * Calls go to parley-api's /api/providers pass-through, which holds the keys;
 * the app sends none.
 */

/**
 * Every request is bounded. Without a signal a hung connection never settles,
 * so the session would sit in `transcribing` with the orb up forever.
 */
export const TRANSCRIBE_TIMEOUT_MS = 30_000;

/** `offline`: parley-api did not answer. `no_key`: it did, without this provider's key. */
export type TranscribeErrorKind = 'no_key' | 'offline' | 'network' | 'auth' | 'rate_limit' | 'server';

/** The name a `server` error puts on the pill, so the user knows whose fault it was. */
export const PROVIDER_NAMES: Record<TranscriptionProvider, string> = {
  groq: 'Groq',
  deepgram: 'Deepgram',
};

function messageFor(kind: TranscribeErrorKind, provider: TranscriptionProvider): string {
  switch (kind) {
    case 'no_key':
      return `No ${PROVIDER_NAMES[provider]} key on the Parley server`;
    case 'offline':
      return 'Parley server not running';
    case 'network':
      return 'No connection';
    case 'auth':
      return `Invalid ${PROVIDER_NAMES[provider]} key`;
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

/** Where parley-api passes a provider call on: `server` is the Parley server address. */
export function providerUrl(server: string, path: string): string {
  return `${server.replace(/\/+$/, '')}/api/providers${path}`;
}

/** parley-api's own refusals carry `{ error: { code } }`; a provider's do not. */
async function errorCode(response: Response): Promise<string | undefined> {
  try {
    const body = (await response.json()) as { error?: { code?: unknown } };
    return typeof body.error?.code === 'string' ? body.error.code : undefined;
  } catch {
    return undefined;
  }
}

/** Shared with the rewriter, which maps a few kinds of its own. */
export async function kindForResponse(response: Response): Promise<TranscribeErrorKind> {
  if (response.status === 503 && (await errorCode(response)) === 'no_key') return 'no_key';
  if (response.status === 502) return 'network';
  if (response.status === 401 || response.status === 403) return 'auth';
  if (response.status === 429) return 'rate_limit';
  return 'server';
}

/** A refused connection means parley-api is not running; a timeout is a slow network. */
export function kindForThrown(error: unknown): 'offline' | 'network' {
  return (error as Error | undefined)?.name === 'TimeoutError' ? 'network' : 'offline';
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
  transcribe(audio: TranscribeAudio, options: TranscribeOptions, server: string): Promise<string>;
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
      response = await fetchFn(url, { ...init, signal: AbortSignal.timeout(timeoutMs) });
    } catch (error) {
      throw new TranscribeError(kindForThrown(error), provider);
    }
    if (!response.ok) throw new TranscribeError(await kindForResponse(response), provider);
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
