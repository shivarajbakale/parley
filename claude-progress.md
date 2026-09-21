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
  `personal-dictionary`. Slice 1 is done: `electron/dictionary.ts` builds the
  Whisper prompt and applies sounds-like rules, `electron/dictionary-store.ts`
  keeps `dictionary.json` in userData, and `electron/session.ts` uses both.
  There is no UI yet, so the dictionary can only be filled by editing that
  file.
- Next step: run `plan-feature` for the Dictionary settings tab (table, inline
  add row, import and export), get it approved, then build it with the IPC
  channels `dictionary:list`, `dictionary:upsert` and `dictionary:remove`.
  That slice also migrates the `vocabulary` setting into entries and removes
  its textarea from the General tab. After it: snippets, pill text mode with
  add-by-voice, learning from corrections, on-screen context.
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
