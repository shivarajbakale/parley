<!-- feature-plan:v1 — generated, do not hand-edit.
     Regenerate with: node scripts/feature-plan.mjs parley-017.feature-plan.json -->

# Provider keys live in parley-api, not the app

`parley-017` · 2 surfaces

## Problem

The Groq, Deepgram and MiniMax keys are pasted into the desktop app and stored there, one copy per device, even though parley-api now runs on this Mac and already holds the MiniMax and Exa keys for Explain. This feature moves every provider key to parley-api's .env. Dictation, voice edit and the Act agent call the providers through parley-api, which adds the key; the app stores none. The app keeps its request code: parley-api is a narrow pass-through for the exact provider calls the app already makes, bound to 127.0.0.1 so nothing off this Mac can spend the keys. Settings stops asking for keys and instead shows whether the Parley server is reachable and which keys it has. When the server is down, the pill says so, as Explain already does. Frame note: the settings window is not PageShell, so the archetypes below are illustrative and not probe-enforced, as in parley-007 to parley-016.

## Not in this feature

- Parley starting parley-api by itself: you run it (make api / npm --prefix parley-api start) as today. Auto-start, like the Act agent's supervisor, is a follow-up.
- Android: it keeps its own keys and native transcriber; it cannot reach this Mac's localhost.
- Queueing audio while the server is down: the take fails with a clear error.
- Copying the keys the app stores today into .env automatically: they are encrypted with this app's keychain entry; you add them to parley-api/.env once, and the app then deletes its copies.

## Surfaces

### Overview tab · Parley server · `settings.html · settings · Overview`

Archetype: `list-detail` — Show whether dictation, voice edit and Act can run: is the Parley server up, and does it have the key each one needs.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│ ▨ Parley      ⌕ Search…                                     ⌘K   ◐   ⬤     │
├───────────────┬────────────────────────────────────────────────────────────┤
│ Overview      │ Overview tab · Parley server               [ Check again ] │
│ Gesture       │                                                            │
│ General       │ ┌──────────────────┐ ┌───────────────────────────────────┐ │
│ Agent         │ │ Parley           │ │ Overview                          │ │
│ Sync          │ │ ──────────────── │ │ Keys live in parley-api on this M…│ │
│ Overview tab …│ │ ▣ Overview       │ │ ───────────────────────────────── │ │
│               │ │ □ Gesture        │ │ Microphone ....... Granted      … │ │
│               │ │ □ General        │ │ Accessibility .... Granted      … │ │
│               │ │ □ Agent          │ │ PARLEY SERVER                   … │ │
│               │ │ □ Sync           │ │ Server ........... http://localh… │ │
│               │ └──────────────────┘ │ Transcription .... [Groq | Deepg… │ │
│               │                      │ Voice edit + Act . MiniMax key ✓… │ │
│               │                      │   Missing a key? Add it to parle… │ │
│               │                      │ Agent ............ Online       … │ │
│               │                      │ ───────────────────────────────── │ │
│               │                      │ [Check again]                     │ │
│               │                      └───────────────────────────────────┘ │
└───────────────┴────────────────────────────────────────────────────────────┘
```

**Mobile @390** — design intent; the probe measures 1280 / 1440 / 1920 only.

```
┌──────────────────────────┐         ┌──────────────────────────┐
│ ☰  Overview tab · Pa…⌕   │         │ ‹ Back  Overview         │
├──────────────────────────┤         ├──────────────────────────┤
│ ┌──────────────────────┐ │    ──▶  │ ┌──────────────────────┐ │
│ │ ▣ Overview           │ │         │ │ Overview             │ │
│ │ □ Gesture            │ │         │ │ Keys live in parley-…│ │
│ │ □ General            │ │         │ │ ──────────────────── │ │
│ │ □ Agent              │ │         │ │ Microphone ....... … │ │
│ │ □ Sync               │ │         │ │ Accessibility .... … │ │
│ └──────────────────────┘ │         │ │ PARLEY SERVER      … │ │
│     [ Check again ]      │         │ │ Server ........... … │ │
└──────────────────────────┘         │ │ Transcription .... … │ │
                                     │ │ Voice edit + Act . … │ │
                                     │ │   Missing a key? Ad… │ │
                                     │ │ Agent ............ … │ │
                                     │ │ ──────────────────── │ │
                                     │ │ [Check again]        │ │
                                     │ └──────────────────────┘ │
                                     └──────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ Server up but a key  │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ missing: that row    │   │ Server unreachable:  │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ shows a 'Not set'    │   │ the Server row shows │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ badge and the line   │   │ a red 'Not running'  │
│                      │   │ 'Add GROQ_API_KEY to │   │ badge and an Alert:  │
│                      │   │ parley-api/.env and  │   │ 'Start it with make  │
│                      │   │ restart the server.' │   │ api in the parley    │
│                      │   │ Dictation with that  │   │ folder. Dictation,   │
│                      │   │ provider fails on    │   │ voice edit and       │
│                      │   │ the pill with the    │   │ Explain need it.'    │
│                      │   │ same sentence.       │   │ Key rows show        │
│                      │   │                      │   │ 'Unknown'.           │
│                      │   │ [ Check again ]      │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: Running: a green badge on Server, a check on each key the server has, and the provider SegmentedControl still switches Groq and Deepgram.

Held to:

- B1 — two or more top-level panels sharing a top edge
- B2 — no panel scrolls; PageShell owns the single scroll region

### Setup wizard · Transcription step · `settings.html · wizard · step 3`

Archetype: `centered-card` — Replace 'paste your Groq key' with 'make sure the Parley server is running', so first-run setup no longer asks for a key.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│                                                                            │
│                   ┌──────────────────────────────────────┐                 │
│                   │ Transcription runs on your Parley se…│                 │
│                   │ Parley sends your speech to parley-a…│                 │
│                   │ ──────────────────────────────────── │                 │
│                   │ Server ...... http://localhost:3100… │                 │
│                   │ Groq key .... ✓ on the server      … │                 │
│                   │ [Check again]            [Continue]… │                 │
│                   │ ──────────────────────────────────── │                 │
│                   │ [Check again]  [Continue]            │                 │
│                   └──────────────────────────────────────┘                 │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

**Mobile @390** — design intent; the probe measures 1280 / 1440 / 1920 only.

```
┌──────────────────────────┐
│ ☰  Setup wizard · Tr…⌕   │
├──────────────────────────┤
│ ┌──────────────────────┐ │
│ │ Server ...... http:… │ │
│ │ Groq key .... ✓ on … │ │
│ │ [Check again]      … │ │
│ │ ──────────────────── │ │
│ │ [Check again]  [Con… │ │
│ └──────────────────────┘ │
│       [ Continue ]       │
└──────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ Server up, no Groq   │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ key: 'Add            │   │ Server not running:  │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ GROQ_API_KEY to      │   │ the start command in │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ parley-api/.env and  │   │ a Code block and     │
│                      │   │ restart the server', │   │ Check again;         │
│                      │   │ Continue still       │   │ Continue still       │
│                      │   │ enabled (setup can   │   │ enabled.             │
│                      │   │ finish; dictation    │   │                      │
│                      │   │ will say what is     │   │ [ Try again ]        │
│                      │   │ missing).            │   │                      │
│                      │   │                      │   │                      │
│                      │   │ [ Continue ]         │   │                      │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: Both checks green, Continue is the primary button.

Held to:

- B3 — the card is centred on both axes and stays under 480px wide

## Components

Each choice states the neighbour it beat. `Use when:` / `Instead:` for every
component family lives in `.claude/skills/use-mantine/mantine-capabilities.md`;
the choices between families live in
`docs/principles/component-selection.md`.

| Surface | Control | Why this one | Not |
| --- | --- | --- | --- |
| overview-server | `SettingRow + Badge for server and key status, Button 'Check again'` | Read-only status in the same label-left, state-right rows the Overview and Agent tabs already use; one action re-runs the check. | `Keeping PasswordInputs that write to the server (the server's .env is the single place keys live; a write path would need auth for no gain on one Mac), a Card per provider (heavier than the rest of the tab)` |
| overview-server | `Alert (red) when the server is unreachable, plain dimmed Text for a missing key` | Unreachable blocks everything, so it earns the one banner; a missing key blocks one mode, so a line under its row is enough. | `A toast (it would vanish while the problem stays), a Modal like MiniMaxOffer (that modal is removed: there is no key to collect)` |
| wizard-server | `The wizard's existing step Card with status rows and a Code block for the start command` | Same frame as the other steps; the step now verifies instead of collecting. | `Dropping the step (first run would never learn the server must be running), blocking Continue on a red check (setup should finish; the pill explains later)` |

## Data model

- **Settings**
  - `apiKeyEncrypted / deepgramKeyEncrypted / rewriteKeyEncrypted`: removed — schema v2 migration deletes them; the getters, setters and hasApiKey/hasRewriteKey go
  - `syncUrl`: string — kept as the Parley server address for Explain, transcription and rewrite (default http://localhost:3100)
  - _relations:_ SettingsView drops hasApiKey and hasRewriteKey; the renderer asks main for server status instead

## API endpoints

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| POST | `parley-api /api/providers/groq/openai/v1/audio/transcriptions` | no | pass-through to Groq with GROQ_API_KEY; the app's existing multipart request, unchanged but for base URL and no Authorization |
| POST | `parley-api /api/providers/deepgram/v1/listen` | no | pass-through to Deepgram with DEEPGRAM_API_KEY; raw audio body and keyterm query kept |
| POST | `parley-api /api/providers/minimax/v1/chat/completions` | no | pass-through to MiniMax with MINIMAX_API_KEY; streaming passes through, so the Act agent can use it as its model base URL |
| GET | `parley-api /api/providers/status` | no | { groq, deepgram, minimax } booleans: which keys the server has, never the keys |
| IPC invoke | `server:status` | no | settings window only; main fetches /api/providers/status and returns { reachable, url, keys } |

## Integration points

```
  electron/transcribers/groq.ts + deepgram.ts  ──▶  parley-api /api/providers/*   (base URL from settings.syncUrl, no key; a 503 'no key' and an unreachable server become TranscribeError messages the pill shows)
  electron/rewriter.ts                         ──▶  parley-api /api/providers/minimax   (same request, same errors, no key)
  electron/agent/env.ts                        ──▶  parley-agent   (the managed agent gets the MiniMax base URL pointed at parley-api instead of MINIMAX_API_KEY)
  electron/session.ts                          ──▶  pill   (the apiKey and rewriteKey gates go; failures surface after the take, as Explain's do)
  parley-api src/index.ts                      ──▶  127.0.0.1   (listens on 127.0.0.1 only (HOST overrides), since the pass-through spends real keys)
```

## Blast radius

```
new (3)
  ├── parley-api/src/providers/route.ts
  ├── parley-api/test/providers-route.test.ts
  └── src/settings/ServerStatus.tsx

changed (22)
  ├── parley-api/src/index.ts
  ├── parley-api/.env.example
  ├── electron/transcriber.ts
  ├── electron/transcribers/groq.ts
  ├── electron/transcribers/deepgram.ts
  ├── electron/transcribers/shared.ts
  ├── electron/rewriter.ts
  ├── electron/settings-store.ts
  ├── electron/session.ts
  ├── electron/agent/env.ts
  ├── electron/main.ts
  ├── electron/preload.ts
  ├── electron/types.ts
  ├── src/settings/OverviewTab.tsx
  ├── src/settings/SetupTab.tsx
  ├── src/settings/wizard/steps.tsx
  ├── src/settings/SettingsApp.tsx
  ├── src/settings/SettingsShell.tsx
  ├── src/settings/use-parley.ts
  ├── src/settings/providers.ts
  ├── src/settings/MiniMaxOffer.tsx (removed)
  └── tests and stories that reference the key fields
```

## Verification plan

- [ ] `make check`
- [ ] `npm --prefix parley-api run check (pass-through: key added, Authorization from the app ignored, only the three paths allowed, 503 when a key is missing)`
- [ ] `Storybook: Overview server Running, KeyMissing, NotRunning; wizard step in dark and light`
- [ ] `Real run with the installed build: parley-api running with GROQ_API_KEY and MINIMAX_API_KEY; dictate, voice edit, Act; stop the server and dictate again to see the pill error`
- [ ] `ux-prepass` — all seven boxes, `npm run ui-lint` green is the evidence for item 7

---

Approve this before any file is written. Every diagram above is rendered
from this feature's plan JSON, so the drawing and the build cannot drift;
the archetype frames are the same shapes `ui-probe` rules B1-B4 assert
against the real DOM once the screens exist.
