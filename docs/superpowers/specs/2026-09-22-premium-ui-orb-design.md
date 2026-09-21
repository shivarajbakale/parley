# Premium UI and Orb Redesign

Date: 2026-09-22
Status: implemented

## Goal

Make the two surfaces a Parley user actually sees, the floating orb and the
settings window, look and feel like a premium product: a lit, fluid,
voice-reactive orb in the spirit of Siri, and a dark glass settings window with
seamless spring-based motion.

## Scope

In scope:

- The orb window (`src/orb/`, `orb.html`, orb window options in `electron/`).
- The settings window (`src/settings/`, settings window options in `electron/`).
- Shared design and motion tokens (`src/theme.ts`, `src/App.css`).

Out of scope:

- The template scaffold under `src/components`, `src/pages`, `src/router`,
  `src/api` (sidebar, data table, auth, pages). Untouched.
- Any change to recording, transcription, injection, or gesture behaviour.
- Replacing Mantine. It stays and is restyled through the theme and CSS modules.

## Decisions

| Decision | Choice | Reason |
| --- | --- | --- |
| Orb renderer | Raw WebGL fragment shader, no three.js | Real lighting feel, no new dependency, cheap at this canvas size |
| Animation library | `motion` (Framer Motion) for React UI only | Layout animations and springs; the orb's per-frame audio loop stays on `requestAnimationFrame` |
| Visual direction | Solid tinted dark with single-hue accents | One indigo-violet hue at three depths, shared by orb and UI so both windows read as one product. Amended after first look: the violet, cyan, pink family read as a rainbow and was dropped. Light theme remains, secondary |
| Component library | Keep Mantine | `ui-lint` and existing tests depend on it |

## 1. Orb

### Why it looks bouncy today

`Orb.tsx` draws one flat circle whose radius is `BASE_RADIUS + level * 30`,
where `level` is the raw RMS of the current audio buffer. Unsmoothed RMS mapped
straight to size produces the bounce. The fix is twofold: smooth the signal,
and express voice energy as light and flow rather than size.

### Audio signal

- `src/orb/envelope.ts` (new, pure): an attack/release envelope follower.
  Attack about 40 ms, release about 350 ms, time-step aware so it is frame-rate
  independent. API: `createEnvelope({ attackMs, releaseMs })` returning
  `next(input: number, deltaMs: number): number`.
- `src/orb/bands.ts` (new, pure): `bandsFromSpectrum(spectrum: Uint8Array,
  sampleRate: number)` returning `{ low, mid, high }`, each 0..1. Bands: low
  up to 250 Hz, mid 250 Hz to 2 kHz, high 2 kHz to 8 kHz.
- `src/orb/recorder.ts` gains `bands()` alongside the existing `level()`, fed
  by `AnalyserNode.getByteFrequencyData`. Each band passes through its own
  envelope before reaching the shader.

### Shader

`src/orb/orb-shader.ts` (new) owns the WebGL context, program, one fullscreen
quad, and a `render(uniforms)` function. `dispose()` releases GL resources.

Fragment shader layers, back to front:

1. Circular mask with a soft edge. Alpha reaches zero before the canvas edge so
   the transparent Electron window never shows a clipped glow.
2. Three to four colour lobes positioned by domain-warped simplex noise,
   blended additively, using the aurora palette.
3. Fake sphere lighting: a normal derived from radial distance, a slowly moving
   specular highlight, and a fresnel rim glow. This is the lit-glass effect.
4. Outer bloom falloff.

Uniforms:

| Uniform | Drives |
| --- | --- |
| `uFlow` | Noise flow position, integrated on the CPU so speed changes never make the field jump |
| `uLow` | Lobe displacement, and the only source of size change |
| `uMid` | Flow speed (folded into `uFlow` on the CPU) |
| `uHigh` | Shimmer and rim intensity |
| `uFrom`, `uTo`, `uMix` | Crossfade between phase looks |
| `uAurora[3]`, `uDone`, `uError` | Colours, read from CSS tokens |
| `uCalm` | Set under reduced motion: slows flow, disables shimmer |

Size stays near constant: at most a 6 percent swell, driven by the smoothed
low band only.

### Phases

| Phase | Look |
| --- | --- |
| listening | Voice-reactive aurora |
| transcribing | Slow inward swirl, no audio input, slightly dimmed |
| done | Teal bloom, then fade out |
| error | Desaturate to red, one slow pulse; error message stays below the orb |

Phase changes crossfade over 300 ms through `uMix`. No hard cuts.
`src/orb/phase-mix.ts` (new, pure) tracks from, to, and mix given phase events
and elapsed time.

### Component and window

- `Orb.tsx` reduces to wiring: phase handler, recorder, rAF loop, uniform feed.
  The Canvas 2D `draw()` is removed.
- Fallback: if `getContext('webgl')` returns null, render the existing simple
  2D circle so the orb never disappears.
- Palette is read from CSS custom properties once at init (and on theme
  change), converted to linear RGB floats in `src/orb/palette.ts` (new, pure).
  No colour literals, so `ui-lint` stays green.
- The orb window grows from 220 px to 260 px and the canvas from 180 px to
  240 px, to give the glow room. The canvas is rendered at `devicePixelRatio`
  for crispness.
- Appear and dismiss use `motion`: scale 0.85 to 1 with opacity, on the shared
  spring. This replaces the current 120 ms CSS opacity transition.

## 2. Tokens

In `src/theme.ts` and `src/App.css`:

- Aurora colours: one indigo-violet hue at three depths (deep, core, glow),
  exposed as CSS custom properties and one gradient token. The settings window
  background is a solid tint of the same hue (`--app-tint-bg`).
- Surfaces: near-black base; glass panel (translucent fill, 1 px light border,
  backdrop blur); elevated glass for hover.
- Motion: one spring preset (stiffness 380, damping 30), one ease curve, and
  three durations (150, 250, 400 ms), exported from `src/lib/motion.ts` (new).
  Every animation uses these; no ad hoc values.
- The settings `BrowserWindow` gets `vibrancy: 'under-window'` and a
  transparent background on macOS so the glass is real system blur. Other
  platforms fall back to a solid dark surface.

Gradient discipline: the aurora gradient appears only on the orb, primary
buttons, the active tab pill, and the focus ring.

## 3. Settings window

### Structure

Split the 317-line `SettingsApp.tsx`:

- `SettingsShell.tsx`: window frame, rail plus content layout, tab state.
- `TabRail.tsx`: name, mini orb, status line, tabs.
- `SetupTab.tsx`, `GestureTab.tsx`, `GeneralTab.tsx`: one per tab.
- `SettingsApp.tsx` remains as the thin entry that composes them.

Behaviour and the `use-parley.ts` data flow are unchanged.

### Motion

- Active tab pill slides between tabs using a shared `layoutId`.
- Tab content crossfades with an 8 px slide through `AnimatePresence`,
  direction-aware (down the rail slides up, and the reverse).
- Cards stagger in 40 ms apart when a tab opens.
- Buttons and switches: spring press to scale 0.97; hover adds a gradient
  sheen.
- Status line change from "Setup needed" to "Ready": colour morph plus a check
  mark that draws on.
- When a permission becomes granted, its row glows aurora once and settles.
- A 48 px idle instance of the orb shader sits in the rail header.

### Reduced motion

With `prefers-reduced-motion`, all UI motion collapses to opacity fades, and
the orb sets `uCalm` to slow flow and drop shimmer.

## 4. Testing

- Unit tests, written first: `envelope`, `bands`, `palette`, `phase-mix`.
- Existing suites stay green: settings tab selection, a11y, recorder, phase
  handler. `electron/__tests__/windows.test.ts` assertions are updated for the
  260 px orb window and the vibrancy option.
- The shader itself is judged by eye through a Storybook story that feeds it
  synthetic signals (silence, sine sweep, speech-like envelope) and lets the
  phase be switched. No pixel tests.
- In jsdom, WebGL is unavailable, so component tests exercise the fallback
  path and the wiring.
- `make check` must pass at the end.

## Risks

- Transparent window plus additive glow can clip at the window edge. Mitigated
  by the mask reaching zero alpha inside the canvas and the larger window.
- Vibrancy with a transparent background can flash on window show. Mitigate
  with `show: false` and showing on `ready-to-show`.
- Continuous rAF in a hidden orb window wastes power. The loop runs only while
  the orb is visible.

## Build order

1. Tokens and motion presets.
2. Orb audio math (`envelope`, `bands`, `palette`, `phase-mix`, `frame`).
3. Shader, Storybook story, `Orb.tsx` rewire, window size.
4. Settings split into components, no visual change.
5. Glass restyle and vibrancy.
6. Motion layer.
7. Polish pass and `make check`.
