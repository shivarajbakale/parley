import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/app.dart';
import 'package:parley_android/providers/parley_providers.dart';
import 'package:parley_android/providers/settings_provider.dart';
import 'package:parley_android/screens/design_system/blog_page.dart';
import 'package:parley_android/screens/library_detail_page.dart';
import 'package:parley_android/screens/parley/api_keys_page.dart';
import 'package:parley_android/screens/parley/history_detail_page.dart';
import 'package:parley_android/services/parley/fake_parley_bridge.dart';
import 'package:parley_android/utils/app_router.dart';
import 'package:parley_android/utils/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The setup gate and the deep links.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    bool setupDone = true,
  }) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': setupDone});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        parleyBridgeProvider.overrideWithValue(FakeParleyBridge.ready()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const RocketshipApp(),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('before setup, every location lands on /setup', (tester) async {
    final container = await pumpApp(tester, setupDone: false);

    container.read(routerProvider).go(AppRoutes.historyEntryAt(12));
    await tester.pumpAndSettle();

    expect(find.text('Set up Parley'), findsOneWidget);
  });

  testWidgets('after setup, a bare /setup bounces home', (tester) async {
    final container = await pumpApp(tester);

    container.read(routerProvider).go(AppRoutes.setup);
    await tester.pumpAndSettle();

    expect(find.text('Set up Parley'), findsNothing);
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('"Run setup again" is let through and starts at step one', (
    tester,
  ) async {
    final container = await pumpApp(tester);

    container.read(routerProvider).go('${AppRoutes.setup}?again=1');
    await tester.pumpAndSettle();

    expect(find.text('Talk, and it types — in any app'), findsOneWidget);
  });

  testWidgets('a transcript deep link resolves by id', (tester) async {
    final container = await pumpApp(tester);

    container.read(routerProvider).go(AppRoutes.historyEntryAt(12));
    await tester.pumpAndSettle();

    expect(find.byType(HistoryDetailPage), findsOneWidget);
    expect(
      find.text('“Running ten minutes late, start without me.”'),
      findsOneWidget,
    );
  });

  testWidgets('an unknown transcript id says so instead of a blank page', (
    tester,
  ) async {
    final container = await pumpApp(tester);

    container.read(routerProvider).go(AppRoutes.historyEntryAt(999));
    await tester.pumpAndSettle();

    expect(find.text('This transcript no longer exists'), findsOneWidget);
  });

  testWidgets('the API keys route opens the form', (tester) async {
    final container = await pumpApp(tester);

    container.read(routerProvider).go(AppRoutes.apiKeys);
    await tester.pumpAndSettle();

    expect(find.byType(ApiKeysPage), findsOneWidget);
    expect(find.text('Check and save'), findsOneWidget);
  });

  testWidgets('library detail deep link resolves the item by index', (
    tester,
  ) async {
    final container = await pumpApp(tester);

    container.read(routerProvider).go(AppRoutes.libraryDetailAt(1));
    await tester.pumpAndSettle();

    // Index 1 → 'Design System' (see demoLibraryItems).
    expect(find.text('Design System'), findsWidgets);
  });

  testWidgets('the recap deep link opens on the week it defaults to', (
    tester,
  ) async {
    final container = await pumpApp(tester);

    container.read(routerProvider).go(AppRoutes.insight);
    await tester.pumpAndSettle();

    expect(find.text('4h 12m'), findsOneWidget);
  });

  group('edge-swipe back gesture routes', () {
    testWidgets('blog route is CupertinoPage on iOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final container = await pumpApp(tester);
        container.read(routerProvider).go(AppRoutes.blog);
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(BlogPage));
        expect(ModalRoute.of(context), isA<PageRoute<dynamic>>());
        expect(
          (ModalRoute.of(context)!).runtimeType.toString(),
          contains('CupertinoPageRoute'),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('library detail route is CupertinoPage on iOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final container = await pumpApp(tester);
        container.read(routerProvider).go(AppRoutes.libraryDetailAt(0));
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(LibraryDetailPage));
        expect(
          (ModalRoute.of(context)!).runtimeType.toString(),
          contains('CupertinoPageRoute'),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('transcript route keeps CustomTransitionPage on Android', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final container = await pumpApp(tester);
        container.read(routerProvider).go(AppRoutes.historyEntryAt(12));
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(HistoryDetailPage));
        expect(ModalRoute.of(context), isNot(isA<CupertinoPageRoute>()));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
