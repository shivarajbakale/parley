<!-- feature-plan:v1 — generated, do not hand-edit.
     Regenerate with: node scripts/feature-plan.mjs explain-selection.feature-plan.json -->

# Explain selection

`explain-selection` · 2 surfaces

## Problem

Reading something unfamiliar in any app (a term, a snippet, a sentence) means leaving it, opening a browser or chat, pasting, and reading the answer somewhere else. Parley already sits over every app, so a third gesture can explain the current selection in a markdown popover right beside it.

## Not in this feature

- Follow-up questions or chat. One selection, one explanation, then dismiss.
- Voice: the gesture is a trigger only, nothing is recorded.
- Windows and Linux. Anchoring and selection reading use the macOS Accessibility API.
- Long essays. The prompt asks for a short answer; the card is built to fit it without scrolling.

## Surfaces

### Explanation popover · `explain.html (own frameless window)`

Archetype: `centered-card` — Show the explanation next to the selection without stealing focus from the app.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│                                                                            │
│                   ┌──────────────────────────────────────┐                 │
│                   │ idempotent                   Explain │                 │
│                   │ glass card, 16 px from selection     │                 │
│                   │ ──────────────────────────────────── │                 │
│                   │ Meaning      Same result if repeated │                 │
│                   │ Example           PUT /users/1 twice │                 │
│                   │ Related                   safe, pure │                 │
│                   │ ──────────────────────────────────── │                 │
│                   │ [Copy]  [Esc]                        │                 │
│                   └──────────────────────────────────────┘                 │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

**Mobile @390** — design intent; the probe measures 1280 / 1440 / 1920 only.

```
┌──────────────────────────┐
│ ☰  Explanation popov…⌕   │
├──────────────────────────┤
│ ┌──────────────────────┐ │
│ │ Meaning  Same resul… │ │
│ │ Example  PUT /users… │ │
│ │ Related   safe, pure │ │
│ │ ──────────────────── │ │
│ │ [Copy]  [Esc]        │ │
│ └──────────────────────┘ │
│         [ Copy ]         │
└──────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ No selection found:  │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ card says 'Select    │   │ One line in the      │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ some text first' and │   │ card: 'No MiniMax    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ dismisses itself     │   │ key', 'No            │
│                      │   │ after 2 s.           │   │ connection', 'Rate   │
│                      │   │                      │   │ limited' — same      │
│                      │   │ [ Copy ]             │   │ wording as voice     │
│                      │   │                      │   │ edit.                │
│                      │   │                      │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: Markdown rendered (headings, lists, code, bold). Card sizes to its content, up to 60% of the display height, then and only then scrolls. Esc, click outside, or a new selection dismisses.

Held to:

- B3 — the card is centred on both axes and stays under 480px wide

### Settings, Gesture tab · `settings window / Gesture`

Archetype: `form` — Choose which key triggers Explain, next to the dictate and edit keys.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│ ▨ Acme      ⌕ Search…                                       ⌘K   ◐   ⬤     │
├───────────────┬────────────────────────────────────────────────────────────┤
│ Dashboard     │ Settings, Gesture tab                                      │
│ Projects      │                                                            │
│ Inbox         │        ┌──────────────────────────────────────────┐        │
│ Team          │        │ Explain key                              │        │
│ Billing       │        │ tap-tap-hold on this key                 │        │
│ Settings      │        │ ──────────────────────────────────────── │        │
│ Settings, Ges…│        │ Dictate                     Right Option │        │
│               │        │ Voice edit                 Right Command │        │
│               │        │ Explain                    Right Control │        │
│               │        └──────────────────────────────────────────┘        │
└───────────────┴────────────────────────────────────────────────────────────┘
```

**Mobile @390** — design intent; the probe measures 1280 / 1440 / 1920 only.

```
┌──────────────────────────┐
│ ☰  Settings, Gesture…⌕   │
├──────────────────────────┤
│ ┌──────────────────────┐ │
│ │ Dictate     Right O… │ │
│ │ Voice edit  Right C… │ │
│ │ Explain     Right C… │ │
│ └──────────────────────┘ │
└──────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ Explain key equal to │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ another gesture key  │   │ No MiniMax key: row  │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ means Explain is     │   │ shows a hint         │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ off, with the same   │   │ pointing to the      │
│                      │   │ hint edit uses.      │   │ Setup tab.           │
│                      │   │                      │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: Selecting a key saves immediately, as the other rows do.

Held to:

- B3 — a form archetype contains a real <form> element
- B3 — the form column stays under 640px wide

## Overlays

```
       popover · explain-card
┌────────────────────────────────┐
│ Explain                        │
│ ────────────────────────────── │
│ Markdown answer, anchored to … │
│                       [ Copy ] │
└────────────────────────────────┘
```

## Components

Each choice states the neighbour it beat. `Use when:` / `Instead:` for every
component family lives in `.claude/skills/use-mantine/mantine-capabilities.md`;
the choices between families live in
`docs/principles/component-selection.md`.

| Surface | Control | Why this one | Not |
| --- | --- | --- | --- |
| popover | `Own frameless BrowserWindow (focusable:false, transparent, alwaysOnTop)` | must float over other apps and never take focus from the selection; Mantine Popover only lives inside our own windows | `Mantine Popover` |
| popover | `react-markdown (new dependency)` | answer is markdown; renders to React elements with no innerHTML, so model output cannot inject markup | `dangerouslySetInnerHTML with marked` |
| popover | `Skeleton` | answer shape is known: a few text lines | `Loader` |
| popover | `ScrollArea (last resort)` | the card grows to fit its content and only scrolls past 60% of display height; short answers make that rare | `fixed-height card that scrolls by default` |
| gesture-row | `Select` | eight fixed modifier keys, same as the existing rows | `Combobox` |
| popover | `Auto-resizing window` | main resizes the window to the rendered content height (renderer reports it over IPC), so there is no inner scrollbar until the cap; the window is transparent so extra size is invisible | `fixed 320 px card` |
| popover | `Brevity prompt` | system prompt asks for at most ~80 words: one-line meaning, then at most 3 bullets or one short example; no headings, no preamble. Fewer lines is the main way to avoid scrolling | `open-ended explanation` |

## Data model

- **Settings.explainGestureKey**
  - `explainGestureKey`: GestureKey — default CtrlRight; equal to another key = off
  - _relations:_ reuses tapCount, so all three gestures share one tap count
- **SelectionSnapshot**
  - `text`: string — capped at ~8k chars before sending
  - `anchor`: Rect | null — AX bounds of selected range, screen coordinates
  - `maxHeight`: number — 0.6 x work-area height of the anchor display; card is 420 px wide so lines wrap less

## API endpoints

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| POST | `https://api.minimax.io/v1/chat/completions` | yes | Rewriter.explain(), same key, endpoint and error kinds as voice edit; streaming optional in a later step |

## Integration points

```
  gesture-detector.ts           ──▶  third detector in main.ts   (tap-tap-hold on the explain key fires onStart; hold release is ignored, it is a trigger only)
  native/parley-ax.swift        ──▶  selection + bounds   (read selection text and bounds for any focused element that is not a password field; multi-line selections anchor to the whole selection rectangle)
  injector.ts sendCopy          ──▶  clipboard fallback   (Chrome and Electron often hide AX text: copy, read, restore the clipboard, anchor at the cursor)
  add-ipc-channel               ──▶  explain:show / explain:dismiss   (main pushes state (loading, text, error, rect) to the explain window; only that window may send dismiss)
  key-hook Escape + mouse-down  ──▶  dismiss   (window is unfocusable, so dismissal comes from the global hook)
```

## Blast radius

```
new (11)
  ├── electron/explain.ts
  ├── electron/explain-placement.ts
  ├── electron/selection-reader.ts
  ├── explain.html
  ├── src/explain/main.tsx
  ├── src/explain/ExplainCard.tsx
  ├── src/explain/ExplainCard.module.css
  ├── electron/__tests__/explain.test.ts
  ├── electron/__tests__/explain-placement.test.ts
  ├── electron/__tests__/selection-reader.test.ts
  └── src/explain/__tests__/ExplainCard.test.tsx

changed (12)
  ├── electron/main.ts
  ├── electron/preload.ts
  ├── electron/types.ts
  ├── electron/windows.ts
  ├── electron/settings-store.ts
  ├── electron/rewriter.ts
  ├── electron/field-reader.ts
  ├── electron/injector.ts
  ├── native/parley-ax.swift
  ├── src/settings/GestureTab.tsx
  ├── vite.config.ts
  └── package.json
```

## Verification plan

- [ ] `make check`
- [ ] `Manual: select text in Safari, Notes and VS Code; tap-tap-hold the explain key; card appears at the selection with markdown`
- [ ] `Manual: password field selection yields nothing; no MiniMax key shows the error line`
- [ ] `ux-prepass` — all seven boxes, `npm run ui-lint` green is the evidence for item 7

---

Approve this before any file is written. Every diagram above is rendered
from this feature's plan JSON, so the drawing and the build cannot drift;
the archetype frames are the same shapes `ui-probe` rules B1-B4 assert
against the real DOM once the screens exist.
