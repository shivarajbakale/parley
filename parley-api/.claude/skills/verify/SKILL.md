---
name: verify
description: Prove an API change actually works by type-checking and driving the running server — not just reading the diff. Run before declaring any non-trivial change done. Use after add-resource/add-endpoint or any change with runtime behavior.
---

# verify — don't declare done until it serves

A change is not done because it compiles. Observe the server actually handling
the request end-to-end.

## The loop

1. **Type-check** — `npm run type-check` (`tsc --noEmit`). Zero errors. Fix and
   repeat; never suppress with `any` or `@ts-ignore`.
2. **Schema in sync** — if you touched `prisma/schema.prisma`, run
   `npm run db:push` then `npm run db:generate` so the client matches the models.
3. **Boot and drive** — `npm run dev` starts the server (ts-node-dev). Then
   actually hit the changed route:
   ```bash
   curl -s localhost:3000/api/health          # server is up
   curl -s localhost:3000/api/<resources>     # your new endpoint
   ```
   Confirm the happy path returns what you expect, and one error path behaves
   (e.g. a missing id returns a 404 shaped by the central error handler, not a
   stack trace).
4. **Test (if the harness is present)** — some generated apps keep Vitest +
   supertest, some strip it. When the test tooling is present (a vitest config +
   a test directory at the root), run the suite with a real db:
   ```bash
   RUN_DB_TESTS=1 npm test
   ```
5. **Lint (preferred)** — `npm run lint`.

## Report

State exactly what you ran and what you observed (e.g. "POST /api/notes → 201 with
the created row; GET /api/notes/999 → 404"). If a step was skipped (e.g. no test
harness in this generated app), say so. Do not report success on the diff alone.
