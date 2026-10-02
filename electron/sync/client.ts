export interface SyncClientOptions {
  baseUrl: string;
  token: string | null;
  fetch?: typeof fetch;
}

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

  async function call<T>(method: string, path: string, body?: unknown): Promise<{ data: T; meta: Meta }> {
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (token) headers.Authorization = `Bearer ${token}`;
    const res = await doFetch(`${root}${path}`, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const parsed = (await res.json().catch(() => ({}))) as { data?: T; meta?: Meta; message?: string };
    if (!res.ok) throw new SyncHttpError(res.status, parsed.message ?? `HTTP ${res.status}`);
    return { data: parsed.data as T, meta: parsed.meta ?? {} };
  }

  return {
    async signIn(email) {
      const { data } = await call<{ token: string }>('POST', '/api/auth/token', { email, label: 'parley-desktop' });
      return { token: data.token };
    },
    async pull<T>(resource: string, since: number) {
      const { data, meta } = await call<T[]>('GET', `/api/${resource}?since=${since}`);
      return { rows: data ?? [], now: meta.now ?? Date.now(), hasMore: meta.hasMore === true };
    },
    async push<T>(resource: string, items: T[]) {
      const { data, meta } = await call<T[]>('PUT', `/api/${resource}`, { items });
      return { rows: data ?? [], now: meta.now ?? Date.now() };
    },
  };
}
