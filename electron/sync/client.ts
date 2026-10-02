export interface SyncClientOptions {
  baseUrl: string;
  token: string | null;
  fetch?: typeof fetch;
}

const MALFORMED = 'Malformed response from the sync server';

export class SyncHttpError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
    this.name = 'SyncHttpError';
  }
}

export interface PullPage<T> {
  rows: T[];
  /** The next `since`. */
  now: number;
  /** More rows wait past `now`; call again with it. */
  hasMore: boolean;
}

export interface SyncClient {
  signIn(email: string): Promise<{ token: string }>;
  pull<T>(resource: string, since: number): Promise<PullPage<T>>;
  push<T>(resource: string, items: T[]): Promise<{ rows: T[]; now: number }>;
}

interface Meta {
  now?: number;
  hasMore?: boolean;
}

/** Thin HTTP over the API's `{ data, meta }` envelope. No retries: the engine decides. */
export function createSyncClient({ baseUrl, token, fetch: doFetch = fetch }: SyncClientOptions): SyncClient {
  const root = baseUrl.replace(/\/+$/, '');

  /** A 2xx that is not our envelope (a captive portal, a proxy page) is a failure, never a success. */
  async function call<T>(method: string, path: string, body?: unknown): Promise<{ data: T; meta: Meta; status: number }> {
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (token) headers.Authorization = `Bearer ${token}`;
    const res = await doFetch(`${root}${path}`, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const parsed = (await res.json().catch(() => null)) as { data?: T; meta?: Meta; message?: string } | null;
    if (!res.ok) throw new SyncHttpError(res.status, parsed?.message ?? `HTTP ${res.status}`);
    if (!parsed || typeof parsed !== 'object' || parsed.data === undefined) throw new SyncHttpError(res.status, MALFORMED);
    return { data: parsed.data, meta: parsed.meta ?? {}, status: res.status };
  }

  /** The cursor is the server's clock; a page without it cannot be trusted. */
  async function stamped<T>(method: string, path: string, body?: unknown): Promise<{ data: T; now: number; hasMore: boolean }> {
    const { data, meta, status } = await call<T>(method, path, body);
    if (typeof meta.now !== 'number' || !Number.isFinite(meta.now)) throw new SyncHttpError(status, MALFORMED);
    return { data, now: meta.now, hasMore: meta.hasMore === true };
  }

  return {
    async signIn(email) {
      const { data } = await call<{ token: string }>('POST', '/api/auth/token', { email, label: 'parley-desktop' });
      return { token: data.token };
    },
    async pull<T>(resource: string, since: number) {
      const { data, now, hasMore } = await stamped<T[]>('GET', `/api/${resource}?since=${since}`);
      return { rows: data, now, hasMore };
    },
    async push<T>(resource: string, items: T[]) {
      const { data, now } = await stamped<T[]>('PUT', `/api/${resource}`, { items });
      return { rows: data, now };
    },
  };
}
