---
name: add-resource
description: Scaffold a complete REST resource end-to-end (Prisma model → types+Zod → service → controller → routes → registration → test), mirroring the Todo reference slice. Use when the user asks to "add a resource", "build CRUD for X", "add an API for X", or "add an endpoint group" (e.g. Notes, Orders, Comments).
---

# add-resource — a full REST slice, the way this API already does it

This API ships one **reference resource**: **Todo**. It is implemented across
every layer. To add a resource, copy that slice and rename — do not invent a new
shape. Study the reference first.

## The reference slice (read these first)

| Layer | Todo file | What it is |
| --- | --- | --- |
| Prisma model | `prisma/schema.prisma` | the `Todo` model (the persisted shape) |
| Types + validation | `src/types/todo.types.ts` | Zod schemas (`createTodoSchema`, …) **and** the `z.infer` DTO types, co-located |
| Service | `src/services/user.service.ts` | data access via Prisma; throws `AppError` |
| Controller | `src/controllers/todo.controller.ts` | thin handlers wrapped in `asyncHandler` |
| Routes | `src/routes/user.routes.ts` | `validate(schema)` per route → controller |
| Registration | `src/routes/index.ts` | `router.use('/todos', todoRoutes)` |

Shared seams you will reuse, not copy: the Prisma client is `src/config/database.ts`
(services `import prisma from '../config/database'`); `asyncHandler` and `AppError`
both come from `src/middleware/error.middleware.ts`; request validation is
`validate(schema)` from `src/middleware/validate.middleware.ts`.

## Procedure

Work bottom-up (data → HTTP). Substitute your resource for `Todo`/`todo`/`todos`.

1. **Clarify the shape.** Ask for the resource name (singular + plural) and its
   fields if not given. Keep the first version small (3–6 fields).
2. **Prisma model** — add a `model <Resource>` to `prisma/schema.prisma` (copy the
   `Todo` model's structure: an `id`, your fields, `createdAt`/`updatedAt`). Then
   push the schema and regenerate the client:
   ```bash
   npm run db:push        # prisma db push — apply to the dev SQLite db
   npm run db:generate    # prisma generate — refresh the typed client
   ```
3. **Types + validation** — create `src/types/<resource>.types.ts` by copying
   `src/types/todo.types.ts`. Keep both halves: the Zod `create`/`update` schemas
   **and** the `z.infer<>` DTO types. The entity type itself comes from
   `@prisma/client` — `import { <Resource> } from '@prisma/client'`.
4. **Service** — create `src/services/<resource>.service.ts` by copying
   `src/services/user.service.ts`. Access `prisma.<resource>`, throw `AppError`
   (not raw `Error`) for not-found / bad input, and log via `../utils/logger`.
5. **Controller** — create `src/controllers/<resource>.controller.ts` by copying
   `src/controllers/todo.controller.ts`. Every handler stays thin and is wrapped
   in `asyncHandler` so errors reach the central `errorHandler`.
6. **Routes** — create `src/routes/<resource>.routes.ts` by copying
   `src/routes/user.routes.ts`. Attach `validate(<schema>)` before the handler on
   each mutating route.
7. **Register** — add one line to `src/routes/index.ts`:
   `router.use('/<resources>', <resource>Routes)`. The app mounts this router at
   `/api` (see `src/app.ts`), so your endpoints live at `/api/<resources>`.
8. **Test (if the app ships a test harness)** — some generated apps keep the
   Vitest + supertest setup, some strip it. When a test directory is present, add
   an e2e test for your resource by copying the Todo suite:
   ```bash
   ls test/todo.e2e.test.ts   # present? copy it to test/<resource>.e2e.test.ts
   ```
   These tests self-skip unless `RUN_DB_TESTS=1` (they hit a real SQLite db).

## Definition of done

Run the `verify` skill. Minimum bar: `npm run type-check` is clean, the resource's
CRUD works against a running server (`npm run dev`, then curl `/api/<resources>`),
and — if the test harness is present — the new e2e test passes under `RUN_DB_TESTS=1`.
Report what you added (one line per layer) and the verification result.
