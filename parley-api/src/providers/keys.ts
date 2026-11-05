import { mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { Router, type Request, type Response } from 'express';

/**
 * Provider keys set from the app's settings window. They live here, on the
 * server, like the ones in `.env` — the app sends a key once and never holds
 * it. A key saved here overrides the same key in `.env`, survives restarts
 * and redeploys (on the host it sits in a volume, not in the synced tree),
 * and is never sent back: `/api/providers/status` only says which are set.
 *
 * Reachable exactly as far as /api/providers is: loopback in local dev, the
 * tailnet on the Mac mini. Anyone who can spend the keys can replace them.
 */

export const MANAGED_KEYS = {
  groq: 'GROQ_API_KEY',
  deepgram: 'DEEPGRAM_API_KEY',
  minimax: 'MINIMAX_API_KEY',
  exa: 'EXA_API_KEY',
} as const;

export type KeyId = keyof typeof MANAGED_KEYS;

type Env = Record<string, string | undefined>;
type Stored = Partial<Record<(typeof MANAGED_KEYS)[KeyId], string>>;

const KNOWN_VARS = new Set<string>(Object.values(MANAGED_KEYS));

export function defaultKeyFile(env: Env = process.env): string {
  return env.PARLEY_KEYS_FILE || path.join(process.cwd(), '.data', 'provider-keys.json');
}

function readStored(file: string): Stored {
  try {
    const raw: unknown = JSON.parse(readFileSync(file, 'utf8'));
    if (!raw || typeof raw !== 'object') return {};
    const out: Stored = {};
    for (const [name, value] of Object.entries(raw)) {
      if (KNOWN_VARS.has(name) && typeof value === 'string') out[name as keyof Stored] = value;
    }
    return out;
  } catch {
    return {};
  }
}

/** At startup: keys saved from the app win over `.env`. An empty string is a removed key. */
export function loadKeyFile(file: string, env: Env): number {
  const stored = readStored(file);
  for (const [name, value] of Object.entries(stored)) env[name] = value;
  return Object.keys(stored).length;
}

function writeStored(file: string, stored: Stored): void {
  mkdirSync(path.dirname(file), { recursive: true, mode: 0o700 });
  const temp = `${file}.${process.pid}.tmp`;
  writeFileSync(temp, JSON.stringify(stored, null, 2) + '\n', { mode: 0o600 });
  renameSync(temp, file);
}

/** A key is one token: no spaces or line breaks, a sane length. */
export function validKey(value: unknown): value is string {
  return typeof value === 'string' && /^[\x21-\x7e]{8,512}$/.test(value.trim());
}

export function createKeysRouter(deps: { env?: Env; file?: string } = {}): Router {
  const env = deps.env ?? process.env;
  const file = deps.file ?? defaultKeyFile(env);
  const router = Router();

  const idOf = (req: Request): KeyId | null => {
    const id = String(req.params.id);
    return id in MANAGED_KEYS ? (id as KeyId) : null;
  };

  router.put('/:id', (req: Request, res: Response) => {
    const id = idOf(req);
    if (!id) return void res.status(404).json({ error: { code: 'unknown_provider', message: 'Unknown provider' } });
    const key = (req.body as { key?: unknown } | undefined)?.key;
    if (!validKey(key)) {
      return void res.status(400).json({ error: { code: 'invalid_key', message: 'That does not look like an API key' } });
    }
    const name = MANAGED_KEYS[id];
    const stored = readStored(file);
    stored[name] = key.trim();
    writeStored(file, stored);
    env[name] = key.trim();
    res.json({ [id]: true });
  });

  router.delete('/:id', (req: Request, res: Response) => {
    const id = idOf(req);
    if (!id) return void res.status(404).json({ error: { code: 'unknown_provider', message: 'Unknown provider' } });
    const name = MANAGED_KEYS[id];
    const stored = readStored(file);
    // Stored as empty, not deleted: a key in `.env` must not come back on restart.
    stored[name] = '';
    writeStored(file, stored);
    env[name] = '';
    res.json({ [id]: false });
  });

  return router;
}
