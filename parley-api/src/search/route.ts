import { Router, type Request, type Response } from 'express';
import type { searchWeb } from '../mastra/tools/exa-search.js';

/**
 * Web search for callers on this Mac — the act-mode agent asks here so the
 * Exa key stays in this server. Same results and soft errors as the
 * explainer's tool: a failed search is a 200 with `error`, not a 5xx, so the
 * agent reads it and says what went wrong.
 *
 *   POST /api/search {query} -> {results: [{title, url, snippet}], error?}
 */
export function createSearchRouter(deps: { search: (query: string) => ReturnType<typeof searchWeb> }): Router {
  const router = Router();
  router.post('/', async (req: Request, res: Response) => {
    const query = typeof req.body?.query === 'string' ? req.body.query.trim() : '';
    if (!query) {
      res.status(400).json({ error: 'query is required' });
      return;
    }
    res.json(await deps.search(query));
  });
  return router;
}
