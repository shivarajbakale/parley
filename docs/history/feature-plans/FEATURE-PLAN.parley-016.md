<!-- feature-plan:v1 — generated, do not hand-edit.
     Regenerate with: node scripts/feature-plan.mjs parley-016.feature-plan.json -->

# Explain streams from parley-api

`parley-016` · 1 surface

## Problem

Explain answers are capped at ~80 words with no context, so the user reads them and still does not understand. parley-api now has a screen-explainer agent that teaches (meaning, how it works, an example, jargon defined) and searches the web with Exa, streamed over SSE. The card should show that answer as it is written, say when it is searching, and link the pages it actually used.

## Not in this feature

- A fallback to the old direct-MiniMax explain when parley-api is down: the card says it cannot reach the server instead.
- A separate Explain server setting: Explain calls the same Parley server address Sync uses.
- Changing the gesture, selection reading, anchoring, or follow-up behaviour.
- Voice edit and dictation, which still call MiniMax directly.

## Surfaces

### Explanation popover · `explain.html (own frameless window)`

Archetype: `centered-card` — Show the answer next to the selection as it streams, without stealing focus from the app.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│                                                                            │
│                   ┌──────────────────────────────────────┐                 │
│                   │ idempotent                   Explain │                 │
│                   │ text streams in; a cursor marks the …│                 │
│                   │ ──────────────────────────────────── │                 │
│                   │ Status   Searching 'Mastra 1.67 rel… │                 │
│                   │ Answer   markdown, growing as it ar… │                 │
│                   │ Sources  newreleases.io · github.com │                 │
│                   │ ──────────────────────────────────── │                 │
│                   │ [Copy]  [Close]                      │                 │
│                   └──────────────────────────────────────┘                 │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

**Mobile @390** — design intent; the probe measures 1280 / 1440 / 1920 only.

```
┌──────────────────────────┐
│ ☰  Explanation popov…⌕   │
├──────────────────────────┤
│ ┌──────────────────────┐ │
│ │ Status   Searching … │ │
│ │ Answer   markdown, … │ │
│ │ Sources  newrelease… │ │
│ │ ──────────────────── │ │
│ │ [Copy]  [Close]      │ │
│ └──────────────────────┘ │
│         [ Copy ]         │
└──────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ No selection: card   │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ says 'Select some    │   │ One line in the      │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ text first' and      │   │ turn: 'Can't reach   │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ dismisses itself     │   │ the Parley server at │
│                      │   │ after 2 s,           │   │ <url>' when the      │
│                      │   │ unchanged.           │   │ request fails,       │
│                      │   │                      │   │ otherwise the        │
│                      │   │ [ Copy ]             │   │ server's message     │
│                      │   │                      │   │ ('No answer came     │
│                      │   │                      │   │ back. Try again.').  │
│                      │   │                      │   │ Text already         │
│                      │   │                      │   │ streamed stays above │
│                      │   │                      │   │ it.                  │
│                      │   │                      │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: Markdown renders as it streams; the card grows with it up to 60% of the display, then scrolls inside and keeps the live edge in view unless the user has scrolled up. When done, a Sources row of site names opens each page in the browser; Copy appears.

Held to:

- B3 — the card is centred on both axes and stays under 480px wide

## Overlays

```
       popover · explain-card
┌────────────────────────────────┐
│ Explain                        │
│ ────────────────────────────── │
│ Streaming markdown answer anc… │
│             [ Copy ] [ Close ] │
└────────────────────────────────┘
```

## Components

Each choice states the neighbour it beat. `Use when:` / `Instead:` for every
component family lives in `.claude/skills/use-mantine/mantine-capabilities.md`;
the choices between families live in
`docs/principles/component-selection.md`.

| Surface | Control | Why this one | Not |
| --- | --- | --- | --- |
| popover | `fetch + SSE parser in the main process` | the request carries the selection in a POST body, which EventSource cannot send; main already owns every network call, and the renderer only reads what main pushes | `EventSource in the renderer` |
| popover | `Existing explain:state push, throttled to one update per animation frame (~32 ms)` | a new 'streaming' turn status rides the channel the card already listens on; throttling keeps window resizes and React renders off the per-token rate | `a new per-delta IPC event` |
| popover | `react-markdown, re-rendered on each update` | already the card's renderer and never emits raw HTML; partial markdown (an unclosed ** or list) renders as text and corrects itself on the next update | `plain text while streaming, markdown at the end (layout jumps on completion)` |
| popover | `Loader size xs + dimmed Text for the search line` | an inline, indeterminate wait for a known step; Skeleton is reserved for the empty first moment before any text | `Skeleton under existing text` |
| popover | `Anchor (size xs, c=dimmed) per source, opening through window.parley.openExternal` | the card itself never navigates; main opens only http/https URLs in the default browser, so a link is one click without widening what the renderer can do | `plain-text domains` |
| popover | `Follow the live edge with scrollTop, paused while the user is scrolled up` | past the 60% cap the newest words are below the fold; forcing the scroll would fight a user reading the top | `always scrollIntoView on each delta` |

## Data model

- **ExplainTurn (electron/types.ts)**
  - `status`: 'loading' | 'streaming' | 'ready' | 'error' — 'streaming' is new: text so far, still arriving
  - `markdown`: string — on streaming, ready, and on error when text arrived before it failed
  - `searching`: string | undefined — the query being searched now; cleared by the next delta
  - `sources`: { title: string; url: string }[] — on ready only; at most 3, from the search tool's real results
  - _relations:_ one thread of turns per selection, unchanged

## API endpoints

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| POST | `<syncUrl>/api/explain` | no | parley-api screen-explainer over SSE: delta, search, reset, sources, done, error. Closing the request aborts the model run. |

## Integration points

```
  electron/explain-client.ts (new)  ──▶  parley-api /api/explain   (fetch with AbortSignal, parse SSE frames, call onEvent per event; a non-2xx or network failure becomes one error event)
  electron/explain.ts               ──▶  explain-client   (replaces rewriter.explain: folds events into the open turn (delta appends, reset clears, search sets status, sources + done finish it); dismiss() aborts the stream)
  electron/main.ts                  ──▶  createExplain   (builds the client from store.get().syncUrl; throttles pushExplain; registers shell:openExternal)
  add-ipc-channel                   ──▶  explain:openExternal   (renderer -> main, http/https only, from the explain window only)
  parley-api                        ──▶  port 3100   (default PORT moves 3000 -> 3100 so the desktop default syncUrl reaches it)
```

## Blast radius

```
new (3)
  ├── electron/explain-client.ts
  ├── electron/__tests__/explain-client.test.ts
  └── src/explain/ExplainCard.stories.tsx

changed (11)
  ├── electron/explain.ts
  ├── electron/__tests__/explain.test.ts
  ├── electron/types.ts
  ├── electron/main.ts
  ├── electron/preload.ts
  ├── electron/rewriter.ts
  ├── src/explain/ExplainCard.tsx
  ├── src/explain/ExplainCard.module.css
  ├── src/explain/__tests__/ExplainCard.test.tsx
  ├── parley-api/src/index.ts
  └── parley-api/.env.example
```

## Verification plan

- [ ] `npm run type-check`
- [ ] `npm run lint`
- [ ] `npm run ui-lint`
- [ ] `npm run test`
- [ ] `npm run ui-probe`
- [ ] `ux-prepass` — all seven boxes, `npm run ui-lint` green is the evidence for item 7

---

Approve this before any file is written. Every diagram above is rendered
from this feature's plan JSON, so the drawing and the build cannot drift;
the archetype frames are the same shapes `ui-probe` rules B1-B4 assert
against the real DOM once the screens exist.
