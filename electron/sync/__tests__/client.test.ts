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

  it('treats a 2xx without the envelope as a failure, not a success', async () => {
    const html = vi.fn(() =>
      Promise.resolve(new Response('<html>Sign in to Wi-Fi</html>', { status: 200, headers: { 'content-type': 'text/html' } })));
    const portal = createSyncClient({ baseUrl: 'http://x', token: 'tok', fetch: html as never });
    await expect(portal.pull('dictionary', 0)).rejects.toBeInstanceOf(SyncHttpError);
    await expect(portal.push('dictionary', [])).rejects.toMatchObject({ message: 'Malformed response from the sync server' });

    const noNow = vi.fn(() => json(200, { data: [], meta: {} }));
    const client = createSyncClient({ baseUrl: 'http://x', token: 'tok', fetch: noNow as never });
    await expect(client.pull('dictionary', 0)).rejects.toBeInstanceOf(SyncHttpError);
    await expect(client.push('dictionary', [])).rejects.toBeInstanceOf(SyncHttpError);

    const noData = vi.fn(() => json(201, { meta: {} }));
    const signIn = createSyncClient({ baseUrl: 'http://x', token: null, fetch: noData as never });
    await expect(signIn.signIn('me@example.com')).rejects.toBeInstanceOf(SyncHttpError);
  });

  it('throws SyncHttpError with the status on a non-2xx', async () => {
    // The API's transformResponse wraps the error handler's body in the envelope.
    const fetchMock = vi.fn(() => json(401, { data: { status: 'error', message: 'Invalid token' }, meta: {} }));
    const client = createSyncClient({ baseUrl: 'http://x', token: 'bad', fetch: fetchMock as never });
    await expect(client.pull('tasks', 0)).rejects.toMatchObject({ status: 401, message: 'Invalid token' });
    await expect(client.pull('tasks', 0)).rejects.toBeInstanceOf(SyncHttpError);
  });

  it('still reads a bare error body, and falls back to the status', async () => {
    const bare = vi.fn(() => json(503, { message: 'Down for maintenance' }));
    await expect(createSyncClient({ baseUrl: 'http://x', token: 't', fetch: bare as never }).pull('tasks', 0))
      .rejects.toMatchObject({ status: 503, message: 'Down for maintenance' });
    const empty = vi.fn(() => json(502, {}));
    await expect(createSyncClient({ baseUrl: 'http://x', token: 't', fetch: empty as never }).pull('tasks', 0))
      .rejects.toMatchObject({ status: 502, message: 'HTTP 502' });
  });
});
