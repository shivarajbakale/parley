# parley-007 — guided onboarding: tour + setup wizard (in review → release)

First run is now a stage, not a tab: a 4-slide animated product tour
(`src/settings/tour/`), then a 6-step setup wizard (`src/settings/wizard/`)
covering mic, accessibility, Groq key, MiniMax (optional), hotkeys with live
capture + tap-tap-hold practice, and a real practice dictation — then the Done
screen lands on the normal Settings with a Ready moment. Design and
`FEATURE-PLAN.md` (11 surfaces) were approved 2026-09-22; the plan JSON is
`parley-007.feature-plan.json` at root.

## Current state

- Code complete on `main`, automated gates green (see Evidence in
  `feature_list.json`). `make check`'s probe phase hung once with frozen CPU
  and no output for 30+ min; killed and re-ran green standalone in under
  4 min — flake, not a code hang.
- `parley-007` stays `in_progress`: the 13-box "Onboarding tour + wizard"
  section in `docs/MANUAL_CHECKLIST.md` needs a human with `make dev`. Do not
  mark `passing` until that walk is recorded.
- Releasing as 0.3.0 (tag + local DMG) on automated verification + owner
  waiver, per explicit instruction. DMG builds into `release/0.3.0/`
  (gitignored, ad-hoc signed, no notarization — known limitation).
- `FEATURE-PLAN.md` at root now renders this feature's plan. The
  `explain-selection` source JSON is untouched and re-renderable; whoever
  merges second re-renders to resolve the shared-file conflict.
- The register shows three `in_progress` (parley-006 on branch
  `personal-dictionary`, explain-selection in its worktree, parley-007 here).
  Pre-existing single-flight violation; each lives on its own branch/tree.

## Settings shape (new)

- `settings.json` is versioned: `schemaVersion` envelope (renderer cannot read
  or write it), currently 1. v0 files migrate by gaining defaults.
- New sanitized settings: `tourSeen`, `wizardStep` (0–5 steps, Done at 6),
  `onboardingComplete`. Stage machine in `src/settings/wizard/stage.ts`;
  upgrades from 0.2.x see the tour once, then walk with values kept.

## Next step

Walk the onboarding checklist from a clean state
(`rm ~/Library/Application\ Support/parley/settings.json`, `make dev`), record
the evidence, then mark `passing` and let `make commit-feature` take it.
