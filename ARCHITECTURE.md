# Architecture

```
┌──────────────── Parley Native.app (macos/, SwiftUI) ────────────────┐
│ ParleyApp        MenuBarExtra; AppController wires everything below │
│ KeyTap           listen-only CGEventTap → key edges                 │
│ AudioCapture     AVAudioEngine → 16 kHz mono AAC .m4a               │
│ HUDPanel         non-activating glass pill                          │
│ Paster           pasteboard save → ⌘V → restore (ParleyCore)        │
│ EngineProcess    spawns Resources/engine/node engine.mjs            │
└──────────────────────────────▲──────────────────────────────────────┘
          newline-delimited JSON-RPC 2.0 over stdin / stdout
┌──────────────────────────────▼──────── engine/ (TypeScript) ────────┐
│ headless/main.ts    stdio, console → stderr, data dir               │
│ headless/engine.ts  createEngine: gesture detector + session        │
│ session.ts          listening → transcribing → paste → done         │
│ transcriber.ts, transcribers/   Groq, Deepgram via parley-api       │
│ dictionary*.ts, settings-store.ts   ~/Library/Application Support/parley │
└─────────────────────────────────────────────────────────────────────┘
```

## Folders

| Path | What |
| --- | --- |
| `macos/Parley/` | the app target: windows, OS integration, process management |
| `macos/ParleyCore/` | Swift package of testable logic: wire codec + peer, key mapping, phase → recorder rules, paster |
| `engine/` | the engine. `headless/` is its entry and composition root; the rest is pure logic with tests in `__tests__/` |
| `engine/{edit-target,field-reader,selection-reader,explain*,rewriter,agent,sync,correction-*,word-offer}.ts` | Electron-era logic kept for the ports in parley-021…024; not wired into the headless engine yet |
| `native/parley-ax.swift` | the old Accessibility helper, reference for the voice-edit port |
| `scripts/build-engine.sh` | esbuild bundle + pinned official Node into `macos/build/engine/` |
| `parley-api/` | the server: provider keys, sync, agent model |
| `parley-agent/` | the Mastra agent behind Act |
| `parley-android/` | the Android app |

## The wire (protocol v1)

| Direction | Method | Kind |
| --- | --- | --- |
| app → engine | `hello {protocolVersion, appVersion, permissions}` → `{engineVersion, settings}` | request |
| app → engine | `key {type, key, time}` — `key` is a `GESTURE_KEYS` name, `Escape` or `Other` | notify |
| app → engine | `audio.ready {path, mimeType, durationMs}` — one per `transcribing`; empty path = nothing recorded | notify |
| app → engine | `permissions.changed {microphone, accessibility}` | notify |
| engine → app | `hud.show`, `hud.hide`, `hud.phase {phase, message?, tick?, mode?}` | notify |
| engine → app | `paste.text {text}` → `{ok}` | request |
| engine → app | `transcript`, `session.blocked {reason}`, `ui.openSettings`, `log` | notify |

The recorder follows `hud.phase`: `listening` starts, `transcribing` stops and
always answers with one `audio.ready`, `cancelled`/`error` discard. The engine's
audio watchdog recovers a session if that answer never comes.

## Build

`make -C macos build` runs XcodeGen on `macos/project.yml`, whose pre-build
step runs `scripts/build-engine.sh` and whose post-build step copies
`engine.mjs` and `node` into `Contents/Resources/engine/`. Signing comes from
`macos/Signing.xcconfig`, overridden by a local `Local.xcconfig`.
