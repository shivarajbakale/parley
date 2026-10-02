# AGENTS.md

An Express + TypeScript API on Prisma and SQLite, built for long-running
agent work.

- **Stack:** Express 4, TypeScript (strict), Prisma + SQLite, Zod, Winston.
- **Entry point:** `src/server.ts` -> `src/app.ts` -> `src/routes/index.ts`.
- **The map:** [ARCHITECTURE.md](ARCHITECTURE.md).

This is the contract. It is read in full at the start of every session, so it
holds what you must not get wrong — not how the code works, and not what already
happened, which is the commit log.

## Start here

```
./init.sh        # install, create the SQLite schema, verify — the session-start command
make check       # type-check, lint, plan-lint, db-lint, api-lint, test, e2e, boot-check
make dev         # run it
make help        # everything else
```

There is no database server and no Docker. `DATABASE_URL` is a `file:` URL, which
is what makes every gate above runnable on a clean clone.

## Hard constraints

Each one names what goes wrong without it. A rule that cannot name its failure
does not belong on this list.

1. **One feature in flight.** Exactly one `in_progress` in `feature_list.json` —
   because two half-finished features leave a tree nobody can verify or revert
   as a unit.
2. **No `passing` without verification you actually ran**, recorded in the
   feature's `evidence` — because a status nobody executed is a status the next
   session has to redo from scratch.
3. **An endpoint is not verified until the server served it.** Boot it and
   capture a real request and response — because green unit logic and a working
   route are different claims, and only one of them is what a caller gets.
4. **Every response leaves through `transformResponse`** as
   `{ data, meta: { timestamp, statusCode } }` — because a second shape makes
   every client branch on which endpoint it called.
5. **Every write validates through `validate(schema)` in the route** — because
   validation inside a controller runs after the request is already being
   handled, which is where inconsistent 400s come from.
6. **Only services touch Prisma, through the single client in
   `config/database.ts`** — because a second client opens a second pool against
   a single-writer SQLite file, and a controller that queries directly cannot be
   reused or tested without HTTP.
7. **Expected failures are `throw new AppError(message, statusCode)`** from
   `src/middleware/error.middleware.ts`, and async handlers are wrapped in
   `asyncHandler` — because an unwrapped rejected promise never reaches the
   error handler and the request hangs.
8. **Never weaken or delete a test, the envelope, or a Zod schema to look
   complete** — because a deleted test converts a known failure into an unknown
   one.
9. **Do not climb the validation hierarchy while a lower level is red** —
   because a green level 3 on top of a red level 1 measured nothing.
10. **Repository artifacts are the system of record, not chat** — because chat
    dies on context reset and the register does not.
11. **A feature reaching `passing` becomes a commit** — because work that is
    verified but uncommitted is work the next session cannot trust or revert.

`feature_list.json` uses four states: `not_started`, `in_progress`, `blocked`
(with the blocker written down) and `passing` (verification ran, evidence
recorded). `passing -> not_started` is forbidden; a regression gets its own new
entry, because a silently reverted status hides that something broke.

## The loop

1. `pwd`, then read `claude-progress.md` — the current state and the next step.
2. Read `BLUEPRINT.md`. While it is an unapproved stub and the user has
   described an API, filling it in *is* the work — see
   [docs/BLUEPRINT.md](docs/BLUEPRINT.md). Do not touch `feature_list.json` yet.
3. Pick the highest-priority unfinished feature from `feature_list.json`.
4. `git log --oneline -5`.
5. `./init.sh`. If the baseline is already red, fix that first.
6. Work that one feature until it verifies or you document why it is blocked.

## Skills and the team

Reach for a skill in `.claude/skills/` instead of improvising — each one copies
the **Todo** reference slice and ends by running the app.

| Skill | When |
| --- | --- |
| `add-resource` | a whole REST resource, end to end |
| `add-endpoint` | one action on a resource that already exists |
| `plan-feature` | before either of those, when the shape is not settled |
| `use-express-api` | you need a server capability and are not sure which call, package or layer it takes |
| `connect-frontend` | a browser client has to call this server, or its requests are failing CORS |
| `verify` | prove a change works by driving the running server |

Three subagents in `.claude/agents/` own the work outside coding; delegate
through the Agent tool. **product-manager** turns a brief into an approved
blueprint and a sequenced register. **api-designer** designs and then reviews an
endpoint's contract, which `type-check` and `test` cannot judge. **devops** boots
the server, exercises endpoints, and owns "can we ship it". Hand off through repo
artifacts, not chat.

## Validation hierarchy

```
Level 1: npm run type-check && npm run lint   (must pass)
Level 2: npm run test                         (must pass — no database)
Level 3: RUN_DB_TESTS=1 npm run test          (must pass when the change touches an endpoint or the DB)
```

## Before you stop

1. Record the evidence for anything you completed and set its status in
   `feature_list.json`.
2. Rewrite `claude-progress.md` — it is the state now, not a log.
3. Walk `clean-state-checklist.md`.
4. `make check`.
5. `make commit-feature`. It finds any feature that is `passing` now and was not
   in `HEAD`, runs `make check`, and commits with that feature's own evidence as
   the message. It does nothing when nothing was completed, so running it is
   never wrong, and it never pushes.

## Where everything else is

| Read this | When |
| --- | --- |
| [ARCHITECTURE.md](ARCHITECTURE.md) | you need the layout, the request flow, or the layer rules |
| [docs/CONSTRAINTS.md](docs/CONSTRAINTS.md) | you are adding a dependency or changing the envelope or error model |
| [docs/API_CONTRACT.md](docs/API_CONTRACT.md) | a browser client is talking to this server — origins, credentials, cookies, the envelope, the error shape |
| [docs/FEATURES.md](docs/FEATURES.md) | you are adding a resource and want the recipe |
| [docs/EXAMPLE_FEATURE.md](docs/EXAMPLE_FEATURE.md) | you want that recipe run end to end |
| [docs/BLUEPRINT.md](docs/BLUEPRINT.md) | the API shape is not settled yet |
| [DECISIONS.md](DECISIONS.md) | you are about to undo something deliberate |
| [docs/loops/](docs/loops/) | you are driving a feature through maker/checker cycles |
| [evaluator-rubric.md](evaluator-rubric.md) | you are judging whether work is good, not merely done |
