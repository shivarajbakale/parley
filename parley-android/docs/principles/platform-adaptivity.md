<!-- principle:platform-adaptivity:v1 -->

# Platform Adaptivity

One app, two skins. The same widget tree, the same providers, the same tests —
and chrome that looks like it belongs to the operating system it is running on.

This is the principle the other five sit on top of, because it decides what
"correct" even means for a shadow, a corner or a page transition.

## The failure this prevents

An app that is visibly a Flutter app. Material chrome on an iPhone reads as
foreign in a way users cannot name but do notice: the wrong back gesture, the
wrong corner curve, a ripple where there should be a press-dim. The reverse is
just as bad — an iOS-shaped app on Android looks unfinished rather than
premium.

The app used to have the opposite problem in its purest form: no platform
branch anywhere outside `app_theme.dart`, and the same Material chrome shipped
to both. `lib/theme/app_platform.dart`, `app_materials.dart`,
`app_springs.dart` and `app_shapes.dart` are where that branch now lives —
and they are the only place it may live.

## The rule

**Branch on the platform for chrome, geometry and motion. Never branch for
structure, content or behaviour.**

| Branch on platform | Never branch on platform |
| --- | --- |
| the material behind a nav bar or sheet | which screens exist |
| corner geometry (squircle vs rounded rect) | what a screen contains |
| page transition and the back gesture | route names or navigation structure |
| press feedback (dim vs ripple) | validation rules, copy, ordering |
| the shape of a switch or a picker | whether a feature is available |

A branch that changes what the app *does* is two apps to test and two apps to
support. A branch that changes how it *feels* is what makes it feel native.

## How to branch

Through the theme and through the design system, never in a screen.

```dart
// In lib/theme/ or lib/design_system/ — one call, greppable.
AppPlatform.select(context, cupertino: …, material: …)
```

Three things are banned in `lib/screens/`:

- `Platform.isIOS` / `dart:io` — it is wrong on web, and it reads the *device*
  rather than the *theme*, so it ignores a `TargetPlatform` override and breaks
  every widget test that sets one.
- `Theme.of(context).platform` scattered inline — the same check written five
  ways is five things to find when the rule changes.
- A `CupertinoApp`. The app stays `MaterialApp.router`, because the Material
  widget layer is what the entire design system is built on and a second app
  widget would mean maintaining both.

`AppPlatform` treats iOS and macOS as one side and everything else as the
other. Web takes the Material side: a browser is not an operating system, and a
squircle on a desktop browser is a costume.

## What "native" means on each side, in 2026

### Apple — Liquid Glass

Since iOS 26 the system chrome is a translucent material that refracts and
blurs what is behind it, with a specular highlight along its top edge. Tab
bars, navigation bars, sheets and toolbars float above the content rather than
sitting in a band beside it.

**The rule that keeps this premium rather than noisy, and it is Apple's own:
glass belongs to the navigation and control layer that floats above content.
Content stays opaque.** Glass on every card is the 2026 version of a gradient
on every card — it destroys the depth cue by spending it everywhere. See
[depth-and-materials.md](depth-and-materials.md), which is where that rule is
stated as a contract with a list of who may use it.

Geometry is the other half: Apple's corners are continuous curves
(superellipses), not circular arcs. Flutter 3.47 ships
`RoundedSuperellipseBorder`, so this costs nothing but using it.

Flutter has **no official Liquid Glass API**. The Cupertino rebuild is on the
roadmap for late 2026 and the team is not accepting contributions for it. So
the app builds its own on `BackdropFilter` — see
[depth-and-materials.md](depth-and-materials.md) for why that beats taking a
shader package.

### Android — Material 3 Expressive

The 2025 update to Material moved motion from timed curves to **spring
physics**, widened the shape scale, and made emphasis a first-class idea: the
one important control on a screen is allowed to be visibly larger, rounder or
louder than its neighbours.

A spring is defined by stiffness and damping, not by a duration, which is why a
spring interrupted mid-flight continues from where it is rather than snapping.
That is the difference a user reads as "responsive" without being able to say
why.

Flutter 3.47 also ships `FadeForwardsPageTransitionsBuilder`, the M3 Expressive
page transition, and the app does not currently use it.

## Where the differences actually land

| | Apple | Android |
| --- | --- | --- |
| Nav bar, tab bar, sheet | glass over content | tonal `surfaceContainer` |
| Corners | continuous (superellipse) | circular, at the larger M3 radii |
| Page push | slide from right + edge-swipe back | fade-forwards |
| Press feedback | opacity dim | ink ripple |
| State change motion | ease curves | springs |
| Minimum tap target | 44×44pt | 48×48dp |
| Switch, date picker, time picker | Cupertino shape | Material shape |

Both sides take the same tokens for colour, spacing and type. Adaptivity is
about material, shape and motion — not about having two palettes.

## The escape hatch

A screen may not branch. If one genuinely needs to, the branch belongs in a
design-system widget, and the reason belongs in `DECISIONS.md`. The whole point
of putting adaptivity in the theme and the kit is that it can be tested by
setting one `TargetPlatform` in a widget test rather than by owning two
devices.

## Enforcement

- `ui_lint` rule `raw-*` keeps screens on design-system widgets, which is where
  the branch lives.
- Goldens (`make golden`) render each screen under both platforms, so a
  regression on the side you are not holding still fails.
- `AGENTS.md` constraint 7 is the prose version of the same rule.
