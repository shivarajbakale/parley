# Building a feature

Hands-on guide for adding a new screen, wiring it into the app, and getting
it past the verification gate.

Companion reads:

- [BLUEPRINT.md](BLUEPRINT.md) — the upstream "describe the app → at-a-glance
  design → approve → features" flow. Feature work only starts once
  [`../BLUEPRINT.md`](../BLUEPRINT.md) is approved.
- [SUPERPLAN.md](SUPERPLAN.md) — the **per-route spec above the feature
  plan**: every route the app needs, with look-and-feel, best practices,
  and APIs. Built once from the app brief, before any feature work
  starts. A feature is *superplan-grade* when its route is in
  `SUPERPLAN.json` and its notes field references `route:<id>`.
- [EXAMPLE_FEATURE.md](EXAMPLE_FEATURE.md) — every step of this guide run
  end-to-end against the existing `/api/ping` mock. Read this first if you
  prefer learning from a worked example.
- [ARCHITECTURE.md](ARCHITECTURE.md) — directory map + allowed dependencies.
- [CONSTRAINTS.md](CONSTRAINTS.md) — rules around theme, dependencies, mocks.

## The 7-step recipe

1. Edit `feature_list.json` — claim the slot, write the verification command.
2. Create the screen file under `lib/screens/`.
3. Pick a layout template (below) and paste it in.
4. (Optional) Add a provider under `lib/providers/`.
5. (Optional) Add data calls + mock routes under `lib/data/`.
6. Register a route in `lib/utils/app_routes.dart`.
7. Add a widget test under `test/`, run `./init.sh`, record evidence.

Each step has a section below.

---

## 1. Claim the feature slot

Open [`feature_list.json`](../feature_list.json). Update **one** entry to
`status: "in_progress"` (only one entry may hold that status at a time).
Fill in `verification` with the exact command(s) you'll run, *before* you
start coding — see [AGENTS.md → Definition Of Done](../AGENTS.md#definition-of-done).

```json
{
  "id": "feature-001",
  "priority": 3,
  "area": "library",
  "title": "Library tab lists saved articles",
  "user_visible_behavior": "The Library tab shows a list of saved articles fetched from /api/articles.",
  "status": "in_progress",
  "verification": [
    "flutter test test/screens/library_page_test.dart",
    "flutter analyze",
    "dart run tool/ui_lint.dart"
  ],
  "evidence": []
}
```

If the work needs to grow, **edit the entry** and note the change in
[`DECISIONS.md`](../DECISIONS.md). Do not split or rewrite to hide
unfinished work.

---

## 2. Create the screen file

Naming and location:

- Top-level screen → `lib/screens/<feature>_page.dart`
- Sub-screen of an existing feature → `lib/screens/<feature>/<thing>_page.dart`
  (mirror the [`settings/`](../lib/screens/settings/) pattern)
- Class name: `<Feature>Page` (e.g. `LibraryPage`, `ArticleDetailPage`)

Use a `ConsumerWidget` if the screen reads providers, `StatelessWidget`
otherwise. Reach for `ConsumerStatefulWidget` only when you need
controllers (`PageController`, `AnimationController`, `TextEditingController`)
that must survive rebuilds.

---

## 3. Pick a page layout

There are **three canonical layouts**. Pick the one that matches the
screen's job and copy the template verbatim — consistency is the point.

### 3a. Large-title scroll page (default)

Use for any top-level page, settings sub-page, detail page. This is the
editorial "iOS-style" pattern used by every screen in the boilerplate.

Anatomy: `CustomScrollView` → `DSLargeAppBar` (first sliver) → content
slivers → trailing `SizedBox` for FAB / bottom-nav clearance.

```dart
import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_large_app_bar.dart';
import 'package:parley_android/theme/app_spacing.dart';

class ArticleDetailPage extends StatelessWidget {
  const ArticleDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const DSLargeAppBar(
            title: 'Article',
            leading: BackButton(),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageGutter,
                AppSpacing.md,
                AppSpacing.pageGutter,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  // … your content
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

Rules:

- `DSLargeAppBar` **must** be the first sliver, and it carries the *only*
  header. A second label line under the title is chrome — put section labels
  in the content with `DSSectionHeader`.
- Page content uses `AppSpacing.pageGutter` on left/right, **not**
  `AppSpacing.lg` directly. The gutter is the editorial convention.
- Trailing padding is `AppSpacing.xl`. The bottom nav is a Material
  `NavigationBar` that reserves its own space, so pages no longer pad
  around a floating bar.

### 3b. Bottom-nav tab page

Same as 3a, but the screen is mounted inside `home_screen.dart`'s
`PageView`, so it does **not** wrap itself in a `Scaffold` (the shell owns the
`Scaffold`, the `NavigationBar`, and the `NavigationDrawer`) and it receives an
`onOpenDrawer` callback for the menu button. Mirror
[`DashboardPage`](../lib/screens/home/dashboard_page.dart) or
[`SettingsPage`](../lib/screens/settings_page.dart).

```dart
class LibraryPage extends ConsumerWidget {
  final VoidCallback? onOpenDrawer;
  const LibraryPage({super.key, this.onOpenDrawer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      slivers: [
        DSLargeAppBar(
          title: 'Library',
          leading: onOpenDrawer != null
              ? IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: onOpenDrawer,
                  tooltip: 'Open navigation menu',
                )
              : null,
        ),
        // … content slivers
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
      ],
    );
  }
}
```

Mount it in `home_screen.dart`: add one entry to `_destinations` (it drives the
`NavigationBar` and the `NavigationDrawer` together) and one page to the
`PageView`, in the same position.

**Layout rules for a tab page** — the difference between "fine" and
"substandard", and what a reviewer will check:

- **One screenful.** The first view should answer what the screen is for
  without a scroll. If it needs three sections to do that, it needs fewer
  sections.
- **Full width.** Content spans gutter to gutter. Rows are edge to edge with
  inset hairline dividers; cards inside an already-guttered page take
  `margin: EdgeInsets.zero`; a `Row` of buttons wraps each in `Expanded`.
  Never stack a card margin on top of the page gutter.
- **No second header.** `DSLargeAppBar` carries the title. Section labels go
  in the content via `DSSectionHeader`.
- **One line per row.** `DSListTile` ellipsizes by default; a wrapping row
  doubles the height of every screen it appears on.

### 3c. Non-sliver page (only when needed)

Use `DSPageHeader` only when the screen's root cannot be a
`CustomScrollView` — e.g. a `TabBarView`, an `IndexedStack`, a form
that needs `Column` + `Expanded`. Same visual as the expanded
`DSLargeAppBar` but fixed at the top.

```dart
Scaffold(
  body: Column(
    children: [
      const DSPageHeader(title: 'New Note'),
      Expanded(child: /* form, tabs, etc. */),
    ],
  ),
);
```

Default to 3a/3b. Only reach for 3c when you've hit a real layout
constraint.

---

## Layout building blocks

Inside the content area, reach for design-system widgets before
inventing layout. The barrel export lives at
[`lib/design_system/design_system.dart`](../lib/design_system/design_system.dart).

| Need                            | Reach for                                |
| ------------------------------- | ---------------------------------------- |
| Group related rows + an eyebrow | `DSSettingsSection` + `DSSettingsRow.*`  |
| Pull-to-refresh list of items   | `RefreshIndicator` + `DSListTile` rows    |
| Card with elevation             | `DSCard` (variants: elevated/filled/outlined) |
| Section header inside content   | `DSSectionHeader`                        |
| Empty list state                | `DSEmptyState`                           |
| Loading placeholder             | `DSLoadingState`                         |
| Primary action button           | `DSButton(variant: primary)`             |
| Floating action button          | `DSFab`                                  |
| Text input                      | `DSTextField`                            |
| Modal confirmation              | `DSDialog(variant: destructive)`         |
| Toast / snack                   | `DSSnackBar.show(context, …)`            |

**Hard rules** (from [CONSTRAINTS.md](CONSTRAINTS.md)):

- No hard-coded `Color(0xFF…)` outside `lib/theme/`. Use
  `Theme.of(context).colorScheme.<token>`.
- No hard-coded padding numbers. Use `AppSpacing.*`.
- New shared widgets only live in `lib/design_system/` if they'll be
  reused twice. One-off screen layout stays in the screen file.
- **Full-width & aligned:** content controls span the row and stay aligned —
  `crossAxisAlignment: stretch`, `DSButton(isFullWidth: true)`, `Expanded`
  segments, single-line labels (no wrapping). See
  [CONSTRAINTS.md → Layout & alignment](CONSTRAINTS.md#layout--alignment).

---

## 4. Add a provider (optional)

Only if the screen has state that survives navigation or that other
screens need.

File: `lib/providers/<feature>_provider.dart`. Use Riverpod
`StateNotifierProvider` — mirror [`settings_provider.dart`](../lib/providers/settings_provider.dart).

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LibraryState {
  final List<Article> articles;
  final bool loading;
  const LibraryState({required this.articles, required this.loading});

  LibraryState copyWith({List<Article>? articles, bool? loading}) =>
      LibraryState(
        articles: articles ?? this.articles,
        loading: loading ?? this.loading,
      );
}

class LibraryNotifier extends StateNotifier<LibraryState> {
  final ArticleApi _api;
  LibraryNotifier(this._api)
      : super(const LibraryState(articles: [], loading: false));

  Future<void> load() async {
    state = state.copyWith(loading: true);
    final articles = await _api.list();
    state = state.copyWith(articles: articles, loading: false);
  }
}

final libraryProvider =
    StateNotifierProvider<LibraryNotifier, LibraryState>((ref) {
  return LibraryNotifier(ref.watch(articleApiProvider));
});
```

If the provider depends on something injected at boot (like
`SharedPreferences`), override it in `main.dart`'s `ProviderScope`.

---

## 5. Add data calls (optional)

If the feature talks to the network:

1. Add the API class at `lib/data/<feature>_api.dart`. Take a `Dio`
   instance in the constructor; wrap calls in `dioCall(...)` for the
   typed-exception envelope.
2. Expose it as a provider in `lib/providers/database_provider.dart`
   (or its own file if it warrants one).
3. Register mock routes in [`lib/data/mock/mock_routes.dart`](../lib/data/mock/mock_routes.dart),
   with backing state in [`lib/data/mock/mock_store.dart`](../lib/data/mock/mock_store.dart).
   Use `delay: _mockLatency` so loading states are visible while
   developing.

`ApiConfig.useMockBackend` (in [`lib/data/api_config.dart`](../lib/data/api_config.dart))
controls whether requests are intercepted. Default is `true`.

---

## 6. Register the route

Routing uses **go_router**. Two files, one responsibility each:

1. Add the path constant to
   [`lib/utils/app_routes.dart`](../lib/utils/app_routes.dart) (the whole
   navigation surface stays greppable from one file).
2. Wire it to a screen in
   [`lib/utils/app_router.dart`](../lib/utils/app_router.dart) as a `GoRoute`.

```dart
// app_routes.dart
static const article = '/article'; // or '/article/:id' for a param

// app_router.dart — as a child of the '/' route so Back returns to home
GoRoute(
  path: 'article/:id',
  builder: (_, state) => ArticleDetailPage(id: state.pathParameters['id']!),
),
```

Navigate with `context.push(AppRoutes.article)` (or `context.push('/article/abc')`),
and `context.pop()` to go back.

**Auth gating is automatic.** Anything not in `_publicRoutes` requires a
session; the router redirects signed-out users to `/login`. **Deep links work
out of the box** — `/paywall`, `/reset?token=…`, etc. resolve to the right
screen and survive the cold-start splash (the intended URL is replayed once the
session loads). For native deep-link setup (universal links / app links), see
[MODULES.md → deep links](MODULES.md#deep-links).

For pages that live inside the bottom-nav `PageView`, you don't add a
route — you mount the widget directly in `home_screen.dart`.

---

## 7. Verify and record evidence

Add a widget test under `test/`, mirroring
[`test/widget_test.dart`](../test/widget_test.dart):

```dart
testWidgets('Library page shows articles', (tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(home: LibraryPage()),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('Library'), findsOneWidget);
});
```

Then run, in order:

```
flutter analyze                # Level 1
dart run tool/ui_lint.dart     # Level 1 — the design-system contract
flutter test                       # Level 2
# Optional level 3: a feature-specific e2e (driver test, golden, etc.)
```

When everything is green, record evidence in `feature_list.json`:

```json
{
  "status": "passing",
  "evidence": [
    "test/screens/library_page_test.dart — Library page shows articles",
    "Commit SHA: <fill in after commit>"
  ]
}
```

`passing → not_started` is forbidden. If a previously-passing feature
regresses, add a **new** feature entry for the regression rather than
silently flipping the status.

---

## Quick reference

| Concern               | File                                                 |
| --------------------- | ---------------------------------------------------- |
| New screen            | `lib/screens/<feature>_page.dart`                    |
| Route                 | `lib/utils/app_routes.dart`                          |
| Provider              | `lib/providers/<feature>_provider.dart`              |
| API client            | `lib/data/<feature>_api.dart`                        |
| Mock routes           | `lib/data/mock/mock_routes.dart`                     |
| Mock state            | `lib/data/mock/mock_store.dart`                      |
| Tokens (colors etc.)  | `lib/theme/app_colors.dart` / `app_spacing.dart` / … |
| Shared widget         | `lib/design_system/ds_*.dart` + barrel export        |
| Feature tracker       | `feature_list.json`                                  |
| Session log           | `claude-progress.md`                                 |
| Architectural changes | `DECISIONS.md`                                       |
