import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parley_android/app.dart';
import 'package:parley_android/providers/auth_provider.dart';
import 'package:parley_android/providers/settings_provider.dart';
import 'package:parley_android/screens/design_system/blog_page.dart';
import 'package:parley_android/screens/library_detail_page.dart';
import 'package:parley_android/screens/onboarding_page.dart';
import 'package:parley_android/services/auth/auth_models.dart';
import 'package:parley_android/services/auth/token_store.dart';
import 'package:parley_android/utils/app_router.dart';
import 'package:parley_android/utils/app_routes.dart';

/// Verifies go_router auth gating + deep links.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    required TokenStore store,
  }) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(store),
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

  InMemoryTokenStore authedStore() => InMemoryTokenStore(
    const AuthSession(
      user: AuthUser(id: 'u1', email: 'test@rocketship.dev'),
      accessToken: 't',
    ),
  );

  testWidgets('signed-out user is redirected from a gated route to sign-in', (
    tester,
  ) async {
    final container = await pumpApp(tester, store: InMemoryTokenStore());

    container.read(routerProvider).go(AppRoutes.paywall);
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('reset deep link is reachable while signed out', (tester) async {
    final container = await pumpApp(tester, store: InMemoryTokenStore());

    container.read(routerProvider).go('${AppRoutes.reset}?token=abc123');
    await tester.pumpAndSettle();

    expect(find.text('New password'), findsWidgets);
  });

  testWidgets('authenticated user can open the paywall deep link', (
    tester,
  ) async {
    final container = await pumpApp(tester, store: authedStore());

    container.read(routerProvider).go(AppRoutes.paywall);
    await tester.pumpAndSettle();

    expect(find.text('Go Pro'), findsWidgets);
  });

  testWidgets('a finished tour can be replayed on purpose', (tester) async {
    // Settings' "Replay the tour" row. Without the opt-in the redirect sends
    // `/onboarding` straight to `/home` for anyone who finished it, which is
    // the whole reason the tour was unreachable.
    final container = await pumpApp(tester, store: authedStore());

    container.read(routerProvider).push('${AppRoutes.onboarding}?demo=1');
    await tester.pumpAndSettle();

    expect(find.text(onboardingStops.first.headline), findsWidgets);
  });

  testWidgets('and the opt-in is local — plain /onboarding still bounces', (
    tester,
  ) async {
    // The flags are untouched by a replay, so the ordinary rule has to keep
    // applying to every other arrival at the route.
    final container = await pumpApp(tester, store: authedStore());

    container.read(routerProvider).go(AppRoutes.onboarding);
    await tester.pumpAndSettle();

    expect(find.text(onboardingStops.first.headline), findsNothing);
  });

  testWidgets('the recap deep link opens on the week it defaults to', (
    tester,
  ) async {
    // Deep-link safe in the trivial sense — the route takes no parameters —
    // but the assertion is about the period: the page has two states and the
    // URL names neither, so a cold start has to land on the one the screen
    // says it opens on rather than on whatever the last reader chose.
    final container = await pumpApp(tester, store: authedStore());

    container.read(routerProvider).go(AppRoutes.insight);
    await tester.pumpAndSettle();

    expect(find.text('4h 12m'), findsOneWidget);
  });

  testWidgets('the profile deep link opens on Activity', (tester) async {
    final container = await pumpApp(tester, store: authedStore());

    container.read(routerProvider).go(AppRoutes.profile);
    await tester.pumpAndSettle();

    expect(find.text('Streak'), findsOneWidget);
  });

  testWidgets('library detail deep link resolves the item by index', (
    tester,
  ) async {
    final container = await pumpApp(tester, store: authedStore());

    container.read(routerProvider).go(AppRoutes.libraryDetailAt(1));
    await tester.pumpAndSettle();

    // Index 1 → 'Design System' (see demoLibraryItems).
    expect(find.text('Design System'), findsWidgets);
  });

  testWidgets('out-of-range library detail index falls back to home', (
    tester,
  ) async {
    final container = await pumpApp(tester, store: authedStore());

    container.read(routerProvider).go(AppRoutes.libraryDetailAt(999));
    await tester.pumpAndSettle();

    // No crash; lands on the home shell rather than a broken detail screen.
    expect(find.text('Rocketship'), findsWidgets);
  });

  // flutter-048 — the Demos tab surfaces a Welcome tile that pushes
  // `/welcome?demo=1`. The query parameter is the opt-in: a demo reader
  // wants to see the screen regardless of their history (the welcome is
  // one-shot for first-launch, but the demo tile is a reader asking to
  // look). Without the opt-in, the router would bounce a
  // `welcomeSeen=true` user back to /onboarding, which is the bug this
  // test was written to catch.
  testWidgets('welcome demo preview bypasses the welcomeSeen gate', (
    tester,
  ) async {
    // Authenticated, welcome already seen, onboarding still pending —
    // exactly the state where the redirect would normally send /welcome
    // to /onboarding. The `?demo=1` query parameter is what knocks that
    // out so the Demos tile can show the welcome regardless.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'welcome_seen': true,
      // onboarding_complete is intentionally absent — false.
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(authedStore()),
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

    container.read(routerProvider).go('${AppRoutes.welcome}?demo=1');
    await tester.pumpAndSettle();

    // The demo-preview path lands on WelcomePage, not OnboardingPage.
    // The headline in subtitle is the strongest landing signal.
    expect(find.textContaining('A faster way to track'), findsOneWidget);
    // And the page is not the tour — the tour's headline is different.
    expect(find.text('Welcome aboard'), findsNothing);
  });

  // The welcome tile has to work for the user who has already finished
  // the tour too — that is the state every long-time reader of the
  // demo is in by the time the Demos tab matters, and it is the state
  // the earlier `?demo=1` short-circuit missed (the check was scoped inside
  // the `!onboardingDone` branch). The fix lifts the short-circuit to a
  // top-level `?demo=1` check that fires regardless of flag state; this
  // test is the regression case for that lift.
  testWidgets(
    'welcome demo preview still lands on welcome after onboarding finishes',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'welcome_seen': true,
        'onboarding_complete': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          tokenStoreProvider.overrideWithValue(authedStore()),
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

      container.read(routerProvider).go('${AppRoutes.welcome}?demo=1');
      await tester.pumpAndSettle();

      // Same landing signal as the welcomeSeen-only case: the welcome
      // screen's headline in its subtitle, NOT the tour.
      expect(find.textContaining('A faster way to track'), findsOneWidget);
      expect(find.text('Welcome aboard'), findsNothing);
    },
  );

  // The three list→detail routes use a custom shared-axis transition by
  // default, but on Apple that transition comes without the edge-swipe-to-go-
  // back gesture — Navigator only attaches the gesture to CupertinoPageRoute.
  // The fix is to use CupertinoPage on Apple. Verified end-to-end: build with
  // the platform overridden, navigate, and assert the route type the user
  // gets. See docs/evidence/flutter-back-swipe.md.
  group('edge-swipe back gesture routes', () {
    testWidgets('blog route is CupertinoPage on iOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final container = await pumpApp(tester, store: authedStore());
        container.read(routerProvider).go(AppRoutes.blog);
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(BlogPage));
        // go_router materialises a CupertinoPage through the private
        // _PageBasedCupertinoPageRoute; the public superclass is the
        // contract that determines whether Navigator attaches the edge
        // gesture, and the right check.
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
        final container = await pumpApp(tester, store: authedStore());
        container.read(routerProvider).go(AppRoutes.libraryDetailAt(0));
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(LibraryDetailPage));
        expect(ModalRoute.of(context), isA<PageRoute<dynamic>>());
        expect(
          (ModalRoute.of(context)!).runtimeType.toString(),
          contains('CupertinoPageRoute'),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('blog route keeps CustomTransitionPage on Android', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final container = await pumpApp(tester, store: authedStore());
        container.read(routerProvider).go(AppRoutes.blog);
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(BlogPage));
        // On Android the shared-axis visual stays. CupertinoPage would
        // substitute the platform's slide-from-right, which is wrong on a
        // Material target.
        expect(ModalRoute.of(context), isNot(isA<CupertinoPageRoute>()));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
