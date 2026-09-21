# Progress Log

## Current Verified State

- Repository root: this repo (parley).
- Standard startup path: `./init.sh`.
- Standard verification path: `make check`.
- `parley-001`, `parley-002` and `parley-003` are `passing`. `parley-004`
  remains `in_progress`: `docs/MANUAL_CHECKLIST.md` exists and covers every
  manual step (paste targets, gesture, onboarding from a clean state,
  System Settings deep links, a real Groq key and an invalid key, errors,
  the tray, and offline behaviour), but nobody has walked it yet — walking it
  requires `make dev` and cannot be done from this session. `make check`
  passes on the current tree.
- Plan: docs/superpowers/plans/2026-09-21-parley-v1.md. All twelve plan tasks
  have been implemented; the only step left before v1 can be called complete
  is walking `docs/MANUAL_CHECKLIST.md` by hand and recording its evidence on
  `parley-004`.
- Blueprint approved by the user on 2026-09-21 (design spec). Next step after
  `parley-004` passes: the "Out of v1" list in
  `docs/superpowers/specs/2026-09-21-parley-design.md`.
- Current blocker: none — `parley-004` is waiting on a human running
  `make dev` and walking the checklist, not on any code change.

## Session Log

### Session 001 — Scaffolded from harness-core

- Date: 2026-07-01
- Goal: Establish a clean, verifiable baseline for agent-driven work.
- Completed: Project scaffolded with a complete harness (AGENTS.md, CLAUDE.md,
  init.sh, Makefile, feature_list.json, and the continuity/checklist artifacts).
- Verification: run `./init.sh` and confirm it exits 0.
- Next action: read `feature_list.json`, pick the highest-priority unfinished
  feature, and implement exactly one before stopping.
