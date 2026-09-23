<!-- principle:forms:v1 -->

# Forms over time

Two other files already own most of a form. `docs/principles/screen-archetypes.md`
owns its **shape** — one column, label above, helper below, primary full width
in the thumb zone. The `add-form` skill (`.claude/skills/add-form/`) owns its
**construction** — how many questions there are, which control each one gets,
and when it becomes a stepped flow. Read those first; this page does not repeat
them.

What is left is the part a screenshot cannot show: what a form does **between**
the first tap and the successful submit. That is where forms are actually lost.

## Nothing is red before the user is done

**Validate on submit first, and only then on change.** A field that turns red
mid-word has decided the user is wrong before they finished typing their own
email address. `DSFieldValidation` is built for this order, and
`test/screens/form_page_test.dart` asserts it: nothing is red before the first
submit.

After that first submit the rule inverts — every keystroke re-validates, so an
error clears the moment it is fixed rather than at the next submit. A form-level
`DSMessage(scope: DSMessageScope.screen)` says *that* something is wrong; the
fields say *what*. The banner clears itself as the fields are fixed.

**Never validate on focus loss alone.** A user who tabs through to see the form
and comes back finds four red fields they never filled in.

## The keyboard is half the screen

When the keyboard is up, a phone form has about 350 points of usable height.
Three consequences:

- **The focused field must be visible.** A `SingleChildScrollView` or a
  `CustomScrollView` inside a `Scaffold` handles this by default —
  `resizeToAvoidBottomInset` plus the scroll view's own `ensureVisible` on
  focus. A form inside a fixed-height box does not, which is the one layout to
  avoid.
- **The submit must be reachable without dismissing the keyboard.** A pinned
  `DSPinnedActionBar` rides above the keyboard; a button at the bottom of the
  scroll body is under it. `DSBottomInsets` is what keeps the bar, the FAB and
  a snack bar from stacking on each other.
- **Chain the focus** — `TextInputAction.next` on every field but the last,
  `done` on the last. A user who has to dismiss the keyboard and tap the next
  field is doing the form's job for it.

## The platform wants to fill it in

**Autofill is two halves and both are required.**

- `DSFieldInput.email` / `.password` carry the `autofillHints` — that is the
  half that lets the platform *offer* a value.
- An `AutofillGroup` around the fields, plus `TextInput.finishAutofillContext()`
  after a **successful** submit, is the half that lets it *offer to save* one.
  `lib/screens/auth/login_page.dart` and `signup_page.dart` do both.

Only on success. Calling `finishAutofillContext` after a rejected password is
how a wrong password gets into someone's keychain.

## An interrupted form is the normal case

A phone call, a notification, a switch to the mail app for the code. The form
comes back; what the user typed must come back with it.

- **`TextEditingController` state survives a rebuild, not a dispose.** A form
  whose route is popped and pushed again is a blank form. If the flow can be
  left and resumed — a multi-step checkout, a long profile edit — the answers
  live in the parent `State` (or a provider) and not in the field widgets.
  This is already the rule for stepped flows in the `add-form` skill, for
  exactly this reason.
- **Back must not silently discard.** A form with typed input that is being
  abandoned asks first — `DSDialog` with a destructive confirm — and a form
  with nothing typed does not ask at all. A confirmation on an empty form is
  the dialog everyone learns to dismiss without reading.
- **Never clear the whole form on a failed submit.** The server rejecting one
  field is not a reason to throw away the other six.

## Submitting is a state, not an event

- **Disable the primary and show its loading state.** `DSButton`'s `loading`
  flag is the one that does both; a double submit is a double booking.
- **Failure names what to do next.** `errorCopyFor` writes it — never the
  exception's own text, which names the library that failed and nothing the
  reader can act on.
- **Success is a screen, not a snack bar,** when the form is the reason the
  user came: `DSEmptyState.done` replacing the fields, with a way back that
  resets what was typed. A snack bar is right for an edit inside a longer
  session, where the user is staying where they are.

## The failure this prevents

Every rule here has the same shape: the form worked when it was tested by
someone who typed straight through it on the first try. The user who gets
interrupted, whose password manager has the credential, who mistyped one
character in a field they cannot see behind the keyboard — that user meets a
different form, and it is the one that loses them.
