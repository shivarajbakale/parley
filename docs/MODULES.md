# Modules — the ship-fast layer

These are the recurring vertical slices every app needs. Each is an
**interface with a mock/console default**, wired through a Riverpod provider,
with one swap point in
[`lib/services/service_config.dart`](../lib/services/service_config.dart).

The clean clone runs entirely on the mocks — no accounts, keys, or backend.
Going live means changing one `ServiceConfig` method per module. Screens and
providers depend on the interfaces, so nothing else changes.

| Module        | Interface                  | Default (offline)      | Go-live swap            |
| ------------- | -------------------------- | ---------------------- | ----------------------- |
| Auth          | `AuthService`              | `MockAuthService`      | Supabase / Firebase / HTTP |
| Token storage | `TokenStore`               | `SecureTokenStore`     | (already production)    |
| Purchases     | `PurchasesService`         | `MockPurchasesService` | RevenueCat              |
| Analytics     | `Analytics`                | `ConsoleAnalytics`     | PostHog / Amplitude     |
| Crash         | `CrashReporter`            | `ConsoleCrashReporter` | Sentry / Crashlytics    |

Also plug-and-play (no swap needed): **environment/flavors**
([`config/env.dart`](../lib/config/env.dart)), **onboarding**
([`onboarding_page.dart`](../lib/screens/onboarding_page.dart)), and **CI**
(`.github/workflows/ci.yml`).

---

## Environment / flavors

[`Env`](../lib/config/env.dart) reads compile-time `--dart-define`s, so
dev/staging/prod differ with no code edits and no runtime config file to leak.
Defaults are safe (dev + mock backend + localhost), so the app runs with no
flags. `ApiConfig` delegates to `Env`.

```
make dev            # ENV=dev (mock backend)
make run-staging    # ENV=staging
make run-prod       # ENV=prod
flutter run --dart-define=ENV=prod --dart-define=API_BASE_URL=https://api.acme.com
flutter run --dart-define-from-file=env/prod.json
```

Add new keys to `Env` via `String.fromEnvironment`. **Secrets** belong in
`--dart-define` from CI secrets, never in source.

## Onboarding

First-run carousel ([`OnboardingPage`](../lib/screens/onboarding_page.dart)),
gated by `settings.onboardingComplete` (persisted). The router shows
`/onboarding` before auth on first launch and never again after the user
finishes or skips. Edit the slides in `onboarding_page.dart`; to disable
onboarding entirely, drop the `/onboarding` route + redirect branch.

## CI

`.github/workflows/ci.yml` runs `flutter pub get` → `analyze` → `test` on every
push to `main` and every PR — the same gate as `./init.sh`, no secrets.

## Release

Fastlane lanes ship for both stores (`android/fastlane`, `ios/fastlane`) plus a
manual `.github/workflows/release.yml` (workflow_dispatch → android/ios). They
are **skeletons**: they won't upload until you add credentials. Checklist:

- **Android:** a Play Store service-account JSON (`PLAY_STORE_JSON_KEY`), and an
  upload keystore wired into `android/app/build.gradle` `signingConfigs`. Then
  `cd android && bundle exec fastlane beta` (internal track) or `release`.
- **iOS:** code signing (recommend `match`) + an App Store Connect API key, and
  an `ios/ExportOptions.plist`. Then `cd ios && bundle exec fastlane beta`
  (TestFlight).

Secrets go in GitHub Actions secrets / your local env — never in git (the
`.gitignore` already blocks keystores, `.p8`, and the Play JSON). For OTA Dart
patches without a store round-trip, add Shorebird separately.

---

## Auth + gated routing

- **Flow:** the go_router `redirect` in
  [`app_router.dart`](../lib/utils/app_router.dart) is the gate: `/splash`
  while restoring → `/login` (+ `/signup`, `/forgot`, `/reset`) when signed
  out → `/` when signed in. The instant `authProvider` flips, `refreshListenable`
  re-runs the redirect — no manual navigation. Sign out from Settings →
  "Sign out".
- **State:** [`authProvider`](../lib/providers/auth_provider.dart) (`AuthNotifier`)
  owns sign-in/up/out, reset, and cold-start restore. Read the user with
  `ref.watch(currentUserProvider)`.
- **Tokens:** persisted via `TokenStore`. `SecureTokenStore` uses the OS
  keychain/keystore. Tests override `tokenStoreProvider` with
  `InMemoryTokenStore`.
- **Mock account:** `demo@rocketship.dev` / `password`, or register any account.

**Go live — Supabase ships ready.** Pass your project keys and it activates
automatically (no code change); the mock is used until then:

```
flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co \
            --dart-define=SUPABASE_ANON_KEY=ey...
```

`ServiceConfig.createAuthService` returns `SupabaseAuthService`
([supabase_auth_service.dart](../lib/services/auth/supabase_auth_service.dart))
when `Env.hasSupabase`; `main.dart` calls `Supabase.initialize` first. For a
**different backend** (Firebase, your own API), implement `AuthService`, throw
the typed `AuthException` subtypes, and branch in `ServiceConfig`. Delete
`mock_auth_service.dart` + the `_DemoHint` widget in `login_page.dart` once
live.

## Purchases + paywall

- **Paywall:** [`PaywallPage`](../lib/screens/paywall_page.dart), pushed with
  `AppRoutes.paywall()`. Lists offerings, handles purchase + restore, pops on
  success.
- **Gating:** `if (ref.watch(isProProvider)) { … }`. To gate an action, check
  it and push the paywall otherwise.
- **State:** [`purchasesProvider`](../lib/providers/purchases_provider.dart)
  hydrates entitlements on launch.

**Go live — RevenueCat ships ready.** Pass your public SDK key and it
activates ([revenuecat_purchases_service.dart](../lib/services/purchases/revenuecat_purchases_service.dart)):

```
flutter run --dart-define=REVENUECAT_API_KEY=appl_xxx   # or goog_xxx
```

Then in App Store Connect / Play Console + RevenueCat: create the products and
an **entitlement named `pro`** (== `kProEntitlement`, so `isProProvider` lights
up). `main.dart` calls `Purchases.configure` when `Env.hasRevenueCat`; the
service maps offerings/entitlements onto the seam, so the paywall UI is
unchanged.

## Analytics + crash reporting

- `ConsoleAnalytics` / `ConsoleCrashReporter` print via `debugPrint` (no-ops in
  release), so the seams are exercised from day one.
- `main.dart` already routes `FlutterError.onError` and uncaught zone errors to
  the crash reporter, and `authProvider` calls `identify`/`setUser` on sign-in
  and `reset` on sign-out. Wire a real backend and that wiring captures
  everything automatically.

**Go live** — implement the interface and return it from
`ServiceConfig.createAnalytics` / `createCrashReporter` (PostHog/Amplitude for
analytics, `sentry_flutter`/`firebase_crashlytics` for crash). Initialize the
SDK in `main.dart` before `runApp`.

## Models + offline storage (codegen)

Code generation is wired (`build_runner`), and **generated files are committed**
so a clean clone needs no codegen step. Run `make gen` (or `make watch`) after
editing a model or table.

- **Models — freezed + json_serializable.** Example:
  [`models/library_item.dart`](../lib/models/library_item.dart) — immutable,
  `copyWith`, value equality, JSON in/out. It is also the app's one demo
  domain: served by the mock backend at `/api/library`, decoded by
  [`data/library_repository.dart`](../lib/data/library_repository.dart), and
  rendered by the Library tab. Use it for API DTOs; trivial models (like
  `AppSettings`) can stay hand-written.
- **Offline DB — Drift.** Example:
  [`data/local/app_database.dart`](../lib/data/local/app_database.dart) — a
  typed, reactive SQLite DB (a `Notes` table with insert/watch/delete), exposed
  via `appDatabaseProvider`. Tests use `AppDatabase(NativeDatabase.memory())`.

Add a table/model, run `make gen`, commit the regenerated `*.g.dart` /
`*.freezed.dart`.

## Deep links

Routing is go_router ([`app_router.dart`](../lib/utils/app_router.dart)), so
URLs map straight to screens and respect the auth gate:

- `/paywall` — open the paywall from a push notification or marketing link.
- `/reset?token=…` — password-reset landing (token-carrying deep link).
- Any path not in `_publicRoutes` redirects signed-out users to `/login`, then
  replays the original URL after sign-in (the cold-start splash preserves it).

Add a deep-linkable screen by registering its path in `app_router.dart`; no
extra wiring. To make links open the app from outside, configure the native
side once per app:

- **iOS:** add an Associated Domain (`applinks:yourdomain.com`) in Xcode and
  host `.well-known/apple-app-site-association`. For local testing, a custom URL
  scheme also works.
- **Android:** add an `intent-filter` with `android:autoVerify="true"` to
  `AndroidManifest.xml` for your domain (App Links), or a custom scheme.

Test without native setup: `routerProvider.go('/paywall')`, or on a device
`adb shell am start -a android.intent.action.VIEW -d "yourscheme://paywall"`.

## App identity — `tool/rename_app.sh`

```
tool/rename_app.sh "My App" com.acme.myapp
```

Sets the Android `applicationId`/`namespace` + label, the iOS
`PRODUCT_BUNDLE_IDENTIFIER` + `CFBundleDisplayName`, and regenerates launcher
icons + splash if `assets/icon/icon.png` exists (config in `pubspec.yaml`). It
does **not** rename the Dart package `parley_android` — that's internal and users
never see it. Run once per new app, then `flutter clean && flutter pub get`.

---

## Adding a new seam

1. Define the interface in `lib/services/<seam>/`.
2. Ship a `Mock`/`Console`/in-memory default next to it.
3. Add a factory to `ServiceConfig` and a provider in `lib/providers/`.
4. Depend on the interface everywhere; override the provider in tests.
5. Document the go-live swap in this file.
