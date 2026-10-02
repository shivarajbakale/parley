<!-- feature-plan:v1 — generated, do not hand-edit.
     Regenerate with: node scripts/feature-plan.mjs api-keys.feature-plan.json -o FEATURE-PLAN.md -->

# Let a customer rotate their own API key

`api-keys` · an Express service · 2 surfaces · endpoint, resource

## Problem

Rotating a key means emailing support, who run a query by hand. It is slow for the customer and it is a production write nobody reviews.

## Not in this feature

- Multiple simultaneous keys per account. One active key, one grace window.
- A UI. This is the API the client will call.

## Surfaces

### Rotate key

Kind: `endpoint` — a route handler plus its zod schema

Issue a new key and start a grace window on the old one.

```
┌──────────────────────────────────────────────────────────────────────────┐
│  POST /v1/api-keys/rotate                                                │
│        │                                                                 │
│        └──▶  src/routes/api-keys.ts                                      │
│                  │                                                       │
│                  └──▶  ApiKeyService.rotate()                            │
│                  │                                                       │
│                  └──▶  audit.record('api-key.rotated')                   │
│                                                                          │
│  a route handler plus its zod schema                                     │
└──────────────────────────────────────────────────────────────────────────┘
```

Becomes: `src/routes/api-keys.ts`

### API keys

Kind: `resource` — a router, service, and Prisma model

The module that owns key issuance, hashing and expiry.

```
┌──────────────────────────────────────────────────────────────────────────┐
│  the router                                                              │
│        │                                                                 │
│        └──▶  src/services/api-keys.ts                                    │
│                  │                                                       │
│                  └──▶  prisma.apiKey                                     │
│                                                                          │
│  a router, service, and Prisma model                                     │
└──────────────────────────────────────────────────────────────────────────┘
```

Becomes: `src/services/api-keys.ts`

## Endpoints

`auth` is required on every row, including `public` — an endpoint whose
audience nobody decided is an endpoint everyone can call.

| Endpoint | Purpose | Auth |
| --- | --- | --- |
| `POST /v1/api-keys/rotate` | Issue a new key; the old one keeps working for the grace window. | the current API key |
| `GET /v1/api-keys` | List the account's keys, prefix and status only — never the secret. | the current API key |
| `DELETE /v1/api-keys/{id}` | Revoke a key immediately, ending its grace window. | the current API key |

## Background work

| Job | Trigger | When it fails |
| --- | --- | --- |
| `expire-grace-windows` | hourly schedule | Logged and retried next hour; a missed run leaves an old key valid slightly longer, which is why the window is stored as an absolute time rather than a countdown. |

## Data model

```
┌────────────────────────────┐
│ ApiKey                     │
│ ────────────────────────── │
│ id            String       │
│ accountId     String       │
│ prefix        String       │
│ hash          String       │
│ expiresAt  DateTime?       │
└────────────────────────────┘
```

## Choices

| Where | Choice | Why this one | Not |
| --- | --- | --- | --- |
| api-keys | `argon2id` | Keys are stored hashed like passwords; argon2id is the default the rest of the service already uses. | `sha256` |

## Blast radius

```
new (4)
  ├── src/routes/api-keys.ts
  ├── src/services/api-keys.ts
  ├── src/schemas/api-keys.ts
  └── test/api-keys.test.ts

changed (2)
  ├── src/routes/index.ts
  └── prisma/schema.prisma
```

## Verification plan

- [ ] `npm run type-check`
- [ ] `npm run lint`
- [ ] `npm run plan-lint`
- [ ] `npm run test`
- [ ] `verify` — run it against a real environment, not only the test suite

---

Approve this before any file is written. Every table and frame above is
rendered from this feature's plan JSON, so the document and the build cannot
drift — and the fields the validator insists on (auth on every endpoint,
idempotency on every webhook, a failure path on every job) are the ones that
are expensive to discover in production.
