<!-- feature-plan:v1 — generated, do not hand-edit.
     Regenerate with: dart run tool/feature_plan.dart parley-a06.feature-plan.json -o FEATURE-PLAN.md -->

# Deepgram Nova-3 as a transcription provider

`parley-a06` · 1 surface

## Problem

Transcription only runs on Groq's Whisper. A user who already pays for Deepgram, or who wants Nova-3's accuracy, has no way to use it: the only key the app asks for, checks and needs to be ready is a Groq key.

## Not in this feature

- A vocabulary or dictionary screen. The Android app has none yet; Deepgram takes a keyterm list the day one exists, and Groq is left exactly as it is.
- Streaming transcription. Both providers get the finished WAV, as today.
- Changing voice edit. MiniMax stays the only rewriter.

## Surfaces

### API keys · `/api-keys`

Archetype: `form` — pick who transcribes, and replace or remove the keys

**Peak** — Tapping Deepgram Nova-3 swaps the key field under it in place, already labelled for Deepgram, with nothing else on the page moving.

**End** — Check and save returns to Settings with a Keys saved snack bar, and the Keys row names the provider now in use.

**Phone @390**

```
┌────────────────────────────────────┐
│ 9:41                     ▮▮▮  ▮▮   │
├────────────────────────────────────┤
│ ‹ API keys                       ⋯ │
├────────────────────────────────────┤
│ Transcription                      │
│ [ ( ) Whisper (Groq)  (o) Deepg… ] │
│ Radio rows, one sentence each.     │
│                                    │
│ Deepgram API key                   │
│ [ Paste a key                    ] │
│ Required for Deepgram. Empty keep… │
│                                    │
│ MiniMax API key                    │
│ [ Paste a key                    ] │
│ Optional. Turns on voice edit.     │
│                                    │
│ ┌────────────────────────────────┐ │
│ │ How they are used              │ │
│ │ ────────────────────────────── │ │
│ │ Deepgram  Nova-3 speech to te… │ │
│ │ MiniMax              voice ed… │ │
│ └────────────────────────────────┘ │
├────────────────────────────────────┤
│ [         Check and save         ] │
│            ────────────            │
└────────────────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ A fresh install      │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ opens on Whisper     │   │ A rejected key shows │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ (Groq), exactly as   │   │ the provider's own   │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ before, with the     │   │ message under its    │
│                      │   │ Groq field asking    │   │ field, and neither   │
│                      │   │ for gsk_.            │   │ the key nor the      │
│                      │   │                      │   │ provider switch is   │
│                      │   │ [ Check and save ]   │   │ saved. Choosing      │
│                      │   │                      │   │ Deepgram with no     │
│                      │   │                      │   │ Deepgram key saved   │
│                      │   │                      │   │ or typed says Add a  │
│                      │   │                      │   │ Deepgram key to use  │
│                      │   │                      │   │ Deepgram.            │
│                      │   │                      │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 skeleton mirrors rows     one action, 3 lines max    retry, never a raw error
```

Success: Keys and provider are saved together, the status turns ready when the chosen provider has a key, and the page closes.

Held to:

- one column, and the primary is bottom, full width, above the safe area — not bottom-right, which is the desktop idiom
- label above the field, helper below, error replaces the helper, so the layout does not jump when validation fires
- `dart run tool/ui_lint.dart` — every control comes from the kit and every colour, radius, duration and shadow from the tokens
- a golden at textScale 2.0 — the accessibility case that breaks layouts

## Overlays

```
      snack-bar · keys-saved
┌────────────────────────────────────┐
│ Keys saved                         │
│ ────────────────────────────────── │
│ Shown on Settings after the page   │
│ closes.                            │
└────────────────────────────────────┘
```

## Components

Each choice states the neighbour it beat. `Use when:` / `Instead:` for every
widget lives in `docs/references/design-system-reference-llms.txt`; the
families where three widgets are all defensible live in
`docs/principles/component-selection.md`.

| Surface | Widget | Why this one | Not |
| --- | --- | --- | --- |
| api-keys | `DSRadioGroup + DSRadioTile` | Two options that each need a sentence (which model, on whose account), all visible, exactly one chosen, and the answer is saved with the form rather than applied on tap. | `DSSegmentedButton — Whisper (Groq) and Deepgram Nova-3 clip at 320pt, and a segment reads as a view switch, not an answer` |
| api-keys | `DSTextField with DSFieldInput.password` | One key field for the chosen provider, swapped in place; label above, helper below, the provider's error replacing the helper so the layout does not jump. | `both transcription key fields at once — a field for a provider that is not in use is a question nobody needs to answer` |
| api-keys | `DSPinnedActionBar + DSButton` | The form's one primary, full width above the safe area, with its loading state while keys are checked. | `saving the provider the moment it is tapped — a switch to Deepgram without a working key would stop dictation` |

## Data model

- **ParleyConfig**
  - `transcriptionProvider`: TranscriptionProvider — groq (default) or deepgram
  - `deepgramKeyLast4`: String?
- **ParleyStatus**
  - `deepgramKeySet`: bool
  - `transcriptionProvider`: TranscriptionProvider
  - `transcriptionKeySet`: bool — the chosen provider has a key; what ready reads

## API endpoints

Each one needs a mock route in `lib/data/mock/mock_routes.dart` too, or the
screen does not run offline and the golden cannot be recorded.

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| POST | `https://api.deepgram.com/v1/listen?model=nova-3&language=…&smart_format=true&keyterm=…` | yes | transcribe the raw WAV body (Authorization: Token <key>) |
| GET | `https://api.deepgram.com/v1/projects` | yes | check a Deepgram key before it is saved |

## Integration points

```
  Session                               ──▶  ParleyRuntime.transcriber(provider)   (the configured provider picks GroqTranscriber or DeepgramTranscriber behind one Transcriber interface)
  ParleyBridge                          ──▶  verifyKey / setKeys / setConfig   (provider deepgram in verifyKey and setKeys; transcriptionProvider is a setConfig key)
  setup_page key step                   ──▶  the configured provider   (the step asks for the chosen provider's key and offers the other provider)
  parley_blocker / overview / settings  ──▶  ParleyStatus.transcriptionKeySet   (copy names the chosen provider instead of Groq)
```

## Blast radius

```
new (3)
  ├── android/app/src/main/kotlin/com/shivarajbakale/parley/Transcriber.kt
  ├── android/app/src/main/kotlin/com/shivarajbakale/parley/DeepgramTranscriber.kt
  └── android/app/src/test/kotlin/com/shivarajbakale/parley/DeepgramTranscriberTest.kt

changed (19)
  ├── android/app/src/main/kotlin/com/shivarajbakale/parley/GroqTranscriber.kt
  ├── android/app/src/main/kotlin/com/shivarajbakale/parley/ConfigStore.kt
  ├── android/app/src/main/kotlin/com/shivarajbakale/parley/Models.kt
  ├── android/app/src/main/kotlin/com/shivarajbakale/parley/Session.kt
  ├── android/app/src/main/kotlin/com/shivarajbakale/parley/ParleyRuntime.kt
  ├── android/app/src/main/kotlin/com/shivarajbakale/parley/ParleyBridge.kt
  ├── android/app/src/main/kotlin/com/shivarajbakale/parley/ParleyAccessibilityService.kt
  ├── android/app/src/main/res/values/strings.xml
  ├── lib/models/parley.dart
  ├── lib/services/parley/parley_bridge.dart
  ├── lib/services/parley/method_channel_parley_bridge.dart
  ├── lib/services/parley/fake_parley_bridge.dart
  ├── lib/screens/parley/api_keys_page.dart
  ├── lib/screens/parley/setup_page.dart
  ├── lib/screens/parley/parley_blocker.dart
  ├── lib/screens/parley/overview_page.dart
  ├── lib/screens/parley/parley_settings_page.dart
  ├── docs/plans/bridge-contract.md
  └── test/screens/api_keys_page_test.dart
```

## Verification plan

- [ ] `flutter analyze`
- [ ] `dart run tool/ui_lint.dart`
- [ ] `dart run tool/plan_lint.dart`
- [ ] `dart run tool/design_system_reference.dart --check`
- [ ] `flutter test`
- [ ] `make golden`
- [ ] the screen runs on a device, not only in a test — `flutter run --dart-define=ENV=dev`

---

Approve this before any file under `lib/` is written. Every frame
above is drawn from this feature's plan JSON, so the picture and the
build cannot drift; the archetypes are the twelve in
`docs/principles/screen-archetypes.md`, which every demo screen names
and `test/screens/archetypes_test.dart` holds them to.
