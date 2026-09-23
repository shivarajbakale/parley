# App Blueprint

> **For the agent:** if this file is still in stub form (no `One-liner`
> filled in, no `Approved` checkbox ticked), produce a real blueprint
> from the user's brief BEFORE touching `feature_list.json`. Protocol:
> [docs/BLUEPRINT.md](docs/BLUEPRINT.md). Do not start implementation
> until the user ticks **Approved**.
>
> **For the user:** describe the app you want (one paragraph is fine).
> The agent fills in the sections below, you review, you tick
> **Approved**, then features get queued. Change anything you like
> first — this is a 5-minute alignment doc, not a contract.

---

**One-liner:** _(filled by the agent from your brief)_

**Status:**
- [ ] drafted
- [ ] approved

**Last updated:** _(YYYY-MM-DD)_

## Screens

| # | Screen | Mount | Layout | Purpose |
|---|--------|-------|--------|---------|
| 1 | _name_ | tab-N / pushed / modal | 3a / 3b / 3c | one-sentence purpose |

> `Mount`: `tab-0..N` for bottom-nav tabs, `pushed` for Navigator.push,
> `modal` for bottom sheet / dialog. `Layout` matches the templates in
> [docs/FEATURES.md](docs/FEATURES.md#3-pick-a-page-layout).

## Navigation map

```
HomeShell (PageView)
├── _tab 0_
├── _tab 1_  ─push→ _detail_
└── _tab 2_  (Settings — boilerplate)
```

## Modules

Pre-built slices that ship in the boilerplate behind a mock/console default.
Tick the ones this app needs; pick the go-live backend (or leave the mock for
v1). Details: [docs/MODULES.md](docs/MODULES.md).

| Module     | Enable? | Go-live backend (or "mock for now") |
|------------|---------|-------------------------------------|
| Onboarding | [ ]     | _on / off (first-run carousel)_     |
| Auth       | [ ]     | _Supabase / Firebase / HTTP / mock_ |
| Paywall    | [ ]     | _RevenueCat / mock_                 |
| Analytics  | [ ]     | _PostHog / Amplitude / console_     |
| Crash      | [ ]     | _Sentry / Crashlytics / console_    |

> - App identity (name + bundle id + icons): `tool/rename_app.sh "App Name" com.you.app`.
> - Environment: dev/staging/prod via `--dart-define=ENV=…` ([lib/config/env.dart](lib/config/env.dart)).
> - CI (analyze + test) ships in `.github/workflows/ci.yml`.

## Data model

- **EntityName:** field, field, field
- …

## Providers

- `someProvider` — what it owns, why it survives navigation

## Backend (mock routes)

- `GET /api/…` → shape
- `POST /api/…` → shape

> Real routes get registered in
> [lib/data/mock/mock_routes.dart](lib/data/mock/mock_routes.dart) once
> approved.

## Open questions

1. _question for the user to answer before approval_

---

## Feature decomposition (filled after approval)

Once **Approved** is ticked, the agent splits this blueprint into
entries in [feature_list.json](feature_list.json), one feature per
screen or per substantial behaviour. Reference the screen `#` from the
table above in each feature's `notes`.
