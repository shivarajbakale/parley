<!-- feature-plan:v1 — generated, do not hand-edit.
     Regenerate with: node scripts/feature-plan.mjs parley-010.feature-plan.json -->

# Revamp phase 3: Overview with status and time saved, native grouped settings

`parley-010` · 3 surfaces

## Problem

After first run, the settings window still reads like a form dump. The Setup tab stacks a permission card and two API key forms, even when everything is already set, so the one question people open the window with, “is Parley working?”, has no direct answer. The Gesture and General tabs are loose glass cards with ad-hoc spacing and no group labels, unlike System Settings. Nothing shows what Parley has done for the user, so it gives no reason to come back. Phase 3 replaces the Setup tab with an Overview. At the top, the live orb and a status line say “Parley is ready” or “Finish setup”. Below that, a time-saved stat is counted from dictated words in the main process. Then a Status group has one row each for microphone, accessibility, transcription key and MiniMax key, and each row has its own one-click fix. Key forms open inline only when asked. Gesture and General become labelled, grouped lists with hairline dividers and 44 px rows. Frame note: the settings window is not PageShell, so the archetypes below are illustrative and not probe-enforced, as in parley-007 to parley-009.

## Not in this feature

- A menu bar popover with recent dictations — a later idea, not this phase.
- Per-day or per-week charts: one running total is enough to make the point.
- Counting voice edit or Explain toward time saved — only pasted dictation replaces typing.
- Syncing the count across Macs or resetting it from the UI.
- A Dictionary tab — parley-006 owns that.

## Surfaces

### Overview tab (replaces Setup) · `settings.html · settings · Overview`

Archetype: `list-detail` — Answers “is it working?” at a glance, fixes whatever is not in one click, and shows what Parley has saved you.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│ ▨ Parley      ⌕ Search…                                     ⌘K   ◐   ⬤     │
├───────────────┬────────────────────────────────────────────────────────────┤
│ Overview      │ Overview tab (replaces Setup)       [ Grant / Add (whiche… │
│ Gesture       │                                                            │
│ General       │ ┌──────────────────┐ ┌───────────────────────────────────┐ │
│ Overview tab …│ │ Parley           │ │ Parley is ready                   │ │
│               │ │ ──────────────── │ │ ◉ orb · Tap Right Option 2× and h…│ │
│               │ │ ▣ Overview       │ │ ───────────────────────────────── │ │
│               │ │ □ Gesture        │ │ USAGE                           … │ │
│               │ │ □ General        │ │ ≈ 26 min saved · 1,340 words dic… │ │
│               │ └──────────────────┘ │ STATUS                          … │ │
│               │                      │ Microphone ............ ✓ Grante… │ │
│               │                      │ Accessibility ......... ✓ Grante… │ │
│               │                      │ Transcription key ..... ✓ Stored… │ │
│               │                      │ MiniMax key ........... Not set … │ │
│               │                      │ ───────────────────────────────── │ │
│               │                      │ [Replace]  [Add]                  │ │
│               │                      └───────────────────────────────────┘ │
└───────────────┴────────────────────────────────────────────────────────────┘
```

**Mobile @390** — design intent; the probe measures 1280 / 1440 / 1920 only.

```
┌──────────────────────────┐         ┌──────────────────────────┐
│ ☰  Overview tab (rep…⌕   │         │ ‹ Back  Parley is ready  │
├──────────────────────────┤         ├──────────────────────────┤
│ ┌──────────────────────┐ │    ──▶  │ ┌──────────────────────┐ │
│ │ ▣ Overview           │ │         │ │ Parley is ready      │ │
│ │ □ Gesture            │ │         │ │ ◉ orb · Tap Right Op…│ │
│ │ □ General            │ │         │ │ ──────────────────── │ │
│ └──────────────────────┘ │         │ │ USAGE              … │ │
│[ Grant / Add (whichever …│         │ │ ≈ 26 min saved · 1,… │ │
└──────────────────────────┘         │ │ STATUS             … │ │
                                     │ │ Microphone ........… │ │
                                     │ │ Accessibility .....… │ │
                                     │ │ Transcription key .… │ │
                                     │ │ MiniMax key .......… │ │
                                     │ │ ──────────────────── │ │
                                     │ │ [Replace]  [Add]     │ │
                                     │ └──────────────────────┘ │
                                     └──────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ No words yet: the    │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ Usage row reads      │   │ A missing permission │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ “Your first          │   │ or key turns the     │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ dictation starts the │   │ title into “Finish   │
│                      │   │ count.” in place of  │   │ setup”, names how    │
│                      │   │ a zero.              │   │ many things need     │
│                      │   │                      │   │ you, and gives that  │
│                      │   │ [ Grant / Add (which…│   │ row a Grant or Add   │
│                      │   │                      │   │ button. A failed     │
│                      │   │                      │   │ permission request   │
│                      │   │                      │   │ shows the existing   │
│                      │   │                      │   │ red Alert under its  │
│                      │   │                      │   │ row.                 │
│                      │   │                      │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: Every row is green and the title reads “Parley is ready”. Saving a key closes its inline form, and the row flips to Stored.

Held to:

- B1 — two or more top-level panels sharing a top edge
- B2 — no panel scrolls; PageShell owns the single scroll region

### Gesture tab · `settings.html · settings · Gesture`

Archetype: `form` — The same controls, grouped under Keys and Timing with native row rhythm.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│ ▨ Parley      ⌕ Search…                                     ⌘K   ◐   ⬤     │
├───────────────┬────────────────────────────────────────────────────────────┤
│ Overview      │ Gesture tab                               [ Select a key ] │
│ Gesture       │                                                            │
│ General       │        ┌──────────────────────────────────────────┐        │
│ Gesture tab ◀…│        │ Gesture                                  │        │
│               │        │ ──────────────────────────────────────── │        │
│               │        │ KEYS                                     │        │
│               │        │ Dictate ............ [Right Option ▾]    │        │
│               │        │ Voice edit ......... [Right Command ▾]   │        │
│               │        │ Explain ............ [Right Control ▾]   │        │
│               │        │ TIMING                                   │        │
│               │        │ Presses ............ [2 | 3 | 4]         │        │
│               │        └──────────────────────────────────────────┘        │
└───────────────┴────────────────────────────────────────────────────────────┘
```

**Mobile @390** — design intent; the probe measures 1280 / 1440 / 1920 only.

```
┌──────────────────────────┐
│ ☰  Gesture tab       ⌕   │
├──────────────────────────┤
│ ┌──────────────────────┐ │
│ │ KEYS               … │ │
│ │ Dictate ...........… │ │
│ │ Voice edit ........… │ │
│ │ Explain ...........… │ │
│ │ TIMING             … │ │
│ │ Presses ...........… │ │
│ └──────────────────────┘ │
│     [ Select a key ]     │
└──────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ No empty state:      │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ every key has a      │   │ The save-failed      │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ default.             │   │ Alert shows above    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │                      │   │ the groups,          │
│                      │   │ [ Select a key ]     │   │ unchanged.           │
│                      │   │                      │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: A change saves at once, unchanged.

Held to:

- B3 — a form archetype contains a real <form> element
- B3 — the form column stays under 640px wide

### General tab · `settings.html · settings · General`

Archetype: `form` — Switches, vocabulary and the tour replay, grouped as Behaviour, Dictation and Help.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│ ▨ Parley      ⌕ Search…                                     ⌘K   ◐   ⬤     │
├───────────────┬────────────────────────────────────────────────────────────┤
│ Overview      │ General tab                                     [ Toggle ] │
│ Gesture       │                                                            │
│ General       │        ┌──────────────────────────────────────────┐        │
│ General tab ◀…│        │ General                                  │        │
│               │        │ ──────────────────────────────────────── │        │
│               │        │ BEHAVIOUR                                │        │
│               │        │ Sounds ............. (●)                 │        │
│               │        │ Launch at login .... (●)                 │        │
│               │        │ DICTATION                                │        │
│               │        │ Custom vocabulary [..........]           │        │
│               │        │ HELP                                     │        │
│               │        │ Product tour ....... Replay tour         │        │
│               │        │ ──────────────────────────────────────── │        │
│               │        │ [Replay tour]                            │        │
│               │        └──────────────────────────────────────────┘        │
└───────────────┴────────────────────────────────────────────────────────────┘
```

**Mobile @390** — design intent; the probe measures 1280 / 1440 / 1920 only.

```
┌──────────────────────────┐
│ ☰  General tab       ⌕   │
├──────────────────────────┤
│ ┌──────────────────────┐ │
│ │ BEHAVIOUR          … │ │
│ │ Sounds ............… │ │
│ │ Launch at login ...… │ │
│ │ DICTATION          … │ │
│ │ Custom vocabulary [… │ │
│ │ HELP               … │ │
│ │ Product tour ......… │ │
│ │ ──────────────────── │ │
│ │ [Replay tour]        │ │
│ └──────────────────────┘ │
│        [ Toggle ]        │
└──────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ Vocabulary empty:    │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ its placeholder      │   │ The save-failed      │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ gives an example.    │   │ Alert shows above    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │                      │   │ the groups,          │
│                      │   │ [ Toggle ]           │   │ unchanged.           │
│                      │   │                      │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: Toggles save at once. Vocabulary saves on blur, unchanged.

Held to:

- B3 — a form archetype contains a real <form> element
- B3 — the form column stays under 640px wide

## Components

Each choice states the neighbour it beat. `Use when:` / `Instead:` for every
component family lives in `.claude/skills/use-mantine/mantine-capabilities.md`;
the choices between families live in
`docs/principles/component-selection.md`.

| Surface | Control | Why this one | Not |
| --- | --- | --- | --- |
| all | `SettingsGroup: an uppercase dimmed label over a glass card whose rows are split by hairlines, with a minimum row height of 44 px` | This is the grouped-list idiom of macOS System Settings. One component gives every tab the same rhythm, so each card no longer sets its own padding. | `One glass Box per control (the current loose cards)` |
| overview | `StatusRow: label and reason on the left; Badge and a one-click fix Button on the right` | The fix sits where the problem is named, so each problem is one click from being fixed. | `A Finish setup banner and a separate forms section (today's Setup tab)` |
| overview | `Collapse under a key row holding the existing ApiKeySection` | Most visits need no key change. The form stays mounted, so a half-typed key survives a tab switch, as it does today. | `Always-open key forms, or a Modal (loses the row's context)` |
| overview | `Time-saved row: Text at size xl for the minutes, dimmed words count` | One number the user can feel. The words count keeps the estimate honest. | `A chart (too much for a running total), or a StatsGrid (one metric)` |

## Data model

- **Usage stat**
  - `wordsDictated`: number — main-process-only, in the settings.json envelope; the renderer reads it through SettingsView and cannot write it
  - _relations:_ time saved = words/40 − words/150 minutes (typing at 40 wpm vs speaking at 150)

## API endpoints

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| IPC invoke | `settings:get` | no | undefined |

## Integration points

```
  electron/settings-store.ts          ──▶  recordDictation(text) adds the word count; view() exposes wordsDictated   (kept out of Settings, so updateSettings can never set it)
  electron/main.ts                    ──▶  onDictation also calls store.recordDictation   (dictation only; voice edit and Explain are not counted)
  src/settings/OverviewTab.tsx        ──▶  SettingsShell, replacing SetupTab   (PermissionRow and ApiKeySection stay in SetupTab.tsx for the wizard and the offer)
  src/settings/SettingsGroup.tsx      ──▶  Overview, Gesture and General tabs   (GestureTab bare in the trainer uses it too)
  src/settings/tabs.ts + TabRail.tsx  ──▶  'setup' becomes 'overview'   (Overview is always the default tab now)
```

## Blast radius

```
new (5)
  ├── src/settings/OverviewTab.tsx
  ├── src/settings/SettingsGroup.tsx
  ├── src/settings/usage.ts
  ├── src/settings/__tests__/usage.test.ts
  └── src/settings/SettingsShell.stories.tsx

changed (23)
  ├── electron/types.ts
  ├── electron/settings-store.ts
  ├── electron/main.ts
  ├── electron/__tests__/settings-store.test.ts
  ├── src/settings/SettingsShell.tsx
  ├── src/settings/TabRail.tsx
  ├── src/settings/tabs.ts
  ├── src/settings/SetupTab.tsx
  ├── src/settings/GestureTab.tsx
  ├── src/settings/GeneralTab.tsx
  ├── src/settings/SettingRow.tsx
  ├── src/settings/settings.module.css
  ├── src/settings/__tests__/SettingsApp.test.tsx
  ├── src/settings/__tests__/SettingsShell.test.tsx
  ├── src/settings/__tests__/MiniMaxOffer.test.tsx
  ├── src/settings/Wizard.stories.tsx
  ├── docs/storybook-taxonomy.json
  ├── docs/MANUAL_CHECKLIST.md
  ├── feature_list.json
  ├── src/settings/__tests__/motion.test.tsx
  ├── src/theme.ts
  ├── .storybook/Introduction.mdx
  └── src/settings/__tests__/onboarding.test.tsx
```

## Verification plan

- [ ] `make check`
- [ ] `npm run test -- src/settings electron/__tests__/settings-store.test.ts`
- [ ] `Storybook screenshots at 760x560, dark and light: Overview ready, Overview needing setup, Gesture, General`
- [ ] `Manual: make dev — dictate a sentence, reopen settings, and see the word count and time saved rise`
- [ ] `Manual: revoke Accessibility in System Settings; the Overview title flips to Finish setup and the row's Grant button fixes it`
- [ ] `ux-prepass` — all seven boxes, `npm run ui-lint` green is the evidence for item 7

---

Approve this before any file is written. Every diagram above is rendered
from this feature's plan JSON, so the drawing and the build cannot drift;
the archetype frames are the same shapes `ui-probe` rules B1-B4 assert
against the real DOM once the screens exist.
