---
name: connect-frontend
description: Wire a browser client — React (Vite), an Electron renderer, or a Chrome extension — to this API. Use when a frontend needs to call this server for the first time, when its requests are failing CORS, or when a request that works in curl fails in the browser.
---

# connect-frontend — wire a browser client to this API

The full contract is [docs/API_CONTRACT.md](../../../docs/API_CONTRACT.md):
origins, credentials, cookies, the envelope, pagination, the error shape. This
skill is the order to do things in, and the four failures that account for
almost every "works in curl, fails in the browser".

## Procedure

1. **Decide the client's origin.** In development it is the Vite dev server,
   `http://localhost:5173`, which is already allowed. Anything else — a
   different port, a deployed frontend — is added by setting `FRONTEND_URL` in
   this server's `.env`, not by editing the array in `src/app.ts`.
2. **Give the client the base URL.** `http://localhost:3000/api` in
   development, from the client's own environment (`VITE_API_URL` for a Vite
   app). Every route is under `/api`.
3. **Send credentials on every request.**
   ```ts
   fetch(`${API_URL}/todos`, { credentials: 'include' })
   ```
   It is not the default. This server sets no cookies today, but the CORS
   headers are configured for them, and adding the option now costs nothing and
   saves a debugging session later.
4. **Unwrap the envelope once, in one place.** A success is
   `{ data, meta }`; read `data`. Do not spread this through the client — one
   module that unwraps and one that throws on failure.
5. **Read errors from `data`, not from `error`.** An error body is the same
   envelope shape with `{ status: 'error', message }` inside `data`, and the
   status is in `meta.statusCode`. There is no top-level `error` key here.
6. **Handle pagination's thinner meta.** A list response's `meta` has
   `total`, `page`, `limit` and `totalPages` and **not** `timestamp` or
   `statusCode`. Treat those two as optional everywhere.
7. **Prove it end to end** before building on it: start this server
   (`npm run dev`), start the client, and confirm one GET and one POST from the
   browser — not from curl. Curl sends no `Origin` header, so it never
   exercises the part that breaks.

## The four failures

- **No `credentials: 'include'`.** The browser sends no cookies and stores none.
  Nothing errors; requests are just anonymous.
- **An origin nobody added.** The browser reports a CORS failure and this server
  logs a **500** with `Origin … not allowed by CORS` — the origin check rejects
  with an `Error`, so it lands in the error handler. A 500 with that message is
  a client on an unlisted origin, not a server fault.
- **A wildcard origin.** `origin: '*'` cannot be combined with
  `credentials: true`; the spec forbids the pair and the browser refuses the
  response. That is why the origin is echoed, and why the allowlist exists.
- **Testing with curl only.** A request with no `Origin` header is allowed
  through unconditionally, so curl passes while the browser fails.

## Auth

This server ships none, deliberately — [docs/CONSTRAINTS.md](../../../docs/CONSTRAINTS.md)
says so and `api-lint` reads the declaration. A client that needs sessions wants
`create-nestjs-app`. If auth is added here, the cookie attributes are the whole
job: `HttpOnly` always, `SameSite=Lax` when the client and the API are on the
same site (two localhost ports count), and `SameSite=None; Secure` over HTTPS
when they are not.

## Verify

`npm run boot-check` proves the server starts, serves, and refuses an unknown
route cleanly. It does not prove the browser can reach it — for that, run both
sides and watch the network tab. Then run the `verify` skill for the full bar.
