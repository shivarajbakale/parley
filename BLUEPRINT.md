# App Blueprint

The at-a-glance version. The full plan is [SUPERPLAN.md](SUPERPLAN.md) (screens)
and [docs/plans/native-core.md](docs/plans/native-core.md) (the orb and the
dictation pipeline). The bridge between the two is
[docs/plans/bridge-contract.md](docs/plans/bridge-contract.md).

**One-liner:** Floating-orb voice dictation and voice edit for any Android text field.

**Status:**
- [x] drafted
- [x] approved (2026-09-24, "go ahead with the end-to-end implementation")

**Last updated:** 2026-09-24

## Screens

| # | Screen | Mount | Layout | Purpose |
|---|--------|-------|--------|---------|
| 1 | Setup | full-screen, first run | sequence | keys, mic, accessibility, battery, practice |
| 2 | Overview | tab-0 | focal | is Parley ready, words and time saved |
| 3 | History | tab-1 | collection | find and copy past dictations |
| 4 | Transcript | pushed from 3 | detail | one entry in full |
| 5 | Settings | tab-2 | settings | triggers, dictation, keys, history, system |
| 6 | API keys | pushed from 5 | form | verify and store Groq / MiniMax keys |

Outside Flutter: the orb overlay and the accessibility service (Kotlin).

## Navigation map

```
/setup (until every grant and the Groq key are in place)
HomeShell
├── Overview    /
├── History     /history ─push→ /history/:id
└── Settings    /settings ─push→ /settings/keys
```

## Modules

| Module     | Enable? | Go-live backend (or "mock for now") |
|------------|---------|-------------------------------------|
| Onboarding | [x]     | replaced by the Setup sequence      |
| Auth       | [ ]     | none — personal use, keys on device |
| Paywall    | [ ]     | none                                |
| Analytics  | [ ]     | none                                |
| Crash      | [ ]     | console default                     |

## Data model

- **HistoryEntry:** id, createdAt, mode, text, instruction, beforeText, appPackage, appLabel, insertMethod, recordingMs, wordCount, savedMs
- **ParleyStatus:** serviceBound, paused, micGranted, batteryUnrestricted, groqKeySet, minimaxKeySet, orbEnabled, volumeGestureEnabled
- **ParleyConfig:** orbEnabled, orbSize, hideOrbWithoutField, volumeGestureEnabled, language, leadingSpace, haptics, historyRetentionDays, groqKeyLast4, minimaxKeyLast4
- **UsageSummary:** weekWords, weekSavedMs, lastEntry

## Providers

- `parleyBridgeProvider` — the platform channel, or `FakeParleyBridge` off-device and in tests
- `parleyStatusProvider` — live status from the event channel
- `parleyConfigProvider`, `usageSummaryProvider`, `historyProvider`

## Backend

None. Groq and MiniMax are called from the Kotlin service with the user's own keys.

## Open questions

See `openQuestions` in [SUPERPLAN.json](SUPERPLAN.json).

---

## Feature decomposition

Registered in [feature_list.json](feature_list.json): `parley-a01`..`parley-a05`
for the native core and identity, one entry per route (`route:<id>` in notes).
