# AGENTS.md

A premium, dark-first Electron desktop SaaS starter with a built-in harness and
a skills system, built for long-running agent work.

- **Stack:** Electron 30 (main, preload, renderer) on React 19 + TypeScript
  (strict) + Vite 5, TanStack Router and Query, Mantine 9 as the only styling
  system, React Hook Form + Zod, axios, MSW, Vitest, Storybook.
- **Entry point:** `electron/main.ts` opens the window;
  `src/main.tsx` -> `src/router/router.tsx` -> `src/App.tsx` is the renderer.
- **The map:** [ARCHITECTURE.md](ARCHITECTURE.md).

This is the contract. It is read in full at the start of every session, so it
holds what you must not get wrong — not how the code works, and not what already
happened, which is the commit log.

## Start here

```
./init.sh        # install and verify — the canonical session-start command
make check       # setup, type-check, lint, ui-lint, plan-lint, storybook-lint, test, ui-probe
make dev         # vite dev server plus the electron main process
make help        # everything else
```

The app runs with no backend: MSW answers every endpoint. Set
`VITE_ENABLE_MOCKING=false` in `.env` to point it at a real API.

## Hard constraints

Each one names what goes wrong without it. A rule that cannot name its failure
does not belong on this list.

1. **One feature in flight.** Exactly one `in_progress` in `feature_list.json` —
   because two half-finished features leave a tree nobody can verify or revert
   as a unit.
2. **No `passing` without verification you actually ran** — because a status
   nobody executed is a status the next session has to redo from scratch.
3. **Verify by running the app, not by reading the diff.** Use the `verify`
   skill — because a component that compiles and a screen that works are
   different claims.
4. **Plan a UI change before building it.** `plan-feature` renders a reviewable
   `FEATURE-PLAN.md` and `make plan-lint` fails an unplanned or hand-edited one
   — because a screen redesigned after it is built is a screen rebuilt twice.
5. **Every UI change clears the `ux-prepass` checklist** — because the defects
   it catches (dead space, rank inversion, an undesigned empty state) are
   invisible to type-check and tests.
6. **The shell is a fixed viewport.** Never add `overflow-y-auto` to a page or
   the shell — because a desktop window that scrolls as a whole reads as a web
   page in a box, and a second scroll region is the dual-axis scroll
   `make ui-probe` exists to catch.
7. **Use the component; do not hand-roll the primitive, and never write a
   utility class.** `make ui-lint` enforces both — a parallel style is a design
   system nobody can retune from one place, and this app emits no utility
   classes, so one would style nothing at all.
8. **Colours are theme values, never a hex** — for the same reason, and because
   the dark-first palette is retuned in `src/theme.ts`.
9. **Server data goes through a Query hook that calls a service**, and every
   endpoint has an MSW handler — because a `fetch` in a component cannot be
   cached, retried, or run without a backend.
10. **The renderer reaches the OS only through `electron/preload.ts`.** Use the
    `add-ipc-channel` skill — because widening that bridge is how an Electron
    app becomes a remote-code-execution surface.
11. **The traffic-light inset lives in two files.** `src/lib/platform.ts` and
    `electron/window-options.ts` — change them together, or the macOS window
    buttons land on top of your content.
12. **Never weaken or delete a test, a story, or a lint rule to look complete** —
    because a deleted test converts a known failure into an unknown one.
13. **Do not climb the validation hierarchy while a lower level is red** —
    because a green level 3 on top of a red level 1 measured nothing.
14. **Repository artifacts are the system of record, not chat** — because chat
    dies on context reset and the register does not.
15. **A feature reaching `passing` becomes a commit** — because work that is
    verified but uncommitted is work the next session cannot trust or revert.

`feature_list.json` uses four states: `not_started`, `in_progress`, `blocked`
(with the blocker written down) and `passing` (verification ran, evidence
recorded).

## The loop

1. `pwd`, then read `claude-progress.md` — the current state and the next step.
2. Read `BLUEPRINT.md`. While it is an unapproved stub and the user has
   described an app, filling it in *is* the work — see
   [docs/BLUEPRINT.md](docs/BLUEPRINT.md). Do not touch `feature_list.json` yet.
3. Pick the highest-priority unfinished feature from `feature_list.json`.
4. `git log --oneline -5`.
5. `./init.sh`. If the baseline is already red, fix that first.
6. Work that one feature until it verifies or you document why it is blocked.

## Skills

Reach for the skill that names your task instead of improvising it.

| Skill | When |
| --- | --- |
| `plan-feature` | **first**, for any UI work — renders a reviewable plan and gates on approval |
| `ux-prepass` | the seven-item checklist every UI change must clear |
| `add-feature` | a whole resource, end to end |
| `add-page` | a standalone routed screen that is not a data resource |
| `add-api-endpoint` | one service method, its MSW mock, and a query hook |
| `add-ipc-channel` | a renderer-to-main capability: files, dialogs, the OS |
| `add-ui-component` | a new design-system component or variant |
| `add-form` | React Hook Form + Zod over Mantine inputs |
| `add-table` | TanStack Table through the `data-table` composite |
| `add-chart` | charts through `@mantine/charts` |
| `add-settings` | a settings screen with sidebar navigation |
| `auth-page` | a login or signup screen |
| `wire-to-backend` | swap a resource's MSW mock for a real API |
| `verify` | prove a change works by running the app |

## Validation hierarchy

```
Level 1: make type-check && make lint        (must pass)
Level 2: make test                           (must pass)
Level 3: make ui-probe                       (real chromium, three viewports)
```

Levels 1 and 2 read text. Level 3 renders pixels and measures them, which is the
only way to catch dead space, dual-axis scroll, clipped labels and rank
inversions.

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
| [ARCHITECTURE.md](ARCHITECTURE.md) | you need the layout, the layer rules, or the reference slice |
| [docs/CONSTRAINTS.md](docs/CONSTRAINTS.md) | you are adding a dependency or changing the tokens |
| [docs/FEATURES.md](docs/FEATURES.md) | you want the build recipe step by step |
| [docs/EXAMPLE_FEATURE.md](docs/EXAMPLE_FEATURE.md) | you want that recipe run end to end |
| [docs/UX.md](docs/UX.md) | you are judging whether a screen is good, not merely done |
| [docs/principles/](docs/principles/) | you are choosing a control, a spacing, a motion, or a message |
| [DECISIONS.md](DECISIONS.md) | you are about to undo something deliberate |
| [docs/loops/](docs/loops/) | you are driving a feature through maker/checker cycles |
