import { createTheme, type CSSVariablesResolver, type MantineColorsTuple } from '@mantine/core';

/**
 * The Mantine theme — the single source of colour, radius and type.
 *
 * The palette is the one this starter already shipped (see the token block in
 * `src/App.css`): near-black cool neutrals, one indigo accent, a tight radius.
 * It is expressed here as Mantine tuples so that every component inherits it
 * without a wrapper, which is the whole reason the shadcn kit could be deleted.
 *
 * Tuples run light (index 0) to dark (index 9). `primaryShade` picks which
 * index a filled Button, a checked Checkbox and a focus ring actually use —
 * 7 in light mode and 6 in dark, which reproduces the two `--primary` values
 * the old stylesheet declared per scheme.
 */

/** Indigo accent. Index 6 is `oklch(0.62 0.19 277)` — the old dark `--primary`. */
const brand: MantineColorsTuple = [
  'oklch(0.97 0.02 277)',
  'oklch(0.94 0.04 277)',
  'oklch(0.89 0.07 277)',
  'oklch(0.83 0.11 277)',
  'oklch(0.76 0.15 277)',
  'oklch(0.69 0.18 277)',
  'oklch(0.62 0.19 277)',
  'oklch(0.54 0.2 277)',
  'oklch(0.48 0.18 277)',
  'oklch(0.42 0.15 277)',
];

/**
 * The neutral ramp Mantine paints dark mode with. Mantine reads specific
 * indices for specific jobs, so these are not free choices:
 *   dark[0]  body text            dark[4]  hairline borders
 *   dark[3]  dimmed text          dark[6]  hovered / raised surface
 *   dark[7]  page background      dark[8]  the surface behind that
 */
const dark: MantineColorsTuple = [
  'oklch(0.98 0 0)',
  'oklch(0.88 0.004 285)',
  'oklch(0.78 0.005 285)',
  'oklch(0.68 0.006 285)',
  'oklch(0.42 0.005 285)',
  'oklch(0.32 0.004 285)',
  'oklch(0.25 0.004 285)',
  'oklch(0.2 0.004 285)',
  'oklch(0.165 0.004 285)',
  'oklch(0.12 0.004 285)',
];

/*
 * The three semantic ramps, overriding Mantine's stock `green`/`yellow`/`red`
 * rather than living beside them under new names. Mantine reaches for `red` by
 * itself — a TextInput's error state, a destructive Button — so a parallel
 * `danger` colour would leave half the app on this palette and half on
 * Mantine's. The old `--success` / `--warning` / `--destructive` values sit at
 * the two indices `primaryShade` selects: 6 in dark, 7 in light.
 */
const green: MantineColorsTuple = [
  'oklch(0.96 0.03 155)',
  'oklch(0.92 0.06 155)',
  'oklch(0.86 0.09 155)',
  'oklch(0.8 0.12 155)',
  'oklch(0.74 0.14 155)',
  'oklch(0.7 0.15 155)',
  'oklch(0.64 0.16 155)',
  'oklch(0.6 0.16 155)',
  'oklch(0.52 0.14 155)',
  'oklch(0.44 0.11 155)',
];

const yellow: MantineColorsTuple = [
  'oklch(0.97 0.03 70)',
  'oklch(0.94 0.06 70)',
  'oklch(0.9 0.1 70)',
  'oklch(0.85 0.13 70)',
  'oklch(0.8 0.15 70)',
  'oklch(0.77 0.16 70)',
  'oklch(0.75 0.16 70)',
  'oklch(0.7 0.17 70)',
  'oklch(0.6 0.15 70)',
  'oklch(0.5 0.13 70)',
];

const red: MantineColorsTuple = [
  'oklch(0.96 0.02 25)',
  'oklch(0.92 0.05 25)',
  'oklch(0.86 0.09 25)',
  'oklch(0.8 0.13 25)',
  'oklch(0.73 0.17 25)',
  'oklch(0.69 0.19 25)',
  'oklch(0.65 0.2 25)',
  'oklch(0.58 0.22 27)',
  'oklch(0.5 0.2 27)',
  'oklch(0.43 0.17 27)',
];

export const theme = createTheme({
  primaryColor: 'brand',
  primaryShade: { light: 7, dark: 6 },
  colors: { brand, dark, green, yellow, red },

  /*
   * WCAG 2.3.3. Mantine's default is `false`, so every Transition consumer —
   * Modal, Drawer, Menu, Tooltip, Loader — animated regardless of the OS
   * setting. `AuthGuard` already said in a comment that its `Loader` respected
   * this; that comment was describing an intention. It is a fact now.
   *
   * Reduced motion is an OS setting: the user told every app on the machine,
   * and this one has no standing to be the tasteful exception.
   */
  respectReducedMotion: true,

  defaultRadius: 'md',
  radius: { xs: '0.25rem', sm: '0.375rem', md: '0.5rem', lg: '0.75rem', xl: '1rem' },

  fontFamily:
    "'Inter', ui-sans-serif, system-ui, -apple-system, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif",
  fontFamilyMonospace:
    "'Geist Mono', ui-monospace, 'SF Mono', 'JetBrains Mono', Menlo, Consolas, monospace",
  headings: { fontWeight: '600' },

  /** Mantine picks black or white text on a filled surface by contrast, not by guess. */
  autoContrast: true,

  components: {
    /*
     * `data-panel` is the ui-probe's hook — it measures every element carrying
     * one and checks its bounds, padding and hierarchy. The local `Card` atom
     * sets `data-panel="card"` by default, which is the only reason the probe
     * sees anything without every screen opting in. Defaulting it here means
     * the probe keeps seeing surfaces as screens move from that atom to
     * Mantine's, rather than going quiet somewhere in the middle of the
     * migration; a screen still passes its own (`data-panel="hero"`, `"kpi"`)
     * to say what a particular surface is.
     */
    Paper: { defaultProps: { bg: 'var(--app-surface)', 'data-panel': 'card' } },
    Card: { defaultProps: { bg: 'var(--app-surface)', 'data-panel': 'card' } },

    /*
     * The same argument, for the other thing the probe reads off the DOM.
     *
     * Mantine renders `data-variant` only when a `variant` prop is actually
     * passed — so `<Button type="submit">`, the accented primary on every form
     * in the app, publishes nothing. It looks filled and declares nothing, and
     * a rule asking "which button is the primary here?" cannot answer.
     * Probe rule B3 found no submit on any form; C5 could not have seen two
     * real primaries either.
     *
     * Naming the implicit default here makes the DOM say what the pixels
     * already say. It changes no rendering: `filled` is what Button falls back
     * to internally.
     */
    Button: { defaultProps: { variant: 'filled' } },

    /*
     * A `SegmentedControl` label neither wraps nor pushes the control wider —
     * it clips, so the last thing in a label is the thing that disappears. In
     * a filter row the last thing is always the count, and three of this app's
     * visible defects were exactly that: `Active 19` rendered as `Active 1`,
     * which is wrong rather than merely missing, and the Inbox counts squeezed
     * to slivers.
     *
     * Fixed once, here, rather than by every page remembering to guard its own
     * label. That is the difference between a theme decision and a wrapper
     * component: a wrapper only protects the pages that remember to use it.
     */
    SegmentedControl: {
      styles: {
        /*
         * And the track needs a ground. Mantine paints it `dark[8]`, which is
         * one step below the page in a stock theme and is *the page* in this
         * one (see the resolver below). The control came out flush with the
         * background: no track, no edges, just the labels and the hairlines
         * between them, which is exactly what a reader means by hand-rolled.
         * `--app-control` is a step above both the page and a Card, because
         * this control appears on each — grounding it on `--app-surface` fixed
         * the Inbox and left Billing's plan toggle flush inside its panel.
         * Probe rule C7 fails the page if any Mantine surface lands back on
         * the colour immediately behind it.
         */
        root: { backgroundColor: 'var(--app-control)' },
        label: { whiteSpace: 'nowrap' },
      },
    },

    /*
     * The same defect, and the worse one: a tooltip floats *over* the chart, so
     * a tooltip the colour of the page is a box of numbers with no box.
     */
    ChartTooltip: {
      styles: {
        tooltip: { backgroundColor: 'var(--app-control)' },
      },
    },
  },
});

const aurora = {
  // One indigo-violet hue at three depths; the orb and the UI accents share it.
  '--app-aurora-deep': 'oklch(0.42 0.2 280)',
  '--app-aurora-core': 'oklch(0.6 0.22 287)',
  '--app-aurora-glow': 'oklch(0.8 0.12 295)',
  // Each mode wears its own hue so the orb says what it is doing at a glance.
  // Voice edit is amber: warm, far from dictation's indigo.
  '--app-edit-deep': 'oklch(0.56 0.15 50)',
  '--app-edit-core': 'oklch(0.76 0.16 68)',
  '--app-edit-glow': 'oklch(0.9 0.1 85)',
  // Explain is cyan, kept clear of the teal the orb flashes on done.
  '--app-explain-deep': 'oklch(0.5 0.12 235)',
  '--app-explain-core': 'oklch(0.72 0.13 225)',
  '--app-explain-glow': 'oklch(0.88 0.08 215)',
  '--app-aurora-gradient':
    'linear-gradient(120deg, var(--app-aurora-deep), var(--app-aurora-core))',
};

/*
 * Mantine builds each ramp's dark `-light` and `-light-hover` variables with
 * `darken()`, which parses hex, rgb and hsl only. Handed these oklch ramps it
 * returns `rgba(0, 0, 0, 1)`, so every light Badge and Button in dark mode
 * came out solid black. A tint of the filled shade is what Mantine meant.
 */
const darkLightVariants = Object.fromEntries(
  ['brand', 'green', 'yellow', 'red'].flatMap(name => [
    [`--mantine-color-${name}-light`, `color-mix(in oklab, var(--mantine-color-${name}-6) 18%, transparent)`],
    [`--mantine-color-${name}-light-hover`, `color-mix(in oklab, var(--mantine-color-${name}-6) 26%, transparent)`],
  ])
);

/**
 * Mantine paints Paper and Card with `--mantine-color-body`, which makes a card
 * the same tone as the page behind it. This starter's design separates them by
 * one step, so the raised surface gets its own variable and those two
 * components default to it (see `components` above).
 *
 * `--app-control` is the third step: the ground under a control that can appear
 * either on the page or inside a Card, so it has to clear both. Mantine's own
 * answer is `dark[8]`, which this theme has spent on the page itself, and a
 * control the colour of its background is a control the reader cannot see.
 *
 * The aurora tokens (`--app-aurora-deep`, `--app-aurora-core`, `--app-aurora-glow`,
 * `--app-aurora-gradient`) and glass tokens (`--app-glass`, `--app-glass-hover`,
 * `--app-glass-border`) are also declared here.
 *
 * This is a `MantineProvider` prop, not part of `createTheme` — it is exported
 * separately and passed alongside `theme` in `components/theme-provider`.
 */
export const cssVariablesResolver: CSSVariablesResolver = t => ({
  variables: aurora,
  light: {
    '--app-surface': t.white,
    '--app-control': t.colors.gray[1],
    '--app-tint-bg': 'oklch(0.97 0.015 287)',
    '--app-glass': 'color-mix(in oklab, white 72%, transparent)',
    '--app-glass-hover': 'color-mix(in oklab, white 86%, transparent)',
    '--app-glass-border': 'color-mix(in oklab, black 10%, transparent)',
  },
  dark: {
    ...darkLightVariants,
    '--mantine-color-body': t.colors.dark[8],
    /*
     * Mantine's dimmed text is `dark[2]`; the ramp above reserves `dark[3]` for
     * it, and that is the value this starter has always used for
     * `--muted-foreground`. Left at Mantine's default, secondary text came out
     * one step *lighter* than the primary text it sits under is dark, and the
     * page collapsed to two contrast levels — probe rule C4 failed every
     * Projects story for exactly that, reporting `levels=2 ratios=17.7, 21`.
     */
    '--mantine-color-dimmed': t.colors.dark[3],
    '--app-surface': t.colors.dark[7],
    '--app-control': t.colors.dark[6],
    '--app-tint-bg': 'oklch(0.19 0.045 285)',
    '--app-glass': 'color-mix(in oklab, white 6%, transparent)',
    '--app-glass-hover': 'color-mix(in oklab, white 10%, transparent)',
    '--app-glass-border': 'color-mix(in oklab, white 12%, transparent)',
  },
});
