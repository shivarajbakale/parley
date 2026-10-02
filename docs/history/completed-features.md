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
