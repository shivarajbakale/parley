import { describe, it, expect, beforeAll } from 'vitest';
import request from 'supertest';
import app from '../src/app';

const dbDescribe = process.env.RUN_DB_TESTS ? describe : describe.skip;

async function tokenFor(email: string) {
  const res = await request(app).post('/api/auth/token').send({ email });
  return { token: res.body.data.token as string, userId: res.body.data.userId as string };
}

dbDescribe('sync (e2e)', () => {
  let a: string;
  let b: string;
  let aId: string;
  let cursor: number;
  beforeAll(async () => {
    const ta = await tokenFor('sync-a@example.com');
    const tb = await tokenFor('sync-b@example.com');
    a = ta.token;
    aId = ta.userId;
    b = tb.token;
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

    const pull = await request(app).get('/api/dictionary?since=0').set('Authorization', `Bearer ${a}`);
    expect(pull.body.data.map((r: { id: string }) => r.id)).toEqual(['d1']);
    expect(typeof pull.body.meta.now).toBe('number');

    const none = await request(app).get(`/api/dictionary?since=${Date.now() + 1000}`).set('Authorization', `Bearer ${a}`);
    expect(none.body.data).toEqual([]);

    const all = await request(app).get('/api/dictionary').set('Authorization', `Bearer ${a}`);
    expect(all.body.meta.hasMore).toBe(false);
    cursor = all.body.meta.now;
  });

  it('isolates users', async () => {
    const pull = await request(app).get('/api/dictionary').set('Authorization', `Bearer ${b}`);
    expect(pull.body.data).toEqual([]);
  });

  it('isolates users on write: the same id under another user is its own row', async () => {
    const put = await request(app).put('/api/dictionary').set('Authorization', `Bearer ${b}`)
      .send({ items: [{ id: 'd1', word: 'Hijack', soundsLike: [], updatedAt: 999 }] });
    expect(put.body.data[0].word).toBe('Hijack');
    const pa = await request(app).get('/api/dictionary').set('Authorization', `Bearer ${a}`);
    expect(pa.body.data).toHaveLength(1);
    expect(pa.body.data[0].word).toBe('MiniMax');
    const pb = await request(app).get('/api/dictionary').set('Authorization', `Bearer ${b}`);
    expect(pb.body.data.map((r: { word: string }) => r.word)).toEqual(['Hijack']);
  });

  it('tombstones come back in a pull', async () => {
    await request(app).put('/api/dictionary').set('Authorization', `Bearer ${a}`)
      .send({ items: [{ id: 'd1', word: 'MiniMax', soundsLike: [], updatedAt: 200, deletedAt: 200 }] });
    const pull = await request(app).get(`/api/dictionary?since=${cursor}`).set('Authorization', `Bearer ${a}`);
    expect(pull.body.data[0].deletedAt).toBe(200);
  });

  it('settings is one row per user whatever id the client sends', async () => {
    await request(app).put('/api/settings').set('Authorization', `Bearer ${a}`)
      .send({ items: [{ id: 'anything', data: { tickSound: false }, updatedAt: 10 }] });
    const pull = await request(app).get('/api/settings').set('Authorization', `Bearer ${a}`);
    expect(pull.body.data).toHaveLength(1);
    expect(pull.body.data[0].data).toEqual({ tickSound: false });

    await request(app).put('/api/settings').set('Authorization', `Bearer ${a}`)
      .send({ items: [{ id: 'first', data: { x: 1 }, updatedAt: 20 }] });
    await request(app).put('/api/settings').set('Authorization', `Bearer ${a}`)
      .send({ items: [{ id: 'second', data: { x: 2 }, updatedAt: 30 }] });
    const again = await request(app).get('/api/settings').set('Authorization', `Bearer ${a}`);
    expect(again.body.data).toHaveLength(1);
    expect(again.body.data[0].id).toBe(aId);
  });

  it('round-trips a history item', async () => {
    const row = { id: 'h1', mode: 'dictate', text: 'hello', app: 'Notes', createdAt: 5, updatedAt: 6, deletedAt: null };
    await request(app).put('/api/history').set('Authorization', `Bearer ${a}`).send({ items: [row] });
    const pull = await request(app).get('/api/history').set('Authorization', `Bearer ${a}`);
    expect(pull.body.data).toEqual([row]);
  });

  it('round-trips a task', async () => {
    const row = {
      id: 't1', title: 'Call', notes: 'n', dueAt: 1234, rrule: 'FREQ=DAILY', priority: 'high',
      status: 'snoozed', sourceText: 'remind me', updatedAt: 7, deletedAt: null,
    };
    await request(app).put('/api/tasks').set('Authorization', `Bearer ${a}`).send({ items: [row] });
    const pull = await request(app).get('/api/tasks').set('Authorization', `Bearer ${a}`);
    expect(pull.body.data).toEqual([row]);
  });

  it('applies zod defaults on push', async () => {
    await request(app).put('/api/tasks').set('Authorization', `Bearer ${a}`)
      .send({ items: [{ id: 't2', title: 'Min', updatedAt: 8 }] });
    const pull = await request(app).get('/api/tasks').set('Authorization', `Bearer ${a}`);
    const t2 = pull.body.data.find((r: { id: string }) => r.id === 't2');
    expect(t2).toMatchObject({ priority: 'medium', status: 'open', notes: '' });
  });

  it('rejects a non-integer since', async () => {
    const res = await request(app).get('/api/dictionary?since=1.5').set('Authorization', `Bearer ${a}`);
    expect(res.status).toBe(400);
  });

  it('pages with hasMore and the returned cursor', async () => {
    const items = Array.from({ length: 500 }, (_, i) => ({ id: `p${i}`, mode: 'edit', text: 'x', createdAt: 1, updatedAt: 1 }));
    for (let k = 0; k < 3; k++) {
      const batch = items.map(i => ({ ...i, id: `${i.id}-${k}` }));
      await request(app).put('/api/history').set('Authorization', `Bearer ${b}`).send({ items: batch });
    }
    const first = await request(app).get('/api/history').set('Authorization', `Bearer ${b}`);
    expect(first.body.data).toHaveLength(1000);
    expect(first.body.meta.hasMore).toBe(true);
    const second = await request(app).get(`/api/history?since=${first.body.meta.now}`).set('Authorization', `Bearer ${b}`);
    expect(second.body.meta.hasMore).toBe(false);
    expect(first.body.data.length + second.body.data.length).toBe(1500);
  });

  it('rejects an unauthenticated push and a bad row', async () => {
    expect((await request(app).put('/api/tasks').send({ items: [] })).status).toBe(401);
    const bad = await request(app).put('/api/tasks').set('Authorization', `Bearer ${a}`)
      .send({ items: [{ id: 't1', updatedAt: 1 }] });
    expect(bad.status).toBe(400);
  });
});
