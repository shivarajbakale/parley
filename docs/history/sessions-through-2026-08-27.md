# Session history — through 2026-08-27

Archived from `claude-progress.md`, which is now a state file rewritten each
session rather than an append-only log. Nothing here is current: read it when you
need the narrative of a finished session, and read `claude-progress.md` for what
is true now.

---

# Progress Log

## Current Verified State

- Repository root: `templates/flutter/boilerplate`
- Standard startup path: `./init.sh`
- Standard verification path: `make check` (pub get + analyze + test)
- Current highest-priority unfinished feature: `feature-001` — "Replace the
  Library placeholder with your first feature"
- UI baseline (2026-08-19, `boilerplate-014`): the design system wraps stock
  Material 3 widgets — `NavigationBar`, `NavigationDrawer`, `ListTile` — plus
  `skeletonizer` and `flutter_animate`. Do not re-implement them; the contract
  is locked by `test/design_system/standard_widgets_test.dart`.
- Release baseline (2026-08-19, `boilerplate-015`): the `ship` skill is the
  release path. Run it before any store upload — a fresh scaffold is
  deliberately unshippable (placeholder ids, debug-signed release build,
  missing iOS build inputs) and the skill's sweep is what finds that.
- Current blocker: none
- Ship-fast modules (auth, paywall, observability, identity tooling) are
  built and `passing` — see `boilerplate-003..006` and `docs/MODULES.md`.

## Session Log

### Session 009 — `ship`: release readiness, then release

- Added `.claude/skills/ship/SKILL.md` (`boilerplate-015`). It sweeps the project
  for everything that keeps a scaffold off the stores, classifies each finding as
  a blocker / policy item / warning with a `file:line`, fixes them in dependency
  order, builds, and uploads only after an explicit go-ahead.
- Its first run against this boilerplate found seven blockers. One was fixed
  here rather than left for every future scaffold to rediscover: the unused
  camera surface — `NSCameraUsageDescription` and
  `NSPhotoLibraryUsageDescription` in `ios/Runner/Info.plist`, both still
  describing the todo demo removed in Session 008, plus
  `android.permission.CAMERA`. Nothing in `lib/` or `pubspec.yaml` requests a
  camera, and Apple rejects permissions an app cannot justify.
- The remaining six are intentional: they are per-project values (bundle id,
  signing key, icon, prod API URL) that only the app's owner can supply, which is
  exactly what the skill exists to walk them through.
- Verified: `flutter analyze` 0 errors (14 pre-existing infos), `flutter test`
  42 passing, `plutil -lint ios/Runner/Info.plist` OK.

### Session 008 — boilerplate-014: full-width UI on standard Material 3 components

- Date: 2026-08-19
- Goal: the shipped UI read as substandard — a near-empty Home tab, a sparse
  Library list, elements floating inside their own margins, and a design system
  that re-implemented widgets Material already ships. Fix the look, cut the
  duplicated demo scaffolding, and move the DS to standard components.

**Wrap, don't re-implement.** Four hand-rolled primitives were replaced by the
standard thing underneath, deleting ~430 lines:

- `DSBottomNavBar` — was a bespoke `Row` + `BackdropFilter` floating pill
  (inset 24pt from both edges, so it never spanned the width). Now a Material 3
  `NavigationBar`: full width, correct safe-area inset, indicator, semantics.
- `DSSidebar` — was ~180 lines of gesture math in `home_screen.dart`
  (drag tracking, scrim tween, custom `PageRouteBuilder`). Now a Material
  `NavigationDrawer` behind `Scaffold(drawer:)`, which brings edge-swipe,
  scrim, focus trapping, and back-dismiss for free. `ds_sidebar_item.dart`
  deleted.
- `DSSkeleton` — was a hand-drawn shimmer (`DSShimmer` inherited controller +
  placeholder boxes whose shape had to be maintained in parallel with the real
  rows). Now the `skeletonizer` package bone-rendering *the real widget tree*,
  so the skeleton cannot drift out of shape. `DSSkeletonList` builds from
  `DSListTile` itself.
- `DSRevealItem` — was a parent-owned `AnimationController` plus interval math
  that every list screen had to create, forward, and dispose. Now
  `flutter_animate`, with a per-index delay capped at 360ms so a long list has
  no tail.

**Layout.** `DSLargeAppBar` lost its `eyebrow` — a second label line *under* a
large title read backwards and cost a row of the first screenful; section
labels now live in the content via `DSSectionHeader`. `DSListTile` is
full-bleed (gutter-to-gutter, tinted circular leading, single-line title and
subtitle) and `listTileTheme.shape` is square, so a full-width row no longer
draws a rounded ink splash. Home became `screens/home/dashboard_page.dart`: a
hero card whose two actions are `Expanded` (previously shrink-wrapped chips)
plus a six-tile Explore grid — the whole tab fits one screenful. Library became
`screens/home/library_page.dart`.

**Less demo boilerplate.** There were three parallel toy domains. `ExampleItem`
(freezed, carrying a leftover `done` flag from the old todo demo) and the
`/api/example` route are deleted; `LibraryItem` is now the single freezed+json
model, seeded into `MockStore`, served at `/api/library`, decoded by the new
`lib/data/library_repository.dart`, and read by the Library tab as an
`AsyncValue` — so one model demonstrates the whole vertical slice. The Library
tab's fake `Future.delayed` is gone; it now does a real (mocked) fetch with
pull-to-refresh via `ref.refresh`.

**Verified**
- `flutter analyze` — 0 errors, 14 pre-existing `prefer_const_constructors`
  infos (unchanged count).
- `flutter test` — **42 pass**, including the new
  `test/design_system/standard_widgets_test.dart`, which fails if a nav
  primitive stops resolving to its Material widget or a row stops spanning the
  viewport.
- Ran on the iPhone 17 simulator (iOS 26.5): Home, Library, and Settings each
  fit one screenful, edge to edge. The drawer is covered by the widget test —
  driving it from the simulator by script was unreliable, so it was not
  visually captured.


### Session 007 — Premium-polish track (stage 1): haptics + shimmer skeletons

- Date: 2026-07-05
- Goal: Make the app *feel* premium without changing the editorial design
  language (user chose "polish current system" over a redesign). Target the
  execution details that read as expensive: tactile feedback + content-shaped
  loading.
- Completed:
  - **`AppHaptics` service (`lib/theme/app_haptics.dart`).** Central,
    semantic haptics (`selection/light/medium/heavy/success/warning/error`)
    gated by a single `enabled` flag synced from `SettingsNotifier` (on load
    + on change). **Fixes a real bug:** the "Haptic feedback" setting existed
    but the app mostly ignored it — raw `HapticFeedback.*` calls bypassed it.
    Wired into `DSButton` (emphasis-scaled), `DSSwitch`, `DSTabBar`,
    `ds_snap_bottom_sheet`, and home bottom-nav. NOTE: haptics don't fire on
    the iOS simulator — needs a physical device to feel.
  - **Shimmer skeleton system (`lib/design_system/ds_skeleton.dart`).**
    `DSShimmer` (one shared repeating controller so the highlight sweeps in
    unison) + `DSSkeleton`/`.line`/`.circle` + `DSSkeletonList`. Replaces the
    "spinner on an empty screen" tell. `DSLoadingState.skeleton()` factory
    added; spinner kept for indeterminate actions (purchases), skeleton for
    content loads.
  - **Library tab demo.** Swapped the static `_PlaceholderPage` for a real
    skeleton→content load (1.5s fake fetch + pull-to-refresh to replay) — the
    boilerplate now *demonstrates* the loading pattern instead of describing
    it. Rendered on iPhone 17 sim (see scratchpad/home_after.png).
  - **Motion (stage 2).** `DSRevealItem` — reusable staggered fade+slide
    (box + sliver lists, one parent controller) via `AppMotion.staggered`.
    Wired into Library so rows cascade in as content lands. Commit `bab9d66`.
  - **Depth / light-model (stage 3).** Unified `DSCard` onto the shared
    `AppShadows.resolve()` warm single-layer shadow contract — it was the only
    elevated surface still using Material's `Card` (M3 tonal tint + grey
    shadow) while sidebar/nav/banner/modal already used `AppShadows`. Added an
    opt-in `DSCard.heroGradient()` (whisper-subtle, theme-derived) and applied
    it to the Home hero card. Confirmed on iPhone 17 sim in Light mode
    (scratchpad/home_depth.png).
  - **Shared-axis list→detail (stage 4).** `AppMotion.sharedAxisTransition`
    (M3 shared-axis X: fade-through + horizontal slide). New
    `LibraryDetailPage` + `LibraryItem` model (`demoLibraryItems`, moved out of
    the Home shell). Route `/library/detail/:index` — deep-link safe (resolves
    by index; out-of-range falls back to home). Library rows now push into it.
    Built via the add-screen skill. Route tests added to `router_test.dart`.
  - **Dependency fix (pre-existing baseline break, not from this work):** the
    committed lock had `dio 5.9.2` but `lib/data/dio_client.dart` uses
    `DioExceptionType.transformTimeout` (added in dio 5.10.0) → 1 analyze
    error. Bumped dio to 5.10.0 (satisfies the existing `^5.7.0` pin).
- Verification: `flutter analyze --no-fatal-infos` ⇒ 0 errors (17 pre-existing
  const info lints); `flutter test` ⇒ 33/33 (added
  `test/design_system/premium_polish_test.dart` +8, `router_test.dart` +2 for
  the library-detail deep link); launched on iPhone 17 sim (light + dark).
- Also fixed a repo-wide bug: root `.gitignore` unanchored `test/` had kept
  every scaffolder's tests out of git (0 tracked across all 7). Anchored to
  `/test/`, committed 30 suites. Commit `c5c5604`.
- Deferred (premium-polish stage 4+): shared-axis list→detail transitions
  (needs a detail route); extend staggered reveal to Home cards. Plus the
  DS-consolidation stage 2 from Session 006 (still open).

### Session 006 — Design-system consistency pass (stage 1) + space utilization

- Date: 2026-07-05
- Goal: From a full DS audit (58 components + tokens), land the safe, visible
  fixes and reduce wasted side padding; stage the risky consolidations.
- Completed:
  - **`w600` correctness sweep (20 sites across `lib/`).** Satoshi ships no
    semibold, so every `FontWeight.w600` silently fell back. Mapped
    selected/active/CTA/badge states → `w700`, standalone titles/initials →
    `w500`. Fixed `ds_tab_bar` selected-pill weight inversion (was lighter
    than unselected). Touched: 14 DS files + `app_theme` navbar label +
    `home_screen`/`paywall`.
  - **Space utilization.** `AppSpacing.pageGutter` 20 → 16 (now on the 4pt
    grid, aliased to `lg`) — tightens every screen's side margins at once.
    This also cut the settings double-inset (container margin + row padding)
    from 40px → a standard 32px. Confirmed no content-narrowing constraints
    elsewhere.
  - **Touch targets.** `DSIconButton` default (`md`) 40 → 44pt (Apple HIG /
    Material min); `sm=32` documented as an intentional compact opt-in.
  - **`ds_text_field` `filled` variant** now renders a rounded filled box
    (was an `UnderlineInputBorder`, inconsistent with the app's rounded input
    language); `underlined` remains the only underline variant.
- Verification: `flutter analyze --no-fatal-infos` ⇒ 0 errors (15 pre-existing
  const info lints); `flutter test` ⇒ 23/23; launched on iPhone 17 sim.
- Deferred to stage 2 (each needs its own visual-review loop): `AppOpacity` +
  `AppIconSize` token scales + migration; collapse the two card engines
  (`DSCard`/`DS2Card`); share a dropdown base (`ds_select` /
  `ds_multi_select_dropdown`); share a picker base (date/range/time);
  consolidate the overlay/scrim layer + single `DSDragHandle`; extract
  `ds_search`'s feature machinery out of the DS; de-scope `DSButton` + unify
  the banner/info-card colour contract.

### Session 005 — Real backends, codegen + Drift, release tooling

- Date: 2026-05-25
- Goal: Make the remaining heavy items plug-and-play (user approved deps).
- Completed (committed in 3 sub-batches):
  - **Backends:** SupabaseAuthService + RevenueCatPurchasesService behind the
    existing seams; ServiceConfig branches on Env.hasSupabase / hasRevenueCat;
    main.dart inits SDKs only when keys present. Deps: supabase_flutter ^2.12,
    purchases_flutter ^10.1. Mock stays the default.
  - **Codegen + DB:** freezed + json_serializable (example_item) and Drift
    (app_database: Notes table + appDatabaseProvider). build_runner wired,
    generated files committed, `make gen`/`make watch`. Min SDK → 3.8 /
    Flutter 3.29 (json_serializable requirement).
  - **Release:** Fastlane lanes (Play internal/prod, TestFlight) + manual
    release.yml workflow (skeletons; need store secrets). .gitignore blocks
    keystores/.p8/Play JSON.
  - Docs: MODULES (Supabase/RevenueCat go-live now ship; codegen/DB section;
    Release section), ARCHITECTURE map, DECISIONS entry, feature_list
    boilerplate-011/012/013.
- Verification: `flutter analyze --no-fatal-infos` ⇒ 0 errors (14 pre-existing
  const lints); `flutter test` ⇒ 22/22 (added local_db_test); `./init.sh`
  exit 0.
- Known risk: release lanes unexecuted (need credentials); Supabase reset-link
  flow depends on the SDK's deep-link handler (documented); real-backend paths
  only exercised at compile time (mock paths are tested).
- Next best step: optional Shorebird (OTA) or a real-backend integration test
  behind a flag; otherwise proceed to feature-001.

### Session 004 — Env/flavors, onboarding, CI (plug-and-play batch)

- Date: 2026-05-25
- Goal: Make the remaining roadmap items plug-and-play. This batch covers the
  no-dependency, no-fork ones; dep-heavy items (real backend SDKs, codegen +
  local DB) are pending user confirmation.
- Completed:
  - **Env/flavors:** `lib/config/env.dart` (dev/staging/prod via
    `--dart-define`, safe dev defaults). `ApiConfig` delegates to `Env`.
    Makefile `run-staging` / `run-prod` / `build-prod`.
  - **Onboarding:** `lib/screens/onboarding_page.dart` carousel gated by
    `settings.onboardingComplete`; router shows `/onboarding` before auth on
    first launch; `_AuthRefresh` listens to the flag.
  - **CI:** `.github/workflows/ci.yml` (pub get + analyze + test on push/PR).
  - Docs: DECISIONS entry, MODULES (env/onboarding/CI sections), ARCHITECTURE
    map (config/ + new screens), BLUEPRINT modules table; `feature_list`
    boilerplate-008/009/010.
- Verification: `flutter analyze --no-fatal-infos` ⇒ 0 errors (14 pre-existing
  const lints); `flutter test` ⇒ 20/20 (added test/env_test.dart +
  test/onboarding_test.dart); `./init.sh` exit 0.
- Pending (needs user decision): real backend reference impls
  (Supabase/RevenueCat — adds heavy native deps) and codegen + local DB
  (freezed/Drift — adds build_runner to the workflow). Release CI lanes
  (signing/upload) need store secrets.

### Session 003 — go_router + deep links

- Date: 2026-05-25
- Goal: Replace static routing with go_router; gate routes by auth; support
  deep links (the next step flagged in Session 002).
- Completed:
  - `lib/utils/app_router.dart`: `routerProvider` (GoRouter) with a
    redirect-based auth gate (`_publicRoutes`), `refreshListenable` bridged to
    `authProvider`, and `?from=` deep-link replay through the cold-start splash.
  - `app.dart` → `MaterialApp.router`. `app_routes.dart` → path constants.
    Deleted the imperative `AuthGate`; added `lib/screens/splash_page.dart`.
  - Deep links: `/paywall` (fullscreen dialog) and `/reset?token=…`
    (`ResetPasswordPage` + `AuthService.completePasswordReset` + mock).
  - Migrated call sites to `context.push/go/pop` (login, forgot, settings).
  - Added in-app entry points so the loops are usable: Settings → Account
    (signed-in email, Upgrade to Pro → paywall, Sign out).
  - Dep: `go_router ^14.6.2`.
  - Docs: DECISIONS entry, FEATURES §6 rewritten, ARCHITECTURE flow + map,
    MODULES auth flow + new `#deep-links` section, `feature_list` boilerplate-007.
- Verification: `flutter analyze --no-fatal-infos` ⇒ 0 errors (14 pre-existing
  const lints); `flutter test` ⇒ 14/14 passing (added test/router_test.dart);
  `./init.sh` exit 0.
- Known risk: native universal/app-link config is per-app (documented, not
  wired). DS modals/sheets still use imperative Navigator (intentional).
- Next best step: optional — a real backend reference impl (Supabase/RevenueCat),
  env/flavors config, or proceed to feature-001.

### Session 002 — Ship-fast modules

- Date: 2026-05-25
- Goal: Make the boilerplate ship real apps fast — add the recurring vertical
  slices every app rebuilds, behind a pluggable seam (mocks by default).
- Completed:
  - New `lib/services/` integration seam: every third-party concern is an
    interface with a mock/console default, swapped in one place
    (`service_config.dart`). Mirrors `ApiConfig.useMockBackend`.
  - **Auth module:** `AuthService` + typed `AuthException`s, `TokenStore`
    (`SecureTokenStore` default via `flutter_secure_storage`, `InMemoryTokenStore`
    for tests), `MockAuthService` (demo@rocketship.dev / password).
    `authProvider` state machine + `AuthGate` (splash → auth flow → home,
    nested navigator). Screens: login / signup / forgot-password. `app.dart`
    now boots through `AuthGate`.
  - **Paywall module:** `PurchasesService` + `MockPurchasesService`,
    `purchasesProvider` + `isProProvider`, `PaywallPage` (offerings, purchase,
    restore) at `AppRoutes.paywall()`.
  - **Observability:** `Analytics` + `CrashReporter` interfaces with console
    defaults; `main.dart` wraps `runZonedGuarded` + `FlutterError.onError`
    into the reporter; auth identifies/resets the user.
  - **Identity tooling:** `tool/rename_app.sh "Name" com.bundle.id` (Android
    applicationId/namespace/label, iOS bundle id + display name, icon/splash
    via flutter_launcher_icons + flutter_native_splash). Ran it to normalize
    the stale `com.example.parley_android` leftover → `com.shivarajbakale.parley`.
  - Deps added: `flutter_secure_storage` (dep), `flutter_launcher_icons` +
    `flutter_native_splash` (dev). Justified in `DECISIONS.md`.
  - Docs: `docs/MODULES.md` (go-live guide per seam), `DECISIONS.md` entry,
    `docs/ARCHITECTURE.md` (services layer + auth-gate boot flow),
    `BLUEPRINT.md` modules checklist, `AGENTS.md`/`CLAUDE.md` topic links,
    `feature_list.json` `boilerplate-003..006` (all `passing` w/ evidence).
- Verification run: `flutter analyze --no-fatal-infos` ⇒ 0 errors/warnings
  (14 pre-existing const info-lints only); `flutter test` ⇒ 11/11 passing.
- Tests added: `test/auth/auth_flow_test.dart` (7), `test/purchases_test.dart`
  (3), updated `test/widget_test.dart` (auth-gate boot, both states).
- Commits: pending — review the diff before committing.
- Known risk / unresolved:
  - Modules default to mocks; each app must swap real backends in
    `service_config.dart` before launch (that's the design).
  - No go_router yet — auth gate is reactive, not deep-link-aware. Documented
    as the next step in `app.dart` if push/paywall deep links are needed.
  - Real-backend impls (Supabase/Firebase/RevenueCat/Sentry) are documented
    in `docs/MODULES.md` but not written (no accounts/keys in the template).
- Next best step: commit; optionally add go_router + a worked Supabase or
  RevenueCat reference impl, or proceed to `feature-001`.

### Session 001 — Boilerplate carve-out

- Date: 2026-05-16
- Goal: Turn the todo demo into a minimal, harness-equipped Flutter
  boilerplate.
- Completed:
  - Removed todo-specific screens, widgets, models, providers, services,
    mock data, and chart design-system components.
  - Decoupled `ds_badge` and `ds_search` from todo-specific providers
    (`ds_search` now uses an internal `_ds_recent_searches.dart` notifier
    backed by SharedPreferences).
  - Rewrote `lib/screens/home_screen.dart` as a three-tab shell with a
    sidebar, demonstrating the design system without prescribing a domain.
  - Slimmed `AppSettings` / `SettingsNotifier` to `themeMode`,
    `hapticFeedback`, `confirmBeforeDelete`.
  - Replaced the todo mock backend with `/api/ping` and `/api/example`
    template routes.
  - Pruned unused dependencies from `pubspec.yaml`
    (`fl_chart`, `appflowy_editor`, `flutter_markdown_plus`,
    `image_picker`, `path`, `path_provider`, `settings_ui`).
  - Authored the harness: `AGENTS.md`, `CLAUDE.md`, `feature_list.json`,
    `claude-progress.md`, `session-handoff.md`, `clean-state-checklist.md`,
    `evaluator-rubric.md`, `quality-document.md`, `DECISIONS.md`,
    `init.sh`, `Makefile`, `docs/ARCHITECTURE.md`, `docs/CONSTRAINTS.md`.
- Verification run: `./init.sh` ⇒ pub get OK, analyze OK
  (14 pre-existing info lints, non-fatal via `--no-fatal-infos`),
  test 1/1 passing.
- Evidence captured: see `feature_list.json` evidence on `boilerplate-001`
  and `boilerplate-002`.
- Commits: pending — the carve-out has not yet been committed.
- Files or artifacts updated: see git status.
- Known risk or unresolved issue: 14 pre-existing info-level
  `prefer_const_constructors` lints inside the design system. Suppressed
  from the verification gate via `--no-fatal-infos`; tracked in
  `quality-document.md` as a future cleanup. Not a release blocker.
- Next best step: Commit the boilerplate carve-out, then pick the first
  real feature in `feature_list.json` (currently `feature-001`).
