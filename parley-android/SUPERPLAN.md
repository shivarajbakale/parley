<!-- super-plan:v1 — generated, do not hand-edit.
     Regenerate with: dart run tool/super_plan.dart SUPERPLAN.json -o SUPERPLAN.md -->

# Superplan — Parley

Floating-orb voice dictation and voice edit for any Android text field.

**Problem.** Typing on a phone is slow and error-prone, and the built-in voice typing lives inside one keyboard, gets names wrong, and cannot rewrite what is already written. The Mac version of Parley fixed this with a system-wide gesture: tap-tap-hold, speak, release, and the text lands at the cursor, or say 'make it shorter' and the field is rewritten. On Android there is no equivalent that works in every app without replacing the keyboard.

**Target users.** One person: the author of Parley for macOS, dictating into chat, mail and notes apps on their own Android phone, with their own Groq and MiniMax API keys.

**Industry.** productivity — see `docs/references/industry-conventions.md` for the design language this brief pulls from.

## Decisions

5 answered by you, 6 assumed. Every assumption below is a question that was not asked — read those first.

| | Question | Call | Why |
| --- | --- | --- | --- |
| you | How does it ship — Play Store, sideload for others, or personal use? | Personal use only. Sideloaded debug/release APK on the author's phone. | — |
| you | What starts a recording? | Both: hold the floating orb, or triple-press volume-down holding the third press. | — |
| you | What is in v1? | Dictation, voice edit, and history with time saved. Personal dictionary is not in v1. | — |
| you | Does the phone share data with the Mac app? | Not in v1. | — |
| **assumed** | Which rocketship scaffolder? | create-flutter-app. It is the mobile scaffolder with the full 13/13 harness and planning skills; create-react-native-app ships without the harness docs. | The user asked to use rocketship and to pick the boilerplate; Flutter is the only mobile one with the full harness |
| **assumed** | Where does the dictation pipeline run — Dart or Kotlin? | Kotlin, inside the accessibility service process. Flutter owns only the app screens and talks to the service over one MethodChannel + one EventChannel. | The pipeline must run while the Flutter UI is closed; a headless Flutter engine per recording adds 30-40 MB and start-up latency to the one path that has to feel instant |
| **assumed** | How is the orb drawn? | A native Kotlin Canvas view in a TYPE_ACCESSIBILITY_OVERLAY window, not a Flutter view. | The accessibility overlay type needs no SYSTEM_ALERT_WINDOW permission, and a native view animates mic levels without keeping a second Flutter engine alive |
| **assumed** | Who owns history and settings storage? | The native side. SQLite for history, EncryptedSharedPreferences for keys and settings. Flutter reads and writes only through the bridge. | One writer, no sync: the service writes history while the app is closed, and two stores (Drift + native) would drift |
| **assumed** | How is text inserted into another app's field? | ACTION_SET_TEXT on the focused editable node, splicing at the selection; fallback is clipboard + ACTION_PASTE; last resort is clipboard + a 'copied' state on the orb. | SET_TEXT keeps the clipboard untouched and works in native and Compose fields; Chrome web fields and some custom editors only accept paste |
| you | How much should the look matter? | A lot: the UI should look amazing, with a very good theme. | — |
| **assumed** | Which visual identity? | Aurora: dark-first ink ground, the Mac app's indigo/amber/green mode colours, Nunito + Nunito Sans (was Instrument Serif + Geist + Geist Mono), the orb as the only glow. | Carries the Mac orb palette over so both apps read as one product, and a serif for the user's own words sets transcripts apart from interface text |

## MVP cut

**In:**
- Floating orb over every app, drawn by an accessibility overlay: hold it to dictate, release to insert
- Volume-down tap-tap-hold as a second trigger, mirroring the Mac gesture
- Dictation: Groq Whisper transcribes and the text is inserted at the cursor of the focused field
- Voice edit: hold the orb and slide toward the middle of the screen (orb-only in v1), then speak an instruction; MiniMax rewrites the selection or the whole field
- History of dictations and edits, with the time saved on an Overview
- First-run setup: API keys, microphone, accessibility service, battery exemption, one practice dictation

**Deferred (explicit):**
- Personal dictionary (names and jargon) — v1.1, same Whisper-prompt approach as desktop
- Explain-selection popover — v1.1, via the text-selection PROCESS_TEXT menu
- Offline transcription with whisper.cpp
- Dictionary or history sync with the Mac app
- Play Store release and its prominent-disclosure flow

## App-level non-goals

- A keyboard (IME). The orb sits over whatever keyboard is already installed.
- Google Play distribution. Personal use, sideloaded with adb, so no Play accessibility-policy work.
- iOS. iOS has no API for an overlay that inserts text into other apps; the ios/ folder stays untouched.
- Sync with the Mac app. The phone stands alone in v1.

## Navigation map

```
tabs: Overview · History · Settings
```

```
First run
  └─ /setup              Setup (sequence, no tab) → /
Home shell
  ├─ /                   Overview (tab 1)
  ├─ /history            History (tab 2)
  ├─ /history/:id        Transcript (pushed from row)
  ├─ /settings           Settings (tab 3)
  └─ /settings/keys      API keys (pushed from Settings)
Outside Flutter (native)
  └─ Orb overlay + accessibility service, running over every app
```

## Modules

| Module | Decision |
| --- | --- |
| `auth` | none |
| `onboarding` | required |
| `paywall` | none |
| `analytics` | none |
| `push` | none |

## Theme tokens

- Identity name: aurora (docs/design/aurora.md), swapped in for the shipped halo identity through lib/theme/spec; palette-lint K1..K7 must pass in both themes
- Dark is the default theme; light is fully supported. Dark: ground #0E0E14, surface #17171F, raised #1F1F2A, border #23232F, text #EDEDF5, muted #9C9CB2, action fill #5555E0, action text #8B8BFF
- Light: ground #F5F5F8, surface #FFFFFF, raised #EFEFF5, border #E6E6EE, text #15151D, muted #5C5C70, action #4646D6
- Mode colours shared by orb, status dots and history dots: dictation #8B8BFF (indigo, hue 277 as on the Mac), voice edit #F4B942 (amber), inserted #4CD38A (green), error #FF6E6E. Light-mode text variants darken to pass 4.5:1
- Typefaces: rounded Nunito for titles and figures; Nunito Sans for interface text and, in italic, for the user's own words (transcripts, instructions). Four sizes: 40 / 22 / 16 / 13, plus 32 for stats. Changed from Instrument Serif + Geist + Geist Mono on 2026-09-24 at the owner's request (DECISIONS.md)
- Shape: cards 24 radius (hero 28), buttons 18, chips pill. 8-point spacing. Borders instead of shadows in dark; soft tinted shadows in light
- The orb is the only glow in the app: layered radial gradient in the mode colour, breathing 4.2 s when idle, 1.1 s pulse plus expanding ring while listening, spinning arc while working. No gradient washes on backgrounds
- Motion: 200 ms cross-fades, springy orb state changes, respects reduce-motion (orb stops breathing, keeps colour)
- Reference mockups: https://claude.ai/artifact/KHuAChbQqTC4rzpxnreHBj

## Dependencies

- **Kotlin: android.accessibilityservice.AccessibilityService** — ParleyAccessibilityService: overlay host, focused-field reader, text insertion, volume-key filter. See docs/plans/native-core.md
- **Kotlin: OkHttp 4** — Groq transcription (multipart WAV) and MiniMax chat completions, called from the service
- **Kotlin: androidx.security:security-crypto** — EncryptedSharedPreferences for API keys
- **Kotlin test: JUnit 4, Robolectric, OkHttp MockWebServer** — Unit tests for gesture detector, text splicing, WAV writer, API clients; wired into make check via ./gradlew testDebugUnitTest

## Routes

6 routes. Each renders a phone-frame wireframe from the same twelve archetypes the per-feature `FEATURE-PLAN.md` keys off, so the shape approved here and the shape approved per feature cannot drift.

### Setup · `/setup`

Archetype: `sequence` — Get from install to a working orb in one pass: keys, mic, accessibility, battery, one practice dictation

**Phone @390**

```
┌────────────────────────────────────┐
│ 9:41                     ▮▮▮  ▮▮   │
├────────────────────────────────────┤
│ ‹ Setup                            │
├────────────────────────────────────┤
│ ● ○ ○ ○ ○ ○  DSSegmentedProgress … │
│                                    │
│ ┌────────────────────────────────┐ │
│ │ 1. Talk, and it types — in an… │ │
│ │ Hold the orb or press volume-… │ │
│ └────────────────────────────────┘ │
│    job: brand                      │
│                                    │
│ ┌────────────────────────────────┐ │
│ │ 2. Your Groq key               │ │
│ │ Paste it; we check it with on… │ │
│ └────────────────────────────────┘ │
│    job: activation                 │
│                                    │
│ ┌────────────────────────────────┐ │
│ │ 3. Microphone                  │ │
│ │ Only while you hold the orb. … │ │
│ └────────────────────────────────┘ │
│    job: trust                      │
│                                    │
│ ┌────────────────────────────────┐ │
│ │ 4. Turn on Parley in Accessib… │ │
│ │ This draws the orb, reads the… │ │
│ └────────────────────────────────┘ │
│    job: trust                      │
│                                    │
│ ┌────────────────────────────────┐ │
│ │ 5. Keep Parley running         │ │
│ │ Set battery to Unrestricted s… │ │
│ └────────────────────────────────┘ │
│    job: activation                 │
│                                    │
│ ┌────────────────────────────────┐ │
│ │ 6. Try it                      │ │
│ │ Hold the orb and say 'testing… │ │
│ └────────────────────────────────┘ │
│    job: activation                 │
│                                    │
│ ◂ back: Back returns to the previ… │
│ ▸ then: overview                   │
├────────────────────────────────────┤
│ [            Continue            ] │
│            ────────────            │
└────────────────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ Fresh install: step  │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ one, nothing         │   │ Key check failed:    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ granted, all         │   │ the field shows      │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ segments empty.      │   │ Groq's error message │
│                      │   │                      │   │ ('Invalid API key')  │
│                      │   │ [ Continue ]         │   │ and Continue stays   │
│                      │   │                      │   │ disabled.            │
│                      │   │                      │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 skeleton mirrors rows     one action, 3 lines max    retry, never a raw error
```

Success: All six segments filled; the practice field shows the dictated text and the primary becomes 'Done'.

**Look & feel**

- **Header:** DSCompactAppBar with the step title; no close button until the accessibility step is done
- **Motion:** Steps cross-fade 200ms; the progress segment fills as each step completes
- **Dark mode:** Follows system; the practice field uses the surface ladder

**Layout (region → kit)**

| Region | Kit | Purpose |
| --- | --- | --- |
| `header` | `DSCompactAppBar`, `DSSegmentedProgress` | — |
| `body.scroll` | `DSText`, `DSTextField` | — |
| `footer` | `DSPinnedActionBar` | — |

scroll `scrollable_header_pinned_footer` · pinned: `header`, `footer` · safe area ✓ top · safe area ✓ bottom

**Components (2)**

| Kit | Region | Purpose | Why | Not |
| --- | --- | --- | --- | --- |
| `DSSegmentedProgress` _(feedback)_ | `header` | Shows which of the six setup steps the user is on | Six discrete steps read better as segments than as a continuous bar, and segments show which grant is still missing | `DSStepper, whose vertical list makes each step a form section rather than a screen` |
| `DSPinnedActionBar` _(chrome)_ | `footer` | Continue / Open settings primary for each step | Grant steps send the user out to system Settings and back; a pinned primary is always where they left it | `an inline button under the text, which moves as step copy changes length` |

**Best practices — Accessibility**

- Each step's status (granted / not yet) is announced, not only shown by a check icon
- The practice step works with the volume-key trigger too, for TalkBack users who cannot find the orb

**Best practices — Design-system rules**

- One primary per step, pinned; 'Open settings' deep links are the primary on grant steps

**Best practices — Verification**

- Resume after returning from system Settings re-checks the grant and advances automatically
- Killing the app mid-setup and reopening lands on the first incomplete step

**Best practices — Non-goals**

- Explaining every setting; the Settings tab owns that

**Gestures (1)**

| Selector | Event | Behaviour | Haptic |
| --- | --- | --- | --- |
| `Continue (DSPinnedActionBar)` | `tap` | validates the step and advances | selectionClick |

**Journeys (2)**

- **First run to first dictation** ✓ happy path
  - `/setup brand → key → mic → accessibility (system settings, back) → battery → try it → /`
- **Wrong key**
  - `/setup key → paste → verify fails → error under field → fix → continue`

**APIs required**

- **Entities:** ServiceStatus, Config

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| CHANNEL | `parley/bridge#getStatus` | no | which grants are in place: mic, accessibility service bound, battery exemption, keys present |
| CHANNEL | `parley/bridge#openSystemSettings` | no | deep link to accessibility, battery or app-permission settings |
| CHANNEL | `parley/bridge#verifyKey` | no | one cheap request to Groq or MiniMax to prove the key works before saving it |

- **Providers:** serviceStatusProvider, setupProgressProvider

| From | To | Note |
| --- | --- | --- |
| `app_router redirect` | `/setup` | any launch where getStatus reports a missing grant or key |
| `setup last step` | `/` | handover after the practice dictation succeeds |

**Blast radius**

```
new (4)
  ├── lib/screens/setup/setup_page.dart
  ├── lib/services/parley_bridge.dart
  ├── lib/services/fake_parley_bridge.dart
  └── test/screens/setup_page_test.dart

changed (1)
  └── lib/utils/app_router.dart
```

**Sprint**

- order `3`, size `M`

Verification gate:
- `flutter analyze --no-fatal-infos`
- `flutter test test/screens/setup_page_test.dart`
- `make ui-probe`
- `Manual: fresh install on device reaches a working orb`

### Overview · `/`

Archetype: `focal` — Is Parley ready right now, and what has it saved me

**Phone @390**

```
┌────────────────────────────────────┐
│ 9:41                     ▮▮▮  ▮▮   │
├────────────────────────────────────┤
│   Overview                       ⋯ │
├────────────────────────────────────┤
│ ┌────────────────────────────────┐ │
│ │ Ready — hold the orb to talk   │ │
│ │ Orb on · Volume-down gesture … │ │
│ └────────────────────────────────┘ │
│                                    │
│ ┌──────────────┐ ┌───────────────┐ │
│ │ Words… 2,318 │ │ Time … 41 min │ │
│ └──────────────┘ └───────────────┘ │
│                                    │
│ ┌────────────────────────────────┐ │
│ │ Last: “Running ten minutes la… │ │
│ └────────────────────────────────┘ │
│                                    │
│                                    │
│                                    │
│                                    │
├────────────────────────────────────┤
│ ● Overview  ○ History  ○ Settings  │
│            ────────────            │
└────────────────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ Nothing dictated     │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ yet: tiles read 0    │   │ Service not running: │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ and the wide tile    │   │ hero reads 'Off' in  │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ says 'Hold the orb   │   │ the danger colour    │
│                      │   │ in any app to        │   │ with 'Turn on in     │
│                      │   │ start'.              │   │ Accessibility' as    │
│                      │   │                      │   │ the action.          │
│                      │   │                      │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 skeleton mirrors rows     one action, 3 lines max    retry, never a raw error
```

Success: Hero reads Ready, tiles filled, last transcript shown.

**Look & feel**

- **Header:** Serif Parley wordmark, no app bar chrome; the hero card holds a live 112 dp orb with its halo, the status title, two status chips and the on/off switch
- **Motion:** Status dot pulses once when the service reconnects; numbers tick up on new data
- **Dark mode:** Status colours unchanged; tiles on the surface ladder

**Layout (region → kit)**

| Region | Kit | Purpose |
| --- | --- | --- |
| `header` | `DSLargeAppBar` | — |
| `body.bento` | `DSCard`, `DSStatTile`, `DSListTile` | — |

scroll `scrollable` · pinned: `header` · safe area ✓ top · safe area ✓ bottom

**Components (2)**

| Kit | Region | Purpose | Why | Not |
| --- | --- | --- | --- | --- |
| `DSLargeAppBar` _(chrome)_ | `header` | App title over the status hero | The hero is the content; a large bar that collapses leaves the tiles room on small phones | `a custom header drawing the orb, which would duplicate the overlay` |
| `DSStatTile` _(row)_ | `body.bento` | Words this week and time saved | A stat tile is one figure with a label, which is exactly what these two tiles are | `DSListTile rows, which bury the number at the trailing edge` |

**Best practices — Accessibility**

- The hero announces the status sentence and what is armed, not the colour
- Time saved is read as '41 minutes saved this week'

**Best practices — Design-system rules**

- Status colours come from the mode tokens shared with the orb

**Best practices — Verification**

- Disable the accessibility service in system settings: the hero switches to 'Off — turn on Parley in Accessibility' with that as the action
- Time saved matches the formula: words / 35 wpm typing minus recording seconds, floored at zero per entry

**Best practices — Non-goals**

- Charts over time; one number per tile is enough for personal use

**Gestures (2)**

| Selector | Event | Behaviour | Haptic |
| --- | --- | --- | --- |
| `wide tile (last transcript)` | `tap` | pushes /history/:id | none |
| `Pause Parley` | `tap` | hides the orb and disarms the volume gesture until tapped again | mediumImpact |

**Journeys (2)**

- **Check it is ready** ✓ happy path
  - `open app → / hero reads Ready`
- **Service was killed**
  - `open app → / hero reads Off → tap action → system Accessibility → back → Ready`

**APIs required**

- **Entities:** ServiceStatus, UsageSummary

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| CHANNEL | `parley/bridge#getUsageSummary` | no | words and time saved this week, plus the last entry |
| CHANNEL | `parley/bridge#setPaused` | no | hide the orb and disarm the volume gesture without unbinding the service |
| EVENT | `parley/events` | no | status changes and new history entries pushed from the service |

- **Providers:** serviceStatusProvider, usageSummaryProvider

| From | To | Note |
| --- | --- | --- |
| `home shell` | `/` | first tab |
| `last-entry tile` | `/history/:id` | tap opens the transcript |

**Blast radius**

```
new (3)
  ├── lib/screens/overview/overview_page.dart
  ├── lib/providers/parley_providers.dart
  └── test/screens/overview_page_test.dart

changed (2)
  ├── lib/screens/home_screen.dart
  └── lib/utils/app_router.dart
```

**Sprint**

- order `4`, size `S`, depends on setup

Verification gate:
- `flutter analyze --no-fatal-infos`
- `flutter test test/screens/overview_page_test.dart`
- `make ui-probe`

### History · `/history`

Archetype: `collection` — Find something I dictated earlier and copy it again

**Phone @390**

```
┌────────────────────────────────────┐
│ 9:41                     ▮▮▮  ▮▮   │
├────────────────────────────────────┤
│                                    │
├────────────────────────────────────┤
│ History                            │
│                                    │
│ [ ⌕ Search transcripts           ] │
│                                    │
│ ( All ) ( Dictation ) ( Edits ) ▸  │
│                                    │
│ ────────────────────────────────── │
│  Running ten minutes late, start…  │
│ ────────────────────────────────── │
│  Edit: make it shorter          …  │
│ ────────────────────────────────── │
│  Pick up milk and the dry cleani…  │
│ ────────────────────────────────── │
│                                    │
│ ◂ swipe: Delete                    │
│   also on: the row's overflow men… │
├────────────────────────────────────┤
│ ○ Overview  ● History  ○ Settings  │
│            ────────────            │
└────────────────────────────────────┘
```

**States**

```
        loading                     empty                   zero results                  error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ No history yet:      │   │ No transcripts match │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ 'Things you dictate  │   │ 'invoice' — clear    │   │ Could not read       │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ show up here' with   │   │ the search or change │   │ history: error state │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ no action.           │   │ the filter.          │   │ with Retry.          │
│                      │   │                      │   │                      │   │                      │
│                      │   │                      │   │ [ Clear filters ]    │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 skeleton mirrors rows     one action, 3 lines max       clears the filter       retry, never a raw error
```

Success: Newest first, grouped by day.

**Look & feel**

- **Header:** DSCompactAppBar titled History with the search bar under it
- **Motion:** Deleted row collapses over 200ms with Undo in a snack bar
- **Dark mode:** Rows on surface; mode chip uses the mode colour at low emphasis

**Layout (region → kit)**

| Region | Kit | Purpose |
| --- | --- | --- |
| `header` | `DSCompactAppBar` | — |
| `body.scroll` | `DSSearchBar`, `DSChipGroup`, `DSDismissibleTile` | — |

scroll `scrollable` · pinned: `header` · safe area ✓ top · safe area ✓ bottom

**Components (3)**

| Kit | Region | Purpose | Why | Not |
| --- | --- | --- | --- | --- |
| `DSDismissibleTile` _(row)_ | `body.list` | One history entry with swipe-to-delete | Delete is the only destructive action here and swipe is the platform idiom for it | `a selection mode with a bulk-delete bar, which is ceremony for a personal log` |
| `DSSearchBar` _(chrome)_ | `body.scroll` | Search transcript text | Finding a past dictation by a word in it is the main reason to open this tab | `a search icon that opens a separate route` |
| `DSChipGroup` _(tag)_ | `body.scroll` | Mode and outcome filters | Four short, mutually exclusive filters fit one chip row | `DSSegmentedButton, which does not scroll if a fifth filter arrives` |

**Best practices — Accessibility**

- Row announces text, app and time; swipe has the overflow-menu twin

**Best practices — Design-system rules**

- Rows are DSDismissibleTile; filters are a DSChipGroup

**Best practices — Verification**

- 500 entries scroll without jank (paged from the bridge, 50 at a time)
- 'Not inserted' shows entries that fell back to clipboard

**Best practices — Non-goals**

- Editing a transcript; history is a record, not a notes app

**Gestures (2)**

| Selector | Event | Behaviour | Haptic |
| --- | --- | --- | --- |
| `DSDismissibleTile` | `swipe` | deletes the entry, with Undo in a snack bar | mediumImpact |
| `DSListTile` | `longPress` | copies the transcript to the clipboard | selectionClick |

**Journeys (2)**

- **Re-use an old dictation** ✓ happy path
  - `/history → search 'address' → long-press row → Copied`
- **Delete by mistake**
  - `/history → swipe → Undo`

**APIs required**

- **Entities:** HistoryEntry

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| CHANNEL | `parley/bridge#listHistory` | no | paged, filtered, searched list of entries |
| CHANNEL | `parley/bridge#deleteHistory` | no | delete one entry, or all when called from Settings |

- **Providers:** historyListProvider

| From | To | Note |
| --- | --- | --- |
| `home shell` | `/history` | second tab |
| `row tap` | `/history/:id` | push |

**Blast radius**

```
new (2)
  ├── lib/screens/history/history_page.dart
  └── test/screens/history_page_test.dart

changed (1)
  └── lib/screens/home_screen.dart
```

**Sprint**

- order `6`, size `M`, depends on overview

Verification gate:
- `flutter analyze --no-fatal-infos`
- `flutter test test/screens/history_page_test.dart`
- `make ui-probe`

### Transcript · `/history/:id`

Archetype: `detail` — Read one entry in full and copy it

**Phone @390**

```
┌────────────────────────────────────┐
│ 9:41                     ▮▮▮  ▮▮   │
├────────────────────────────────────┤
│ ‹                                  │
├────────────────────────────────────┤
│ Transcript                         │
│                                    │
│ ┌────────────────────────────────┐ │
│ │ Transcript                     │ │
│ │ ────────────────────────────── │ │
│ │ Running ten minutes late, sta… │ │
│ └────────────────────────────────┘ │
│                                    │
│ ┌────────────────────────────────┐ │
│ │ Details                        │ │
│ │ ────────────────────────────── │ │
│ │ App             WhatsApp       │ │
│ │ Mode           Dictation       │ │
│ │ Inserted        Set text       │ │
│ │ Length    0:06 · 8 words       │ │
│ │ Saved              8 sec       │ │
│ └────────────────────────────────┘ │
├────────────────────────────────────┤
│ [ ● ] [           Copy           ] │
│            ────────────            │
└────────────────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ Entry was deleted:   │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ 'This transcript no  │   │ Could not read the   │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ longer exists' and   │   │ entry: error state   │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ Back.                │   │ with Retry.          │
│                      │   │                      │   │                      │
│                      │   │ [ Copy ]             │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 skeleton mirrors rows     one action, 3 lines max    retry, never a raw error
```

Success: Full transcript and details; Copy pinned.

**Look & feel**

- **Header:** DSCompactAppBar with the date as title and Delete in the overflow
- **Motion:** None beyond the platform push
- **Dark mode:** Transcript on surface, details in the muted ladder

**Layout (region → kit)**

| Region | Kit | Purpose |
| --- | --- | --- |
| `header` | `DSCompactAppBar` | — |
| `body.scroll` | `DSText`, `DSSettingsSection` | — |
| `footer` | `DSPinnedActionBar` | — |

scroll `scrollable_header_pinned_footer` · pinned: `header`, `footer` · safe area ✓ top · safe area ✓ bottom

**Components (1)**

| Kit | Region | Purpose | Why | Not |
| --- | --- | --- | --- | --- |
| `DSPinnedActionBar` _(chrome)_ | `footer` | Copy primary | A long transcript scrolls; Copy must not scroll away with it | `a copy icon in the app bar, which is easy to miss` |

**Best practices — Accessibility**

- Transcript text is selectable and read as one block

**Best practices — Design-system rules**

- Copy is the pinned primary; Delete lives in the overflow menu

**Best practices — Verification**

- Edit entries show the instruction, the before text and the after text as three sections

**Best practices — Non-goals**

- Re-inserting into another app from here; copy covers it

**Gestures (1)**

| Selector | Event | Behaviour | Haptic |
| --- | --- | --- | --- |
| `Copy (DSPinnedActionBar)` | `tap` | copies the transcript (for edits, the after text) | selectionClick |

**Journeys (1)**

- **Copy an old message** ✓ happy path
  - `/history → row → /history/:id → Copy`

**APIs required**

- **Entities:** HistoryEntry

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| CHANNEL | `parley/bridge#getHistoryEntry` | no | one entry with its metadata |

- **Providers:** historyEntryProvider

| From | To | Note |
| --- | --- | --- |
| `history row / overview last tile` | `/history/:id` | push |

**Blast radius**

```
new (2)
  ├── lib/screens/history/history_detail_page.dart
  └── test/screens/history_detail_page_test.dart

changed (1)
  └── lib/utils/app_router.dart
```

**Sprint**

- order `7`, size `S`, depends on history

Verification gate:
- `flutter analyze --no-fatal-infos`
- `flutter test test/screens/history_detail_page_test.dart`

### Settings · `/settings`

Archetype: `settings` — Change how the orb and the gesture behave, manage keys and history

**Phone @390**

```
┌────────────────────────────────────┐
│ 9:41                     ▮▮▮  ▮▮   │
├────────────────────────────────────┤
│   Settings                         │
├────────────────────────────────────┤
│ TRIGGERS                           │
│ ┌────────────────────────────────┐ │
│ │ Floating orb                 … │ │
│ │ Volume-down tap-tap-hold     … │ │
│ │ Orb size                     … │ │
│ │ Hide orb when no text field i… │ │
│ └────────────────────────────────┘ │
│                                    │
│ DICTATION                          │
│ ┌────────────────────────────────┐ │
│ │ Language                     … │ │
│ │ Add a space before inserted t… │ │
│ │ Haptic on start and stop     … │ │
│ └────────────────────────────────┘ │
│                                    │
│ ACCOUNT KEYS                       │
│ ┌────────────────────────────────┐ │
│ │ API keys  Groq ✓ · MiniMax ✓ › │ │
│ └────────────────────────────────┘ │
│                                    │
│ HISTORY                            │
│ ┌────────────────────────────────┐ │
│ │ Keep history for  30 days ›    │ │
│ │ Clear history             ›    │ │
│ └────────────────────────────────┘ │
│                                    │
│ SYSTEM                             │
│ ┌────────────────────────────────┐ │
│ │ Accessibility service        … │ │
│ │ Battery                Unrest… │ │
│ │ Run setup again              … │ │
│ └────────────────────────────────┘ │
├────────────────────────────────────┤
│ ○ Overview  ○ History  ● Settings  │
│            ────────────            │
└────────────────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ Defaults shown;      │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ there is always a    │   │ Could not read       │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ config.              │   │ settings: error      │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │                      │   │ state with Retry.    │
│                      │   │                      │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 skeleton mirrors rows     one action, 3 lines max    retry, never a raw error
```

Success: Sections rendered with current values.

**Look & feel**

- **Header:** DSLargeAppBar titled Settings
- **Motion:** None
- **Dark mode:** Grouped inset sections on the surface ladder

**Layout (region → kit)**

| Region | Kit | Purpose |
| --- | --- | --- |
| `header` | `DSLargeAppBar` | — |
| `body.section` | `DSSettingsSection`, `DSSwitchTile`, `DSSettingsRow` | — |

scroll `scrollable` · pinned: `header` · safe area ✓ top · safe area ✓ bottom

**Components (2)**

| Kit | Region | Purpose | Why | Not |
| --- | --- | --- | --- | --- |
| `DSSettingsSection` _(grouping)_ | `body.section` | Grouped settings with eyebrows | Five small groups read as a native Android settings screen and match the archetype | `tabs inside Settings, which hide groups from a scroll` |
| `DSSwitchTile` _(row)_ | `body.section` | On/off settings | Makes the whole row the tap target for a binary setting | `DSCheckboxTile, which reads as selection, not a live toggle` |

**Best practices — Accessibility**

- Every switch row is a DSSwitchTile so the label is the tap target

**Best practices — Design-system rules**

- Grouped DSSettingsSection with eyebrows; no custom rows

**Best practices — Verification**

- Turning the volume gesture off takes effect in the service without reopening the app
- Clear history asks for confirmation in a DSDialog

**Best practices — Non-goals**

- Theme picker; the app follows the system

**Gestures (1)**

| Selector | Event | Behaviour | Haptic |
| --- | --- | --- | --- |
| `DSSwitchTile` | `tap` | toggles the setting and sends setConfig | selectionClick |

**Journeys (1)**

- **Turn off the volume gesture** ✓ happy path
  - `/settings → Volume-down tap-tap-hold off → volume keys behave normally`

**APIs required**

- **Entities:** Config

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| CHANNEL | `parley/bridge#getConfig` | no | current settings, with keys masked |
| CHANNEL | `parley/bridge#setConfig` | no | change one setting; the service applies it live |

- **Providers:** configProvider

| From | To | Note |
| --- | --- | --- |
| `home shell` | `/settings` | third tab |
| `API keys row` | `/settings/keys` | push |
| `Run setup again` | `/setup` | replace |

**Blast radius**

```
new (2)
  ├── lib/screens/settings/parley_settings_page.dart
  └── test/screens/parley_settings_page_test.dart

changed (1)
  └── lib/screens/home_screen.dart
```

**Sprint**

- order `8`, size `M`, depends on overview

Verification gate:
- `flutter analyze --no-fatal-infos`
- `flutter test test/screens/parley_settings_page_test.dart`
- `make ui-probe`

### API keys · `/settings/keys`

Archetype: `form` — Replace or remove the Groq and MiniMax keys

**Phone @390**

```
┌────────────────────────────────────┐
│ 9:41                     ▮▮▮  ▮▮   │
├────────────────────────────────────┤
│ ‹ API keys                         │
├────────────────────────────────────┤
│ Groq API key                       │
│ [ gsk_…                          ] │
│ Used for transcription (whisper-l… │
│                                    │
│ MiniMax API key                    │
│ [ Paste key                      ] │
│ Used for voice edit only. Leave e… │
│                                    │
│                                    │
│                                    │
│                                    │
│                                    │
│                                    │
│                                    │
│                                    │
│                                    │
├────────────────────────────────────┤
│ [         Check and save         ] │
│            ────────────            │
└────────────────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ No keys: both fields │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ empty, Groq marked   │   │ Verification failed: │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │ required.            │   │ the provider's       │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓      │   │                      │   │ message under the    │
│                      │   │ [ Check and save ]   │   │ field; nothing       │
│                      │   │                      │   │ saved.               │
│                      │   │                      │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 skeleton mirrors rows     one action, 3 lines max    retry, never a raw error
```

Success: Saved; pops back to Settings with a 'Keys saved' snack bar.

**Look & feel**

- **Header:** DSCompactAppBar titled API keys
- **Motion:** None
- **Dark mode:** Default

**Layout (region → kit)**

| Region | Kit | Purpose |
| --- | --- | --- |
| `header` | `DSCompactAppBar` | — |
| `body.form` | `DSTextField` | — |
| `footer` | `DSPinnedActionBar` | — |

scroll `scrollable_header_pinned_footer` · pinned: `header`, `footer` · safe area ✓ top · safe area ✓ bottom

**Components (2)**

| Kit | Region | Purpose | Why | Not |
| --- | --- | --- | --- | --- |
| `DSTextField` _(input)_ | `body.form` | Key inputs | Obscured single-line inputs with helper and error slots under each | `a dialog per key, which hides the other key's state` |
| `DSPinnedActionBar` _(chrome)_ | `footer` | Check and save | The keyboard covers the lower half; the pinned bar stays above it | `an app-bar Save action, which does not show verification progress` |

**Best practices — Accessibility**

- Fields are obscured with a show/hide toggle that announces its state

**Best practices — Design-system rules**

- Errors from verifyKey render under the field that failed

**Best practices — Verification**

- A wrong key is refused and the old key stays in place
- Keys never appear in logs or in the Flutter side after save; getConfig returns only the last four characters

**Best practices — Non-goals**

- Choosing models; the models are fixed in v1

**Gestures (1)**

| Selector | Event | Behaviour | Haptic |
| --- | --- | --- | --- |
| `Check and save (DSPinnedActionBar)` | `tap` | verifies each non-empty key, then saves | selectionClick |

**Journeys (1)**

- **Rotate the Groq key** ✓ happy path
  - `/settings → API keys → paste → Check and save → /settings`

**APIs required**

- **Entities:** Config

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| CHANNEL | `parley/bridge#setKeys` | no | verify then store keys in EncryptedSharedPreferences |

- **Providers:** configProvider

| From | To | Note |
| --- | --- | --- |
| `/settings API keys row` | `/settings/keys` | push; pops on save |

**Blast radius**

```
new (2)
  ├── lib/screens/settings/api_keys_page.dart
  └── test/screens/api_keys_page_test.dart

changed (1)
  └── lib/utils/app_router.dart
```

**Sprint**

- order `9`, size `S`, depends on settings

Verification gate:
- `flutter analyze --no-fatal-infos`
- `flutter test test/screens/api_keys_page_test.dart`

## Shared entities

- **ServiceStatus** — serviceBound, paused, micGranted, batteryUnrestricted, groqKeySet, minimaxKeySet, orbVisible, volumeGestureArmed
- **Config** — orbEnabled, orbSize, hideOrbWithoutField, volumeGestureEnabled, language, leadingSpace, haptics, historyRetentionDays, groqKeyLast4, minimaxKeyLast4
- **HistoryEntry** — id, createdAt, mode (dictation|edit), text, instruction?, beforeText?, appPackage, appLabel, insertMethod (setText|paste|clipboardOnly|failed), recordingMs, wordCount, savedMs
- **UsageSummary** — weekWords, weekSavedMs, lastEntry (HistoryEntry?)

## Shared providers

- parleyBridgeProvider — MethodChannel `parley/bridge` in the app, FakeParleyBridge in tests and when run on a desktop/emulator without the service
- serviceStatusProvider — StreamProvider over the `parley/events` EventChannel, seeded by getStatus
- configProvider — AsyncNotifier over getConfig/setConfig

## Shared mocks

- FakeParleyBridge — in-memory ServiceStatus, Config and 40 seeded HistoryEntry rows; replaces the boilerplate's Dio mock adapter as the offline seam

## Open questions

- Android 14+ restricts starting a microphone foreground service from the background. Does a bound accessibility service with a visible accessibility overlay qualify for the while-in-use exemption on the author's phone? Spike parley-a01 answers this before anything else is built.
- Consuming volume-down to detect tap-tap-hold means single presses must be replayed as volume changes after the gesture window (~350 ms). Is that lag acceptable, or should the gesture be volume-down + volume-up chord instead?
- Which apps reject ACTION_SET_TEXT? Chrome and WebView fields are expected to need the paste fallback; the spike logs the insert method per app.

## Sprint order

| # | Route | Size | Depends on |
| --- | --- | --- | --- |
| 3 | `setup` | `M` | — |
| 4 | `overview` | `S` | setup |
| 6 | `history` | `M` | overview |
| 7 | `history-detail` | `S` | history |
| 8 | `settings` | `M` | overview |
| 9 | `api-keys` | `S` | settings |

## DS component inventory

10 distinct kit components across 6 routes. Sorted by reuse count descending; a kit used by 3+ routes is the visual vocabulary of the app, a kit used by exactly one deserves a second look.

| Kit | Used by | Uses |
| --- | --- | --- |
| `DSPinnedActionBar` _(chrome)_ | `api-keys`, `history-detail`, `setup` | 3 |
| `DSChipGroup` _(tag)_ | `history` | 1 |
| `DSDismissibleTile` _(row)_ | `history` | 1 |
| `DSLargeAppBar` _(chrome)_ | `overview` | 1 |
| `DSSearchBar` _(chrome)_ | `history` | 1 |
| `DSSegmentedProgress` _(feedback)_ | `setup` | 1 |
| `DSSettingsSection` _(grouping)_ | `settings` | 1 |
| `DSStatTile` _(row)_ | `overview` | 1 |
| `DSSwitchTile` _(row)_ | `settings` | 1 |
| `DSTextField` _(input)_ | `api-keys` | 1 |

---

Approve this before any file under `lib/` is written. Every frame
above is drawn from this superplan's JSON, so the picture and the
build cannot drift; the archetypes are the twelve in
`docs/principles/screen-archetypes.md`, which every demo screen names
and `test/screens/archetypes_test.dart` holds them to.
