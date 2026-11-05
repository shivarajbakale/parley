import { SERVER_KEY_IDS, type ServerKeyId } from './types';

/**
 * Sets or removes a provider key on parley-api, from the settings window. The
 * key goes to the server once and is never kept, logged or echoed here; the
 * server answers only whether the key is now set.
 */

const TIMEOUT_MS = 8000;

export class ServerKeyError extends Error {}

export function isServerKeyId(value: unknown): value is ServerKeyId {
  return typeof value === 'string' && (SERVER_KEY_IDS as readonly string[]).includes(value);
}

async function send(server: string, id: ServerKeyId, init: RequestInit, fetchFn: typeof fetch): Promise<void> {
  let response: Response;
  try {
    response = await fetchFn(`${server.replace(/\/+$/, '')}/api/providers/keys/${id}`, {
      ...init,
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
  } catch {
    throw new ServerKeyError('The Parley server did not answer');
  }
  if (response.status === 404) {
    throw new ServerKeyError('This Parley server is too old to take keys from the app — redeploy it');
  }
  if (!response.ok) {
    let message = `The server refused the key (${response.status})`;
    try {
      const body = (await response.json()) as { error?: { message?: unknown } };
      if (typeof body.error?.message === 'string') message = body.error.message;
    } catch {
      // Not JSON: keep the status message.
    }
    throw new ServerKeyError(message);
  }
}

export function setServerKey(server: string, id: ServerKeyId, key: string, fetchFn: typeof fetch = fetch) {
  return send(
    server,
    id,
    { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ key: key.trim() }) },
    fetchFn
  );
}

export function removeServerKey(server: string, id: ServerKeyId, fetchFn: typeof fetch = fetch) {
  return send(server, id, { method: 'DELETE' }, fetchFn);
}
