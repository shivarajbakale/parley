<!-- principle:premium:v2 -->

# Production-ready is the bar

This app is the starting point for a premium SaaS product, not a reference
implementation. The difference is not polish added at the end; it is a set of
things that are never true of a shipped screen, checked before a feature is
called done.

## The failure this prevents

**A screen that passes every gate and still looks unfinished.** Every defect
listed below shipped green: `flutter analyze` was clean, `make ui-lint` found
nothing, every test passed, and the goldens matched. They were found by a
person opening the app and looking at it.

That is the specific gap this document closes. `analyze` reads types,
`ui_lint` reads source text, and a golden only fails on a *change* — so a
layout that was wrong the day its baseline was recorded is recorded as
correct, forever. None of the three grades a first draft.

The goldens had a second hole underneath that one. A gallery is a
`SingleChildScrollView` in a fixed 360 × 640 frame, so its tail was scrolled
out and never painted: `forms` was hiding 358 points, `feedback` 290, and two
widgets added to `meters` changed not one pixel of its baseline. Five of the
nine sheets were reporting coverage they did not have — including the empty
state in defect 7, which no golden had ever drawn. `expectGoldenSheet` now
takes `mustFit`, grows the frame to its content and fails when it still does
not fit.

## The nine that shipped

Each is a class, not an anecdote. A screen is not done while any of them is
true of it. Defects 7 and 8 were reported the same way as the first six —
someone opened the Library tab and said the header looked wrong.

| # | The defect | What it looked like |
| --- | --- | --- |
| 1 | **Siblings in a row do not share a baseline.** | `DSSegmentedProgress.labelled` gave a tappable step a 48-point cell and an upcoming one a 24-point cell, so three labels sat 24 points below the other two and the connectors ran through empty space above the nodes they joined. |
| 2 | **A surface inside a surface.** | `showDSCustomModal` wrapped its builder in a modal; the caller passed another modal holding a card. Three stacked surfaces, two drag handles, and the content inset twice. |
| 3 | **A row with no `Expanded` in it.** | `DSSectionHeader` overflowed by 31 points on a title of four words, with the striped overflow bar drawn over the end of the text. |
| 4 | **Chrome above the fold.** | A component page spent 348 of its first 844 points on an app bar, an eyebrow, a summary and a fixed note that is identical on all fifty pages. The component the page exists to show started below the fold. |
| 5 | **One idiom measured three ways.** | The structured modal capped at 400, the custom one at infinity, the dialog at the screen minus 48. Three widths for one surface means there is no surface, only three of them. |
| 6 | **A desktop idiom on a phone.** | `DSSelect` opens an anchored popover, which the HIG reserves for regular width. On a compact width the same content is a sheet — and the popover is an `OverlayEntry`, so the Android back button does not dismiss it. |
| 7 | **Chrome painted at rest.** | `DSLargeAppBar` tinted its surface whether or not anything was under it, so every unscrolled page opened with a 108-point band across the top holding one word. A bar's material belongs to the moment content goes under it — which on Apple is also the only moment glass has anything to composite. |
| 8 | **A control that owns the page's gutter.** | `DSSearchBar` applied `pageHorizontal` inside itself and every caller applied it again, so the Library's search pill sat at 32 while the chips and rows beside it sat at 16. The page owns the gutter; a control that adds one is inset twice. |
| 9 | **A placeholder standing in for artwork.** | `DSEmptyState` renders an 80-point Material glyph in the outline colour. It is the single screen a user sees at their emptiest moment, and it is a wireframe. |

## What to check, before calling a screen done

Run it, then read this list against what is on the screen.

**Gutters.** The page applies the gutter, once. A control that pads itself is a control that will be inset twice by the next caller who does it properly.

**Alignment.** Every row's children share a baseline or a centre line, in every
state. State that changes a child's size — a tap target appearing, a badge
arriving, a label switching weight — must change every sibling's size or none.

**Surfaces.** Count them from the screen edge inward. A sheet holding a card
holding a card is two too many. One surface owns the elevation; what is inside
it is content.

**The fold.** On a 390 × 844 phone, the thing the screen is *for* is visible
without scrolling. Chrome that repeats on every screen of its kind is a
footnote, not a card.

**Width and inset.** A surface of a given kind is the same width everywhere it
appears. If two call sites disagree, one of them is wrong; the number belongs
in the component, not the call.

**Idiom.** Compact width gets the compact idiom — sheet over popover, full-width
over anchored. Something dismissible is dismissible with the platform's own
gesture and its back button.

**Emptiness and error.** Both states are designed, not defaulted. Neither is a
grey glyph and a sentence.

**Text scale 1.0, 1.3 and 2.0, both themes.** Nothing clips, nothing overflows,
nothing overlaps. If a label cannot survive 2.0, the layout changes shape
rather than the label shrinking.

## Where this is enforced

`AGENTS.md` constraints 3 and 4 — run it on a simulator, capture a screenshot,
have the design reviewed — are graded against this list, and they remain the
only answer to whether something looks good.

The checkable half is `make ui-probe`, which is inside `make check`. It mounts
every catalog page and every demo screen across three widths, three text scales
and both platform skins, and asserts on facts a render tree can be asked for.
Each of the nine defects above is named here with the rule that would now catch
it, or with what catches it instead:

| # | The defect | Caught by |
| --- | --- | --- |
| 1 | Siblings in a row do not share a baseline | `baseline` — and it still finds this one on the labelled step meter |
| 2 | A surface inside a surface | `nesting` |
| 3 | A row with no `Expanded` in it | `overflow` |
| 4 | Chrome above the fold | `fold` |
| 5 | One idiom measured three ways | `width-band` |
| 6 | A desktop idiom on a phone | Fixed rather than measured, by `flutter-018`. A popover is not wrong, it is wrong *at this width*, so `showDSOverlay` degrades `popover` and `menu` to a sheet under 600 points and `ui_lint` fails the build on any other way of presenting a surface. `ds_overlay_test` holds both halves |
| 7 | Chrome painted at rest | The goldens. It is a picture of a material, and a measurement cannot see it |
| 8 | A control that owns the page's gutter | `ui_lint`'s gutter rule, which fails the build on a second `pageGutter` |
| 9 | A placeholder standing in for artwork | Nothing. It is a judgement about what is drawn, and it is `flutter-021` |

Defects 2 and 5 are now structural rather than merely caught: there is one
surface — `DSOverlaySurface` — behind all five presentations, so "a modal
inside a modal" and "three widths for one idiom" are no longer expressible.
The two rules stay, because the shapes they catch are not specific to the
components that had them.

Three more rules run for the checklist above rather than for a defect that
shipped: `target` (a control under the tap floor), `contrast` (rendered text
against the surface it is actually painted on) and `dual-axis` (a page that
scrolls sideways as well as down).

A tenth arrived later, for a defect none of the others could see. Every rule
above asks whether a screen is **broken**; `dead-band` asks whether it is
**empty** — how much white sits between the last line of a page that has
nothing left to scroll and the pinned bar at the bottom of it. A booking form
shipped with 247 points of it, a quarter of the phone, and every gate was
green. Two things paid it off, and both are the general answer rather than a
nudge to that screen: a field that can produce no message stops reserving a
line to be silent in (`DSTextField.reserveHelper`), and the tail is given the
one thing its reader cannot see from the screen — what else is on the day.
It grades against the ledger, because a rule that measures emptiness finds a
class the moment it exists: seven surfaces across five screens on the day it
was written.

The rule's floor is 140 points, a sixth of the screenful, and it is skipped
whenever anything is still scrollable — space under content that continues is
the next screenful arriving, not a hole.

An eleventh asks the same question one scale down. `dead-band` measures the
space a *page* is not using; `row-air` measures the space a **row** is not
using. A screenshot of the Settings tab and the word "spacy" is what found it:
nine rows on a screenful, each 64 points tall around a 19-point line, and every
gate green. `DSListTile` passed no `minTileHeight`, so Material's
`_defaultTileHeight` picked the number and the kit's own padding was added on
top of it — while `ComponentSpec.listRowMinHeight` had said 56 since the spec
was written and no row had ever read it. `DSListTileSkeleton`, built by hand
from the same tokens, drew 56: the row and its own placeholder were eight
points apart and nothing compared them.

`row-air` compares every rendered row against
`max(listRowMinHeight, content + verticalPadding * 2)`, both read from the spec
the row itself reads, so the rule does its arithmetic in the kit's numbers
rather than in a tolerance. It is absolute, not graded: what a row should be is
not a matter of taste a ledger has to hold open. It stops above 1.3x text,
where the row restructures and is no longer the row being graded, and it
reports a violation of *itself* if a surface has rows on screen and it measured
none of them — a rule that reports nothing reads exactly like a rule that
passed.

It is also the answer to why `SpaceSpec.density` looked like a knob and behaved
like a decoration: at 0.9 it moved a row from 64.0 points to 63.2, because the
token scale was never what owned the height.

A twelfth grades the other two things a user presses. `control-air` asks each
button and each floating action button on screen which size it *is* — an
explicit `DSButtonSize`, the ambient `DSScope`, or, for the FAB, a label,
which is what makes a floating button extended — and compares what it painted
against the one token in `ComponentSpec` that answer names. A control may be
that token, the tap floor `DSTapTarget` inflates its box to, or the height its
own content needs when a label wraps, because the button never ellipsises: a
truncated action label is an unknown action, so the button grows instead.
Anything above all three is height nothing in the kit asked for.

It was written because `row-air` had found the wrong lesson. The defect was
never about rows — it was a painted dimension arriving from outside the spec
while every gate stayed green — and the same shape was sitting in the two
largest controls in the kit. `ComponentSpec.buttonHeight` was 48, which is
exactly `minTapTarget`, so every button in the app painted the accessibility
minimum around a 19-point label: sixty per cent air. The token's own doc
comment said the opposite — *a control may be visually shorter than 44/48 so
long as its gesture area is not* — and `DSTapTarget` had held that gesture area
all along. `sm` used it and painted 36 inside a 48 box. `md`, which is nearly
every button in the app, did not.

The floating action button had inherited its numbers from further away still.
40/56/96 is Material 3's FAB table copied whole, including the 96 Material
specifies for an *expanded* window — a tablet — which on a 390-point phone is a
quarter of the width around a 24-point glyph. This kit is Apple-first, and
Apple ships no floating action button at all, so there was no second opinion to
weigh Material's against, and no golden covering the large size to make anyone
look. The table shrank from three sizes to one: `DSFabSize { sm, md, lg }` let
two FABs disagree about which was primary before a user ever saw them side by
side, so the size argument was removed rather than tuned again. `fabSize` is
now 40, the old `sm` — secondary beside the buttons and rows around it, since
a floating action is an escape hatch and not the loudest control on the
screen.

The button ramp is three named tokens now rather than one token and two sums.
It used to be `buttonHeight - space.md` and `buttonHeight + space.sm`, so
lowering the middle step silently dragged the small one under any size worth
painting: a change to one button size was a change to three.

`target` and `contrast` grade a kit built before anything measured it, so they
start from a count rather than from zero. `test/probe/debt.dart` holds it, and
it is a ratchet in both directions: a surface that gains a violation fails, and
a surface that loses one fails until the number is lowered. `flutter-032` is
the work of emptying it.

That has already cut it once, and not by changing a component. `target` used to
ask the node in front of it for its clip and skip a control only when it sat
flush against that clip within half a point — but the nearest clip is not the
only one, and a clipped rect is rounded on the way through the layer tree, so a
48-point button cut by one point reported 47 and was called a defect. Carrying
the clip down the walk took 24 entries off the list. They were facts about a
scroll offset rather than about a control, which is the failure mode a rule
that grades a rendered tree has to be watched for.
