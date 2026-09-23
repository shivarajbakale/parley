<!-- principle:accessibility:v1 -->

# Accessibility

Everything here is also a quality rule. Targets big enough for a screen reader
user are targets big enough for someone holding a coffee; text that survives
a 2× font scale is text that survives a translation into German.

## Tap targets

**44×44pt on Apple, 48×48dp on Android.** That is the floor for anything
tappable, including icon buttons, chips, switches and list row trailing
controls.

Two things that get missed:

- **The visual size and the tap size are different numbers.** A 24dp icon in a
  48dp target is correct and normal. `IconButton` already does this; a
  `GestureDetector` wrapped around an `Icon` does not, which is one of the
  reasons hand-rolled controls are a lint failure.
- **8dp of separation between adjacent targets.** Two 48dp buttons touching
  are one 96dp button as far as a shaky thumb is concerned.

There is deliberately no `ui_lint` rule for this: it is rendered geometry, not
a source pattern. An `IconButton` with no explicit size is fine; the same
button inside a `SizedBox(24)` is not, and no regex can tell them apart. The
goldens are where it gets checked.

## Contrast

**4.5:1 for body text, 3:1 for text at 18pt+ or bold 14pt+, 3:1 for the
boundary of any control the user must find.**

The token layer is built to hit this in both themes, which is the real argument
for `ui_lint`'s colour rules: a literal is tuned against one background and
silently fails on the other. `Colors.grey` is the classic — legible on white,
invisible on the dark surface.

Never carry meaning in colour alone. An error is a colour **and** an icon
**and** words. Roughly one man in twelve cannot use the first of those.

## Text scale

The app must work at **`textScaleFactor` 2.0**. Both platforms let users go
there and a meaningful number of them do.

What breaks, in order of frequency:

1. Fixed-height containers around text — a 56dp row with 2× text clips it.
   Set a minimum height, not a height.
2. Single-line labels that need `maxLines` and an ellipsis, or a wrap.
3. Buttons in a `Row` that overflow — they need to become a `Column` at scale.
4. Bottom nav labels, which have the least room of anything on the screen.

Never clamp the scale globally. Overriding `MediaQuery.textScaler` back down is
overruling an accessibility setting the user chose deliberately, and it is the
one shortcut this project will not take.

The goldens render at 1.0 and 2.0 for exactly this reason.

## Screen readers

- Every icon-only control needs a `Semantics` label. The tooltip is for sighted
  pointer users; the label is for everyone else, and neither substitutes for
  the other. Where a component cannot draw a name of its own — a bare switch, a
  checkbox, an icon-only segment — `semanticLabel` is **required** rather than
  optional, so the omission is a compile error instead of a silent control.
- **`excludeSemantics` takes the tap action with it.** Naming a control by
  wrapping it in `Semantics(..., excludeSemantics: true)` drops the subtree
  underneath, and the wrapped control's `onTap` is part of that subtree. The
  wrapper has to declare `onTap` itself, or the node says "button", says what
  the button is for, and offers nothing to activate — VoiceOver's double-tap
  and TalkBack's click both arrive as `SemanticsAction.tap`.
- Decorative images are `ExcludeSemantics`. An avatar next to a name that is
  already read is noise.
- A group that reads as one thing should be one node — `MergeSemantics` around
  a list row, so it announces once rather than four times.
- State is announced, not implied: `Semantics(selected:)`, `checked:`,
  `enabled:`. A blue border says nothing to a screen reader.
- Anything that changes without user action — a toast, a completed upload —
  needs a live announcement, or it never happened.

`test/design_system/semantics_test.dart` holds the first four of these, over
every usage in the component gallery: it walks the semantics tree the reader
walks and fails on a control with no name or no action. It cannot judge whether
a name is a *good* one — "Button" would pass — so test with VoiceOver (iOS) and
TalkBack (Android) as well. Five minutes of tabbing through a screen finds what
no static check can.

## Motion and translucency preferences

`MediaQuery.disableAnimationsOf(context)` and
`MediaQuery.highContrastOf(context)` are settings the OS already collected.
Honour them: cascades stop staggering, transitions become cross-fades, glass
falls back to opaque. See [motion.md](motion.md) and
[depth-and-materials.md](depth-and-materials.md).

## Focus and input

- **Every focusable control draws a ring, and one implementation draws it.**
  `DSPressable` observes focus the way it observes the press — a `Focus` that
  cannot take focus and is skipped by traversal — and hands the state to
  `DSFocusRing`. Anything built on the kit gets this without asking. Anything
  that hand-rolls its own tap handling gets nothing, which is what `ui_lint`'s
  `pressable-floor` rule is for.
- **The ring is drawn outside the control, and costs no layout.** Painted on
  the edge it is invisible on a filled button; drawn as a border or a padding
  it moves the page every time focus lands, which is worse than no ring for the
  keyboard user it was meant to serve. Width and gap are `ComponentSpec`
  tokens; the colour is the accent, which `palette_lint` K8 holds at 3:1
  against all three surface roles — WCAG 2.2 SC 1.4.11 for a non-text
  indicator.
- **A finger never sees it.** The ring is drawn only in
  `FocusHighlightMode.traditional`, which is the mode Flutter switches to when
  a key is pressed. A control that was tapped may hold focus without the person
  who tapped it having any idea that focus exists.
- Every form field has a visible focus state that is not only a colour change.
- The keyboard must never cover the field being typed into — the design
  system's sheets handle this; a hand-rolled one will not.
- Text fields declare `keyboardType` and `textInputAction`, so the keyboard is
  the right keyboard and "next" moves to the next field.
- Errors are announced, associated with their field, and stated as what to do
  ("Enter an email address"), not as what went wrong ("Invalid input").

## Enforcement

| Rule | Where |
| --- | --- |
| every control the kit renders has an accessible name | `test/design_system/semantics_test.dart` |
| every control the kit renders publishes an action | `test/design_system/semantics_test.dart` |
| colour comes from tokens that meet contrast in both themes | `ui_lint` `hardcoded-color`, `hardcoded-hex` |
| focus is visible on every control the kit builds | `test/design_system/ds_focus_ring_test.dart` |
| the focus ring is legible on every surface role | `palette_lint` K8 |
| text comes from the theme, so it scales | `ui_lint` `hardcoded-text-style` |
| layouts survive textScale 2.0 | goldens (`make golden`) |
| tap targets and separation | goldens, and the simulator pass in `verify` |

The gates cover the mechanical half. Tabbing a screen with a screen reader on
is the half that is not automatable, and it is a step in the `verify` skill for
that reason.
