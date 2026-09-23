import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/data/api_exceptions.dart';
import 'package:parley_android/data/dashboard_repository.dart';
import 'package:parley_android/data/library_repository.dart';
import 'package:parley_android/design_system/ds_status_state.dart';
import 'package:parley_android/design_system/ds_skeleton.dart';
import 'package:parley_android/models/dashboard_summary.dart';
import 'package:parley_android/models/library_item.dart';
import 'package:parley_android/providers/auth_provider.dart';
import 'package:parley_android/providers/settings_provider.dart';
import 'package:parley_android/screens/home/dashboard_page.dart';
import 'package:parley_android/screens/home/library_page.dart';
import 'package:parley_android/services/auth/auth_models.dart';
import 'package:parley_android/services/auth/token_store.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/utils/error_copy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A screen that fetches has three outcomes, and all three are on screen.
///
/// Every screen here watches something that can be late and can fail. The two
/// claims this file makes are the ones a golden cannot: that the loading frame
/// and the error frame are *different screens* rather than the same empty
/// column, and that neither of them shows the reader an exception.
///
/// The second is the one that erodes quietly. `'$error'` in a message is one
/// character longer to type than the alternative and it compiles, so it
/// arrives on the screen after next unless something fails the build. On a
/// dropped connection it reads as `ClientException with SocketException:
/// Failed host lookup: 'api.example.com'` — which names the package that
/// failed, and nothing the person holding the phone can do about it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_complete': true,
    });
    prefs = await SharedPreferences.getInstance();
  });

  const items = <LibraryItem>[
    LibraryItem(
      id: 'a',
      title: 'Designing for the platform',
      subtitle: 'Six chapters',
      detail: 'What native means on each side.',
      iconName: 'palette',
      category: 'Design',
    ),
  ];

  const summary = DashboardSummary(
    itemCount: 6,
    categoryCount: 3,
    completedCount: 2,
  );

  /// The failure every one of these screens will actually meet first.
  const offline = NetworkException('Failed host lookup: api.example.com');

  List<Override> base() => <Override>[
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
  ];

  /// Pumps [child] with [overrides] on top of the signed-in defaults.
  ///
  /// Two fixed frames rather than `pumpAndSettle`, which never returns on a
  /// screen carrying a shimmer — and the loading case is exactly that screen.
  /// The second frame is not optional: the staggered entrance schedules its
  /// first tick from a zero-duration timer during layout, and a test that
  /// ends before that timer fires fails on a pending timer rather than on
  /// anything it asserted.
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [...base(), ...overrides],
        child: MaterialApp(theme: AppTheme.lightTheme, home: child),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  /// The bones actually being drawn.
  ///
  /// Not `find.byType(DSSkeleton)`: the components that take a `loading` flag
  /// keep their skeleton mounted and toggle `enabled`, so the type is on the
  /// tree in both states and only this distinguishes them.
  Finder activeBones() => find.byWidgetPredicate(
    (widget) => widget is DSSkeleton && widget.enabled,
    description: 'a skeleton that is drawing',
  );

  /// Every string the screen is currently drawing.
  List<String> textOn(WidgetTester tester) => [
    for (final text in tester.widgetList<Text>(find.byType(Text)))
      text.data ?? text.textSpan?.toPlainText() ?? '',
  ];

  /// The screens under test, each with the three provider states it can be in.
  final screens =
      <
        String,
        ({Widget page, Override loading, Override loaded, Override failed})
      >{
        'the dashboard': (
          page: DashboardPage(onOpenDrawer: () {}),
          // A future that never completes is the loading state held still, which
          // is the only way to assert on a frame that is normally in transit.
          loading: dashboardSummaryProvider.overrideWith(
            (ref) => Completer<DashboardSummary>().future,
          ),
          loaded: dashboardSummaryProvider.overrideWith((ref) => summary),
          failed: dashboardSummaryProvider.overrideWith(
            (ref) => Future<DashboardSummary>.error(offline),
          ),
        ),
        'the library': (
          page: const LibraryPage(),
          loading: libraryItemsProvider.overrideWith(
            (ref) => Completer<List<LibraryItem>>().future,
          ),
          loaded: libraryItemsProvider.overrideWith((ref) => items),
          failed: libraryItemsProvider.overrideWith(
            (ref) => Future<List<LibraryItem>>.error(offline),
          ),
        ),
      };

  group('the copy itself', () {
    // The mapping, branch by branch. The widget tests above prove the screens
    // read it; this proves what they read.
    final cases = <String, Object>{
      'offline': const NetworkException('Failed host lookup: api.example.com'),
      'missing': const NotFoundException('No such record: 91ac'),
      'server': const ServerException('NullPointerException at Foo.bar:14'),
      'expired': const ApiException('Unauthorized', statusCode: 401),
      'unknown': StateError('Bad state: nobody wrote copy for this'),
    };

    cases.forEach((name, error) {
      test('$name says something a person can act on', () {
        final copy = errorCopyFor(error);

        expect(copy.message, isNot(contains('Exception')));
        expect(copy.message, isNot(contains(error.toString())));
        // A sentence, not a fragment: the copy has to end somewhere, and
        // "Network error" is a label rather than something to do next.
        expect(copy.message, endsWith('.'));
        expect(copy.actionLabel, isNotEmpty);
      });
    });

    test('a validation message keeps the words the server wrote', () {
      // The one branch that passes the server's text through, because a 400
      // describes the user's input rather than the server's internals, and
      // "Email address is already registered" is the only thing on the screen
      // that would let them fix it.
      const message = 'Email address is already registered.';
      expect(errorCopyFor(const ValidationException(message)).message, message);
    });
  });

  screens.forEach((name, screen) {
    group(name, () {
      testWidgets('draws bones while it loads, not an empty column', (
        tester,
      ) async {
        await pump(
          tester,
          Scaffold(body: screen.page),
          overrides: [screen.loading],
        );

        expect(
          activeBones(),
          findsWidgets,
          reason:
              '$name renders nothing recognisable while its data is in '
              'flight — a blank screen and a broken screen look identical to '
              'the person waiting',
        );
        // A skeleton is not an error. A screen showing both has failed and is
        // still pretending to load.
        expect(find.byType(DSEmptyState), findsNothing);
      });

      testWidgets('puts the bones away once the data arrives', (tester) async {
        await pump(
          tester,
          Scaffold(body: screen.page),
          overrides: [screen.loaded],
        );

        // The failure this catches is a screen that never leaves its loading
        // state because the switch matched `AsyncLoading` before `AsyncValue`
        // — which looks like a slow backend and is a bug in the screen.
        expect(activeBones(), findsNothing);
        expect(find.byType(DSEmptyState), findsNothing);
      });

      testWidgets('says what failed, in a sentence, over a way back', (
        tester,
      ) async {
        await pump(
          tester,
          Scaffold(body: screen.page),
          overrides: [screen.failed],
        );

        // A failure is a DSErrorState, not an empty state. Plan 29 separated
        // them because they are different claims: empty means there is
        // nothing, and failed means we could not find out.
        expect(
          find.byType(DSErrorState),
          findsOneWidget,
          reason: '$name swallows a failed fetch',
        );

        final failure = tester.widget<DSErrorState>(find.byType(DSErrorState));
        expect(
          failure.onRetry,
          isNotNull,
          reason:
              '$name tells the reader it failed and offers them nothing to '
              'do about it',
        );
        expect(failure.title, errorCopyFor(offline).message);
      });

      testWidgets('never shows the reader an exception', (tester) async {
        await pump(
          tester,
          Scaffold(body: screen.page),
          overrides: [screen.failed],
        );

        for (final line in textOn(tester)) {
          expect(
            line,
            isNot(
              anyOf(
                contains('Exception'),
                contains('Error:'),
                contains('#0'),
                contains('host lookup'),
              ),
            ),
            reason:
                '$name is rendering the exception\'s own text: "$line". '
                'Route it through errorCopyFor instead',
          );
        }
      });
    });
  });
}
