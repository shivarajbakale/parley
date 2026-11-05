# Completed features

Features that reached `passing` leave `feature_list.json` for this archive, so the
session prelude does not grow by one entry per finished feature. Each keeps its
full register entry, evidence included.

| Feature | Title |
| --- | --- |
| `boilerplate-001` | Repo boots from a clean clone |
| `parley-001` | Dictation pipeline units |
| `parley-002` | Orb window records and animates |
| `parley-003` | Settings and onboarding window |
| `parley-014` | Monorepo: Android and the sync API live beside the desktop app |
| `parley-019` | Native macOS shell, phase 1: headless engine + Swift dictation |

## Register entries

### boilerplate-001

```json
{
  "id": "boilerplate-001",
  "priority": 1,
  "area": "harness",
  "title": "Repo boots from a clean clone",
  "user_visible_behavior": "Running ./init.sh on a fresh clone installs dependencies and runs verification to completion.",
  "status": "passing",
  "verification": [
    "Run `./init.sh` from the repo root.",
    "Confirm the script exits 0."
  ],
  "evidence": [
    "Baseline. Every new feature starts from this passing state."
  ],
  "notes": "Baseline."
}
```

### parley-001

```json
{
  "id": "parley-001",
  "priority": 2,
  "area": "main-process",
  "title": "Dictation pipeline units",
  "user_visible_behavior": "Gesture detection, Groq transcription, paste injection, settings storage and the session orchestrator exist as tested main-process units.",
  "status": "passing",
  "plan": "none: main-process units with no UI, specified in docs/superpowers/specs/2026-09-21-parley-design.md",
  "verification": [
    "Run `make check` and confirm the electron/__tests__ suites pass."
  ],
  "evidence": [
    "make check exit 0 on 2026-09-21; electron/__tests__ suites for gesture-detector, key-hook, transcriber, injector, settings-store and session pass."
  ],
  "notes": "Plan tasks 1 to 7."
}
```

### parley-002

```json
{
  "id": "parley-002",
  "priority": 3,
  "area": "orb",
  "title": "Orb window records and animates",
  "user_visible_behavior": "A floating orb appears while the gesture key is held, reacts to the voice, and sends the recording to the main process.",
  "status": "passing",
  "plan": "none: canvas-only overlay window, approved as ASCII wireframes in the design spec",
  "verification": [
    "Run `make check`.",
    "Run `make dev`, perform the gesture and watch the orb states."
  ],
  "evidence": [
    "make check exit 0 on 2026-09-21; electron/__tests__ suites (gesture-detector 11, key-hook 2, injector 2, windows 4, tray 3, plus settings-store, session, transcriber, window carried from parley-001) pass. Manual `make dev` verification (tray item appears, no dock icon, Accessibility grant, gesture performed, quit from tray) has not been run and is pending — tracked in docs/MANUAL_CHECKLIST.md."
  ],
  "notes": "Plan tasks 8 to 10."
}
```

### parley-003

```json
{
  "id": "parley-003",
  "priority": 4,
  "area": "settings",
  "title": "Settings and onboarding window",
  "user_visible_behavior": "The tray opens a settings window that shows permission status, stores the Groq key and edits gesture, vocabulary, tick sound and launch at login.",
  "status": "passing",
  "plan": "none: single form window, approved as ASCII wireframes in the design spec",
  "verification": [
    "Run `make check`.",
    "Run `make dev` and change each setting."
  ],
  "evidence": [
    "make check exit 0 on 2026-09-22; src/settings/__tests__/SettingsApp.test.tsx (6 tests) pass; full unit suite 272 tests pass, story-probe suite 106 tests pass.",
    "Manual `make dev` verification (grant permissions and watch badges update, test and save a real Groq key including an invalid key, perform the gesture in Notes and confirm paste, cancel with Esc, change gesture key/tap count and confirm the new gesture, use tray 'Copy last transcript') has not been run and is pending — tracked in docs/MANUAL_CHECKLIST.md."
  ],
  "notes": "Plan task 11."
}
```

### parley-014

Archived 2026-10-03. Its Express/Prisma server was replaced by the Mastra parley-api (commit 6ef5467).

```json
{
  "id": "parley-014",
  "priority": 16,
  "area": "repo",
  "title": "Monorepo: Android and the sync API live beside the desktop app",
  "user_visible_behavior": "One clone holds the desktop app, the agent, the Android app and the API. ./init.sh installs all of them and make check verifies all of them, skipping Android when flutter is absent.",
  "status": "passing",
  "plan": "none: repository plumbing, no UI surface",
  "verification": [
    "make check",
    "git log --oneline 66493cd^2 | wc -l is at least 16 (the Android subtree merge parent)",
    "make -C parley-api check",
    "make android-check prints the skip line without flutter and runs the Flutter check with it"
  ],
  "evidence": [
    "2026-10-02 make check exit 0: unit 85 files / 741 tests, ui-probe 140/140, all lints 0 violations; nested parley-api check 43/43 incl. e2e; Android flutter suites (1924+167+131+100+21) and 170 Kotlin pass.",
    "2026-10-02 make -C parley-api check exit 0: type-check, lint, plan/db/api/capability lints, 43/43 tests, build, boot-check, doc-lint 9.9 KB.",
    "2026-10-02 git log --oneline 66493cd^2 | wc -l = 16 (Android history kept)."
  ],
  "notes": "Spec docs/superpowers/specs/2026-10-02-monorepo-and-api-design.md, layout A."
}
```

### parley-019

```json
{
  "id": "parley-019",
  "priority": 21,
  "area": "native-shell",
  "title": "Native macOS shell, phase 1: headless engine + Swift dictation",
  "user_visible_behavior": "SwiftUI menu-bar Parley.app dictates end to end (gesture, speak, release, pasted) with a glass HUD, driving the TypeScript engine under bundled Node over stdio JSON-RPC.",
  "status": "passing",
  "plan": "none: native shell, no web surface. Spec: docs/plans/parley-019-native-shell.md",
  "verification": [
    "make check",
    "Live: dictate into TextEdit, Notes, Slack from Parley.app; latency and RSS vs Electron"
  ],
  "evidence": [
    "2026-11-05 unit: headless-rpc 12 + headless-engine 14 vitest pass; ParleyCore 23 swift tests pass; tsc + eslint clean",
    "2026-11-05 build: make -C macos build clean (0 warnings), signed Apple Development; engine.mjs 40K + node v24.22.1 117M in Resources",
    "2026-11-05 smoke: bundled engine answers hello over stdio, refuses protocol 7; app refuses to start engine while Electron Parley runs",
    "2026-11-05 baseline: Electron Parley 276 MB RSS over 9 processes, 541 MB on disk",
    "2026-11-05 live: Parley Native.app, Electron quit; hello ok (engine 0.6.4); Accessibility granted live, key tap started without relaunch; 3 dictations via Left Shift x2 hold: listening -> transcribing -> pasted 14/29/23 chars -> done. Gesture release to paste 1.4 s, 1.1 s, 0.9 s (Groq via parley-api over Tailscale).",
    "2026-11-05 Accessibility and Microphone survive a rebuild and relaunch (Apple Development signing).",
    "2026-11-05 memory after use: app 196 MB + engine 102 MB RSS (idle before first use: 75 + 51). Not yet compared like for like with Electron (276 MB idle).",
    "2026-11-05 after the Electron removal (build with the new icon): the user dictated and confirmed it works; the app log shows pasted 6 and 64 chars at 23:15.",
    "2026-11-05 memory settled after use: app 92 MB + engine 68 MB = 160 MB RSS, against 276 MB for the Electron build at idle (9 processes).",
    "2026-11-05 make check green on main after PR #1 (merge 47ee962); GitHub CI passed."
  ]
}
```
