<!-- ux-layer:v1 -->
<!-- flutter mobile variant — deliberately not the stamped desktop-web version.
     See DECISIONS.md, 2026-08-28. scripts/stamp-ux-layer.mjs only writes this
     file when it does not exist, so it will not be overwritten; do not delete
     it and re-stamp. -->

# UX Patterns

Every screen follows the same rules. Deviating requires a DECISIONS.md entry.

This is the short version. The reasoning, and the parts that need more than a
bullet, live in [docs/principles/](principles/).

## The four states (non-negotiable)

Every async surface renders all four states. Missing any one is a bug:

1. **Loading** — a skeleton that mirrors the shape of what is coming
   (`DSSkeleton`), or `DSLoadingState` when there is no shape to preview. Never
   a blank region, and never a spinner over content that already loaded.
2. **Empty** — say what belongs here and give exactly one action that creates
   it (`DSEmptyState`). Zero *search results* is a different screen: offer to
   clear the filter, not to create a record.
3. **Error** — human-readable message plus retry. Never raw exception text.
4. **Success** — the data, or explicit confirmation when there is nothing to
   show.

## Reachability

The bottom third of the screen is where a thumb lives. The top is where the eye
goes. Design accordingly:

- **Primary actions go bottom, full width, above the safe area** — not
  bottom-right, which is the desktop pattern.
- Titles, status and identity go top.
- Destructive actions are never adjacent to a common one.
- Nothing important sits under the notch, the home indicator, or the keyboard.
  Use `SafeArea`; the design system's sheets and bars already do.

## Collection-screen anatomy

- Search at the top (`DSSearchBar`), filters as a horizontally scrolling chip
  strip below it — not a dropdown, which hides the current state.
- **Pull-to-refresh, always.** A refresh button is a desktop idiom.
- Rows: identity first, metadata second, one trailing control.
- Swipe for the destructive or common action (`DSDismissibleTile`) — and that
  same action must also exist somewhere tappable, because a swipe is not
  discoverable on its own.
- Paginate or lazily build. Never an unbounded render.

## Form layout

- One column. Label above the field, helper below, error text **replaces**
  helper text, so the layout does not jump when validation fires.
- Validate on submit first, on blur after the first submit.
- Primary button bottom, full width, above the safe area; disabled with its
  loading state showing while submitting. Never a double submit.
- Cancel is a ghost button or a route back, never a second filled button.
- Declare `keyboardType` and `textInputAction` on every field, so the keyboard
  is the right keyboard and "next" moves to the next field.

## Interruption — sheet, dialog, snack bar

- **Blocks the next step** → `DSDialog`, naming the object
  ("Delete 'Acme'?"), with the verb on the button.
- **The user may reasonably ignore it** → `DSBottomSheet`. On a phone this is
  the default: a sheet is thumb-reachable and drags away.
- **Reversible** (archive, toggle, mark done) → optimistic update plus an undo
  in a `DSSnackBar`. No confirm dialog for something undoable.
- **Must survive until dealt with** → `DSMessage`. Never put a required action
  only in a snack bar; it leaves on a timer.
- Never a dialog for pure information.

## Empty-state copy

- Say what belongs here, why it is empty, and what to do next — three short
  lines at most.
- End with exactly one call to action.
- No illustrations required; no lorem text, ever.

## The floor

- **48dp tap targets** (44pt on Apple), with 8dp between adjacent ones.
- **Works at textScale 2.0.** Minimum heights, not fixed heights.
- **4.5:1 contrast** for body text, and never colour alone to carry meaning.
- Honours reduced motion and high contrast.

Details in [docs/principles/accessibility.md](principles/accessibility.md).

## Reading direction

Positions come from the reading direction, not from the screen: `start`/`end`,
never `left`/`right`. `ui_lint`'s `physical-direction` rule fails a build on
an inset, a border or an alignment written the physical way — an inset written
as `left` lands on the trailing edge in Arabic, and the label indents away
from the field it labels.

Details in [docs/principles/direction.md](principles/direction.md).

## Forms

Shape from the Form archetype, construction from the `add-form` skill — and
the part neither covers: nothing is red before the first submit, the focused
field stays above the keyboard, autofill needs an `AutofillGroup` as well as
the hints, and an interrupted form comes back with what was typed.

Details in [docs/principles/forms.md](principles/forms.md).
