# AGENTS.md

A Flutter app with a built-in harness, a design system, and a ship-fast module
layer, built for long-running agent work.

- **Stack:** Flutter (Dart 3.5+), Riverpod, go_router, Dio with
  `http_mock_adapter`, Drift, SharedPreferences.
- **Entry point:** `lib/main.dart` -> `lib/app.dart` -> `lib/utils/app_router.dart`.
- **The map:** [ARCHITECTURE.md](ARCHITECTURE.md).

This is the contract. It is read in full at the start of every session, so it
holds what you must not get wrong — not how the code works, and not what already
happened, which is the commit log.

## Start here

```
./init.sh      # pub get and verify — the canonical session-start command
make check     # setup, analyze, ui-lint, plan-lint, design-system-reference, test
make dev       # flutter run
make help      # everything else
```

The app runs with no backend: `useMockBackend` in `lib/data/api_config.dart`
routes Dio through `http_mock_adapter`.

## Hard constraints

Each one names what goes wrong without it. A rule that cannot name its failure
does not belong on this list.

1. **One feature in flight.** Exactly one `in_progress` in `feature_list.json` —
   because two half-finished features leave a tree nobody can verify or revert
   as a unit.
2. **No `passing` without verification you actually ran** — because a status
   nobody executed is a status the next session has to redo from scratch.
3. **A screen is not verified until the app ran on a device and left a frame
   behind.** `make run-capture` boots it and writes the screenshot; **devops**
   drives from there — because `analyze` and `test` never launch the app.
4. **A screen's design gets reviewed before it goes `passing`,** against
   [docs/principles/premium.md](docs/principles/premium.md). Delegate to
   **designer** — for the same reason: nothing in the toolchain grades a
   layout, and seven defects shipped green because nobody looked.
5. **Do not build auth, payments, or observability from scratch.** They ship as
   interfaces with mock defaults; read [docs/MODULES.md](docs/MODULES.md) —
   because rebuilding one means two auth paths, and the gate only knows about
   the one in `service_config.dart`.
6. **Screens and providers depend on service interfaces, never a concrete SDK** —
   because `service_config.dart` is the single swap point, and a direct SDK
   import in a screen turns a one-file change into a search.
7. **Build screens out of the design system, not out of Material** — because
   the DS widget is where validation, press motion, haptics and the loading
   states live, and a hand-rolled control has none of them. `make ui-lint`
   fails the build and names the widget to use; `// ui-lint: allow <rule-id> —
   <reason>` is the way to say an exception is real. What the kit already owns
   is listed in `docs/references/design-system-reference-llms.txt` — read it
   before composing a screen, and run `make design-system-reference-update`
   after adding a component, which is also where its `Use when:` / `Instead:`
   guidance is written. The **Components** tab in the running app is the same
   catalog at real size, one page per widget with its usages live; a new
   component needs stories there too, which
   `test/screens/design_system_gallery_test.dart` enforces.
8. **Colours, spacing, radii and durations are tokens** from `lib/theme/` —
   because a literal survives a re-theme and then looks wrong.
9. **The design system depends on the theme and nothing above it** — because a
   widget that reaches into a provider cannot be reused or previewed alone.
10. **Models are pure Dart, with no Flutter imports** — because a widget binding
   in the domain makes it untestable without one.
11. **Never weaken or delete a test to look complete** — because a deleted test
    converts a known failure into an unknown one.
12. **Do not climb the validation hierarchy while a lower level is red** —
    because a green level 3 on top of a red level 1 measured nothing.
13. **Repository artifacts are the system of record, not chat** — because chat
    dies on context reset and the register does not.
14. **A feature reaching `passing` becomes a commit** — because work that is
    verified but uncommitted is work the next session cannot trust or revert.

`feature_list.json` uses four states: `not_started`, `in_progress`, `blocked`
(with the blocker written down) and `passing` (verification ran, evidence
recorded). `passing -> not_started` is forbidden; a regression gets its own new
entry, because a silently reverted status hides that something broke.

## The loop

1. `pwd`, then read `claude-progress.md` — the current state and the next step.
2. Read `BLUEPRINT.md`. While it is an unapproved stub and the user has
   described an app, filling it in *is* the work — see
   [docs/BLUEPRINT.md](docs/BLUEPRINT.md). Do not touch `feature_list.json` yet.
3. Pick the highest-priority unfinished feature from `feature_list.json`.
4. `git log --oneline -5`.
5. `./init.sh`. If the baseline is already red, fix that first.
6. Work that one feature until it verifies or you document why it is blocked.

## Skills and the team

| Skill | When |
| --- | --- |
| `add-feature` | a full slice: model, API client, Riverpod state, screen, route, test |
| `add-screen` | a standalone routed screen wired into go_router and the shell |
| `add-component` | a widget joining `lib/design_system/` — style chain, barrel, selection guidance, story, test, golden |
| `fix-gate` | a red `make check` — which gate, what it claims, and the fix rather than the loosening |
| `verify` | prove a change works — analyze, test, run the app |
| `ship` | release to the stores, after sweeping for placeholders and signing |

Three subagents in `.claude/agents/` own the work outside coding; delegate
through the Agent tool. **product-manager** turns a brief into an approved
blueprint and a sequenced register. **designer** picks the layout template and
reviews the built screen. **devops** owns `make run-capture`, reads the frame it
leaves, and owns flavors, signing and release. Hand off through repo
artifacts, not chat.

## Validation hierarchy

```
Level 1: flutter analyze       (must pass)
Level 2: flutter test          (must pass)
Level 3: make ui-probe         (every surface, in a binding with no platform)
Level 3+: make run-capture     (the app on a real device; it fails, never skips)
```

## Before you stop

1. Record the evidence for anything you completed and set its status in
   `feature_list.json`.
2. Rewrite `claude-progress.md` — it is the state now, not a log.
3. Walk `clean-state-checklist.md`.
4. `make check`.
5. `make commit-feature`. It finds any feature that is `passing` now and was not
   in `HEAD`, runs `make check`, and commits with that feature's own evidence as
   the message. It never pushes.

## Where everything else is

| Read this | When |
| --- | --- |
| [ARCHITECTURE.md](ARCHITECTURE.md) | you need the layout, the layer rules, or the startup flow |
| [docs/MODULES.md](docs/MODULES.md) | you are about to touch auth, payments, or observability |
| [docs/CONSTRAINTS.md](docs/CONSTRAINTS.md) | you are adding a dependency or changing the theme tokens |
| [docs/FEATURES.md](docs/FEATURES.md) | you want the build recipe and the page-layout templates |
| [docs/EXAMPLE_FEATURE.md](docs/EXAMPLE_FEATURE.md) | you want that recipe run end to end |
| [docs/UX.md](docs/UX.md) | you are judging whether a screen is good, not merely done |
| [docs/principles/](docs/principles/) | you are choosing a control, a spacing, a motion, a material, or a screen shape |
| [docs/references/design-system-reference-llms.txt](docs/references/design-system-reference-llms.txt) | you need to know what the kit already owns |
| [DESIGN.md](DESIGN.md) | a tool outside this repo needs the tokens — generated from `lib/theme/spec/`, never edited |
| [lib/screens/design_system/](lib/screens/design_system/) | you would rather see the kit than read it — the Components tab |
| [DECISIONS.md](DECISIONS.md) | you are about to undo something deliberate |
| [docs/loops/](docs/loops/) | you are driving a feature through maker/checker cycles |
