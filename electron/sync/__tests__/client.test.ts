import { describe, expect, it, vi } from 'vitest';

import { createSyncClient, SyncHttpError } from '../client';

const json = (status: number, body: unknown) =>
  Promise.resolve(new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } }));

describe('sync client', () => {
  it('signs in and sends the bearer token afterwards', async () => {
    const fetchMock = vi.fn()
      .mockImplementationOnce(() => json(201, { data: { token: 'tok', userId: 'u' }, meta: {} }))
      .mockImplementationOnce(() => json(200, { data: [{ id: 'd1' }], meta: { now: 5 } }));
    const client = createSyncClient({ baseUrl: 'http://x', token: null, fetch: fetchMock as never });
    expect(await client.signIn('me@example.com')).toEqual({ token: 'tok' });
    const pulled = await createSyncClient({ baseUrl: 'http://x/', token: 'tok', fetch: fetchMock as never })
      .pull('dictionary', 3);
    expect(pulled).toEqual({ rows: [{ id: 'd1' }], now: 5, hasMore: false });
    const [url, init] = fetchMock.mock.calls[1];
    expect(url).toBe('http://x/api/dictionary?since=3');
    expect((init.headers as Record<string, string>).Authorization).toBe('Bearer tok');
  });

  it('reports hasMore from the pull meta', async () => {
    const fetchMock = vi.fn(() => json(200, { data: [], meta: { now: 9, hasMore: true } }));
    const client = createSyncClient({ baseUrl: 'http://x', token: 'tok', fetch: fetchMock as never });
    expect(await client.pull('settings', 0)).toEqual({ rows: [], now: 9, hasMore: true });
  });

  it('throws SyncHttpError with the status on a non-2xx', async () => {
    const fetchMock = vi.fn(() => json(401, { status: 'error', message: 'Invalid token' }));
    const client = createSyncClient({ baseUrl: 'http://x', token: 'bad', fetch: fetchMock as never });
    await expect(client.pull('tasks', 0)).rejects.toMatchObject({ status: 401, message: 'Invalid token' });
    await expect(client.pull('tasks', 0)).rejects.toBeInstanceOf(SyncHttpError);
  });
});
