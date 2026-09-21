---
name: plan-feature
description: Turn a feature request into a reviewable FEATURE-PLAN.md — ASCII wireframes of every surface, the four states drawn, the component choices justified, integration points and blast radius — then gate on approval before writing a single file. Use whenever the user asks for a feature, a screen, or a resource and there is more than one defensible way to build it.
---

# plan-feature — plan the screen before you build it

The first reviewable artifact for a feature used to be a diff. By then the
layout argument is expensive: the code exists, the tests exist, and changing
`Tabs` to a sidebar rail means rewriting all three.

This skill moves the review to where changes are free. You produce a plan the
user can read in one pass — including pictures of the screens — and you do not
touch `src/` until they approve it.

## When to skip

Skip for a one-line copy fix, a bug with an obvious cause, or a change the user
has already specified down to the file. Planning something already decided is
ceremony. Everything else — a new resource, a new screen, a new pane on an
existing screen — gets a plan.

## Procedure

### 1. Interview — the product first, the shape second

Ask about the problem before the implementation. What can't the user do today?
Who hits it? What happens now instead? Ask about anything genuinely ambiguous
that would change the build (does this need to be linkable? who can see it?
what happens to the old records?) — but make the routine calls yourself. Two
or three real questions, not an interrogation.

### 2. Choose the archetype for each surface

`PageShell` declares one of exactly four, and `ui-probe` rules B1–B4 assert the
shape against the real DOM at three widths. Pick deliberately:

| Archetype | For |
| --- | --- |
| `list-detail` | browse a set, act on one without losing the set |
| `dashboard-grid` | at-a-glance tiles + a chart |
| `form` | a single focused editing column |
| `centered-card` | auth and other no-shell screens |

### 3. Choose each control, and record what it beat

Read `.claude/skills/use-mantine/mantine-capabilities.md` for the `Use when:` /
`Instead:` line on each component family, and
`docs/principles/component-selection.md` for the families where three of them
are all defensible. Every entry in
`components[]` needs a `why`, and the validator rejects a blank one — an
unjustified choice is the thing this plan exists to surface.

### 4. Write the plan JSON

Copy `scripts/__fixtures__/invoices.feature-plan.json` and edit it. Shape:

- `feature` — `id`, `title`, `problem`, optional `nonGoals[]`
- `surfaces[]` — `archetype`, `panels[]`, `states{loading,empty,error,success}`
- `overlays[]` — dialogs, sheets, drawers
- `components[]` — `{surface, control, why, rejected}`
- `entities[]`, `endpoints[]`, `integration[]`, `blastRadius{new,changed}`
- `nav[]` — override only if this app's rail differs from `src/config/nav.ts`

Write it to `<feature-id>.feature-plan.json` at the repo root.

### 5. Render and present

```bash
node scripts/feature-plan.mjs <feature-id>.feature-plan.json -o FEATURE-PLAN.md
```

Show the user the rendered document. Do not paraphrase it — the wireframes are
the point, and they only work if they are looked at.

### 6. Gate

Ask for approval before implementing. In Claude Code that is `ExitPlanMode`.
If the user changes something, edit the JSON and re-render — never hand-edit
`FEATURE-PLAN.md`, which is generated and will be overwritten.

### 7. Implement against the approved plan

Hand off to `add-feature`, `add-page`, `add-form`, or `add-table` with the
choices already made: the archetype goes into `PageShell`'s `archetype` prop,
`components[]` decides the controls, `states{}` is the copy, `blastRadius`
is the file list. Register the feature in `feature_list.json` and keep
`FEATURE-PLAN.md` next to it as the spec.

## Why the wireframes are trustworthy

They are rendered from the plan JSON, not drawn. The renderer is covered by a
golden-output test, so a template cannot drift without a test going red. And
the frames key off the same `archetype` vocabulary `PageShell` declares and
`ui-probe` enforces — so the shape you approve is the shape the gate checks
once the screen exists.

## Definition of done for this skill

- `FEATURE-PLAN.md` rendered and shown.
- The user approved it, or asked for changes which were made in the JSON.
- No file under `src/` written before that approval.
- The feature is registered in `feature_list.json`.
- `npm run plan-lint` is green.

## The gate behind this skill

`plan-lint` runs inside `make check`, so the three rules above stop being
etiquette:

| Rule | What it catches |
| --- | --- |
| P1 | A plan the renderer would refuse to draw — a control choice with no `why`, a surface missing one of the four states, an archetype the geometry forbids. |
| P2 | A hand-edited `FEATURE-PLAN.md`. The document is generated; if it no longer matches a fresh render of its source JSON, the plan that was approved and the plan that is tracked have quietly diverged. |
| P3 | A `FEATURE-PLAN.md` with no source JSON — prose wearing a generated filename, impossible to re-render or diff. |
| P4 | A plan whose `feature.id` nobody registered in `feature_list.json`, so nothing will ever verify it. |

The gate is inert on a project with no plans. It bites the moment you write one,
which is when the drift starts.
