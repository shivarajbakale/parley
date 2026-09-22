<!-- feature-plan:v1 — generated, do not hand-edit.
     Regenerate with: node scripts/feature-plan.mjs parley-009.feature-plan.json -->

# Revamp phase 2: one first-run flow, gesture trainer, MiniMax on first use, menu-bar finale

`parley-009` · 4 surfaces

## Problem

First run is two flows back to back. A four-slide tour explains features before anything works, then a six-step wizard sets them up, and the MiniMax step asks for a second API key that most people cannot use yet. The practice step shows three dots and a ring, so a failed gesture gets no reason. The Done screen is a table of settings and never says where Parley lives afterwards, and people forget the menu bar icon. On the dark Scene every light-variant Badge and Button (Missing, Grant …) renders solid black: Mantine's dark light-variant calls darken(), which cannot parse the theme's oklch colors and returns rgba(0,0,0,1). Phase 2 merges everything into one six-screen flow on the Scene: Welcome, Microphone, Accessibility, Transcription, Gesture trainer and First words, then a finale where the orb flies to the ◉ menu bar item. MiniMax leaves first run: the first voice edit or Explain gesture without a key opens a mode-colored offer instead of a toast. The tour stays, reachable only as a replay. Frame note: the settings window is not PageShell, so the archetypes below are illustrative and not probe-enforced, as in parley-007 and parley-008.

## Not in this feature

- Native grouped-list settings, a status header or a time-saved stat — that is phase 3.
- Validating a key on paste with no Save button — Test and save stays.
- An orb that pulses to key presses in the real overlay — the trainer lights key caps only.
- Animating across the real screen to the macOS menu bar — the flight stays inside the window, onto a drawn menu bar strip.
- Migrating a stored mid-wizard step: indices keep their count (0–5, Done 6), so a resumed user may land one screen off, which is harmless.

## Surfaces

### Welcome (screen 1 of 6) · `settings.html · first run 1/6`

Archetype: `centered-card` — Replaces the tour on first run. One line of promise, the three modes each with its orb color, a privacy line and one button.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│                                                                            │
│                   ┌──────────────────────────────────────┐                 │
│                   │ Talk to any text field      ring 1/6 │                 │
│                   │ Welcome to Parley                    │                 │
│                   │ ──────────────────────────────────── │                 │
│                   │ ● violet  Dictate — hold, speak, re… │                 │
│                   │ ● amber   Voice edit — say how to c… │                 │
│                   │ ● cyan    Explain — ask about a sel… │                 │
│                   ├──────────────────────────────────────┤                 │
│                   │Mic is live only while you hold · abo…│                 │
│                   │ ──────────────────────────────────── │                 │
│                   │ [Get started →]                      │                 │
│                   └──────────────────────────────────────┘                 │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

**Mobile @390** — design intent; the probe measures 1280 / 1440 / 1920 only.

```
┌──────────────────────────┐
│ ☰  Welcome (screen 1…⌕   │
├──────────────────────────┤
│ ┌──────────────────────┐ │
│ │ ● violet  Dictate —… │ │
│ │ ● amber   Voice edi… │ │
│ │ ● cyan    Explain —… │ │
│ ├──────────────────────┤ │
│ │Mic is live only whil…│ │
│ │ ──────────────────── │ │
│ │ [Get started →]      │ │
│ └──────────────────────┘ │
│    [ Get started → ]     │
└──────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ No empty state: the  │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ screen is static     │   │ Save failed on Get   │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ content.             │   │ started: the red     │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │                      │   │ Alert shows above    │
│                      │   │ [ Get started → ]    │   │ the column and the   │
│                      │   │                      │   │ screen stays put.    │
│                      │   │                      │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: Get started advances to Microphone and the ring sweeps on SPRING.

Held to:

- B3 — the card is centred on both axes and stays under 480px wide

### Gesture trainer (screen 5 of 6) · `settings.html · first run 5/6`

Archetype: `form` — Replaces the Hotkeys step. One Kbd cap per press lights as you press, the last one fills while held, and a missed attempt says why in words from the real detector's constants. Capture sets the key, and the edit and explain keys plus the press count sit behind a More keys toggle.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│ ▨ Parley      ⌕ Search…                                     ⌘K   ◐   ⬤     │
├───────────────┬────────────────────────────────────────────────────────────┤
│ Setup         │ Gesture trainer (screen 5 of 6)             [ Continue → ] │
│ Gesture       │                                                            │
│ General       │        ┌──────────────────────────────────────────┐        │
│ Gesture train…│        │ Learn the gesture                        │        │
│               │        │ Right Option · Capture                   │        │
│               │        │ ──────────────────────────────────────── │        │
│               │        │ [⌥ tap] [⌥ tap] [⌥ hold ▓▓░]           … │        │
│               │        │ Too slow between taps — keep them withi… │        │
│               │        │ More keys  ▸ Voice edit, Explain, Press… │        │
│               │        │ ──────────────────────────────────────── │        │
│               │        │ [Back]  [Continue →]                     │        │
│               │        └──────────────────────────────────────────┘        │
└───────────────┴────────────────────────────────────────────────────────────┘
```

**Mobile @390** — design intent; the probe measures 1280 / 1440 / 1920 only.

```
┌──────────────────────────┐
│ ☰  Gesture trainer (…⌕   │
├──────────────────────────┤
│ ┌──────────────────────┐ │
│ │ [⌥ tap] [⌥ tap] [⌥ … │ │
│ │ Too slow between ta… │ │
│ │ More keys  ▸ Voice … │ │
│ │ ──────────────────── │ │
│ │ [Back]  [Continue →] │ │
│ └──────────────────────┘ │
│      [ Continue → ]      │
└──────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ Nothing pressed yet: │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ every cap is unlit   │   │ A missed attempt     │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ and the hint reads   │   │ resets the caps and  │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ ‘Tap ⌥ twice, then   │   │ names the reason: a  │
│                      │   │ hold it’.            │   │ tap held too long,   │
│                      │   │                      │   │ too long a gap, or   │
│                      │   │ [ Continue → ]       │   │ the hold let go      │
│                      │   │                      │   │ early.               │
│                      │   │                      │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: The hold completes: every cap turns teal and the live line reads ‘That’s the gesture ✓’. Continue is never gated on it.

Held to:

- B3 — a form archetype contains a real <form> element
- B3 — the form column stays under 640px wide

### Finale (after screen 6) · `settings.html · first run done`

Archetype: `centered-card` — Replaces the Done table. The orb flies from the middle of the window onto a drawn menu bar strip next to ◉, and the copy says where Parley lives. Only missing items are listed, each with a fix.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│                                                                            │
│                   ┌──────────────────────────────────────┐                 │
│                   │ Parley lives in your menu bar        │                 │
│                   │ Wi‑Fi  ◉  9:41                       │                 │
│                   │ ──────────────────────────────────── │                 │
│                   │ Hold ⌥ in any app to talk.         … │                 │
│                   │ Click ◉ up top for settings.       … │                 │
│                   │ (only if missing) Microphone · Re-o… │                 │
│                   │ ──────────────────────────────────── │                 │
│                   │ [Take the tour]  [Start using Parle… │                 │
│                   └──────────────────────────────────────┘                 │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

**Mobile @390** — design intent; the probe measures 1280 / 1440 / 1920 only.

```
┌──────────────────────────┐
│ ☰  Finale (after scr…⌕   │
├──────────────────────────┤
│ ┌──────────────────────┐ │
│ │ Hold ⌥ in any app t… │ │
│ │ Click ◉ up top for … │ │
│ │ (only if missing) M… │ │
│ │ ──────────────────── │ │
│ │ [Take the tour]  [S… │ │
│ └──────────────────────┘ │
│  [ Start using Parley ]  │
└──────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ Nothing missing: no  │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ rows, only the two   │   │ A missing permission │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ lines of copy.       │   │ or key shows as a    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │                      │   │ row with Re-open     │
│                      │   │ [ Start using Parley…│   │ step, which jumps    │
│                      │   │                      │   │ back to that screen. │
│                      │   │                      │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: The orb lands on the strip after a beat, the Scene turns teal, and Start using Parley opens the tabbed settings. Under reduced motion the orb is already in place.

Held to:

- B3 — the card is centred on both axes and stays under 480px wide

### MiniMax first-use offer (modal over any stage) · `settings.html · session blocked: rewriteKey`

Archetype: `centered-card` — The first voice edit or Explain gesture with no MiniMax key opens the settings window with this modal in place of a toast: what the two modes do, in their colors, and the key form.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│                                                                            │
│                   ┌──────────────────────────────────────┐                 │
│                   │ Voice edit and Explain need MiniMax  │                 │
│                   │ ──────────────────────────────────── │                 │
│                   │ ● amber  Voice edit rewrites the fi… │                 │
│                   │ ● cyan   Explain answers about a se… │                 │
│                   │ [ MiniMax API key ••••• ] Test and … │                 │
│                   │ ──────────────────────────────────── │                 │
│                   │ [Not now]  [Test and save MiniMax k… │                 │
│                   └──────────────────────────────────────┘                 │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

**Mobile @390** — design intent; the probe measures 1280 / 1440 / 1920 only.

```
┌──────────────────────────┐
│ ☰  MiniMax first-use…⌕   │
├──────────────────────────┤
│ ┌──────────────────────┐ │
│ │ ● amber  Voice edit… │ │
│ │ ● cyan   Explain an… │ │
│ │ [ MiniMax API key •… │ │
│ │ ──────────────────── │ │
│ │ [Not now]  [Test an… │ │
│ └──────────────────────┘ │
│[ Test and save MiniMax k…│
└──────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ Opened with no key   │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ stored: the form is  │   │ A key that fails its │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ empty.               │   │ test shows the       │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │                      │   │ reason in red under  │
│                      │   │ [ Test and save Mini…│   │ the field, and the   │
│                      │   │                      │   │ modal stays open.    │
│                      │   │                      │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: The key stores, the modal says ‘Try the gesture again’ and closes itself.

Held to:

- B3 — the card is centred on both axes and stays under 480px wide

## Overlays

```
    dialog · minimax-offer-modal
┌────────────────────────────────┐
│ Voice edit and Explain need… ✕ │
│ ────────────────────────────── │
└────────────────────────────────┘
```

## Components

Each choice states the neighbour it beat. `Use when:` / `Instead:` for every
component family lives in `.claude/skills/use-mantine/mantine-capabilities.md`;
the choices between families live in
`docs/principles/component-selection.md`.

| Surface | Control | Why this one | Not |
| --- | --- | --- | --- |
| welcome | `ColorSwatch per mode, colored from the --app-*-core tokens` | It teaches the orb's three colors before the user ever sees the overlay, using a Mantine primitive rather than a hand-drawn dot. | `The four-slide Carousel tour on first run (explains before anything works)` |
| trainer | `Kbd caps with a data-state (idle, lit, holding, done) styled by a CSS module, driven by a pure trainer reducer` | The keys you press are the thing drawn, and the reducer mirrors gesture-detector's TAP_MAX_MS, GAP_MAX_MS and HOLD_MIN_MS, so a failure names a real reason. | `Dots plus RingProgress (shows progress but never why a try failed)` |
| trainer | `Collapse behind a subtle ‘More keys’ Button holding GestureTab bare` | Most people keep the default edit and explain keys, so progressive disclosure keeps the trainer the focus. | `GestureTab always open under the trainer` |
| finale | `motion layoutId shared between the centered orb and the menu bar strip slot` | One spring flight with no measuring code, and MotionConfig reducedMotion=user already makes it instant. | `Measured x/y keyframes (brittle at other widths)` |
| minimax-offer | `Modal with ApiKeySection` | Asking at the moment of need is a confirmation-shaped interruption, and the key form is already built. | `A wizard step (asks before anyone needs it) or a toast (no way to act on it)` |
| all | `cssVariablesResolver dark overrides for --mantine-color-{brand,green,yellow,red}-light and -light-hover as color-mix of the filled shade` | Fixes every light-variant Badge and Button app-wide at the root, not per call site. | `Switching the PermissionRow badge and button to another variant (leaves the bug everywhere else)` |

## Data model

- **Trainer state**
  - `taps`: number — quick presses so far
  - `phase`: 'idle' | 'tapping' | 'holding' | 'done'
  - `miss`: 'tapTooLong' | 'gapTooLong' | 'releasedEarly' | null — why the last try reset
  - _relations:_ mirrors electron/gesture-detector.ts timing constants

## API endpoints

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| IPC invoke | `session:take-blocked` | no | undefined |

## Integration points

```
  src/settings/wizard/stage.ts              ──▶  stageFor: wizard until onboarding completes, then the tour only if replayed   (complete() also sets tourSeen, so a new user never sees the tour unasked)
  src/settings/wizard/steps.tsx             ──▶  WelcomeStep, TranscriptionStep (renamed Groq), TrainerStep, FinaleStep; MinimaxStep and HotkeysStep removed   (Mic, Accessibility and First words keep their behaviour)
  src/settings/wizard/trainer.ts            ──▶  pure reducer used by TrainerStep   (unit-tested without timers)
  electron/main.ts + preload.ts + types.ts  ──▶  pending blocked reason and takeBlockedReason()   (live push unchanged when the window is loaded)
  src/settings/MiniMaxOffer.tsx             ──▶  SettingsApp, over every stage   (rewriteKey no longer toasts; the other reasons still do)
  src/theme.ts                              ──▶  dark light-variant variables   (all four custom ramps)
  src/settings/tour/Tour.tsx                ──▶  replay only: last button reads Done, trust copy drops the setup line   (slides unchanged)
```

## Blast radius

```
new (6)
  ├── src/settings/wizard/trainer.ts
  ├── src/settings/wizard/Trainer.module.css
  ├── src/settings/MiniMaxOffer.tsx
  ├── src/settings/__tests__/trainer.test.ts
  ├── src/settings/__tests__/MiniMaxOffer.test.tsx
  └── src/settings/MiniMaxOffer.stories.tsx

changed (22)
  ├── src/settings/wizard/steps.tsx
  ├── src/settings/wizard/WizardShell.tsx
  ├── src/settings/wizard/stage.ts
  ├── src/settings/wizard/useOnboarding.ts
  ├── src/settings/SettingsApp.tsx
  ├── src/settings/tour/Tour.tsx
  ├── src/settings/Scene.module.css
  ├── src/theme.ts
  ├── electron/types.ts
  ├── electron/preload.ts
  ├── electron/main.ts
  ├── src/settings/__tests__/onboarding.test.tsx
  ├── src/settings/__tests__/SettingsApp.test.tsx
  ├── src/settings/__tests__/SettingsShell.test.tsx
  ├── src/settings/Wizard.stories.tsx
  ├── src/settings/Tour.stories.tsx
  ├── docs/MANUAL_CHECKLIST.md
  ├── feature_list.json
  ├── src/settings/gesture-keys.ts
  ├── docs/storybook-taxonomy.json
  ├── .storybook/sections/parley-onboarding.mdx
  └── .storybook/Introduction.mdx
```

## Verification plan

- [ ] `make check`
- [ ] `npm run test -- src/settings`
- [ ] `npm run ui-probe (Wizard stories: Welcome, Trainer, Finale; Tour stories)`
- [ ] `Storybook screenshots at 760x560, dark and light: no black Badge or Button on the Scene`
- [ ] `Manual: make dev from a clean userData — Welcome to finale without the tour; the orb lands by ◉`
- [ ] `Manual: with no MiniMax key, the voice edit gesture opens the settings window on the offer, both when the window was closed and when it was open`
- [ ] `ux-prepass` — all seven boxes, `npm run ui-lint` green is the evidence for item 7

---

Approve this before any file is written. Every diagram above is rendered
from this feature's plan JSON, so the drawing and the build cannot drift;
the archetype frames are the same shapes `ui-probe` rules B1-B4 assert
against the real DOM once the screens exist.
