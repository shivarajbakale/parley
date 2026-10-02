# Architecture

A map of parley: where things live, how a request or a command flows
through it, and which invariants the layout encodes.

It points at files rather than reproducing them, and it does not repeat the
stack, entry point or commands — those are in [AGENTS.md](AGENTS.md).

## Parley

| File | Responsibility |
|------|----------------|
| `electron/types.ts` | Shared types: `GestureKey`, `Settings`, `OrbPhase`, `ParleyApi`, IPC payloads |
| `electron/gesture-detector.ts` | Pure tap-tap-hold state machine |
| `electron/key-hook.ts` | Maps `uiohook-napi` events to detector events |
| `electron/transcriber.ts` | Picks the selected provider per call; providers (Groq, Deepgram) and shared error mapping in `transcribers/`, all through parley-api's `/api/providers` pass-through, which adds the key; `server-status.ts` asks which keys it holds |
| `electron/injector.ts` | Clipboard snapshot, paste keystroke, restore |
| `electron/settings-store.ts` | JSON settings, the transcription provider, and the encrypted sync token; no provider keys (they live in `parley-api/.env`) |
| `electron/session.ts` | Orchestrates one dictation session |
| `electron/agent/` | Act mode: the agent supervisor, HTTP/SSE client and tap-to-approve |
| `electron/windows.ts` | Pure window option and bounds functions for orb and settings windows |
| `electron/permissions.ts` | Microphone and Accessibility status, request, System Settings deep links |
| `electron/tray.ts` | Menu bar item and menu |
| `electron/audio-watchdog.ts` | Pure timer that recovers a session wedged waiting on `orb:audio` |
| `electron/orb-audio.ts` | Pure `parseOrbAudio` — validates and bounds the `orb:audio` payload |
| `electron/main.ts` | Wiring: creates windows, hook, IPC handlers, tray, login item |
| `electron/preload.ts` | Exposes `window.parley` — the only bridge; no generic `ipcRenderer` |
| `orb.html`, `src/orb/*` | Orb window: recorder, level meter, canvas, tick sound, `phase-handler.ts` |
| `settings.html`, `src/settings/*` | Settings and onboarding window |

The main process owns all state. Units under `electron/` take their
dependencies as arguments and never import Electron, except `main.ts` and
`permissions.ts`.

`src/orb/phase-handler.ts`, pulled out of `Orb.tsx`, turns each `orb:phase`
event into recorder calls and orb visibility: it clears any pending hide timer
so a new phase always supersedes a stale one, guards `recorder.start()`/`stop()`
failures, and on `transcribing` always calls `sendAudio` exactly once — empty
payload if there is no real recording — since the session is blocked in
`awaiting_audio` until that call arrives. `electron/audio-watchdog.ts` is the
main-process half of the same guarantee: `main.ts` arms it
(`AUDIO_WATCHDOG_MS`, 5000 ms) on entering `awaiting_audio`, clears it when
real audio arrives, and on timeout, a malformed `orb:audio`, or the orb's
`render-process-gone` (which also reloads the orb), recovers the session with
an empty, zero-duration payload — the cancelled path a too-short recording
already takes. `main.ts` also takes a single-instance lock so a second launch
opens settings instead of doubling the key hook and tray icon, quits if startup
fails, hands `shell.openExternal` only an http(s) URL, and sets the login item
only when packaged. The settings window shows an inline Alert on an IPC failure.
Act mode hands the transcript to the Mastra agent in the in-repo
`parley-agent/` project — dev spawns its `mastra dev`, packaged spawns
the `resources/parley-agent` bundle — and the pill carries progress,
approvals and the one-line result.

<!-- rocketship:own shape -->
## The shape

```
electron/
  main.ts            main process: windows, IPC handlers (each checks event.sender)
  preload.ts         the context-isolated bridge — named methods only, no raw channel
  window-options.ts  a pure function, unit-tested in electron/__tests__/
src/                 the renderer, a React app
  main.tsx           boots React: MSW, then QueryClient -> Theme -> Router
  App.tsx            the shell — titlebar, sidebar, topbar, palette, AuthGuard
  router/router.tsx  one manual route tree; every route is registered here
  pages/             one folder or file per screen
  components/
    ui/              the design system, flat: every atom and composition directly here
    titlebar.tsx     the frameless-window drag region
    *.tsx            app chrome — sidebar, page-shell, panel, stat cards
  config/nav.ts      one source of truth for the sidebar, the palette and page titles
  hooks/             TanStack Query hooks — the only place server state is read
  api/               client.ts, services/, types/
  lib/               auth.ts, platform.ts, queryClient.ts, errors.ts, utils.ts
  mocks/handlers/    one MSW handler file per resource
```

`docs/principles/` holds the "why" behind the recipes, and
`.claude/skills/use-mantine/mantine-capabilities.md` is the routing table from a
capability to the Mantine component that provides it.

`src/theme.ts` holds the Mantine theme — palette, radius, component defaults —
and `src/App.css` holds the cascade: `@layer mantine, app`, Mantine's six
stylesheets, and the four things a theme object cannot express above them (the
desktop body defaults, the two painted auth backdrops, and the frameless
window's drag region). There is no `ui/` kit directory — pages import
`@mantine/core` directly — and no `stores/` directory: server state lives in
Query, shell state in `useShellNav`, the rest in the router.

## How a screen is built

```
route -> page -> query hook -> service -> axios client -> MSW handler or the real API
```

A native capability takes the other path: renderer -> `preload.ts` bridge ->
an IPC handler in `main.ts`. Nothing in `src/` imports from `electron/` directly
— that is what context isolation is for, and the `add-ipc-channel` skill is the
way to add a channel.

Dependencies inside the renderer run one way. Pages depend on hooks, components
and lib. The composites in `src/components/` depend on `@mantine/core` and the
theme only — never on a page, a hook or the api layer. Services depend on the
client and the types; types have no runtime imports.

## Invariants the layout encodes

- **The shell is a fixed viewport.** `App.tsx` is `h-svh overflow-hidden` and
  pages scroll through `PageShell` — because a desktop window that scrolls as a
  whole reads as a web page in a box, and a second scroll region is the
  dual-axis scroll `make ui-probe` catches.
- **The window is frameless on macOS.** `src/components/titlebar.tsx` is the
  drag region, and anything interactive inside it needs `app-region-no-drag` or
  it cannot be clicked. The traffic-light inset is defined in both
  `src/lib/platform.ts` and `electron/window-options.ts` — change them together
  or the buttons land on top of your content.
- **The renderer reaches the OS only through `preload.ts`.** Widening that
  bridge is how an Electron app becomes a remote-code-execution surface.
- **Use the Mantine component; do not hand-roll the primitive.** `npm run
  ui-lint` fails the build on a hand-rolled badge, card, tab, button, input,
  table or progress bar, because a parallel style is a design system nobody can
  retune from one place. Read
  `.claude/skills/use-mantine/mantine-capabilities.md` before composing a
  screen.
- **Colour, border, radius, elevation and layout are all Mantine's.** Pass `c`,
  `bg`, `color`, `variant`, `radius`, `shadow`, `withBorder`, and lay out with
  `Group` / `Stack` / `SimpleGrid` / `Grid` / `Box` — never a hex, never a
  utility class. Retune `src/theme.ts`.
- **Server data goes through a Query hook that calls a service**, and every
  endpoint has an MSW handler, so the app always runs standalone.
- **Auth is a local demo shim** in `src/lib/auth.ts`. Replace the file, keep the
  exports, and nothing else in the app changes.

## The reference slice

**Projects** is implemented across every layer; copy it rather than inventing a shape.
`src/pages/Projects/ProjectsPage.tsx` is one component serving both `/projects` and `/projects/$projectId`.

## Where to add a thing

| Adding | Goes | Start from |
| --- | --- | --- |
| a whole resource | types, service, mock, hook, page, route, nav | the `add-feature` skill |
| a standalone screen | `src/pages/`, route in `router.tsx` | the `add-page` skill |
| a native capability | `electron/preload.ts` and a handler in `main.ts` | the `add-ipc-channel` skill |
| a design-system component | `src/components/`, flat, with a `.stories.tsx` | the `add-ui-component` skill |
| a dependency or a new top-level directory | read [docs/CONSTRAINTS.md](docs/CONSTRAINTS.md) first | — |
<!-- /rocketship:own -->
