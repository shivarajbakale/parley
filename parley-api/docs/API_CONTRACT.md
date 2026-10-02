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
OPTIONS /api/todos   Origin: http://localhost:5173
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
OPTIONS /api/todos   Origin: http://evil.example
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
fetch(`${API_URL}/api/todos`, { credentials: 'include' })
```

`credentials: 'include'` is not the default. Without it the browser sends no
cookies and stores none from the response, and every request looks
unauthenticated with nothing in either log to say why.

## Cookies

**This server sets no cookies.** It ships no authentication layer at all — that
is a decision, written down in [CONSTRAINTS.md](CONSTRAINTS.md), and
`api-lint` reads the declaration. `Cookie` is in the allowed headers and
`credentials: true` is set so the wiring is already right for the day auth
arrives.

When it does, the attributes are not a style choice:

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
POST /api/todos   {"title":"probe"}
{"data":{"id":"d0dc3a11-…","title":"probe","completed":false,…},
 "meta":{"timestamp":"2026-08-27T20:21:04.721Z","statusCode":201}}
```

`data` is whatever the handler returned. `meta.statusCode` repeats the HTTP
status, so a client that has already lost the response object can still tell
success from failure.

## Pagination

```
GET /api/todos?page=1&limit=20
{"data":[],"meta":{"total":0,"page":1,"limit":20,"totalPages":0}}
```

`page` defaults to 1, `limit` to 20 and is capped at 100.

**A paginated response has no `meta.timestamp` and no `meta.statusCode`.** The
transform passes a body that already has `data` and `meta` straight through
rather than merging into it, so those two fields are present on every other
response and absent here. A client must treat them as optional.

(NestJS's interceptor merges instead of passing through, so the same request
there returns all six fields. If you are writing one client for both, read the
list's own `meta.total` / `meta.page` and ignore the rest.)

## Errors

Errors go through the same transform, so an error body is a **success-shaped
envelope with an error payload inside `data`**:

```
POST /api/todos   {"description":"no title"}
{"data":{"status":"error","message":"title: Required"},
 "meta":{"timestamp":"…","statusCode":400}}

GET /api/todos/00000000-0000-0000-0000-000000000000
{"data":{"status":"error","message":"Todo not found"},"meta":{…,"statusCode":404}}

GET /api/nope
{"data":{"status":"error","message":"Route /api/nope not found"},"meta":{…,"statusCode":404}}
```

There is **no top-level `error` key**. Read `meta.statusCode` for the status and
`data.message` for the text. `create-nestjs-app` answers `{"error":{…}}`
instead, so a client that talks to both has to handle two shapes — see the table
below.

A validation failure is one string, not a field list: Zod's path and message
joined by `src/middleware/validate.middleware.ts` (`"title: Required"`). A form
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
| Paginated `meta` | `total,page,limit,totalPages` | the same plus `timestamp,statusCode` |
| Auth | none | session cookie, every route guarded |
| Health | `/api/health` | plus `/api/health/ready`, `/api/health/live` |
| `chrome-extension://` origins | rejected | allowed |
| Stack in an error body | never | in development only |

## Wiring a client

The `connect-frontend` skill walks the whole path, including the `.env` values on
both sides.
