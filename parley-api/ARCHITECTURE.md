# Architecture

A map of parley-api: where things live, how a request or a command flows
through it, and which invariants the layout encodes.

It points at files rather than reproducing them, because a copy of code is a copy
that goes stale, and it deliberately does not repeat the stack, the entry point
or the commands — those are in [AGENTS.md](AGENTS.md), which is read every
session. This one is read on demand, which is what keeps that one short: anything
an agent needs *in order to find its way around* belongs here rather than there.

<!-- rocketship:own shape -->
## The shape

```
src/
  server.ts        boots the HTTP server, graceful shutdown
  app.ts           the Express app: middleware order, then routes
  config/          env.ts (process.env -> typed config), database.ts (the one PrismaClient)
  middleware/      correlation, validate, transform, error, notFound — cross-cutting only
  routes/          index.ts mounts /health, /users, /todos under /api
  controllers/     thin: read req, call a service, set the status
  services/        all business logic, and the only layer that touches Prisma
  types/           one file per resource: the Zod schema and its inferred DTO
  utils/logger.ts  Winston logger, Morgan stream, redaction
prisma/            schema.prisma (SQLite) + seed.ts
test/              health + validation run with no database; todo.e2e needs RUN_DB_TESTS=1
scripts/           the gates make check runs: db-lint, api-lint, capability-lint,
                   doc-links, boot-check, plan-lint
```

## How a request flows

```
request
  -> correlationId          attaches X-Correlation-Id
  -> helmet, cors, json, urlencoded
  -> morgan                 logging through the Winston stream
  -> transformResponse      wraps res.json in { data, meta }
  -> /api -> resource router -> validate(schema) -> controller -> service -> Prisma
  -> notFoundHandler        no route matched: 404
  -> errorHandler           anything thrown: AppError's status, or 500
```

Every response leaves through `transformResponse`, so the shape is always
`{ data, meta: { timestamp, statusCode } }`. Adding a second shape means a client
has to branch on which endpoint it called.

## Invariants the layout encodes

- **Only services touch Prisma.** A controller that queries directly cannot be
  reused by a job or another endpoint, and its logic cannot be tested without HTTP.
- **One PrismaClient**, in `config/database.ts`. A second one opens a second pool
  against a single-writer SQLite file.
- **Every write validates through `validate(schema)`** in the route, before the
  controller runs. Validation in the controller runs after the request is already
  being handled, which is where inconsistent 400s come from.
- **Expected failures are `throw new AppError(message, statusCode)`** — message
  first — from `src/middleware/error.middleware.ts`. Async handlers are wrapped in
  `asyncHandler` from the same file, or a rejected promise never reaches the error
  handler and the request hangs.
- **`process.env` is read in `config/env.ts` and nowhere else**, so a missing
  variable fails at boot instead of on the first request that needs it.

## Where to add a thing

| Adding | Goes | Start from |
| --- | --- | --- |
| a whole REST resource | model, types, service, controller, routes | the `add-resource` skill |
| one action on a resource | service method, controller, route | the `add-endpoint` skill |
| a cross-cutting concern | `src/middleware/` | `correlation.middleware.ts` |
| a config value | `.env.example` and `src/config/env.ts` | `env.ts` |
| a dependency, a layer, a new envelope | read [docs/CONSTRAINTS.md](docs/CONSTRAINTS.md) first | — |
| a capability you have not used here before | the `use-express-api` map says which call, package and layer | the map's closest row |
| a browser client calling this server | nothing here changes — read [docs/API_CONTRACT.md](docs/API_CONTRACT.md) | the `connect-frontend` skill |
<!-- /rocketship:own -->
