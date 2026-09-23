# Architecture

A map of parley_android: where things live, how a request or a command flows
through it, and which invariants the layout encodes.

It points at files rather than reproducing them, because a copy of code is a copy
that goes stale, and it deliberately does not repeat the stack, the entry point
or the commands — those are in [AGENTS.md](AGENTS.md), which is read every
session. This one is read on demand, which is what keeps that one short: anything
an agent needs *in order to find its way around* belongs here rather than there.

<!-- rocketship:own shape -->
## The shape

```
lib/
  main.dart          boots inside runZonedGuarded, wires the crash reporter
  app.dart           MaterialApp.router driven by routerProvider
  config/env.dart    compile-time flavors via --dart-define
  screens/           one file per screen; home_screen.dart is the shell
  design_system/     DS-prefixed widgets, exported from design_system.dart
  providers/         Riverpod: settings, auth, purchases, observability, dio
  services/          the swappable seams — auth, purchases, observability
    service_config.dart   THE swap point: which implementation each one gets
  data/              dio_client, api_config, the mock backend, the Drift database
  models/            pure Dart entities, no Flutter imports
  theme/             the tokens: colors, typography, spacing, radius, shadows, motion
  utils/             app_routes.dart and app_router.dart — go_router and the auth gate
```

## How the app starts

`main()` builds the crash reporter and `SharedPreferences`, then `ProviderScope`
overrides those providers so nothing constructs a second instance.
`MaterialApp.router` takes its routes from `routerProvider`, whose `redirect` is
the auth gate: while the session restores it parks on `/splash` with the target
stashed in `?from=`, then sends signed-out users to `/login` and everyone else
onward. That stash is what lets a deep link to `/paywall` or
`/reset?token=...` survive a cold start.

`HomeScreen` is the shell — a `NavigationBar`, a `PageView` and a
`NavigationDrawer`, all driven by one destinations list. The drawer's
edge-swipe, scrim and dismissal come from `Scaffold`, not from gesture code.

## Invariants the layout encodes

Dependencies run one way: screens depend on providers, the design system and the
theme; providers depend on data, models and services; data depends on models;
models and theme are leaves with no internal dependencies.

- **The design system depends on the theme and nothing above it.** A widget that
  reaches into a provider cannot be reused or previewed in isolation.
- **Screens and providers depend on service *interfaces*, never a concrete SDK.**
  `service_config.dart` is the single place an implementation is chosen, which
  is what makes swapping the mock for a real backend a one-file change.
- **Models are pure Dart.** A Flutter import in a model makes the domain
  untestable without a widget binding.
- **Colours, spacing, radii, shadows and durations are tokens** from `theme/`.
  A literal in a widget is the thing that survives a re-theme and looks wrong.
- **Every route path lives in `utils/app_routes.dart`**, so the navigation
  surface is greppable in one file.
- **The mock backend is internal to `data/`.** Nothing above it knows whether a
  response came from `http_mock_adapter` or the network.

## Where to add a thing

| Adding | Goes | Start from |
| --- | --- | --- |
| a whole feature slice | model, API, provider, screen, route, test | the `add-feature` skill |
| a standalone screen | `lib/screens/`, route in `app_routes.dart` | the `add-screen` skill |
| state that survives navigation | `lib/providers/` | `settings_provider.dart` |
| a network call | an `<x>_api.dart` beside `dio_client.dart`, plus mock routes | `mock_routes.dart` |
| a reusable widget | `lib/design_system/`, exported from the barrel | any `ds_*.dart` |
| auth, payments or observability | do not build it — read [docs/MODULES.md](docs/MODULES.md) | `service_config.dart` |
<!-- /rocketship:own -->
