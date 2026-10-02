import { describe, it, expect } from 'vitest';
import request from 'supertest';
import app from '../src/app';

// Level-1 baseline: no database required. The validate() middleware runs and
// rejects bad input BEFORE any controller/service touches Prisma, so these
// assertions hold on a clean clone with no database pushed.
describe('request validation (Zod middleware)', () => {
  it('rejects a user with an invalid email', async () => {
    const res = await request(app)
      .post('/api/users')
      .send({ name: 'Jo', email: 'not-an-email' })
      .set('Content-Type', 'application/json');

    expect(res.status).toBe(400);
    expect(res.body.data.message).toContain('email');
  });
});
