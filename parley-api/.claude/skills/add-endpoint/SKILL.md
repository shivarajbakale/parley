---
name: add-endpoint
description: Add a single new endpoint/action to an existing resource — one service method + one controller handler + one route (plus a Zod schema if it takes a body). Use when the user wants one action, not a whole resource (e.g. "archive a todo", "search orders", "mark as read").
---

# add-endpoint — one action on an existing resource

For a whole new resource use `add-resource`. This is the small case: add one
verb to a resource that already exists. The **Todo** slice has worked examples of
every route shape you'll need.

## The three edits (four with a body)

1. **Service method** — add a method to the resource's service
   (`src/services/<resource>.service.ts`). Do the Prisma work there; throw
   `AppError` from `src/middleware/error.middleware.ts` on not-found / bad state.
   Never put data access in the controller.
2. **Controller handler** — add a handler to
   `src/controllers/<resource>.controller.ts`, wrapped in `asyncHandler` so
   thrown errors reach the central `errorHandler`. Read params/body, call the
   service, return the result.
3. **Route** — register it in `src/routes/<resource>.routes.ts`. Match the verb
   and path to intent (e.g. `router.patch('/:id/archive', archive)`). Look at
   `src/routes/user.routes.ts` for the toggle / bulk / search patterns.
4. **Validation (only if it takes a body)** — add a Zod schema to
   `src/types/<resource>.types.ts` and guard the route with
   `validate(<schema>)` from `src/middleware/validate.middleware.ts`. See how
   `src/routes/user.routes.ts` applies `validate(...)` on POST/PUT.

## Rules

- Responses flow through the response transformer already wired in `src/app.ts` —
  just return data from the controller; don't hand-format the envelope.
- Read config from `src/config/env.ts`, never `process.env` directly.
- A GET that lists should paginate the way the Todo list endpoint does.

## Verify

`npm run type-check`, then `npm run dev` and exercise the new route with curl (or
the app). Confirm the happy path and one error path (e.g. a 404 for a missing id).
Run the `verify` skill for the full bar.
