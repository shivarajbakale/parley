# Parley

Tap-tap-hold voice dictation for macOS. Tap your dictation key, hold the last
tap, speak, release: the words are transcribed and pasted at your cursor.

## Projects in this repo

| Folder | What | Verify |
|---|---|---|
| `macos/` | the macOS app (SwiftUI, macOS 26) | `make -C macos test` |
| `engine/` | the TypeScript engine the app runs under a bundled Node | `npm test` |
| `parley-api/` | the server: provider keys, sync, the agent's model | `make -C parley-api check` |
| `parley-agent/` | the Mastra agent behind Act mode | `cd parley-agent && npm test` |
| `parley-android/` | the Android app (Flutter) | `make -C parley-android check` |

`make check` runs all of them.

## Run

Needs Xcode 26, XcodeGen (`brew install xcodegen`) and Node 22+.

```bash
./init.sh        # install dependencies and verify
make api         # the Parley server on 127.0.0.1:3100 (keys in parley-api/.env)
make run         # build and open Parley Native.app
```

Grant Microphone and Accessibility from the menu bar icon. The provider keys
(`GROQ_API_KEY`, `DEEPGRAM_API_KEY`, `MINIMAX_API_KEY`, `EXA_API_KEY`) live only
in `parley-api/.env`; the app stores none.

To keep permissions across rebuilds, sign with your own identity: create
`macos/Local.xcconfig` with `CODE_SIGN_IDENTITY`, `DEVELOPMENT_TEAM` and
`CODE_SIGN_STYLE = Automatic` (see `macos/Signing.xcconfig`).

## Status

Dictation works in the native app. Voice edit, Explain, Act, the settings
window and sync worked in the earlier Electron app and are being ported
(`feature_list.json`, parley-020 to parley-024; the old entries are in
`docs/history/electron-features.md`).

How it fits together: [ARCHITECTURE.md](ARCHITECTURE.md).
