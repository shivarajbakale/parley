---
name: add-form
description: Design and build a form that is short, typed and — when it cannot be short — stepped. Use BEFORE writing any screen that collects input: sign-up, checkout, booking, profile edit, settings detail, "add a form", "a screen with fields", "let the user enter X". Covers density (how to make a form smaller), which control each data type gets, and when to split into a multi-step flow.
---

# add-form — a form is a set of questions, not a stack of fields

The **Form** archetype in `docs/principles/screen-archetypes.md` owns the frame:
one column, label above, helper below, error replacing the helper in a reserved
slot, primary full width in the thumb zone. This skill owns what the archetype
does not decide — **how many questions there are, what each one is asked with,
and what to do when there are too many for one screen.**

Answer the three sections below **in order** before writing a widget. Section 3
only exists because section 1 failed.

## The reference slice

| Layer | File | What to copy |
| --- | --- | --- |
| A short form | `lib/screens/auth/login_page.dart` | the two-field case — do not reach for more machinery than this |
| A stepped flow | `lib/screens/design_system/form_page.dart` | four steps, validation scoped to the step, a review that can be corrected from |
| Its option data | `lib/screens/design_system/form_data.dart` | value types, defaults and copy kept out of the widget |
| The tests | `test/screens/form_page_test.dart` | nothing red before Next, Back keeps what was typed, confirm reaches the booked state |

Read `docs/references/design-system-reference-llms.txt` (Input section) before
picking controls. `tool/ui_lint.dart` fails a form that hand-rolls one.

---

## 1. Make it shorter — before anything else

A form's cost is **screenfuls, not fields**. The bar: at text scale 1.0 on a
390pt screen the whole form is **one and a half screenfuls or less**. Record the
goldens and look at where the fold cuts (`test/golden/goldens/`) — that image is
the measurement, not a feeling.

**Every field pays rent. Four ways to evict one:**

- **Derive it.** Locale, timezone, currency, today's date, the signed-in user's
  name and email. A field the device already knows the answer to is a question
  you are asking to be polite.
- **Default it.** A pre-filled field is not a question. `form_page.dart` opens
  with a day, an arrival slot and a party size already chosen — the user
  confirms three things instead of answering them.
- **Defer it.** Optional detail belongs after the submit, or on first use. If
  more than a third of the form is optional, it is two forms and one of them is
  not urgent.
- **Delete it.** Data nobody reads downstream is not a field.

**Then cut the chrome, which is usually the real bloat:**

- One label per group, not a `DSSectionHeader` *and* a group eyebrow *and* a
  field label. `DSFieldGroup`'s `eyebrow` replaces the header; its `footer`
  replaces the paragraph under the group.
- **The helper slot is one line and always drawn** — reserved so an error can
  replace it without moving the fields below. A sentence put there ellipsises.
  Sentences go in `DSFieldGroup`'s `footer`, which wraps.
- Two fields share a row only when they are one fact (expiry month / year).
  Otherwise one column, always: two columns do not survive a 2.0x text size.
- The page has one headline. A header that only repeats the screen's name is a
  compact bar — `ui_lint`'s `header-earns-its-height` is the gate.

**Group with `lib/design_system/ds_field_group.dart`.** It owns the page gutter,
the eyebrow, the gap between fields and the wrapping footer, so a form's rhythm
is a token rather than a `Padding` typed out per screen.

**One caveat, and it decides the whole layout:** a group holds its fields in a
column, which puts them one level below the child the viewport clips — and
`make ui-probe` can then no longer tell a control the fold cut from a control
that is too small. That does not matter for a form that never scrolls, and it
is the whole problem for one that does:

| The form | Build it as | Because |
| --- | --- | --- |
| fits without scrolling (the bar in this section) | `DSFieldGroup`s in a `Column` — see `lib/screens/auth/login_page.dart` | nothing is ever at a fold |
| scrolls | one field per child of a `CustomScrollView` — see `lib/screens/design_system/form_page.dart` | the probe grades what the fold cuts |

A form in the second row is a form that failed this section. Trim it, or take
it to section 3 — and a stepped flow's steps land back in the first row, where
grouping is free.

---

## 2. Give each data type its own control

A control is chosen by **what the answer is**, never by what is quickest to
type. A known set is never a text field: a typo'd value is a support ticket.

| The answer is | Use | Not |
| --- | --- | --- |
| free text, one line | `DSTextField` | — |
| an email | `DSTextField` + `DSFieldInput.email` | a bare field — wrong keyboard, no autofill |
| a password | `DSFieldInput.password` | setting `obscure` by hand |
| a paragraph | `DSFieldInput.multiline` with a `maxLength` | a one-line field that scrolls sideways |
| an unbounded number | `DSFieldInput.number` | `DSStepper` — that is a lot of taps |
| a bounded count (say 1–20) | `DSStepper` in `lib/design_system/ds_stepper.dart` | a number field |
| an approximate value | `DSSlider` | a field the user has to guess a number for |
| one of 2–4, one word each | `DSSegmentedButton` | — |
| one of 2–5, each needing a sentence | `DSRadioGroup` + `DSRadioTile` | `DSSegmentedButton` — long labels clip at 320pt |
| one of 4–20 | `DSSelect` | a text field, a segmented control |
| several of a set | `DSMultiSelect`, or `DSCheckboxTile` rows | — |
| a date near today | `DSDateStrip` | — |
| a date far away or exact | `showDatePicker` | `DSDateStrip` — it is a strip, not a calendar |
| a setting that applies immediately | `DSSwitch` | — anywhere inside a form that is submitted |
| filtering a list on screen | `DSSearchBar` | `DSTextField` — a search bar is not a field that gets submitted |

**Three rules that go with the table:**

1. **Every field declares a `DSFieldInput`.** It is the keyboard, the autofill
   hint, the capitalisation and the obscuring as one coherent group — the named
   constructors in `lib/design_system/ds_text_field.dart` exist so an incoherent
   combination cannot be expressed.
2. **Chain the focus.** Every field but the last takes
   `textInputAction: TextInputAction.next`; the last takes `done`.
3. **A checkbox, not a switch, inside a form that is submitted.** A switch says
   the change already happened, and a switch with a Save button is a lie
   (`lib/design_system/ds_control_tile.dart` ships `DSCheckboxTile`).

**Validate the type, not the string,** and let the control shape the error copy:
a select's error names the choice ("Pick a zone"), a text field's names the rule
("Use at least 8 characters"). Validation runs on submit first and only then on
interaction — a field that turns red mid-word has decided the user is wrong
before they finished. A form-level `DSMessage` with
`scope: DSMessageScope.screen` says *that* something is missing; the fields say
*what*, and the banner must clear itself as they are fixed rather than waiting
for a second submit.

---

## 3. Still too long? Then it is a stepped flow

**Trigger:** after section 1, the form is still more than about two screenfuls
at 1.0x, **or** it holds more than one decision domain (who / when / where /
pay). Do not ship a five-screenful scroll with one button at the bottom.

> **Naming trap:** `DSStepper` is the *numeric* control (− 2 +). The step
> indicator for a multi-step flow is **`DSSegmentedProgress`** in
> `lib/design_system/ds_segmented_progress.dart`.

**The shape:**

- `DSSegmentedProgress.labelled` under the header for up to five steps;
  `DSSegmentedProgress` (the bar) with a counter past that — labelled nodes
  collide on a phone at six, and the component refuses to build.
- **One step on screen at a time, swapped — never a `PageView`.** The step
  index lives in the parent `State` and the bodies are exchanged through an
  `AnimatedSwitcher` on the motion tokens. A `PageView` scrolls sideways, and
  a horizontal scroller wrapping the step's own vertical scroll is
  `ui-probe`'s `dual-axis` failure: a page with two axes is a page whose
  reader does not know which one moves. `lib/screens/onboarding_page.dart`
  does page, and gets away with it only because its slides never scroll.
- **One `Form` per step**, so `validate()` is scoped to what is on screen.
- All the answers live in the parent `State`, never in the pages.
- `DSPinnedActionBar` carries Back (a ghost button) and Next (the primary).

**The rules:**

- Three to five steps. A step holding one field merges into its neighbour.
- One decision domain per step, answerable without the others.
- Back never loses input, and no step may be un-leavable.
- Only Next validates, and a failure keeps the user on the step with the field
  named — never bounces them to step one.
- **The last step is a review and confirm**, listing what the earlier steps
  collected. The submit exists only there; every earlier primary says Next.
- The counter is legible ("Step 2 of 4"), not decoration.
- Register **each step** in `test/_screens.dart` — a paged flow needs a fixture
  per page, which is exactly why `lib/screens/onboarding_page.dart` is still
  sitting in the `ungradedScreens` map. Do not add a second one.

---

## Rules the gates enforce

- **A form that scrolls puts one field per child of the sliver list** — see the
  table in section 1, and the `_gutter` helper in
  `lib/screens/design_system/form_page.dart` that applies the page gutter to a
  field that has none of its own. Wrapping the same fields in one box took
  `make ui-probe` from 3 findings to 40, all of them the fold rather than the
  controls.
- **The gutter has one owner.** `DSFieldGroup`, `DSControlTile` rows,
  `DSSectionHeader` and a screen-scope `DSMessage` each apply the page gutter
  themselves. A bare `DSTextField` does not — that is what the group is for.
  Never nest two of them.
- **Do not `extendBody` under a pinned action bar** when the form scrolls. Let
  the `Scaffold` lay the bar out; content painted behind it is an `overlap`
  violation at a 2.0x text size, where the bar is a fifth of the screen.
- Never a raw `TextFormField`, `DropdownButton` or `Switch` — `raw-text-field`
  and its siblings in `tool/ui_lint.dart` name the kit widget instead.
- No hand-typed colours, radii, paddings or durations. `context.design.space`,
  `context.radiusOf(role)`, `context.design.motion`.
- Disable the primary while submitting and show its loading state. A double
  submit is a double booking.
- The state **after** a successful submit is part of the form: `DSEmptyState`
  (`lib/design_system/ds_status_state.dart`) replacing the fields, with the way
  back resetting what was typed.

## Procedure

1. Write the questions as a list, in words, before any code. Apply section 1 to
   the list — derive, default, defer, delete — and count what survives.
2. If it survives at two-plus screenfuls or spans more than one decision domain,
   go to section 3 and plan the steps; otherwise it is one screen.
3. Run the `plan-feature` skill. `make plan-lint` fails an unplanned UI change,
   and a form's frame is exactly the thing worth drawing before building.
4. Pick a control per question from section 2's table.
5. Build the screen with the `add-screen` skill's edit list — screen, route
   constant in `lib/utils/app_routes.dart`, `GoRoute` in
   `lib/utils/app_router.dart`, reachability, and the entry in
   `test/_screens.dart`.
6. Write the tests from `test/screens/form_page_test.dart`: nothing is red
   before the first submit, an empty submit names what is missing, the banner
   clears as it is fixed, a complete submit reaches the success state and the
   way back resets.

## Definition of done

Run the `verify` skill. The minimum bar is `make check` green — including
`make ui-probe` with no new entry in `test/probe/debt.dart` — plus the form
driven by hand in a running app: submit it empty, fix it field by field, submit
it complete, and come back from the success state.
