import { describe, it, expect, beforeAll } from 'vitest';
import request from 'supertest';
import app from '../src/app';

const dbDescribe = process.env.RUN_DB_TESTS ? describe : describe.skip;

async function tokenFor(email: string) {
  const res = await request(app).post('/api/auth/token').send({ email });
  return res.body.data.token as string;
}

dbDescribe('sync (e2e)', () => {
  let a: string;
  let b: string;
  beforeAll(async () => {
    a = await tokenFor('sync-a@example.com');
    b = await tokenFor('sync-b@example.com');
  });

  it('pushes, pulls since, and keeps the newer row', async () => {
    const put1 = await request(app).put('/api/dictionary').set('Authorization', `Bearer ${a}`)
      .send({ items: [{ id: 'd1', word: 'MiniMax', soundsLike: ['mini max'], updatedAt: 100 }] });
    expect(put1.status).toBe(200);
    expect(put1.body.data[0].word).toBe('MiniMax');

    const stale = await request(app).put('/api/dictionary').set('Authorization', `Bearer ${a}`)
      .send({ items: [{ id: 'd1', word: 'Minimax', soundsLike: [], updatedAt: 50 }] });
    expect(stale.body.data[0].word).toBe('MiniMax');
    expect(stale.body.data[0].updatedAt).toBe(100);

    const pull = await request(app).get('/api/dictionary?since=99').set('Authorization', `Bearer ${a}`);
    expect(pull.body.data.map((r: { id: string }) => r.id)).toEqual(['d1']);
    expect(typeof pull.body.meta.now).toBe('number');

    const none = await request(app).get('/api/dictionary?since=100').set('Authorization', `Bearer ${a}`);
    expect(none.body.data).toEqual([]);
  });

  it('isolates users', async () => {
    const pull = await request(app).get('/api/dictionary').set('Authorization', `Bearer ${b}`);
    expect(pull.body.data).toEqual([]);
  });

  it('tombstones come back in a pull', async () => {
    await request(app).put('/api/dictionary').set('Authorization', `Bearer ${a}`)
      .send({ items: [{ id: 'd1', word: 'MiniMax', soundsLike: [], updatedAt: 200, deletedAt: 200 }] });
    const pull = await request(app).get('/api/dictionary?since=150').set('Authorization', `Bearer ${a}`);
    expect(pull.body.data[0].deletedAt).toBe(200);
  });

  it('settings is one row per user whatever id the client sends', async () => {
    await request(app).put('/api/settings').set('Authorization', `Bearer ${a}`)
      .send({ items: [{ id: 'anything', data: { tickSound: false }, updatedAt: 10 }] });
    const pull = await request(app).get('/api/settings').set('Authorization', `Bearer ${a}`);
    expect(pull.body.data).toHaveLength(1);
    expect(pull.body.data[0].data).toEqual({ tickSound: false });
  });

  it('rejects an unauthenticated push and a bad row', async () => {
    expect((await request(app).put('/api/tasks').send({ items: [] })).status).toBe(401);
    const bad = await request(app).put('/api/tasks').set('Authorization', `Bearer ${a}`)
      .send({ items: [{ id: 't1', updatedAt: 1 }] });
    expect(bad.status).toBe(400);
  });
});
