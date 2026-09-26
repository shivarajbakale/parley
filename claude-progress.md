# parley-013 — Act mode: voice commands handed to a Mastra agent (branch feat/parley-013-act)

A fourth gesture key (default ShiftRight) turns speech into a command for
the `parley-action` agent in a new sibling project: progress streams onto
the pill, each write-class tool waits for one tap, and the result lands as
one line or on the clipboard. Parley starts the server on launch and
supervises it (attach if answering, restart on crash); the Agent settings
tab shows health, mirrors a waiting approval with Approve/Decline, and
keeps the last failure standing. The plan is
`parley-013.feature-plan.json`, and `FEATURE-PLAN.md` is its render.

## Current state

- Implementation complete on `feat/parley-013-act`, automated gates
  green (see Evidence on parley-013 in `feature_list.json`): `make
  check` exit 0 (699 unit tests, ui-probe 136/136), the four Agent
  stories rendered in Chromium in dark and light with zero page errors,
  and the agent contract proven keyless end to end.
- `parley-013` stays `in_progress`: one human step remains — say
  "what are my notes" to `make dev` with a MiniMax key saved. The dummy
  answers with zero MCP setup; the fake-key run already proved the
  request reaches MiniMax correctly formed. Then walk the rest of the
  Act mode block in `docs/MANUAL_CHECKLIST.md`.
- The agent is an in-repo project now: `parley-agent/` (agent, six
  `/parley/*` routes, mock models, fixture MCP server,
  `smoke/run.mjs` all green, `mastra build` output verified under
  Electron-as-Node). It moved in from `/tmp` after review; dev spawns
  it from the repo, `./init.sh` installs its dependencies.

## Shape

- `electron/agent/` holds the client (HTTP + SSE), the event decoder,
  the tap-to-approve machine and the supervisor; `session.ts` adds the
  `act` branch (transcribe, never paste; `agent` block opens the Agent
  tab); `main.ts` wires spawn/approve/quit (warmup shows the starting
  pill, quitting mid-run waits for the run's DELETE).
- Agent routes live at `/parley/*`, not `/api/parley/*`: Mastra serves
  custom routes from the root and reserves `/api/` (its own docs plus
  the jev-poc house convention). Both sides match.
- Packaging: `scripts/build-agent.sh` bundles the sibling into
  `resources/parley-agent` (fails loud when the checkout is missing);
  `electron-builder.json5` ships it on every platform; packaged main
  runs it with `ELECTRON_RUN_AS_NODE`. The bundle is ~200M of
  `node_modules` because `bundler.externals: false` fails on mastra
  1.30 — recorded as a known cost, revisit on upgrade.
- Pre-existing, not mine: the storybook-render gate fails 36 scaffold
  Shell/Pages stories on this tree and 38 on pristine HEAD (clean
  worktree check); the gate is not part of `make check`.

## Next step

Write a real `parley-agent/mcp-servers.json`, set a model key, then
walk the Act mode checklist block with `make dev`. Record the
evidence, mark `passing`, and let `make commit-feature` take it.
