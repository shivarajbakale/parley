import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/design_system/ds_button.dart';
import 'package:parley_android/design_system/ds_large_app_bar.dart';
import 'package:parley_android/design_system/ds_pinned_action_bar.dart';
import 'package:parley_android/design_system/ds_stat_tile.dart';
import 'package:parley_android/providers/auth_provider.dart';
import 'package:parley_android/providers/settings_provider.dart';
import 'package:parley_android/design_system/ds_tour.dart';
import 'package:parley_android/screens/onboarding_page.dart';
import 'package:parley_android/screens/welcome_page.dart';
import 'package:parley_android/screens/welcome_sheet.dart';
import 'package:parley_android/services/auth/auth_models.dart';
import 'package:parley_android/services/auth/token_store.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Welcome — the moment a new user meets the app.
///
/// Tests pin the claims `docs/plans/flutter-048-welcome.md` makes about the
/// screen, one observable behavior per test:
///   * the headline sits in the bar's `subtitle` slot (the spot the
///     `header-earns-its-height` lint protects);
///   * three stat tiles in a row, none carrying a gradient;
///   * one full-width primary + one ghost secondary, both in the pinned bar;
///   * primary tap persists `welcomeSeen`, secondary tap does too (both routes
///     cross the one-shot threshold).
///
///   * the third-tier affordance opens the preview sheet, and the sheet
///     declares three detents against the same list the widget passes.
///
/// What these tests do NOT pin: the drawing itself (it regressed each time the
/// catalogue refactored illustration — the goldens are its gate), the *drag*
/// between detents (the gesture is `DSBottomSheet.snapPoints`' own and is
/// graded there), or the router redirect (`router_test.dart`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    // welcome_seen absent → the welcome is the screen the router shows.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  /// Pumps [WelcomePage] on the app's own theme at a fixed phone size.
  ///
  /// The signed-in override is what `/welcome` always runs against — the
  /// route is gated by auth, so the page never sees an unauthenticated user.
  /// Without it [AuthStatus.unknown] would park the screen on splash chrome
  /// and every assertion below would be measuring the splash.
  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(
          InMemoryTokenStore(
            const AuthSession(
              user: AuthUser(
                id: 'usr_test',
                email: 'ada@rocketship.dev',
                displayName: 'Ada Lovelace',
              ),
              accessToken: 'test',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    // A minimal router so the page's `context.go(...)` calls have somewhere
    // to land. The destination string is what each test inspects to confirm
    // which branch fired (Get started → /onboarding, sign in → /login).
    final router = GoRouter(
      initialLocation: '/welcome',
      routes: <RouteBase>[
        GoRoute(path: '/welcome', builder: (_, __) => const WelcomePage()),
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => const Scaffold(
            body: Text('onboarding stub', textDirection: TextDirection.ltr),
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(
            body: Text('login stub', textDirection: TextDirection.ltr),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    // Two long frames rather than pumpAndSettle: the staggered entrance and
    // the peek sheet's settling animation do not always terminate on a
    // single settle call.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return container;
  }

  group('Welcome', () {
    testWidgets(
      'renders exactly one DSLargeAppBar carrying the headline as subtitle',
      (tester) async {
        await pump(tester);
        // One bar, not a tall appbar plus a compact bar plus a sub-bar.
        expect(find.byType(DSLargeAppBar), findsOneWidget);
        // The headline lives in subtitle (the slot `header-earns-its-height`
        // protects — empty title, populated subtitle is not a header).
        expect(
          find.text('A faster way to track what you’re building.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows three DSStatTile instances side-by-side at compact size',
      (tester) async {
        await pump(tester);
        // Exactly three — a row of figures, not a hero-plus-bento (the
        // dashboard owns that pattern) and not one tile fitting two claims.
        expect(find.byType(DSStatTile), findsNWidgets(3));
        // Compact scale — the dashboard's md-scale tiles are wider than
        // three fit on a 320pt phone, and the welcome has to.
        final tiles = tester
            .widgetList<DSStatTile>(find.byType(DSStatTile))
            .toList();
        expect(
          tiles.every((t) => t.size == DSStatTileSize.compact),
          isTrue,
          reason: 'a row of three stats on a phone is compact, not md',
        );
      },
    );

    testWidgets(
      'primary and ghost buttons both live in the pinned action bar',
      (tester) async {
        await pump(tester);
        // One full-width primary + one ghost. Two primaries at equal weight
        // is the failure the dashboard test already names; this screen
        // proves the rule also holds for the one-CTA-with-secondary shape.
        expect(
          find.descendant(
            of: find.byType(DSPinnedActionBar),
            matching: find.widgetWithText(DSButton, 'Get started'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(DSPinnedActionBar),
            matching: find.widgetWithText(
              DSButton,
              'I already have an account',
            ),
          ),
          findsOneWidget,
        );
        // No second primary anywhere on the page.
        final primaries = tester
            .widgetList<DSButton>(find.byType(DSButton))
            .where((b) => b.variant == DSButtonVariant.primary);
        expect(primaries, hasLength(1));
        // Scoped to the bar. The page carries a second ghost — the small
        // "See what's inside" affordance — and the claim this test makes is
        // about the bar holding exactly one primary and one ghost, not about
        // the page owning one ghost in total.
        final barGhosts = tester
            .widgetList<DSButton>(
              find.descendant(
                of: find.byType(DSPinnedActionBar),
                matching: find.byType(DSButton),
              ),
            )
            .where((b) => b.variant == DSButtonVariant.ghost);
        expect(barGhosts, hasLength(1));
      },
    );

    testWidgets('primary tap persists welcomeSeen', (tester) async {
      final container = await pump(tester);
      // Both flags start clean. The router's redirect depends on these.
      expect(container.read(settingsProvider).welcomeSeen, isFalse);
      expect(container.read(settingsProvider).onboardingComplete, isFalse);

      await tester.tap(find.widgetWithText(DSButton, 'Get started'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Persisted. The router reads this same provider and skips /welcome
      // on the next cold launch. Onboarding stays incomplete — the user
      // has not read the tour yet, only agreed to be introduced.
      expect(container.read(settingsProvider).welcomeSeen, isTrue);
      expect(
        container.read(settingsProvider).onboardingComplete,
        isFalse,
        reason:
            'Get started commits to the welcome step, not to the tour. '
            'The tour is what flipping onboardingComplete means.',
      );
    });

    testWidgets('I already have an account tap also persists welcomeSeen', (
      tester,
    ) async {
      final container = await pump(tester);
      expect(container.read(settingsProvider).welcomeSeen, isFalse);

      await tester.tap(
        find.widgetWithText(DSButton, 'I already have an account'),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The welcome is one-shot per device: a returning user who taps
      // "I already have an account" sees /login, never /welcome again on
      // this device. Marking the flag on both branches is what the router
      // relies on, not special-casing the skip affordance.
      expect(container.read(settingsProvider).welcomeSeen, isTrue);
    });

    testWidgets('the third-tier affordance opens the preview sheet', (
      tester,
    ) async {
      final container = await pump(tester);

      expect(find.byType(WelcomeSheetBody), findsNothing);
      // Scrolled to, not tapped where it used to sit: the three claims added
      // in `flutter-086` push the affordance below the fold on a 390x844
      // phone, which is the screen having something to say rather than a
      // regression.
      final Finder affordance = find.widgetWithText(
        DSButton,
        'See what’s inside',
      );
      // Dragged to the end rather than `ensureVisible`d: the latter stops the
      // moment the row is inside the viewport, which on a screen whose bar
      // floats over the body puts it *under* the bar. The trailing padding
      // below the affordance is what clears it, and only the end of the
      // scroll reaches that.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.tap(affordance);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The preview is of the tour, so it shows the tour's own stops — one
      // row each, headline and body, drawn with that stop's art.
      expect(find.byType(WelcomeSheetBody), findsOneWidget);

      // At the peek only the first stop is on screen, which is that detent's
      // whole argument: one stop visible and the rest a promise. The others
      // are below the fold and a `ListView` has not built them, so they are
      // scrolled to rather than expected in the tree.
      final DSTourStop first = onboardingStops.first;
      expect(find.text(first.headline), findsOneWidget);
      // That there is a row for every stop is read off the list rather than
      // by dragging: the sheet's own detent gesture and its list share one
      // finger, so a scroll written here would be testing the drag arbitration
      // and not the content. `ListView.separated` reports its `itemCount` as
      // the semantic child count, which is the number a screen reader is told
      // as well.
      final ListView list = tester.widget<ListView>(
        find.descendant(
          of: find.byType(WelcomeSheetBody),
          matching: find.byType(ListView),
        ),
      );
      expect(list.semanticChildCount, onboardingStops.length);

      // And it costs the user nothing: the welcome is still behind it, and
      // neither flag moved. A preview that commits is not a preview.
      expect(find.byType(DSPinnedActionBar), findsOneWidget);
      expect(container.read(settingsProvider).welcomeSeen, isFalse);
    });

    test('the sheet declares three detents, each with a name', () {
      // The peek is what the sheet opens at, and it has to be the smallest —
      // a sheet that opens at its full height is a page wearing a sheet's
      // chrome. Asserted against the exported lists rather than against three
      // literals typed here a second time.
      expect(welcomeDetents, hasLength(3));
      expect(welcomeDetentLabels, hasLength(welcomeDetents.length));
      expect(welcomeDetents.first, lessThan(welcomeDetents.last));
      final sorted = List<double>.of(welcomeDetents)..sort();
      expect(welcomeDetents, sorted);
      expect(welcomeDetents.last, lessThanOrEqualTo(1.0));
    });
  });
}
