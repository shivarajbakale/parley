# Progress Log

## Current Verified State

- Repository root: this repo (parley).
- Standard startup path: `./init.sh`.
- Standard verification path: `make check`.
- `parley-001`, `parley-002` and `parley-003` are `passing`. `parley-004`
  (dictation by hand) and `parley-005` (voice edit) are `blocked` on a human
  walking `docs/MANUAL_CHECKLIST.md` with `make dev`; no code is pending on
  either. Both are merged to `main`, along with the waveform pill and the
  glass sounds.
- `parley-006` (personal dictionary) is `in_progress` on branch
  `personal-dictionary`. Done so far: the core (`electron/dictionary.ts`,
  `electron/dictionary-store.ts`, used by `electron/session.ts`), and learning
  from corrections: after a dictation `electron/correction-watcher.ts` re-reads
  the field, `electron/correction-detect.ts` decides whether one word was
  respelled, and `electron/word-offer.ts` asks on the pill
  (`src/orb/Notice.tsx`) and takes one clean tap of the dictation key as yes.
  None of the learning path has been tried in the real app yet; the manual
  steps are the "Personal dictionary" section of `docs/MANUAL_CHECKLIST.md`.
- Next step: have the user walk that section, tune the detector on what they
  report, then run `plan-feature` for the Dictionary settings tab (table,
  inline add row, import and export, the learning toggle, migration of the
  `vocabulary` setting). After it: snippets, add-by-voice, on-screen context.
- A second worktree, `.claude/worktrees/explain-selection`, belongs to other
  work. Its untracked `explain-selection.feature-plan.json` and
  `FEATURE-PLAN.md` in the repo root fail `plan-lint` (P4) and were left
  alone; `vite.config.ts` now keeps `.claude/**` out of the test run.
- Current blocker: none.

## Session Log

### Session 001 — Scaffolded from harness-core

- Date: 2026-07-01
- Goal: Establish a clean, verifiable baseline for agent-driven work.
- Completed: Project scaffolded with a complete harness (AGENTS.md, CLAUDE.md,
  init.sh, Makefile, feature_list.json, and the continuity/checklist artifacts).
- Verification: run `./init.sh` and confirm it exits 0.
- Next action: read `feature_list.json`, pick the highest-priority unfinished
  feature, and implement exactly one before stopping.
