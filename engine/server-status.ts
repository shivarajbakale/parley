import type { ServerKeys, ServerStatus } from './types';

/**
 * Asks parley-api whether it is up and which provider keys it holds, for the
 * settings window. Never throws: a server that does not answer, or answers
 * with something else, reads as not reachable.
 */

const STATUS_TIMEOUT_MS = 3_000;

function isKeys(value: unknown): value is ServerKeys {
  const keys = value as Partial<ServerKeys> | null;
  return (
    typeof keys === 'object' &&
    keys !== null &&
    typeof keys.groq === 'boolean' &&
    typeof keys.deepgram === 'boolean' &&
    typeof keys.minimax === 'boolean'
  );
}

export async function fetchServerStatus(url: string, fetchFn: typeof fetch = fetch): Promise<ServerStatus> {
  const unreachable: ServerStatus = { reachable: false, url, keys: null };
  try {
    const response = await fetchFn(`${url.replace(/\/+$/, '')}/api/providers/status`, {
      signal: AbortSignal.timeout(STATUS_TIMEOUT_MS),
    });
    if (!response.ok) return unreachable;
    const keys: unknown = await response.json();
    return isKeys(keys) ? { reachable: true, url, keys } : unreachable;
  } catch {
    return unreachable;
  }
}
