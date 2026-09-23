---
name: add-welcome
description: Build the first-run welcome — the one screen whose whole job is to say what the app is before anything is asked, and the two flags that decide who ever sees it. Use when the user wants a welcome screen, a splash that says something, a "get started" screen, or a first-run moment before onboarding.
---

# add-welcome — the moment a new user meets the app

Not the tour. `add-tour` builds the three-stop sequence that runs *after* the
user agrees to be introduced; this is the single screen before it, and the two
are separated by a flag on purpose.

## Decide whether you need one at all

A welcome earns its screen when the app's value is not obvious from its first
real screen. If the first screen explains itself — a list with an empty state
that says what to put in it — the welcome is a tap between the user and the
thing they came for.

Build it when the answer to "what is this?" has to arrive before the answer to
"what do I do?".

## Two flags, not one

`lib/models/app_settings.dart` carries **`welcomeSeen`** and
**`onboardingComplete`**, and collapsing them is the tempting mistake:

- `welcomeSeen` — the user has been *introduced*. Every way off the welcome
  sets it, including the skip and the "I already have an account" shortcut.
- `onboardingComplete` — the user has *finished the tour*.

They answer different questions, and one flag cannot express "introduced, but
walked away mid-tour" — which is the state a user is in every time they kill
the app on stop two. `lib/utils/app_router.dart` reads both;
`test/onboarding_test.dart` covers the four combinations plus the walk.

## The edits

1. **The screen** — `lib/screens/welcome_page.dart` is the worked example.
   Copy its shape rather than its copy:
   - a `DSLargeAppBar` with an **empty `title` and the headline in
     `subtitle`**. That is the configuration `ui_lint`'s
     `header-earns-its-height` rule grades — a tall bar whose payload is a
     headline is a header, a tall bar with nothing in it is chrome.
   - one drawing, composed in a `DSTourCanvas`
     (`lib/design_system/ds_tour_art.dart`). A picture of what *this app*
     does, not a stock icon.
   - a row of three `DSStatTile`s at `DSStatTileSize.compact`. Three md-scale
     tiles do not fit a 320pt phone and the welcome has to.
   - a `DSPinnedActionBar` holding exactly one primary and one ghost.
2. **Three tiers of action, and no more.** The primary commits, the bar's ghost
   is the shortcut for a returning user, and anything else is a *small* ghost
   inside the body — `lib/screens/welcome_sheet.dart` is the shipped one, a
   peek-detent `DSBottomSheet` previewing the tour's own stops. Three equal
   actions is a screen with none.
3. **Route it** — a constant in `lib/utils/app_routes.dart`, a `GoRoute` in
   `lib/utils/app_router.dart`, and the redirect. The welcome is a public
   route: it runs before sign-in.
4. **Persist on every exit path.** Each way off the screen calls
   `markWelcomeSeen()` in `lib/providers/settings_provider.dart` before it
   navigates. A skip that does not set the flag is a screen the user is shown
   again tomorrow.
5. **Register it for the gates** — an `AppScreen` entry in `test/_screens.dart`.
   That list is what `make ui-probe` walks and `make golden` records, and
   `test/screens_registry_test.dart` fails a `*_page.dart` in neither it nor
   the `ungradedScreens` map beside it.

## Write the copy last

The headline is the one sentence the app gets. Name what the user will be able
to do, not what the software is: "A faster way to track what you're building"
is a claim; "Beautiful, fast and modern" is a brochure.

The three stat tiles are figures, not adjectives. A figure the reader can check
is worth three they cannot.

## Verify

`flutter analyze`, `dart run tool/ui_lint.dart`, then `flutter test`. Then the
walk itself, because the flags are the part that breaks:
`test/onboarding_test.dart` boots the real app with empty preferences, taps
through welcome → tour → sign-in, and asserts both flags landed — a redirect
tested only with flags set from the outside is a redirect nobody has walked.

Run `make golden` for the baselines and `make ui-probe` for the shape. Then the
`verify` skill for the full bar.

<!-- ux-prepass:v2 -->
<!-- MANDATORY before marking this task done. Same wording as evaluator-rubric.md "UI pre-pass". -->
## Pre-passing checklist (all mandatory)

- [ ] Four states handled: loading, empty, error, success
- [ ] Touch targets >= 48x48dp (Material minimum)
- [ ] Semantics labels on icon-only controls (screen readers)
- [ ] Dark mode checked — theme scheme roles only, no hardcoded hex
- [ ] Content wraps, labels ellipsise. A headline, title or body string cut
      with "…" is a defect, not a fitted layout — give it lines. `make
      ui-probe` fails it (`clipped-text`), and fails a box narrower than a
      word of what it holds (`word-break`)
- [ ] Every new screen registered in `test/_screens.dart` — that list is what
      `make ui-probe` walks and `make golden` records, and an unregistered
      screen is graded by nothing
- [ ] Navigation works via keyboard/external input where supported
