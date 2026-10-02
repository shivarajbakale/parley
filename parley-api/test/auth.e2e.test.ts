import { describe, it, expect } from 'vitest';
import request from 'supertest';
import app from '../src/app';

const dbDescribe = process.env.RUN_DB_TESTS ? describe : describe.skip;

dbDescribe('auth (e2e)', () => {
  it('issues a token and gates /api/me with it', async () => {
    const issued = await request(app).post('/api/auth/token').send({ email: 'a@example.com' });
    expect(issued.status).toBe(201);
    const { token } = issued.body.data;
    expect(token).toMatch(/^[A-Za-z0-9_-]{40,}$/);

    expect((await request(app).get('/api/me')).status).toBe(401);
    const ok = await request(app).get('/api/me').set('Authorization', `Bearer ${token}`);
    expect(ok.status).toBe(200);
    expect(ok.body.data.userId).toBe(issued.body.data.userId);
    const bad = await request(app).get('/api/me').set('Authorization', 'Bearer nope');
    expect(bad.status).toBe(401);
  });
  it('rejects a malformed email', async () => {
    const res = await request(app).post('/api/auth/token').send({ email: 'nope' });
    expect(res.status).toBe(400);
  });
});
