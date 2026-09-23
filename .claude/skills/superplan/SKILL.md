---
name: superplan
description: Turn a one-paragraph app brief into SUPERPLAN.md — every route the app needs with its plan, look-and-feel, best practices, and APIs required, generated from one source-of-truth JSON and gated by its own lint — before any feature plan or any file under lib/. Use whenever the user describes a new app (or a substantial redesign of one) and there is more than one route to plan. Triggers on app briefs, not per-feature requests.
---

# superplan — draw the app before you build any feature

The first reviewable artifact for a feature used to be its `FEATURE-PLAN.md`
(see `plan-feature`). What sits above that — the app-level plan that names
every route, every shared entity, every module choice, every dependency —
had no artifact of its own. The agent filled `BLUEPRINT.md` from the brief
alone, which silently baked the user's app into one screen of tables and
forced a per-route planning round-trip for every screen.

This skill moves the review to where changes are still free. You produce
one superplan the user can read end to end — including phone-frame
wireframes of every route — and you do not touch `lib/` until they
approve it. The superplan is the gate that sits between `BLUEPRINT.md`
(the one-screen at-a-glance) and the per-feature `FEATURE-PLAN.md`.

## When to skip

Skip for a bug fix, a copy change, a tweak to an existing screen, or a
single new feature on an app that already has a superplan. Planning what is
already approved is ceremony. The superplan is for the moment *before* the
app has any routes — when the brief is at the app level.

## Procedure

### 1. Interview — the app first, the routes second

Ask about the problem before the implementation. What can't the user do
today? What do they do instead? Who are they? Ask about anything genuinely
ambiguous that would change the route map (does this need an account?
does it work offline? does it have notifications? does the user pay?). Two
or three real questions, not an interrogation.

Read `docs/references/industry-conventions.md` and
`docs/principles/emotional-design.md` for the design language the industry
and emotional-stage choice pulls from. `app.industry` in the JSON should
name the industry directly.

**Write the answers down as you get them.** Every call that shapes the
route map goes into `decisions[]`:

```json
{ "question": "Does a habit need an account, or does it live on the device?",
  "answer": "On the device. No auth in the MVP.",
  "source": "user" }
```

`source` is `user` when they answered it and `assumed` when you decided
for them; an `assumed` entry needs a `why`. There is no third case — a
decision you made quietly is `assumed`, and writing it as one is the
whole point. `superplan-lint` S8 fails a plan with no `decisions[]`, and
fails one where every entry is `assumed`: a plan nobody was consulted on
is a plan nobody agreed to.

This is not paperwork about the interview — it *is* the interview's
artifact. Skipping step 1 used to cost nothing because it left no trace;
now it fails a gate. Do not fill `decisions[]` retroactively from what
you already decided. That is the failure this rule exists to catch, and
it converts a real question into a fabricated answer.

### 2. Choose the route map

A route is a single screen the user can land on. Tab roots and pushed
routes both count. Three is a good MVP floor, six is a sane ceiling; if the
map is larger, the question is "what is in `app.mvp.out`?", not "what is
in `app.mvp.in`?". The superplan's job is to make the cut explicit.

### 3. Choose the archetype for each route

`docs/principles/screen-archetypes.md` declares exactly seven, every demo
screen names its own in its doc comment, and
`test/screens/archetypes_test.dart` holds them to it once they exist. Pick
deliberately:

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

A screen that is two archetypes is two screens. The same vocabulary is
used at the per-feature layer so the wireframe cannot drift.

### 4. Choose each widget, and record what it beat

Read `docs/references/design-system-reference-llms.txt` for the
`Use when:` / `Instead:` line on each widget, and
`docs/principles/component-selection.md` for the families where three are
all defensible — sheet vs dialog vs snack bar, tab vs segmented button,
which of the three loading states. Read `tool/fixtures/ds-catalog.json`
(regenerate with `make ds-catalog`) for the kit names the plan is allowed
to cite — a `kit` outside it is rejected.

Every entry in the route's top-level `components[]` needs a `why`
(>= 12 chars), and the validator rejects a blank one: an unjustified
choice is the thing this plan exists to surface. `components[]` is
**top-level on the route**, not under `bestPractices` — the
`bestPractices.components[]` of the pre-flutter-045 shape is rejected
with a migration message.

You may leave `components[]` empty when `lookAndFeel.panels[]` is filled:
the renderer derives the manifest from the panel kinds (`hero` -> DSCard,
`tile`/`wide` -> DSListTile, `list` -> DSSearchBar + DSChipGroup +
DSDismissibleTile, `section`/`eyebrow-row` -> DSSettingsSection,
`field-set` -> DSTextField per field) so the same kit is not written
twice. Derived manifests are a floor, not a ceiling — name the kit
explicitly wherever the choice was actually a decision.

### 5. Write the superplan JSON

Copy `tool/fixtures/habit-tracker.super-plan.json` and edit it. Shape:

- `app` — `name`, `oneLiner`, `problem`, `targetUsers`, `industry`,
  `nonGoals[]`, `mvp{ in[], out[] }`
- `navigation` — `tabs[]`, optional `ascii` tree
- `modules` — every one of `auth`, `onboarding`, `paywall`, `analytics`,
  `push` declared as `required | none | deferred`
- `theme` — `palette`, `typography`, optional `tokens[]`
- `routes[]` — one entry per route, with:
  - `lookAndFeel` — `panels[]` (same vocabulary as `feature-plan`),
    `header`, `motion`, `darkMode`
  - `layout` — `regions[{name, kit | kits[]}]` over the region vocabulary
    (`header`, `body.scroll`, `body.list`, `body.form`, `body.section`,
    `body.bento`, `body.tile`, `body.eyebrow`, `footer`, `fab`)
  - `components[]` — **top-level on the route**, one entry per DS kit:
    `{kit, region, purpose, why, rejected[], a11y, props}`. Every `kit`
    must exist in `tool/fixtures/ds-catalog.json`
  - `bestPractices` — `accessibility[]`, `designSystemRules[]`,
    `verification[]`, `nonGoals[]`. It no longer owns `components[]`
  - `apis` — `entities[]` (string refs into `sharedEntities` or inline
    objects), `endpoints[{method, path, auth, purpose}]`, `providers[]`,
    `integration[{from, to, note}]`
  - `states` — `loading`, `empty`, `error`, `success`, plus `zeroResults`
    for `collection`
  - `gestures[]` — `{selector, event, behavior}` required, plus `haptic`
    and `transition`
  - `journeys[]` — `{name, trace}` required, plus `happy`
  - `blastRadius` — `new[]`, `changed[]`
  - `sprint` — `order`, `depends[]`, `size: S|M|L`, `gate[]`
- `sharedEntities[]`, `sharedProviders[]`, `sharedMocks[]`,
  `dependencies[]`, `openQuestions[]`, `revision`

Write it to `SUPERPLAN.json` at the project root.

The validator enforces each archetype's own shape, not just the common
fields, plus uniqueness on `routes[].id`, `routes[].sprint.order`, and
`routes[].apis.endpoints[]`; plus that `navigation.tabs` is the union of
`routes[].tab`; plus that every `routes[].apis.entities[]` string ref
resolves to `sharedEntities[]`.

### 6. Render and present

```bash
make superplan
```

Show the user the rendered `SUPERPLAN.md`. Do not paraphrase it — the
frames are the point, and they only work if they are looked at.

### 7. Gate

Ask for approval before implementing. In Claude Code that is
`ExitPlanMode`. If the user changes something, edit the JSON and re-render
— never hand-edit `SUPERPLAN.md`, which is generated and will be
overwritten.

### 8. Hand off to feature planning

A passing superplan has a route map, but no per-route plans yet. Walk the
`routes[]` entries by `sprint.order`, and for each route run the
`plan-feature` skill. That produces the per-feature `FEATURE-PLAN.md` and
the `feature_list.json` entries that the superplan's `route:<id>` markers
reference. `make superplan-lint` is the gate that holds the two layers
together.

## Why the frames are trustworthy

They are drawn from the superplan JSON, not free-drawn. The renderer is
covered by tests that assert every phone frame is square, that the same
JSON renders the same bytes, and that the worked example (habit-tracker,
six routes across all five archetypes) reproduces exactly — so a template
cannot drift without a test going red. The frames key off the same five
archetypes the principles document declares and the per-feature screen
suite enforces, so the shape approved at the app level and the shape
approved per feature cannot disagree.

## Definition of done for this skill

- The interview happened, and `decisions[]` records it — at least one
  entry with `source: "user"`, and a `why` on every assumption.
- `SUPERPLAN.md` rendered and shown.
- The user approved it, or asked for changes which were made in the JSON.
- No `*.feature-plan.json` written, no `lib/` file written before that
  approval.
- Each route has been handed off to `plan-feature`, the per-feature plans
  exist, and `feature_list.json` references `route:<id>` for each route.
- `dart run tool/superplan_lint.dart` is green.

## The gate behind this skill

Two numbered rule sets, and they answer different questions. The **V
rules** live in `tool/super_plan.dart` — "is this JSON a superplan?" —
and run on every render and every `--check`. The **S rules** live in
`tool/superplan_lint.dart` — "does this project's superplan still
describe this project?" — and run on the tree.

The validator, which is what stops a render:

| Rule | What it catches |
| --- | --- |
| V0 | The top-level shape — `app`, `navigation`, `modules`, `routes[]` present and well formed. |
| V1 | An archetype outside the fifteen, or an archetype that does not own its panels (a `focal` with no hero, a `collection` with no swipe twin, a `form` with no named primary, a `shelf` with one rail, a `session` that pins a primary, a `canvas` sheet with one detent, a `confirmation` with no identifier). |
| V2 | A route missing one of `loading` / `empty` / `error` / `success` — or a `collection` missing `zeroResults`, because nothing matched and nothing exists are two different screens. |
| V3 | Two routes claiming the same endpoint, or an entity reference that resolves to nothing in `sharedEntities[]`. |
| V4 | A `components[]` entry with no `kit` in the DS catalog, no `purpose`, an unknown `region`, or a `why` under 12 characters — and a route with neither `components[]` nor `lookAndFeel.panels[]` to derive them from. The pre-flutter-045 `bestPractices.components[]` shape is rejected here with a migration message. |
| V5 | A `sprint.depends[]` pointing at no route, a duplicated `sprint.order`, or a `sprint.size` outside `S`/`M`/`L`. |
| V6 | A tab declared in `navigation.tabs[]` that no route mounts under, or a `routes[].tab` that the navigation never declared. |
| V7 | A `layout.regions[]` entry naming an unknown region, citing no kit at all, or citing a kit the DS catalog does not have. |
| V8 | A `gestures[]` entry missing its `selector`, `event` or `behavior` — the renderer draws the table either way, so without this rule a blank cell shipped as a plan. |
| V9 | A `journeys[]` entry missing its `name` or its `trace`. |
| V10 | A `decisions[]` entry with no `question`, no `answer`, a `source` outside `user`/`assumed`, or an assumption with no `why`. |

The gate, which is what stops `make check`:

| Rule | What it catches |
| --- | --- |
| S1 | A superplan the renderer would refuse to draw — a route missing states, a widget choice with no `why`, a tab union that does not match. |
| S2 | A hand-edited `SUPERPLAN.md`. The document is generated; if it no longer matches a fresh render of its source JSON, the superplan that was approved and the superplan that is tracked have quietly diverged. |
| S3 | A `SUPERPLAN.md` with no source JSON — prose wearing a generated filename, impossible to re-render or diff. |
| S4 | A route nobody tracked (`feature_list.json` notes) and nobody deferred (`app.mvp.out` mentions `route:<id>`). A route nobody will ever build. |
| S5 | A feature built against a route id that does not exist in `SUPERPLAN.json` — the feature's scope was never checked against the app-level plan. |
| S6 | The DS catalog is missing (`tool/fixtures/ds-catalog.json`) — every `kit:` reference is unverified. `make ds-catalog` regenerates it from `lib/design_system/`. |
| S7 | A route that is missing an archetype-required kit — a form without `DSPinnedActionBar` loses its primary on every scroll; a collection without `DSDismissibleTile` has no swipe. |
| S8 | A plan with no `decisions[]` at all, or one where every entry is `assumed`. The interview is the one step that used to leave no trace, which made it the one step nothing could check. |

The gate is inert on a project with no superplan. It bites the moment you
write one, which is when the drift starts.
