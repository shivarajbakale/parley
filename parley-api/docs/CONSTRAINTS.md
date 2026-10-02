# Constraints

Required reading before adding a dependency, changing the response envelope, or
touching the error model.

## Dependencies (`package.json`)

MUST be true of any new dependency:

- Pinned to a `^` minor version, not `*` or `latest`.
- Justified in `DECISIONS.md` (what problem it solves, what was rejected).
- Maintained — last release within ~12 months, not deprecated.
- Type-safe: ships types or has an `@types/*` package; `npm run type-check`
  still passes.

MUST NOT:

- Add a dependency for a one-off helper that fits in `src/utils/` in < 50 lines.
- Add a second validation library (the standard is **Zod**).
- Add a second ORM / query builder (the standard is **Prisma**).
- Add a logging framework (the standard is **Winston** via `src/utils/logger.ts`).
- Add a web framework or router layer on top of Express.

## Response envelope & error model

MUST be true:

- Every response is wrapped in `{ data, meta: { timestamp, statusCode } }` by
  `transformResponse`. Do not bypass it or invent a parallel shape.
- Status codes: `200` read/update, `201` create, `204` delete (no body),
  `400` validation, `404` not found, `409` conflict.
- Every write validates its body with a Zod schema through `validate(schema)`
  in the route, before the controller runs.
- Expected failures are thrown as `AppError(message, statusCode)` from the
  service — message first. It lives in `src/middleware/error.middleware.ts`.
  Unexpected errors bubble to the global error handler (rendered as 500).

MUST NOT:

- Return raw Prisma errors or stack traces to the client.
- Leak internal-only fields (e.g. password hashes if you add auth) in a response.
- Catch an error in a controller just to `res.status(500)` — let it propagate.

## Auth

Bearer tokens. `POST /api/auth/token` takes an email and returns a long-lived
token; the client stores it and sends `Authorization: Bearer <token>`.
`requireAuth` (src/middleware/auth.middleware.ts) resolves it to `req.userId`.
Only the SHA-256 hash of a token is stored. Health and the token route are
public; every other route file names `requireAuth`.

## Database (`prisma/schema.prisma`)

MUST be true:

- IDs are `String @id @default(uuid())`; models carry `createdAt`/`updatedAt`.
- A schema change is applied with `make db` (`prisma db push`) and the client is
  regenerated (`make generate`); a destructive change gets a `DECISIONS.md` note.
- SQLite has no enums, no scalar lists, no `Json` and no `@db.` native types.
  `make db-lint` fails the build on all four, because Prisma accepts them at
  edit time and only the push fails.
- SQLite is the default. To switch providers, change `provider` + `DATABASE_URL`
  together and note it in `DECISIONS.md`.

MUST NOT:

- Instantiate `new PrismaClient()` outside `src/config/database.ts`.
- Commit `prisma/dev.db` or `.env` (both are gitignored).

## Environment

- New env vars are added to `.env.example` AND read through `src/config/env.ts`
  (typed). Never read `process.env.X` directly in a service.
- Secrets never land in git — they come from `.env` (local) or the deploy
  environment.

## Tests

- The default `npm run test` (Level 1+2) must pass with **no database** present.
  Anything needing the DB goes behind `RUN_DB_TESTS=1` (Level 3).
- Don't delete or weaken a test to make a feature look done — a failing test is
  a blocker, a deleted test is a regression.
