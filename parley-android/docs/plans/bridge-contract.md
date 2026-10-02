# Bridge contract — Flutter ⇄ native

The only surface between the Flutter screens (`lib/`) and the Kotlin core
(`android/app/src/main/kotlin/com/shivarajbakale/parley/`). Both sides are
written against this file; a change here changes both in the same commit.

- MethodChannel **`parley/bridge`**. Arguments and results are plain maps,
  lists, strings, ints, bools, or null. Times are epoch milliseconds (int).
- EventChannel **`parley/events`**. Each event is a map with a `type`.
- Errors: a method that fails throws `PlatformException(code, message)` with
  code `unavailable`, `invalid_argument` or `io`. Key verification failures
  are **not** exceptions; they come back as results.

## Shapes

`Status`

| key | type | meaning |
| --- | --- | --- |
| `serviceBound` | bool | the accessibility service is enabled and connected |
| `paused` | bool | orb hidden and gesture disarmed by the user |
| `micGranted` | bool | RECORD_AUDIO granted |
| `batteryUnrestricted` | bool | `isIgnoringBatteryOptimizations` |
| `groqKeySet` | bool | |
| `minimaxKeySet` | bool | |
| `orbEnabled` | bool | config value |
| `volumeGestureEnabled` | bool | config value |
| `deepgramKeySet` | bool | |
| `transcriptionProvider` | `groq`\|`deepgram` | config value |
| `transcriptionKeySet` | bool | the chosen provider has a key; what "ready" reads |

`Config`

| key | type | default |
| --- | --- | --- |
| `orbEnabled` | bool | true |
| `orbSize` | string `small`\|`medium`\|`large` | `medium` |
| `hideOrbWithoutField` | bool | true |
| `volumeGestureEnabled` | bool | true |
| `language` | string, ISO-639-1 or `auto` | `auto` |
| `leadingSpace` | bool | true |
| `haptics` | bool | true |
| `historyRetentionDays` | int (7, 30, 90, 0 = forever) | 30 |
| `groqKeyLast4` | string or null | null |
| `minimaxKeyLast4` | string or null | null |
| `transcriptionProvider` | string `groq`\|`deepgram` | `groq` |
| `deepgramKeyLast4` | string or null | null |

`HistoryEntry`

| key | type |
| --- | --- |
| `id` | int |
| `createdAt` | int (ms) |
| `mode` | `dictation`\|`edit` |
| `text` | string — the dictated text, or for an edit the text after |
| `instruction` | string or null — edit only |
| `beforeText` | string or null — edit only |
| `appPackage` | string |
| `appLabel` | string |
| `insertMethod` | `setText`\|`paste`\|`clipboardOnly`\|`failed` |
| `recordingMs` | int |
| `wordCount` | int |
| `savedMs` | int — `max(0, wordCount / 35 * 60000 − recordingMs)` |

`UsageSummary`: `{weekWords:int, weekSavedMs:int, lastEntry: HistoryEntry|null}`
(week = the last 7 days).

## Methods (`parley/bridge`)

| method | args | result |
| --- | --- | --- |
| `getStatus` | — | Status |
| `setPaused` | `{paused: bool}` | Status |
| `openSystemSettings` | `{target: 'accessibility'\|'battery'\|'appDetails'}` | null |
| `requestMicPermission` | — | bool (granted) |
| `verifyKey` | `{provider: 'groq'\|'deepgram'\|'minimax', key: string}` | `{ok: bool, message: string\|null}` |
| `setKeys` | `{groq?: string, deepgram?: string, minimax?: string}` (`''` removes that key) | `{ok: bool, errors: {groq?: string, deepgram?: string, minimax?: string}}` — verifies every non-empty key first; saves none if any fails |
| `getConfig` | — | Config |
| `setConfig` | `{key: string, value: any}` | Config — `transcriptionProvider` (`groq`\|`deepgram`) is how the Dart `setTranscriptionProvider` chooses who transcribes |
| `getUsageSummary` | — | UsageSummary |
| `listHistory` | `{offset: int, limit: int, query: string\|null, filter: 'all'\|'dictation'\|'edit'\|'notInserted'}` | List\<HistoryEntry\>, newest first |
| `getHistoryEntry` | `{id: int}` | HistoryEntry or null |
| `deleteHistory` | `{id: int\|null}` (null = all) | int (rows deleted) |
| `restoreHistory` | `{entry: HistoryEntry}` | int (id) — undo of a delete |

## Events (`parley/events`)

- `{type: 'status', status: Status}` — whenever any Status field changes.
- `{type: 'history', entry: HistoryEntry}` — after each entry is written.
