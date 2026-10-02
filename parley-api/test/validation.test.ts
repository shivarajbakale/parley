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
});
