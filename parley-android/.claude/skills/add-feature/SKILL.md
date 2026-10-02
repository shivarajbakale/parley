---
name: add-feature
description: Build a full feature slice the way this app is structured — model → API client (Dio, mock-backed) → Riverpod state → screen (design-system widgets) → route + nav → widget test. Use when the user asks to "add a feature", "add a screen for X", "build X", or "add a section" (e.g. a Notes list, an Orders tab).
---

# add-feature — a full Riverpod slice, the way this app is built

This app ships an **app shell + integration seams + a written recipe**, not a
throwaway CRUD toy. So you don't copy one "reference resource" — you follow the
recipe and imitate the two real slices that already exist.

## Plan it first

If more than one shape is defensible — and for a new feature it almost always
is — run `plan-feature` before this skill. It renders the screens as frames the
user can look at, which is a review that costs nothing; the alternative is
having the layout argument against a diff, three tests and a golden baseline.
`plan-lint` runs in `make check`, so the plan stays a checked artifact
afterwards rather than a note.

Skip it for a change the user has already specified down to the file.

## Read these first

- `docs/FEATURES.md` — the canonical 7-step recipe + page-layout templates.
- `docs/EXAMPLE_FEATURE.md` — that recipe run end-to-end (the "Ping Log" walk-through).
- `ARCHITECTURE.md` + `docs/CONSTRAINTS.md` — the layering + hard rules.

**Real slices to imitate for structure:**

| Concern | Simplest real example | Fuller real example |
| --- | --- | --- |
| Model | `lib/models/app_settings.dart` (hand-written) | `lib/models/library_item.dart` (freezed + json) |
| State (Riverpod) | `lib/providers/settings_provider.dart` | `lib/providers/auth_provider.dart` |
| Screen | `lib/screens/settings_page.dart` | `lib/screens/auth/login_page.dart` |
| Data / API client | `lib/data/library_repository.dart` (repository + providers) | `lib/services/auth/auth_service.dart` |
| List screen (async + skeleton + refresh) | `lib/screens/home/library_page.dart` | — |
| Mock backend (offline) | `lib/data/mock/mock_routes.dart` + `lib/data/mock/mock_store.dart` | — |
| Test | `test/widget_test.dart` | `test/auth/auth_flow_test.dart` |

## Procedure (substitute your feature; create the placeholder paths below)

State is **Riverpod** (`StateNotifier` + `StateNotifierProvider`). Layering is
`screens/design_system → providers → data/services → models`.

1. **Clarify the shape** — feature name and the fields of its model. Keep it small.
2. **Model** — `lib/models/<feature>.dart`. Plain class for something trivial
   (copy `lib/models/app_settings.dart`); freezed for anything non-trivial (copy
   `lib/models/library_item.dart`, keep the `part '<feature>.freezed.dart'` /
   `.g.dart` directives, then run codegen — see Verify).
3. **API client** — `lib/data/<feature>_api.dart`, taking a `Dio` in its
   constructor and using `dioCall<T>()` from `lib/data/dio_client.dart`. Register
   a mock route in `lib/data/mock/mock_routes.dart` (+ seed in
   `lib/data/mock/mock_store.dart`) so the feature runs offline — the mock
   backend is on by default (`lib/data/api_config.dart`).
4. **State** — `lib/providers/<feature>_provider.dart`, a `StateNotifier` +
   `StateNotifierProvider` (copy `lib/providers/settings_provider.dart`). Read the
   shared Dio from `dioProvider` in `lib/providers/database_provider.dart`.
5. **Screen** — `lib/screens/<feature>_page.dart`, a `ConsumerWidget`, built from
   the design-system widgets (barrel `lib/design_system/design_system.dart` —
   e.g. `lib/design_system/ds_page_header.dart`) and theme tokens
   (`lib/theme/tokens.dart`). **No hard-coded colors or paddings** (see rules).
   Pick the archetype from `docs/principles/screen-archetypes.md`, then the
   widgets from `docs/references/design-system-reference-llms.txt`, which
   carries a `Use when:` / `Instead:` line for every one of them. Run the app
   and open the **Components** tab to see any of them at size.
   `docs/principles/component-selection.md` covers the choices that reference
   cannot — sheet vs dialog vs snack bar, tab vs segmented button, which of the
   three loading states.
6. **Route + nav** — add a route path constant in `lib/utils/app_routes.dart` and
   a `GoRoute` in `lib/utils/app_router.dart`. For a top-level tab, mount the page
   into the `PageView` in `lib/screens/home_screen.dart` and add one entry to
   the `_destinations` list at the top of that file — it drives the
   `NavigationBar` and the `NavigationDrawer` together.
7. **Test** — `test/screens/<feature>_page_test.dart`, overriding your provider
   with a stub so it never hits Dio (copy the `ProviderScope` pattern in
   `test/widget_test.dart`).

## Non-negotiables (from `docs/CONSTRAINTS.md`)

- **No `Color(0xFF…)` outside `lib/theme/`.** Use `context.palette`, which
  resolves the brightness for you, or `Theme.of(context).colorScheme`. The
  palette is derived in `lib/theme/spec/palette_spec.dart`.
- **No magic padding numbers** — use `AppSpacing.*` (via `lib/theme/tokens.dart`).
- Respect the dependency direction; don't reach from a model up into a screen.

## Definition of done

Run the `verify` skill. Minimum bar: `flutter analyze` clean,
`dart run tool/ui_lint.dart` clean,
`flutter test` green (incl. your new test), and `flutter run` shows the feature
working against the mock backend. Report what you added (one line per layer).

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
