import { describe, it, expect } from 'vitest';
import request from 'supertest';
import app from '../src/app';

// Level-1 baseline: no database required. validate() and requireAuth both
// reject BEFORE any service touches Prisma, so these hold on a clean clone.
describe('request validation and auth gate (no database)', () => {
  it('rejects a token request with an invalid email', async () => {
    const res = await request(app)
      .post('/api/auth/token')
      .send({ email: 'not-an-email' })
      .set('Content-Type', 'application/json');

    expect(res.status).toBe(400);
    expect(res.body.data.message).toContain('email');
  });

  it('GET /api/me without an Authorization header returns 401', async () => {
    const res = await request(app).get('/api/me');
    expect(res.status).toBe(401);
  });

  it('a body over the 1 MB limit gets 413 with a message, not 500', async () => {
    const items = [{ id: 'x', word: 'a'.repeat(1_100_000), soundsLike: [], updatedAt: 1, deletedAt: null }];
    const res = await request(app)
      .put('/api/dictionary')
      .send({ items })
      .set('Content-Type', 'application/json');

    expect(res.status).toBe(413);
    expect(res.body.data.message).toMatch(/too large/i);
  });

  it('a full 500-row push (8 sounds-like each, ~300 kB) is parsed, not refused for size', async () => {
    const items = Array.from({ length: 500 }, (_, i) => ({
      id: `id-${i}`, word: 'w'.repeat(60), soundsLike: Array.from({ length: 8 }, () => 's'.repeat(60)), updatedAt: 1, deletedAt: null,
    }));
    const res = await request(app)
      .put('/api/dictionary')
      .send({ items })
      .set('Content-Type', 'application/json');

    // Past the parser: the auth gate answers, not body-parser.
    expect(res.status).toBe(401);
  });
});
