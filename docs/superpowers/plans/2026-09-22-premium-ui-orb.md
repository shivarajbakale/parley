# Premium UI and Orb Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Parley's flat bouncing orb with a lit, fluid, voice-reactive WebGL orb, and restyle the settings window as dark glass with spring-based motion.

**Architecture:** Pure, unit-tested math (`envelope`, `bands`, `palette`, `phase-mix`, `frame`) turns microphone data into shader uniforms. One raw-WebGL renderer (`orb-shader.ts`) draws them, wrapped by a reusable `OrbCanvas` React component used by both the orb window and the settings rail. The settings window is split into focused components, restyled through theme tokens, then animated with the `motion` package.

**Tech Stack:** React 19, Mantine 9, Electron, Vite, Vitest + Testing Library (jsdom), Storybook 9, raw WebGL 1 (GLSL ES 1.0), `motion` (Framer Motion).

**Spec:** `docs/superpowers/specs/2026-09-22-premium-ui-orb-design.md`

## Global Constraints

- Work on branch `premium-ui-orb`. Commit after every task.
- No colour literals (`#hex`, `rgb(`, `oklch(`) in any `.tsx` file or story: `ui-lint` and `storybook-lint` R7 fail on them. Colours are tokens. New tokens are `--app-*` custom properties declared in `cssVariablesResolver` in `src/theme.ts` (a `.ts` file, where `oklch()` literals are the existing convention).
- No utility classes. Layout uses Mantine components and style props; custom styling goes in `*.module.css`.
- Mantine stays. Do not add another component library. The only new dependency is `motion`.
- Do not touch `src/components`, `src/pages`, `src/router`, `src/api`, or any recording, transcription, injection, or gesture behaviour.
- `focusable: false` on the orb window must never change.
- All animation values come from `src/lib/motion.ts`. Spring: stiffness 380, damping 30. Durations: 150, 250, 400 ms.
- Orb size change is at most 6 percent, driven by the smoothed low band only.
- Phase crossfade is 300 ms.
- Envelope: attack 40 ms, release 350 ms.
- Bands: low up to 250 Hz, mid 250 Hz to 2 kHz, high 2 kHz to 8 kHz.
- Orb window 260 px square, orb canvas 240 px square, mini orb 48 px.
- The aurora gradient appears only on: the orb, primary buttons, the active tab pill, the focus ring.
- `prefers-reduced-motion` must collapse UI motion to opacity fades and calm the orb.
- Final gate: `make check` exits 0.
- Test commands run from the repo root. Single file: `npx vitest run <path>`.

## File Structure

| File | Responsibility |
| --- | --- |
| `src/lib/motion.ts` (new) | Spring, ease, and duration presets |
| `src/theme.ts` (modify) | Aurora and glass `--app-*` tokens |
| `src/orb/envelope.ts` (new) | Attack/release follower |
| `src/orb/bands.ts` (new) | Spectrum to low/mid/high |
| `src/orb/palette.ts` (new) | sRGB bytes to linear floats; CSS token sampling |
| `src/orb/phase-mix.ts` (new) | From/to/mix crossfade state |
| `src/orb/frame.ts` (new) | Combines the above into per-frame uniforms |
| `src/orb/recorder.ts` (modify) | Adds `bands()` |
| `src/orb/orb-shader.ts` (new) | WebGL program and `render(uniforms)` |
| `src/orb/OrbCanvas.tsx` (new) | Canvas, rAF loop, WebGL or 2D fallback |
| `src/orb/OrbCanvas.stories.tsx` (new) | Visual check with synthetic audio |
| `src/orb/Orb.tsx` (modify) | Wiring only; `motion` appear and dismiss |
| `electron/windows.ts` (modify) | 260 px orb window; vibrancy for settings |
| `src/settings/SettingsShell.tsx`, `TabRail.tsx`, `SetupTab.tsx`, `GestureTab.tsx`, `GeneralTab.tsx`, `SettingRow.tsx` (new) | Settings split |
| `src/settings/settings.module.css` (new) | Glass, pill, sheen, glow styles |

---

### Task 1: Motion presets and design tokens

**Files:**
- Create: `src/lib/motion.ts`, `src/lib/__tests__/motion.test.ts`
- Modify: `src/theme.ts` (the `cssVariablesResolver` at the bottom), `package.json`, `src/test/setup.ts`

**Interfaces:**
- Produces: `SPRING`, `EASE`, `DURATION` from `@/lib/motion`; CSS custom properties `--app-aurora-violet`, `--app-aurora-cyan`, `--app-aurora-pink`, `--app-aurora-gradient`, `--app-glass`, `--app-glass-hover`, `--app-glass-border`.

- [ ] **Step 1: Install motion**

Run: `npm install motion`
Expected: `motion` appears under `dependencies` in `package.json`.

- [ ] **Step 2: Write the failing test**

`src/lib/__tests__/motion.test.ts`:

```ts
import { describe, expect, it } from 'vitest';

import { DURATION, EASE, SPRING } from '../motion';

describe('motion presets', () => {
  it('exposes the one spring the whole app uses', () => {
    expect(SPRING).toEqual({ type: 'spring', stiffness: 380, damping: 30 });
  });

  it('exposes three durations in seconds', () => {
    expect(DURATION).toEqual({ fast: 0.15, base: 0.25, slow: 0.4 });
  });

  it('exposes a four-point cubic bezier', () => {
    expect(EASE).toHaveLength(4);
  });
});
```

- [ ] **Step 3: Run test to verify it fails**

Run: `npx vitest run src/lib/__tests__/motion.test.ts`
Expected: FAIL, cannot resolve `../motion`.

- [ ] **Step 4: Implement**

`src/lib/motion.ts`:

```ts
/**
 * The only animation values in the app. Every `motion` component reads these,
 * so the whole product moves with one character.
 */
export const SPRING = { type: 'spring', stiffness: 380, damping: 30 } as const;

/** Decelerating curve for opacity and colour, where a spring would overshoot. */
export const EASE = [0.22, 1, 0.36, 1] as const;

/** Seconds, because that is what `motion` takes. */
export const DURATION = { fast: 0.15, base: 0.25, slow: 0.4 } as const;

/** Delay between siblings in a staggered entrance, in seconds. */
export const STAGGER = 0.04;
```

- [ ] **Step 5: Add the tokens**

In `src/theme.ts`, replace the body of `cssVariablesResolver` so both schemes gain the new tokens. Keep every existing entry.

```ts
const aurora = {
  '--app-aurora-violet': 'oklch(0.62 0.22 295)',
  '--app-aurora-cyan': 'oklch(0.78 0.14 210)',
  '--app-aurora-pink': 'oklch(0.72 0.2 350)',
  '--app-aurora-gradient':
    'linear-gradient(120deg, var(--app-aurora-violet), var(--app-aurora-cyan) 55%, var(--app-aurora-pink))',
};

export const cssVariablesResolver: CSSVariablesResolver = t => ({
  variables: aurora,
  light: {
    '--app-surface': t.white,
    '--app-control': t.colors.gray[1],
    '--app-glass': 'color-mix(in oklab, white 72%, transparent)',
    '--app-glass-hover': 'color-mix(in oklab, white 86%, transparent)',
    '--app-glass-border': 'color-mix(in oklab, black 10%, transparent)',
  },
  dark: {
    '--mantine-color-body': t.colors.dark[8],
    '--mantine-color-dimmed': t.colors.dark[3],
    '--app-surface': t.colors.dark[7],
    '--app-control': t.colors.dark[6],
    '--app-glass': 'color-mix(in oklab, white 6%, transparent)',
    '--app-glass-hover': 'color-mix(in oklab, white 10%, transparent)',
    '--app-glass-border': 'color-mix(in oklab, white 12%, transparent)',
  },
});
```

Preserve the existing comments above and inside the resolver; extend the doc comment to say the aurora and glass tokens are also declared here.

- [ ] **Step 6: Make animations instant in tests**

Append to `src/test/setup.ts`:

```ts
import { MotionGlobalConfig } from 'motion/react';

// Tests assert on end states; an exit animation only adds flake.
MotionGlobalConfig.skipAnimations = true;
```

- [ ] **Step 7: Run tests**

Run: `npx vitest run src/lib src/test`
Expected: PASS, including `css-tokens.test.ts`.

- [ ] **Step 8: Commit**

```bash
git add package.json package-lock.json src/lib/motion.ts src/lib/__tests__/motion.test.ts src/theme.ts src/test/setup.ts
git commit -m "feat: motion presets and aurora/glass tokens"
```

---

### Task 2: Envelope follower

**Files:**
- Create: `src/orb/envelope.ts`, `src/orb/__tests__/envelope.test.ts`

**Interfaces:**
- Produces: `createEnvelope(options: { attackMs: number; releaseMs: number }): Envelope` where `Envelope = { next(input: number, deltaMs: number): number; reset(): void }`.

- [ ] **Step 1: Write the failing test**

```ts
import { describe, expect, it } from 'vitest';

import { createEnvelope } from '../envelope';

const make = () => createEnvelope({ attackMs: 40, releaseMs: 350 });

describe('createEnvelope', () => {
  it('starts at zero', () => {
    expect(make().next(0, 16)).toBe(0);
  });

  it('reaches about 63 percent of a step input after one attack time', () => {
    expect(make().next(1, 40)).toBeCloseTo(1 - Math.exp(-1), 5);
  });

  it('falls much more slowly than it rises', () => {
    const envelope = make();
    envelope.next(1, 1000);
    const afterRelease = envelope.next(0, 40);
    expect(afterRelease).toBeGreaterThan(0.85);
  });

  it('is frame-rate independent', () => {
    const oneStep = make().next(1, 32);
    const twoSteps = make();
    twoSteps.next(1, 16);
    expect(twoSteps.next(1, 16)).toBeCloseTo(oneStep, 10);
  });

  it('ignores a zero or negative time step', () => {
    const envelope = make();
    envelope.next(1, 40);
    const before = envelope.next(1, 0);
    expect(envelope.next(0, -5)).toBe(before);
  });

  it('resets to zero', () => {
    const envelope = make();
    envelope.next(1, 500);
    envelope.reset();
    expect(envelope.next(0, 16)).toBe(0);
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run src/orb/__tests__/envelope.test.ts`
Expected: FAIL, cannot resolve `../envelope`.

- [ ] **Step 3: Implement**

```ts
/**
 * Attack/release envelope follower. Raw voice level jitters every buffer, and
 * anything drawn straight from it bounces. This rises fast, falls slowly, and
 * uses the real time step so it behaves the same at 60 and 120 Hz.
 */
export interface Envelope {
  next(input: number, deltaMs: number): number;
  reset(): void;
}

export function createEnvelope({
  attackMs,
  releaseMs,
}: {
  attackMs: number;
  releaseMs: number;
}): Envelope {
  let value = 0;
  return {
    next(input, deltaMs) {
      if (deltaMs <= 0) return value;
      const timeConstant = input > value ? attackMs : releaseMs;
      value += (input - value) * (1 - Math.exp(-deltaMs / timeConstant));
      return value;
    },
    reset() {
      value = 0;
    },
  };
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `npx vitest run src/orb/__tests__/envelope.test.ts`
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add src/orb/envelope.ts src/orb/__tests__/envelope.test.ts
git commit -m "feat: attack/release envelope for the orb signal"
```

---

### Task 3: Frequency bands and recorder.bands()

**Files:**
- Create: `src/orb/bands.ts`, `src/orb/__tests__/bands.test.ts`
- Modify: `src/orb/recorder.ts`, `src/orb/__tests__/recorder.test.ts`

**Interfaces:**
- Produces: `type Bands = { low: number; mid: number; high: number }`, `SILENT_BANDS: Bands`, `bandsFromSpectrum(spectrum: Uint8Array, sampleRate: number): Bands`, and `Recorder.bands(): Bands`.

- [ ] **Step 1: Write the failing bands test**

```ts
import { describe, expect, it } from 'vitest';

import { bandsFromSpectrum, SILENT_BANDS } from '../bands';

/** 256 bins at 48 kHz: each bin spans 93.75 Hz. */
const SAMPLE_RATE = 48000;
const BINS = 256;

function spectrumWith(fromHz: number, toHz: number, value: number) {
  const spectrum = new Uint8Array(BINS);
  const hzPerBin = SAMPLE_RATE / 2 / BINS;
  for (let bin = 0; bin < BINS; bin++) {
    const hz = bin * hzPerBin;
    if (hz >= fromHz && hz < toHz) spectrum[bin] = value;
  }
  return spectrum;
}

describe('bandsFromSpectrum', () => {
  it('is silent for an empty or all-zero spectrum', () => {
    expect(bandsFromSpectrum(new Uint8Array(0), SAMPLE_RATE)).toEqual(SILENT_BANDS);
    expect(bandsFromSpectrum(new Uint8Array(BINS), SAMPLE_RATE)).toEqual(SILENT_BANDS);
  });

  it('puts energy below 250 Hz in low only', () => {
    const bands = bandsFromSpectrum(spectrumWith(0, 250, 255), SAMPLE_RATE);
    expect(bands.low).toBeGreaterThan(0.9);
    expect(bands.mid).toBe(0);
    expect(bands.high).toBe(0);
  });

  it('puts energy between 250 Hz and 2 kHz in mid only', () => {
    const bands = bandsFromSpectrum(spectrumWith(250, 2000, 255), SAMPLE_RATE);
    expect(bands.low).toBe(0);
    expect(bands.mid).toBeGreaterThan(0.9);
    expect(bands.high).toBe(0);
  });

  it('puts energy between 2 kHz and 8 kHz in high only, and ignores everything above', () => {
    expect(bandsFromSpectrum(spectrumWith(2000, 8000, 255), SAMPLE_RATE).high).toBeGreaterThan(0.9);
    expect(bandsFromSpectrum(spectrumWith(8000, 24000, 255), SAMPLE_RATE)).toEqual(SILENT_BANDS);
  });

  it('clamps to 1', () => {
    const bands = bandsFromSpectrum(new Uint8Array(BINS).fill(255), SAMPLE_RATE);
    expect(bands).toEqual({ low: 1, mid: 1, high: 1 });
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run src/orb/__tests__/bands.test.ts`
Expected: FAIL, cannot resolve `../bands`.

- [ ] **Step 3: Implement bands**

```ts
/**
 * Three voice bands from an `AnalyserNode.getByteFrequencyData` buffer. Low
 * moves the orb's body, mid sets how fast it flows, high adds shimmer.
 */
export interface Bands {
  low: number;
  mid: number;
  high: number;
}

export const SILENT_BANDS: Bands = { low: 0, mid: 0, high: 0 };

const LOW_MAX_HZ = 250;
const MID_MAX_HZ = 2000;
const HIGH_MAX_HZ = 8000;

/** Speech carries less energy the higher you go; these even the bands out. */
const GAIN = { low: 1.4, mid: 1.8, high: 2.6 };

export function bandsFromSpectrum(spectrum: Uint8Array, sampleRate: number): Bands {
  if (spectrum.length === 0) return SILENT_BANDS;
  const hzPerBin = sampleRate / 2 / spectrum.length;
  const sums = { low: 0, mid: 0, high: 0 };
  const counts = { low: 0, mid: 0, high: 0 };

  for (let bin = 0; bin < spectrum.length; bin++) {
    const hz = bin * hzPerBin;
    if (hz >= HIGH_MAX_HZ) break;
    const band = hz < LOW_MAX_HZ ? 'low' : hz < MID_MAX_HZ ? 'mid' : 'high';
    sums[band] += spectrum[bin];
    counts[band]++;
  }

  const scale = (band: keyof Bands) =>
    counts[band] === 0 ? 0 : Math.min(1, (sums[band] / counts[band] / 255) * GAIN[band]);
  return { low: scale('low'), mid: scale('mid'), high: scale('high') };
}
```

- [ ] **Step 4: Run to verify bands pass**

Run: `npx vitest run src/orb/__tests__/bands.test.ts`
Expected: PASS, 5 tests.

- [ ] **Step 5: Write the failing recorder test**

In `src/orb/__tests__/recorder.test.ts`, extend the two fakes and add a describe block at the end of the file:

```ts
class FakeAnalyser {
  fftSize = 0;
  frequencyBinCount = 256;
  getByteTimeDomainData() {}
  getByteFrequencyData(target: Uint8Array) {
    target.fill(255);
  }
}

class FakeAudioContext {
  sampleRate = 48000;
  close = vi.fn().mockResolvedValue(undefined);
  createAnalyser() {
    return new FakeAnalyser() as unknown as AnalyserNode;
  }
  createMediaStreamSource() {
    return { connect: vi.fn() };
  }
}
```

```ts
describe('createRecorder bands', () => {
  beforeEach(() => {
    vi.stubGlobal('navigator', {
      mediaDevices: { getUserMedia: vi.fn().mockResolvedValue(fakeStream([fakeTrack()])) },
    });
    vi.stubGlobal('AudioContext', FakeAudioContext);
    vi.stubGlobal('MediaRecorder', FakeMediaRecorder);
  });

  afterEach(() => vi.unstubAllGlobals());

  it('is silent before recording starts', () => {
    expect(createRecorder().bands()).toEqual({ low: 0, mid: 0, high: 0 });
  });

  it('reads the analyser spectrum while recording', async () => {
    const recorder = createRecorder();
    await recorder.start();
    expect(recorder.bands()).toEqual({ low: 1, mid: 1, high: 1 });
    recorder.discard();
  });
});
```

If the file already has an `afterEach` that unstubs globals at top level, reuse it rather than adding a second.

- [ ] **Step 6: Run to verify it fails**

Run: `npx vitest run src/orb/__tests__/recorder.test.ts`
Expected: FAIL, `recorder.bands is not a function`.

- [ ] **Step 7: Implement recorder.bands()**

In `src/orb/recorder.ts`:

1. Add the import: `import { bandsFromSpectrum, SILENT_BANDS, type Bands } from './bands';`
2. Add to the `Recorder` interface:

```ts
  /** Current low/mid/high voice energy, each 0 to 1. */
  bands(): Bands;
```

3. Beside `let samples = new Uint8Array(0);` add `let spectrum = new Uint8Array(0);`
4. In `start()`, after `samples = new Uint8Array(analyser.fftSize);` add `spectrum = new Uint8Array(analyser.frequencyBinCount);`
5. After the `level()` method add:

```ts
    bands() {
      if (!analyser || !audioContext) return SILENT_BANDS;
      analyser.getByteFrequencyData(spectrum);
      return bandsFromSpectrum(spectrum, audioContext.sampleRate);
    },
```

- [ ] **Step 8: Run to verify all pass**

Run: `npx vitest run src/orb`
Expected: PASS. If `phase-handler.test.ts` builds a `Recorder` fake and type-check complains, add `bands: () => ({ low: 0, mid: 0, high: 0 })` to that fake.

Run: `npm run type-check`
Expected: exit 0.

- [ ] **Step 9: Commit**

```bash
git add src/orb/bands.ts src/orb/recorder.ts src/orb/__tests__
git commit -m "feat: low/mid/high voice bands from the recorder"
```

---

### Task 4: Palette conversion

**Files:**
- Create: `src/orb/palette.ts`, `src/orb/__tests__/palette.test.ts`

**Interfaces:**
- Produces: `type Rgb = [number, number, number]`; `srgbByteToLinear(byte: number): number`; `type OrbPalette = { aurora: [Rgb, Rgb, Rgb]; done: Rgb; error: Rgb }`; `PALETTE_TOKENS`; `buildPalette(readBytes: (token: string) => Rgb): OrbPalette`; `readTokenBytes(token: string): Rgb` (DOM-only).

- [ ] **Step 1: Write the failing test**

```ts
import { describe, expect, it } from 'vitest';

import { buildPalette, PALETTE_TOKENS, srgbByteToLinear } from '../palette';

describe('srgbByteToLinear', () => {
  it('maps the ends of the range', () => {
    expect(srgbByteToLinear(0)).toBe(0);
    expect(srgbByteToLinear(255)).toBeCloseTo(1, 6);
  });

  it('applies the sRGB curve, not a straight divide', () => {
    expect(srgbByteToLinear(128)).toBeCloseTo(0.2158, 3);
  });
});

describe('buildPalette', () => {
  it('reads each token once and converts it to linear floats', () => {
    const seen: string[] = [];
    const palette = buildPalette((token) => {
      seen.push(token);
      return [255, 0, 128];
    });
    expect(seen).toEqual([...PALETTE_TOKENS.aurora, PALETTE_TOKENS.done, PALETTE_TOKENS.error]);
    expect(palette.aurora).toHaveLength(3);
    expect(palette.done[0]).toBeCloseTo(1, 6);
    expect(palette.done[1]).toBe(0);
    expect(palette.error[2]).toBeCloseTo(0.2158, 3);
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run src/orb/__tests__/palette.test.ts`
Expected: FAIL, cannot resolve `../palette`.

- [ ] **Step 3: Implement**

```ts
/**
 * The orb's colours come from theme tokens, never literals. Tokens are
 * `oklch()` strings, which a shader cannot use, so each one is painted onto a
 * 1 px canvas and read back as sRGB bytes, then converted to the linear floats
 * the shader blends in.
 */
export type Rgb = [number, number, number];

export interface OrbPalette {
  aurora: [Rgb, Rgb, Rgb];
  done: Rgb;
  error: Rgb;
}

export const PALETTE_TOKENS = {
  aurora: ['--app-aurora-violet', '--app-aurora-cyan', '--app-aurora-pink'],
  done: '--mantine-color-teal-5',
  error: '--mantine-color-red-6',
} as const;

export function srgbByteToLinear(byte: number): number {
  const channel = byte / 255;
  return channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4;
}

const toLinear = ([r, g, b]: Rgb): Rgb => [
  srgbByteToLinear(r),
  srgbByteToLinear(g),
  srgbByteToLinear(b),
];

export function buildPalette(readBytes: (token: string) => Rgb): OrbPalette {
  const [violet, cyan, pink] = PALETTE_TOKENS.aurora.map((token) => toLinear(readBytes(token)));
  return {
    aurora: [violet, cyan, pink],
    done: toLinear(readBytes(PALETTE_TOKENS.done)),
    error: toLinear(readBytes(PALETTE_TOKENS.error)),
  };
}

/** Browser only: resolves a CSS custom property to sRGB bytes. */
export function readTokenBytes(token: string): Rgb {
  const value = getComputedStyle(document.documentElement).getPropertyValue(token).trim();
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = 1;
  const context = canvas.getContext('2d', { willReadFrequently: true });
  if (!context || !value) return [255, 255, 255];
  context.fillStyle = value;
  context.fillRect(0, 0, 1, 1);
  const [r, g, b] = context.getImageData(0, 0, 1, 1).data;
  return [r, g, b];
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `npx vitest run src/orb/__tests__/palette.test.ts`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add src/orb/palette.ts src/orb/__tests__/palette.test.ts
git commit -m "feat: orb palette from theme tokens as linear RGB"
```

---

### Task 5: Phase mix and per-frame uniforms

**Files:**
- Create: `src/orb/phase-mix.ts`, `src/orb/frame.ts`, `src/orb/__tests__/phase-mix.test.ts`, `src/orb/__tests__/frame.test.ts`

**Interfaces:**
- Consumes: `createEnvelope` (Task 2), `Bands` (Task 3), `OrbPhase` from `electron/types`.
- Produces:
  - `PHASE_FADE_MS = 300`, `PHASE_INDEX: Record<OrbPhase, number>` (`cancelled: 0, listening: 1, transcribing: 2, done: 3, error: 4`), `createPhaseMix(initial: OrbPhase)` returning `{ set(phase: OrbPhase): void; advance(deltaMs: number): { from: OrbPhase; to: OrbPhase; mix: number } }`.
  - `type OrbUniforms = { flow: number; low: number; mid: number; high: number; from: number; to: number; mix: number; calm: number }`.
  - `type FrameInput = { deltaMs: number; bands: Bands; phase: OrbPhase; reducedMotion: boolean }`.
  - `createFrame(initial: OrbPhase): { step(input: FrameInput): OrbUniforms }`.

- [ ] **Step 1: Write the failing phase-mix test**

```ts
import { describe, expect, it } from 'vitest';

import { createPhaseMix, PHASE_FADE_MS } from '../phase-mix';

describe('createPhaseMix', () => {
  it('starts settled on the initial phase', () => {
    expect(createPhaseMix('cancelled').advance(16)).toEqual({
      from: 'cancelled',
      to: 'cancelled',
      mix: 1,
    });
  });

  it('fades linearly to a new phase over the fade time', () => {
    const phaseMix = createPhaseMix('cancelled');
    phaseMix.set('listening');
    expect(phaseMix.advance(PHASE_FADE_MS / 2)).toEqual({
      from: 'cancelled',
      to: 'listening',
      mix: 0.5,
    });
    expect(phaseMix.advance(PHASE_FADE_MS).mix).toBe(1);
  });

  it('ignores a repeat of the current target', () => {
    const phaseMix = createPhaseMix('cancelled');
    phaseMix.set('listening');
    phaseMix.advance(150);
    phaseMix.set('listening');
    expect(phaseMix.advance(0).mix).toBe(0.5);
  });

  it('fades on from the previous target when interrupted', () => {
    const phaseMix = createPhaseMix('cancelled');
    phaseMix.set('listening');
    phaseMix.advance(100);
    phaseMix.set('transcribing');
    expect(phaseMix.advance(0)).toEqual({ from: 'listening', to: 'transcribing', mix: 0 });
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run src/orb/__tests__/phase-mix.test.ts`
Expected: FAIL, cannot resolve `../phase-mix`.

- [ ] **Step 3: Implement phase-mix**

```ts
import type { OrbPhase } from '../../electron/types';

/** No hard cuts: every phase change crossfades in the shader over this long. */
export const PHASE_FADE_MS = 300;

/** What the shader receives. `cancelled` draws nothing. */
export const PHASE_INDEX: Record<OrbPhase, number> = {
  cancelled: 0,
  listening: 1,
  transcribing: 2,
  done: 3,
  error: 4,
};

export function createPhaseMix(initial: OrbPhase) {
  let from = initial;
  let to = initial;
  let mix = 1;
  return {
    set(phase: OrbPhase) {
      if (phase === to) return;
      from = to;
      to = phase;
      mix = 0;
    },
    advance(deltaMs: number) {
      mix = Math.min(1, mix + Math.max(0, deltaMs) / PHASE_FADE_MS);
      return { from, to, mix };
    },
  };
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `npx vitest run src/orb/__tests__/phase-mix.test.ts`
Expected: PASS, 4 tests.

- [ ] **Step 5: Write the failing frame test**

```ts
import { describe, expect, it } from 'vitest';

import { createFrame } from '../frame';

const LOUD = { low: 1, mid: 1, high: 1 };
const SILENT = { low: 0, mid: 0, high: 0 };

describe('createFrame', () => {
  it('smooths the bands instead of passing them straight through', () => {
    const frame = createFrame('listening');
    const first = frame.step({ deltaMs: 16, bands: LOUD, phase: 'listening', reducedMotion: false });
    expect(first.low).toBeGreaterThan(0);
    expect(first.low).toBeLessThan(0.5);
  });

  it('lets the bands fall slowly after the voice stops', () => {
    const frame = createFrame('listening');
    frame.step({ deltaMs: 1000, bands: LOUD, phase: 'listening', reducedMotion: false });
    const after = frame.step({ deltaMs: 16, bands: SILENT, phase: 'listening', reducedMotion: false });
    expect(after.low).toBeGreaterThan(0.9);
  });

  it('advances flow every frame and faster with mid energy, never backwards', () => {
    const quiet = createFrame('listening');
    const loud = createFrame('listening');
    const quietFlow = quiet.step({ deltaMs: 1000, bands: SILENT, phase: 'listening', reducedMotion: false }).flow;
    const loudFlow = loud.step({ deltaMs: 1000, bands: LOUD, phase: 'listening', reducedMotion: false }).flow;
    expect(quietFlow).toBeGreaterThan(0);
    expect(loudFlow).toBeGreaterThan(quietFlow);
  });

  it('slows flow and reports calm under reduced motion', () => {
    const normal = createFrame('listening');
    const reduced = createFrame('listening');
    const input = { deltaMs: 1000, bands: SILENT, phase: 'listening' as const };
    const normalStep = normal.step({ ...input, reducedMotion: false });
    const reducedStep = reduced.step({ ...input, reducedMotion: true });
    expect(reducedStep.flow).toBeLessThan(normalStep.flow);
    expect(reducedStep.calm).toBe(1);
    expect(normalStep.calm).toBe(0);
  });

  it('reports the phase crossfade as shader indices', () => {
    const frame = createFrame('cancelled');
    const step = frame.step({ deltaMs: 150, bands: SILENT, phase: 'listening', reducedMotion: false });
    expect(step).toMatchObject({ from: 0, to: 1, mix: 0.5 });
  });
});
```

- [ ] **Step 6: Run to verify it fails**

Run: `npx vitest run src/orb/__tests__/frame.test.ts`
Expected: FAIL, cannot resolve `../frame`.

- [ ] **Step 7: Implement frame**

```ts
import type { OrbPhase } from '../../electron/types';

import type { Bands } from './bands';
import { createEnvelope } from './envelope';
import { createPhaseMix, PHASE_INDEX } from './phase-mix';

/**
 * One frame of orb state. Everything that decides how the orb looks, short of
 * the pixels, happens here so it can be tested without a GPU.
 */
export interface OrbUniforms {
  flow: number;
  low: number;
  mid: number;
  high: number;
  from: number;
  to: number;
  mix: number;
  calm: number;
}

export interface FrameInput {
  deltaMs: number;
  bands: Bands;
  phase: OrbPhase;
  reducedMotion: boolean;
}

const ATTACK_MS = 40;
const RELEASE_MS = 350;

/** Flow units per second at rest, and how much full mid energy adds. */
const BASE_FLOW = 0.35;
const MID_FLOW = 0.9;
const CALM_FLOW_SCALE = 0.35;

export function createFrame(initial: OrbPhase) {
  const envelopes = {
    low: createEnvelope({ attackMs: ATTACK_MS, releaseMs: RELEASE_MS }),
    mid: createEnvelope({ attackMs: ATTACK_MS, releaseMs: RELEASE_MS }),
    high: createEnvelope({ attackMs: ATTACK_MS, releaseMs: RELEASE_MS }),
  };
  const phaseMix = createPhaseMix(initial);
  let flow = 0;

  return {
    step({ deltaMs, bands, phase, reducedMotion }: FrameInput): OrbUniforms {
      const low = envelopes.low.next(bands.low, deltaMs);
      const mid = envelopes.mid.next(bands.mid, deltaMs);
      const high = envelopes.high.next(bands.high, deltaMs);

      // Flow is integrated, never `time * speed`: multiplying would make the
      // whole field jump every time the speed changed.
      const speed = (BASE_FLOW + mid * MID_FLOW) * (reducedMotion ? CALM_FLOW_SCALE : 1);
      flow += (Math.max(0, deltaMs) / 1000) * speed;

      phaseMix.set(phase);
      const { from, to, mix } = phaseMix.advance(deltaMs);

      return {
        flow,
        low,
        mid,
        high,
        from: PHASE_INDEX[from],
        to: PHASE_INDEX[to],
        mix,
        calm: reducedMotion ? 1 : 0,
      };
    },
  };
}
```

- [ ] **Step 8: Run to verify all pass**

Run: `npx vitest run src/orb`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add src/orb/phase-mix.ts src/orb/frame.ts src/orb/__tests__/phase-mix.test.ts src/orb/__tests__/frame.test.ts
git commit -m "feat: phase crossfade and per-frame orb uniforms"
```

---

### Task 6: WebGL renderer, OrbCanvas, and the Storybook visual check

**Files:**
- Create: `src/orb/orb-shader.ts`, `src/orb/OrbCanvas.tsx`, `src/orb/OrbCanvas.stories.tsx`, `src/orb/__tests__/OrbCanvas.test.tsx`
- Modify: `docs/storybook-taxonomy.json`

**Interfaces:**
- Consumes: `OrbUniforms`, `createFrame`, `FrameInput` (Task 5); `OrbPalette`, `buildPalette`, `readTokenBytes` (Task 4); `Bands`.
- Produces:
  - `createOrbRenderer(canvas: HTMLCanvasElement, palette: OrbPalette): OrbRenderer | null` where `OrbRenderer = { render(uniforms: OrbUniforms): void; dispose(): void }`. Returns `null` when WebGL is unavailable.
  - `<OrbCanvas size={number} running={boolean} read={() => { bands: Bands; phase: OrbPhase }} />`.

- [ ] **Step 1: Write the renderer**

`src/orb/orb-shader.ts`:

```ts
import type { OrbUniforms } from './frame';
import type { OrbPalette } from './palette';

/**
 * The orb, drawn by one fragment shader on one fullscreen triangle pair.
 *
 * Voice energy is shown as light and flow, not size: `uLow` pushes the colour
 * lobes apart, `uHigh` brightens the rim and specular, and the radius moves at
 * most 6 percent. Output is premultiplied alpha, which is what a transparent
 * Electron window composites correctly.
 */

const VERTEX = `
attribute vec2 aPosition;
varying vec2 vUv;
void main() {
  vUv = aPosition;
  gl_Position = vec4(aPosition, 0.0, 1.0);
}`;

const FRAGMENT = `
precision highp float;
varying vec2 vUv;
uniform float uFlow, uLow, uMid, uHigh, uFrom, uTo, uMix, uCalm;
uniform vec3 uAurora[3];
uniform vec3 uDone;
uniform vec3 uError;

// 2D simplex noise, Ian McEwan / Ashima Arts, MIT licence.
vec3 permute(vec3 x) { return mod(((x * 34.0) + 1.0) * x, 289.0); }
float snoise(vec2 v) {
  const vec4 C = vec4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);
  vec2 i = floor(v + dot(v, C.yy));
  vec2 x0 = v - i + dot(i, C.xx);
  vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
  vec4 x12 = x0.xyxy + C.xxzz;
  x12.xy -= i1;
  i = mod(i, 289.0);
  vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0));
  vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
  m = m * m;
  m = m * m;
  vec3 x = 2.0 * fract(p * C.www) - 1.0;
  vec3 h = abs(x) - 0.5;
  vec3 ox = floor(x + 0.5);
  vec3 a0 = x - ox;
  m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
  vec3 g;
  g.x = a0.x * x0.x + h.x * x0.y;
  g.yz = a0.yz * x12.xz + h.yz * x12.yw;
  return 130.0 * dot(m, g);
}

mat2 rotate(float angle) {
  float s = sin(angle), c = cos(angle);
  return mat2(c, -s, s, c);
}

float isPhase(float phase, float index) {
  return step(index - 0.5, phase) * step(phase, index + 0.5);
}

// One phase's look, premultiplied. Phase 0 (cancelled) draws nothing.
vec4 look(float phase, vec2 uv) {
  if (phase < 0.5) return vec4(0.0);
  float listening = isPhase(phase, 1.0);
  float transcribing = isPhase(phase, 2.0);
  float done = isPhase(phase, 3.0);
  float failed = isPhase(phase, 4.0);

  float low = uLow * listening;
  float high = uHigh * listening;

  float edge = length(uv);
  float radius = 0.62 * (1.0 + 0.06 * low);

  // Transcribing: the field winds inward, tighter toward the centre.
  vec2 p = rotate(transcribing * (uFlow * 0.8 + (1.0 - edge) * 2.5)) * uv;
  vec2 q = p / radius;
  float r = length(q);

  vec2 warp = vec2(
    snoise(q * 1.3 + vec2(uFlow, 0.0)),
    snoise(q * 1.3 + vec2(7.3, uFlow))
  );
  vec2 w = q + warp * 0.35 * (1.0 + low * 1.2);

  vec3 colour = vec3(0.0);
  for (int i = 0; i < 3; i++) {
    float offset = float(i) * 2.094;
    vec2 centre = 0.45 * (0.6 + low * 0.8)
      * vec2(cos(uFlow * 0.7 + offset), sin(uFlow * 0.9 + offset));
    vec3 tint = mix(mix(uAurora[i], uDone, done), uError, failed);
    vec2 delta = w - centre;
    colour += tint * exp(-dot(delta, delta) * 3.2);
  }

  // Fake sphere lighting.
  float z = sqrt(max(0.0, 1.0 - r * r));
  vec3 normal = vec3(q, z);
  vec3 light = normalize(vec3(0.5 * cos(uFlow * 0.5), 0.6 + 0.2 * sin(uFlow * 0.4), 0.8));
  float diffuse = 0.55 + 0.45 * max(dot(normal, light), 0.0);
  float specular = pow(max(dot(reflect(-light, normal), vec3(0.0, 0.0, 1.0)), 0.0), 24.0);
  float fresnel = pow(1.0 - z, 2.5);
  vec3 rimTint = mix(uAurora[1], uAurora[2], 0.5 + 0.5 * sin(uFlow + atan(q.y, q.x)));
  rimTint = mix(mix(rimTint, uDone, done), uError, failed);

  colour = colour * diffuse
    + vec3(specular) * (0.35 + high * 0.9)
    + rimTint * fresnel * (0.5 + high * 1.2);
  colour += high * (1.0 - uCalm) * 0.15 * snoise(q * 9.0 + uFlow * 3.0);
  colour *= 1.0 - 0.25 * transcribing;
  // Error: one slow pulse.
  colour *= 1.0 - failed * 0.25 * (0.5 + 0.5 * sin(uFlow * 4.0));

  float body = smoothstep(1.0, 0.96, r);
  float halo = exp(-max(r - 1.0, 0.0) * 5.0) * (0.25 + low * 0.35 + done * 0.3) * (1.0 - body);
  // Reaches zero before the canvas edge, so the window never clips the glow.
  float fade = smoothstep(1.0, 0.85, edge);

  float alpha = clamp(body + halo, 0.0, 1.0) * fade;
  vec3 lit = mix(rimTint, colour, body);
  return vec4(lit * alpha, alpha);
}

void main() {
  vec4 colour = mix(look(uFrom, vUv), look(uTo, vUv), uMix);
  // Linear to sRGB on the premultiplied colour's straight component.
  vec3 straight = colour.a > 0.0 ? colour.rgb / colour.a : vec3(0.0);
  gl_FragColor = vec4(pow(straight, vec3(1.0 / 2.2)) * colour.a, colour.a);
}`;

export interface OrbRenderer {
  render(uniforms: OrbUniforms): void;
  dispose(): void;
}

function compile(gl: WebGLRenderingContext, type: number, source: string) {
  const shader = gl.createShader(type);
  if (!shader) return null;
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    console.error('orb shader failed to compile', gl.getShaderInfoLog(shader));
    gl.deleteShader(shader);
    return null;
  }
  return shader;
}

export function createOrbRenderer(
  canvas: HTMLCanvasElement,
  palette: OrbPalette
): OrbRenderer | null {
  const gl = canvas.getContext('webgl', { alpha: true, premultipliedAlpha: true, antialias: false });
  if (!gl) return null;

  const vertex = compile(gl, gl.VERTEX_SHADER, VERTEX);
  const fragment = compile(gl, gl.FRAGMENT_SHADER, FRAGMENT);
  const program = gl.createProgram();
  if (!vertex || !fragment || !program) return null;
  gl.attachShader(program, vertex);
  gl.attachShader(program, fragment);
  gl.linkProgram(program);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    console.error('orb program failed to link', gl.getProgramInfoLog(program));
    return null;
  }
  gl.useProgram(program);

  const buffer = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, -1, 1, 1, -1, 1, 1]), gl.STATIC_DRAW);
  const position = gl.getAttribLocation(program, 'aPosition');
  gl.enableVertexAttribArray(position);
  gl.vertexAttribPointer(position, 2, gl.FLOAT, false, 0, 0);

  const location = (name: string) => gl.getUniformLocation(program, name);
  gl.uniform3fv(location('uAurora[0]'), new Float32Array(palette.aurora.flat()));
  gl.uniform3fv(location('uDone'), new Float32Array(palette.done));
  gl.uniform3fv(location('uError'), new Float32Array(palette.error));

  const scalars = {
    uFlow: location('uFlow'),
    uLow: location('uLow'),
    uMid: location('uMid'),
    uHigh: location('uHigh'),
    uFrom: location('uFrom'),
    uTo: location('uTo'),
    uMix: location('uMix'),
    uCalm: location('uCalm'),
  };

  gl.clearColor(0, 0, 0, 0);

  return {
    render(uniforms) {
      gl.viewport(0, 0, canvas.width, canvas.height);
      gl.clear(gl.COLOR_BUFFER_BIT);
      gl.uniform1f(scalars.uFlow, uniforms.flow);
      gl.uniform1f(scalars.uLow, uniforms.low);
      gl.uniform1f(scalars.uMid, uniforms.mid);
      gl.uniform1f(scalars.uHigh, uniforms.high);
      gl.uniform1f(scalars.uFrom, uniforms.from);
      gl.uniform1f(scalars.uTo, uniforms.to);
      gl.uniform1f(scalars.uMix, uniforms.mix);
      gl.uniform1f(scalars.uCalm, uniforms.calm);
      gl.drawArrays(gl.TRIANGLES, 0, 6);
    },
    dispose() {
      gl.deleteBuffer(buffer);
      gl.deleteProgram(program);
      gl.deleteShader(vertex);
      gl.deleteShader(fragment);
      gl.getExtension('WEBGL_lose_context')?.loseContext();
    },
  };
}
```

- [ ] **Step 2: Write the failing OrbCanvas test**

`src/orb/__tests__/OrbCanvas.test.tsx`:

```tsx
import { render } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { OrbCanvas } from '../OrbCanvas';

const read = () => ({ bands: { low: 0, mid: 0, high: 0 }, phase: 'listening' as const });

describe('OrbCanvas', () => {
  let getContext: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    // jsdom has no WebGL: this is the fallback path every test machine takes.
    getContext = vi.fn().mockReturnValue(null);
    vi.spyOn(HTMLCanvasElement.prototype, 'getContext').mockImplementation(getContext);
  });

  afterEach(() => vi.restoreAllMocks());

  it('renders a canvas at device-pixel resolution and CSS size', () => {
    vi.stubGlobal('devicePixelRatio', 2);
    const { container } = render(<OrbCanvas size={240} running read={read} />);
    const canvas = container.querySelector('canvas')!;
    expect(canvas.width).toBe(480);
    expect(canvas.style.width).toBe('240px');
    vi.unstubAllGlobals();
  });

  it('is decorative to assistive technology', () => {
    const { container } = render(<OrbCanvas size={48} running read={read} />);
    expect(container.querySelector('canvas')).toHaveAttribute('aria-hidden', 'true');
  });

  it('asks for WebGL first and survives not getting it', () => {
    render(<OrbCanvas size={240} running read={read} />);
    expect(getContext).toHaveBeenCalledWith('webgl', expect.anything());
  });

  it('does not animate while not running', () => {
    const raf = vi.spyOn(window, 'requestAnimationFrame');
    render(<OrbCanvas size={240} running={false} read={read} />);
    expect(raf).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 3: Run to verify it fails**

Run: `npx vitest run src/orb/__tests__/OrbCanvas.test.tsx`
Expected: FAIL, cannot resolve `../OrbCanvas`.

- [ ] **Step 4: Implement OrbCanvas**

`src/orb/OrbCanvas.tsx`:

```tsx
import { useEffect, useRef } from 'react';

import type { OrbPhase } from '../../electron/types';

import type { Bands } from './bands';
import { createFrame, type OrbUniforms } from './frame';
import { createOrbRenderer } from './orb-shader';
import { buildPalette, readTokenBytes } from './palette';

interface OrbCanvasProps {
  /** CSS pixels, square. */
  size: number;
  /** The loop runs only while true, so a hidden orb costs nothing. */
  running: boolean;
  /** Called once per frame for the current audio and phase. */
  read: () => { bands: Bands; phase: OrbPhase };
}

/** Without WebGL the orb is a plain disc in the accent colour: dull, never missing. */
function drawFallback(canvas: HTMLCanvasElement, uniforms: OrbUniforms) {
  const context = canvas.getContext('2d');
  if (!context) return;
  const center = canvas.width / 2;
  context.clearRect(0, 0, canvas.width, canvas.height);
  if (uniforms.to === 0 && uniforms.mix === 1) return;
  context.fillStyle = getComputedStyle(document.documentElement)
    .getPropertyValue('--mantine-primary-color-filled')
    .trim();
  context.beginPath();
  context.arc(center, center, canvas.width * 0.31 * (1 + 0.06 * uniforms.low), 0, Math.PI * 2);
  context.fill();
}

export function OrbCanvas({ size, running, read }: OrbCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const readRef = useRef(read);
  readRef.current = read;

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || !running) return;

    const renderer = createOrbRenderer(canvas, buildPalette(readTokenBytes));
    const frame = createFrame('cancelled');
    const reducedMotion = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ?? false;

    let handle = 0;
    let previous = performance.now();
    const loop = (now: number) => {
      const { bands, phase } = readRef.current();
      const uniforms = frame.step({ deltaMs: now - previous, bands, phase, reducedMotion });
      previous = now;
      if (renderer) renderer.render(uniforms);
      else drawFallback(canvas, uniforms);
      handle = requestAnimationFrame(loop);
    };
    handle = requestAnimationFrame(loop);

    return () => {
      cancelAnimationFrame(handle);
      renderer?.dispose();
    };
  }, [running]);

  const pixels = Math.round(size * (window.devicePixelRatio || 1));
  return (
    <canvas
      ref={canvasRef}
      aria-hidden="true"
      width={pixels}
      height={pixels}
      style={{ width: `${size}px`, height: `${size}px`, display: 'block' }}
    />
  );
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `npx vitest run src/orb/__tests__/OrbCanvas.test.tsx`
Expected: PASS, 4 tests.

- [ ] **Step 6: Register the orb in the Storybook taxonomy**

In `docs/storybook-taxonomy.json`, add `"Parley"` to the end of `"order"`, and add this root beside the others under `"roots"`:

```json
"Parley": {
  "blurb": "The surfaces a Parley user actually sees: the orb and the settings window.",
  "depth": 3,
  "sourceDirs": ["src/orb", "src/settings"],
  "sections": {
    "Orb": {
      "blurb": "The voice-reactive orb and its phases.",
      "members": ["OrbCanvas"]
    }
  }
}
```

- [ ] **Step 7: Write the story**

`src/orb/OrbCanvas.stories.tsx`. The story drives the real component with synthetic audio so the shader can be judged without a microphone.

```tsx
import type { Meta, StoryObj } from '@storybook/react';
import { Center } from '@mantine/core';

import { numberArg } from 'storybook/story-helpers';

import type { OrbPhase } from '../../electron/types';

import type { Bands } from './bands';
import { OrbCanvas } from './OrbCanvas';

type Signal = 'silence' | 'speech' | 'sweep';

/** Speech-like: syllable bursts at about 4 Hz with a slower phrase contour. */
function synth(signal: Signal, seconds: number): Bands {
  if (signal === 'silence') return { low: 0, mid: 0, high: 0 };
  if (signal === 'sweep') {
    const position = (seconds % 6) / 6;
    return {
      low: Math.max(0, 1 - position * 3),
      mid: Math.max(0, 1 - Math.abs(position - 0.5) * 3),
      high: Math.max(0, position * 3 - 2),
    };
  }
  const syllable = Math.max(0, Math.sin(seconds * Math.PI * 4)) ** 2;
  const phrase = 0.5 + 0.5 * Math.sin(seconds * 0.9);
  const energy = syllable * phrase;
  return { low: energy * 0.9, mid: energy * 0.7, high: energy * 0.4 * (0.5 + 0.5 * Math.sin(seconds * 11)) };
}

function Demo({ size, phase, signal }: { size: number; phase: OrbPhase; signal: Signal }) {
  return (
    <Center w={size + 40} h={size + 40}>
      <OrbCanvas
        size={size}
        running
        read={() => ({ bands: synth(signal, performance.now() / 1000), phase })}
      />
    </Center>
  );
}

/** The orb renderer, fed synthetic audio. Judge it by eye: fluid, lit, never bouncing. */
const meta = {
  title: 'Parley/Orb/OrbCanvas',
  component: Demo,
  tags: ['autodocs'],
  parameters: { layout: 'centered' },
  argTypes: {
    size: numberArg('size', { description: 'Canvas size in CSS pixels.', defaultValue: 240 }),
    phase: {
      control: 'select',
      options: ['listening', 'transcribing', 'done', 'error', 'cancelled'],
      description: 'Orb phase. Changes crossfade over 300 ms.',
    },
    signal: {
      control: 'select',
      options: ['silence', 'speech', 'sweep'],
      description: 'Synthetic audio fed to the orb.',
    },
  },
} satisfies Meta<typeof Demo>;

export default meta;
type Story = StoryObj<typeof Demo>;

export const Default: Story = { args: { size: 240, phase: 'listening', signal: 'speech' } };
export const Idle: Story = { args: { size: 240, phase: 'listening', signal: 'silence' } };
export const BandSweep: Story = { args: { size: 240, phase: 'listening', signal: 'sweep' } };
export const Transcribing: Story = { args: { size: 240, phase: 'transcribing', signal: 'silence' } };
export const Done: Story = { args: { size: 240, phase: 'done', signal: 'silence' } };
export const Failed: Story = { args: { size: 240, phase: 'error', signal: 'silence' } };
export const Mini: Story = { args: { size: 48, phase: 'listening', signal: 'silence' } };
```

- [ ] **Step 8: Regenerate story docs and lint**

Run: `npm run storybook-docs && npm run storybook-lint`
Expected: exit 0. If `storybook-lint` reports a rule failure, fix exactly what it names (it prints rule ids R1 to R10) and rerun.

- [ ] **Step 9: Judge the shader by eye**

Run: `npm run storybook`, open `Parley/Orb/OrbCanvas`.

Accept only when all of these hold. Tune the numeric constants in `FRAGMENT` (lobe spread `0.45`, falloff `3.2`, warp `0.35`, specular power `24.0`, halo `5.0`) until they do:

1. `Default`: the orb's outline stays essentially still while speech plays; energy reads as colour lobes spreading and the rim brightening. No visible pulsing of size.
2. `Idle`: slow, continuous drift; never frozen, never busy.
3. `BandSweep`: low moves the body, mid speeds the flow, high adds sparkle at the rim. Three visibly different responses.
4. `Transcribing`: inward swirl, dimmer than listening.
5. Switching `phase` in the controls crossfades; no pop.
6. `Done` turns teal with a brighter halo; `Failed` turns red and pulses slowly.
7. No hard edge or clipped glow at the canvas boundary, on both a dark and a light Storybook background.
8. `Mini` at 48 px still reads as the same object.

- [ ] **Step 10: Commit**

```bash
git add src/orb/orb-shader.ts src/orb/OrbCanvas.tsx src/orb/OrbCanvas.stories.tsx src/orb/__tests__/OrbCanvas.test.tsx docs/storybook-taxonomy.json docs .storybook
git commit -m "feat: WebGL orb renderer with Storybook visual check"
```

---

### Task 7: Rewire the orb window

**Files:**
- Modify: `src/orb/Orb.tsx`, `src/orb/Orb.module.css`, `src/orb/main.tsx`, `electron/windows.ts`, `electron/__tests__/windows.test.ts`
- Create: `src/orb/__tests__/Orb.test.tsx`

**Interfaces:**
- Consumes: `OrbCanvas` (Task 6), `Recorder.bands()` (Task 3), `SPRING` (Task 1).
- Produces: `ORB_SIZE = { width: 260, height: 260 }`.

- [ ] **Step 1: Update the window test first**

In `electron/__tests__/windows.test.ts`, add inside `describe('orb window', ...)`:

```ts
  it('is 260 px square so the orb glow has room to fade out', () => {
    expect(ORB_SIZE).toEqual({ width: 260, height: 260 });
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run electron/__tests__/windows.test.ts`
Expected: FAIL, received `{ width: 220, height: 220 }`.

- [ ] **Step 3: Resize the window**

In `electron/windows.ts` change:

```ts
export const ORB_SIZE = { width: 260, height: 260 };
```

Run: `npx vitest run electron/__tests__/windows.test.ts`
Expected: PASS.

- [ ] **Step 4: Write the failing Orb test**

`src/orb/__tests__/Orb.test.tsx`:

```tsx
import { act, render, screen } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { ThemeProvider } from '@/components/theme-provider';

import type { OrbPhasePayload, ParleyApi } from '../../../electron/types';
import { Orb } from '../Orb';

describe('Orb', () => {
  let emit: (payload: OrbPhasePayload) => void;

  beforeEach(() => {
    vi.spyOn(HTMLCanvasElement.prototype, 'getContext').mockReturnValue(null);
    window.parley = {
      onOrbPhase: (listener: (payload: OrbPhasePayload) => void) => {
        emit = listener;
        return () => {};
      },
      sendAudio: vi.fn(),
    } as unknown as ParleyApi;
  });

  afterEach(() => vi.restoreAllMocks());

  it('shows the error message the main process sends', async () => {
    render(
      <ThemeProvider defaultTheme="dark" storageKey="test-color-scheme">
        <Orb />
      </ThemeProvider>
    );
    await act(async () => emit({ phase: 'error', message: 'No API key' }));
    expect(await screen.findByText('No API key')).toBeInTheDocument();
  });

  it('draws the orb on a 240 px canvas', () => {
    const { container } = render(
      <ThemeProvider defaultTheme="dark" storageKey="test-color-scheme">
        <Orb />
      </ThemeProvider>
    );
    expect(container.querySelector('canvas')!.style.width).toBe('240px');
  });
});
```

- [ ] **Step 5: Run to verify it fails**

Run: `npx vitest run src/orb/__tests__/Orb.test.tsx`
Expected: FAIL on the 240 px assertion (the current canvas has no inline width).

- [ ] **Step 6: Rewrite Orb.tsx**

Replace the whole file:

```tsx
import { useCallback, useEffect, useRef, useState } from 'react';
import { Stack, Text } from '@mantine/core';
import { motion } from 'motion/react';

import { SPRING } from '@/lib/motion';

import type { OrbPhase } from '../../electron/types';

import { SILENT_BANDS } from './bands';
import { OrbCanvas } from './OrbCanvas';
import { createPhaseHandler } from './phase-handler';
import { createRecorder, type Recorder } from './recorder';
import { playTick } from './tick';
import classes from './Orb.module.css';

const ORB_CANVAS_SIZE = 240;

export function Orb() {
  const recorderRef = useRef<Recorder | null>(null);
  const phaseRef = useRef<OrbPhase>('cancelled');
  const [visible, setVisible] = useState(false);
  const [message, setMessage] = useState('');

  useEffect(() => {
    const recorder = createRecorder();
    recorderRef.current = recorder;
    const { handlePhase, dispose } = createPhaseHandler({
      recorder,
      sendAudio: window.parley.sendAudio,
      playTick,
      onPhase: (phase) => {
        phaseRef.current = phase;
      },
      setVisible,
      setMessage,
    });
    const unsubscribe = window.parley.onOrbPhase(handlePhase);

    return () => {
      unsubscribe();
      dispose();
      recorder.discard();
      recorderRef.current = null;
    };
  }, []);

  const read = useCallback(
    () => ({ bands: recorderRef.current?.bands() ?? SILENT_BANDS, phase: phaseRef.current }),
    []
  );

  return (
    <Stack className={classes.root} align="center" justify="center" gap={0}>
      <motion.div
        initial={false}
        animate={{ opacity: visible ? 1 : 0, scale: visible ? 1 : 0.85 }}
        transition={SPRING}
      >
        <OrbCanvas size={ORB_CANVAS_SIZE} running={visible} read={read} />
      </motion.div>
      <Text size="xs" c="red.4" fw={500} h={16}>
        {message}
      </Text>
    </Stack>
  );
}
```

In `src/orb/Orb.module.css`, delete the `opacity: 0`, `transition`, and the `.root[data-visible='true']` rule; `motion` owns visibility now. Keep the transparent `html, body, #root` block and `.root { height: 100%; }`.

- [ ] **Step 7: Honour reduced motion in the orb entry**

In `src/orb/main.tsx`, wrap `<Orb />`:

```tsx
import { MotionConfig } from 'motion/react';
```

```tsx
      <MotionConfig reducedMotion="user">
        <Orb />
      </MotionConfig>
```

- [ ] **Step 8: Run tests and type-check**

Run: `npx vitest run src/orb electron && npm run type-check`
Expected: PASS, exit 0.

- [ ] **Step 9: Check in the real app**

Run: `make dev`. Trigger the gesture (default: tap Right Option twice and hold) in any text field and speak.
Expected: the orb springs in, flows with your voice without bouncing, swirls while transcribing, flashes teal, and fades. No glow is clipped at the window edge. The text field keeps focus and the transcript pastes.

- [ ] **Step 10: Commit**

```bash
git add src/orb electron/windows.ts electron/__tests__/windows.test.ts
git commit -m "feat: orb window uses the WebGL orb with spring appear and dismiss"
```

---

### Task 8: Split the settings window (no visual change)

**Files:**
- Create: `src/settings/SettingRow.tsx`, `src/settings/SetupTab.tsx`, `src/settings/GestureTab.tsx`, `src/settings/GeneralTab.tsx`, `src/settings/TabRail.tsx`, `src/settings/SettingsShell.tsx`
- Modify: `src/settings/SettingsApp.tsx`

**Interfaces:**
- Produces:
  - `type TabId = 'setup' | 'gesture' | 'general'`, `TAB_ORDER: TabId[]` from `SettingsShell.tsx`.
  - `<SettingRow label description? children />`.
  - `<SetupTab needsSetup={boolean} permissions={PermissionStatus} hasApiKey={boolean} />`.
  - `<GestureTab settings={SettingsView} onChange={(patch: Partial<Settings>) => void} />`.
  - `<GeneralTab settings={SettingsView} onChange={(patch: Partial<Settings>) => void} />`.
  - `<TabRail needsSetup={boolean} />` rendering the `Tabs.List`.
  - `<SettingsShell settings permissions saveFailed onChange />`.

This task is a pure move. The existing `src/settings/__tests__/SettingsApp.test.tsx` is the safety net and must stay green untouched.

- [ ] **Step 1: Confirm the baseline**

Run: `npx vitest run src/settings`
Expected: PASS. Note the test count.

- [ ] **Step 2: Move the code**

Cut from `SettingsApp.tsx` into the new files, changing nothing but imports and props:

- `SettingRow.tsx`: the `SettingRow` function, exported.
- `SetupTab.tsx`: `keySchema`, `KeyForm`, `PermissionRow`, `ApiKeySection`, and an exported `SetupTab` that returns the current contents of `<Tabs.Panel value="setup">` (the `Stack`, not the `Tabs.Panel`).
- `GestureTab.tsx`: `KEY_LABELS` and an exported `GestureTab` returning the contents of the gesture panel. Replace `update.mutate(...)` with `onChange(...)`.
- `GeneralTab.tsx`: exported `GeneralTab` returning the contents of the general panel, keeping the "Saves on blur" comment. Replace `update.mutate(...)` with `onChange(...)`.
- `TabRail.tsx`: exported `TabRail` returning the current `<Tabs.List ...>` element with its header and three `Tabs.Tab`s.
- `SettingsShell.tsx`:

```tsx
import { Alert, Box, Tabs } from '@mantine/core';
import { useState } from 'react';

import type { PermissionStatus, Settings, SettingsView } from '../../electron/types';

import { GeneralTab } from './GeneralTab';
import { GestureTab } from './GestureTab';
import { SetupTab } from './SetupTab';
import { TabRail } from './TabRail';

export type TabId = 'setup' | 'gesture' | 'general';
export const TAB_ORDER: TabId[] = ['setup', 'gesture', 'general'];

export function SettingsShell({
  settings,
  permissions,
  saveFailed,
  onChange,
}: {
  settings: SettingsView;
  permissions: PermissionStatus;
  saveFailed: boolean;
  onChange: (patch: Partial<Settings>) => void;
}) {
  const needsSetup = !permissions.microphone || !permissions.accessibility || !settings.hasApiKey;
  const [active, setActive] = useState<TabId>(needsSetup ? 'setup' : 'gesture');

  return (
    <Tabs
      orientation="vertical"
      variant="pills"
      radius="md"
      h="100vh"
      style={{ overflow: 'hidden' }}
      value={active}
      onChange={(value) => value && setActive(value as TabId)}
    >
      <TabRail needsSetup={needsSetup} />
      <Box flex={1} miw={0} p="xl" style={{ overflowY: 'auto' }}>
        {saveFailed && (
          <Alert color="red" variant="light" mb="md">
            Could not save settings
          </Alert>
        )}
        <Tabs.Panel value="setup">
          <SetupTab
            needsSetup={needsSetup}
            permissions={permissions}
            hasApiKey={settings.hasApiKey}
          />
        </Tabs.Panel>
        <Tabs.Panel value="gesture">
          <GestureTab settings={settings} onChange={onChange} />
        </Tabs.Panel>
        <Tabs.Panel value="general">
          <GeneralTab settings={settings} onChange={onChange} />
        </Tabs.Panel>
      </Box>
    </Tabs>
  );
}
```

If `PermissionStatus`, `Settings`, or `SettingsView` are not exported from `electron/types.ts` under those names, use the names that file exports; do not add new types.

- `SettingsApp.tsx` becomes:

```tsx
import { Loader, Stack } from '@mantine/core';

import { SettingsShell } from './SettingsShell';
import { usePermissions, useSettings, useUpdateSettings } from './use-parley';

export function SettingsApp() {
  const settings = useSettings();
  const permissions = usePermissions();
  const update = useUpdateSettings();

  if (!settings.data || !permissions.data) {
    return (
      <Stack h="100vh" align="center" justify="center">
        <Loader />
      </Stack>
    );
  }

  return (
    <SettingsShell
      settings={settings.data}
      permissions={permissions.data}
      saveFailed={update.isError}
      onChange={(patch) => update.mutate(patch)}
    />
  );
}
```

- [ ] **Step 3: Verify nothing changed**

Run: `npx vitest run src/settings && npm run type-check && npm run lint && npm run ui-lint`
Expected: same test count as Step 1, all PASS, exit 0.

- [ ] **Step 4: Commit**

```bash
git add src/settings
git commit -m "refactor: split the settings window into focused components"
```

---

### Task 9: Glass restyle, vibrancy, and the rail orb

**Files:**
- Create: `src/settings/settings.module.css`
- Modify: `electron/windows.ts`, `electron/__tests__/windows.test.ts`, `src/settings/SettingsShell.tsx`, `src/settings/TabRail.tsx`, `src/settings/SetupTab.tsx`, `src/settings/GestureTab.tsx`, `src/settings/GeneralTab.tsx`, `settings.html`

**Interfaces:**
- Consumes: tokens (Task 1), `OrbCanvas` (Task 6).
- Produces: `settingsWindowOptions(preloadPath: string, platform?: NodeJS.Platform)`; CSS classes `shell`, `rail`, `glass`, `primary`, `tab`, `tabLabel`, `pill`, `glow`.

- [ ] **Step 1: Write the failing window test**

Replace the `describe('settings window', ...)` block in `electron/__tests__/windows.test.ts`:

```ts
describe('settings window', () => {
  it('is a small fixed-size window that opens hidden', () => {
    const options = settingsWindowOptions('/app/preload.mjs', 'darwin');
    expect(options).toMatchObject({ width: 760, height: 560, resizable: false, show: false });
    expect(options.webPreferences).toMatchObject({ contextIsolation: true, nodeIntegration: false });
  });

  it('uses real macOS blur behind a transparent background', () => {
    const options = settingsWindowOptions('/app/preload.mjs', 'darwin');
    expect(options.vibrancy).toBe('under-window');
    expect(options.visualEffectState).toBe('active');
    expect(options.backgroundColor).toBe('#00000000');
  });

  it('keeps a solid dark background where vibrancy does not exist', () => {
    const options = settingsWindowOptions('/app/preload.mjs', 'win32');
    expect(options.vibrancy).toBeUndefined();
    expect(options.backgroundColor).toBe(BACKGROUND_DARK);
  });
});
```

Add `import { BACKGROUND_DARK } from '../window-options';` at the top.

- [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run electron/__tests__/windows.test.ts`
Expected: FAIL, `vibrancy` is undefined.

- [ ] **Step 3: Implement vibrancy**

In `electron/windows.ts`:

```ts
export function settingsWindowOptions(
  preloadPath: string,
  platform: NodeJS.Platform = process.platform
) {
  const isMac = platform === 'darwin';
  return {
    width: 760,
    height: 560,
    useContentSize: true,
    resizable: false,
    fullscreenable: false,
    // Shown on `ready-to-show` in main.ts, which also avoids a vibrancy flash.
    show: false,
    title: 'Parley',
    // Glass is real system blur on macOS; elsewhere the window stays solid.
    vibrancy: isMac ? ('under-window' as const) : undefined,
    visualEffectState: isMac ? ('active' as const) : undefined,
    backgroundColor: isMac ? '#00000000' : BACKGROUND_DARK,
    webPreferences: lockedDown(preloadPath),
  };
}
```

Run: `npx vitest run electron/__tests__/windows.test.ts`
Expected: PASS.

- [ ] **Step 4: Write the styles**

`src/settings/settings.module.css`:

```css
/* The settings window sits on macOS vibrancy, so the page itself is clear. */
:global(html),
:global(body) {
  background: transparent;
}

.shell {
  height: 100vh;
  overflow: hidden;
  background: color-mix(in oklab, var(--mantine-color-body) 55%, transparent);
}

.rail {
  width: 200px;
  padding: var(--mantine-spacing-md);
  background: var(--app-glass);
  border-right: 1px solid var(--app-glass-border);
  backdrop-filter: blur(24px) saturate(1.4);
}

.glass {
  background: var(--app-glass);
  border: 1px solid var(--app-glass-border);
  border-radius: var(--mantine-radius-lg);
  backdrop-filter: blur(24px) saturate(1.4);
  transition: background 150ms ease;
}

.glass:hover {
  background: var(--app-glass-hover);
}

.tab {
  position: relative;
  background: transparent;
  color: var(--mantine-color-text);
}

.tab:hover {
  background: var(--app-glass-hover);
}

.tabLabel {
  position: relative;
  z-index: 1;
}

.pill {
  position: absolute;
  inset: 0;
  z-index: 0;
  border-radius: var(--mantine-radius-md);
  background: var(--app-aurora-gradient);
  opacity: 0.9;
}

/* Primary buttons carry the gradient, with a sheen that crosses on hover. */
.primary {
  position: relative;
  overflow: hidden;
  border: 0;
  background: var(--app-aurora-gradient);
}

.primary::after {
  content: '';
  position: absolute;
  inset: 0;
  transform: translateX(-120%);
  background: linear-gradient(
    100deg,
    transparent 30%,
    color-mix(in oklab, white 35%, transparent) 50%,
    transparent 70%
  );
  transition: transform 400ms cubic-bezier(0.22, 1, 0.36, 1);
}

.primary:hover::after {
  transform: translateX(120%);
}

.glow {
  border-radius: var(--mantine-radius-md);
  box-shadow: 0 0 0 1px var(--app-aurora-cyan), 0 0 24px -4px var(--app-aurora-violet);
}

:global(:focus-visible) {
  outline: 2px solid var(--app-aurora-cyan);
  outline-offset: 2px;
}

@media (prefers-reduced-motion: reduce) {
  .primary::after {
    display: none;
  }
}
```

- [ ] **Step 5: Apply the styles**

1. `SettingsShell.tsx`: import `classes from './settings.module.css'`; on `<Tabs>` replace `h="100vh"` and the inline `style` with `className={classes.shell}`, and set `variant="unstyled"`.
2. `TabRail.tsx`:
   - `<Tabs.List className={classes.rail}>` (drop `w`, `p`, `bg`).
   - Replace the `ThemeIcon` and its `Mic` icon with the live mini orb:

```tsx
<OrbCanvas size={48} running read={IDLE} />
```

with, at module scope:

```tsx
const IDLE = () => ({ bands: SILENT_BANDS, phase: 'listening' as const });
```

   and imports `import { SILENT_BANDS } from '../orb/bands';` and `import { OrbCanvas } from '../orb/OrbCanvas';`. Remove the now-unused `Mic` and `ThemeIcon` imports.
   - Each `Tabs.Tab` gets `className={classes.tab}` and `classNames={{ tabLabel: classes.tabLabel, tabSection: classes.tabLabel }}` plus `px="sm" py={8}` so the unstyled variant keeps its padding.
3. `SetupTab.tsx`, `GestureTab.tsx`, `GeneralTab.tsx`: replace each `<Panel contentProps={{ p: 'md' }}>...</Panel>` with `<Box className={classes.glass} p="md">...</Box>`, importing `Box` from Mantine and the CSS module. Remove the unused `Panel` import.
4. `SetupTab.tsx`: the "Test and save" button gets `className={classes.primary}`.
5. `settings.html`: no change needed; confirm `data-mantine-color-scheme="dark"` is still present.

- [ ] **Step 6: Run the gates**

Run: `npx vitest run src/settings electron && npm run type-check && npm run lint && npm run ui-lint`
Expected: PASS, exit 0. Tests find tabs by role, which the unstyled variant preserves.

- [ ] **Step 7: Check in the real app**

Run: `make dev`, open Settings from the tray.
Expected: desktop wallpaper blurs through the window; the rail and cards are frosted glass with a hairline border; the mini orb drifts in the rail header; the primary button is aurora with a sheen on hover; keyboard focus shows a cyan ring; no white flash on open. Text stays readable over both a bright and a dark wallpaper; if not, raise the `55%` in `.shell`.

- [ ] **Step 8: Commit**

```bash
git add electron/windows.ts electron/__tests__/windows.test.ts src/settings
git commit -m "feat: dark glass settings window with vibrancy and a live rail orb"
```

---

### Task 10: Motion layer

**Files:**
- Modify: `src/settings/main.tsx`, `src/settings/SettingsShell.tsx`, `src/settings/TabRail.tsx`, `src/settings/SetupTab.tsx`, `src/settings/GestureTab.tsx`, `src/settings/GeneralTab.tsx`
- Create: `src/settings/tabs.ts`, `src/settings/motion.tsx`, `src/settings/__tests__/motion.test.tsx`

**Interfaces:**
- Consumes: `SPRING`, `EASE`, `DURATION`, `STAGGER` (Task 1); `TabId`, `TAB_ORDER` (Task 8); CSS classes `pill`, `glow` (Task 9).
- Produces: `tabDirection(from: TabId, to: TabId): 1 | -1`; `<StaggerGroup>` and `<StaggerItem>`; `<Pressable>`.

- [ ] **Step 1: Write the failing test**

`src/settings/__tests__/motion.test.tsx`:

```tsx
import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';

import { StaggerGroup, StaggerItem, tabDirection } from '../motion';

describe('tabDirection', () => {
  it('is 1 moving down the rail and -1 moving up', () => {
    expect(tabDirection('setup', 'general')).toBe(1);
    expect(tabDirection('general', 'gesture')).toBe(-1);
  });
});

describe('StaggerGroup', () => {
  it('renders its children', () => {
    render(
      <StaggerGroup>
        <StaggerItem>first</StaggerItem>
        <StaggerItem>second</StaggerItem>
      </StaggerGroup>
    );
    expect(screen.getByText('first')).toBeInTheDocument();
    expect(screen.getByText('second')).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run src/settings/__tests__/motion.test.tsx`
Expected: FAIL, cannot resolve `../motion`.

- [ ] **Step 3: Implement the motion helpers**

`src/settings/motion.tsx`:

```tsx
import { motion } from 'motion/react';
import type { ReactNode } from 'react';

import { DURATION, EASE, SPRING, STAGGER } from '@/lib/motion';

import { TAB_ORDER, type TabId } from './tabs';

/** 1 when the new tab is further down the rail, so content slides up to meet it. */
export function tabDirection(from: TabId, to: TabId): 1 | -1 {
  return TAB_ORDER.indexOf(to) >= TAB_ORDER.indexOf(from) ? 1 : -1;
}

/** Tab content: crossfade with an 8 px slide in the direction of travel. */
export const panelVariants = {
  enter: (direction: number) => ({ opacity: 0, y: 8 * direction }),
  center: { opacity: 1, y: 0, transition: { duration: DURATION.base, ease: EASE } },
  exit: (direction: number) => ({
    opacity: 0,
    y: -8 * direction,
    transition: { duration: DURATION.fast, ease: EASE },
  }),
};

const group = { center: { transition: { staggerChildren: STAGGER } } };
const item = {
  enter: { opacity: 0, y: 6 },
  center: { opacity: 1, y: 0, transition: SPRING },
};

export function StaggerGroup({ children }: { children: ReactNode }) {
  return (
    <motion.div variants={group} initial="enter" animate="center">
      {children}
    </motion.div>
  );
}

export function StaggerItem({ children }: { children: ReactNode }) {
  return <motion.div variants={item}>{children}</motion.div>;
}

/** Spring press for anything tappable. Wraps, so Mantine's own element is untouched. */
export function Pressable({ children }: { children: ReactNode }) {
  return (
    <motion.span style={{ display: 'inline-block' }} whileTap={{ scale: 0.97 }} transition={SPRING}>
      {children}
    </motion.span>
  );
}
```

`motion.tsx` must not import from `SettingsShell.tsx`: the shell imports the tabs, and the tabs import `motion.tsx`, which would be a cycle. So first create `src/settings/tabs.ts`:

```ts
export type TabId = 'setup' | 'gesture' | 'general';
export const TAB_ORDER: TabId[] = ['setup', 'gesture', 'general'];
```

and in `SettingsShell.tsx` replace the two local declarations with `export { TAB_ORDER, type TabId } from './tabs';` plus `import { type TabId } from './tabs';`.

- [ ] **Step 4: Run to verify it passes**

Run: `npx vitest run src/settings/__tests__/motion.test.tsx`
Expected: PASS, 2 tests.

- [ ] **Step 5: Reduced motion at the root**

In `src/settings/main.tsx`, wrap `<SettingsApp />` in `<MotionConfig reducedMotion="user">` (import from `motion/react`). With this, transforms are dropped and only opacity animates for users who ask for less motion.

- [ ] **Step 6: Sliding pill**

In `TabRail.tsx`, take the active tab as a prop (`active: TabId`, passed from `SettingsShell`) and render the pill inside the active tab only:

```tsx
<Tabs.Tab value="setup" className={classes.tab} /* ...existing props */>
  {active === 'setup' && (
    <motion.span layoutId="tab-pill" className={classes.pill} transition={SPRING} />
  )}
  <span className={classes.tabLabel}>Setup</span>
</Tabs.Tab>
```

Repeat for `gesture` and `general` with their own labels. The shared `layoutId` is what makes one pill slide rather than three fade.

- [ ] **Step 7: Direction-aware panel transitions**

In `SettingsShell.tsx`, track direction and render only the active panel through `AnimatePresence`:

```tsx
const [direction, setDirection] = useState<1 | -1>(1);

const select = (next: TabId) => {
  setDirection(tabDirection(active, next));
  setActive(next);
};
```

Pass `onChange={(value) => value && select(value as TabId)}` to `<Tabs>`, and replace the three `Tabs.Panel`s with:

```tsx
<Tabs.Panel value={active}>
  <AnimatePresence mode="wait" custom={direction} initial={false}>
    <motion.div
      key={active}
      custom={direction}
      variants={panelVariants}
      initial="enter"
      animate="center"
      exit="exit"
    >
      {active === 'setup' && (
        <SetupTab needsSetup={needsSetup} permissions={permissions} hasApiKey={settings.hasApiKey} />
      )}
      {active === 'gesture' && <GestureTab settings={settings} onChange={onChange} />}
      {active === 'general' && <GeneralTab settings={settings} onChange={onChange} />}
    </motion.div>
  </AnimatePresence>
</Tabs.Panel>
```

- [ ] **Step 8: Stagger, press, status, and permission glow**

1. In each of the three tab components, wrap the outer `Stack`'s children: the `Stack` goes inside `<StaggerGroup>`, and each direct child (heading block, each glass card, the textarea) inside `<StaggerItem>`.
2. Wrap every `Button` in `SetupTab.tsx` in `<Pressable>`.
3. Status line in `TabRail.tsx`: replace the `Text` with a keyed, animated one and a drawn check:

```tsx
<AnimatePresence mode="wait" initial={false}>
  <motion.div
    key={needsSetup ? 'setup' : 'ready'}
    initial={{ opacity: 0, y: 4 }}
    animate={{ opacity: 1, y: 0 }}
    exit={{ opacity: 0, y: -4 }}
    transition={{ duration: DURATION.fast, ease: EASE }}
  >
    <Group gap={4} wrap="nowrap">
      {!needsSetup && (
        <svg width="12" height="12" viewBox="0 0 12 12" fill="none" aria-hidden="true">
          <motion.path
            d="M2 6.5 5 9.5 10 3"
            stroke="currentColor"
            strokeWidth="1.6"
            strokeLinecap="round"
            strokeLinejoin="round"
            initial={{ pathLength: 0 }}
            animate={{ pathLength: 1 }}
            transition={{ duration: DURATION.slow, ease: EASE }}
          />
        </svg>
      )}
      <Text size="xs" c={needsSetup ? 'yellow' : 'teal'}>
        {needsSetup ? 'Setup needed' : 'Ready'}
      </Text>
    </Group>
  </motion.div>
</AnimatePresence>
```

Give the `Group` `c={needsSetup ? 'yellow' : 'teal'}` so the check inherits the colour through `currentColor`.

4. Permission glow in `SetupTab.tsx`'s `PermissionRow`: glow once when `granted` flips from false to true.

```tsx
const wasGranted = useRef(granted);
const [justGranted, setJustGranted] = useState(false);

useEffect(() => {
  if (granted && !wasGranted.current) {
    setJustGranted(true);
    const timer = setTimeout(() => setJustGranted(false), 1200);
    wasGranted.current = granted;
    return () => clearTimeout(timer);
  }
  wasGranted.current = granted;
}, [granted]);
```

Give the row's outer `Stack` `className={justGranted ? classes.glow : undefined}` (import the CSS module).

and add to `settings.module.css` so the glow eases out rather than snapping:

```css
.glow {
  animation: glow-settle 1200ms cubic-bezier(0.22, 1, 0.36, 1) forwards;
}

@keyframes glow-settle {
  from {
    box-shadow: 0 0 0 1px var(--app-aurora-cyan), 0 0 24px -4px var(--app-aurora-violet);
  }
  to {
    box-shadow: 0 0 0 1px transparent, 0 0 0 0 transparent;
  }
}

@media (prefers-reduced-motion: reduce) {
  .glow {
    animation: none;
  }
}
```

Replace the static `.glow` rule from Task 9 with this one.

- [ ] **Step 9: Run the gates**

Run: `npx vitest run src/settings && npm run type-check && npm run lint && npm run ui-lint`
Expected: PASS, exit 0. `MotionGlobalConfig.skipAnimations` (Task 1) makes exits instant, so the existing tab tests need no waits.

- [ ] **Step 10: Check in the real app**

Run: `make dev`, open Settings.
Expected: the pill glides between tabs; content slides up going down the rail and down going up; cards arrive 40 ms apart; buttons dip on press; revoking then granting a permission in System Settings makes that row glow once and the status line redraw its check. Then enable System Settings, Accessibility, Display, Reduce Motion: everything still works with fades only and the mini orb drifts slower.

- [ ] **Step 11: Commit**

```bash
git add src/settings
git commit -m "feat: spring motion across the settings window"
```

---

### Task 11: Full gate and docs

**Files:**
- Modify: `docs/MANUAL_CHECKLIST.md`, `docs/superpowers/specs/2026-09-22-premium-ui-orb-design.md`

- [ ] **Step 1: Run the full gate**

Run: `make check`
Expected: exit 0. Fix anything it names. Likely candidates: `doc-lint` or `doc-links` on new docs, `storybook-lint` R8/R10, `ui-probe` thresholds on the restyled settings surfaces. Fix the cause; do not add exemptions.

- [ ] **Step 2: Record the manual checks**

Append to `docs/MANUAL_CHECKLIST.md`, matching that file's existing heading and list style:

```markdown
## Orb and settings visuals

- Hold the gesture and speak: the orb flows with the voice and its outline does not pulse.
- The orb's glow is never cut off by the window edge, over light and dark wallpapers.
- Release: the orb swirls while transcribing, flashes teal, fades. The text field keeps focus throughout.
- Settings opens with no white flash; wallpaper blurs through the glass.
- The tab pill slides; tab content slides in the direction of travel.
- With Reduce Motion on, the app uses fades only and the orb drifts slower.
```

- [ ] **Step 3: Mark the spec implemented**

In the spec, change `Status: approved design, pending implementation plan` to `Status: implemented`.

- [ ] **Step 4: Commit**

```bash
git add docs
git commit -m "docs: manual checks for the orb and settings visuals"
```
