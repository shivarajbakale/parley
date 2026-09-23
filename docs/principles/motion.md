<!-- principle:motion:v1 -->

# Motion

Motion's job is to explain what just happened: where this came from, what it
turned into, what is still loading. Motion that does not answer one of those
questions is delay with a curve on it.

## The failure this prevents

**Everything animating.** If every element eases, nothing reads as intentional
and the app feels slower than a static one, because the user is waiting for
decoration.

The second failure is the one this codebase actually had: **the same gesture
timed differently in different components.** `ui_lint`'s first run found three
cascade speeds — 45ms, 30ms and 50ms in three list components — and nine
hand-typed durations. A list of cards and a list of suggestions scrolling past
each other at different rhythms is a system that does not feel like one system.

## The scale

`lib/theme/app_motion.dart`. Every duration in the app is one of these.

| Token | ms | For |
| --- | --- | --- |
| `instant` | 100 | a state flip the user should barely see |
| `press` | 120 | the press-down |
| `pressRelease` | 180 | the release back |
| `fast` | 200 | hover, selection, small local changes |
| `routeExit` | 220 | a page leaving |
| `routeEnter` | 280 | a page arriving |
| `normal` | 300 | expand/collapse, sheets, dialogs |
| `revealStep` | 45 | one step of the onboarding art filling in |
| `slow` | 500 | a full-screen transition |
| `shimmer` | 1200 | one skeleton shimmer pass |

Curves: `enter` (`easeOutCubic`) for things arriving, `exit` (`easeInCubic`)
for things leaving, `emphasize` for the one movement that matters,
`standard` for everything else.

**Enter slower than exit.** Something arriving needs to be understood;
something leaving is already understood. 280 in, 220 out.

## Springs, on Android

Material 3 Expressive replaced timed curves with spring physics for state
change, and it is the single biggest reason a 2026 Android app feels current.

A spring is stiffness and damping, not a duration. The property that matters:
**a spring interrupted mid-flight continues from where it is**, while a curve
restarts or snaps. That is what a user reads as responsive.

Use springs for: press and release, selection, sheet drag settle, FAB
expansion, reordering. Keep curves for: fades, cross-dissolves, shimmer,
anything crossing a route boundary.

Apple keeps the ease curves — the platform's own animations are curve-based and
a bouncing tab bar on iOS looks like a bug.

## Press

One component. `DSPressable` in
`ds_pressable.dart` owns the dip under a finger — 0.97, a spring on Android and
a curve on Apple, nothing at all under reduced motion — and the widgets that
need it wrap it rather than writing their own. Fifteen widgets writing their own
is fifteen slightly different presses, which is what "assembled rather than
designed" feels like.

It **observes** the press from a `Listener` and never takes the tap, so
wrapping something tappable cannot change what tapping it does.

Rows are the deliberate exception. A full-bleed list row that shrinks away from
its neighbours detaches from the column it belongs to; a row is pressed by
lighting up, which is what both platforms do.

## Entrances

Content does not animate in. A list, a card or a screen is on screen the
frame it is ready: no fade, no slide, no cascade. An entrance is decoration
the reader waits through on every visit, and it tells them nothing.

Motion is kept for feedback — a press, a toggle, an indicator travelling, a
sheet or a page arriving — where the movement says what just changed.

## Reduced motion

`MediaQuery.disableAnimationsOf(context)`. When it is set:

- page transitions become cross-fades
- shimmer becomes a static placeholder
- glass falls back to opaque (see [depth-and-materials.md](depth-and-materials.md))

Nothing becomes *slower*, and nothing is removed that carried meaning. The user
asked for less movement, not for less information.

## Haptics

Through `AppHaptics`, never `HapticFeedback` directly — `ui_lint` rule
`raw-haptic` fails that — because `AppHaptics.enabled` is what the user's
setting switches, and a direct call ignores it.

`selection` for picking, `light` for a confirmation, `medium` for a completed
action, `success`/`warning`/`error` for outcomes. **Haptics confirm; they do
not decorate.** A buzz on scroll is a battery drain the user cannot switch off
from inside your app.

## Enforcement

| Rule | Where |
| --- | --- |
| no hand-typed `Duration` | `ui_lint` `hardcoded-duration` |
| no hand-typed `Curves.*` | `ui_lint` `hardcoded-curve` |
| haptics go through the token | `ui_lint` `raw-haptic` |
| springs are Android-only, and off under reduced motion | `AppSprings.isAvailable`, asserted per platform |
| no entrance animation | the kit ships no reveal or stagger component to reach for |
| one press animation | `DSPressable` is the only one; a test asserts it dips, releases on a drag, and never takes the tap |
