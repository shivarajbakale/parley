# parley-016: Explain streams from parley-api (on main, uncommitted)

## What landed

- `parley-api/` is now Mastra on Express (port 3100). Its `screen-explainer`
  agent teaches rather than summarises and searches with Exa; `POST
  /api/explain` streams it over SSE (delta, search, reset, sources, done,
  error). Keys live in `parley-api/.env` (`MINIMAX_API_KEY`, `EXA_API_KEY`).
  The old Express/Prisma sync API is gone, so `parley-015` sync has no server.
- Desktop: `electron/explain-client.ts` reads the stream; `electron/explain.ts`
  folds it into a `streaming` turn, throttled to one push per 32 ms; the card
  shows a live caret, a Searching line, and Sources that open in the browser
  through `explain:openExternal`. Explain no longer needs a desktop MiniMax
  key. The old direct-MiniMax explain and `web-search.ts` are removed.
- `boilerplate-001` and `parley-001` to `003` moved to
  `docs/history/completed-features.md` to keep the prelude under budget.

## Run it

`npm --prefix parley-api start`, then `make dev` (quit /Applications/Parley.app
first: the single-instance lock closes the dev build otherwise).

## Next step

Walk the Explain block of `docs/MANUAL_CHECKLIST.md`, record it, and mark
`parley-016` passing. Open: about 1 in 5 "check several sources" questions end
in "No answer came back" (MiniMax keeps calling tools); a no-tools retry on the
server is the proposed fix. Rebuilding the sync routes in the new API is
`parley-015`'s remaining work.
