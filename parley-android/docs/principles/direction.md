<!-- principle:direction:v1 -->

# Reading direction

About a fifth of the world reads right to left. Flutter will mirror a layout
for them for free — but only for the widgets that were told to think in
**start and end** rather than in **left and right**. Every physical direction
in the source is a place the mirror stops.

This is not a localisation task that arrives with the first Arabic string. The
day a layout is written is the only cheap day to get it right; after that it
is an audit of every screen.

## The rule

**Positions come from the reading direction. Geometry comes from the screen.**

| Physical, and wrong for layout | Directional, and correct |
| --- | --- |
| `EdgeInsets.only(left:, right:)` | `EdgeInsetsDirectional.only(start:, end:)` |
| `Positioned(left:, right:)` | `PositionedDirectional(start:, end:)` |
| `Border(left:, right:)` | `BorderDirectional(start:, end:)` |
| `Alignment.centerLeft` / `centerRight` | `AlignmentDirectional.centerStart` / `centerEnd` |
| `BorderRadius.only(topLeft:)` | `BorderRadiusDirectional.only(topStart:)` |
| `TextAlign.left` / `right` | `TextAlign.start` / `end` |

`ui_lint`'s `physical-direction` rule fails the build on the first four. It is
a source-pattern rule, so it catches what a regex can see; the reasoning below
is for everything else.

## What stays physical

Four things genuinely have no reading direction, and writing them the
directional way is worse, not better:

- **A symmetric inset.** `left: 0, right: 0` mirrors to itself, and so does
  `EdgeInsets.symmetric(horizontal:)`. The lint does not fire on a zero.
- **An already-resolved `EdgeInsets`.** `insets.resolve(Directionality.of(context))`
  returns physical values *because* it just consumed the direction; passing
  them on as `left`/`right` is the correct next step. Say so with the escape
  hatch — `// ui-lint: allow physical-direction — …` — as `ds_text_field.dart`
  does.
- **`Row` and `Column`.** They are already directional: `MainAxisAlignment.start`
  in a `Row` is the right-hand edge under RTL, with no work from the caller.
  This is why most of the kit needed no change at all.
- **A drawing.** A gradient across a decorative card, a shadow offset, the
  angle of an illustration. These are pictures, not layout; mirroring a
  drop shadow does not help anyone read.

The one gradient in the kit that *is* directional is `DSTabBar`'s scroll-edge
fade, and it is directional for a layout reason: it marks the end of a
scrollable, and the end of a scrollable moves.

## Text and numbers

- **Never `TextAlign.left`.** `start` is what you meant every time.
- **Numbers and Latin names inside RTL text are handled by the engine.** Do
  not reorder a string yourself; a manually reversed string is correct in one
  locale and broken in the other.
- **An icon that points is a direction.** A back chevron, a "next" arrow, a
  progress caret. `Icons.arrow_forward` mirrors automatically inside a
  directional layout only when it is drawn with `matchTextDirection` — the
  reliable move is to pick the icon from `Directionality.of(context)`, which
  is what `DSCompactAppBar`'s back affordance does via `BackButtonIcon`.
- **An icon that depicts does not.** A camera, a heart, a logo. Mirroring
  those makes an app look broken, not localised.

## Checking it

```dart
// Wrap any widget under test and the whole subtree flips.
Directionality(textDirection: TextDirection.rtl, child: subject)
```

A component test that pumps its subject under both directions is the cheapest
RTL coverage there is, and it catches the one class of defect the lint cannot
see: a widget that reads `Directionality` itself and gets the branch backwards.

The goldens are the other half. `make golden` renders LTR only today — an RTL
pass is worth adding the day the app ships a right-to-left locale, and until
then a per-component `Directionality` test is the honest level of coverage to
claim.

## The failure this prevents

A leading inset written as `left` lands on the trailing edge under RTL. The
label indents away from the field it labels, the avatar sits on the wrong side
of the name it belongs to, and the chevron at the end of a row points back the
way the user came. None of it crashes, none of it shows up in a test that only
asserts text, and all of it reads as an app that was translated but not
built for the reader.
