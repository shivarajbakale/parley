---
name: add-tour
description: Build a first-run tour on DSTour — write the stops, draw the illustrations, and decide whether the sequence earns a way out. Use when the user wants onboarding, a welcome carousel, a product tour, or a "what this app does" sequence before sign-in.
---

# add-tour — a first-run sequence that is worth the taps

The kit ships the mechanics. What you supply is three or four things the app
*does* and a picture of each one.

## Decide whether to build one at all

A tour whose slides only advertise is a run of taps that produces nothing. The
question is what the last stop hands over to. If the answer is "the app", an
empty state on the first screen does the job better: it introduces a feature at
the moment it is wanted rather than three screens early.

Build the tour when the last stop hands over to something the user has to do
anyway — sign-in, a setup step, a permission.

## The stops

Write them in `lib/screens/onboarding_page.dart`, replacing `onboardingStops`.

- **Three or four.** A fifth claim turns a handover into a brochure.
- **Each stop is a thing the app does, not a quality it has.** "Know who still
  owes you" is a stop. "Fast and beautiful" is not.
- **The body backs the headline up.** One sentence, concrete, naming the actual
  mechanism.
- **Keep the body short.** It has to fit beside its picture at 2.0x text on a
  320pt phone. Longer and the slide starts scrolling down inside a pager that
  already scrolls sideways, and `ui-probe`'s `dual-axis` rule fails the tour —
  a page with two axes is a page whose reader does not know which one moves.
  About ninety characters is the working ceiling; the shipped three sit under
  it.
- **The last stop is the handover.** It is not a fifth advert; it is a picture
  of the thing the button is about to start.

## The illustrations

Replace the three in `lib/screens/onboarding_art.dart`. Draw them in Flutter
rather than shipping a screenshot or a raster: a screenshot goes stale at the
next redesign and scales badly in the other theme, and a drawing that reads the
live `ColorScheme` is the app the user is about to open.

Three rules, all of which the shipped examples follow:

1. **Compose inside `DSTourCanvas`.** It is a fixed-width board that the slide
   scales into whatever room the words leave over. A drawing that sizes itself
   to the screen reflows on a narrow phone; this one shrinks.
2. **Draw the pieces still.** Nothing in a slide animates in; the swipe between
   slides is the only movement. An entrance played on build would be finished
   before its slide arrived anyway, because a `PageView` builds pages early.
3. **Every colour comes from `Theme.of(context).colorScheme` or
   `context.design`.** `tool/ui_lint.dart` fails the build on a literal, and
   the reason is not tidiness: a hex tuned for the light theme is wrong in the
   dark one.

Use `DSTourFillSlot` for the stop that argues the app is different afterwards —
a blank rule that fills with a real answer. It is the argument for the tour made
in a picture rather than in a sentence.

If the numbers in your drawings are meant to be read, keep them consistent
across the set. Someone will check the arithmetic.

## Skip, and what dropping it costs

`DSTour.onSkip` is nullable, and passing null removes the control.

Drop it only when the last stop hands over to something the user cannot avoid.
The invoice app this was ported from has no Skip because its last slide opens a
four-step setup checklist: nobody reaches the app by reading, they reach it by
finishing setup, so a Skip would be a button that does nothing.

The template keeps its Skip, because its last stop hands over to sign-in — which
a returning user can reach without reading three slides. A tour with no way out
that ends at "Get started" is the advert without the payoff.

## Register it, or nothing grades it

A tour is a paged flow, so **one entry per stop** in `test/_screens.dart` —
`OnboardingPage(initialStop: n)` — exactly as the shipped three do. A flow the
gates only see the first page of is a flow whose other pages are measured by
nothing and pictured by nothing. `test/screens_registry_test.dart` fails if you
add a screen and forget.

Give each stop a subject in `test/probe/corpus.dart` too. On a tour the subject
is the slide, not the button under it.

## Done when

- `make check` is green: `analyze`, `ui-lint`, `test`, `ui-probe` and `golden`.
- `make ui-probe` walks one surface per stop and finds nothing.
- The baselines in `test/golden/goldens/` have been looked at, not just
  regenerated.
- Reduced motion shows finished illustrations rather than blank ones — the
  `active` gate returns the child untouched, so check it rather than assume it.
