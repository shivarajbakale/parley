# EXAMPLE_SUPERPLAN.md — the habit-tracker superplan, walked through

The worked example for [`docs/SUPERPLAN.md`](SUPERPLAN.md). Six routes,
all five archetypes, every validator rule exercised. Copy this when you
need to bootstrap a superplan from scratch.

The fixture is `tool/fixtures/habit-tracker.super-plan.json`. The
rendered `SUPERPLAN.md` lives at `tool/fixtures/super-plan-test/habit-tracker.SUPERPLAN.md`.
The renderer and lint both run against this file in `make superplan-lint`.

## The brief

> A daily habit tracker with streaks, daily check-in, and reminders.

That's the whole brief. The superplan turns it into six routes,
twenty-five components with `why` attachments, eight mock endpoints,
two shared entities, two shared providers, and a six-step build sequence.

## The app block

```json
"app": {
  "name": "Habit Tracker",
  "oneLiner": "A daily habit tracker with streaks, daily check-in, and reminders.",
  "problem": "People who want to build a habit forget to do it on day two. …",
  "targetUsers": "Adults forming one to three new habits at a time, comfortable with a phone, not comfortable with a journal.",
  "industry": "health-wellness",
  "nonGoals": ["Social features.", "Analytics dashboards.", "Habit libraries."],
  "mvp": {
    "in": ["Today's habits list", "Add / edit / delete", "Stats tab", "Local notifications"],
    "out": ["Cloud sync", "Apple HealthKit / Google Fit", "Premium tier"]
  }
}
```

The shape every app block has to clear:

- `problem` — at least one full sentence. A superplan without a problem
  is a domain model with no app.
- `targetUsers` — who, specifically. A superplan that does not name who
  it is for designs for nobody.
- `industry` — names the entry in `docs/references/industry-conventions.md`
  the design language comes from. "health-wellness" here is the
  peak-end / safety-trust pairing the conventions doc names.
- `nonGoals[]` — what is intentionally out. Without these, every
  reasonable extension is in scope by default.
- `mvp.in[]` and `mvp.out[]` — both required. An MVP without an explicit
  out-list grows to fill the screen.

## The route map

Six routes, three tabs, three pushed:

```
Home shell
  ├─ /habits           Today (tab 1, focal)
  ├─ /habits/new       New habit (pushed, form)
  ├─ /habits/:id       Habit detail (pushed, detail)
  ├─ /habits/:id/edit  Edit habit (pushed, form)
  ├─ /stats            Stats (tab 2, settings)
  └─ /settings         Settings (tab 3, settings)
```

The V6 rule is the one this exercises: `navigation.tabs` is the union of
`routes[].tab`. Drop a tab from `navigation.tabs` without removing the
route that uses it — the validator fires "X is declared but no route
uses it". Add a route with `tab: "Phantom"` — the validator fires
"Phantom is used but not in tabs".

## The routes

Each route is a self-contained block. Every one of them clears the
seven validator rules:

### `home` (focal)

```json
{
  "id": "home",
  "route": "/",
  "name": "Today",
  "tab": "Today",
  "archetype": "focal",
  "purpose": "one hero (today's date + ring), then a bento of the three habits due",
  "primaryAction": "Add habit",
  "lookAndFeel": {
    "panels": [
      { "kind": "hero", "title": "Mon · Mar 4", "subtitle": "2 of 3 done" },
      { "kind": "tile", "title": "Read 10 pages", "badge": "5d" },
      { "kind": "tile", "title": "Stretch" },
      { "kind": "wide", "title": "Drink water · 1l today" }
    ],
    …
  },
  "bestPractices": {
    "components": [
      {
        "control": "DSLargeAppBar",
        "why": "It carries the date+count subtitle and pushes back under scroll, which makes the bento the content rather than a header chrome strip",
        "rejected": "a custom AppBar with a CircularProgressIndicator drawn in it"
      }
    ]
  },
  "apis": { … },
  "states": { "loading": "Six skeleton rows …", … },
  "blastRadius": { "new": ["…"], "changed": ["…"] },
  "sprint": { "order": 1, "depends": [], "size": "M" }
}
```

What the per-route validator rules catch here:

- **V1** — focal starts with a `hero` panel and the bento under it has
  two sizes (`tile` and `wide`). Drop the `wide` and the validator
  rejects it as "the bento of one tile size" — the same defect
  `docs/principles/screen-archetypes.md` is named after.
- **V2** — every route has `loading | empty | error | success`. The
  copy is reviewable before it is written.
- **V4** — every `bestPractices.components[]` entry has a `why` of at
  least 12 characters and a `rejected` neighbour. The plan that
  approved the choice can be diffed.

### `habit-list` (collection)

A pushed route on top of the home shell. The list panel exercises the
collection-specific panel shape: `search`, `filters`, `swipe`,
`swipeTwin`, `rows`. `states.zeroResults` joins the four-state set
because "nothing matched" and "nothing exists" are two different
screens with two different things to do about them.

### `habit-detail` (detail)

Pinned primary (Edit) above the safe area. The archetype rule that
"primary pins above the safe area on a chrome surface and does not
scroll away" is what `DSPinnedActionBar` exists for; a `primaryAction:
"Edit"` without `DSPinnedActionBar` would fail the per-feature plan
later, but at the superplan layer the validator only checks that the
field is named.

### `habit-edit` (form)

One column of fields, full-width primary above the safe area. The form
archetype's panel vocabulary is one panel with a `fields[]` array — a
second panel with fields is "form is one column" failing V1.

### `stats` (settings)

The Settings archetype makes a fine home for grouped statistics —
eyebrow + rows per group, with `DSProgressRing` per habit. The example
has no entities (stats reads through the habits repository) and one
endpoint.

### `settings` (settings)

Settings archetype, three groups (Reminders, Appearance, About). The
`auth: false` note in `apis.endpoints[]` is the absence of a key —
the schema does not require auth on every endpoint.

## The shared bit

```json
"sharedEntities": [
  { "name": "Habit", "note": "id, name, createdAt, reminderTime, daysOfWeek, …" },
  { "name": "Completion", "note": "id, habitId (FK), date, createdAt" }
],
"sharedProviders": [
  "habitsRepositoryProvider — owns CRUD + completion writes",
  "notificationServiceProvider — schedules daily local notifications"
],
"sharedMocks": [
  "GET /habits/today → list of { habit, completion }",
  …
]
```

`routes[].apis.entities[]` is a list of strings that resolve into
`sharedEntities[]` by name, or inline `{name, fields: [...]}` objects
when the entity is local to the route. The V3 rule catches a string
that resolves to nothing.

## The sprint ordering

```json
"sprint": { "order": 1, "depends": [], "size": "M" }
```

| # | Route | Size | Depends on |
| --- | --- | --- | --- |
| 1 | `home` | M | — |
| 2 | `habit-list` | M | `home` |
| 3 | `habit-detail` | L | `habit-list` |
| 4 | `habit-edit` | L | `habit-detail` |
| 5 | `stats` | M | `home`, `habit-list` |
| 6 | `settings` | S | `home` |

`sprint.order` is unique across the superplan (V5). `sprint.depends`
references route ids that exist in the same superplan — never module
names, never external system names. The table at the bottom of the
rendered `SUPERPLAN.md` is just this list, sorted by `order`.

## What the gate holds together

Running `make superplan-lint` against this fixture, with each route
referenced by a `feature_list.json` entry whose notes field starts with
`route:<id>`, exits clean. Drop the notes field on one entry and the
lint exits non-zero with **S4**: "route X is declared in SUPERPLAN.json
but no feature_list.json entry references it". Reference a route id
that is not in the superplan and the lint exits non-zero with **S5**:
"the feature is tracking a route that does not exist".

## Hand-edit a sentence to test the gate

Open the rendered `SUPERPLAN.md` and fix a typo in any line. Run
`make superplan-lint`. The exit code is 1 and the message starts with
**[S2]**: "SUPERPLAN.md does not match a fresh render of SUPERPLAN.json.
The document is generated — never hand-edit it." That is the hand-edit
check: the document approved in review and the document the JSON
produces have to be the same bytes.
