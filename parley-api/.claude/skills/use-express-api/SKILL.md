---
name: use-express-api
description: >-
  Reach any Express capability the right way — map a capability (route,
  validation, async, error path, envelope, config, prisma, sqlite, cors, helmet,
  log, auth, background job) to the exact call, the package that provides it,
  the layer the code belongs in, and the gotcha. Use whenever a feature needs a
  server capability and you are not sure which call, which package, or which
  layer it takes.
---

# use-express-api — pick the right call, package, and layer

Express is small, which is the problem: almost nothing is enforced, and the
mistakes are all silent. Middleware in the wrong order swallows the routes below
it. An error handler that loses its fourth parameter stops being an error
handler. An `async` handler that throws without a wrapper hangs the request
forever. None of those is a type error, a lint error, or a failing test — they
are behaviour you only see from the client side.

## The map

The routing table is
`.claude/skills/use-express-api/express-capabilities.md`. Each row answers, for
one capability: **which call**, **which package**, **which layer**, **which
slice in this repo to copy**, and **the gotcha**. Start there — find the row
that matches what you want, or the closest one.

Below the table are the two things a table cannot hold: which layer is allowed
to do what, and the four conditions the error path depends on.

## Procedure

1. **Look up the capability** in
   `.claude/skills/use-express-api/express-capabilities.md`. If there is no
   exact row, take the closest and apply the same shape.
2. **Put the code in the layer the row names.** Data access is a service;
   request and response handling is a controller; anything that applies to more
   than one route is middleware. `npm run api-lint` fails a controller that
   touches `prisma`, reads `process.env`, or builds its own envelope.
3. **Copy the reference slice** rather than writing from a blank file. A row
   whose slice reads *(not wired…)* has no example here yet — build it, then
   replace that cell with the file you wrote.
4. **Add the dependency if the row names one you do not have.** The lint fails a
   wired row whose package is not in `package.json`, which is the check that
   stops a map from promising a library nobody installed.
5. **Run `npm run capability-lint`.** The map is a graded artifact: it fails on
   a row that names a symbol this stack does not expose, cites a package the
   project does not depend on, or points at a file that moved.
6. **Run `npm run check`.** A new route is not done until `api-lint`,
   `db-lint`, the tests and `boot-check` all pass.

## Rules

- The constraints this project will not bend are in `docs/CONSTRAINTS.md`, and
  `api-lint` enforces the mechanical half of them. Read it before adding a
  dependency or a second way to do something the repo already does once.
- Never read `process.env` outside `src/config/env.ts`.
- Never format an error body in a controller — throw `AppError` and let
  `src/middleware/error.middleware.ts` answer.
- A capability the map does not cover is a row to add, not a lookup to skip.
  Adding the row is part of building the feature, and the lint is what makes
  that true rather than aspirational.
