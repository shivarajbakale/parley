# BLUEPRINT

At-a-glance design for this Electron desktop app (Vite + React + TypeScript). This file **gates feature work**:
until it is approved, do not create `feature_list.json` entries or write feature
code. Keep it to roughly one screen of scroll.

- **Approved:** [x] approved
- **One-liner:** Tap-tap-hold voice dictation: Groq Whisper speech-to-text pasted at the cursor.

## Scope

- In scope: everything under "In v1" in
  [the design spec](docs/superpowers/specs/2026-09-21-parley-design.md).
- Explicitly out of scope: everything under "Out of v1" in the same spec.

## Surfaces / Screens / Endpoints

| Name | Purpose | Notes |
| ---- | ------- | ----- |
| Orb window | Listening, transcribing, done and error feedback | Transparent, never focusable, hidden when idle |
| Settings window | Settings and first-run onboarding | Opened from the tray |
| Tray menu | Status, Copy last transcript, Settings, Quit | No dock icon |
| Groq transcription | `POST /openai/v1/audio/transcriptions` | Called from the main process |

## Data Model

- Core entities: `Settings` (gesture key, tap count, vocabulary, tick sound, launch at login), encrypted API key, last transcript (memory only).
- Relationships: none.

## Open Questions

- None. The design was approved in brainstorming on 2026-09-21.

---

**Blueprint mode:** when this file is an unapproved stub and the user has
described the app, fill in every section above, then stop and surface it for
review — do not write code. Only once the user ticks `[x] approved` do you record
the approval in `claude-progress.md`, split the blueprint into `feature_list.json`
entries, and resume the normal operating loop.
