<!-- principle:component-selection:v1 -->

# Component Selection

Every gate in this project checks that a screen was built *correctly*. None of
them check that it was built out of the *right parts*.

## The failure this prevents

`ui_lint`'s twenty rules all ask one question: did you hand-roll or hardcode
something the kit already owns? So a settings screen built as a nine-tab tab
bar, a destructive confirm buried in a snack bar, or a twenty-option
`DSSegmentedButton` passes every automated check in the repository — every
control came from `lib/design_system/`.

Choosing the wrong control is the most common way a screen built entirely from
the design system still feels wrong to use.

Per-component guidance lives in the `Use when:` / `Instead:` lines of
[design-system-reference-llms.txt](../references/design-system-reference-llms.txt),
and the **Components** tab in the running app shows each of them in every
usage worth comparing.
That file handles the pairwise cases. This one handles the three- and four-way
decisions, where several components are all defensible and only one is right.

## The default

**When two options are defensible, pick the one that is visible, reachable with
a thumb, and survives a screen reader.** Almost every rule below is that
sentence applied to a family. Reach for the cleverer option only when you can
say what it buys.

## Interruption — sheet / dialog / snack bar / banner / inline

Two questions, in order:

1. **Must the user answer before anything else can happen?** If yes it is a
   `DSDialog`, and that is the only thing a dialog is for. A dialog the user
   can safely dismiss should not have been a dialog.
2. **Does the message need to survive?** If it must stay until acted on, it is
   a `DSMessage` — `scope: screen` above the content, `scope: section` inside
   it. If it merely confirms something that already happened, it is a
   `DSSnackBar`.

| Surface | Blocks? | Lifetime | Typical |
| --- | --- | --- | --- |
| `DSDialog` | yes | until answered | delete, discard, resolve a conflict |
| `DSBottomSheet` | no | until dismissed | pick an option, a short task |
| `DSBottomSheet` + `snapPoints` | no | multi-height | a map filter, a now-playing panel |
| `DSMenu` | no | until a command runs | three to seven actions on one item |
| `DSMessage.screen` | no | until acted on | offline, expired session, degraded mode |
| `DSMessage.section` | no | until acted on | an unaccepted invite, a draft, a read-only notice |
| `DSSnackBar` | no | seconds | "Saved", "Deleted" + undo |

**On a phone, prefer the sheet.** A sheet is reachable with a thumb, drags away
naturally, and can hold a real amount of content. A dialog on a phone is a
small box in the middle of a screen the user cannot reach the top of. Reserve
it for the case where blocking is the point.

**Never put a required action only in a snack bar.** It leaves on a timer, it
is unreachable by keyboard, and on a slow screen reader it is gone before it is
announced.

## Choosing one of a set

Count the options first.

| Count | Control | Why |
| --- | --- | --- |
| 2–4, visible | `DSSegmentedButton` | showing them all costs nothing |
| 4–20 | `DSSelect` | a list you scan |
| 20+, or the name is known | `DSSearchBar` + list | typing beats scrolling |
| many, several may be on | `DSMultiSelect` | the trigger summarises, the menu stays open |
| 2–5, each a whole view | `DSTabBar` | it is navigation, not a value |

The line people cross without noticing: **a tab is not a value.** If the choice
sets something you would send to a server, it is a control. If it changes what
the screen is showing, it is navigation.

## Navigation

| Destinations | Use |
| --- | --- |
| 3–5 top-level | `DSBottomNavBar` |
| 6+, or secondary | `DSSidebar` |
| peer views inside one destination | `DSTabBar` |
| a drill-in from a list | a pushed route (`AppTheme` supplies the platform transition) |
| a task with a beginning and an end | `showDSBottomSheet(fit: DSSheetFit.expanded)` |

**A route, not a sheet, when the user might want to come back to it.** A route
keeps the platform back gesture, survives rotation, and can be deep-linked. A
transient surface is for something finished or abandoned in one sitting.

Every one of the surfaces above is presented through `showDSOverlay`, which is
why they share a scrim, a motion contract and a dismissal policy. A surface
presented any other way is off the navigator, and `ui_lint` fails the build on
`showDialog`, `showModalBottomSheet`, `Overlay.of(...).insert` and a private
`PopupRoute` subclass.

Bottom nav and a drawer are alternatives, not layers. Both at once means the
user has to learn where each destination lives.

## Loading

| State | Use |
| --- | --- |
| the shape of what is coming is known | `DSSkeleton` |
| nothing on screen yet | `DSLoadingState` |
| an operation in flight | `DSProgressIndicator` |
| a list refreshing with content already up | pull-to-refresh, not a spinner |

**Never replace real content with a spinner.** If part of the screen has
loaded, it stays; the part that has not gets a skeleton. A full-screen spinner
over content the user could have been reading is throwing away the only thing
you had.

`DSSkeleton` derives the skeleton from the real widget tree, so it cannot drift
out of shape with the content it stands for. Hand-drawn placeholder boxes
always do.

## Empty vs error vs zero

Three different screens, and they are routinely conflated:

- **Empty** — the query worked, there is nothing yet. Say what belongs here and
  give exactly one action that creates it. `DSEmptyState`.
- **Error** — the query failed. Say what failed in human words and offer retry.
  Never the raw exception.
- **Zero results** — the query worked, the *filter* excluded everything. Offer
  to clear the filter, not to create a record.

Showing an empty state while a fetch is still running tells the user their data
is gone. Showing it for zero results tells them to create a record they already
have.

## Destructive actions

Confirm in a `DSDialog`, name the object ("Delete 'Acme'?"), and label the
button with the verb ("Delete") rather than "OK". Reversible actions
(archive, mark done, toggle) get an optimistic update plus an undo in a
`DSSnackBar` — a confirm dialog on something undoable is a tax on every use to
protect against a mistake that costs nothing.

## When nothing fits

Say so, and then either compose from existing components or add one to
`lib/design_system/` — with its `use` + `instead` entry in
`tool/design_system_reference.dart`, which is a build failure if you skip it,
and its usages in `lib/screens/design_system/catalog/`, which is a test
failure if you skip that.
What you may not do is hand-roll it in `lib/screens/`; `ui_lint` fails that,
and it is the mechanism by which a design system becomes decoration.

## Changing a component without editing it

The kit is a package, not a folder of widgets you own. Every appearance
resolves through four layers, and each overrides only what it sets:

    1. ComponentSpec / DesignSpec   the identity   "wells are 40dp in this app"
    2. ThemeExtension<DSxStyle>     a subtree      "cards are flat on this screen"
    3. DSScope                      a container    "controls in this footer are small"
    4. style:                       one instance   "this card has no shadow"
    5. a slot                       replacement    "draw this instead"

`DSCardStyle` in `ds_card.dart` is the worked example, and
`DSComponentStyle` states the four rules every style object obeys — all fields
nullable, defaults read from the spec inside `resolve` and nowhere else, a real
`lerp`, and no behaviour. `ui_lint` fails a style object that breaks the first
three.

The test for whether a component is open: **could a caller who cannot edit
`lib/design_system/` get the look they need?** If the only answer is "add an
enum case", the component is closed, and the fix is a style field or a slot —
not a fifteenth variant.

`DSScope` carries exactly four things a container may tell its contents — size,
density, tone, enabled — and supplies them as *defaults*. An explicit argument
always wins, so a large button inside a compact footer is large.

## The floor

`DSPressable` is the unstyled floor beneath every interactive component: press
feedback, focus, haptics and disabled semantics, with no paint. A control that
handles its own taps and never reaches it has re-implemented all of that, worse
— so `ui_lint`'s `pressable-floor` rule fails a design-system file that builds
a `GestureDetector` or an `InkWell` and never mentions `DSPressable`.

`DSSkeleton` is the same idea for loading: the shimmer, with no shape opinion.
