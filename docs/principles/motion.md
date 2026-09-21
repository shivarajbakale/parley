<!-- principles:v1 -->

# Motion principles

Motion in this app is **token-driven**, **purposeful**, and
**reduced-motion-aware**. Every transition communicates a state change
(open / closed / loading / done); nothing animates for decoration.

> Source: Mantine's transition defaults + WCAG 2.3.3 (Animation from
> Interactions).

## Duration scale

| Token | ms | Used for |
| --- | --- | --- |
| `duration-0` | 0 | Disabled / no animation (instant) |
| `duration-100` | 100 | Tiny state changes (toggle, focus ring) |
| `duration-200` | 200 | Default UI transition (hover, menu open) |
| `duration-300` | 300 | Page-level transitions, modal open/close |
| `duration-500` | 500 | Emphasis only (confirmation, success toast) |

Anything off this scale (`duration-[150]`, `transition-all duration-700`)
is banned by `ui-lint`'s `raw-duration` rule.

## Easing

Two default easings, plus the explicit `spring`:

- `ease-out` — for entrance animations (open, appear)
- `ease-in` — for exit animations (close, leave)
- `spring` — for playful / physical interactions (toggle, drag, swipe)
- `linear` — banned. Nothing in this app needs linear motion.

CSS names these `ease-in`, `ease-out`, `linear`. Use them by name; Mantine's
own transitions read `--mantine-transition-duration` and its easing.

## What animates, what doesn't

| Pattern | Animate? | Why |
| --- | --- | --- |
| Hover state (button bg, link color) | Yes (100ms, ease-out) | Feedback |
| Focus ring | Yes (100ms, ease-out) | Accessibility hint |
| Dropdown menu open / close | Yes (200ms, ease-out / ease-in) | Spatial continuity |
| Dialog / Sheet open / close | Yes (300ms, ease-out / ease-in) | Big state change |
| Toast appear | Yes (200ms, ease-out) | Notification |
| Toast dismiss | Yes (200ms, ease-in) | Subtle |
| Tab switch | No | Content swap is instant |
| Page navigation | No | Route change is instant (no flash) |
| Form submit → success toast | Yes (200ms in / 200ms out) | Confirmation |
| Skeleton shimmer | Yes (1500ms loop, ease-in-out) | Loading signal |
| Chart redraw on data change | Yes (300ms) | Data continuity |
| Loading spinner | Yes (infinite, 1000ms) | Wait signal |

## `prefers-reduced-motion`

WCAG 2.3.3 requires the app to be usable when the user has reduced
motion enabled at the OS level. Mantine handles its own components — set
`respectReducedMotion` on the provider, which `src/theme.ts` does:

- `Modal`, `Drawer`, `Menu`, `Tooltip` and every other `Transition` consumer
  snap open / closed with no animation under `prefers-reduced-motion: reduce`.
- `Loader` reads the same setting, which is why `AuthGuard` uses it rather than
  a hand-spun ring.

For custom animations, wrap with the
`@media (prefers-reduced-motion: reduce)` rule:

```css
@media (prefers-reduced-motion: reduce) {
  .my-component { animation: none; transition: none; }
}
```

## Skeletons, not spinners

A spinner says "wait." A skeleton says "this is where the content will
appear." Skeletons are better because they:

- Preserve the layout (no shift when data arrives).
- Communicate the data shape (a list skeleton shows row count).
- Reduce perceived latency (the user sees structure immediately).

Use the `Skeleton` atom for any loading state where the data shape is
known. Use a `<Spinner>` only when the action takes > 1 second AND the
shape isn't predictable (e.g. a long-running export).

## Hover transitions

Three classes of hover:

1. **Background change** — `transition-colors duration-100`. The bg
   shifts to the hover variant of the token.
2. **Elevation** — `transition-shadow duration-200`. A shadow grows on
   hover (cards, dropdowns). Don't elevate on every button — only on
   surfaces that benefit from a sense of lift.
3. **Scale** — banned. Buttons don't scale on hover. Hover = colour or
   ring, not size.

## Don'ts

- **Don't animate decorative elements.** A spinning logo, a bouncing
  bear, a parallax scroll — none of these belong.
- **Don't animate multiple properties at once.** `transition-all` is
  banned; specify the property (`transition-colors`,
  `transition-opacity`).
- **Don't use durations longer than 500ms.** Anything past that feels
  laggy. If the transition is "important", use a toast + icon, not a
  longer duration.
- **Don't animate `width` or `height`.** Animate `transform` (scale,
  translate). Width/height trigger layout; transform doesn't. Use
  `scale-x-*` or `translate-x-*` for reveals.
- **Don't animate on every interaction.** Hover? Yes. Click? No. The
  click is the user's action; let it be instant.

## Verify

1. Every interactive element has a hover state that's visible within
   100ms.
2. Every modal / dropdown animates open AND closed (not just open).
3. With `prefers-reduced-motion: reduce` enabled, no animation runs
   longer than 100ms.
4. With the DevTools "Slow 3G" throttling, the skeleton shows within
   200ms (not the page being blank).
5. Tab through the app — focus rings transition smoothly; no "jumps".

See `ux-prepass` for the mandatory UI gates.
