<!-- principle:spacing-and-type:v1 -->

# Spacing and Type

Most screens that "look off" are not badly designed. They are inconsistently
measured.

## The failure this prevents

Eight hand-typed corner radii against a seven-step scale — which is what
`ui_lint`'s first run found, and it is exactly why two cards on one screen did
not match. The same happens with padding: 12 here, 14 there, 16 in the third
place, and a screen that feels subtly wrong with nothing identifiable to point
at.

## The spacing scale

`lib/theme/app_spacing.dart`. A 4dp base, doubling where it matters.

| Token | Value | Use for |
| --- | --- | --- |
| `xs` | 4 | icon-to-label, inside a chip |
| `sm` | 8 | between related lines, chip gaps |
| `md` | 12 | inside a card, between list rows |
| `lg` | 16 | the page gutter, between cards |
| `xl` | 24 | between sections |
| `xxl` | 32 | above a section that starts a new idea |
| `xxxl` | 48 | before a screen-level primary action |

**`pageGutter` is `lg` (16) and every screen uses it.** Two screens with
different side margins is the first thing that reads as unfinished, and it is
invisible in review because you never see them side by side.

The composed insets — `pagePadding`, `cardPadding`, `listItemPadding`,
`sheetPadding`, `fabClearance` — exist so the common cases cannot drift. Reach
for those before composing an `EdgeInsets` by hand.

**Group by proximity, not by lines.** Space *within* a group is smaller than
space *between* groups; that ratio is what makes structure readable without a
single divider. A separator between two things already 24dp apart is telling
the user something they can see.

## The radius scale

`lib/theme/app_radius.dart`: `xs` 4, `sm` 6, `md` 10, `lg` 14, `xl` 20, `full`
999.

Radius carries meaning, so keep it consistent by *role*, not by taste: chips
and pills are `full`, cards are `lg`, inputs and small controls are `md`,
sheets take the larger top corners. The drag handle on a sheet is `full` —
a pill is not a rectangle with a 2dp radius.

On Apple these become continuous curves rather than circular arcs (see
[platform-adaptivity.md](platform-adaptivity.md)); the scale itself does not
change.

## The size ladder

`ComponentSpec` in `lib/theme/spec/component_spec.dart` owns every glyph and
box dimension the kit draws. Ask for a role, never a number:

| Token | Where the glyph sits |
| --- | --- |
| `iconSizeMicro` | inside a badge, or a chip's affordance |
| `iconSizeSmall` | inside a tab, a segment, beside a dense label |
| `iconSizeInline` | beside a label in a row, a menu, a field, a snack bar |
| `iconSize` | the default, and what an `IconTheme` hands anything that does not ask |
| `iconSizeLarge` | a section's or a sidebar's leading glyph |
| `glyphHero` | a splash or a paywall's headline glyph |

Above the ladder sit the named boxes — `grabberWidth`/`grabberHeight`,
`iconWellSize`, `leadingSlotSize`, `chipMaxWidth`, `wellSize`, `minTapTarget`,
`hairlineWidth` — for the shapes that repeat across components and used to be
re-typed in each one.

There is **one** tap-target floor: `ComponentSpec.minTapTarget`, 48, which
clears both vendor minimums. A minimum is a floor rather than a target, so a
control four points larger than Apple's 44 is not a defect; two disagreeing
floors in one kit is, and the kit had exactly that until `AppPlatform` lost its
own copy.

## Type

`lib/theme/app_typography.dart` — Satoshi, with Roboto as the fallback. Satoshi
ships at 300 / 400 / 500 / 700 / 900 and has **no Semibold**, which is why what
would be `w600` elsewhere is `w500` for titles and `w700` for a strong CTA.
Asking for 600 gets you a synthesised weight that looks muddy on Android.

Take styles from `Theme.of(context).textTheme` and adjust with `copyWith`.
`ui_lint` rule `hardcoded-text-style` fails an inline `TextStyle(fontSize:` or
`fontFamily:`.

### Two to three sizes per screen

More than three and the hierarchy stops being a hierarchy. A typical screen:

- one **headline** (`headlineMedium`, 28) — the screen's subject, once
- one **body** (`bodyLarge` / `bodyMedium`) — everything the user reads
- one **label** (`labelMedium` / `labelSmall`) — metadata, captions, eyebrows

Everything else is that same size at a different weight or opacity. Weight and
colour separate importance more cleanly than size does, and they do not disturb
the vertical rhythm.

### The opacity ladder

Three levels of text importance, and only three:

| | Value | Use |
| --- | --- | --- |
| Primary | `onSurface` at 100% | what the user came for |
| Secondary | ~60% | supporting detail, metadata |
| Tertiary | ~40% | placeholders, disabled, timestamps |

A fourth level is a level nobody can distinguish. Below 40% on a light surface
you are also below the 4.5:1 contrast floor — see
[accessibility.md](accessibility.md), which owns that number.

### Numbers

Anything that updates in place — a counter, a timer, a price — takes the
`tabular` getter on its style: `text.labelMedium?.copyWith(color: x).tabular`.
Proportional digits change width as they change value, so the layout jitters on
every tick. Writing `fontFeatures` out by hand is a `ui-lint` failure
(`raw-font-feature`) — twelve call sites did, while the text atom called the
helper, and one decision with two spellings has no single place to change it.

### Weight

A weight is a token, never a literal. `context.design.type` carries five of
them — `displayWeight`, `titleWeight`, `bodyWeight`, `labelWeight` and
`emphasisWeight` — and a component names the one that says what the weight is
*for*. `FontWeight.w700` in a widget is a `ui-lint` failure
(`raw-font-weight`), because the literals were copied from the `TypeSpec`
defaults and are therefore invisible under the brand they were written against
and wrong under the others: `signal` sets `emphasisWeight` to w900 and
`ledger` sets `titleWeight` and `labelWeight` to w700. The literal belongs in
`type_spec.dart` and in each brand's own `TypeSpec`, and nowhere else.

## Alignment

Optical, not mathematical. An icon centred by its bounding box usually looks
low, because its visual mass is not centred in that box. Trust the eye over the
number; the design system's components already carry these corrections, which
is one more reason not to hand-roll them.

## Enforcement

| Rule | Where |
| --- | --- |
| radius comes from the scale | `ui_lint` `hardcoded-radius` |
| type comes from the theme | `ui_lint` `hardcoded-text-style` |
| a glyph size comes from the ladder | `ui_lint` `hardcoded-icon-size` |
| a box dimension is named | `ui_lint` `hardcoded-box-size` |
| a screen fits at textScale 2.0 | goldens (`make golden`) |

Size used to be on the unlinted list here, on the argument that a rule over
numeric literals cries wolf. It did not survive contact with the kit: with
nothing reading size, 13 distinct icon sizes and 13 distinct box dimensions
accumulated against a token layer offering two, and every one of them passed
the gate. The two rules are narrow enough not to cry wolf — they read
`size:`/`iconSize:` and `width:`/`height:`/`min*`/`max*`, nothing else. A
fractional value is treated as a line height and passes, the component gallery
may size its own preview frames, and a real exception says so on the line with
`// ui-lint: allow`.

`EdgeInsets` is still **not** linted. Padding genuinely does carry one-off
geometry — a hit-slop, an optical correction — and there the wolf argument
holds. Use the spacing tokens; the review and the goldens catch the drift.
