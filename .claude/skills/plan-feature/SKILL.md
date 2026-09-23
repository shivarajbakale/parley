---
name: plan-feature
description: Turn a feature request into a reviewable FEATURE-PLAN.md — phone-frame wireframes of every surface, the states drawn, the widget choices justified, integration points and blast radius — then gate on approval before writing a single file under lib/. Use whenever the user asks for a feature, a screen or a tab and there is more than one defensible way to build it.
---

# plan-feature — draw the screen before you build it

The first reviewable artifact for a feature used to be a diff. By then the
layout argument is expensive: the screen exists, its widget test exists, its
golden baseline exists, and moving the primary action means rewriting all
three.

This skill moves the review to where changes are still free. You produce a plan
the user can read in one pass — including pictures of the screens — and you do
not touch `lib/` until they approve it.

## When to skip

Skip for a one-line copy fix, a bug with an obvious cause, or a change the user
has already specified down to the file. Planning something already decided is
ceremony. Everything else — a new tab, a new screen, a new section on an
existing screen — gets a plan.

## Procedure

### 1. Interview — the product first, the shape second

Ask about the problem before the implementation. What can't the user do today?
What do they do instead? Ask about anything genuinely ambiguous that would
change the build (does this need a route of its own? does it work offline? what
happens to what is already stored?) — but make the routine calls yourself. Two
or three real questions, not an interrogation.

### 2. Choose the archetype for each surface

`docs/principles/screen-archetypes.md` declares exactly seven, every demo screen
names its own in its doc comment, and `test/screens/archetypes_test.dart` holds
them to it once they exist. Pick deliberately:

| Archetype | For |
| --- | --- |
| `focal` | the first thing after launch — one hero at scale, then a bento of two sizes |
| `collection` | a list of things: search, chip strip, pull-to-refresh, swipe |
| `detail` | one of those things, with a pinned primary that cannot scroll away |
| `form` | data the user types — one column, full-width primary above the safe area |
| `settings` | preferences — grouped inset rows, platform-correct controls |
| `sequence` | one of several steps, in an order you chose — a tour, a wizard, a signup questionnaire |
| `offer` | where the user is asked to pay — outcome, at most three plans, one named purchase |
| `insight` | a number the app worked out, handed back — one figure, one chart, one sentence |
| `shelf` | ranked rails of things the app chose — a browse screen, one hero and named rails |
| `session` | something happening right now — playback, a workout, a timer: full bleed, one escape |
| `canvas` | a space with controls over it — a map under a sheet with named detents |
| `confirmation` | the end moment — what happened, its identifier, what happens next, one way onward |
| `conversation` | a transcript that grows from the bottom, and the composer it is written in |
| `editor` | work the user makes and comes back to — one document, an honest save state, undo one tap away |
| `schedule` | when something happens, read off the day — one day panel, a window, an empty day, a way to add |

A screen that is two archetypes is two screens. A Sequence step may be shaped
like a Form, but it is planned as a Sequence — its job, its progress and its
handover are what it is held to.

### 3. Choose each widget, and record what it beat

Read `docs/references/design-system-reference-llms.txt` for the `Use when:` /
`Instead:` line on each widget, and `docs/principles/component-selection.md`
for the families where three are all defensible — sheet vs dialog vs snack bar,
tab vs segmented button, which of the three loading states. Every entry in
`components[]` needs a `why`, and the validator rejects a blank one: an
unjustified choice is the thing this plan exists to surface.

### 4. Write the plan JSON

Copy `tool/fixtures/notes.feature-plan.json` and edit it. Shape:

- `feature` — `id`, `title`, `problem`, optional `nonGoals[]`
- `surfaces[]` — `archetype`, `panels[]`, `moments{peak,end}`,
  `states{loading,empty,error,success}`, `tab` when it is a tab root,
  `primaryAction`, `secondaryActions[]`. The peak is the one moment the user
  came for and the end is the last impression before they leave — named before
  the layout is drawn, because polish spent evenly is polish diluted
  (`docs/principles/emotional-design.md`)
- `overlays[]` — `dialog`, `alert-dialog`, `bottom-sheet`, `snap-sheet`, `menu`,
  `snack-bar`
- `components[]` — `{surface, control, why, rejected}`
- `entities[]`, `endpoints[]`, `integration[]`, `blastRadius{new,changed}`
- `tabs[]` — override only if this app's bottom nav differs from
  `lib/screens/home_screen.dart`

Write it to `<feature-id>.feature-plan.json` at the project root.

The validator enforces each archetype's own shape, not just the common fields:
a `focal` surface needs a hero and a bento of two sizes, a `collection` needs
search, filters, a swipe **and the tap target the swipe's action also lives
on**, plus a `zeroResults` state distinct from `empty`; a `detail` and a `form`
each have to name their pinned primary; a `settings` group needs an eyebrow; a
`sequence` needs two steps or more with a `job` on each — `brand`,
`segmentation`, `trust`, `activation`, `monetization` or `retention` — plus
`progress`, `back` and a named `handover`; an `offer` needs one `plans` panel
of at most three plans that each carry both `period` and `price`, plus
`outcome`, `billing`, `restore` and `terms`.

### 5. Render and present

```bash
make plan PLAN=<feature-id>.feature-plan.json
```

Show the user the rendered `FEATURE-PLAN.md`. Do not paraphrase it — the frames
are the point, and they only work if they are looked at.

### 6. Gate

Ask for approval before implementing. In Claude Code that is `ExitPlanMode`. If
the user changes something, edit the JSON and re-render — never hand-edit
`FEATURE-PLAN.md`, which is generated and will be overwritten.

### 7. Implement against the approved plan

Hand off to `add-feature` or `add-screen` with the choices already made: the
archetype goes into the screen's doc comment and decides its shape,
`components[]` decides the widgets, `states{}` is the copy, `blastRadius` is
the file list. Register the feature in `feature_list.json` and keep
`FEATURE-PLAN.md` next to it as the spec.

## Why the frames are trustworthy

They are drawn from the plan JSON, not free-drawn. The renderer is covered by
tests that assert every frame is square and that the same plan renders the same
bytes — so a template cannot drift without a test going red. And the frames key
off the same seven archetypes the principles document declares and the screen
suite enforces, so the shape approved here is the shape the gate checks once
the screen exists.

The frame draws the home indicator on purpose. "Bottom, full width, above the
safe area" is the single clearest difference between the mobile Form archetype
and the desktop pattern it is usually mistaken for, and a frame that does not
draw the safe area cannot show it.

## Definition of done for this skill

- `FEATURE-PLAN.md` rendered and shown.
- The user approved it, or asked for changes which were made in the JSON.
- No file under `lib/` written before that approval.
- The feature is registered in `feature_list.json`.
- `dart run tool/plan_lint.dart` is green.

## The gate behind this skill

`plan-lint` runs inside `make check`, so the rules above stop being etiquette:

| Rule | What it catches |
| --- | --- |
| P1 | A plan the renderer would refuse to draw — a widget choice with no `why`, a surface missing a state, a bento of six identical tiles. |
| P2 | A hand-edited `FEATURE-PLAN.md`. The document is generated; if it no longer matches a fresh render of its source JSON, the plan that was approved and the plan that is tracked have quietly diverged. |
| P3 | A `FEATURE-PLAN.md` with no source JSON — prose wearing a generated filename, impossible to re-render or diff. |
| P4 | A plan whose `feature.id` nobody registered in `feature_list.json`, so nothing will ever verify it. |

The gate is inert on a project with no plans. It bites the moment you write
one, which is when the drift starts.
