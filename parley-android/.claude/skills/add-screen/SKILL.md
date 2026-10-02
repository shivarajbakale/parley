---
name: add-screen
description: Add a standalone screen/page and wire it into go_router and the app shell — no data model needed. Use when the user wants a routed screen that isn't a data feature (e.g. an About page, a Help screen, an onboarding step, a full-page detail view).
---

# add-screen — a routed screen without a data slice

For a data-backed feature use `add-feature`. This is the lighter case: one screen,
wired into navigation. Routing is **go_router**, built in a Riverpod provider.

## Plan it first

One screen with an obvious shape does not need a plan. A screen where the
archetype is a real choice does: run `plan-feature`, which draws the frame and
the states before any of it is code. `plan-lint` keeps the rendered document
and its source JSON together afterwards.

## The edits

1. **The screen** — create `lib/screens/<name>_page.dart` as a `ConsumerWidget`
   (or `StatelessWidget` if it needs no providers). Build it from the
   design-system widgets (barrel `lib/design_system/design_system.dart`;
   `lib/design_system/ds_page_header.dart` for the header) and theme tokens
   (`lib/theme/tokens.dart`). Copy `lib/screens/settings/about_page.dart` for a
   simple static screen. Never hard-code colors or paddings.

   **Pick the archetype before you write any layout** — Focal, Collection,
   Detail, Form or Settings, from `docs/principles/screen-archetypes.md`. A
   screen that is two archetypes is two screens, and naming it first is what
   stops a grid of six equal tiles standing in for a hierarchy.

   **Read `docs/references/design-system-reference-llms.txt` first.** It lists
   all 44 components in one pass with a `Use when:` / `Instead:` line each, so
   you pick the right one rather than the first one you remember. `ui_lint`
   fails a screen that hand-rolls what the kit already owns, and this is where
   you find out what it owns. The **Components** tab
   (`lib/screens/design_system/`) is the same catalog rendered live — every
   variant, state and size of a widget on one page.
2. **Route constant** — add a path to `AppRoutes` in `lib/utils/app_routes.dart`.
3. **Route wiring** — add a `GoRoute` in `lib/utils/app_router.dart`. If the
   screen must be reachable signed-out, add its path to the `_publicRoutes` set
   there (otherwise the auth redirect will bounce it).
4. **Reach it** — either push to the route from an existing screen, or, for a
   top-level destination, mount it into the `PageView` and add one entry to the
   `_destinations` list in `lib/screens/home_screen.dart` (that single list
   drives the `NavigationBar` and the `NavigationDrawer`).
5. **Register it for the gates** — add an `AppScreen` entry to `appScreens` in
   `test/_screens.dart`. That list is what `make ui-probe` walks and what
   `make golden` records, so a screen missing from it is measured by nothing
   and pictured by nothing. `test/screens_registry_test.dart` fails a
   `*_page.dart` that appears in neither `appScreens` nor the
   `ungradedScreens` map beside it, so the choice is register it or write down
   why not — silence is not one of the options. A screen whose content is its
   fixture (a list, an article, a detail view) sets `contentDriven: true` and
   is walked a second time with the long-content fixtures, which is where a
   headline that only fits because the demo copy is short gets found.

## Rules

- Bottom-nav tabs are **not** routed — they mount directly in the `PageView` in
  `lib/screens/home_screen.dart`. Pushed sub-screens get a `GoRoute` child under
  `'/'` in `lib/utils/app_router.dart`. Pick the right one for how the screen is
  reached.
- Keep the design-token discipline (no `Color(0xFF…)` outside `lib/theme/`, no
  magic paddings — use `AppSpacing.*`).

## Verify

`flutter analyze`, then `dart run tool/ui_lint.dart` — build the screen out of
the DS widgets and the theme tokens and it passes; hand-roll a control and it
names the one to use instead — then `flutter test` (add a route test
mirroring `test/router_test.dart` if the screen is routed), then `flutter run`
and navigate to the screen. Run the `verify` skill for the full bar.

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
