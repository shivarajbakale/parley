<!-- principle:depth-and-materials:v1 -->

# Depth and Materials

What separates an app that looks designed from one that looks assembled is
rarely colour. It is whether the surfaces sit at believable heights.

## The failure this prevents

**Flat cards on a flat background.** One surface colour, one shadow value, and
every element at the same apparent height, so nothing tells the eye what is
above what. The dashboard is the current example: a hero card and six identical
tiles, all at the same elevation, so the screen reads as a wall rather than a
hierarchy.

The second failure is the overcorrection: shadow on everything, glass on
everything, gradients on everything. Depth is a contrast effect. Spending it
everywhere is the same as not having it.

## The surface ladder

Five levels. A screen normally uses three of them.

| Level | Token | What lives here |
| --- | --- | --- |
| 0 — ground | `surface` | the page background |
| 1 — raised | `surfaceContainerLow` | cards, grouped list containers |
| 2 — floating | `surfaceContainer` | sheets, menus, dialogs |
| 3 — chrome | glass / `surfaceContainerHigh` | nav bar, tab bar, app bar, FAB |
| 4 — transient | `surfaceContainerHighest` | snack bars, toasts |

Two rules:

1. **Adjacent levels only.** A dialog (2) over a card (1) is legible. A dialog
   over a snack bar is not a hierarchy, it is a collision.
2. **A level is a colour *and* a shadow.** `AppShadows.resolve` pairs them.
   Raising a surface's colour without raising its shadow gives you a lighter
   rectangle, not a higher one.

### The colour half of it does not always point the same way

In dark, the page is the darkest thing on screen and a raised surface steps
toward light, so tone alone reads as height.

In light, the page is **white**. Nothing is above white, so `surface` steps
*down* from `canvas` — far enough to clear 1.20:1, which is what lets a card
be found by its own edge — and the shadow does the whole job of saying it is
above. This is the one place the two themes are not mirror images, and it is
why rule 2 is not optional in light: a light card with its shadow removed is
indistinguishable from a recess.

## Shadows

`lib/theme/app_shadows.dart` holds the contract: elevations `none` (0), `low`
(1), `medium` (2), `high` (4), `highest` (8), each with a light and a dark
variant, plus `sheet()` for a surface that rises from the bottom edge and
therefore casts *upward*.

Two things to know:

- **Dark mode is not the same shadow, dimmer.** A shadow works by darkening
  what is behind it, and on a dark surface there is nothing left to darken. The
  dark ramp leans on the surface colour stepping up instead, which is why the
  dark values are not a scaled copy of the light ones. Do not "simplify" them
  into one set.
- **A real shadow is two shadows.** A tight, dark contact shadow directly under
  the element, plus a wide, soft ambient one. One blurred rectangle is the
  single most recognisable tell of a UI that was not designed. Every ramp in
  `AppShadows` is exactly `[contact, ambient]` for this reason, and a test
  asserts it — a later simplification back to one layer fails.

`ui_lint` rule `hardcoded-shadow` fails an inline `BoxShadow`. Two of them
existed before the rule; one was the bottom sheet's, lifting in a direction the
contract did not have. That is the normal way this goes wrong — not somebody
ignoring the contract, but the contract missing a case.

## Glass — the rule that keeps it premium

**Glass belongs to the navigation and control layer that floats above content.
Content stays opaque.**

This is Apple's own guidance for Liquid Glass and it is the whole difference
between "current" and "noisy". Glass earns its cost by saying *this floats*.
If the cards are glass too, nothing floats.

| May be glass | Must not be glass |
| --- | --- |
| bottom nav bar, tab bar | cards, tiles, stat cards |
| large / collapsing app bar | list rows |
| bottom sheets and their handles | form fields |
| dialogs, menus, the FAB | anything holding body text |
| a pinned action bar over content | full-screen backgrounds |

One exception in practice: **`DSDialog` is on the "may" side of the table and
is deliberately opaque anyway.** `AlertDialog` owns its own Material and its
route semantics, and wrapping it to blur what is behind would either cost those
or blur the whole barrier. It takes the platform shape and the floating surface
level instead. "May" is permission, not obligation, and a material is never
worth an announced semantic.

Three further constraints:

- **Legibility wins.** Text on glass needs a scrim behind it or a bolder
  weight, and glass over a busy photo needs more blur, not more transparency.
  If a label is hard to read, the material is wrong — not the colour.
- **Never nest glass in glass.** Two translucent layers stack their blurs and
  produce mud.
- **Fall back to opaque** when `MediaQuery.highContrastOf(context)` is set, or
  when `disableAnimations` is on. Translucency is a preference, and the OS
  already asked.

### Why it is built here rather than taken from a package

Flutter has no official Liquid Glass API — the Cupertino rebuild is roadmapped
for late 2026 and closed to contributions. The community shader packages
(`liquid_glass_widgets`, `cupertino_liquid_glass`) work, but they are a
dependency and a shader-compatibility risk in a project whose entire job is to
be a clean starting point.

`BackdropFilter(ImageFilter.blur)` plus a saturation `ColorFilter.matrix` plus
a hairline specular gradient along the top edge gets most of the way, uses only
the SDK, and cannot break on a Flutter upgrade in a way we cannot fix.

**The cost is real, so it is bounded:** a `BackdropFilter` reads back the
layer under it every frame. That is fine for a nav bar and a sheet. It is not
fine for fifty list rows, which is the other reason content stays opaque.

## Gradients

One per screen, at most, and only on a surface that is the screen's subject —
a hero card, an onboarding panel. `AppColors.heroGradient` exists for this. A
gradient on an error state, a settings row, or six tiles at once is decoration
applied where meaning was needed.

## Enforcement

| Rule | Where |
| --- | --- |
| no inline `BoxShadow` | `ui_lint` `hardcoded-shadow` |
| no literal colour or hex | `ui_lint` `hardcoded-color`, `hardcoded-hex` |
| no hand-typed radius | `ui_lint` `hardcoded-radius` |
| glass only on chrome | `ui_lint` `glass-off-chrome` — the table above is the `_chromeLayer` allowlist |
| a shadow is two layers | a test over every ramp in `AppShadows`; goldens catch the rest |
