import { describe, it, expect } from 'vitest';
import request from 'supertest';
import app from '../src/app';

// Level-1 baseline: no database required. Exercises routing, the root route,
// the response-transform middleware, and the 404 handler.
describe('health + app shell', () => {
  it('GET /api/health returns 200 wrapped in the { data, meta } envelope', async () => {
    const res = await request(app).get('/api/health');

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('data');
    expect(res.body).toHaveProperty('meta');
    expect(res.body.data.status).toBe('success');
    expect(res.body.meta.statusCode).toBe(200);
  });

  it('GET / returns the welcome payload with the endpoint map', async () => {
    const res = await request(app).get('/');

    expect(res.status).toBe(200);
    expect(res.body.data.endpoints).toMatchObject({
      health: '/api/health',
      users: '/api/users',
    });
  });

  it('unknown routes hit the 404 handler', async () => {
    const res = await request(app).get('/api/does-not-exist');

    expect(res.status).toBe(404);
    expect(res.body.data.status).toBe('error');
  });

  it('sets a correlation id header on every response', async () => {
    const res = await request(app).get('/api/health');
    expect(res.headers['x-correlation-id']).toBeDefined();
  });
});
