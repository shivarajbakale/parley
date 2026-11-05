import { Readable } from 'node:stream';
import { Router, type Request, type Response } from 'express';

/**
 * /api/providers: the provider keys live here, not in the desktop app. The app
 * makes the same Groq, Deepgram and MiniMax calls it always made, to this
 * server instead, with no key; this adds the key and streams the answer back.
 *
 * Only the exact calls the app and the Act agent make are passed on, so this
 * is not an open proxy. Mount it before `express.json()`: the body is
 * forwarded as the raw stream it arrived as.
 */

interface Provider {
  base: string;
  env: string;
  name: string;
  auth(key: string): string;
  paths: string[];
}

export const PROVIDERS: Record<string, Provider> = {
  groq: {
    base: 'https://api.groq.com',
    env: 'GROQ_API_KEY',
    name: 'Groq',
    auth: (key) => `Bearer ${key}`,
    paths: ['/openai/v1/audio/transcriptions'],
  },
  deepgram: {
    base: 'https://api.deepgram.com',
    env: 'DEEPGRAM_API_KEY',
    name: 'Deepgram',
    auth: (key) => `Token ${key}`,
    paths: ['/v1/listen'],
  },
  minimax: {
    base: 'https://api.minimax.io',
    env: 'MINIMAX_API_KEY',
    name: 'MiniMax',
    auth: (key) => `Bearer ${key}`,
    // Chat completions for voice edit; MiniMax's Anthropic-style API for the Act agent's model.
    paths: ['/v1/chat/completions', '/anthropic/v1/messages'],
  },
};

/** Headers passed on to the provider; everything else, Authorization included, is dropped. */
const FORWARDED_HEADERS = ['content-type', 'accept'];
/** The Anthropic-style API also needs its version and beta headers. */
const FORWARDED_PREFIX = 'anthropic-';

type Env = Record<string, string | undefined>;

function keyFor(provider: Provider, env: Env): string | undefined {
  return env[provider.env]?.trim() || undefined;
}

function fail(res: Response, status: number, code: string, message: string) {
  res.status(status).json({ error: { code, message } });
}

export function createProvidersRouter(deps: { env?: Env; fetch?: typeof fetch } = {}): Router {
  const env = deps.env ?? process.env;
  const fetchFn = deps.fetch ?? fetch;
  const router = Router();

  /** Which keys this server has; never the keys. */
  router.get('/status', (_req: Request, res: Response) => {
    res.json(Object.fromEntries(Object.entries(PROVIDERS).map(([id, p]) => [id, Boolean(keyFor(p, env))])));
  });

  router.post('/:provider/*path', async (req: Request, res: Response) => {
    const provider = PROVIDERS[String(req.params.provider)];
    const path = '/' + ([] as string[]).concat(req.params.path ?? []).join('/');
    if (!provider || !provider.paths.includes(path)) {
      fail(res, 404, 'not_allowed', 'Not a provider call this server passes on');
      return;
    }
    const key = keyFor(provider, env);
    if (!key) {
      fail(
        res,
        503,
        'no_key',
        `${provider.env} is not set on the Parley server. Add it to parley-api/.env and restart the server.`,
      );
      return;
    }

    const headers: Record<string, string> = { Authorization: provider.auth(key) };
    for (const [name, value] of Object.entries(req.headers)) {
      if (typeof value !== 'string') continue;
      if (FORWARDED_HEADERS.includes(name) || name.startsWith(FORWARDED_PREFIX)) headers[name] = value;
    }
    const query = req.originalUrl.includes('?') ? req.originalUrl.slice(req.originalUrl.indexOf('?')) : '';

    const abort = new AbortController();
    res.on('close', () => {
      if (!res.writableFinished) abort.abort();
    });

    let upstream: globalThis.Response;
    try {
      upstream = await fetchFn(`${provider.base}${path}${query}`, {
        method: 'POST',
        headers,
        body: Readable.toWeb(req) as ReadableStream,
        // Node's fetch needs this to send a streamed body.
        duplex: 'half',
        signal: abort.signal,
      } as RequestInit);
    } catch {
      if (!abort.signal.aborted) fail(res, 502, 'unreachable', `Can't reach ${provider.name}`);
      return;
    }

    res.status(upstream.status);
    const type = upstream.headers.get('content-type');
    if (type) res.setHeader('Content-Type', type);
    if (!upstream.body) {
      res.end();
      return;
    }
    Readable.fromWeb(upstream.body as import('node:stream/web').ReadableStream).on('error', () => res.end()).pipe(res);
  });

  return router;
}
