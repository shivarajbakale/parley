<!-- agent-protocol -->
> **Agent working protocol:** read [AGENTS.md](AGENTS.md) before coding, and
> [ARCHITECTURE.md](ARCHITECTURE.md) before composing a screen. Session state is
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

- **Skills, in order: `plan-feature`, `add-ipc-channel` for anything crossing
  to main, `ux-prepass` last.** `make plan-lint` fails an unplanned change; a
  hand-written channel skips the preload contract and fails at the boundary
  test. The `use-mantine` skill routes a capability to its component.
- `src/lib/auth.ts` is a local demo shim, not a real auth client — swap the
  file, keep the exports. The macOS traffic-light inset is defined in both
  `src/lib/platform.ts` and `electron/window-options.ts`; change them together.

Verification beats speed: done means `make check` green and evidence written.
