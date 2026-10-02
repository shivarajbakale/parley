# API contract

What a browser client — React, Electron renderer, Chrome extension — has to do
to talk to this server, and what it gets back.

Every shape below was read off the running server, not off the source. The
transcripts are real responses from `node dist/server.js` with
`NODE_ENV=development`.

## Base URL and health

Every route is mounted under `/api` (`src/routes/index.ts`, mounted in
`src/app.ts`). The port is `PORT`, default 3000.

```
GET /api/health
{"data":{"status":"success","message":"Server is healthy","timestamp":"…","uptime":0.52},
 "meta":{"timestamp":"…","statusCode":200}}
```

There is one health route. `create-nestjs-app` also answers `/api/health/ready`
and `/api/health/live`; this server does not, so a deploy probe pointed at those
paths gets a 404.

## Which origins are allowed, and how to add one

`src/app.ts` builds the allowlist:

| Origin | Where it comes from |
| --- | --- |
| `http://localhost:5173` | the Vite dev server — `create-react-app`'s default |
| `http://localhost:3000` | the alternative dev port |
| whatever `FRONTEND_URL` holds | `src/config/env.ts`, dropped when unset |

A request with **no** `Origin` header — curl, a server-to-server call, a test —
is allowed through.

**Add an origin by setting `FRONTEND_URL`, not by editing the array.** The array
is the two local defaults plus one configured value on purpose: a deployment
that needs a second production origin needs a decision about who that is, and
`.env` is where that decision is recorded.

Verified against the running server:

```
OPTIONS /api/me   Origin: http://localhost:5173
  204 No Content
  Access-Control-Allow-Origin: http://localhost:5173
  Access-Control-Allow-Credentials: true
  Access-Control-Allow-Methods: GET,HEAD,PUT,PATCH,POST,DELETE
  Access-Control-Allow-Headers: Content-Type,Authorization,Cookie
  Vary: Origin
```

**A rejected origin is a 500, not a 403.** The origin check is a callback that
calls back with an `Error`, and an error out of middleware lands in
`errorHandler` like any other. The browser reports a CORS failure; the server
log reports a fault:

```
OPTIONS /api/me   Origin: http://evil.example
  500 Internal Server Error, no Access-Control-* headers
  log: Origin http://evil.example not allowed by CORS
```

They are the same event seen from two sides. A 500 in the log with that message
is a client on an origin nobody added — not a bug in the server.

## Credentials

`credentials: true` is set, so **`origin: '*'` is not available**: the CORS spec
forbids the pair, and a browser refuses the response rather than warning about
it. That is why the origin is echoed and `Vary: Origin` is set.

The client must opt in on every request:

```ts
fetch(`${API_URL}/api/me`, { credentials: 'include' })
```

`credentials: 'include'` is not the default. Without it the browser sends no
cookies and stores none from the response, and every request looks
unauthenticated with nothing in either log to say why.

## Cookies

**This server sets no cookies.** Auth is a bearer token: `POST /api/auth/token
{ email }` issues one, and every other route except health and that one needs
`Authorization: Bearer <token>`. `Cookie` is in the allowed headers and
`credentials: true` is set so the wiring is already right if cookies arrive.

If they do, the attributes are not a style choice:

- **Same site** (`localhost:5173` → `localhost:3000`, or `app.example.com` →
  `api.example.com`): `SameSite=Lax` is enough. A port is not part of a *site*,
  so two localhost ports are same-site even though they are cross-origin.
- **Cross site** (frontend and API on different registrable domains, or any
  `chrome-extension://` origin): the cookie must be `SameSite=None; Secure`,
  which means the API must be served over HTTPS. A `Lax` cookie is simply not
  attached to a cross-site request — no error, no log line, just an
  unauthenticated request.
- **`HttpOnly` always.** A token the page can read is a token an injected script
  can read.

## The success envelope

`src/middleware/transform.middleware.ts` owns it, and it is the only owner —
a controller returns data and never builds this shape itself (`api-lint` A5).

```
POST /api/auth/token   {"email":"a@example.com"}
{"data":{"token":"…"},
 "meta":{"timestamp":"2026-08-27T20:21:04.721Z","statusCode":201}}
```

`data` is whatever the handler returned. `meta.statusCode` repeats the HTTP
status, so a client that has already lost the response object can still tell
success from failure.

## Sync

Four resources sync: `dictionary`, `settings`, `history`, `tasks`. Every route
is under `requireAuth` (`Authorization: Bearer <token>`) and every read and
write is scoped to the token's user.

```
GET /api/{resource}?since=<ms>
{"data":[<row>,…],"meta":{"timestamp":"…","statusCode":200,"now":1790000000000}}

PUT /api/{resource}   {"items":[<row>,…]}
{"data":[<winning row>,…],"meta":{"timestamp":"…","statusCode":200,"now":1790000000000}}
```

- `since` defaults to 0 and must be a non-negative integer. A pull returns rows
  the server stored after `since` (a server-assigned `syncedAt`, not the client
  `updatedAt`, so an old offline edit is still delivered), oldest first, at most
  1000, **including tombstones** (rows with `deletedAt` set). `meta.now` is the
  next `since`. `meta.hasMore` is true when more rows remain: **while `hasMore`
  is true, call again with the returned `meta.now`, until it is false.**
- **Pulls may re-deliver rows.** The cursor overlaps by design (a pull's
  `since` is inclusive and the final cursor trails server time by 2 seconds), so
  a client must apply rows idempotently under last-writer-wins.
- Rows are keyed by `(userId, id)`, so two users can use the same row id.
- A push takes at most **500** items. The response holds the winning row for
  every submitted id, so the client overwrites its copy with it.
- **Merge rule: last writer wins** on `updatedAt`. An incoming row with an older
  `updatedAt` loses and the stored row comes back. A client clock further in
  the future than `MAX_FUTURE_MS` is clamped to server time (`src/services/merge.ts`).
- `settings` is one row per user: the server ignores the client `id` and uses
  the user id. `settings.data` may not contain keys matching `key`, `token` or
  `secret` (case-insensitive); the push is rejected with a 400.
- A tombstone for `dictionary` may carry an empty `word`; a live row may not.

Row shapes (timestamps are JSON numbers, milliseconds):

```ts
dictionary: { id, word, soundsLike: string[], updatedAt, deletedAt? }
settings:   { id, data: Record<string, unknown>, updatedAt, deletedAt? }
history:    { id, mode, text, app, createdAt, updatedAt, deletedAt? }
tasks:      { id, title, notes, dueAt?, rrule?, priority, status, sourceText, updatedAt, deletedAt? }
```

Sync responses carry the standard `meta.timestamp` and `meta.statusCode` plus
`meta.now` and `meta.hasMore`, merged in by the transform from `res.locals.meta`.

## Errors

Errors go through the same transform, so an error body is a **success-shaped
envelope with an error payload inside `data`**:

```
PUT /api/tasks   {"items":[{"id":"t1","updatedAt":1}]}
{"data":{"status":"error","message":"items.0.title: Required"},
 "meta":{"timestamp":"…","statusCode":400}}

GET /api/me   (no Authorization header)
{"data":{"status":"error","message":"Missing bearer token"},"meta":{…,"statusCode":401}}

GET /api/nope
{"data":{"status":"error","message":"Route /api/nope not found"},"meta":{…,"statusCode":404}}
```

There is **no top-level `error` key**. Read `meta.statusCode` for the status and
`data.message` for the text. `create-nestjs-app` answers `{"error":{…}}`
instead, so a client that talks to both has to handle two shapes — see the table
below.

A validation failure is one string, not a field list: Zod's path and message
joined by `src/middleware/validate.middleware.ts` (`"items.0.title: Required"`). A form
that wants per-field errors has to parse it, or the middleware has to change.

**No stack trace ever leaves this server.** `errorHandler` sends `message` only,
in every environment. `npm run boot-check` boots the built server with
`NODE_ENV=production` and fails the build if a 404 body contains one.

## Differences from create-nestjs-app

Both backends in this repo answer `{data, meta}` on success. Everything else in
the contract differs, so a shared client needs a small adapter, not one fetch
wrapper.

| | this server | create-nestjs-app |
| --- | --- | --- |
| Error body | `{data:{status,message},meta}` | `{error:{message,statusCode,timestamp,path}}` |
| Validation detail | one joined string in `data.message` | `error.errors[]` of `{field,message,value}` |
| Auth | bearer token (`/api/auth/token`) | session cookie, every route guarded |
| Health | `/api/health` | plus `/api/health/ready`, `/api/health/live` |
| `chrome-extension://` origins | rejected | allowed |
| Stack in an error body | never | in development only |

## Wiring a client

The `connect-frontend` skill walks the whole path, including the `.env` values on
both sides.
