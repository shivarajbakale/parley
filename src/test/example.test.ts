import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';
import { server } from '../mocks/node';
import type { Project } from '@/api/types';

/**
 * Reference test for the Projects slice.
 *
 * Shows the pattern the `add-feature` skill follows: exercise a resource through
 * its MSW handlers (the same ones the app uses), and override a handler to test
 * a failure path.
 *
 * The handlers use relative paths (e.g. `/api/projects`) so MSW resolves them
 * against the current origin — exactly as in the browser. Under jsdom (this
 * project's test environment) that origin is `location.origin`, so we build
 * request URLs from it to guarantee handler and request agree.
 */
const api = (path: string) => `${location.origin}${path}`;

describe('Projects API (MSW handlers)', () => {
  it('lists projects', async () => {
    const res = await fetch(api('/api/projects'));
    const body = await res.json();

    expect(res.ok).toBe(true);
    expect(body.success).toBe(true);
    expect(Array.isArray(body.data)).toBe(true);
    expect(body.data.length).toBeGreaterThan(0);
  });

  it('creates then fetches a project', async () => {
    const create = await fetch(api('/api/projects'), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: 'Test Project', description: 'from a test' }),
    });
    const created = (await create.json()).data as Project;

    expect(create.status).toBe(201);
    expect(created.name).toBe('Test Project');
    expect(created.status).toBe('active');

    const get = await fetch(api(`/api/projects/${created.id}`));
    const fetched = (await get.json()).data as Project;
    expect(fetched.id).toBe(created.id);
  });

  it('returns 404 for a missing project', async () => {
    const res = await fetch(api('/api/projects/does-not-exist'));
    expect(res.status).toBe(404);
  });

  it('surfaces server errors (handler override)', async () => {
    server.use(
      http.get('/api/projects', () =>
        HttpResponse.json({ success: false, message: 'boom' }, { status: 500 })
      )
    );
    const res = await fetch(api('/api/projects'));
    expect(res.status).toBe(500);
  });
});
