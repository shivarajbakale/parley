# Clean State Checklist

Run through this before ending any session.

- [ ] `./init.sh` still works from a fresh shell (exits 0).
- [ ] `npm run type-check` exits 0.
- [ ] `npm run lint` exits 0.
- [ ] `npm run test` passes (Level 1+2).
- [ ] `RUN_DB_TESTS=1 npm run test` passes (Level 3) if any endpoint/DB code changed.
- [ ] `BLUEPRINT.md` reflects current scope (revisions noted if scope shifted).
- [ ] `claude-progress.md` has an entry for this session.
- [ ] `feature_list.json` reflects what is actually passing vs unverified, with evidence.
- [ ] Schema changes are reflected in `prisma/schema.prisma`, pushed (`make db`),
      and the client regenerated; destructive changes have a `DECISIONS.md` note.
- [ ] No half-finished step left undocumented (note it under "Broken Or
      Unverified" in `session-handoff.md` if you must stop mid-flight).
- [ ] No debug code remaining (`console.log`, commented-out blocks, `TODO(me)`).
- [ ] No temp files in the repo (`.env` stays local and gitignored; no scratch
      JSON, no `*.db` committed, no `dist/`).
- [ ] All intended changes are committed.
- [ ] The next session can continue without manual repair.
