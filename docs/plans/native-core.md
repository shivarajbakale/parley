# Native core plan — orb, accessibility service, pipeline

`SUPERPLAN.md` plans the Flutter screens. This document plans the part that is
not a screen: the Kotlin code under `android/app/src/main/kotlin/` that draws
the orb over other apps, records, transcribes, and inserts text. It runs while
the Flutter UI is closed, so it cannot live in Dart.

Decisions behind it are recorded in `SUPERPLAN.json` `decisions[]` (pipeline in
Kotlin, native orb, native owns storage, SET_TEXT then paste fallback).

## Shape

```
┌──────────────────────── Parley process ─────────────────────────┐
│                                                                 │
│  ParleyAccessibilityService  (bound by the system, long-lived)  │
│   ├─ OrbController ── OrbView (Canvas, TYPE_ACCESSIBILITY_OVERLAY)
│   ├─ VolumeGestureDetector ◄── onKeyEvent(KEYCODE_VOLUME_DOWN)  │
│   ├─ FocusTracker ◄── onAccessibilityEvent(focus/selection)     │
│   └─ Session (one recording at a time)                          │
│        Recorder (AudioRecord 16 kHz mono → WAV)                 │
│        GroqTranscriber / MiniMaxRewriter (OkHttp)               │
│        Injector (SET_TEXT → PASTE → clipboard)                  │
│        HistoryStore (SQLite)                                    │
│                                                                 │
│  ConfigStore (EncryptedSharedPreferences)                       │
│                                                                 │
│  MainActivity (FlutterActivity)                                 │
│   └─ ParleyBridge: MethodChannel parley/bridge                  │
│                    EventChannel  parley/events ─► Flutter UI     │
└─────────────────────────────────────────────────────────────────┘
```

Ports from the Mac app (`~/Projects/parley/electron/`): `gesture-detector.ts`
(timing windows), `session.ts` (state machine), `transcriber.ts`,
`rewriter.ts` (prompt), `injector.ts` (leading-space rule). Port the logic and
its tests, not the Electron plumbing.

## Session state machine

```
idle ──hold orb / tap-tap-hold──► listening ──release──► transcribing
  ▲                                  │ >120 s or cancel        │
  │                                  ▼                         ▼
  └──── done (1.2 s) ◄── inserting ◄─────── (edit mode) rewriting
  └──── error (2 s, orb shakes, tap to copy last text)
```

- Release under 300 ms of audio: discard, back to idle, no API call.
- Mode is fixed at start: orb double-tap-then-hold is **edit**, everything else
  is **dictation**.
- The field target is captured at start (window id + node id + selection), so
  focus moving during transcription does not send text to the wrong field.

## Components

**ParleyAccessibilityService.** `accessibility_service_config.xml`:
`typeViewFocused|typeViewTextSelectionChanged|typeWindowStateChanged`,
`flagRequestFilterKeyEvents`, `flagRetrieveInteractiveWindows`,
`canRetrieveWindowContent=true`, `isAccessibilityTool=false`. Personal use,
so there is no Play disclosure flow.

**OrbView.** A 36/44/52 dp lit sphere in a `TYPE_ACCESSIBILITY_OVERLAY` window
(needs no `SYSTEM_ALERT_WINDOW`), drawn as one shape that morphs. It is
draggable (lifts 1.08x) and docks to the nearest edge with a small overshoot;
the position is saved. States: idle (highlight slowly drifts), listening (the
sphere stretches into a capsule toward the screen centre with a live waveform
and an `m:ss` timer, "Edit" for a voice edit, red in the last 10 s before the
2-minute cap), working (two soft lights circle inside), done (pop to 1.12x and
a drawn tick, green fading back to indigo), error (shake, and the capsule
shows the message). A press squashes it to 0.92x. Sizes run on springs
(`OrbMotion.kt`) and colours crossfade over 250 ms. The window is only as wide
as the current shape, anchored on the docked side. When "Tuck away outside
text fields" is on, it slides into the edge (14 dp showing, dimmed) while no
editable node has focus; a tap brings it out for 3 s. It glides above the IME
(300 ms, the IME's easing), reading the keyboard window's bounds from a focus
check that is throttled, not debounced, so a busy screen cannot starve it.

**VolumeGestureDetector.** A pure Kotlin class that takes key down/up events
with timestamps. Tap-tap-hold means two taps and a third press held longer
than 250 ms, with at most 350 ms between presses. The service consumes
volume-down while armed, and after the window closes it replays single presses
with `AudioManager.adjustStreamVolume`. Volume-up is never touched. The
gesture works only with the screen on (Android does not deliver key events to
accessibility services when the screen is off).

**Recorder.** `AudioRecord` at 16 kHz, mono, PCM16, written to a WAV file in
the cache directory: 32 KB/s, about 3.8 MB for two minutes, well under Groq's
upload limit. The RMS level is published at 30 Hz for the orb. It runs under a
foreground service of type `microphone` while listening; see Spike A01.

**GroqTranscriber.** `POST https://api.groq.com/openai/v1/audio/transcriptions`
with model `whisper-large-v3-turbo`, `response_format=text`, and the language
from config. Timeouts: 10 s connect, 30 s read. One retry on 5xx.

**MiniMaxRewriter.** Uses the Mac app's rewrite prompt and chat completions
API. Input is the instruction plus the target text (the selection, or the
whole field). Output is the replacement text only.

**Injector.**
1. Re-find the captured node (`AccessibilityNodeInfo.refresh()`). If it is not
   editable, or `isPassword` is true, refuse and copy to the clipboard instead.
2. Dictation: `new = text[0:selStart] + lead + dictated + text[selEnd:]`, where
   `text` is empty if `isShowingHintText`. Call `ACTION_SET_TEXT`, then
   `ACTION_SET_SELECTION` to the end of the inserted text.
3. If SET_TEXT returns false, or the node text did not change after 150 ms,
   put the text on the clipboard, call `ACTION_PASTE`, and restore the old
   clipboard after 1 s.
4. If that fails too, leave the text on the clipboard and show the orb's
   "copied" state.
5. Edit mode replaces the captured range (or the whole text) the same way. The
   before text is kept for 10 s, and tapping the orb in that window undoes.

Record `insertMethod` on the history entry every time, so the History filter
shows which apps need the fallback.

**HistoryStore.** Plain `SQLiteOpenHelper` with one table matching
`HistoryEntry`. Retention is pruned on service start. Words are counted by
whitespace split. `savedMs = max(0, words / 35 wpm − recordingMs)`.

**ConfigStore.** EncryptedSharedPreferences. Keys never cross the bridge in
full, only their last 4 characters. Changes go out to the service in-process
through a `StateFlow`.

**ParleyBridge.** The MethodChannel methods listed in `SUPERPLAN.json`
endpoints, plus the EventChannel for status and new entries. The Dart side is
`lib/services/parley_bridge.dart`, with a `FakeParleyBridge` so widget tests,
goldens and `make ui-probe` run without Android.

## Build order (feature_list.json entries after approval)

| # | id | What | Proves |
|---|----|------|--------|
| 1 | `parley-a01` | **Spike**: service + orb + record 5 s from Messages + SET_TEXT "hello" | The three risky platform bets on the real phone |
| 2 | `parley-a02` | Session + Recorder + GroqTranscriber + Injector with fallbacks; orb hold to dictate | Dictation end to end |
| 3 | `parley-a03` | VolumeGestureDetector + volume replay | Second trigger |
| 3b | `parley-a05` | **Aurora identity**: swap `lib/theme/spec` from halo to aurora (palette, type, shape), bundle Instrument Serif / Geist / Geist Mono, regenerate `DESIGN.md`, match the orb's Kotlin gradients to the same mode tokens; `palette-lint` and goldens green in both themes | Every screen after this is built in the final look |
| 4 | `route:setup` | Bridge + Setup sequence | First run without adb |
| 5 | `route:overview` | Overview + pause | Status in the app |
| 6 | `parley-a04` | Voice edit: MiniMaxRewriter, range replace, undo | Edit end to end |
| 7 | `route:history`, `route:history-detail` | HistoryStore + screens | Record and time saved |
| 8 | `route:settings`, `route:api-keys` | Config live-apply | Tuning without reinstall |

Native entries follow the harness contract, like the screen entries: one
feature is active at a time, and `passing` requires evidence. Evidence for a
native feature is the JUnit output plus a screen recording from the phone
(`adb shell screenrecord`), saved under `docs/evidence/<id>/`.

## Spike A01 — do this before anything else

This spike answers three questions on the author's phone. Record its Android
version and OEM.

1. **Background mic.** Can the service start a `microphone` foreground service
   and record while another app is in front, on Android 14+? If not, try
   these fallbacks in order: (a) start the FGS from the orb touch, a user
   interaction on our own window; (b) keep a low-priority FGS running whenever
   the orb is enabled, and turn on recording inside it.
2. **Insertion.** Does SET_TEXT work in Messages, WhatsApp, Gmail, Keep and
   Chrome (address bar and a web textarea)? Log a table of which apps need
   PASTE.
3. **Volume consume + replay.** Does the replayed volume change feel
   acceptable? If not, switch the gesture to a volume-down + volume-up chord
   (open question in the superplan).

The spike's code is thrown away; its findings table goes into `DECISIONS.md`.

## Verification wiring

- `make check` gains a `native-test` target: `cd android && ./gradlew
  testDebugUnitTest`. It covers the gesture detector timing table, text
  splicing (hint text, selection, leading space, emoji surrogate pairs), the WAV
  header, the transcriber and rewriter against MockWebServer, and history
  retention.
- Device checks are manual and recorded as evidence. Automating them with UI
  Automator is not in v1.
- `ios/` is untouched and excluded from the gate; iOS is a non-goal.

## Risks

| Risk | Mitigation |
|------|------------|
| OEM battery killers (Samsung, Xiaomi) unbind the service | Setup step for the Unrestricted battery setting; Overview shows Off with a one-tap fix |
| Background-mic restriction | Spike A01 decides the approach before any other code |
| SET_TEXT wipes rich text or breaks the app's undo stack | Paste fallback per app, logged in history |
| Keys on a rooted or lost phone | EncryptedSharedPreferences; keys are per-user and revocable at the provider |
