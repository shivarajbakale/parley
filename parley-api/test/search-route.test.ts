import express from 'express';
import request from 'supertest';
import { describe, expect, it, vi } from 'vitest';
import { createSearchRouter } from '../src/search/route.js';

function appWith(search: (query: string) => Promise<{ results: { title: string; url: string; snippet: string }[]; error?: string }>) {
  const app = express();
  app.use(express.json());
  app.use('/api/search', createSearchRouter({ search }));
  return app;
}

describe('POST /api/search', () => {
  it('answers with the search results for the trimmed query', async () => {
    const search = vi.fn().mockResolvedValue({ results: [{ title: 'T', url: 'https://t.dev', snippet: 's' }] });
    const res = await request(appWith(search)).post('/api/search').send({ query: '  weather in Pune ' });
    expect(res.status).toBe(200);
    expect(search).toHaveBeenCalledWith('weather in Pune');
    expect(res.body).toEqual({ results: [{ title: 'T', url: 'https://t.dev', snippet: 's' }] });
  });

  it('passes a soft search error through as a 200', async () => {
    const search = vi.fn().mockResolvedValue({ results: [], error: 'Search unavailable: EXA_API_KEY is not set' });
    const res = await request(appWith(search)).post('/api/search').send({ query: 'q' });
    expect(res.status).toBe(200);
    expect(res.body.error).toMatch(/EXA_API_KEY/);
  });

  it('rejects a missing or blank query without searching', async () => {
    const search = vi.fn();
    expect((await request(appWith(search)).post('/api/search').send({ query: ' ' })).status).toBe(400);
    expect((await request(appWith(search)).post('/api/search').send({})).status).toBe(400);
    expect(search).not.toHaveBeenCalled();
  });
});
