# parley-014 / parley-015: monorepo and sync API (branch feat/parley-014-monorepo)

## What landed

- One clone: desktop app at root, `parley-agent/`, `parley-api/` (Express +
  Prisma + SQLite on :3100) and `parley-android/` (subtree merge, history
  kept). `./init.sh` installs all; `make check` runs all, skipping Android
  without flutter.
- Desktop sync: `electron/sync/` (client + engine; dictionary and settings,
  never keys, last writer wins) and a Settings > Sync tab.
- `parley-014` passing. `parley-015` in_progress: headless sync against the
  live API proven; the GUI walk is pending.

## Run the API

`make -C parley-api db` once, then `make -C parley-api dev`; inspect rows
with `make -C parley-api studio`.

## Next step

Walk the Sync block of `docs/MANUAL_CHECKLIST.md` with `make dev`, then
mark `parley-015` passing. Remains: the Android sync client and a key proxy.
`parley-013` still waits on its Act mode block (real model key).
