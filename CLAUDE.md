<!-- agent-protocol -->
> **Agent working protocol:** read [AGENTS.md](AGENTS.md) before coding and
> [ARCHITECTURE.md](ARCHITECTURE.md) before touching the wire. Session state is
> `feature_list.json` + `claude-progress.md`. Start with `./init.sh`, verify with
> `make check`.

# CLAUDE.md

[AGENTS.md](AGENTS.md) is the contract and this file does not repeat it. Below is
only what is specific to running as Claude Code here.

## Hooks are watching

- **SessionStart** prints the current state. A red baseline is the first fix.
- **Stop** blocks if a feature reached `passing` and the work is uncommitted, and
  runs `make check` and evidence-lint, then commits. `HARNESS_STRICT=0` skips that;
  `ROCKETSHIP_AUTOCOMMIT=0` switches the tier off, and neither ever pushes.

## What bites here

- Accessibility and Microphone grants follow the app's signature. Build with
  your own identity in `macos/Local.xcconfig` (gitignored) or they reset every
  build. If System Settings shows Parley Native on but the app still says no,
  remove the entry and add it again.
- The Electron Parley may still be installed in /Applications. The native app
  refuses to start its engine while it runs: both would answer the same keys.
- Logs: `log show --last 5m --info --predicate 'subsystem == "com.shivarajbakale.parley.mac"'`.

Verification beats speed: done means `make check` green and the real app used.
