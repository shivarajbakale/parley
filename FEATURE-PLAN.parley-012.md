<!-- feature-plan:v1 — generated, do not hand-edit.
     Regenerate with: node scripts/feature-plan.mjs parley-012.feature-plan.json -->

# Deepgram Nova-3 as a transcription provider

`parley-012` · 1 surface

## Problem

Parley can only transcribe through Groq's Whisper. Someone who already pays for Deepgram, or who wants Nova-3's keyterm prompting for jargon-heavy dictation, has no way to use it. This feature adds Deepgram Nova-3 as a second speech-to-text provider next to Groq. The Overview's Transcription row gains a provider choice (Whisper (Groq) / Deepgram Nova-3) and a key form for whichever is selected. Groq stays the default, so existing users see no change. Readiness and the gesture block mean “the selected provider has a key”. Deepgram gets the dictionary words as keyterms, not Whisper's prose prompt. Frame note: the settings window is not PageShell, so the archetype below is illustrative and not probe-enforced, as in parley-007 to parley-010.

## Not in this feature

- A provider choice in the first-run flow — it stays Groq-only; Deepgram is chosen on the Overview.
- Streaming (websocket) transcription — the orb still sends one recording after release.
- Languages other than English, or a model picker beyond Nova-3.
- Falling back to the other provider when one fails.

## Surfaces

### Overview tab · Transcription row · `settings.html · settings · Overview`

Archetype: `list-detail` — Pick which service turns speech into text, and store that service's key, without leaving the Status group.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│ ▨ Parley      ⌕ Search…                                     ⌘K   ◐   ⬤     │
├───────────────┬────────────────────────────────────────────────────────────┤
│ Overview      │ Overview tab · Transcription row         [ Test and save ] │
│ Gesture       │                                                            │
│ General       │ ┌──────────────────┐ ┌───────────────────────────────────┐ │
│ Overview tab …│ │ Parley           │ │ Parley is ready                   │ │
│               │ │ ──────────────── │ │ ◉ orb · Tap Right Option 2× and h…│ │
│               │ │ ▣ Overview       │ │ ───────────────────────────────── │ │
│               │ │ □ Gesture        │ │ STATUS                          … │ │
│               │ │ □ General        │ │ Microphone ............ ✓ Grante… │ │
│               │ └──────────────────┘ │ Accessibility ......... ✓ Grante… │ │
│               │                      │ Transcription ......... ✓ Stored… │ │
│               │                      │   [ Whisper (Groq) | Deepgram No… │ │
│               │                      │   Deepgram API key [••••••••]  T… │ │
│               │                      │ MiniMax key ........... Not set … │ │
│               │                      │ ───────────────────────────────── │ │
│               │                      │ [Test and save]  [Replace]        │ │
│               │                      └───────────────────────────────────┘ │
└───────────────┴────────────────────────────────────────────────────────────┘
```

**Mobile @390** — design intent; the probe measures 1280 / 1440 / 1920 only.

```
┌──────────────────────────┐         ┌──────────────────────────┐
│ ☰  Overview tab · Tr…⌕   │         │ ‹ Back  Parley is ready  │
├──────────────────────────┤         ├──────────────────────────┤
│ ┌──────────────────────┐ │    ──▶  │ ┌──────────────────────┐ │
│ │ ▣ Overview           │ │         │ │ Parley is ready      │ │
│ │ □ Gesture            │ │         │ │ ◉ orb · Tap Right Op…│ │
│ │ □ General            │ │         │ │ ──────────────────── │ │
│ └──────────────────────┘ │         │ │ STATUS             … │ │
│    [ Test and save ]     │         │ │ Microphone ........… │ │
└──────────────────────────┘         │ │ Accessibility .....… │ │
                                     │ │ Transcription .....… │ │
                                     │ │   [ Whisper (Groq) … │ │
                                     │ │   Deepgram API key … │ │
                                     │ │ MiniMax key .......… │ │
                                     │ │ ──────────────────── │ │
                                     │ │ [Test and save]  [R… │ │
                                     │ └──────────────────────┘ │
                                     └──────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ The selected         │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ provider has no key: │   │ A rejected key shows │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ the row badge reads  │   │ the provider's       │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ Missing, the title   │   │ message (“Invalid    │
│                      │   │ reads Finish setup,  │   │ API key”) beside the │
│                      │   │ and that provider's  │   │ button. A failed     │
│                      │   │ key form opens.      │   │ switch shows a red   │
│                      │   │                      │   │ Alert under the row. │
│                      │   │ [ Test and save ]    │   │ A failed dictation   │
│                      │   │                      │   │ names the provider   │
│                      │   │                      │   │ on the pill          │
│                      │   │                      │   │ (“Deepgram error”).  │
│                      │   │                      │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: Saving a key closes the form and the badge flips to Stored. Switching to a provider that already has a key keeps Parley ready at once.

Held to:

- B1 — two or more top-level panels sharing a top edge
- B2 — no panel scrolls; PageShell owns the single scroll region

## Components

Each choice states the neighbour it beat. `Use when:` / `Instead:` for every
component family lives in `.claude/skills/use-mantine/mantine-capabilities.md`;
the choices between families live in
`docs/principles/component-selection.md`.

| Surface | Control | Why this one | Not |
| --- | --- | --- | --- |
| overview | `SegmentedControl (Whisper (Groq) / Deepgram Nova-3) inside the Transcription row's Collapse, above the key form` | Two mutually exclusive options that are both visible at once, and the choice applies immediately. That is what SegmentedControl is for. | `Select (hides the second option behind a click), Radio group (heavier, and reads as a form to submit)` |
| overview | `The existing ApiKeySection, relabelled per provider (Groq API key / Deepgram API key)` | The same test-then-save form and messages the Groq key already uses. Only the label, placeholder and mutation change. | `Two always-visible key forms (one of them is irrelevant to the selected provider)` |

## Data model

- **Settings**
  - `transcriptionProvider`: 'groq' | 'deepgram' — default 'groq'; set only through settings:setTranscriptionProvider, never through an update patch
  - `deepgramKeyEncrypted`: string — safeStorage-encrypted, in the settings.json envelope next to apiKeyEncrypted
  - _relations:_ SettingsView.hasApiKey = the selected provider has a key; hasGroqKey and hasDeepgramKey are exposed as well

## API endpoints

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| IPC invoke | `settings:setDeepgramKey` | no | undefined |
| IPC invoke | `settings:setTranscriptionProvider` | no | undefined |
| POST | `https://api.deepgram.com/v1/listen?model=nova-3&language=en&smart_format=true&keyterm=…` | no | undefined |

## Integration points

```
  electron/transcriber.ts                        ──▶  electron/transcribers/groq.ts and electron/transcribers/deepgram.ts   (createTranscriber keeps its interface and picks a provider through getProvider())
  electron/session.ts                            ──▶  transcribe options gain terms[] next to the Whisper prompt   (Groq keeps the prompt exactly as today; Deepgram uses the raw terms)
  src/settings/OverviewTab.tsx                   ──▶  Transcription row: provider SegmentedControl + key form for the selected provider   (the wizard keeps its Groq-only key step)
  src/settings/GeneralTab.tsx + SettingsApp.tsx  ──▶  copy names the selected provider   (vocabulary description and the blocked-gesture notice)
```

## Blast radius

```
new (5)
  ├── electron/transcribers/shared.ts
  ├── electron/transcribers/groq.ts
  ├── electron/transcribers/deepgram.ts
  ├── electron/__tests__/deepgram.test.ts
  └── src/settings/providers.ts

changed (23)
  ├── electron/transcriber.ts
  ├── electron/types.ts
  ├── electron/settings-store.ts
  ├── electron/session.ts
  ├── electron/dictionary.ts
  ├── electron/main.ts
  ├── electron/preload.ts
  ├── electron/__tests__/settings-store.test.ts
  ├── electron/__tests__/session.test.ts
  ├── electron/__tests__/dictionary.test.ts
  ├── src/settings/use-parley.ts
  ├── src/settings/OverviewTab.tsx
  ├── src/settings/GeneralTab.tsx
  ├── src/settings/SettingsApp.tsx
  ├── src/settings/SettingsShell.stories.tsx
  ├── src/settings/Wizard.stories.tsx
  ├── src/settings/__tests__/SettingsApp.test.tsx
  ├── src/settings/__tests__/SettingsShell.test.tsx
  ├── src/settings/__tests__/MiniMaxOffer.test.tsx
  ├── src/settings/__tests__/onboarding.test.tsx
  ├── ARCHITECTURE.md
  ├── docs/MANUAL_CHECKLIST.md
  └── feature_list.json
```

## Verification plan

- [ ] `make check`
- [ ] `npm run test -- electron/__tests__/deepgram.test.ts electron/__tests__/transcriber.test.ts electron/__tests__/settings-store.test.ts`
- [ ] `Storybook: SettingsShell DeepgramNeedsKey (provider choice and Deepgram key form open), in dark and light`
- [ ] `Manual: make dev — choose Deepgram Nova-3, save a real Deepgram key, dictate a sentence with a dictionary word, and see it pasted`
- [ ] `ux-prepass` — all seven boxes, `npm run ui-lint` green is the evidence for item 7

---

Approve this before any file is written. Every diagram above is rendered
from this feature's plan JSON, so the drawing and the build cannot drift;
the archetype frames are the same shapes `ui-probe` rules B1-B4 assert
against the real DOM once the screens exist.
