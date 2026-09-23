import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parley_android/app.dart';
import 'package:parley_android/providers/auth_provider.dart';
import 'package:parley_android/providers/settings_provider.dart';
import 'package:parley_android/screens/onboarding_page.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/services/auth/token_store.dart';

/// First-run welcome + onboarding gating.
///
/// `flutter-048` introduced the welcome screen between the splash and the
/// existing onboarding carousel, so a user who has not seen *either* lands
/// on /welcome first. The flag set this file inspects:
///
///   * `welcomeSeen` — true means the user has *been introduced* to the
///     app. Set by either branch of the welcome page (Get started and
///     "I already have an account" both flip it).
///   * `onboarding_complete` — true means the user has *finished* the
///     tour. The two flags answer different questions.
///
/// The router reads both. The tests below cover the four combinations.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    bool seen = false,
    bool welcomeSeen = false,
  }) async {
    SharedPreferences.setMockInitialValues(
      seen || welcomeSeen
          ? <String, Object>{
              'welcome_seen': welcomeSeen,
              'onboarding_complete': seen,
            }
          : <String, Object>{},
    );
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
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

  testWidgets('first launch shows welcome, not onboarding yet', (tester) async {
    await pump(tester);
    // Welcome precedes onboarding on a cold launch. The screen the reader
    // sees is the welcome, not the tour.
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Welcome aboard'), findsNothing);
    // Auth flow is gated behind both welcome and onboarding.
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('welcome seen but onboarding not: tour shows next', (
    tester,
  ) async {
    await pump(tester, welcomeSeen: true);
    expect(find.text('Welcome aboard'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('completing onboarding routes on to sign-in', (tester) async {
    // Welcome skipped (the saved flag puts the user past it).
    final container = await pump(tester, welcomeSeen: true);
    await container.read(settingsProvider.notifier).completeOnboarding();
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('returning users (both flags set) skip both screens', (
    tester,
  ) async {
    await pump(tester, seen: true, welcomeSeen: true);
    expect(find.text('Welcome aboard'), findsNothing);
    expect(find.text('Get started'), findsNothing);
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('the sequence is three stops and ends in a commitment', (
    tester,
  ) async {
    // Past the welcome — the tour is what runs after.
    await pump(tester, welcomeSeen: true);

    for (int i = 0; i < 2; i++) {
      expect(find.text('Next'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Next'), findsNothing);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('a cold launch walks welcome to tour to home', (tester) async {
    // The four legs of this flow each had a test and nothing joined them, so
    // the walk a new user actually takes — the one the feature is written in
    // terms of — was covered by nothing. This is that walk, on the real
    // router, driven by taps rather than by flags set from the outside.
    final container = await pump(tester);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Welcome aboard'), findsNothing);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    // The welcome hands over to the tour, not to the app.
    expect(find.text('Welcome aboard'), findsOneWidget);
    final settings = container.read(settingsProvider);
    expect(settings.welcomeSeen, isTrue);
    expect(settings.onboardingComplete, isFalse);

    // Walk the tour to its handover and take it.
    for (int i = 0; i < 2; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets);

    // The second cold launch: both flags are on disk now, so a fresh boot of
    // the same app skips both screens. Pumped as a new widget tree from the
    // same preferences, which is what "cold launch" means here.
    final stored = container.read(sharedPreferencesProvider);
    expect(stored.getBool('welcome_seen'), isTrue);
    expect(stored.getBool('onboarding_complete'), isTrue);
    await pump(tester, seen: true, welcomeSeen: true);
    expect(find.text('Welcome aboard'), findsNothing);
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('initialStop opens the tour part-way through', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ProviderScope(child: OnboardingPage(initialStop: 2)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
  });
}
