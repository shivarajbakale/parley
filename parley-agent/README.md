# parley-agent

The Mastra agent behind Parley act mode. Parley spawns this server on
launch, POSTs transcribed voice commands to it, and paints the streamed
progress, approval questions and one-line results on the orb pill.

Reads run their tools free. Anything that changes, sends, deletes or
books suspends first: the pill asks, one tap runs it, Esc skips it, and
the question waits until answered — there is no timeout.

## Setup

```sh
npm install
cp .env.example .env   # then set GROQ_API_KEY (or your provider's key)
```

Write your MCP servers to `mcp-servers.json` (same shape as the MCPClient
`servers` map, optionally wrapped in a `{"servers": …}` object):

```json
{
  "calendar": { "command": "npx", "args": ["-y", "calendar-mcp"] },
  "github": { "url": "http://localhost:3000/mcp" }
}
```

```sh
npm run dev    # serves :4111, the address Parley expects
```

No `mcp-servers.json` means no servers: health still answers, the Agent
tab says no servers are connected, and the act gesture blocks until one
is. A malformed file fails the boot out loud.

## Contract (what Parley calls)

All routes live at the server root — Mastra reserves `/api/` for itself.

| Method | Path | Purpose |
| ------ | ---- | ------- |
| POST | `/parley/run` | `{transcript}` → `{runId}`; 400 on an empty transcript |
| GET | `/parley/runs/:id` | `{status, lastStep}`; 404 when the run is gone |
| GET | `/parley/runs/:id/events` | SSE: `step`, `approval_requested`, `completed`, `failed`, plus a 15s heartbeat |
| POST | `/parley/runs/:id/approve` | `{approved}` resumes or declines the suspended tool; 404 when the run is gone |
| DELETE | `/parley/runs/:id` | Cancels the run, suspended or not; always 200 |
| GET | `/parley/health` | `{online, mcpServers: [{name, tools}]}` |

Every SSE event carries the `runId` and an integer `seq` starting at 1.
Events buffer per run, so a subscriber that connects late replays from
the start. `approval_requested` carries `callId`, `tool`, a one-line
`summary` (description-first, args after) and the `transcript` fragment
the pill echoes. Statuses: `working`, `awaiting_approval`, `done`,
`failed`, `cancelled`.

## Approval policy

`parley/mcp.ts` decides per tool call: a tool whose MCP annotations say
`readOnlyHint: true`, or whose name starts with list/get/read/search/
show/describe/fetch/find, runs free — everything else suspends. Unknown
tools ask rather than act. This is a v1 heuristic, not a security
boundary: annotations are server hints, so point Parley only at servers
you trust.

## Keyless verification

`PARLEY_MODEL=mock:<read|write|plain>` swaps the model for a canned
script, so the whole contract runs with no key and no network:

- `mock:read` — one free read, then the one-line answer
- `mock:write` — one write (suspends), then the one-line answer
- `mock:plain` — a refusal with no tools

The mocks answer the same way whatever was said; the write script's
post-decline text still says "deleted". The smoke asserts the server's
events, not the canned words.

```sh
PARLEY_MODEL=mock:write PARLEY_MCP_SERVERS_FILE=./mcp-servers.smoke.json npm run dev
```

`node smoke/run.mjs` drives the whole contract against fresh boots —
read, approve, decline, cancel-suspended and the 404s — and asserts
every event shape. It writes `mcp-servers.smoke.json` itself, pointing
at the two-tool fixture notes server (`smoke/fixture-mcp.mjs`:
`list_notes` read-only, `delete_note` destructive) by absolute path,
because a stdio spawn starts in the bundler's directory, not the
project root — real configs should use absolute paths too (or a
PATH-resolved command). `PARLEY_DEBUG=1` logs every Mastra stream
chunk while a run pumps.

## Layout

- `src/mastra/index.ts` — wires model + MCP tools + agent + routes
- `src/mastra/agents/parley-action.ts` — the agent and its one-line-answer instructions
- `src/mastra/parley/mcp.ts` — server config, the MCP client, the approval policy, health catalog
- `src/mastra/parley/runs.ts` — the run store: streaming pump, suspend/resume, cancel
- `src/mastra/parley/routes.ts` — the six `/parley/*` routes
- `src/mastra/parley/mock.ts` — the keyless mock models (lazy-loaded, never in the prod path)

## Constraints from the desktop side

- Keep zero native dependencies: Parley ships `.mastra/output` inside the
  app and runs it with Electron-as-Node, where there is no toolchain to
  rebuild bindings.
- Runs are in memory: a restart orphans them and Parley folds the pill.
  Suspended runs survive only in the process that suspended them (the
  default in-memory store; a persistent store would keep them across
  restarts, at the cost of a storage adapter).
- `mastra build` with `bundler.externals: false` fails on mastra 1.30
  (Rollup chokes inside @mastra/core), so the build ships ~200M of
  `node_modules`. Revisit on upgrade — see the NOTE in `index.ts`.
