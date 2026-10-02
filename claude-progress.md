# parley-017: provider keys live in parley-api (on main)

## What landed

- parley-api `/api/providers/*` passes the app's exact Groq, Deepgram and
  MiniMax calls on with the key from `parley-api/.env`; only those paths are
  allowed, and the server listens on 127.0.0.1. `GET /api/providers/status`
  says which keys it holds. `make api` runs it.
- Desktop: transcribers and the rewriter call the server with no key
  (`offline` = "Parley server not running", `no_key` = "No <provider> key on
  the Parley server"). Settings schema v2 deletes the stored keys. The key
  gates, key IPC, key forms and the MiniMax offer are gone; Overview has a
  Parley server group and the wizard step checks the server. The managed Act
  agent gets `MINIMAX_BASE_URL` pointed at the server.
- 0.6.0 is built and installed in /Applications.

## Next step

Walk the "Parley server and keys" block of `docs/MANUAL_CHECKLIST.md`, then
mark `parley-017` passing. Follow-up: the app starting parley-api itself.

# Earlier

`parley-016` (Explain streams from parley-api over SSE) and `parley-015`
(sync, no server since the Mastra rewrite) are in progress; their next steps
are in `feature_list.json` evidence.
