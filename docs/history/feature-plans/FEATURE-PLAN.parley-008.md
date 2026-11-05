<!-- feature-plan:v1 — generated, do not hand-edit.
     Regenerate with: node scripts/feature-plan.mjs parley-008.feature-plan.json -->

# Revamp phase 1: mode-colored orb, scene backdrop, one progress ring

`parley-008` · 3 surfaces

## Problem

Onboarding and settings read like an admin panel rather than a Mac app. The wizard shows progress three ways at once (a vertical Stepper rail, “Step N of 6” twice, and a Progress bar). The aurora gradient is on the tab pill and every primary button, so it no longer marks anything. The orb, Parley's one distinctive asset, is a 48 px sidebar icon. It also barely tells the modes apart: dictate and explain share the indigo palette, and edit is only a slightly shifted lilac. Phase 1 changes the atmosphere without changing the flow. The orb gets a distinct color per mode (dictate violet, edit amber, explain cyan — teal stays the orb's done flash, so the two never read alike). A tone-tinted Scene backdrop sits behind the tour and wizard. The wizard's progress becomes a single ring around a live orb above one centered column. The gradient is kept for the primary CTA only. The settings window gets an inset title bar so the scene runs edge to edge. Frame note: the settings window is not PageShell, so the archetypes below are illustrative and not probe-enforced, as in parley-007.

## Not in this feature

- Merging the tour and wizard into one flow, the gesture trainer, or moving MiniMax to first use — that is phase 2.
- Native grouped-list settings, a status header, or a time-saved stat — that is phase 3.
- Changing the 760x560 settings window size — it is already compact.
- New IPC channels — every change is renderer-side or in window options.
- A dark-only onboarding: the Scene follows the app theme, with lighter blooms on the light ground.

## Surfaces

### Setup wizard (all six steps) · `settings.html · wizard N/6`

Archetype: `form` — One centered column on a full-bleed Scene. A live orb inside a progress ring replaces the Stepper rail, both step counters and the Progress bar. Each step's content and footer stay as they are.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│ ▨ Parley      ⌕ Search…                                     ⌘K   ◐   ⬤     │
├───────────────┬────────────────────────────────────────────────────────────┤
│ Setup         │ Setup wizard (all six steps)                [ Continue → ] │
│ Gesture       │                                                            │
│ General       │        ┌──────────────────────────────────────────┐        │
│ Setup wizard …│        │ Open what Parley needs          ring 2/6 │        │
│               │        │ ◌ orb in a ring · Accessibility          │        │
│               │        │ ──────────────────────────────────────── │        │
│               │        │ ( ◉ ) ring 33% — Accessibility           │        │
│               │        │ 1 · Press the button below               │        │
│               │        │ 2 · Toggle Parley on                     │        │
│               │        │ 3 · Come back — this finishes itself     │        │
│               │        │ Status                         ○ Missing │        │
│               │        │ ──────────────────────────────────────── │        │
│               │        │ [Back]  [Open System Settings]           │        │
│               │        └──────────────────────────────────────────┘        │
└───────────────┴────────────────────────────────────────────────────────────┘
```

**Mobile @390** — design intent; the probe measures 1280 / 1440 / 1920 only.

```
┌──────────────────────────┐
│ ☰  Setup wizard (all…⌕   │
├──────────────────────────┤
│ ┌──────────────────────┐ │
│ │ ( ◉ ) ring 33% — Ac… │ │
│ │ 1 · Press the butto… │ │
│ │ 2 · Toggle Parley o… │ │
│ │ 3 · Come back — thi… │ │
│ │ Status     ○ Missing │ │
│ │ ──────────────────── │ │
│ │ [Back]  [Open Syste… │ │
│ └──────────────────────┘ │
│      [ Continue → ]      │
└──────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ Step already         │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ satisfied on         │   │ Save failed: the red │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ arrival: the ring    │   │ Alert sits above the │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ shows that step's    │   │ column. The ring     │
│                      │   │ fraction, the orb    │   │ does not advance and │
│                      │   │ sits still, and      │   │ the Scene keeps its  │
│                      │   │ Continue is          │   │ tone.                │
│                      │   │ available at once.   │   │                      │
│                      │   │                      │   │ [ Try again ]        │
│                      │   │ [ Continue → ]       │   │                      │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: Step completes: the ring sweeps to the next fraction on SPRING and the orb pulses once in the step's tone. Done fills the ring and turns it teal.

Held to:

- B3 — a form archetype contains a real <form> element
- B3 — the form column stays under 640px wide

### Tour slide · `settings.html · tour N/4`

Archetype: `centered-card` — Same four slides and Carousel, now on a Scene whose tone follows the slide: dictate violet, edit amber, explain cyan, trust neutral. The grey stage box goes away.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│                                                                            │
│                   ┌──────────────────────────────────────┐                 │
│                   │ Say how to change it          2 of 4 │                 │
│                   │ Scene tone: edit · amber             │                 │
│                   │ ──────────────────────────────────── │                 │
│                   │ “make it shorter”                    │                 │
│                   │ “The meeting that was planned…”      │                 │
│                   │ → “Meeting moved.” ✓                 │                 │
│                   ├──────────────────────────────────────┤                 │
│                   │               ○ ● ○ ○                │                 │
│                   │ ──────────────────────────────────── │                 │
│                   │ [Back]  [Next]                       │                 │
│                   └──────────────────────────────────────┘                 │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

**Mobile @390** — design intent; the probe measures 1280 / 1440 / 1920 only.

```
┌──────────────────────────┐
│ ☰  Tour slide        ⌕   │
├──────────────────────────┤
│ ┌──────────────────────┐ │
│ │ “make it shorter”  … │ │
│ │ “The meeting that w… │ │
│ │ → “Meeting moved.” … │ │
│ ├──────────────────────┤ │
│ │       ○ ● ○ ○        │ │
│ │ ──────────────────── │ │
│ │ [Back]  [Next]       │ │
│ └──────────────────────┘ │
│         [ Next ]         │
└──────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ If an illustration   │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ fails, the copy,     │   │ No error state: the  │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ dots and controls    │   │ tour is static       │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ still show on the    │   │ content.             │
│                      │   │ Scene, as today.     │   │                      │
│                      │   │                      │   │ [ Try again ]        │
│                      │   │ [ Next ]             │   │                      │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: On slide change the Scene tone crossfades over DURATION.slow. Under reduced motion it swaps with no transition.

Held to:

- B3 — the card is centred on both axes and stays under 480px wide

### Settings tab rail · `settings.html · settings`

Archetype: `list-detail` — The selection pill loses the aurora gradient and becomes an accent tint, so the gradient means ‘the primary action’ again. The rail header clears the inset traffic lights.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│ ▨ Parley      ⌕ Search…                                     ⌘K   ◐   ⬤     │
├───────────────┬────────────────────────────────────────────────────────────┤
│ Setup         │ Settings tab rail                           [ Select tab ] │
│ Gesture       │                                                            │
│ General       │ ┌──────────────────┐ ┌───────────────────────────────────┐ │
│ Settings tab …│ │ Parley           │ │ Gesture                           │ │
│               │ │ ──────────────── │ │ unchanged content                 │ │
│               │ │ ▣ Setup          │ │ ───────────────────────────────── │ │
│               │ │ □ Gesture        │ │ Selection  accent tint, not grad… │ │
│               │ │ □ General        │ └───────────────────────────────────┘ │
│               │ └──────────────────┘                                       │
└───────────────┴────────────────────────────────────────────────────────────┘
```

**Mobile @390** — design intent; the probe measures 1280 / 1440 / 1920 only.

```
┌──────────────────────────┐         ┌──────────────────────────┐
│ ☰  Settings tab rail ⌕   │         │ ‹ Back  Gesture          │
├──────────────────────────┤         ├──────────────────────────┤
│ ┌──────────────────────┐ │    ──▶  │ ┌──────────────────────┐ │
│ │ ▣ Setup              │ │         │ │ Gesture              │ │
│ │ □ Gesture            │ │         │ │ unchanged content    │ │
│ │ □ General            │ │         │ │ ──────────────────── │ │
│ └──────────────────────┘ │         │ │ Selection  accent t… │ │
│      [ Select tab ]      │         │ └──────────────────────┘ │
└──────────────────────────┘         └──────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ Unchanged:           │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ needs-setup lands on │   │ Unchanged: the       │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ the Setup tab.       │   │ save-failed Alert    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │                      │   │ shows above the      │
│                      │   │ [ Select tab ]       │   │ panel.               │
│                      │   │                      │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: The tinted pill slides between tabs on the existing layoutId spring.

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
| wizard | `OrbProgress: OrbCanvas inside an SVG ring, role=progressbar with aria-valuetext “Step 2 of 6: Accessibility”` | One indicator that also shows the hero object. The number now lives in aria-valuetext, so screen readers still get the fraction. | `Stepper + Progress + “Step N of 6” text (three competing indicators)` |
| wizard, tour | `Scene (CSS module: layered radial gradients + 3% noise, tone prop)` | Full-bleed atmosphere with no JS cost. Tone comes from mode tokens, so the backdrop and the orb always agree. | `WebGL backdrop (a second GL context beside OrbCanvas)` |
| all | `Mode token triples --app-edit-* (amber) and --app-explain-* (cyan) in theme.ts` | The orb palette already reads token triples through readTokenBytes. Two new triples give each mode its own hue without literals in the shader. | `Hard-coded RGB in orb-shader.ts` |
| wizard, tour | `Button with shell.primary for the primary CTA only` | One gradient per screen puts the eye on the next action. | `Gradient on every filled button` |
| settings-rail | `Accent-tint pill (primary-light background)` | Selection is state, not action, so a tint is the native macOS idiom. | `Aurora gradient pill` |
| all | `titleBarStyle hiddenInset + trafficLightPosition on the settings window` | The scene runs under the title bar the way full-bleed Mac apps do. The inset reuses TRAFFIC_LIGHT_INSET. | `frame:false (loses native window drag and the traffic lights)` |

## Data model

- **SceneTone**
  - `tone`: 'dictate' | 'edit' | 'explain' | 'neutral' | 'done' — maps 1:1 to SessionMode plus two onboarding states
  - _relations:_ drives Scene's CSS variables and the OrbProgress orb mode

## Integration points

```
  src/theme.ts                                 ──▶  --app-edit-{deep,core,glow} + --app-explain-{deep,core,glow}   (shared across color schemes like the aurora tokens; lilac is retired, nothing else reads it)
  src/orb/palette.ts                           ──▶  OrbPalette swaps lilac for edit + explain triples   (buildPalette reads them like aurora)
  src/orb/orb-shader.ts                        ──▶  mode map: dictate→aurora, edit→amber, explain→cyan   (the live overlay orb changes too, which is the point)
  src/orb/Pill.tsx                             ──▶  bar colours per mode   (edit and explain tokens, same as the shader)
  src/settings/Scene.tsx (+ Scene.module.css)  ──▶  Tour and WizardShell root   (replaces shell.shell's flat tint on those two stages)
  src/settings/wizard/OrbProgress.tsx          ──▶  WizardShell header   (Stepper, both step texts and Progress are deleted)
  src/settings/wizard/steps.tsx                ──▶  Continue buttons get shell.primary   (secondary buttons stay default)
  src/settings/settings.module.css             ──▶  .pill → accent tint   (.primary is unchanged)
  electron/windows.ts                          ──▶  settingsWindowOptions: hiddenInset + trafficLightPosition   (keep in step with src/lib/platform.ts TRAFFIC_LIGHT_INSET)
  src/settings/Tour.tsx                        ──▶  Scene tone per slide; stage box removed   (Carousel unchanged)
```

## Blast radius

```
new (4)
  ├── src/settings/Scene.tsx
  ├── src/settings/Scene.module.css
  ├── src/settings/wizard/OrbProgress.tsx
  └── src/settings/__tests__/OrbProgress.test.tsx

changed (15)
  ├── src/theme.ts
  ├── src/orb/palette.ts
  ├── src/orb/orb-shader.ts
  ├── src/orb/Pill.tsx
  ├── src/orb/__tests__/palette.test.ts
  ├── src/settings/wizard/WizardShell.tsx
  ├── src/settings/wizard/steps.tsx
  ├── src/settings/tour/Tour.tsx
  ├── src/settings/settings.module.css
  ├── src/settings/SettingsShell.tsx
  ├── src/settings/TabRail.tsx
  ├── electron/windows.ts
  ├── electron/__tests__/windows.test.ts
  ├── src/settings/Wizard.stories.tsx
  └── feature_list.json
```

## Verification plan

- [ ] `make check`
- [ ] `npm run test -- src/settings/__tests__/onboarding.test.tsx src/settings/__tests__/OrbProgress.test.tsx src/orb`
- [ ] `npm run ui-probe (Tour + Wizard stories)`
- [ ] `Manual: make dev — the overlay orb is violet for dictate, amber for edit and cyan for explain`
- [ ] `Manual: walk the wizard; only the ring shows progress and each step has one gradient button`
- [ ] `Manual: Reduce Motion — the ring and Scene tone change with no animation`
- [ ] `ux-prepass` — all seven boxes, `npm run ui-lint` green is the evidence for item 7

---

Approve this before any file is written. Every diagram above is rendered
from this feature's plan JSON, so the drawing and the build cannot drift;
the archetype frames are the same shapes `ui-probe` rules B1-B4 assert
against the real DOM once the screens exist.
