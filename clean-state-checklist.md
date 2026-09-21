# Clean State Checklist

Run through this before ending any session.

- [ ] `./init.sh` still works from a fresh shell.
- [ ] `make check` exits 0 (no tests deleted or weakened to get there).
- [ ] `claude-progress.md` has an entry for this session with real verification output.
- [ ] `feature_list.json` reflects what is actually passing vs unverified (evidence recorded).
- [ ] `DECISIONS.md` has an entry for any non-obvious choice made this session.
- [ ] No half-finished step left undocumented (note it under "Known risk").
- [ ] No debug code remaining (stray prints, `debugger`, commented-out blocks, `TODO(me)`).
- [ ] No temp files committed (scratch JSON, screenshots, `.swp`).
- [ ] All intended changes are committed.
- [ ] The next session can continue from repo artifacts alone, no chat needed.
