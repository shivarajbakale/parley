# parley-019 — Native macOS shell, phase 1: headless engine + Swift dictation

Status: **approved 2026-11-05** (minimum macOS 26). Built; live dictation check pending.
Design reference: <https://claude.ai/artifact/Mirpic2JxR1ZZyewgN8nZL> (Liquid Glass
settings, dictionary, HUD states, menu bar extra, onboarding).

## Problem

Parley is a menu-bar utility whose value is almost entirely OS integration: global
modifier gestures, microphone, reading the focused field through Accessibility,
pasting at the caret. Electron is the weakest layer for all of it — `uiohook-napi`
because `globalShortcut` cannot see bare modifiers or key-up, a new `parley-ax`
process for every field read, permissions attributed to the Electron binary, and a
Chromium runtime resident all day for a tray icon. The React UI (~8k lines) is the
only thing Electron does well, and it is the part we are replacing.

## Goal of this phase

One full **dictation** — tap-tap-hold Right Option, speak, release, text pasted at
the caret — driven by a SwiftUI menu-bar app talking to the existing TypeScript
engine running under plain Node. Nothing is deleted in this phase; the Electron app
keeps working, so every later step can be compared against it.

## Non-goals (later phases)

- Voice edit, Explain, Act, word offers, correction watcher (engine paths stay, the
  Swift side does not drive them yet).
- Settings window, dictionary UI, onboarding — the design canvas covers them; they
  are phase 3.
- Deleting `src/`, React, Mantine, Storybook, Electron (phase 4).
- Signing / notarization, auto-update.
- Moving engine logic into Swift or parley-api.

## Architecture

```
┌──────────────────────── Parley.app (Swift, SwiftUI) ────────────────────────┐
│ MenuBarExtra         HUDPanel (NSPanel, glass pill)      PermissionsMonitor │
│ KeyTap (CGEventTap, flagsChanged + keyDown/Up)                              │
│ AudioCapture (AVAudioEngine → AAC .m4a, levels @ 30 Hz)                     │
│ Paster (NSPasteboard save → write → ⌘V via CGEvent → restore)               │
│ EngineProcess ── spawns ──▶ Contents/Resources/node  engine.mjs  (stdio)    │
└──────────────────────────────────▲──────────────────────────────────────────┘
                 newline-delimited JSON-RPC 2.0 over stdin/stdout
┌──────────────────────────────────▼─────── engine (TypeScript, Node) ────────┐
│ engine/main.ts: createGestureDetector ×1 (dictate)  createSession(deps)     │
│ deps.orb        → notify  hud.phase                                         │
│ deps.injector   → request paste.text            (Swift does the paste)      │
│ deps.transcriber, dictionary, settings-store, sync — unchanged modules      │
│ edit/explain/act deps → stubs that refuse ("not in this build")             │
└─────────────────────────────────────────────────────────────────────────────┘
```

The seam already exists: `createSession(deps: SessionDeps)` in
`electron/session.ts` takes every side effect as a dependency, and
`createGestureDetector` is pure. Only `main.ts`, `permissions.ts` and `preload.ts`
import Electron. Phase 1 adds a second composition root next to `main.ts`; it does
not refactor the first.

### Who owns what

| Concern | Owner | Why |
| --- | --- | --- |
| Key events | Swift `CGEventTap` | sees bare modifiers + key-up; drops `uiohook-napi` |
| Gesture detection | Engine (existing `gesture-detector.ts`) | already tested; Swift just forwards `{type,key,time}` |
| Mic capture, levels | Swift `AVAudioEngine` | renderer `MediaRecorder` goes away with the renderer |
| Transcribe, dictionary, settings, sync | Engine (unchanged) | logic, not OS |
| Paste at caret | Swift | pasteboard + synthetic ⌘V, no child process |
| HUD / menu bar | Swift | the point of the exercise |
| Permissions (Mic, Accessibility) | Swift | TCC attributes to `Parley.app`; engine must never prompt |

### Protocol (v1)

Newline-delimited JSON-RPC 2.0. Both sides may send requests; ids are per-sender.
First message is `hello` with `protocolVersion: 1`; a mismatch is a fatal, visible
error.

| Direction | Method | Kind | Payload |
| --- | --- | --- | --- |
| app → engine | `hello` | request | `{protocolVersion, appVersion, permissions}` → `{engineVersion, settings}` |
| app → engine | `key` | notify | `{type: "down"\|"up", key: GestureKey\|"Escape"\|"Other", time}` |
| app → engine | `audio.ready` | notify | `{path, mimeType: "audio/mp4", durationMs}` (temp file, engine deletes) |
| app → engine | `permissions.changed` | notify | `{microphone, accessibility}` |
| engine → app | `hud.phase` | notify | the existing `OrbPhasePayload`; the shell's recorder follows it exactly as `src/orb/phase-handler.ts` did: `listening` starts, `transcribing` stops and always answers with one `audio.ready` (empty `path` when nothing was recorded), `cancelled`/`error` discard |
| engine → app | `hud.show` / `hud.hide` | notify | `{}` |
| engine → app | `paste.text` | request | `{text}` → `{ok}` or error |
| engine → app | `transcript` | notify | `{text}` — the menu's "copy last" |
| engine → app | `session.blocked` | notify | `{reason: "microphone"\|"accessibility"}` |
| engine → app | `ui.openSettings` | notify | `{}` |
| engine → app | `log` | notify | `{level, message}` |

Audio goes as a temp-file path, not base64 on the pipe: a 60 s clip is ~500 KB
and stdio framing stays trivial.

## Files

**New** (as built)
- `electron/headless/main.ts` — Node entry: stdio, console → stderr, data dir.
- `electron/headless/engine.ts` — composition: session + gesture detector +
  transcriber + dictionary, OS effects as RPC messages; testable with fakes.
- `electron/headless/rpc.ts` — framing, correlation, timeouts.
- `electron/__tests__/headless-rpc.test.ts`, `headless-engine.test.ts`.
- `scripts/build-engine.sh` — esbuild bundle → `macos/build/engine/engine.mjs`, plus
  an official Node v24.22.1 (static, SHA-256 verified) as `macos/build/engine/node`.
- `macos/ParleyCore/` (SwiftPM, Swift 6) — `JSONValue`, `RPC` (codec, line buffer,
  `RPCPeer`), `KeyMap` (+ `ModifierTracker`), `HUDPhase` (+ recorder rules),
  `Paster`; 23 tests under `swift test`.
- `macos/Parley/` (app, Swift 5 mode for now) — `ParleyApp` (`MenuBarExtra`),
  `AppController`, `EngineProcess`, `KeyTap`, `AudioCapture`, `HUD` (glass pill),
  `Permissions`.
- `macos/project.yml` (XcodeGen), `Signing.xcconfig` (+ gitignored
  `Local.xcconfig`), `Makefile` (`test`, `build`, `run`).

**Changed**
- `electron/transcribers/groq.ts` — filename from mime type (`speech.m4a` for
  `audio/mp4`); today it is hard-coded `speech.webm`.
- `Makefile` — `check` adds `macos-check` (skipped without Swift). The engine
  tests run in the existing `npm test`.
- `feature_list.json` — register parley-019.
- `README.md` — "Native shell (preview)" section.

**Untouched:** everything under `src/`, `electron/main.ts`, `parley-api/`,
`parley-agent/`, `parley-android/`.

## Decisions taken (say if any is wrong)

1. **Ship a pinned Node binary** inside the app rather than requiring a system Node.
   Measured: 117 MB (official build; Homebrew's node links its own dylibs and cannot
   be bundled). Later phases can shrink this by moving logic to Swift or
   parley-api.
2. **XcodeGen** for the project (already installed), so the `.xcodeproj` is
   generated, not committed.
3. **Gesture detection stays in TypeScript** this phase; Swift forwards raw keys.
   Moving it costs a rewrite of tested code for no user-visible gain yet.
4. **Electron and Swift builds never run together** — both would hook the same keys.
   The Swift app refuses to start if `Parley` (Electron) is running, and says so.
5. **Same data directory** as the Electron build, so dictionary and settings
   carry over and the comparison is fair.

6. **macOS 26 minimum** (decided 2026-11-05): real `.glassEffect`. A macOS 14
   fallback is a candidate before the open-source release.

## Known gaps in phase 1

- **Sync token.** It is encrypted with Electron's `safeStorage`, which Node cannot
  read, so the native build has no sync. Dictation does not need it. Phase 3 moves the
  token to the Keychain, owned by Swift.
- **Settings are read-only** from the native build (no settings UI yet); change them
  in the Electron build.

## States (HUD, from the design canvas)

- Listening: accent orb + live level bars + timer.
- Transcribing: ring spinner, "Writing it down…".
- Done: pill fades after `DONE_MS`.
- Error: red badge + message from the engine (`ERROR_MS`), e.g. "Parley server not
  running"; mic or Accessibility missing opens the menu with the reason.

## Verification

- `make check` green (adds engine tests + `xcodebuild test`).
- Unit: RPC framing/correlation/timeouts (TS and Swift), dictation flow against a fake
  client, Swift key-code → `GestureKey` mapping, paster restores the pasteboard.
- Live: with parley-api running, dictate into TextEdit, Notes and Slack from the Swift
  app; record time from key-up to paste vs. the Electron build, and idle RSS of
  `Parley.app` + node vs. Electron. Evidence goes in `feature_list.json`.

## Risks

- **TCC attribution of the Node child.** Expected: the child inherits `Parley.app` as
  responsible process, so Accessibility/Mic are never asked of `node`. The engine
  does no AX or mic work anyway; if a prompt names `node`, that is a bug.
- **Event tap disabled by timeout.** macOS disables a slow tap; the tap callback only
  enqueues and returns, and re-enables on `tapDisabledByTimeout`.
- **Engine crash.** `EngineProcess` restarts with backoff and shows the error pill;
  three crashes in a minute stop retrying and surface "Engine stopped".
