# SUPERPLAN.md — the app-level plan, above `BLUEPRINT.md`

This document is the **protocol** for the superplan: what it is, what it
owns, and what it deliberately does *not* own. The worked example is in
[`EXAMPLE_SUPERPLAN.md`](EXAMPLE_SUPERPLAN.md); the rendered artifact in
your project is `SUPERPLAN.md` at the project root.

## What it is

A superplan is the initializer artifact the Flutter harness produces from
a one-paragraph app brief, **before any feature is built**:

- **every route** the app needs,
- with **plan** (archetype, primary action, the four states, blast
  radius),
- **look-and-feel** (panels, header, motion, dark-mode notes),
- **layout** (the region skeleton — which kit owns `header`,
  `body.scroll`, `body.form`, `footer`, `fab` — and the scroll
  strategy),
- **components** (the per-route DS kit manifest: `kit`, `region`,
  `purpose`, `why`, `rejected[]`, `a11y`, `props`),
- **best practices** (accessibility, design-system rules, verification,
  non-goals),
- **APIs required** (entities, endpoints, providers, integration
  points),
- **gestures** (`selector × event × behavior × haptic × transition`),
- **journeys** (the named paths through the app, happy and not),

— all in one document, all generated from one source-of-truth JSON,
all wired into the gate (`make superplan-lint`).

## Where it sits

```
BLUEPRINT.md (one-screen at-a-glance)
   └─►  SUPERPLAN.md (per-route spec; this protocol)
            └─►  <id>.feature-plan.json  +  FEATURE-PLAN.md  (per-feature wireframe)
                    └─►  lib/  (the build)
```

Three planning artifacts, three scopes:

| Layer | Document | Owns |
| --- | --- | --- |
| App | `BLUEPRINT.md` | one-screen summary — at-a-glance |
| App | `SUPERPLAN.md` | the per-route spec, end to end |
| Feature | `FEATURE-PLAN.md` | phone-frame wireframes + states per feature |

The superplan is what `BLUEPRINT.md` cannot be: detailed enough to be
buildable, without forcing a per-feature planning round-trip for every
screen before the app's shape has been agreed. The per-feature
`FEATURE-PLAN.md` is what `SUPERPLAN.md` cannot be: detailed enough to be
implementable, without baking the per-route spec into the larger plan.

## What it is *not*

- **Not a wireframe replacement.** `FEATURE-PLAN.md` still renders the
  phone-frame wireframes per feature. The superplan renders a phone frame
  *per route* — the same vocabulary, at a coarser grain.
- **Not a ticketing tool.** The superplan has `sprint.order` and
  `sprint.depends[]`, but the build sequence is also held in
  `feature_list.json`. The two are kept in sync by `superplan-lint` rule
  S4: a route nobody tracked and nobody deferred is a route nobody will
  ever build.
- **Not a Figma replacement.** This is a structural document, not a
  visual one. The visual vocabulary is owned by the design system;
  `lookAndFeel.header` and `lookAndFeel.motion` point at it by name.
- **Not for one feature at a time.** The per-feature artifact is
  `plan-feature`. The superplan is the moment *before* the app has any
  features — when the brief is at the app level.

## The JSON schema

`SUPERPLAN.json` is the source of truth. Top-level shape:

| Key | Purpose |
| --- | --- |
| `app` | `name`, `oneLiner`, `problem`, `targetUsers`, `industry` (feeds `docs/references/industry-conventions.md`), `nonGoals[]`, `mvp{ in[], out[] }` |
| `decisions[]` | the interview, on the record — one entry per call that shaped the plan: `question`, `answer`, `source` (`user` \| `assumed`), and `why` when it was assumed. Rendered first, above the MVP cut |
| `navigation` | bottom-nav `tabs[]` + optional `ascii` tree |
| `modules` | the five cross-cutting seams (`auth`, `onboarding`, `paywall`, `analytics`, `push`), each `required | none | deferred` |
| `theme` | `palette`, `typography`, optional `tokens[]` |
| `routes[]` | the route inventory — one entry per route; see the route-entry table below |
| `sharedEntities[]` | cross-route entity definitions, referenced by name from `routes[].apis.entities[]` |
| `sharedProviders[]` | Riverpod providers that live outside any one widget tree |
| `sharedMocks[]` | mock route signatures (mirrors `lib/data/mock/mock_routes.dart`) |
| `dependencies[]` | new pubspec additions with justifications |
| `openQuestions[]` | decisions the initializer flagged for the user, never silently resolved |
| `revision` | ISO date + revision label |

### A route entry

| Key | Purpose |
| --- | --- |
| `id`, `route`, `name`, `purpose` | identity — `id` is what `feature_list.json` notes reference as `route:<id>` |
| `archetype` | one of the fifteen in `docs/principles/screen-archetypes.md`; the same list `feature_plan.dart` owns |
| `tab` | the bottom-nav tab this route mounts under, when it is a top-level destination |
| `states` | `loading`, `empty`, `error`, `success` — plus `zeroResults` for `collection` |
| `lookAndFeel` | `panels[]` (the wireframe), `header`, `motion`, `darkMode` |
| `layout` | `regions[]` — each `{ name, kit | kits[] }` over the region vocabulary (`header`, `body.scroll`, `body.list`, `body.form`, `body.section`, `body.bento`, `body.tile`, `body.eyebrow`, `footer`, `fab`) — plus the scroll strategy |
| `components[]` | the DS kit manifest: `kit`, `region`, `purpose`, `why` (>= 12 chars), `rejected[]`, `a11y`, `props`. Every `kit` must exist in `tool/fixtures/ds-catalog.json`. **May be left empty when `lookAndFeel.panels[]` is filled** — the renderer derives the manifest from the panel kinds (`hero → DSCard`, `tile`/`wide` → `DSListTile`, `list → DSSearchBar + DSChipGroup + DSDismissibleTile`, `section`/`eyebrow-row` → `DSSettingsSection`, `field-set → DSTextField` per field) so the same kit is not written twice |
| `bestPractices` | `accessibility`, `designSystemRules[]`, `verification`, `nonGoals[]` |
| `apis` | `entities[]` (by name, resolving into `sharedEntities[]`), `endpoints[]` (`method`, `path`, `auth`, `purpose`), `providers[]`, `integration` |
| `gestures[]` | `selector`, `event`, `behavior` (all required), plus `haptic` and `transition` |
| `journeys[]` | `name`, `trace` (one string, the path through the app; both required), `happy` |
| `blastRadius` | the files and seams this route touches |
| `sprint` | `order` (unique across the plan), `size` (`S | M | L`), `depends[]` (route ids in the same plan) |

> `bestPractices.components[]` is the **pre-flutter-045** shape. The
> validator rejects it with a migration message: move every entry to the
> top-level `components[]` above.

## How it is generated

```bash
make superplan
```

This calls `dart run tool/super_plan.dart SUPERPLAN.json -o SUPERPLAN.md`.
The renderer is dependency-free (`dart:io` and `dart:convert`, nothing
from pub) so a project that has not yet had `flutter pub get` can still
render its superplan.

## How it is gated

```bash
make superplan-lint
```

Two rule sets, and they are numbered separately on purpose. The **V
rules** live in `tool/super_plan.dart` and answer "is this JSON a
superplan?" — they run on every render and every `--check`. The **S
rules** live in `tool/superplan_lint.dart` and answer "does this
project's superplan still describe this project?" — they run on the
tree.

The interview is the reason the split matters. Step 1 of the `superplan`
skill is *ask two or three questions before choosing the route map* — and
for a long time it was the only step of this primitive that produced no
artifact, so it was the only step no rule could check. An agent filling
the fields the validator names had no field that said *ask*, and a plan
written for the user without consulting them passed every gate. The
`decisions[]` block is that field: V10 checks its shape, and S8 refuses a
plan in which nothing was ever the user's call.

Validator (`dart run tool/super_plan.dart <plan> --check`):

| Rule | What it catches |
| --- | --- |
| V0 | the top-level shape — `app`, `navigation`, `modules`, `routes[]` present and well formed |
| V1 | `archetype` is one of the fifteen, and the archetype owns its panels (a `focal` needs a hero and a bento of two sizes; a `collection` needs search, filters, swipe and a swipe twin; `detail` and `form` need a named primary; `settings` needs an eyebrow per group; a `shelf` needs two named rails; a `session` needs a stage, a transport and an escape and pins nothing; a `canvas` needs a ground and a sheet with two or three detents; a `confirmation` needs an identifier and a dated next step; a `conversation` needs one transcript panel with two speakers in it, a composer, a retry and an empty, and pins nothing; an `editor` needs one document panel, an autosave sentence, an undo, an exit, and pins nothing; a `schedule` needs one day panel, a window, an empty day and a way to add) |
| V2 | every route declares `loading`, `empty`, `error`, `success` — and `zeroResults` when it is a `collection` |
| V3 | endpoints are unique across the plan, and every entity reference resolves to a `sharedEntities[]` entry |
| V4 | every `components[]` entry has a `kit` in the DS catalog, a `purpose`, a known `region` and a `why` of at least 12 characters — and the route has at least one component, explicitly or derivable from `lookAndFeel.panels[]`. The pre-flutter-045 `bestPractices.components[]` shape is rejected here |
| V5 | `sprint.depends[]` resolves to route ids in the same plan, `sprint.order` is unique, `sprint.size` is `S | M | L` |
| V6 | `navigation.tabs[]` is exactly the union of `routes[].tab` — a declared-but-unrouted tab and a routed-but-undeclared tab both fail |
| V7 | `layout.regions[]` name a known region and cite a `kit` (or `kits[]`) that exists in the DS catalog |
| V8 | every `gestures[]` entry has a `selector`, an `event` and a `behavior` |
| V9 | every `journeys[]` entry has a `name` and a `trace` |
| V10 | every `decisions[]` entry has a `question`, an `answer` and a `source` of `user` or `assumed` — and an assumed one carries a `why` of at least 12 characters. The validator checks the shape only; whether an interview happened at all is S8's job |

Gate (`make superplan-lint`):

| Rule | What it catches |
| --- | --- |
| S1 | `SUPERPLAN.json` fails the validator above |
| S2 | a hand-edited `SUPERPLAN.md` — the committed bytes do not match a fresh render of the JSON |
| S3 | an orphan `SUPERPLAN.md` with no `SUPERPLAN.json` beside it |
| S4 | a route no `feature_list.json` entry references, and that is not in `app.mvp.out` |
| S5 | a feature whose notes references a `route:<id>` that does not exist in the superplan |
| S6 | `tool/fixtures/ds-catalog.json` is missing — without it every `kit:` reference in the plan is unverified |
| S7 | a route that does not cite the kit its archetype requires (a `form` without `DSPinnedActionBar` loses its primary on every scroll; a `collection` without `DSDismissibleTile` has no swipe) |
| S8 | a plan with no `decisions[]`, or one where every entry is `assumed` — the plan was written for the user without asking them anything |

`superplan-lint` runs as part of `make check`, so the gate is part of
the project a user receives, not a step they remember to run.

## Worked example

[`EXAMPLE_SUPERPLAN.md`](EXAMPLE_SUPERPLAN.md) walks through the
habit-tracker superplan end to end — six routes across all five
archetypes, with the JSON and the rendered `SUPERPLAN.md` side by side.
