# Design Decisions

Append-only. New entries go at the top. Each entry answers **What / Why /
Rejected alternatives / Constraint** so future agents know what they must not
silently undo.

---

## 2026-09-26: Act mode hands commands to a Mastra agent Parley supervises

- **What:** A fourth gesture key (`actGestureKey`, default ShiftRight) turns
  speech into a command for the `parley-action` agent in the sibling
  `../Mastra/parley-agent` project. Parley spawns and supervises that server
  on launch (`mastra dev` in dev, the `mastra build` bundle from
  `resources/parley-agent` packaged, run with `ELECTRON_RUN_AS_NODE`),
  attaching when the port already answers. Reads run free; every write-class
  tool suspends for a tap of the act key, Esc is no, and the approval waits
  until answered — no timeout. Progress, the question and the one-line
  result ride the orb pill; the Agent tab mirrors a waiting approval with
  Approve/Decline and keeps the last failure standing. Agent routes live at
  the server root (`/parley/run`, …), never under `/api/`.
- **Why:** The agent owns the MCP tools, the model and the run state, so
  Parley stays a mic, a pill and a supervisor — no tool code in the desktop
  app, and the server stays usable from anywhere. Parley-managed (not
  user-run) because act mode must work on first launch with no terminal.
  Approvals wait because a timed-out yes-or-no is a destructive action taken
  by a timer. Root paths because Mastra serves custom routes from the root
  and reserves `/api/` for itself.
- **Rejected alternatives:** Inline MCP tools in the Electron main process
  (every tool reimplements streaming, suspension and retry; the app bloats
  with server code); the user running `mastra dev` themselves (a terminal
  dependency for a menu-bar app); approvals with a timeout (auto-decline
  strands multi-step runs, auto-approve acts without consent); `/api/parley`
  paths (inside Mastra's reserved namespace).
- **Constraint:** Localhost URLs are managed (spawned); anything else is
  attach-only and Restart is disabled. Tool calls are not transactional —
  quit cancels the run but cannot roll a tool back. v1 has no auth on
  localhost and no voice approval; the scaffold keeps zero native
  dependencies so the bundle stays plain JS.

## 2026-09-24: Transcription provider is its own channel; hasApiKey follows it

- **What:** `transcriptionProvider` (`groq` | `deepgram`, default `groq`) lives
  in `Settings` but is dropped from every `updateSettings` patch and is set only
  through `settings:setTranscriptionProvider`. `hasApiKey` (store and
  `SettingsView`) means "the selected provider has a key". Deepgram gets
  `terms` (a word list) and Groq gets `vocabulary` (the Whisper sentence).
  Both are built from the same ordered dictionary words.
- **Why:** Switching provider changes readiness, so main has to refresh the tray
  when it happens. A dedicated channel does that in one place. Keeping the
  meaning of `hasApiKey` let the Overview, the shell's needs-setup check, the
  tray and the session block follow the provider without changes. Deepgram's
  keyterms are words to boost, so a prose prompt would boost "Notes" and
  "about".
- **Rejected alternatives:** Patching the provider through `settings:update`
  (the tray would go stale); `hasGroqKey`/`hasDeepgramKey` view fields (every
  readiness check would have to pick one); splitting Whisper's prompt sentence
  back into words (fragile).
- **Constraint:** The Groq key keeps `apiKeyEncrypted` and
  `getApiKey`/`setApiKey`, so existing installs keep their key. The first-run
  wizard is Groq-only.

## 2026-09-22: Versioned settings envelope for onboarding state

- **What:** `settings.json` gained `schemaVersion` (envelope-only: the
  renderer can neither read nor write it) starting at 1, plus three sanitized
  settings — `tourSeen`, `wizardStep` (steps 0–5, Done at 6),
  `onboardingComplete`. v0 files migrate by gaining v1 defaults; the migration
  is idempotent and persists on the next save.
- **Why:** First run is now a persisted stage machine (tour → wizard →
  settings) that must survive quits mid-flow; stuffing that into unversioned
  settings would leave every future shape change guessing.
- **Rejected alternatives:** Unversioned fields (no way to evolve the shape
  later); renderer localStorage (invisible to main, wiped on cache clear,
  untestable from the store).
- **Constraint:** New settings fields stay renderer-sanitized; envelope fields
  never enter `Settings`. `migrate()` stays idempotent — old files and first
  launches both flow through it.

---

## 2026-09-22: No generic `ipcRenderer` bridge in the preload

- **What:** Removed the scaffold's `contextBridge.exposeInMainWorld('ipcRenderer', …)`
  block and its `Window` declaration. `window.parley` is the whole renderer/main
  seam, and every `settings:*` / `permissions:*` handler checks `event.sender`.
- **Why:** The generic bridge let any renderer `invoke`/`send` an arbitrary
  channel, which turns one renderer XSS into full main-process reach — including
  `settings:setApiKey`. The preload is loaded into the orb window too.
- **Rejected alternatives:** Keeping it behind a channel allowlist (a second
  list to keep in sync with the handlers); leaving it because only the unopened
  scaffold demo used it (an unused hole is still a hole).
- **Constraint:** Renderer host detection is `'parley' in window`
  (`src/lib/platform.ts`), not `ipcRenderer`. New channels get a named method on
  `window.parley` and a sender check in the handler.

## 2026-09-21: `uiohook-napi` for the global key hook and paste keystroke

- **What:** Added `uiohook-napi` as a runtime dependency of the main process.
- **Why:** The tap-tap-hold gesture needs global keydown and keyup events for a
  bare modifier key. Electron's `globalShortcut` reports neither keyup nor bare
  modifiers. The same module sends the Cmd+V keystroke for paste injection.
- **Rejected alternatives:** `globalShortcut` (no keyup); AppleScript keystrokes
  (slow, and still no key listening); a Swift helper binary (kept as the
  fallback if the native module fails to load).
- **Constraint:** It is a native module. Keep it in `rollupOptions.external` in
  `vite.config.ts` and in `asarUnpack` in `electron-builder.json5`. It ships
  N-API prebuilds, so no `electron-rebuild` step is needed.

## 2026-09-21: The scaffold's demo app stays but is not opened

- **What:** Parley adds `orb.html` and `settings.html` as separate renderer
  entries. `index.html` and the demo pages remain in the tree, unopened.
- **Why:** The harness gates (`ui-probe`, `storybook-lint`, the a11y suite)
  exercise the demo pages. Deleting them is a large change unrelated to v1.
- **Rejected alternatives:** Hosting settings as a route in the demo shell
  (drags in auth and a sidebar a menu bar tool does not need).
- **Constraint:** `electron/main.ts` must never load `index.html`.

## 2026-07-01: Project scaffolded with a harness-first baseline

- **What:** Generated this Electron desktop app (Vite + React + TypeScript) with a complete agent harness from
  rocketship's `harness-core`.
- **Why:** Long-running agent work needs continuity, explicit verification, and a
  repository that is its own system of record — not a bare prompt.
- **Rejected alternatives:** A README-only scaffold — rejected because it leaves
  the agent to re-infer conventions and definition-of-done every session.
- **Constraint:** `make check` is the definition of done. Do not mark features
  `passing` without running their verification and recording evidence.
