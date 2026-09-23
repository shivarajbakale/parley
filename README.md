# Parley

Generated with [create-flutter-app](https://www.npmjs.com/package/create-flutter-app).

## Run

```bash
flutter pub get
flutter run
```

## What's inside

- **State:** Riverpod (`flutter_riverpod`)
- **Networking:** Dio + `http_mock_adapter` (no backend required to start)
- **Persistence:** `shared_preferences`
- **Design system:** custom components in `lib/design_system/`
- **Theme:** Material 3, "Quiet Editorial" palette in `lib/theme/`
- **Typography:** Satoshi (bundled in `assets/fonts/`)

## Project structure

```
lib/
  main.dart              # entrypoint
  app.dart               # root MaterialApp
  data/                  # dio client + mock routes
  design_system/         # reusable widgets (ds_*.dart)
  models/                # domain models
  providers/             # Riverpod providers
  screens/               # routed screens
  theme/                 # color + text theme
  utils/                 # helpers
```

## Customising

The app title and root widget class are still named after the original
boilerplate (`RocketshipApp`, title `Rocketship`). Search-and-replace those
when you're ready to brand.

## Building with an AI agent

This project ships an opinionated agent harness for long-running
implementation work. The full protocol — including the "describe the app →
at-a-glance blueprint → approve → features" flow — is documented in:

- [`AGENTS.md`](AGENTS.md) / [`CLAUDE.md`](CLAUDE.md) — the operating loop
  and rules
- [`BLUEPRINT.md`](BLUEPRINT.md) — fill this in (or have the agent fill it)
  with the app's at-a-glance design before any feature work starts
- [`feature_list.json`](feature_list.json) — single source of truth for
  feature state; one in-progress at a time
- [`docs/FEATURES.md`](docs/FEATURES.md) — step-by-step recipe for adding
  a new screen
- [`docs/EXAMPLE_FEATURE.md`](docs/EXAMPLE_FEATURE.md) — the recipe run
  end-to-end as a worked example
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) /
  [`docs/CONSTRAINTS.md`](docs/CONSTRAINTS.md) — directory map and the
  rules to follow

Start a session with `./init.sh` (or `make check`); agents should read
`BLUEPRINT.md` and `feature_list.json` first.

## Identifiers

- Dart package: `parley_android`
- Run `flutter doctor` if you hit platform setup issues.
