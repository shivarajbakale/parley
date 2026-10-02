# Monorepo and Sync API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put every Parley project in this one repo under one `make check`, and add an Express sync API the desktop app pushes its dictionary and settings to.

**Architecture:** Desktop stays at the repo root. Android arrives by `git subtree add` into `parley-android/`. The API is a `create-express-app` scaffold in `parley-api/` with bearer-token auth and one generic last-writer-wins sync router mounted once per resource. The desktop gets an `electron/sync/` module (HTTP client, merge engine) behind three IPC channels and a Sync settings tab.

**Tech Stack:** Express 4, Prisma 5 + SQLite, Zod, vitest + supertest (API). Electron, React 19, Mantine 9, TanStack Query, vitest (desktop). Flutter (Android, untouched).

**Spec:** `docs/superpowers/specs/2026-10-02-monorepo-and-api-design.md`

## Global Constraints

- Layout A: desktop at root, siblings `parley-agent/`, `parley-api/`, `parley-android/`. No `apps/` move.
- API port default `3100`. Agent keeps `4111`.
- API keys for Groq, Deepgram and MiniMax never leave the client. The sync `settings` blob never contains them.
- Sync rule: last-writer-wins by `updatedAt` (ms since epoch), soft delete via `deletedAt`.
- Auth v1: bearer token issued per email, no passwords. Token hash stored, never the token.
- Root `make check` must stay green on a machine without Flutter (android-check skips with a message).
- Every root feature plan change goes through `plan-feature`; `make plan-lint` enforces it.
- Commit messages end with the attribution lines from the session reminder.
- Spec deviation, recorded here: the API `dictionary` entry mirrors the desktop's real shape (`word`, `soundsLike[]`), not `spoken`/`written`.

## Review Focus

1. A push with an `updatedAt` older than the server row must not overwrite it, and the server must answer with the winning row so the client converges. (Task 5 unit test on `mergeRow`, e2e in Task 6.)
2. A token from user A must never read user B's rows. (Task 6 e2e: two tokens, cross-read returns empty.)
3. A client clock ahead of the server must not freeze a row forever: server clamps `updatedAt` to `now + 5 min`. (Task 5 unit test.)
4. Sync must never block dictation: a down server yields a status message, dictation continues. (Task 8 engine test with a rejecting fetch; no throw escapes `syncNow`.)
5. `git subtree add` must keep Android history and must not drag `build/`, `.dart_tool/` into the root index. (Task 1 verification step counts commits and checks `git ls-files`.)

---

### Task 1: Bring Android in with history

**Files:**
- Create: `parley-android/` (subtree)
- Modify: `Makefile` (root), `init.sh` (root), `README.md` (root)

**Interfaces:**
- Produces: root `make android-check` target, root `init.sh` running `flutter pub get` when flutter exists.

- [ ] **Step 1: Commit the pending Android work in its own repo**

```bash
cd ~/Projects/parley_android
git add -A
git commit -m "wip: parley-a07 screen context serializer and review notes

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EHEdBYfo6unHheVK8q8RUy"
git log --oneline | wc -l   # expect 16
git status --porcelain      # expect empty
```

- [ ] **Step 2: Subtree add from the parley root**

```bash
cd ~/Projects/parley
git subtree add --prefix=parley-android ~/Projects/parley_android main -m "feat: fold the Android app in as parley-android/ (parley-014)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EHEdBYfo6unHheVK8q8RUy"
```

If the Android default branch is not `main`, use the name `git -C ~/Projects/parley_android branch --show-current` prints.

- [ ] **Step 3: Verify history and index**

```bash
git log --oneline -- parley-android | wc -l        # expect >= 16
git ls-files parley-android | grep -E '^parley-android/(build|\.dart_tool)/' | wc -l   # expect 0
ls parley-android/Makefile parley-android/init.sh   # both exist
```

- [ ] **Step 4: Root Makefile targets**

Add to `.PHONY`: `android-check api-check`. Add after the `setup:` block:

```make
# The Android app verifies with its own harness. Skipped, not failed, when
# flutter is absent: the desktop baseline must stay runnable without it.
android-check:
	@if command -v "$${FLUTTER_BIN:-flutter}" >/dev/null 2>&1; then \
		$(MAKE) -C parley-android check; \
	else \
		echo "android-check: flutter not on PATH, skipped (set FLUTTER_BIN to run it)"; \
	fi
```

Append `android-check` to the root `check:` dependency list (after `loop-lint`) and to the `help` line for `check`.

- [ ] **Step 5: Root init.sh**

After `npm --prefix parley-agent install` add:

```bash
if command -v "${FLUTTER_BIN:-flutter}" >/dev/null 2>&1; then
  echo "==> Android dependencies (flutter pub get)"
  (cd parley-android && "${FLUTTER_BIN:-flutter}" pub get)
else
  echo "==> flutter not on PATH: skipping parley-android (set FLUTTER_BIN to include it)"
fi
```

- [ ] **Step 6: README project map**

Insert after the first paragraph of `README.md`:

```markdown
## Projects in this repo

| Folder | What | Verify |
|---|---|---|
| `/` (root) | macOS desktop app (Electron) | `make check` |
| `parley-agent/` | Mastra agent behind act mode | `cd parley-agent && npm test` |
| `parley-api/` | Express sync API (dictionary, settings, history, tasks) | `make -C parley-api check` |
| `parley-android/` | Android app (Flutter) | `make -C parley-android check` |

`~/Projects/parley_android` is a stale copy. Edit only `parley-android/` here.
```

- [ ] **Step 7: Run and commit**

```bash
make android-check            # runs or prints the skip line, exit 0
git add Makefile init.sh README.md
git commit -m "chore: root harness fans out to parley-android (parley-014)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EHEdBYfo6unHheVK8q8RUy"
```

---

### Task 2: Scaffold the API and wire it into the root harness

**Files:**
- Create: `parley-api/` (scaffold)
- Delete: `parley-api/src/routes/todo.routes.ts`, `src/controllers/todo.controller.ts`, `src/services/todo.service.ts`, `src/types/todo.types.ts`, `test/todo.e2e.test.ts`
- Modify: `parley-api/src/routes/index.ts`, `parley-api/src/app.ts`, `parley-api/prisma/schema.prisma`, `parley-api/prisma/seed.ts`, `parley-api/.env.example`, `parley-api/test/health.test.ts`
- Modify (root): `Makefile`, `init.sh`, `vite.config.ts:84`, `.eslintrc.cjs:9`, `.prettierignore`, `feature_list.json`

**Interfaces:**
- Produces: `parley-api` app exporting `app` from `src/app.ts`; root `make api-check`.

- [ ] **Step 1: Scaffold**

```bash
cd ~/Projects/parley
cea parley-api --dir ./parley-api --skip-git --description "Parley sync API" -y
ls parley-api/src/app.ts parley-api/Makefile   # both exist
test -d parley-api/.git && echo "UNEXPECTED nested git" || echo ok
```

- [ ] **Step 2: Strip the todo sample**

```bash
cd parley-api
git rm -q --cached -r . 2>/dev/null; rm -f src/routes/todo.routes.ts src/controllers/todo.controller.ts src/services/todo.service.ts src/types/todo.types.ts test/todo.e2e.test.ts
```

Edit `src/routes/index.ts` to:

```ts
import { Router } from 'express';
import healthRoutes from './health.routes';
import userRoutes from './user.routes';

const router = Router();

router.use('/health', healthRoutes);
router.use('/users', userRoutes);

export default router;
```

In `src/app.ts` root route, replace the `endpoints` object with:

```ts
    endpoints: {
      health: '/api/health',
      users: '/api/users',
    }
```

and `message: 'Parley sync API'`.

In `prisma/schema.prisma` delete the `Todo` model. In `prisma/seed.ts` delete every todo line (keep the demo user if present, or make the seed a no-op that logs "nothing to seed").

In `test/health.test.ts` change the `toMatchObject` to `{ health: '/api/health', users: '/api/users' }`.

In `.env.example` and `.env` set `PORT=3100`. In `src/config/env.ts` change the default `'3000'` to `'3100'`.

- [ ] **Step 3: API check green on its own**

```bash
cd ~/Projects/parley/parley-api
./init.sh
make check
```

Expected: exit 0. If `api-lint` A4 fails, that is expected to pass here because `docs/CONSTRAINTS.md` still declares "ships no auth"; Task 4 replaces that.

- [ ] **Step 4: Root wiring**

`Makefile`: add

```make
api-check:
	$(MAKE) -C parley-api check
```

and `api-check` to `.PHONY`, to the `check:` dependencies (before `android-check`), and to the help line. `setup:` gains `$(NPM) --prefix parley-api install`.

`init.sh`: after the agent install add

```bash
echo "==> API dependencies and schema (parley-api)"
(cd parley-api && [ -f .env ] || cp .env.example .env)
npm --prefix parley-api install
npm --prefix parley-api run db:push
```

`vite.config.ts` line 84:

```ts
    exclude: [...configDefaults.exclude, '.claude/**', 'parley-api/**', 'parley-android/**'],
```

`.eslintrc.cjs` line 9:

```js
  ignorePatterns: ['dist', 'dist-electron', 'release', '.eslintrc.cjs', 'parley-agent', 'parley-api', 'parley-android'],
```

`.prettierignore`: append `parley-api`, `parley-android`, `parley-agent` on three lines.

- [ ] **Step 5: Register parley-014 in feature_list.json**

Append to `features` (match the existing object shape; `priority` one above the highest present):

```json
{
  "id": "parley-014",
  "priority": 16,
  "area": "repo",
  "title": "Monorepo: Android and the sync API live beside the desktop app",
  "user_visible_behavior": "One clone holds the desktop app, the agent, the Android app and the API. ./init.sh installs all of them and make check verifies all of them, skipping Android when flutter is absent.",
  "status": "in_progress",
  "plan": "none: repository plumbing, no UI surface",
  "verification": [
    "make check",
    "git log --oneline -- parley-android | wc -l is at least 16",
    "make -C parley-api check",
    "make android-check prints the skip line without flutter and runs the Flutter check with it"
  ],
  "evidence": [],
  "notes": "Spec docs/superpowers/specs/2026-10-02-monorepo-and-api-design.md, layout A."
}
```

- [ ] **Step 6: Root check and commit**

```bash
cd ~/Projects/parley
make check
git add -A parley-api Makefile init.sh vite.config.ts .eslintrc.cjs .prettierignore feature_list.json
git commit -m "feat: scaffold parley-api with create-express-app and fan root check out to it (parley-014)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EHEdBYfo6unHheVK8q8RUy"
```

---

### Task 3: Prisma schema for users, tokens and the four sync resources

**Files:**
- Modify: `parley-api/prisma/schema.prisma`
- Test: `parley-api/test/schema.test.ts`

**Interfaces:**
- Produces: Prisma models `User`, `ApiToken`, `DictionaryEntry`, `SettingsBlob`, `HistoryItem`, `Task`. Every sync model has `id String @id`, `userId String`, `updatedAt BigInt`, `deletedAt BigInt?`.

- [ ] **Step 1: Failing test**

`test/schema.test.ts`:

```ts
import { describe, it, expect } from 'vitest';
import { Prisma } from '@prisma/client';

const syncModels = ['DictionaryEntry', 'SettingsBlob', 'HistoryItem', 'Task'];

describe('sync schema', () => {
  for (const name of syncModels) {
    it(`${name} carries userId, updatedAt and deletedAt`, () => {
      const model = Prisma.dmmf.datamodel.models.find(m => m.name === name);
      expect(model, `${name} model`).toBeTruthy();
      const fields = Object.fromEntries(model!.fields.map(f => [f.name, f]));
      expect(fields.userId.type).toBe('String');
      expect(fields.updatedAt.type).toBe('BigInt');
      expect(fields.deletedAt.isRequired).toBe(false);
    });
  }
  it('ApiToken stores a hash, never a token', () => {
    const model = Prisma.dmmf.datamodel.models.find(m => m.name === 'ApiToken')!;
    const names = model.fields.map(f => f.name);
    expect(names).toContain('tokenHash');
    expect(names).not.toContain('token');
  });
});
```

- [ ] **Step 2: Run, expect FAIL** (`cd parley-api && npm test -- schema`): models missing.

- [ ] **Step 3: Schema**

Replace the models in `prisma/schema.prisma` with:

```prisma
model User {
  id        String   @id @default(uuid())
  email     String   @unique
  name      String   @default("")
  createdAt DateTime @default(now())
  tokens    ApiToken[]
  dictionary DictionaryEntry[]
  settings  SettingsBlob[]
  history   HistoryItem[]
  tasks     Task[]

  @@map("users")
}

model ApiToken {
  id        String   @id @default(uuid())
  userId    String
  tokenHash String   @unique
  label     String   @default("")
  createdAt DateTime @default(now())
  user      User     @relation(fields: [userId], references: [id])

  @@map("api_tokens")
}

// Sync rows. `updatedAt` and `deletedAt` are client clocks in ms since the
// epoch (BigInt), not DateTime: last-writer-wins compares the numbers the
// clients wrote, and SQLite DateTime would round them.

model DictionaryEntry {
  id         String  @id
  userId     String
  word       String
  soundsLike String  @default("[]") // JSON string[]
  updatedAt  BigInt
  deletedAt  BigInt?
  user       User    @relation(fields: [userId], references: [id])

  @@index([userId, updatedAt])
  @@map("dictionary_entries")
}

model SettingsBlob {
  id        String  @id // one row per user: id == userId
  userId    String
  data      String  @default("{}") // JSON, never API keys
  updatedAt BigInt
  deletedAt BigInt?
  user      User    @relation(fields: [userId], references: [id])

  @@index([userId, updatedAt])
  @@map("settings_blobs")
}

model HistoryItem {
  id        String  @id
  userId    String
  mode      String
  text      String
  app       String  @default("")
  createdAt BigInt
  updatedAt BigInt
  deletedAt BigInt?
  user      User    @relation(fields: [userId], references: [id])

  @@index([userId, updatedAt])
  @@map("history_items")
}

model Task {
  id         String  @id
  userId     String
  title      String
  notes      String  @default("")
  dueAt      BigInt?
  rrule      String?
  priority   String  @default("medium")
  status     String  @default("open")
  sourceText String  @default("")
  updatedAt  BigInt
  deletedAt  BigInt?
  user       User    @relation(fields: [userId], references: [id])

  @@index([userId, updatedAt])
  @@map("tasks")
}
```

Fix `src/services/user.service.ts` and `src/types/user.types.ts` if they reference a required `name` (make `name` optional with default `''`). Run `npm run db:generate && npm run db:push`.

- [ ] **Step 4: Run, expect PASS**: `npm test -- schema`, then `make db-lint`.

- [ ] **Step 5: Commit**

```bash
git add parley-api/prisma parley-api/test/schema.test.ts parley-api/src
git commit -m "feat(api): schema for users, tokens and the four sync resources (parley-015)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EHEdBYfo6unHheVK8q8RUy"
```

---

### Task 4: Bearer-token auth

**Files:**
- Create: `parley-api/src/middleware/auth.middleware.ts`, `parley-api/src/services/auth.service.ts`, `parley-api/src/controllers/auth.controller.ts`, `parley-api/src/routes/auth.routes.ts`, `parley-api/src/types/auth.types.ts`
- Modify: `parley-api/src/routes/index.ts`, `parley-api/src/routes/health.routes.ts`, `parley-api/src/routes/user.routes.ts`, `parley-api/docs/CONSTRAINTS.md`
- Test: `parley-api/test/auth.test.ts`, `parley-api/test/auth.e2e.test.ts`

**Interfaces:**
- Produces: `requireAuth` middleware setting `req.userId: string`; `issueToken(email): Promise<{ token: string; userId: string }>`; `hashToken(token): string`; route `POST /api/auth/token { email } -> { token, userId }`.
- Express `Request` augmented in `src/types/auth.types.ts`:

```ts
declare global {
  namespace Express {
    interface Request { userId?: string }
  }
}
```

- [ ] **Step 1: Failing unit test** `test/auth.test.ts`:

```ts
import { describe, it, expect } from 'vitest';
import { hashToken, parseBearer } from '../src/services/auth.service';

describe('auth helpers', () => {
  it('hashes deterministically and never returns the input', () => {
    const h = hashToken('abc');
    expect(h).toBe(hashToken('abc'));
    expect(h).not.toContain('abc');
    expect(h).toHaveLength(64);
  });
  it('parses a bearer header and rejects others', () => {
    expect(parseBearer('Bearer xyz')).toBe('xyz');
    expect(parseBearer('bearer xyz')).toBe('xyz');
    expect(parseBearer('Basic xyz')).toBeNull();
    expect(parseBearer(undefined)).toBeNull();
  });
});
```

- [ ] **Step 2: Run, expect FAIL**: module not found.

- [ ] **Step 3: Implement**

`src/services/auth.service.ts`:

```ts
import { createHash, randomBytes } from 'node:crypto';
import prisma from '../config/database';
import { AppError } from '../middleware/error.middleware';

export const hashToken = (token: string): string =>
  createHash('sha256').update(token).digest('hex');

export const parseBearer = (header: string | undefined): string | null => {
  if (!header) return null;
  const m = /^bearer\s+(\S+)$/i.exec(header);
  return m ? m[1] : null;
};

export const issueToken = async (email: string, label = '') => {
  const normalized = email.trim().toLowerCase();
  const user = await prisma.user.upsert({
    where: { email: normalized },
    update: {},
    create: { email: normalized },
  });
  const token = randomBytes(32).toString('base64url');
  await prisma.apiToken.create({ data: { userId: user.id, tokenHash: hashToken(token), label } });
  return { token, userId: user.id };
};

export const userIdForToken = async (token: string): Promise<string> => {
  const row = await prisma.apiToken.findUnique({ where: { tokenHash: hashToken(token) } });
  if (!row) throw new AppError('Invalid token', 401);
  return row.userId;
};
```

`src/middleware/auth.middleware.ts`:

```ts
import { Request, Response, NextFunction } from 'express';
import { AppError } from './error.middleware';
import { parseBearer, userIdForToken } from '../services/auth.service';

export const requireAuth = async (req: Request, _res: Response, next: NextFunction) => {
  const token = parseBearer(req.headers.authorization);
  if (!token) return next(new AppError('Missing bearer token', 401));
  try {
    req.userId = await userIdForToken(token);
    next();
  } catch (err) {
    next(err);
  }
};
```

`src/types/auth.types.ts`:

```ts
import { z } from 'zod';

export const tokenRequestSchema = z.object({
  email: z.string().email(),
  label: z.string().max(80).optional(),
});
export type TokenRequestDto = z.infer<typeof tokenRequestSchema>;

declare global {
  namespace Express {
    interface Request { userId?: string }
  }
}
```

`src/controllers/auth.controller.ts`:

```ts
import { Request, Response } from 'express';
import { asyncHandler } from '../middleware/error.middleware';
import * as authService from '../services/auth.service';

export const token = asyncHandler(async (req: Request, res: Response) => {
  const result = await authService.issueToken(req.body.email, req.body.label);
  res.status(201).json(result);
});
```

`src/routes/auth.routes.ts`:

```ts
import { Router } from 'express';
import { token } from '../controllers/auth.controller';
import { validate } from '../middleware/validate.middleware';
import { tokenRequestSchema } from '../types/auth.types';

const router = Router();
// Deliberately without requireAuth: this is how a client gets its first token.
router.post('/token', validate(tokenRequestSchema), token);
export default router;
```

`src/routes/index.ts`: add `import authRoutes from './auth.routes';` and `router.use('/auth', authRoutes);`.

`src/routes/health.routes.ts`: add a top comment `// Public on purpose, no requireAuth: load balancers probe it unauthenticated.`
`src/routes/user.routes.ts`: `import { requireAuth } from '../middleware/auth.middleware';` and `router.use(requireAuth);` before the routes.

`docs/CONSTRAINTS.md` `## Auth` section replaced with:

```markdown
## Auth

Bearer tokens. `POST /api/auth/token` takes an email and returns a long-lived
token; the client stores it and sends `Authorization: Bearer <token>`.
`requireAuth` (src/middleware/auth.middleware.ts) resolves it to `req.userId`.
Only the SHA-256 hash of a token is stored. Health and the token route are
public; every other route file names `requireAuth`.
```

- [ ] **Step 4: e2e test** `test/auth.e2e.test.ts`:

```ts
import { describe, it, expect } from 'vitest';
import request from 'supertest';
import app from '../src/app';

const dbDescribe = process.env.RUN_DB_TESTS ? describe : describe.skip;

dbDescribe('auth (e2e)', () => {
  it('issues a token and gates /api/users with it', async () => {
    const issued = await request(app).post('/api/auth/token').send({ email: 'a@example.com' });
    expect(issued.status).toBe(201);
    const { token } = issued.body.data;
    expect(token).toMatch(/^[A-Za-z0-9_-]{40,}$/);

    expect((await request(app).get('/api/users')).status).toBe(401);
    const ok = await request(app).get('/api/users').set('Authorization', `Bearer ${token}`);
    expect(ok.status).toBe(200);
    const bad = await request(app).get('/api/users').set('Authorization', 'Bearer nope');
    expect(bad.status).toBe(401);
  });
  it('rejects a malformed email', async () => {
    const res = await request(app).post('/api/auth/token').send({ email: 'nope' });
    expect(res.status).toBe(400);
  });
});
```

- [ ] **Step 5: Run** `make check` in `parley-api`: expect exit 0, including `api-lint` (A4 now sees the auth layer and every routes file names it).

- [ ] **Step 6: Commit**

```bash
git add parley-api
git commit -m "feat(api): bearer-token auth with hashed tokens (parley-015)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EHEdBYfo6unHheVK8q8RUy"
```

---

### Task 5: The merge rule as a pure function

**Files:**
- Create: `parley-api/src/services/merge.ts`
- Test: `parley-api/test/merge.test.ts`

**Interfaces:**
- Produces:

```ts
export interface SyncRow { id: string; updatedAt: number; deletedAt?: number | null }
export const MAX_FUTURE_MS = 5 * 60 * 1000;
export function clampClock<T extends SyncRow>(row: T, now: number): T
export function mergeRow<T extends SyncRow>(existing: T | null, incoming: T, now: number): { winner: T; changed: boolean }
```

- [ ] **Step 1: Failing test** `test/merge.test.ts`:

```ts
import { describe, it, expect } from 'vitest';
import { mergeRow, clampClock, MAX_FUTURE_MS } from '../src/services/merge';

const now = 1_000_000;
const row = (updatedAt: number, extra: Record<string, unknown> = {}) =>
  ({ id: 'r1', updatedAt, deletedAt: null, ...extra });

describe('mergeRow', () => {
  it('inserts when nothing exists', () => {
    const r = mergeRow(null, row(10), now);
    expect(r).toEqual({ winner: row(10), changed: true });
  });
  it('newer incoming wins', () => {
    const r = mergeRow(row(10, { v: 'old' }), row(20, { v: 'new' }), now);
    expect(r.winner).toMatchObject({ v: 'new' });
    expect(r.changed).toBe(true);
  });
  it('older incoming loses and reports no change', () => {
    const r = mergeRow(row(20, { v: 'kept' }), row(10, { v: 'stale' }), now);
    expect(r.winner).toMatchObject({ v: 'kept' });
    expect(r.changed).toBe(false);
  });
  it('equal timestamps keep the existing row', () => {
    const r = mergeRow(row(10, { v: 'a' }), row(10, { v: 'b' }), now);
    expect(r.winner).toMatchObject({ v: 'a' });
    expect(r.changed).toBe(false);
  });
  it('a newer tombstone beats a live row', () => {
    const r = mergeRow(row(10), row(20, { deletedAt: 20 }), now);
    expect(r.winner.deletedAt).toBe(20);
  });
  it('clamps a clock far in the future', () => {
    const r = clampClock(row(now + MAX_FUTURE_MS * 10), now);
    expect(r.updatedAt).toBe(now + MAX_FUTURE_MS);
  });
});
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement** `src/services/merge.ts`:

```ts
export interface SyncRow {
  id: string;
  updatedAt: number;
  deletedAt?: number | null;
}

/** A client clock may run ahead; beyond this it would freeze the row for every other client. */
export const MAX_FUTURE_MS = 5 * 60 * 1000;

export function clampClock<T extends SyncRow>(row: T, now: number): T {
  const ceiling = now + MAX_FUTURE_MS;
  const updatedAt = Math.min(row.updatedAt, ceiling);
  const deletedAt = row.deletedAt == null ? row.deletedAt : Math.min(row.deletedAt, ceiling);
  return { ...row, updatedAt, deletedAt };
}

/** Last writer wins by `updatedAt`. Ties keep what the server has. */
export function mergeRow<T extends SyncRow>(
  existing: T | null,
  incoming: T,
  now: number,
): { winner: T; changed: boolean } {
  const candidate = clampClock(incoming, now);
  if (!existing) return { winner: candidate, changed: true };
  if (candidate.updatedAt > existing.updatedAt) return { winner: candidate, changed: true };
  return { winner: existing, changed: false };
}
```

- [ ] **Step 4: Run, expect PASS.**

- [ ] **Step 5: Commit**

```bash
git add parley-api/src/services/merge.ts parley-api/test/merge.test.ts
git commit -m "feat(api): last-writer-wins merge rule (parley-015)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EHEdBYfo6unHheVK8q8RUy"
```

---

### Task 6: Generic sync routes for the four resources

**Files:**
- Create: `parley-api/src/types/sync.types.ts`, `parley-api/src/services/sync.service.ts`, `parley-api/src/controllers/sync.controller.ts`, `parley-api/src/routes/sync.routes.ts`
- Modify: `parley-api/src/routes/index.ts`, `parley-api/src/app.ts` (endpoint map), `parley-api/docs/API_CONTRACT.md`
- Test: `parley-api/test/sync.e2e.test.ts`, `parley-api/test/sync.types.test.ts`

**Interfaces:**
- Routes, each under `requireAuth`:
  - `GET /api/{dictionary|settings|history|tasks}?since=<ms>` returns `{ data: Row[], meta: { now: number } }`. `since` defaults to 0. Includes tombstones.
  - `PUT /api/{resource}` body `{ items: Row[] }` (max 500) returns `{ data: Row[] }` = the winning rows for every submitted id, plus `meta.now`.
- Row shapes (wire, JSON numbers for timestamps):

```ts
dictionary: { id, word, soundsLike: string[], updatedAt, deletedAt? }
settings:   { id, data: Record<string, unknown>, updatedAt, deletedAt? }   // id is ignored and set to userId
history:    { id, mode, text, app, createdAt, updatedAt, deletedAt? }
tasks:      { id, title, notes, dueAt?, rrule?, priority, status, sourceText, updatedAt, deletedAt? }
```

- [ ] **Step 1: Failing types test** `test/sync.types.test.ts`:

```ts
import { describe, it, expect } from 'vitest';
import { SYNC_RESOURCES, rowSchemaFor, pushSchemaFor } from '../src/types/sync.types';

describe('sync schemas', () => {
  it('names the four resources', () => {
    expect(SYNC_RESOURCES).toEqual(['dictionary', 'settings', 'history', 'tasks']);
  });
  it('rejects API keys inside the settings blob', () => {
    const r = rowSchemaFor('settings').safeParse({
      id: 'x', updatedAt: 1, data: { apiKey: 'gsk_123' },
    });
    expect(r.success).toBe(false);
  });
  it('caps a push at 500 items', () => {
    const items = Array.from({ length: 501 }, (_, i) => ({ id: `d${i}`, word: 'w', soundsLike: [], updatedAt: 1 }));
    expect(pushSchemaFor('dictionary').safeParse({ items }).success).toBe(false);
  });
});
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Types** `src/types/sync.types.ts`:

```ts
import { z } from 'zod';

export const SYNC_RESOURCES = ['dictionary', 'settings', 'history', 'tasks'] as const;
export type SyncResource = (typeof SYNC_RESOURCES)[number];

const ms = z.number().int().nonnegative();
const base = { id: z.string().min(1).max(64), updatedAt: ms, deletedAt: ms.nullable().optional() };

const FORBIDDEN_SETTINGS_KEYS = /key|token|secret/i;

export const dictionaryRow = z.object({
  ...base,
  word: z.string().min(1).max(60),
  soundsLike: z.array(z.string().min(1).max(60)).max(8),
});
export const settingsRow = z.object({
  ...base,
  data: z.record(z.unknown()).refine(
    d => Object.keys(d).every(k => !FORBIDDEN_SETTINGS_KEYS.test(k)),
    'settings must not carry keys, tokens or secrets',
  ),
});
export const historyRow = z.object({
  ...base,
  mode: z.enum(['dictate', 'edit', 'explain', 'act']),
  text: z.string().max(20_000),
  app: z.string().max(200).default(''),
  createdAt: ms,
});
export const taskRow = z.object({
  ...base,
  title: z.string().min(1).max(500),
  notes: z.string().max(20_000).default(''),
  dueAt: ms.nullable().optional(),
  rrule: z.string().max(500).nullable().optional(),
  priority: z.enum(['low', 'medium', 'high']).default('medium'),
  status: z.enum(['open', 'done', 'snoozed']).default('open'),
  sourceText: z.string().max(5_000).default(''),
});

const rowSchemas = { dictionary: dictionaryRow, settings: settingsRow, history: historyRow, tasks: taskRow };
export const rowSchemaFor = (r: SyncResource) => rowSchemas[r];
export const pushSchemaFor = (r: SyncResource) => z.object({ items: z.array(rowSchemas[r]).max(500) });

export type DictionaryRow = z.infer<typeof dictionaryRow>;
export type SettingsRow = z.infer<typeof settingsRow>;
export type HistoryRow = z.infer<typeof historyRow>;
export type TaskRow = z.infer<typeof taskRow>;
export type AnyRow = DictionaryRow | SettingsRow | HistoryRow | TaskRow;
```

- [ ] **Step 4: Run types test, expect PASS.**

- [ ] **Step 5: Failing e2e** `test/sync.e2e.test.ts`:

```ts
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
```

- [ ] **Step 6: Run, expect FAIL** (`make e2e`): 404s.

- [ ] **Step 7: Service** `src/services/sync.service.ts`:

```ts
import prisma from '../config/database';
import { mergeRow, type SyncRow } from './merge';
import type { SyncResource, AnyRow, DictionaryRow, SettingsRow, HistoryRow, TaskRow } from '../types/sync.types';

type DbRow = Record<string, unknown> & { id: string; userId: string; updatedAt: bigint; deletedAt: bigint | null };

const big = (n: number | null | undefined) => (n == null ? null : BigInt(n));
const num = (b: bigint | null | undefined) => (b == null ? null : Number(b));

/** Wire row -> columns. Strips `id` for settings (one row per user). */
function toDb(resource: SyncResource, userId: string, row: AnyRow) {
  const common = { userId, updatedAt: BigInt(row.updatedAt), deletedAt: big(row.deletedAt) };
  switch (resource) {
    case 'dictionary': {
      const r = row as DictionaryRow;
      return { id: r.id, ...common, word: r.word, soundsLike: JSON.stringify(r.soundsLike) };
    }
    case 'settings': {
      const r = row as SettingsRow;
      return { id: userId, ...common, data: JSON.stringify(r.data) };
    }
    case 'history': {
      const r = row as HistoryRow;
      return { id: r.id, ...common, mode: r.mode, text: r.text, app: r.app, createdAt: BigInt(r.createdAt) };
    }
    case 'tasks': {
      const r = row as TaskRow;
      return {
        id: r.id, ...common, title: r.title, notes: r.notes, dueAt: big(r.dueAt), rrule: r.rrule ?? null,
        priority: r.priority, status: r.status, sourceText: r.sourceText,
      };
    }
  }
}

/** Columns -> wire row. */
function toWire(resource: SyncResource, row: DbRow): AnyRow {
  const common = { id: row.id, updatedAt: Number(row.updatedAt), deletedAt: num(row.deletedAt) };
  switch (resource) {
    case 'dictionary':
      return { ...common, word: row.word as string, soundsLike: JSON.parse(row.soundsLike as string) };
    case 'settings':
      return { ...common, data: JSON.parse(row.data as string) };
    case 'history':
      return {
        ...common, mode: row.mode as HistoryRow['mode'], text: row.text as string,
        app: row.app as string, createdAt: Number(row.createdAt),
      };
    case 'tasks':
      return {
        ...common, title: row.title as string, notes: row.notes as string, dueAt: num(row.dueAt as bigint | null),
        rrule: (row.rrule as string | null) ?? null, priority: row.priority as TaskRow['priority'],
        status: row.status as TaskRow['status'], sourceText: row.sourceText as string,
      };
  }
}

function table(resource: SyncResource) {
  // Prisma delegates share the findUnique/findMany/upsert shape used below.
  const map = {
    dictionary: prisma.dictionaryEntry,
    settings: prisma.settingsBlob,
    history: prisma.historyItem,
    tasks: prisma.task,
  } as const;
  return map[resource] as unknown as {
    findMany(args: unknown): Promise<DbRow[]>;
    findUnique(args: unknown): Promise<DbRow | null>;
    upsert(args: unknown): Promise<DbRow>;
  };
}

export const pull = async (resource: SyncResource, userId: string, since: number) => {
  const rows = await table(resource).findMany({
    where: { userId, updatedAt: { gt: BigInt(since) } },
    orderBy: { updatedAt: 'asc' },
    take: 1000,
  });
  return rows.map(r => toWire(resource, r));
};

export const push = async (resource: SyncResource, userId: string, items: AnyRow[], now = Date.now()) => {
  const winners: AnyRow[] = [];
  for (const item of items) {
    const data = toDb(resource, userId, item);
    const existing = await table(resource).findUnique({ where: { id: data.id } });
    if (existing && existing.userId !== userId) {
      // An id collision across users: ignore the foreign row, treat as insert under a scoped id.
      continue;
    }
    const current: SyncRow | null = existing
      ? { id: existing.id, updatedAt: Number(existing.updatedAt), deletedAt: num(existing.deletedAt) }
      : null;
    const incoming: SyncRow = { id: data.id, updatedAt: item.updatedAt, deletedAt: item.deletedAt ?? null };
    const { winner, changed } = mergeRow(current, incoming, now);
    if (changed) {
      const clamped = { ...data, updatedAt: BigInt(winner.updatedAt), deletedAt: big(winner.deletedAt) };
      const saved = await table(resource).upsert({ where: { id: data.id }, create: clamped, update: clamped });
      winners.push(toWire(resource, saved));
    } else if (existing) {
      winners.push(toWire(resource, existing));
    }
  }
  return winners;
};
```

Note for the implementer: dictionary, history and task ids are client UUIDs, so cross-user collisions are astronomically unlikely; the `continue` only prevents overwriting a stranger's row.

- [ ] **Step 8: Controller and routes**

`src/controllers/sync.controller.ts`:

```ts
import { Request, Response } from 'express';
import { asyncHandler, AppError } from '../middleware/error.middleware';
import * as syncService from '../services/sync.service';
import type { SyncResource } from '../types/sync.types';

export const pullFor = (resource: SyncResource) =>
  asyncHandler(async (req: Request, res: Response) => {
    const raw = req.query.since;
    const since = raw === undefined ? 0 : Number(raw);
    if (!Number.isFinite(since) || since < 0) throw new AppError('since must be a non-negative number', 400);
    const data = await syncService.pull(resource, req.userId!, since);
    res.status(200).json({ data, meta: { now: Date.now() } });
  });

export const pushFor = (resource: SyncResource) =>
  asyncHandler(async (req: Request, res: Response) => {
    const now = Date.now();
    const data = await syncService.push(resource, req.userId!, req.body.items, now);
    res.status(200).json({ data, meta: { now } });
  });
```

If `api-lint` A5 flags the explicit `{ data, meta }` here, move the `now` into `res.locals.meta` handling in `transform.middleware.ts` instead: have the transform read `res.locals.meta` and spread it into `meta`. Then controllers call `res.locals.meta = { now }; res.json(data)`. Pick whichever passes A5; the e2e asserts only the wire shape.

`src/routes/sync.routes.ts`:

```ts
import { Router } from 'express';
import { requireAuth } from '../middleware/auth.middleware';
import { validate } from '../middleware/validate.middleware';
import { pullFor, pushFor } from '../controllers/sync.controller';
import { pushSchemaFor, type SyncResource } from '../types/sync.types';

/** One router shape for every resource: GET ?since, PUT { items }. */
export const syncRouter = (resource: SyncResource) => {
  const router = Router();
  router.use(requireAuth);
  router.get('/', pullFor(resource));
  router.put('/', validate(pushSchemaFor(resource)), pushFor(resource));
  return router;
};
```

`src/routes/index.ts`: add

```ts
import { syncRouter } from './sync.routes';
import { SYNC_RESOURCES } from '../types/sync.types';
for (const resource of SYNC_RESOURCES) router.use(`/${resource}`, syncRouter(resource));
```

`src/app.ts` endpoint map: add `dictionary: '/api/dictionary', settings: '/api/settings', history: '/api/history', tasks: '/api/tasks', auth: '/api/auth/token'`. Update `test/health.test.ts` `toMatchObject` accordingly.

`docs/API_CONTRACT.md`: add a "Sync" section listing the two verbs, the `since` query, the 500-item cap, the merge rule and the four row shapes from the Interfaces block above.

- [ ] **Step 9: Run** `make check` in `parley-api`: expect exit 0.

- [ ] **Step 10: Commit**

```bash
git add parley-api
git commit -m "feat(api): generic sync routes for dictionary, settings, history and tasks (parley-015)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EHEdBYfo6unHheVK8q8RUy"
```

---

### Task 7: Desktop settings fields and token storage for sync

**Files:**
- Modify: `electron/types.ts:30-91`, `electron/settings-store.ts`, `electron/__tests__/settings-store.test.ts`

**Interfaces:**
- `Settings` gains `syncEnabled: boolean` (default `false`), `syncUrl: string` (default `'http://localhost:3100'`), `syncEmail: string` (default `''`).
- `SettingsView` gains `hasSyncToken: boolean`, `syncLastAt: number` (0 = never), `syncLastError: string`.
- `SettingsStore` gains `getSyncToken(): string | null`, `setSyncToken(token: string | null): void`, `recordSync(result: { at: number; error?: string }): void`, `settingsUpdatedAt(): number` (bumped to `Date.now()` by every `update()` that changed something), `getSyncCursor(): number`, `setSyncCursor(value: number): void`.
- File envelope gains `syncTokenEncrypted?: string`, `syncLastAt?: number`, `syncLastError?: string`, `settingsUpdatedAt?: number`, `syncCursor?: number`.

- [ ] **Step 1: Failing tests** appended to `electron/__tests__/settings-store.test.ts`:

```ts
  it('stores the sync token encrypted and reports it in the view', () => {
    const store = createSettingsStore({ dir, crypto });
    expect(store.view().hasSyncToken).toBe(false);
    store.setSyncToken('tok_1');
    expect(store.getSyncToken()).toBe('tok_1');
    expect(readFileSync(path.join(dir, 'settings.json'), 'utf8')).not.toContain('tok_1');
    expect(createSettingsStore({ dir, crypto }).view().hasSyncToken).toBe(true);
    store.setSyncToken(null);
    expect(store.getSyncToken()).toBeNull();
  });

  it('keeps sync url, email and enabled, and drops a bad url', () => {
    const store = createSettingsStore({ dir, crypto });
    store.update({ syncUrl: 'https://sync.example.com', syncEmail: 'me@example.com', syncEnabled: true });
    expect(store.get()).toMatchObject({ syncUrl: 'https://sync.example.com', syncEmail: 'me@example.com', syncEnabled: true });
    store.update({ syncUrl: 'ftp://nope' as never });
    expect(store.get().syncUrl).toBe('https://sync.example.com');
  });

  it('records the last sync outcome outside any patch', () => {
    const store = createSettingsStore({ dir, crypto });
    store.recordSync({ at: 1234, error: 'offline' });
    const view = createSettingsStore({ dir, crypto }).view();
    expect(view.syncLastAt).toBe(1234);
    expect(view.syncLastError).toBe('offline');
    store.update({ syncLastAt: 9 } as never);
    expect(store.view().syncLastAt).toBe(1234);
  });

  it('stamps settingsUpdatedAt on a real change and persists the sync cursor', () => {
    const store = createSettingsStore({ dir, crypto });
    expect(store.settingsUpdatedAt()).toBe(0);
    const before = Date.now();
    store.update({ tickSound: false });
    expect(store.settingsUpdatedAt()).toBeGreaterThanOrEqual(before);
    store.setSyncCursor(5);
    expect(createSettingsStore({ dir, crypto }).getSyncCursor()).toBe(5);
  });
```

- [ ] **Step 2: Run** `npm test -- settings-store`: expect FAIL on the new fields.

- [ ] **Step 3: Implement**

`electron/types.ts`: add to `Settings` after `agentAutoStart`:

```ts
  /** Push the dictionary and settings to a Parley API and pull what other devices wrote. */
  syncEnabled: boolean;
  /** Where the sync API answers. http(s) only. */
  syncUrl: string;
  /** The account the token was issued to. Shown, never used as a secret. */
  syncEmail: string;
```

`DEFAULT_SETTINGS`: `syncEnabled: false, syncUrl: 'http://localhost:3100', syncEmail: ''`.

`SettingsView`: add `hasSyncToken: boolean; syncLastAt: number; syncLastError: string;`.

`electron/settings-store.ts`: extend `FileShape` with `syncTokenEncrypted?: string; syncLastAt?: number; syncLastError?: string;`. In the patch cleaner, accept `syncEnabled` when boolean, `syncEmail` when string up to 200 chars, `syncUrl` when `new URL(v).protocol` is `http:` or `https:` and length under 200 (copy the agent URL validation that already exists in this file). Add the three store methods using the same encrypt/decrypt helpers the Groq key uses; `setSyncToken(null)` deletes `syncTokenEncrypted`. `view()` returns `hasSyncToken`, `syncLastAt ?? 0`, `syncLastError ?? ''`. Keep the sync fields out of the Settings tab stories' `settled` fixture only if the type forces it; otherwise add defaults there.

- [ ] **Step 4: Run** `npm test -- settings-store` and `npm run type-check`: expect PASS. Fix any story or test fixture that spreads a full `Settings`.

- [ ] **Step 5: Commit**

```bash
git add electron/types.ts electron/settings-store.ts electron/__tests__/settings-store.test.ts src
git commit -m "feat: sync settings fields and encrypted sync token (parley-015)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EHEdBYfo6unHheVK8q8RUy"
```

---

### Task 8: Dictionary store change tracking and tombstones

**Files:**
- Modify: `electron/dictionary.ts:7-16`, `electron/dictionary-store.ts`, `electron/__tests__/dictionary-store.test.ts`

**Interfaces:**
- `DictionaryEntry` gains `updatedAt: number` (ms). Entries loaded from a file without it get `updatedAt = lastUsedAt`.
- `DictionaryStore` gains:
  - `changedSince(since: number): { entries: DictionaryEntry[]; removed: { id: string; deletedAt: number }[] }`
  - `applyRemote(rows: { id: string; word: string; soundsLike: string[]; updatedAt: number; deletedAt: number | null }[]): void` which applies last-writer-wins locally: a newer remote row replaces or deletes, an older one is ignored.
- Tombstones persist in `dictionary.json` under `removed`, capped at 500, oldest dropped.
- `upsert` and `remove` stamp `updatedAt = Date.now()` (injectable `now` in the factory options for tests).

- [ ] **Step 1: Failing tests** appended to `electron/__tests__/dictionary-store.test.ts` (reuse the file's existing `createDictionaryStore({ dir })` setup; add a `now` option):

```ts
  it('stamps updatedAt and reports changes since a time', () => {
    let clock = 100;
    const store = createDictionaryStore({ dir, now: () => clock });
    const a = store.upsert({ word: 'MiniMax', soundsLike: ['mini max'] })!;
    clock = 200;
    const b = store.upsert({ word: 'Groq', soundsLike: [] })!;
    expect(a.updatedAt).toBe(100);
    expect(store.changedSince(150).entries.map(e => e.id)).toEqual([b.id]);
    clock = 300;
    store.remove(a.id);
    expect(store.changedSince(250).removed).toEqual([{ id: a.id, deletedAt: 300 }]);
    expect(store.list().map(e => e.id)).toEqual([b.id]);
  });

  it('applies newer remote rows and ignores older ones', () => {
    let clock = 100;
    const store = createDictionaryStore({ dir, now: () => clock });
    const a = store.upsert({ word: 'MiniMax', soundsLike: [] })!;
    store.applyRemote([
      { id: a.id, word: 'MiniMax', soundsLike: ['mini max'], updatedAt: 150, deletedAt: null },
      { id: 'remote-1', word: 'Deepgram', soundsLike: [], updatedAt: 120, deletedAt: null },
      { id: a.id, word: 'Stale', soundsLike: [], updatedAt: 90, deletedAt: null },
    ]);
    const byId = Object.fromEntries(store.list().map(e => [e.id, e]));
    expect(byId[a.id].soundsLike).toEqual(['mini max']);
    expect(byId['remote-1'].word).toBe('Deepgram');
    store.applyRemote([{ id: 'remote-1', word: 'Deepgram', soundsLike: [], updatedAt: 130, deletedAt: 130 }]);
    expect(store.list().some(e => e.id === 'remote-1')).toBe(false);
    expect(createDictionaryStore({ dir }).changedSince(0).removed.some(r => r.id === 'remote-1')).toBe(true);
  });

  it('migrates an entry without updatedAt from lastUsedAt', () => {
    writeFileSync(path.join(dir, 'dictionary.json'), JSON.stringify({
      entries: [{ id: 'old', word: 'Old', soundsLike: [], uses: 1, lastUsedAt: 42 }],
    }));
    expect(createDictionaryStore({ dir }).list()[0].updatedAt).toBe(42);
  });
```

- [ ] **Step 2: Run** `npm test -- dictionary-store`: expect FAIL.

- [ ] **Step 3: Implement**

In `electron/dictionary.ts` add `updatedAt: number;` with the doc comment `/** Milliseconds since the epoch of the last edit; what sync compares. */`.

In `electron/dictionary-store.ts`:
- factory options gain `now?: () => number` (default `Date.now`).
- `cleanEntry` sets `updatedAt: typeof raw.updatedAt === 'number' ? raw.updatedAt : lastUsedAt`.
- file shape gains `removed?: { id: string; deletedAt: number }[]`; clean it the same way (string id, finite number), cap at 500 keeping the newest.
- `upsert` sets `updatedAt: now()` on the written entry; `remove(id)` pushes `{ id, deletedAt: now() }` onto `removed` and drops any older tombstone for the same id.
- `changedSince(since)` filters entries by `updatedAt > since` and tombstones by `deletedAt > since`.
- `applyRemote(rows)`: for each row find local entry and local tombstone; local stamp = max(entry.updatedAt, tombstone.deletedAt); skip when `row.updatedAt <= localStamp`; else if `row.deletedAt != null` delete the entry and record the tombstone with `deletedAt: row.deletedAt`; else write the entry with `uses` and `lastUsedAt` preserved from local when present, `updatedAt: row.updatedAt`, and drop its tombstone. Save once at the end.
- Wherever `dictionary.json` is written, keep `MAX_ENTRIES` enforcement; a remote row that would exceed the cap is skipped (the server is the store of record).

Update any other test in the file that compares a full entry with `toEqual` to include `updatedAt`.

- [ ] **Step 4: Run** `npm test -- dictionary` and `npm run type-check`: expect PASS.

- [ ] **Step 5: Commit**

```bash
git add electron/dictionary.ts electron/dictionary-store.ts electron/__tests__
git commit -m "feat: dictionary store tracks edits and tombstones for sync (parley-015)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EHEdBYfo6unHheVK8q8RUy"
```

---

### Task 9: Desktop sync client and engine

**Files:**
- Create: `electron/sync/client.ts`, `electron/sync/engine.ts`, `electron/sync/__tests__/client.test.ts`, `electron/sync/__tests__/engine.test.ts`

**Interfaces:**
- `client.ts`:

```ts
export interface SyncClientOptions { baseUrl: string; token: string | null; fetch?: typeof fetch }
export interface SyncClient {
  signIn(email: string): Promise<{ token: string }>;                 // POST /api/auth/token
  pull<T>(resource: string, since: number): Promise<{ rows: T[]; now: number }>;
  push<T>(resource: string, items: T[]): Promise<{ rows: T[]; now: number }>;
}
export function createSyncClient(opts: SyncClientOptions): SyncClient
export class SyncHttpError extends Error { status: number }
```

- `engine.ts`:

```ts
export interface SyncDeps {
  client: SyncClient;
  dictionary: Pick<DictionaryStore, 'changedSince' | 'applyRemote' | 'list'>;
  settings: Pick<SettingsStore, 'get' | 'update' | 'recordSync'>;
  cursor: { get(): number; set(value: number): void };   // last successful pull `now`, persisted by main in settings.json envelope via recordSync's `at`
  now?: () => number;
}
export interface SyncOutcome { ok: boolean; pushed: number; pulled: number; message: string; at: number }
export function createSyncEngine(deps: SyncDeps): { syncNow(): Promise<SyncOutcome> }
```

Settings blob pushed = the `Settings` object minus `syncEnabled`, `syncUrl`, `syncEmail` (device-local), minus nothing else; `agentUrl` stays since the API forbids only key/token/secret names. Settings `updatedAt` on the wire = `settings.settingsUpdatedAt()` from Task 7.

- [ ] **Step 1: Failing client test** `electron/sync/__tests__/client.test.ts`:

```ts
import { describe, expect, it, vi } from 'vitest';

import { createSyncClient, SyncHttpError } from '../client';

const json = (status: number, body: unknown) =>
  Promise.resolve(new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } }));

describe('sync client', () => {
  it('signs in and sends the bearer token afterwards', async () => {
    const fetchMock = vi.fn()
      .mockImplementationOnce(() => json(201, { data: { token: 'tok', userId: 'u' }, meta: {} }))
      .mockImplementationOnce(() => json(200, { data: [{ id: 'd1' }], meta: { now: 5 } }));
    const client = createSyncClient({ baseUrl: 'http://x', token: null, fetch: fetchMock as never });
    expect(await client.signIn('me@example.com')).toEqual({ token: 'tok' });
    const pulled = await createSyncClient({ baseUrl: 'http://x/', token: 'tok', fetch: fetchMock as never })
      .pull('dictionary', 3);
    expect(pulled).toEqual({ rows: [{ id: 'd1' }], now: 5 });
    const [url, init] = fetchMock.mock.calls[1];
    expect(url).toBe('http://x/api/dictionary?since=3');
    expect((init.headers as Record<string, string>).Authorization).toBe('Bearer tok');
  });

  it('throws SyncHttpError with the status on a non-2xx', async () => {
    const fetchMock = vi.fn(() => json(401, { status: 'error', message: 'Invalid token' }));
    const client = createSyncClient({ baseUrl: 'http://x', token: 'bad', fetch: fetchMock as never });
    await expect(client.pull('tasks', 0)).rejects.toMatchObject({ status: 401, message: 'Invalid token' });
    await expect(client.pull('tasks', 0)).rejects.toBeInstanceOf(SyncHttpError);
  });
});
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement** `electron/sync/client.ts`:

```ts
export interface SyncClientOptions {
  baseUrl: string;
  token: string | null;
  fetch?: typeof fetch;
}

export class SyncHttpError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

export interface SyncClient {
  signIn(email: string): Promise<{ token: string }>;
  pull<T>(resource: string, since: number): Promise<{ rows: T[]; now: number }>;
  push<T>(resource: string, items: T[]): Promise<{ rows: T[]; now: number }>;
}

/** Thin HTTP over the API's `{ data, meta }` envelope. No retries: the engine decides. */
export function createSyncClient({ baseUrl, token, fetch: doFetch = fetch }: SyncClientOptions): SyncClient {
  const root = baseUrl.replace(/\/+$/, '');

  async function call<T>(method: string, path: string, body?: unknown): Promise<{ data: T; meta: { now?: number } }> {
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (token) headers.Authorization = `Bearer ${token}`;
    const res = await doFetch(`${root}${path}`, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const parsed = (await res.json().catch(() => ({}))) as { data?: T; meta?: { now?: number }; message?: string };
    if (!res.ok) throw new SyncHttpError(res.status, parsed.message ?? `HTTP ${res.status}`);
    return { data: parsed.data as T, meta: parsed.meta ?? {} };
  }

  return {
    async signIn(email) {
      const { data } = await call<{ token: string }>('POST', '/api/auth/token', { email, label: 'parley-desktop' });
      return { token: data.token };
    },
    async pull(resource, since) {
      const { data, meta } = await call<unknown[]>('GET', `/api/${resource}?since=${since}`);
      return { rows: data as never, now: meta.now ?? Date.now() };
    },
    async push(resource, items) {
      const { data, meta } = await call<unknown[]>('PUT', `/api/${resource}`, { items });
      return { rows: data as never, now: meta.now ?? Date.now() };
    },
  };
}
```

- [ ] **Step 4: Run client test, expect PASS.**

- [ ] **Step 5: Failing engine test** `electron/sync/__tests__/engine.test.ts`:

```ts
import { describe, expect, it, vi } from 'vitest';

import { DEFAULT_SETTINGS } from '../../types';
import { createSyncEngine } from '../engine';

function fakeClient() {
  return {
    signIn: vi.fn(),
    pull: vi.fn(async (resource: string) =>
      resource === 'dictionary'
        ? { rows: [{ id: 'r1', word: 'Remote', soundsLike: [], updatedAt: 50, deletedAt: null }], now: 1000 }
        : { rows: [], now: 1000 }),
    push: vi.fn(async (_r: string, items: unknown[]) => ({ rows: items, now: 1000 })),
  };
}

function fakeDictionary() {
  const applied: unknown[] = [];
  return {
    applied,
    list: () => [],
    changedSince: vi.fn(() => ({
      entries: [{ id: 'l1', word: 'Local', soundsLike: ['lo cal'], uses: 0, lastUsedAt: 0, updatedAt: 70 }],
      removed: [{ id: 'gone', deletedAt: 80 }],
    })),
    applyRemote: vi.fn((rows: unknown[]) => applied.push(...rows)),
  };
}

function fakeSettings() {
  let current = { ...DEFAULT_SETTINGS, syncEnabled: true, syncUrl: 'http://x', syncEmail: 'a@b.c', tickSound: false };
  const recorded: unknown[] = [];
  return {
    recorded,
    get: () => current,
    update: vi.fn((patch: object) => (current = { ...current, ...patch })),
    recordSync: vi.fn((r: unknown) => recorded.push(r)),
    settingsUpdatedAt: () => 60,
  };
}

describe('sync engine', () => {
  it('pushes local changes since the cursor, pulls remote ones, advances the cursor', async () => {
    const client = fakeClient();
    const dictionary = fakeDictionary();
    const settings = fakeSettings();
    let cursor = 10;
    const engine = createSyncEngine({
      client, dictionary, settings,
      cursor: { get: () => cursor, set: v => (cursor = v) },
      now: () => 999,
    });
    const outcome = await engine.syncNow();

    expect(outcome.ok).toBe(true);
    expect(dictionary.changedSince).toHaveBeenCalledWith(10);
    const dictPush = client.push.mock.calls.find(c => c[0] === 'dictionary')!;
    expect(dictPush[1]).toEqual([
      { id: 'l1', word: 'Local', soundsLike: ['lo cal'], updatedAt: 70, deletedAt: null },
      { id: 'gone', word: '', soundsLike: [], updatedAt: 80, deletedAt: 80 },
    ]);
    const settingsPush = client.push.mock.calls.find(c => c[0] === 'settings')!;
    expect(settingsPush[1][0]).toMatchObject({ updatedAt: 60, data: { tickSound: false } });
    expect(settingsPush[1][0].data).not.toHaveProperty('syncUrl');
    expect(dictionary.applied).toEqual([{ id: 'r1', word: 'Remote', soundsLike: [], updatedAt: 50, deletedAt: null }]);
    expect(cursor).toBe(1000);
    expect(settings.recordSync).toHaveBeenCalledWith({ at: 999 });
  });

  it('applies a newer remote settings blob and ignores an older one', async () => {
    const client = fakeClient();
    client.pull.mockImplementation(async (resource: string) =>
      resource === 'settings'
        ? { rows: [{ id: 'u', data: { tickSound: true, apiKey: 'x', syncUrl: 'evil' }, updatedAt: 90, deletedAt: null }], now: 1 }
        : { rows: [], now: 1 });
    const settings = fakeSettings();
    const engine = createSyncEngine({ client, dictionary: fakeDictionary(), settings, cursor: { get: () => 0, set: () => {} } });
    await engine.syncNow();
    expect(settings.update).toHaveBeenCalledWith({ tickSound: true });
  });

  it('never throws: a down server becomes a recorded error', async () => {
    const client = fakeClient();
    client.pull.mockRejectedValue(new TypeError('fetch failed'));
    const settings = fakeSettings();
    const engine = createSyncEngine({ client, dictionary: fakeDictionary(), settings, cursor: { get: () => 0, set: () => {} } });
    const outcome = await engine.syncNow();
    expect(outcome.ok).toBe(false);
    expect(outcome.message).toContain('fetch failed');
    expect(settings.recordSync).toHaveBeenCalledWith(expect.objectContaining({ error: expect.stringContaining('fetch failed') }));
  });
});
```

- [ ] **Step 6: Run, expect FAIL.**

- [ ] **Step 7: Implement** `electron/sync/engine.ts`:

```ts
import type { DictionaryEntry } from '../dictionary';
import type { DictionaryStore } from '../dictionary-store';
import type { SettingsStore } from '../settings-store';
import type { Settings } from '../types';

import type { SyncClient } from './client';

/** Device-local: which server, who, and whether to sync are never synced. */
const LOCAL_ONLY: (keyof Settings)[] = ['syncEnabled', 'syncUrl', 'syncEmail'];
/** A remote blob is as untrusted as the renderer; the store's patch cleaner drops the rest. */
const FORBIDDEN = /key|token|secret/i;

interface DictionaryWire {
  id: string;
  word: string;
  soundsLike: string[];
  updatedAt: number;
  deletedAt: number | null;
}
interface SettingsWire {
  id: string;
  data: Record<string, unknown>;
  updatedAt: number;
  deletedAt: number | null;
}

export interface SyncDeps {
  client: SyncClient;
  dictionary: Pick<DictionaryStore, 'changedSince' | 'applyRemote' | 'list'>;
  settings: Pick<SettingsStore, 'get' | 'update' | 'recordSync' | 'settingsUpdatedAt'>;
  cursor: { get(): number; set(value: number): void };
  now?: () => number;
}

export interface SyncOutcome {
  ok: boolean;
  pushed: number;
  pulled: number;
  message: string;
  at: number;
}

const toWire = (e: DictionaryEntry): DictionaryWire => ({
  id: e.id, word: e.word, soundsLike: e.soundsLike, updatedAt: e.updatedAt, deletedAt: null,
});

function localSettingsBlob(settings: Settings): Record<string, unknown> {
  const data: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(settings)) {
    if (!LOCAL_ONLY.includes(k as keyof Settings)) data[k] = v;
  }
  return data;
}

function remotePatch(data: Record<string, unknown>): Partial<Settings> {
  const patch: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(data)) {
    if (LOCAL_ONLY.includes(k as keyof Settings) || FORBIDDEN.test(k)) continue;
    patch[k] = v;
  }
  return patch as Partial<Settings>;
}

export function createSyncEngine({ client, dictionary, settings, cursor, now = Date.now }: SyncDeps) {
  let running: Promise<SyncOutcome> | null = null;

  async function run(): Promise<SyncOutcome> {
    const since = cursor.get();
    let pushed = 0;
    let pulled = 0;
    try {
      // Push first so the pull that follows returns our own rows only if they lost.
      const { entries, removed } = dictionary.changedSince(since);
      const dictItems: DictionaryWire[] = [
        ...entries.map(toWire),
        ...removed.map(r => ({ id: r.id, word: '', soundsLike: [], updatedAt: r.deletedAt, deletedAt: r.deletedAt })),
      ];
      if (dictItems.length) {
        await client.push('dictionary', dictItems);
        pushed += dictItems.length;
      }
      const settingsStamp = settings.settingsUpdatedAt();
      if (settingsStamp > since) {
        await client.push<SettingsWire>('settings', [
          { id: 'me', data: localSettingsBlob(settings.get()), updatedAt: settingsStamp, deletedAt: null },
        ]);
        pushed += 1;
      }

      const dict = await client.pull<DictionaryWire>('dictionary', since);
      if (dict.rows.length) dictionary.applyRemote(dict.rows);
      pulled += dict.rows.length;

      const remoteSettings = await client.pull<SettingsWire>('settings', since);
      const blob = remoteSettings.rows[0];
      if (blob && blob.deletedAt == null && blob.updatedAt > settingsStamp) {
        settings.update(remotePatch(blob.data));
        pulled += 1;
      }

      cursor.set(Math.min(dict.now, remoteSettings.now));
      const at = now();
      settings.recordSync({ at });
      return { ok: true, pushed, pulled, message: `Synced ${pushed} up, ${pulled} down`, at };
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      const at = now();
      settings.recordSync({ at, error: message });
      return { ok: false, pushed, pulled, message, at };
    }
  }

  return {
    /** One run at a time; a second caller shares the in-flight result. */
    syncNow(): Promise<SyncOutcome> {
      if (!running) running = run().finally(() => (running = null));
      return running;
    },
  };
}
```

Note: the `removed` push sends `word: ''`, which the API's `dictionaryRow` schema rejects (`min(1)`). Change the API schema in `parley-api/src/types/sync.types.ts` so `word` is `z.string().max(60)` and add `.refine(r => r.deletedAt != null || r.word.length > 0, 'word required unless deleted')` on `dictionaryRow`. Add this case to `test/sync.types.test.ts`:

```ts
  it('allows an empty word only on a tombstone', () => {
    const s = rowSchemaFor('dictionary');
    expect(s.safeParse({ id: 'x', word: '', soundsLike: [], updatedAt: 1, deletedAt: 1 }).success).toBe(true);
    expect(s.safeParse({ id: 'x', word: '', soundsLike: [], updatedAt: 1 }).success).toBe(false);
  });
```

- [ ] **Step 8: Run** `npm test -- sync` and `npm run type-check`; then `make -C parley-api check`. Expect PASS.

- [ ] **Step 9: Commit**

```bash
git add electron/sync parley-api/src/types/sync.types.ts parley-api/test/sync.types.test.ts electron/settings-store.ts electron/__tests__/settings-store.test.ts
git commit -m "feat: desktop sync client and last-writer-wins engine (parley-015)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EHEdBYfo6unHheVK8q8RUy"
```

---

### Task 10: IPC channels, scheduler in main, and the feature plan

**Files:**
- Modify: `electron/main.ts` (near the `settings:*` handlers at lines 886-940), `electron/preload.ts:29-41`, `electron/electron-env.d.ts`, `electron/types.ts`
- Create: `parley-015.feature-plan.json` via the `plan-feature` skill, rendered to `FEATURE-PLAN.md`
- Modify: `feature_list.json`

**Interfaces:**
- Channels (all `onlySettingsWindow`):
  - `sync:signIn (email: string) -> SyncSignInResult { ok: boolean; message: string }`: validates email with a simple `/^[^@\s]+@[^@\s]+\.[^@\s]+$/`, builds a client with the current `syncUrl` and no token, calls `signIn`, stores the token with `store.setSyncToken`, updates `syncEmail`, runs one sync, returns the outcome message.
  - `sync:signOut () -> SettingsView`: clears the token, sets `syncEnabled: false`.
  - `sync:now () -> SyncOutcome`.
  - `sync:status` is unnecessary: `SettingsView` already carries `hasSyncToken`, `syncLastAt`, `syncLastError`.
- Preload `window.parley` gains `signInSync(email)`, `signOutSync()`, `syncNow()`. Types added in `electron-env.d.ts` next to the agent ones.
- `electron/types.ts` exports `SyncSignInResult` and re-exports `SyncOutcome` from `./sync/engine`.
- Scheduler in `main.ts`: when `syncEnabled && hasSyncToken`, run `syncNow()` 10 s after launch, then every 5 min, and 30 s after any `settings:update` or dictionary change (debounced). The engine is rebuilt when `syncUrl` or the token changes, same pattern as the agent client rebuild in `settings:update`. Timers cleared on quit.

- [ ] **Step 1: Run the plan-feature skill** for parley-015 ("Sync: dictionary and settings follow you between devices"). Surfaces: the Sync settings tab in four states (signed out, signing in, synced, error). Register in `feature_list.json` as `parley-015`, priority 17, area `settings`, `plan: "parley-015.feature-plan.json"`, verification:

```json
[
  "make check",
  "npm run test -- electron/sync electron/__tests__/settings-store.test.ts electron/__tests__/dictionary-store.test.ts",
  "make -C parley-api check",
  "Storybook: SettingsShell SyncSignedOut, SyncSigningIn, SyncSynced, SyncError in dark and light",
  "make dev with parley-api running on :3100: sign in, add a dictionary word, see it in sqlite via prisma studio; stop the API, press Sync now, see the error line and dictate normally"
]
```

`make plan-lint` must pass after this step.

- [ ] **Step 2: Implement main.ts handlers**, following the `settings:setApiKey` handler shape:

```ts
  ipcMain.handle('sync:signIn', async (event, email: unknown): Promise<SyncSignInResult> => {
    onlySettingsWindow(event);
    if (typeof email !== 'string' || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.trim())) {
      return { ok: false, message: 'Enter an email address' };
    }
    try {
      const { token } = await createSyncClient({ baseUrl: store.get().syncUrl, token: null }).signIn(email.trim());
      store.setSyncToken(token);
      store.update({ syncEmail: email.trim(), syncEnabled: true });
      rebuildSync();
      const outcome = await syncEngine!.syncNow();
      return { ok: outcome.ok, message: outcome.ok ? 'Signed in and synced' : outcome.message };
    } catch (err) {
      return { ok: false, message: err instanceof Error ? err.message : 'Sign-in failed' };
    }
  });
  ipcMain.handle('sync:signOut', async (event) => {
    onlySettingsWindow(event);
    store.setSyncToken(null);
    store.update({ syncEnabled: false });
    rebuildSync();
    return liveView();
  });
  ipcMain.handle('sync:now', async (event): Promise<SyncOutcome> => {
    onlySettingsWindow(event);
    if (!syncEngine) return { ok: false, pushed: 0, pulled: 0, message: 'Sign in to sync', at: Date.now() };
    return syncEngine.syncNow();
  });
```

with, above the handlers:

```ts
  let syncEngine: ReturnType<typeof createSyncEngine> | null = null;
  let syncTimer: NodeJS.Timeout | null = null;
  function rebuildSync() {
    if (syncTimer) clearInterval(syncTimer);
    syncTimer = null;
    const token = store.getSyncToken();
    const settings = store.get();
    if (!token || !settings.syncEnabled) {
      syncEngine = null;
      return;
    }
    syncEngine = createSyncEngine({
      client: createSyncClient({ baseUrl: settings.syncUrl, token }),
      dictionary: dictionaryStore,
      settings: store,
      cursor: { get: () => store.getSyncCursor(), set: v => store.setSyncCursor(v) },
    });
    setTimeout(() => void syncEngine?.syncNow(), 10_000);
    syncTimer = setInterval(() => void syncEngine?.syncNow(), 5 * 60_000);
  }
```

`getSyncCursor`/`setSyncCursor` come from Task 7. Call `rebuildSync()` once after the store is created, and inside `settings:update` when `syncUrl` or `syncEnabled` changed. Clear `syncTimer` in the existing quit path. Use the name of the dictionary store variable `main.ts` already has (search for `createDictionaryStore(`).

- [ ] **Step 3: Preload and types**

`electron/preload.ts` after `agentStatus`:

```ts
  signInSync: (email: string) => ipcRenderer.invoke('sync:signIn', email),
  signOutSync: () => ipcRenderer.invoke('sync:signOut'),
  syncNow: () => ipcRenderer.invoke('sync:now'),
```

`electron/electron-env.d.ts`: add the three signatures to the `parley` interface, importing `SyncSignInResult, SyncOutcome` from `./types`.

`electron/types.ts`:

```ts
export interface SyncSignInResult {
  ok: boolean;
  message: string;
}
export type { SyncOutcome } from './sync/engine';
```

- [ ] **Step 4: Verify** `npm run type-check && npm run lint && npm test`: PASS. `npm run dev` with the API running (`make -C parley-api dev`): confirm no main-process errors at launch.

- [ ] **Step 5: Commit**

```bash
git add electron parley-015.feature-plan.json FEATURE-PLAN.md feature_list.json
git commit -m "feat: sync IPC channels and scheduler in main (parley-015)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EHEdBYfo6unHheVK8q8RUy"
```

---

### Task 11: Sync settings tab

**Files:**
- Create: `src/settings/SyncTab.tsx`
- Modify: `src/settings/tabs.ts`, `src/settings/TabRail.tsx` (copy the `agent` tab block), `src/settings/SettingsShell.tsx` (new `Tabs.Panel value="sync"`), `src/settings/use-parley.ts`, `src/settings/SettingsShell.stories.tsx`, `src/mocks/` parley bridge mock if one exists for stories (search for `agentStatus:` under `src` and `.storybook`)
- Test: `src/settings/__tests__/SyncTab.test.tsx`

**Interfaces:**
- Hooks in `use-parley.ts`:

```ts
export function useSignInSync()  // useMutation(email => window.parley.signInSync(email)), invalidates SETTINGS
export function useSignOutSync() // useMutation(() => window.parley.signOutSync()), setQueryData(SETTINGS, view)
export function useSyncNow()     // useMutation(() => window.parley.syncNow()), invalidates SETTINGS
```

- `SyncTab({ settings, onChange })` same props as `AgentTab`.
- Four states, from `settings`: signed out (`!hasSyncToken`), signing in (mutation pending), synced (`hasSyncToken && !syncLastError`), error (`hasSyncToken && syncLastError`).

- [ ] **Step 1: Failing test** `src/settings/__tests__/SyncTab.test.tsx` (mirror the setup of the existing tests in that folder, which render inside the app providers and stub `window.parley`):

```tsx
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';

import { SyncTab } from '../SyncTab';
import { renderWithProviders, settledView } from './helpers'; // use whatever this folder already exports; if nothing, build a QueryClientProvider + MantineProvider wrapper here

describe('SyncTab', () => {
  it('signed out: shows the email form and no Sync now', () => {
    renderWithProviders(<SyncTab settings={{ ...settledView, hasSyncToken: false }} onChange={() => {}} />);
    expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /sync now/i })).toBeNull();
  });

  it('synced: shows the account, last sync time, and Sync now calls the bridge', async () => {
    window.parley.syncNow = vi.fn().mockResolvedValue({ ok: true, pushed: 1, pulled: 0, message: 'Synced 1 up, 0 down', at: 1 });
    renderWithProviders(
      <SyncTab settings={{ ...settledView, hasSyncToken: true, syncEmail: 'me@example.com', syncLastAt: Date.now(), syncLastError: '' }} onChange={() => {}} />,
    );
    expect(screen.getByText('me@example.com')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: /sync now/i }));
    expect(window.parley.syncNow).toHaveBeenCalled();
    expect(await screen.findByText(/synced 1 up/i)).toBeInTheDocument();
  });

  it('error: the last failure stays visible with dictation reassurance', () => {
    renderWithProviders(
      <SyncTab settings={{ ...settledView, hasSyncToken: true, syncLastAt: 5, syncLastError: 'fetch failed' }} onChange={() => {}} />,
    );
    expect(screen.getByRole('alert')).toHaveTextContent('fetch failed');
    expect(screen.getByText(/dictation keeps working/i)).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run** `npm test -- SyncTab`: FAIL.

- [ ] **Step 3: Implement** `src/settings/SyncTab.tsx`, built from the `AgentTab` pieces (`SettingsGroup`, `SettingRow`, `StaggerGroup`, `Pressable`, `classes.primary`; Mantine `TextInput`, `Switch`, `Button`, `Alert`, `Badge`, `Text`):

- Header: `Title order={4}` "Sync", dimmed line "Your dictionary and settings follow you between devices. API keys stay on this Mac."
- Group "Server": `TextInput label="Sync URL"` saving on blur through `onChange({ syncUrl })` (same blur pattern as the vocabulary textarea in `GeneralTab`).
- Signed out: group "Account" with an email `TextInput` (zod `z.string().email()` via react-hook-form, like `AgentUrlSection`) and a `Button` "Sign in" calling `useSignInSync`. While pending the button shows `loading`. A failed result renders an `Alert color="red"` with the message.
- Signed in: `SettingRow label="Account"` showing `settings.syncEmail` in a `Badge`, a "Sign out" `Button variant="subtle"`; `SettingRow label="Sync"` with a `Switch` bound to `syncEnabled`; `SettingRow label="Last sync"` with relative time from `syncLastAt` (0 renders "Never") and a "Sync now" `Button`; after a run, the outcome message under it in dimmed text.
- Error: `Alert color="red" role="alert" title="Last sync failed"` with `syncLastError` and the line "Dictation keeps working; sync retries every five minutes."

`tabs.ts`: `export type TabId = 'overview' | 'gesture' | 'general' | 'agent' | 'sync'; TAB_ORDER` appends `'sync'`. `TabRail.tsx`: add a `sync` tab after `agent`, label "Sync". `SettingsShell.tsx`: add the panel.

`use-parley.ts`: the three hooks from Interfaces.

Stories in `SettingsShell.stories.tsx`: `SyncSignedOut`, `SyncSigningIn` (parameters stub `signInSync` to a never-resolving promise and `play` clicks Sign in), `SyncSynced`, `SyncError`, each `initialTab: 'sync'`. Extend the story bridge mock with the three new bridge methods returning resolved values.

- [ ] **Step 4: UX pre-pass**: run the `ux-prepass` skill checklist on the tab; run `npm run storybook-render` and confirm the four stories render in dark and light with zero page errors.

- [ ] **Step 5: Run** `make check`: PASS.

- [ ] **Step 6: Commit**

```bash
git add src FEATURE-PLAN.md parley-015.feature-plan.json storybook-render-report.json
git commit -m "feat: Sync settings tab (parley-015)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EHEdBYfo6unHheVK8q8RUy"
```

---

### Task 12: Evidence, hand verification, and progress notes

**Files:**
- Modify: `feature_list.json` (parley-014 and parley-015 evidence), `claude-progress.md`, `docs/MANUAL_CHECKLIST.md`

- [ ] **Step 1: Hand run**

```bash
make -C parley-api dev &      # :3100
make dev
```

In Settings > Sync: sign in with any email, add a dictionary word in the dictionary UI, press Sync now, open `make -C parley-api studio` and see the row. Kill the API, press Sync now, see the error alert, dictate into a text field and confirm the paste works.

- [ ] **Step 2: Evidence**: paste the `make check` tail, the API `make check` tail, and the storybook render summary into each feature's `evidence` array per the existing entries' format. Set `parley-014` to `passing`. Leave `parley-015` `in_progress` only if the hand run in Step 1 could not be completed; otherwise `passing`.

- [ ] **Step 3: Add an "Sync" block to `docs/MANUAL_CHECKLIST.md`** with the four Step 1 actions as checkboxes.

- [ ] **Step 4: `claude-progress.md`**: replace the parley-013 header section with a short "parley-014 / parley-015" section: what landed, the layout, how to run the API, what remains (Android client, key proxy).

- [ ] **Step 5: Final gate and commit**

```bash
make check
git add feature_list.json claude-progress.md docs/MANUAL_CHECKLIST.md
git commit -m "chore: evidence and notes for the monorepo and sync API (parley-014, parley-015)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EHEdBYfo6unHheVK8q8RUy"
```
