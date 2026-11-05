# Architecture

```
┌──────────────── Parley Native.app (macos/, SwiftUI) ────────────────┐
│ ParleyApp        MenuBarExtra; AppController wires everything below │
│ KeyTap           listen-only CGEventTap → key edges                 │
│ AudioCapture     AVAudioEngine → 16 kHz mono AAC .m4a               │
│ HUDPanel, ExplainPanel, SettingsWindow   glass pill, card, settings │
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
| `engine/headless/platform.ts` | every call the engine makes to the app, typed |
| `engine/headless/secret.ts` | AES-GCM for the sync token, keyed from the Keychain |
| `macos/Parley/Accessibility.swift` | the focused field and selection, in-process (port of the old `parley-ax` helper) |
| `scripts/build-engine.sh` | esbuild bundle + pinned official Node into `macos/build/engine/` |
| `parley-api/` | the server: provider keys, sync, agent model |
| `parley-agent/` | the Mastra agent behind Act |
| `parley-android/` | the Android app |

## The wire (protocol v2)

Newline-delimited JSON-RPC 2.0. Both sides send requests; `protocolVersion`
in `engine/headless/rpc.ts` and `ParleyCore/RPC.swift` must match.

**App → engine**

| Method | Kind | What |
| --- | --- | --- |
| `hello {protocolVersion, permissions, secretKey, agentDir}` | request | → `{engineVersion, settings}`; `secretKey` is the Keychain key for the sync token |
| `key {type, key, time}` | notify | every key edge; `key` is a `GESTURE_KEYS` name, `Escape` or `Other` |
| `audio.ready {path, mimeType, durationMs}` | notify | one per `transcribing`; empty path = nothing recorded |
| `permissions.changed`, `explain.dismiss` | notify | |
| `settings.get`, `settings.update {patch}`, `settings.setProvider {provider}` | request | → the settings view |
| `dictionary.list`, `dictionary.upsert {word, soundsLike, id?}`, `dictionary.remove {id}` | request | |
| `server.status` | request | is parley-api up, which keys it holds |
| `server.setKey {provider, key}`, `server.removeKey {provider}` | request | → status; the key goes to parley-api's `/api/providers/keys` and is kept only there |
| `agent.status`, `agent.setUrl {url}`, `agent.test`, `agent.restart`, `agent.decide {callId, approved}` | request | |
| `sync.signIn {email}`, `sync.signOut`, `sync.now` | request | |

**Engine → app**

| Method | Kind | What |
| --- | --- | --- |
| `hud.show`, `hud.hide`, `hud.phase {phase, message?, hint?, accepted?, mode?, tick?}` | notify | the pill |
| `paste.text {text, selectAll}` | request | paste with clipboard restore |
| `inject.copyAll`, `inject.copySelection` → `{text}`, `inject.erase {count}` | request | voice edit and Explain fallbacks |
| `ax.focusedField` → field, `ax.select {location, length}` → `{selected}` | request | Accessibility, in-process |
| `explain.show {anchor, content}`, `explain.update {content}`, `explain.hide` | notify | the Explain card |
| `clipboard.write`, `speak`, `app.launchAtLogin`, `settings.changed` | notify | |
| `clipboard.recent {withinMs}` → `{text}` | request | what the user copied in that window, else empty (Explain fallback) |
| `transcript`, `session.blocked {reason}`, `ui.openSettings`, `log` | notify | |

The recorder follows `hud.phase`: `listening` starts, `transcribing` stops and
always answers with one `audio.ready`, `cancelled`/`error` discard. The engine's
audio watchdog recovers a session if that answer never comes.

The Act agent (`resources/parley-agent`, built by `make agent`) is copied into
the app and started by the engine with the bundled Node; a server already
answering at the agent URL is attached to instead.

## Build

`make -C macos build` runs XcodeGen on `macos/project.yml`, whose pre-build
step runs `scripts/build-engine.sh` and whose post-build step copies
`engine.mjs` and `node` into `Contents/Resources/engine/`. Signing comes from
`macos/Signing.xcconfig`, overridden by a local `Local.xcconfig`.
