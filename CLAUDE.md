# CLAUDE.md

[AGENTS.md](AGENTS.md) is the contract and this file does not repeat it. Below
is only what is specific to running as Claude Code here.

## Hooks are watching

- **SessionStart** prints the current state. A red baseline is the first fix.
- **Stop** blocks if a feature reached `passing` and the work is uncommitted, and runs `make check` and evidence-lint, then commits. `HARNESS_STRICT=0` skips that; `ROCKETSHIP_AUTOCOMMIT=0` switches the tier off, and neither ever pushes.

## What bites here

- **`plan-feature` comes first for UI work** — `make plan-lint` fails an unplanned change — and **`add-form` before it** for any screen that collects input.
- **`superplan` comes first for an app.** When the brief is at the app level — "I want a habit tracker" —
  run the `superplan` skill before any `plan-feature`. `make superplan-lint` fails a superplan out of sync
  with `SUPERPLAN.json`, an orphan `SUPERPLAN.md`, or a route nobody tracked.
- **`doc-lint` holds the budget where the work happens.** Same nine rules as the root's `scripts/doc-lint.mjs`.
  `make doc-lint` is part of `check`; see [docs/doc-lint.md](docs/doc-lint.md).
- **Delegate the screenshot run and the design review** to the `designer` and `devops`
  subagents in `.claude/agents/`.
- Read [docs/references/design-system-reference-llms.txt](docs/references/design-system-reference-llms.txt)
  in one pass before composing a screen — it lists every atom the kit owns.
- `lib/services/service_config.dart` is the only place a concrete SDK import is chosen; an
  import anywhere else defeats the seam AGENTS.md constraint 6 names.
- Codegen: `models/` uses freezed + json_serializable, `data/local/` uses Drift. A model
  change needs `make gen`.

Verification beats speed: done means `make check` green and evidence written.
