<!-- principles:v1 -->

# Nielsen's 10 usability heuristics — applied to this app

This is the lingua franca for "why does this feel right (or wrong)?" The
heuristics are general; the table below maps each one to the specific
pattern or atom in this app that implements it. When you change the UX
of a screen, walk this list. When you're unsure whether a flow is
"premium enough", this is the yardstick.

> Source: Jakob Nielsen, "10 Usability Heuristics for User Interface
> Design" (1994, revised 2020). Public domain.

## 1. Visibility of system status

The user should always know what the system is doing.

- **Where it shows up here:**
  - `Skeleton` components while data is loading (never a blank region).
  - `sonner` toasts for every async action (create / update / delete).
  - `<Spinner>` only when an action takes > 300ms — anything faster
    shouldn't show a spinner, just the disabled button + "…" label.
  - `useX().isFetching` to show a subtle refresh indicator when re-fetching.
- **Failure mode:** a button that does nothing on click. Never. If a
  click has no immediate effect, it's not wired.

## 2. Match between system and the real world

Speak the user's language. Don't use internal jargon.

- **Where it shows up here:**
  - Resource names: "Projects", "Members", "Invoices" — not `Entity`,
    `Tenant`, `Subscription`. If the user-facing term and the API term
    differ, the API term wins internally; the UI term wins externally.
  - Date format: `format(date, "MMM d, yyyy")` — never raw ISO.
  - Money: `Intl.NumberFormat(locale, { style: "currency", currency })`
    with `tabular-nums` for column alignment.
- **Failure mode:** "Resource creation failed: 422 unprocessable_entity".
  Map to a human sentence: "Please enter a name".

## 3. User control and freedom

Support undo and redo. Never trap the user.

- **Where it shows up here:**
  - Every destructive action has a confirmation dialog ("Delete
    'Acme'?") — see `add-settings` for the Danger Zone pattern.
  - Inline optimistic updates for trivial reversibles (archive, toggle)
    with an undo toast — `docs/UX.md` "Modal vs inline confirm".
  - Browser back / forward should restore scroll position and form
    state. Don't `replaceState` on form changes.
- **Failure mode:** "Submit" with no Cancel. If the dialog is dismissable
  via Esc and the backdrop click, the user has a way out.

## 4. Consistency and standards

Same words, same actions, same order. Every screen.

- **Where it shows up here:**
  - The shell is the same on every page (`PageShell`). Never bypass it.
  - Primary action is always bottom-right of a form.
  - Cancel is always a ghost / link button, never a second filled
    button.
  - Destructive buttons are always `variant="destructive"`, always at
    the bottom of a section, always in the Danger Zone.
- **Failure mode:** Two pages that put the primary action in different
  corners. Pick one, document it, follow it everywhere.

## 5. Error prevention

Catch errors before they happen. Constrain inputs.

- **Where it shows up here:**
  - Zod schemas with `min` / `max` / `email` / `url` constraints.
  - Confirmation for irreversible actions — but only via
    `modals.openConfirmModal`, never the native browser `confirm()`.
    `ui-lint`'s `native-dialog` rule fails the build on the latter.
  - Disabled submit while pending — prevents double-submit.
  - `<Input type="email">`, `<Input type="number" min={1}>` — the browser
    provides a keyboard hint that helps.
- **Failure mode:** A free-text field for an email that accepts
  "not-an-email". The schema catches it on submit, but the input type
  prevents the user from typing the worst forms.

## 6. Recognition rather than recall

Show, don't make the user remember. Make options visible.

- **Where it shows up here:**
  - `DropdownMenu` instead of a button that opens a modal for "what
    should happen to this row?".
  - Placeholders are *examples*, not labels. The label is always
    visible above the input (`FieldLabel`).
  - Recent items at the top of a search dropdown.
  - `Breadcrumb` for deep navigation. Don't make the user remember the
    route.
- **Failure mode:** A blank `<textarea>` with no hint about what to put
  in it. Always have a `FieldDescription` or placeholder that explains.

## 7. Flexibility and efficiency of use

Shortcuts for power users. Don't hide the common path.

- **Where it shows up here:**
  - ⌘K palette (`command-palette.tsx`) for fast navigation.
  - Keyboard shortcuts: `Esc` closes dialogs, `Enter` submits forms,
    arrow keys navigate tables and selects.
  - Bulk actions on the data table (select N rows → archive all).
  - Recently-used items in the search palette.
- **Failure mode:** A flow that requires 5 clicks when a power user
  could do it in 1 with a shortcut. Build the shortcut in parallel with
  the click path, not as a "pro feature" later.

## 8. Aesthetic and minimalist design

Every element earns its place. Remove what doesn't.

- **Where it shows up here:**
  - The shell is a fixed viewport (`h-svh overflow-hidden`); pages
    scroll inside `PageShell`. No long stacked pages.
  - Charts: max 5 series. Anything past 5 is unreadable.
  - Modals: one primary action, one cancel. No "Learn more" buttons.
  - Empty states: 3 lines max + one CTA. No illustrations. No lorem.
- **Failure mode:** A dashboard with 12 widgets. Pick the 4 that
  matter, delete the rest.

## 9. Help users recognize, diagnose, recover from errors

Error messages should say what happened, why, and what to do next.

- **Where it shows up here:**
  - `getErrorMessage(error)` returns a human sentence.
  - Form errors via `form.setError("field", { message })` — rendered by
    `FormMessage`.
  - Toast for cross-cutting errors ("rate limit", "session expired").
- **Failure mode:** "Something went wrong" toast. Always say what +
  what to do. "Couldn't save changes — check your connection and try
  again."

## 10. Help and documentation

The user shouldn't need docs to use the app, but docs help.

- **Where it shows up here:**
  - Tooltips on icon-only buttons (`aria-label` is also there for
    screen readers).
  - `FieldDescription` for inputs that aren't self-explanatory.
  - Empty states tell the user what will appear here + how to make it
    appear (the CTA).
- **Failure mode:** An advanced feature with no hint about its
  existence. Power users find it via the ⌘K palette; everyone else
  finds it because there's a discoverable entry point (Settings,
  empty-state CTA, etc.).

## How to use this list

When you're designing a new screen:

1. Pick the heuristics most relevant to your screen (e.g. settings
   pages care about #3, #6, #10; data tables care about #2, #8).
2. For each, check whether your design satisfies it.
3. If not, either fix the design or note the deviation in `DECISIONS.md`.

When you're reviewing someone else's screen:

1. Walk the list top-down.
2. For each violated heuristic, name it ("#5 violated — submit not
   disabled while pending") and propose a fix.
3. Don't ship if more than 2 are violated on a critical flow.

This doc is read-only; it informs but does not enforce. The mechanical
counterparts are `ux-prepass` (textual gates) and `make a11y` (axe
violations).
