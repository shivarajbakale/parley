# CLAUDE.md

Read [AGENTS.md](AGENTS.md) first — it is the contract, and this file does not
repeat it. Below is only what is specific to running as Claude Code here.

## Hooks are watching

- **SessionStart** prints the current state. A red baseline is the first fix.
- **Stop** blocks if a feature reached `passing` and the work is uncommitted, and
  runs `make check` and evidence-lint, then commits. `HARNESS_STRICT=0` skips that;
  `ROCKETSHIP_AUTOCOMMIT=0` switches the tier off, and neither ever pushes.

## Skills and subagents

`.claude/skills/` holds `add-resource`, `add-endpoint`, `plan-feature` and
`verify`; `.claude/agents/` holds product-manager, api-designer and devops.
Invoke the skill that names your task and delegate the rest through the Agent
tool, rather than improvising either. Both are described in `AGENTS.md`.

## What bites here

- `AppError(message, statusCode)` takes the **message first**, and lives in
  `src/middleware/error.middleware.ts`, not in a `utils/` file.
- Level 2 tests must pass with no database; anything needing one goes behind
  `RUN_DB_TESTS=1`.
- SQLite rejects enums, scalar lists, `Json` and `@db.` types; Prisma accepts
  them at edit time, so `make db-lint` is what tells you.

Verification beats speed: done means `make check` green and evidence written.
