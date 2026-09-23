# Worked example: building the "Ping Log" feature

This walks through every step of [FEATURES.md](FEATURES.md) using the
existing `/api/ping` mock route, end-to-end. Copy it, swap in your own
endpoint + screen, and you have a real feature.

The example builds a **Ping Log** screen for the Library tab:
press "Ping", the app calls `/api/ping`, the server's timestamp is
prepended to a scrolling list, pull-to-refresh fires another ping.

Layers exercised:

- Page layout: **3b — bottom-nav tab** (`DSLargeAppBar` inside a
  `CustomScrollView`).
- Provider: `StateNotifierProvider` holding the ping history.
- Data: a small `PingApi` class wrapping `dioCall`.
- Mock backend: uses the `/api/ping` route already in
  [mock_routes.dart](../lib/data/mock/mock_routes.dart).
- Test: a widget test that pumps the screen with a mocked provider and
  asserts the empty state renders.

---

## Step 1 — Claim the slot

Edit [`feature_list.json`](../feature_list.json) — flip `feature-001`
to `in_progress` and write the verification command **before** coding.

```json
{
  "id": "feature-001",
  "priority": 3,
  "area": "library",
  "title": "Library tab is a Ping Log",
  "user_visible_behavior": "The Library tab shows a list of timestamps. Tapping 'Ping' or pulling to refresh appends a new entry from /api/ping.",
  "status": "in_progress",
  "verification": [
    "flutter analyze",
    "dart run tool/ui_lint.dart",
    "flutter test test/screens/library_page_test.dart"
  ],
  "evidence": []
}
```

## Step 2 — The model

A two-field record is enough. Put it next to the screen since nothing
else needs it.

```dart
// lib/models/ping_entry.dart
class PingEntry {
  final DateTime serverTime;
  final DateTime receivedAt;
  const PingEntry({required this.serverTime, required this.receivedAt});
}
```

## Step 3 — The API client

Wrap the network call in `dioCall` so errors come back as typed
`ApiException`s.

```dart
// lib/data/ping_api.dart
import 'package:dio/dio.dart';
import 'package:parley_android/data/dio_client.dart';
import 'package:parley_android/models/ping_entry.dart';

class PingApi {
  final Dio _dio;
  PingApi(this._dio);

  Future<PingEntry> ping() => dioCall(() async {
        final response = await _dio.get<Map<String, dynamic>>('/api/ping');
        final data = response.data!;
        return PingEntry(
          serverTime: DateTime.parse(data['time'] as String),
          receivedAt: DateTime.now(),
        );
      });
}
```

No mock-route change needed — `/api/ping` already lives in
[mock_routes.dart](../lib/data/mock/mock_routes.dart) and returns
`{ok, time}`. If you were adding a *new* endpoint, you'd register it
there with `delay: _mockLatency`.

## Step 4 — The provider

```dart
// lib/providers/pings_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parley_android/data/api_exceptions.dart';
import 'package:parley_android/data/ping_api.dart';
import 'package:parley_android/models/ping_entry.dart';
import 'package:parley_android/providers/database_provider.dart';

class PingsState {
  final List<PingEntry> entries;
  final bool loading;
  final String? error;

  const PingsState({
    this.entries = const [],
    this.loading = false,
    this.error,
  });

  PingsState copyWith({
    List<PingEntry>? entries,
    bool? loading,
    String? error,
  }) =>
      PingsState(
        entries: entries ?? this.entries,
        loading: loading ?? this.loading,
        error: error,
      );
}

class PingsNotifier extends StateNotifier<PingsState> {
  final PingApi _api;
  PingsNotifier(this._api) : super(const PingsState());

  Future<void> ping() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final entry = await _api.ping();
      state = state.copyWith(
        entries: [entry, ...state.entries],
        loading: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    }
  }
}

final pingApiProvider = Provider<PingApi>((ref) {
  return PingApi(ref.watch(dioProvider));
});

final pingsProvider =
    StateNotifierProvider<PingsNotifier, PingsState>((ref) {
  return PingsNotifier(ref.watch(pingApiProvider));
});
```

`dioProvider` already exists in
[database_provider.dart](../lib/providers/database_provider.dart) — no
need to re-wire Dio.

## Step 5 — The screen

This is layout template **3b** from [FEATURES.md](FEATURES.md#3b-bottom-nav-tab-page) —
a bottom-nav tab page: no `Scaffold`, takes an `onOpenDrawer`
callback, mounts directly into the `PageView` in `home_screen.dart`.

```dart
// lib/screens/library_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parley_android/design_system/ds_button.dart';
import 'package:parley_android/design_system/ds_card.dart';
import 'package:parley_android/design_system/ds_empty_state.dart';
import 'package:parley_android/design_system/ds_large_app_bar.dart';
import 'package:parley_android/providers/pings_provider.dart';
import 'package:parley_android/theme/app_spacing.dart';

class LibraryPage extends ConsumerWidget {
  final VoidCallback? onOpenDrawer;
  const LibraryPage({super.key, this.onOpenDrawer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pings = ref.watch(pingsProvider);
    final notifier = ref.read(pingsProvider.notifier);

    return RefreshIndicator(
      onRefresh: notifier.ping,
      color: theme.colorScheme.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          DSLargeAppBar(
            title: 'Ping Log',
            leading: onOpenDrawer != null
                ? IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: onOpenDrawer,
                  )
                : null,
            actions: [
              IconButton(
                tooltip: 'Ping',
                icon: const Icon(Icons.network_ping),
                onPressed: pings.loading ? null : notifier.ping,
              ),
            ],
          ),
          if (pings.entries.isEmpty && !pings.loading)
            SliverFillRemaining(
              hasScrollBody: false,
              child: DSEmptyState(
                icon: Icons.network_ping,
                title: 'No pings yet',
                description: 'Tap the ping icon to call /api/ping.',
                action: DSButton(
                  variant: DSButtonVariant.primary,
                  label: 'Ping',
                  onPressed: notifier.ping,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageGutter,
                AppSpacing.md,
                AppSpacing.pageGutter,
                AppSpacing.xxxl + 24,
              ),
              sliver: SliverList.separated(
                itemCount: pings.entries.length,
                separatorBuilder: (_, __) => AppSpacing.verticalSm,
                itemBuilder: (context, index) {
                  final entry = pings.entries[index];
                  return DSCard(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Server time',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          AppSpacing.verticalXs,
                          Text(
                            entry.serverTime.toIso8601String(),
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
```

Things worth noticing — these are the conventions from
[FEATURES.md](FEATURES.md#layout-building-blocks):

- `DSLargeAppBar` is the first sliver.
- Horizontal padding is `AppSpacing.pageGutter` (the editorial gutter),
  not `AppSpacing.lg`.
- Trailing padding is `AppSpacing.xxxl + 24` because the page lives
  under the bottom nav.
- No hard-coded colors — everything goes through
  `Theme.of(context).colorScheme.*`.
- Empty state uses `DSEmptyState` rather than a hand-rolled
  `Column(Icon, Text, …)`.

## Step 6 — Mount the screen

Bottom-nav tabs don't go through `AppRoutes`; they're mounted inline
in [home_screen.dart](../lib/screens/home_screen.dart). Find the
`PageView` and swap the placeholder for the real screen:

```dart
// lib/screens/home_screen.dart  (inside the PageView children)
children: [
  DashboardPage(onOpenDrawer: _openDrawer),
- const LibraryPage(),
+ LibraryPage(onOpenDrawer: _openDrawer),
  SettingsPage(onOpenDrawer: _openDrawer),
],
```

The destination's label and icons come from the single `_destinations` list at
the top of the same file — it feeds the `NavigationBar` and the
`NavigationDrawer`, so the two can never disagree.

For a **pushed sub-screen** (e.g. tapping a row to drill in), you'd
instead add a builder to [app_routes.dart](../lib/utils/app_routes.dart):

```dart
abstract final class AppRoutes {
  // … existing entries

  static Route pingDetail(PingEntry entry) =>
      MaterialPageRoute(builder: (_) => PingDetailPage(entry: entry));
}

// And from the screen:
Navigator.of(context).push(AppRoutes.pingDetail(entry));
```

## Step 7 — The test

Mirror [test/widget_test.dart](../test/widget_test.dart). Override the
provider with a stub so the test never touches Dio.

```dart
// test/screens/library_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/data/ping_api.dart';
import 'package:parley_android/models/ping_entry.dart';
import 'package:parley_android/providers/pings_provider.dart';
import 'package:parley_android/screens/library_page.dart';

class _StubPingApi implements PingApi {
  @override
  Future<PingEntry> ping() async => PingEntry(
        serverTime: DateTime.utc(2026, 1, 1),
        receivedAt: DateTime.utc(2026, 1, 1),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Library page shows the empty state on first load',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pingApiProvider.overrideWithValue(_StubPingApi()),
        ],
        child: const MaterialApp(home: Scaffold(body: LibraryPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ping Log'), findsOneWidget);
    expect(find.text('No pings yet'), findsOneWidget);
  });
}
```

## Step 8 — Verify and record evidence

Run the verification declared in step 1:

```bash
flutter analyze
dart run tool/ui_lint.dart
flutter test test/screens/library_page_test.dart
```

Both green? Commit, then update `feature_list.json`:

```json
{
  "id": "feature-001",
  "status": "passing",
  "evidence": [
    "test/screens/library_page_test.dart — Library page shows the empty state on first load",
    "Commit SHA: <fill in after commit>"
  ]
}
```

…and add a session entry to [`claude-progress.md`](../claude-progress.md).
You're done.

---

## What this example deliberately leaves out

A real production feature would also need:

- **Loading state** while `pings.loading` is true — currently the screen
  just shows the empty state. Reach for `DSSkeleton` / `DSSkeletonList`,
  which bone-render the real rows (see the Library tab).
- **Error surfacing** when `pings.error` is non-null — `DSSnackBar.show`
  or a `DSMessage` are the standard moves.
- **Persistence** if the log should survive app restarts — wire
  `SharedPreferences` through `sharedPreferencesProvider` (already
  overridden in `main.dart`).
- **An e2e test** that drives the actual button tap, asserts the list
  grows, and verifies `dioProvider` was called once.

Each of those is a follow-on `feature_list.json` entry with its own
verification — *not* a quiet extension of this one. That's what the
single-active-feature rule is protecting.
