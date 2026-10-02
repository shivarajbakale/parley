# Express capability map

The routing table behind the `use-express-api` and `add-endpoint` skills. Read a
row by **what you want to do**: it names the call, the package that provides it,
the layer the code belongs in, the slice in this repo to copy, and the gotcha
that bites people.

This map is written against `express` **4**, `@prisma/client` **5** and `zod`
**3**. The majors matter — Express 4 and Express 5 disagree about whether a
rejected promise reaches the error handler, which is the single most
consequential row below — so `npm run capability-lint` compares each one against
`package.json` and fails when they drift.

The map is a checked artifact, not prose. `npm run capability-lint` fails a row
that loses a column, names a symbol this stack does not expose, cites a package
the project does not depend on, puts the code in a layer that does not exist, or
points at a file that moved. A row whose reference slice reads *(not wired…)* is
a capability this repo documents but has not built — the honest way to answer
"can I do X here" with "not yet, and here is what it would take".

## The map

| Capability (what you want) | API or symbol | Package | Layer | Reference slice in this repo | Gotcha |
|---|---|---|---|---|---|
| Register a route | `router.get`, `router.post` | `express` | route | `src/routes/user.routes.ts` | Routers mount under `/api` in `src/app.ts`, so the path in the router is not the path a client calls. A router registered after `notFoundHandler` never runs — the 404 answers first, and nothing says so. |
| Validate a request body | `validate`, `z.object` | `zod` | middleware | `src/middleware/validate.middleware.ts` | Validation is a **route** guard, not a controller step. A schema that is exported and never passed to `validate(...)` type-checks, lints, and validates nothing; the controller then reads whatever the client sent. |
| Let an async handler's throw reach the error handler | `asyncHandler` | `—` | controller | `src/middleware/error.middleware.ts` | Express 4 does not catch a rejected promise. An `async` handler that throws without this wrapper never calls `next`, so the request hangs until the client times out — no 500, no log, no stack. Express 5 changed this; this project is on 4. |
| Fail a request with a status and message | `AppError` | `—` | service | `src/middleware/error.middleware.ts` | Throw it from the service. A controller that formats its own error body bypasses the central handler, and `api-lint` fails the build for it. |
| Handle every error in one place | `errorHandler` | `—` | app | `src/app.ts` | **Arity is the registration.** Express identifies error middleware by `fn.length === 4`; delete the unused `_next` parameter and it silently becomes ordinary middleware that never runs, and every error falls through to Express's default HTML page. |
| Shape the response envelope | `transformResponse` | `—` | middleware | `src/middleware/transform.middleware.ts` | One owner. It wraps whatever a handler passes to `res.json`, so a controller that returns `{ status, data }` ships `data.data` — which is exactly how `/api/users` and `/api/todos` once answered different shapes. |
| Answer an unknown route with a 404 | `notFoundHandler` | `—` | app | `src/middleware/notFound.middleware.ts` | It is ordinary middleware, so position is the whole behaviour: after every route, before `errorHandler`. Move it up and it swallows the routes below it. |
| Read configuration | `config` | `dotenv` | config | `src/config/env.ts` | `process.env` anywhere else fails `api-lint`. A value read at module scope in a file imported before `dotenv.config()` runs is `undefined`, and the failure is a missing header rather than a crash. |
| Query the database | `prisma.user.findMany` | `@prisma/client` | service | `src/services/user.service.ts` | Only a service may touch `prisma` — a controller that imports it fails `api-lint`. One client per process: a `new PrismaClient()` per request exhausts SQLite's handles under any load at all. |
| Run two reads at once | `Promise.all` | `@prisma/client` | service | `src/services/user.service.ts` | Safe for reads — the paginated list does a `findMany` and a `count` together. Do not reach for the same shape with two writes; see the next row. |
| Write concurrently | `prisma.$transaction` | `@prisma/client` | service | *(not wired — the demo slice writes one row at a time)* | SQLite has exactly one writer. Two writes in flight return `SQLITE_BUSY`, which surfaces as an intermittent 500 under load and never in development. Batch them into one `$transaction` instead of a `Promise.all`. |
| Let a browser send cookies | `cors` | `cors` | app | `src/app.ts` | `credentials: true` with `origin: '*'` is rejected by every browser — the spec forbids the pair, and the request fails in the browser with nothing in the server log. Echo the specific origin, which is why the origin here is a callback. |
| Set security headers | `helmet` | `helmet` | app | `src/app.ts` | It must be registered before the routes. Middleware added after a route cannot add headers to a response that route already sent. |
| Trace one request across every log line | `correlationId` | `winston` | middleware | `src/middleware/correlation.middleware.ts` | It is registered first on purpose. Anything registered above it logs without the id, and a request you cannot follow across services is a request you cannot debug. |
| Write a log line | `logger` | `winston` | any | `src/utils/logger.ts` | `console.log` bypasses the transports. In production the file transport *is* the log, so a `console.log` is invisible exactly where you need it. |
| Authenticate a request | `betterAuth` | `better-auth` | any | *(not wired — this project ships no auth, by decision)* | Deliberate, and written down in `docs/CONSTRAINTS.md`; `api-lint` reads that declaration. `create-nestjs-app` is the authenticated backend. Adding auth here means a guard every route passes through, not a middleware on the routes you remember. |
| Run work that outlives the response | `inngest` | `inngest` | any | *(not wired — this project has no job runner)* | A long request is not a background job: the client holds the socket, a deploy kills the work, and a retry means the caller retries. Choosing a runner is a decision to write down before the first job. |

## Where code runs

| | Route | Controller | Service | Middleware |
| --- | --- | --- | --- | --- |
| Reads `req` / writes `res` | mounts only | yes | never | yes |
| Calls `prisma` | no | **no** — `api-lint` fails it | yes | no |
| Throws `AppError` | no | rarely | yes | yes |
| Formats the response body | no | no — the transform owns it | no | one, `transformResponse` |

The controller is a translator: read the request, call one service method,
return the result. Everything it does beyond that belongs on one side of it or
the other, and `api-lint` enforces the two that are mechanical — no database in
a controller, no hand-built envelope.

## The error path

Four things have to line up, and three of them are invisible to the type system.

1. The handler is wrapped in `asyncHandler`, or its rejection is lost.
2. It throws `AppError` (or anything else) rather than writing a body.
3. `errorHandler` is registered **last**, after `notFoundHandler`.
4. `errorHandler` takes **four** parameters. This is not style — it is how
   Express tells an error handler from ordinary middleware, so the unused
   `_next` is load-bearing.

The failure when any of them is missing is the same shape: the client gets a
hang, an HTML stack page, or a 200 with no body, and the server log says nothing.

## Sources

Read and verified against the vendor's own documentation on **2026-08-27**.

- Express error handling, including the four-argument signature —
  <https://expressjs.com/en/guide/error-handling.html>
- Express middleware ordering — <https://expressjs.com/en/guide/using-middleware.html>
- Express 4 API reference — <https://expressjs.com/en/4x/api.html>
- The `cors` middleware options — <https://expressjs.com/en/resources/middleware/cors.html>
- CORS and credentials, and why the wildcard is refused —
  <https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS>
- Prisma transactions — <https://www.prisma.io/docs/orm/prisma-client/queries/transactions>
- Prisma on SQLite — <https://www.prisma.io/docs/orm/overview/databases/sqlite>
- Zod schemas — <https://zod.dev/>
