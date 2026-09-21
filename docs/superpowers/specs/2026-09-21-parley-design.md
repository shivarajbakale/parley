# Parley — design

Date: 2026-09-21
Status: approved in brainstorming, awaiting written-spec review

## Purpose

Parley is a macOS menu bar app for voice dictation into any text field. The
user performs a tap-tap-hold gesture on a modifier key, speaks while holding,
and releases. The speech is transcribed by Groq's hosted Whisper and pasted at
the cursor of whatever app is focused.

Personal-use tool. Target machine: macOS 26, Apple Silicon (arm64).

## Scope

### In v1

- Tap-tap-hold gesture on a configurable modifier key (default Right Option,
  default 3 taps).
- Microphone capture while the key is held.
- Transcription through Groq `whisper-large-v3-turbo`, language pinned to
  English.
- Raw Whisper output, pasted as is. No LLM cleanup pass.
- Paste at cursor through clipboard swap plus simulated Cmd+V.
- Floating audio-reactive orb, visible only during an active session.
- Soft tick sound when recording stops (toggleable). No start sound.
- Custom vocabulary, sent to Whisper as the `prompt` parameter.
- Menu bar only (no dock icon), launch at login.
- "Copy last transcript" tray item, held in memory only, one entry.
- First-run onboarding for Microphone permission, Accessibility permission
  and the Groq API key.

### Out of v1

Transcript history, failed-audio retry, LLM cleanup, per-app modes, voice
commands, streaming partial text, language selection, always-listening /
wake word, caret-following orb, code signing and notarization.

## Architecture

Electron app scaffolded by `@rocketship/create-electron-app` (Electron + Vite
+ React + Mantine, with the Rocketship agent harness and `make check` gate).

Three processes:

- **Main process** owns all state: key hook, gesture state machine, Groq
  call, paste injection, tray, settings, login item.
- **Orb window** (renderer): transparent, frameless, always-on-top,
  `focusable: false`, click-through (`setIgnoreMouseEvents(true)`), positioned
  bottom center of the active display. Owns microphone capture (`getUserMedia`
  only exists in a renderer), the orb animation and the stop sound.
- **Settings window** (renderer): ordinary window opened from the tray. Also
  hosts onboarding.

The orb window is created once at launch and kept hidden with `hide()`, never
destroyed, so that showing it costs nothing and the first word is not clipped.
The microphone stream opens at the third keydown and closes on release, so the
macOS microphone indicator shows only while the user is talking.

```
 MAIN PROCESS
   key-hook -> gesture-detector -> session --IPC--> ORB WINDOW
                                   /  |  \           (mic capture, animation,
                        transcriber   |   injector    tick sound)
                          (Groq)      |  (clipboard   <--audio--
                                      |    + Cmd+V)
        settings-store   permissions  tray  --IPC--> SETTINGS WINDOW
```

## Units

Main process, one file each under `electron/`:

| Unit | Responsibility | Depends on |
|------|----------------|------------|
| `gesture-detector` | Pure state machine. Takes key events with timestamps, emits `start`, `stop`, `cancel`. No Electron imports. | nothing |
| `key-hook` | Wraps `uiohook-napi`, forwards global keydown/keyup to `gesture-detector`. | `uiohook-napi` |
| `transcriber` | `transcribe(audio, { vocabulary }) -> Promise<string>`. POSTs to Groq `/openai/v1/audio/transcriptions` with `model=whisper-large-v3-turbo`, `language=en`, `prompt=<vocabulary>`. The single seam where a cleanup step could be added later. | `fetch`, API key |
| `injector` | Saves the clipboard, writes the transcript, simulates Cmd+V, restores the clipboard after about 200 ms. | Electron `clipboard`, key simulation via `uiohook-napi` or AppleScript |
| `settings-store` | JSON config in `userData`. API key encrypted with `safeStorage` (Keychain-backed). | Electron `safeStorage` |
| `permissions` | Checks Microphone and Accessibility status, opens the matching System Settings pane. | `systemPreferences` |
| `tray` | Menu bar icon and menu: status line, Copy last transcript, Settings, Quit. | Electron `Tray` |
| `session` | Orchestrator. Wires the units together and owns the session lifecycle. | all of the above |

Renderer:

- `orb/` — orb window entry: canvas animation driven by mic amplitude,
  `MediaRecorder` capture of a 16 kHz mono track, encoded as WebM/Opus (Groq
  accepts it, and 10 minutes stays far below the 25 MB cap), stop
  sound.
- `settings/` — settings and onboarding UI, built with the scaffold's Mantine
  design system.

## Gesture

Default: Right Option, 3 taps.

1. Tap 1 and tap 2: keydown then keyup, each press shorter than 250 ms, gap
   between presses under 300 ms.
2. Press 3 held longer than 150 ms: emit `start`.
3. Keyup of press 3: emit `stop`.
4. Esc while held: emit `cancel`.

Rules:

- Any other key pressed between taps resets the machine, so normal
  Option+letter shortcuts never trigger it.
- Any timeout resets the machine silently. Key events are observed, never
  swallowed.
- Only modifier keys are selectable as the gesture key, because a character
  key would type into the focused field before recording starts.
- Tap count is configurable from 2 to 4.

## Data flow

1. Gesture completes: `gesture-detector` emits `start`.
2. `session` tells the orb window to show and record. The orb fades in
   (about 120 ms) and animates from live mic amplitude.
3. Release: `stop`. Orb plays the tick, sends 16 kHz mono audio to main over
   IPC, switches to the transcribing state.
4. `transcriber` calls Groq (about 300 ms for a short clip).
5. `injector` pastes into the focused field. Orb flashes for about 300 ms and
   hides. The transcript is kept as the tray's "Copy last transcript".

## Orb visibility

| State | Orb visible |
|-------|-------------|
| Idle | No. Only the tray icon exists. |
| Tap 1, tap 2 | No. Avoids flicker during normal Option use. |
| Third press held | Yes. Fades in, listening, swells and glows with voice level. |
| Released | Yes. Contracts, shimmers while transcribing. |
| Pasted | Yes for about 300 ms (flash), then fades out. |
| Error | Yes for 3 s, red tint with a short message, then fades out. |
| Cancelled | Fades out at once. |

The orb never takes focus. If it did, the paste would land in the wrong
window.

## Error handling and edge cases

- Audio shorter than 300 ms: discarded, no API call, orb fades out.
- Esc during hold: cancelled, nothing pasted.
- Recording reaches 10 minutes: auto-stop and transcribe (Groq upload cap is
  25 MB).
- No internet, Groq error or invalid key: orb shows a red state and a short
  message for 3 s. Nothing is pasted, the clipboard is untouched.
- Missing Microphone or Accessibility permission: gesture opens onboarding
  with a button that deep-links to the right System Settings pane. Without
  Accessibility the key hook cannot see keys at all, so onboarding also opens
  at launch whenever a permission or the API key is missing.
- No API key configured: gesture opens the settings window.
- Empty transcript (silence): nothing pasted, orb fades out.
- A second gesture during transcription is ignored until the session ends.

## Settings

- Groq API key, with a Test button that validates the key.
- Gesture key (modifier keys only, default Right Option).
- Tap count (default 3).
- Custom vocabulary (free text, comma separated).
- Play tick sound when recording stops (default on).
- Launch at login (default on).
- Read-only permission status for Microphone and Accessibility.

## Testing

- Unit tests (Vitest):
  - `gesture-detector`: valid gesture, slow taps, interleaved keys, Esc
    cancel, configurable key and tap count, reset after timeout.
  - `transcriber`: request shape (model, language, prompt), error mapping,
    with `fetch` mocked.
  - `injector`: clipboard is restored, also when the paste fails.
  - `settings-store`: defaults, persistence, key encryption round trip.
  - `session`: short-audio discard, busy-state guard, error path leaves the
    clipboard untouched, with the units mocked.
- Manual checklist (the native hook and OS permissions cannot be automated):
  paste into Safari, Chrome, Slack, VS Code, Terminal and Notes; permission
  onboarding from a clean state; offline behaviour.
- `make check` stays green throughout.

## Risks

- `uiohook-napi` is a native module. It must be rebuilt against Electron's
  ABI for arm64. Fallback: a small Swift helper binary that emits key events
  over stdout.
- macOS resets the Accessibility grant whenever an unsigned development build
  changes. Known annoyance during development.
- Distribution (signing, notarization) is out of scope. v1 runs from a local
  build.
