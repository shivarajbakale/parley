---
name: verify
description: Prove a Flutter change actually works by analyzing, testing, and running the app — not just reading the diff. Run before declaring any non-trivial change done. Use after add-feature/add-screen or any change with runtime behavior.
---

# verify — don't declare done until it runs

A change is not done because it analyzes clean. Observe the app actually showing
the change.

## The loop

1. **Codegen (if you touched a freezed model or Drift table)** — generated code
   is committed, so a clean clone runs without it, but you must regenerate after
   editing a model:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
2. **Analyze** — `flutter analyze`. Zero errors. Fix and repeat;
   don't silence with `// ignore:` unless there's a documented reason.
3. **UI contract** — `dart run tool/ui_lint.dart`. Zero violations. Every one
   names the DS widget or token to use instead; if the exception is real, waive
   it with `// ui-lint: allow <rule-id> — <reason>` and say why. Never delete a
   rule to get past it.
4. **Feature plans** — `dart run tool/plan_lint.dart`. Silent on a project
   with no plans. If it fires, the plan JSON and the `FEATURE-PLAN.md` rendered
   from it have diverged: fix the JSON and re-render with `make plan
   PLAN=<id>.feature-plan.json`. Never hand-edit the document — it is generated,
   and editing it is exactly what P2 is looking for.
5. **Design-system reference** — `dart run tool/design_system_reference.dart
   --check`. If it reports the reference is stale, you added or changed a
   component: run `make design-system-reference-update` and commit the result.
   If it reports a component with no selection entry, write the `use` +
   `instead` pair in `tool/design_system_reference.dart` — the `instead` half
   is the one that earns the entry.
6. **The probe** — `make ui-probe`. The level-3 gate, and the only one that
   grades a *first draft*: it mounts every catalog page and every registered
   screen across three widths, three text scales and both platform skins, and
   fails on absolute facts — a row that overflowed, a control under the tap
   floor, content cut with an ellipsis, a box narrower than a word of what it
   holds, two runs of text painted over each other, a page whose subject is
   below the fold. `analyze` reads types, `ui_lint` reads source text, a test
   checks what somebody thought to check, and a golden only fails on a
   *change*, so none of the four grades a screen nobody has looked at.

   **A new screen is invisible to it until it is registered.** Add the screen
   to `appScreens` in `test/_screens.dart`; the probe's corpus and the golden
   sheets both read that list, and `test/screens_registry_test.dart` fails a
   `*_page.dart` that is in neither it nor the documented-gap list beside it.

   Two of the probe's rules — `clipped-text` and `overlap` — are graded against
   `test/probe/debt.dart` rather than against zero, because they found a class
   of defect in a kit built before anything measured it. The count ratchets in
   both directions: a surface that gains one fails, and a surface that loses
   one fails until the number is lowered.

7. **Goldens** — `make golden`. The pixel baselines cover the design system and
   every demo screen, each rendered on both platforms, in both brightnesses,
   and again at textScale 2.0. A failure prints a percentage and writes the
   before/after pair to `test/golden/failures/` — **look at those images**. If
   the change was intended, `make golden-update` and read the diff before
   committing it; that reading is the review. If it was not, you have found a
   regression the widget tests could not see. Never update a baseline to make a
   red gate go away.

   The baselines belong to one host (`GOLDEN_HOST` in the Makefile, macOS by
   default) because text rasterisation differs between operating systems. On
   any other host the target says so and skips, and the `goldens` job in CI
   runs them on the matching runner.
8. **Test** — `flutter test`. If you added behavior, there must be a test that
   exercises it (copy the `ProviderScope`-override pattern in
   `test/widget_test.dart` so tests never hit Dio). Single file:
   `flutter test test/screens/<feature>_page_test.dart`.
9. **Boot it on a device** — `make run-capture`. It picks a screenshot-capable
   device (an iOS simulator or an Android emulator — Flutter's own
   `capabilities.screenshot` is the predicate, so a physical iPhone, macOS and
   Chrome are all correctly excluded), boots the app, waits for the daemon's
   `app.started` event, writes the launch frame to
   `build/run-capture/<timestamp>-<env>.png`, and
   fails if there is no device, if the build dies, or if the frame it captured
   is small enough to be blank. **Open the PNG.** It is the level-3 evidence,
   and citing a path nobody looked at is the honour system with extra steps.

   This is the only step that starts the app on a real platform. The probe
   above mounts real widgets in a binding with *no platform under it*, so a
   missing `Info.plist` usage string, a plugin whose iOS half was never
   pod-installed, or a `main()` awaiting a channel nothing answers is green
   through every gate in `make check` and dead on first launch.

   It captures the launch frame and cannot navigate: the router sets
   `initialLocation` explicitly, so `flutter run --route` is ignored, and the
   app registers no URL scheme to deep-link into. A claim about a *particular*
   screen is step 10's, not this one's.

10. **Drive it** — `flutter run --dart-define=ENV=dev` (the mock backend is
   on by default). Actually exercise the changed flow:
   - Navigate to the screen (bottom nav / sidebar / a push).
   - Perform any action and confirm the UI updates.
   - Toggle light/dark once to confirm nothing hard-codes a color.
   - **Raise the text size to the maximum** in the OS accessibility settings
     and look at the screen again. Fixed-height rows clip, single-line labels
     overflow, and button rows stop fitting — the three failures that make up
     most of what breaks at scale. Minimum heights, not fixed heights.
   - **Check the reachable zone.** The primary action belongs bottom and full
     width above the safe area, not bottom-right
     (`docs/principles/screen-archetypes.md`).
   - **Look at the other platform.** The app renders two skins from one tree
     (`docs/principles/platform-adaptivity.md`), and a change made while
     holding one device regresses the other silently. A simulator on each side
     is the real check; a widget test wrapped in
     `Theme(data: theme.copyWith(platform: TargetPlatform.android))` is the
     cheap one, and is how `test/theme/adaptive_tokens_test.dart` covers both
     sides on one machine. Never reach for `Platform.isIOS` to do this — it
     reads the device rather than the theme, so it ignores the override.

`make check` wraps setup + ds-catalog-check + analyze + ui-lint + palette-lint +
plan-lint + superplan-lint + doc-lint + loop-lint + design-system-reference +
test + ui-probe + golden as the baseline gate. This list is the whole of it —
an earlier version of this file left `ui-probe` and `palette-lint` out, and a
screen that no gate mounted shipped underneath the gap. `run-capture` is
deliberately outside it, like `golden`: it needs a device this machine may not
have, and it fails rather than skips when there is none.

## Report

State exactly what you ran and what you observed (e.g. "opened the Notes tab →
seeded rows rendered; added one → list updated"). If a step was skipped, say so.
Do not report success on the analyzer alone.
