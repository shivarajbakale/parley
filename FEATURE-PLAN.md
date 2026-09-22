<!-- feature-plan:v1 — generated, do not hand-edit.
     Regenerate with: node scripts/feature-plan.mjs parley-007.feature-plan.json -->

# Guided onboarding: product tour + setup wizard

`parley-007` · 11 surfaces

## Problem

First launch drops the user into a Setup tab that stacks both permissions and both API keys on one scrolling page, while hotkeys hide on a separate Gesture tab nothing points to. Nothing says what order to do things in, what is required versus optional (MiniMax), or when setup is done — so users stall with a half-configured menu-bar app they cannot try. This feature replaces first-run with a 4-slide animated product tour (literal mini-UI scenes), then a 6-step setup wizard (mic, accessibility, Groq key, MiniMax optional, hotkeys, practice), then lands on the normal Settings with a Ready moment. No new IPC channels: every step rides the existing settings/permissions/key bridge. Frame note: the settings window is not PageShell, so the desktop shell sidebar below stands in for the window edge, the B-rules are illustrative rather than probe-enforced, and during tour/wizard the tab rail is replaced (tour: nothing; wizard: step rail).

## Not in this feature

- Autoplay on the tour — manual advance only, so nothing moves unless the user asked.
- A Dictionary tab, snippets, or add-by-voice — parley-006 owns those.
- Windows/Linux onboarding differences — macOS-first; other platforms get honest degrading copy.
- Tour analytics or telemetry — completion is local state only.
- Resizing the 760x560 window — tour and wizard stack inside it.

## Surfaces

### Tour · Hold to talk · `settings.html · tour 1/4`

Archetype: `centered-card` — Slide 1 sells the aha moment: hold, speak, release, text appears.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│                                                                            │
│                   ┌──────────────────────────────────────┐                 │
│                   │ Hold to talk, release to paste 1 of 4│                 │
│                   │ The whole product in ten seconds     │                 │
│                   │ ──────────────────────────────────── │                 │
│                   │ [Right Option] held …                │                 │
│                   │ ◉ ▂▄▆█▆▄▂ listening                  │                 │
│                   │ “Meeting moved to three” ▌           │                 │
│                   ├──────────────────────────────────────┤                 │
│                   │               ● ○ ○ ○                │                 │
│                   │ ──────────────────────────────────── │                 │
│                   │ [Skip]  [Next]                       │                 │
│                   └──────────────────────────────────────┘                 │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

**Mobile @390** — design intent; the probe measures 1280 / 1440 / 1920 only.

```
┌──────────────────────────┐
│ ☰  Tour · Hold to ta…⌕   │
├──────────────────────────┤
│ ┌──────────────────────┐ │
│ │ [Right Option] held… │ │
│ │ ◉ ▂▄▆█▆▄▂ listening… │ │
│ │ “Meeting moved to t… │ │
│ ├──────────────────────┤ │
│ │       ● ○ ○ ○        │ │
│ │ ──────────────────── │ │
│ │ [Skip]  [Next]       │ │
│ └──────────────────────┘ │
│         [ Next ]         │
└──────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ A slide whose        │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ illustration failed  │   │ No error state: the  │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ still shows          │   │ tour is static       │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ headline, copy, dots │   │ content with no      │
│                      │   │ and Next — the tour  │   │ async work.          │
│                      │   │ never strands.       │   │                      │
│                      │   │                      │   │ [ Try again ]        │
│                      │   │ [ Next ]             │   │                      │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: Loop runs (pauses offscreen; static end-frame under reduced motion). Next advances, Skip jumps to the wizard.

Held to:

- B3 — the card is centred on both axes and stays under 480px wide

### Tour · Say how to change it · `settings.html · tour 2/4`

Archetype: `centered-card` — Slide 2 shows voice edit: speech becomes an instruction that rewrites the field.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│                                                                            │
│                   ┌──────────────────────────────────────┐                 │
│                   │ Say how to change it          2 of 4 │                 │
│                   │ Voice edit rewrites the field        │                 │
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
│ ☰  Tour · Say how to…⌕   │
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
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ Same guarantee as    │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ slide 1: copy and    │   │ No error state:      │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ controls survive an  │   │ static content.      │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ illustration         │   │                      │
│                      │   │ failure.             │   │ [ Try again ]        │
│                      │   │                      │   │                      │
│                      │   │ [ Next ]             │   │                      │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: Strike-through dissolves into the teal rewrite on a loop; Back returns, Next advances.

Held to:

- B3 — the card is centred on both axes and stays under 480px wide

### Tour · Ask about anything · `settings.html · tour 3/4`

Archetype: `centered-card` — Slide 3 shows Explain: select text anywhere, get an answer beside it.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│                                                                            │
│                   ┌──────────────────────────────────────┐                 │
│                   │ Ask about anything            3 of 4 │                 │
│                   │ Explain answers beside the text      │                 │
│                   │ ──────────────────────────────────── │                 │
│                   │ selected: “…idempotent…”             │                 │
│                   │ card blooms beside it                │                 │
│                   │ skeleton → markdown lines            │                 │
│                   ├──────────────────────────────────────┤                 │
│                   │               ○ ○ ● ○                │                 │
│                   │ ──────────────────────────────────── │                 │
│                   │ [Back]  [Next]                       │                 │
│                   └──────────────────────────────────────┘                 │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

**Mobile @390** — design intent; the probe measures 1280 / 1440 / 1920 only.

```
┌──────────────────────────┐
│ ☰  Tour · Ask about …⌕   │
├──────────────────────────┤
│ ┌──────────────────────┐ │
│ │ selected: “…idempot… │ │
│ │ card blooms beside … │ │
│ │ skeleton → markdown… │ │
│ ├──────────────────────┤ │
│ │       ○ ○ ● ○        │ │
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
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ Same guarantee: copy │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ and controls survive │   │ No error state:      │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ an illustration      │   │ static content.      │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ failure.             │   │                      │
│                      │   │                      │   │ [ Try again ]        │
│                      │   │ [ Next ]             │   │                      │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: Highlight pulses, mini card blooms with skeleton resolving to lines; Back/Next work.

Held to:

- B3 — the card is centred on both axes and stays under 480px wide

### Tour · Yours alone · `settings.html · tour 4/4`

Archetype: `centered-card` — Slide 4 earns trust before asking for permissions and keys.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│                                                                            │
│                   ┌──────────────────────────────────────┐                 │
│                   │ Yours alone                   4 of 4 │                 │
│                   │ Private by design · ~2 min setup next│                 │
│                   │ ──────────────────────────────────── │                 │
│                   │ keys → encrypted at rest             │                 │
│                   │ mic live only while held             │                 │
│                   │ transcripts never stored             │                 │
│                   ├──────────────────────────────────────┤                 │
│                   │               ○ ○ ○ ●                │                 │
│                   │ ──────────────────────────────────── │                 │
│                   │ [Back]  [Set up Parley]              │                 │
│                   └──────────────────────────────────────┘                 │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

**Mobile @390** — design intent; the probe measures 1280 / 1440 / 1920 only.

```
┌──────────────────────────┐
│ ☰  Tour · Yours alone⌕   │
├──────────────────────────┤
│ ┌──────────────────────┐ │
│ │ keys → encrypted at… │ │
│ │ mic live only while… │ │
│ │ transcripts never s… │ │
│ ├──────────────────────┤ │
│ │       ○ ○ ○ ●        │ │
│ │ ──────────────────── │ │
│ │ [Back]  [Set up Par… │ │
│ └──────────────────────┘ │
│    [ Set up Parley ]     │
└──────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ Same guarantee: copy │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ and controls survive │   │ No error state:      │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ an illustration      │   │ static content.      │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ failure.             │   │                      │
│                      │   │                      │   │ [ Try again ]        │
│                      │   │ [ Set up Parley ]    │   │                      │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: Trust rows + time estimate land; CTA enters the wizard at step 1.

Held to:

- B3 — the card is centred on both axes and stays under 480px wide

### Setup wizard · `settings.html · wizard 1/6`

Archetype: `list-detail` — The step rail persists across all six steps; the mic pane proves “it hears me” with a live orb. Later steps reuse this rail and are drawn pane-only.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│ ▨ Parley      ⌕ Search…                                     ⌘K   ◐   ⬤     │
├───────────────┬────────────────────────────────────────────────────────────┤
│ Setup         │ Setup wizard                                [ Continue → ] │
│ Gesture       │                                                            │
│ General       │ ┌──────────────────┐ ┌───────────────────────────────────┐ │
│ Setup wizard …│ │ Setup            │ │ Let Parley hear you        1 of 6 │ │
│               │ │ ──────────────── │ │ Grant the mic, watch the orb move │ │
│               │ │ ● Microphone     │ │ ───────────────────────────────── │ │
│               │ │ ○ Accessibility  │ │ Status                  ○ Missing │ │
│               │ │ ○ Groq key       │ │ Proof        live orb after grant │ │
│               │ │ ○ MiniMax · opt  │ │ ───────────────────────────────── │ │
│               │ │ ○ Hotkeys        │ │ [Back]  [Grant Microphone]  [Con… │ │
│               │ │ ○ Practice       │ └───────────────────────────────────┘ │
│               │ └──────────────────┘                                       │
└───────────────┴────────────────────────────────────────────────────────────┘
```

**Mobile @390** — design intent; the probe measures 1280 / 1440 / 1920 only.

```
┌──────────────────────────┐         ┌──────────────────────────┐
│ ☰  Setup wizard      ⌕   │         │ ‹ Back  Let Parley hear… │
├──────────────────────────┤         ├──────────────────────────┤
│ ┌──────────────────────┐ │    ──▶  │ ┌──────────────────────┐ │
│ │ ● Microphone         │ │         │ │ Let Parley hear you …│ │
│ │ ○ Accessibility      │ │         │ │ Grant the mic, watch…│ │
│ │ ○ Groq key           │ │         │ │ ──────────────────── │ │
│ │ ○ MiniMax · opt      │ │         │ │ Status     ○ Missing │ │
│ │ ○ Hotkeys            │ │         │ │ Proof   live orb af… │ │
│ │ ○ Practice           │ │         │ │ ──────────────────── │ │
│ └──────────────────────┘ │         │ │ [Back]  [Grant Micr… │ │
│      [ Continue → ]      │         │ └──────────────────────┘ │
└──────────────────────────┘         └──────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ Mic already granted  │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ on an earlier run:   │   │ Grant dismissed or   │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ step shows Granted   │   │ failed: human line + │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ and offers Continue  │   │ “Open System         │
│                      │   │ at once.             │   │ Settings” retry;     │
│                      │   │                      │   │ nothing              │
│                      │   │ [ Continue → ]       │   │ auto-advances.       │
│                      │   │                      │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: Granted → badge flips, glow-settle + quiet chord, live orb level ~3 s, then auto-continues.

Held to:

- B1 — two or more top-level panels sharing a top edge
- B2 — no panel scrolls; PageShell owns the single scroll region

### Wizard · Accessibility · `settings.html · wizard 2/6`

Archetype: `form` — Guide the System Settings round-trip; polling finishes the step by itself.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│ ▨ Parley      ⌕ Search…                                     ⌘K   ◐   ⬤     │
├───────────────┬────────────────────────────────────────────────────────────┤
│ Setup         │ Wizard · Accessibility                      [ Continue → ] │
│ Gesture       │                                                            │
│ General       │        ┌──────────────────────────────────────────┐        │
│ Wizard · Acce…│        │ Open what Parley needs            2 of 6 │        │
│               │        │ Accessibility sees keys + paste          │        │
│               │        │ ──────────────────────────────────────── │        │
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
│ ☰  Wizard · Accessib…⌕   │
├──────────────────────────┤
│ ┌──────────────────────┐ │
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
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ Already trusted:     │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ step shows Granted   │   │ Deep link missed its │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ and offers Continue  │   │ pane (macOS version  │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ at once.             │   │ drift): shows the    │
│                      │   │                      │   │ manual path Privacy  │
│                      │   │ [ Continue → ]       │   │ & Security →         │
│                      │   │                      │   │ Accessibility.       │
│                      │   │                      │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: The 2 s poll sees the grant → success beat → auto-continues.

Held to:

- B3 — a form archetype contains a real <form> element
- B3 — the form column stays under 640px wide

### Wizard · Groq key · `settings.html · wizard 3/6`

Archetype: `form` — The one required key, tested before it is stored.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│ ▨ Parley      ⌕ Search…                                     ⌘K   ◐   ⬤     │
├───────────────┬────────────────────────────────────────────────────────────┤
│ Setup         │ Wizard · Groq key                        [ Test and save ] │
│ Gesture       │                                                            │
│ General       │        ┌──────────────────────────────────────────┐        │
│ Wizard · Groq…│        │ Add your Groq key                 3 of 6 │        │
│               │        │ Transcribes what you say                 │        │
│               │        │ ──────────────────────────────────────── │        │
│               │        │ Groq API key                       gsk_… │        │
│               │        │ Find it at         console.groq.com/keys │        │
│               │        │ ──────────────────────────────────────── │        │
│               │        │ [Back]  [Test and save]                  │        │
│               │        └──────────────────────────────────────────┘        │
└───────────────┴────────────────────────────────────────────────────────────┘
```

**Mobile @390** — design intent; the probe measures 1280 / 1440 / 1920 only.

```
┌──────────────────────────┐
│ ☰  Wizard · Groq key ⌕   │
├──────────────────────────┤
│ ┌──────────────────────┐ │
│ │ Groq API key   gsk_… │ │
│ │ Find it at    conso… │ │
│ │ ──────────────────── │ │
│ │ [Back]  [Test and s… │ │
│ └──────────────────────┘ │
│    [ Test and save ]     │
└──────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ Blank submit: inline │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ “Enter your Groq API │   │ Invalid key: its     │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ key”, focus stays in │   │ wording + console    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ the field.           │   │ link; nothing        │
│                      │   │                      │   │ stored. Twice in a   │
│                      │   │ [ Test and save ]    │   │ row adds the         │
│                      │   │                      │   │ where-to-find hint.  │
│                      │   │                      │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: “Key works” panel replaces the form (the key is never echoed), then Continue appears.

Held to:

- B3 — a form archetype contains a real <form> element
- B3 — the form column stays under 640px wide

### Wizard · MiniMax key · `settings.html · wizard 4/6`

Archetype: `form` — The optional key, framed as skippable from the first word.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│ ▨ Parley      ⌕ Search…                                     ⌘K   ◐   ⬤     │
├───────────────┬────────────────────────────────────────────────────────────┤
│ Setup         │ Wizard · MiniMax key                     [ Test and save ] │
│ Gesture       │                                                            │
│ General       │        ┌──────────────────────────────────────────┐        │
│ Wizard · Mini…│        │ Add MiniMax? (optional)           4 of 6 │        │
│               │        │ Only for voice edit + explain            │        │
│               │        │ ──────────────────────────────────────── │        │
│               │        │ MiniMax key                     optional │        │
│               │        │ ──────────────────────────────────────── │        │
│               │        │ [Back]  [Skip for now]  [Test and save]  │        │
│               │        └──────────────────────────────────────────┘        │
└───────────────┴────────────────────────────────────────────────────────────┘
```

**Mobile @390** — design intent; the probe measures 1280 / 1440 / 1920 only.

```
┌──────────────────────────┐
│ ☰  Wizard · MiniMax …⌕   │
├──────────────────────────┤
│ ┌──────────────────────┐ │
│ │ MiniMax key  option… │ │
│ │ ──────────────────── │ │
│ │ [Back]  [Skip for n… │ │
│ └──────────────────────┘ │
│    [ Test and save ]     │
└──────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ Skip jumps to        │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ hotkeys; the key can │   │ Invalid key: its     │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ be added later in    │   │ wording + retry;     │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ Setup.               │   │ Skip stays available │
│                      │   │                      │   │ throughout.          │
│                      │   │ [ Test and save ]    │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: “Key works” panel, then Continue. Skipped or saved, the step completes.

Held to:

- B3 — a form archetype contains a real <form> element
- B3 — the form column stays under 640px wide

### Wizard · Hotkeys · `settings.html · wizard 5/6`

Archetype: `form` — Keys are captured live, then proved with a tap-tap-hold practice meter.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│ ▨ Parley      ⌕ Search…                                     ⌘K   ◐   ⬤     │
├───────────────┬────────────────────────────────────────────────────────────┤
│ Setup         │ Wizard · Hotkeys                            [ Continue → ] │
│ Gesture       │                                                            │
│ General       │        ┌──────────────────────────────────────────┐        │
│ Wizard · Hotk…│        │ Choose your keys                  5 of 6 │        │
│               │        │ Tap, tap, hold the last press            │        │
│               │        │ ──────────────────────────────────────── │        │
│               │        │ Gesture key   [ Right Option ▾ ]         │        │
│               │        │ Presses                2  [3]  4         │        │
│               │        │ Voice edit   [ Right Command ▾ ]         │        │
│               │        │ Explain      [ Right Control ▾ ]         │        │
│               │        │ Practice          ○ ○ ○   hold ◌         │        │
│               │        │ ──────────────────────────────────────── │        │
│               │        │ [Back]  [Continue →]                     │        │
│               │        └──────────────────────────────────────────┘        │
└───────────────┴────────────────────────────────────────────────────────────┘
```

**Mobile @390** — design intent; the probe measures 1280 / 1440 / 1920 only.

```
┌──────────────────────────┐
│ ☰  Wizard · Hotkeys  ⌕   │
├──────────────────────────┤
│ ┌──────────────────────┐ │
│ │ Gesture key   [ Rig… │ │
│ │ Presses            … │ │
│ │ Voice edit   [ Righ… │ │
│ │ Explain      [ Righ… │ │
│ │ Practice          ○… │ │
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
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ A key equal to       │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ another reads Off    │   │ Capture hears a      │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ with the existing    │   │ non-modifier:        │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ hint — valid, not an │   │ “Modifiers only”     │
│                      │   │ error.               │   │ nudge, value         │
│                      │   │                      │   │ unchanged.           │
│                      │   │ [ Continue → ]       │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: Capture sets the key; practice dots fill per tap and the hold ring completes.

Held to:

- B3 — a form archetype contains a real <form> element
- B3 — the form column stays under 640px wide

### Wizard · Practice · `settings.html · wizard 6/6`

Archetype: `form` — First success: a real dictation landing in a sandbox that already has focus.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│ ▨ Parley      ⌕ Search…                                     ⌘K   ◐   ⬤     │
├───────────────┬────────────────────────────────────────────────────────────┤
│ Setup         │ Wizard · Practice                             [ Finish → ] │
│ Gesture       │                                                            │
│ General       │        ┌──────────────────────────────────────────┐        │
│ Wizard · Prac…│        │ Say your first sentence           6 of 6 │        │
│               │        │ A real dictation, landing here           │        │
│               │        │ ──────────────────────────────────────── │        │
│               │        │ sandbox:                                 │        │
│               │        │ “…speak now…”                            │        │
│               │        │ 1 hold your key · 2 speak · 3 release    │        │
│               │        │ ──────────────────────────────────────── │        │
│               │        │ [Back]  [Finish →]                       │        │
│               │        └──────────────────────────────────────────┘        │
└───────────────┴────────────────────────────────────────────────────────────┘
```

**Mobile @390** — design intent; the probe measures 1280 / 1440 / 1920 only.

```
┌──────────────────────────┐
│ ☰  Wizard · Practice ⌕   │
├──────────────────────────┤
│ ┌──────────────────────┐ │
│ │ sandbox:           … │ │
│ │ “…speak now…”      … │ │
│ │ 1 hold your key · 2… │ │
│ │ ──────────────────── │ │
│ │ [Back]  [Finish →]   │ │
│ └──────────────────────┘ │
│       [ Finish → ]       │
└──────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ Released with <300   │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ ms of audio: “Hold a │   │ Transcription        │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ little longer” and   │   │ failed: the orb      │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ the step stays.      │   │ wording (“No         │
│                      │   │                      │   │ connection”, …)      │
│                      │   │ [ Finish → ]         │   │ mirrored inline +    │
│                      │   │                      │   │ Try again.           │
│                      │   │                      │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: Text lands in the sandbox → teal flash + chord → Finish opens Done.

Held to:

- B3 — a form archetype contains a real <form> element
- B3 — the form column stays under 640px wide

### Ready · `settings.html · done`

Archetype: `centered-card` — The completion beat: what is configured, then the handoff to Settings.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│                                                                            │
│                   ┌──────────────────────────────────────┐                 │
│                   │ You're ready                         │                 │
│                   │ Parley is listening everywhere       │                 │
│                   │ ──────────────────────────────────── │                 │
│                   │ ✓ Microphone · ✓ Accessibility       │                 │
│                   │ ✓ Groq key · Right Option ×3         │                 │
│                   │ MiniMax skipped — add later in Setup │                 │
│                   │ ──────────────────────────────────── │                 │
│                   │ [Replay tour]  [Open Settings]       │                 │
│                   └──────────────────────────────────────┘                 │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

**Mobile @390** — design intent; the probe measures 1280 / 1440 / 1920 only.

```
┌──────────────────────────┐
│ ☰  Ready             ⌕   │
├──────────────────────────┤
│ ┌──────────────────────┐ │
│ │ ✓ Microphone · ✓ Ac… │ │
│ │ ✓ Groq key · Right … │ │
│ │ MiniMax skipped — a… │ │
│ │ ──────────────────── │ │
│ │ [Replay tour]  [Ope… │ │
│ └──────────────────────┘ │
│    [ Open Settings ]     │
└──────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ MiniMax skipped: the │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ row says so with a   │   │ A permission revoked │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ Setup pointer (not   │   │ since step 1: that   │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ an error).           │   │ row re-opens its     │
│                      │   │                      │   │ step instead of      │
│                      │   │ [ Open Settings ]    │   │ failing.             │
│                      │   │                      │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: Open Settings morphs to the 3-tab shell with the Ready badge + one-time banner.

Held to:

- B3 — the card is centred on both axes and stays under 480px wide

## Components

Each choice states the neighbour it beat. `Use when:` / `Instead:` for every
component family lives in `.claude/skills/use-mantine/mantine-capabilities.md`;
the choices between families live in
`docs/principles/component-selection.md`.

| Surface | Control | Why this one | Not |
| --- | --- | --- | --- |
| tour | `Carousel (no autoplay)` | 4 peer slides, each skippable, missing one costs nothing; manual + dots + Skip | `Stepper` |
| tour | `OrbCanvas + bands (reuse)` | the slide-1 loop must move like the real orb, not a drawing of it | `static SVG` |
| wizard | `Stepper, vertical, allowNextStepsSelect=false` | a sequence with real prerequisites — the capability map's onboarding row verbatim | `Tabs` |
| wizard | `Progress + “Step N of 6”` | a known fraction; the map fails a bar with no nearby number | `dots alone` |
| wizard-groq, wizard-minimax | `PasswordInput + RHF/zod` | a secret with a labeled reveal; the existing SetupTab pattern | `TextInput type=password` |
| wizard-hotkeys | `Kbd` | keys the user presses; the token background reads as pressable | `Text monospace` |
| wizard-hotkeys | `Select` | 8 fixed modifier keys (map: five to ten); the rows GestureTab already mounts | `Radio.Group` |
| wizard-hotkeys | `SegmentedControl` | 3 short options applied immediately; also dodges Select's jsdom cost | `Select` |
| wizard | `Badge` | Granted/Missing status; the word carries meaning and color only reinforces | `colored dot` |
| wizard | `Alert (title + icon + role=alert)` | standing failures with retry; a toast leaves too fast for slow readers | `notifications` |
| wizard | `Skeleton / Loader` | skeleton where the shape is known (pane), Loader only for the busy key-test button | `spinner everywhere` |
| wizard-practice | `Textarea sandbox` | a real dictation target with focus already inside it | `mock transcript` |
| all | `motion lib (SPRING/EASE/DURATION)` | interruption-safe springs on one token set with reduced-motion paths | `Mantine Transition` |

## Data model

- **OnboardingState**
  - `tourSeen`: boolean — tour never auto-shows twice; Replay resets this only
  - `wizardStep`: 0..6 — resume index; Done is the only exit to completion
  - `onboardingComplete`: boolean — flips the stage to the 3-tab Settings
  - `schemaVersion`: number — first versioned settings field; v0 files migrate to v1 defaults
  - _relations:_ lives in settings.json FileShape beside Settings; sanitized + migrated in settings-store

## Integration points

```
  electron/settings-store.ts    ──▶  schemaVersion + migrate() + sanitize the new fields   (old files load as v0, gain v1 defaults)
  electron/types.ts             ──▶  Settings gains tourSeen/wizardStep/onboardingComplete; schemaVersion stays envelope-only   (SettingsView inherits them)
  src/settings/SettingsApp.tsx  ──▶  stage switch   (!tourSeen → Tour, !onboardingComplete → Wizard(step), else the shell)
  usePermissions (2 s poll)     ──▶  grant auto-advance   (600 ms success beat first — the reward, not the delay)
  src/settings/GestureTab.tsx   ──▶  embedded in HotkeysStep   (settings + onChange passthrough, plus the practice meter below)
  src/orb/OrbCanvas + bands     ──▶  mic proof + tour-1 loop   (one live instance at a time; loops stop offscreen)
  src/lib/motion.ts             ──▶  pane slides, stagger, glow-settle, hold ring   (no new tokens; reduced-motion paths already exist)
  src/settings/GeneralTab.tsx   ──▶  “Replay tour” link   (resets tourSeen only)
  tray isReady                  ──▶  unchanged (mic + a11y + key)   (Ready badge flips on completion)
  docs/MANUAL_CHECKLIST.md      ──▶  clean-state walk deltas   (tour skip/replay, resume-after-quit, reduced motion)
```

## Blast radius

```
new (11)
  ├── src/settings/tour/Tour.tsx
  ├── src/settings/tour/illustrations.tsx
  ├── src/settings/tour/illustrations.module.css
  ├── src/settings/Tour.stories.tsx
  ├── src/settings/wizard/WizardShell.tsx
  ├── src/settings/wizard/steps.tsx
  ├── src/settings/wizard/stage.ts
  ├── src/settings/wizard/useOnboarding.ts
  ├── src/settings/Wizard.stories.tsx
  ├── src/settings/gesture-keys.ts
  └── src/settings/__tests__/onboarding.test.tsx

changed (12)
  ├── electron/types.ts
  ├── electron/settings-store.ts
  ├── electron/__tests__/settings-store.test.ts
  ├── src/settings/SettingsApp.tsx
  ├── src/settings/GestureTab.tsx
  ├── src/settings/GeneralTab.tsx
  ├── src/settings/SetupTab.tsx
  ├── src/settings/__tests__/SettingsApp.test.tsx
  ├── src/settings/__tests__/SettingsShell.test.tsx
  ├── docs/storybook-taxonomy.json
  ├── docs/MANUAL_CHECKLIST.md
  └── feature_list.json
```

## Verification plan

- [ ] `make type-check`
- [ ] `make lint`
- [ ] `make ui-lint`
- [ ] `npm run test -- src/settings/__tests__/onboarding.test.tsx`
- [ ] `npm run ui-probe`
- [ ] `Manual: fresh userData walks tour → wizard → settings without touching tabs`
- [ ] `Manual: quit mid-wizard resumes at the saved step; Replay tour never auto-shows`
- [ ] `Manual: Reduce Motion + keyboard-only pass of every step`
- [ ] `ux-prepass` — all seven boxes, `npm run ui-lint` green is the evidence for item 7

---

Approve this before any file is written. Every diagram above is rendered
from this feature's plan JSON, so the drawing and the build cannot drift;
the archetype frames are the same shapes `ui-probe` rules B1-B4 assert
against the real DOM once the screens exist.
