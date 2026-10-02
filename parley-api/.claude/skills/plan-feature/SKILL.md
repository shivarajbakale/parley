---
name: plan-feature
description: Turn a feature request into a reviewable FEATURE-PLAN.md — every surface named and drawn, every endpoint's audience decided, every webhook's duplicate handled, every job's failure path written down, blast radius listed — then gate on approval before writing a single file. Use FIRST for any non-trivial feature.
---

# plan-feature — decide the contract before you build it

The first reviewable artifact for a feature used to be a diff. By then the
argument is expensive: the route exists, the schema exists, the migration
exists, and discovering that the contract was wrong means redoing all three.

## When to skip

Skip for a one-line fix, a bug with an obvious cause, or a change the user has
already specified down to the file. Planning something already decided is
ceremony. Everything else gets a plan.

## The surfaces you can build on

| Kind | What it is |
| --- | --- |
| `endpoint` | a route handler plus its zod schema |
| `resource` | a router, service, and Prisma model together |
| `job` | a scheduled or queued task |

## Procedure

### 1. Interview — the problem first, the shape second

Ask what the user cannot do today and what happens instead. Ask about anything
genuinely ambiguous that would change the build. Two or three real questions,
not an interrogation.

### 2. Name every surface

A feature is rarely one thing. Name each piece and give it a kind — the kind
decides what the reviewer is shown, and the validator holds you to it.

A resource is a router, a service, a model and a migration. Naming it as one
surface keeps those four in the same review instead of four separate diffs.

### 3. Decide the contracts

The validator requires these because each one is expensive to discover later:

- **`auth` on every endpoint**, including `public`. An endpoint whose audience
  nobody decided is an endpoint everyone can call.
- **`idempotencyNote` on every webhook.** Delivery is at least once, so the
  same event arriving twice is normal traffic, not an edge case. Say what key
  or state makes the repeat a no-op.
- **`onFailure` on every job.** A retried job that fails forever is an outage
  nobody is paged for.
- **`fields` on every entity.** An entity with no fields is a name, not a model.
- **`why` on every choice.** An unjustified choice is the thing this document
  exists to surface, and the validator rejects a blank one.

### 4. Write the plan JSON

Copy `scripts/__fixtures__/api-keys.feature-plan.json` and edit it. Write it to
`<feature-id>.feature-plan.json` at the repo root.

### 5. Render and present

```bash
npm run feature-plan <feature-id>.feature-plan.json -- -o FEATURE-PLAN.md
```

Show the user the rendered document. Do not paraphrase it.

### 6. Gate

Ask for approval before implementing. In Claude Code that is `ExitPlanMode`. If
the user changes something, edit the JSON and re-render — never hand-edit
`FEATURE-PLAN.md`, which is generated and will be overwritten.

### 7. Implement against the approved plan

Hand off to the `add-*` skills with the decisions already made. Register the
feature in `feature_list.json` and keep `FEATURE-PLAN.md` beside it as the spec.

## Rules

- Don't over-build: the smallest surface that delivers the outcome wins.
- Validation lives in a zod schema at the edge, not in the handler body.
- A migration is part of the blast radius, not an afterthought.
- No file under `src/` before approval.

## The gate behind this skill

`plan-lint` runs inside `make check`, so the rules above stop being etiquette:

| Rule | What it catches |
| --- | --- |
| P1 | A plan the renderer would refuse to draw — a missing `auth`, a webhook with no idempotency note, a job with no failure path. |
| P2 | A hand-edited `FEATURE-PLAN.md`. The document is generated; if it no longer matches a fresh render of its source JSON, the plan that was approved and the plan that is tracked have quietly diverged. |
| P3 | A `FEATURE-PLAN.md` with no source JSON — prose wearing a generated filename. |
| P4 | A plan whose `feature.id` nobody registered in `feature_list.json`. |

The gate is inert on a project with no plans. It bites the moment you write one.

## Definition of done for this skill

- `FEATURE-PLAN.md` rendered and shown.
- The user approved it, or asked for changes which were made in the JSON.
- No file under `src/` written before that approval.
- The feature is registered in `feature_list.json`.
- `npm run plan-lint` is green.
