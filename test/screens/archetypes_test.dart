import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/data/dashboard_repository.dart';
import 'package:parley_android/data/library_repository.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/models/dashboard_summary.dart';
import 'package:parley_android/models/library_item.dart';
import 'package:parley_android/providers/auth_provider.dart';
import 'package:parley_android/providers/settings_provider.dart';
import 'package:parley_android/screens/auth/login_page.dart';
import 'package:parley_android/screens/auth/signup_page.dart';
import 'package:parley_android/screens/design_system/browse_data.dart';
import 'package:parley_android/screens/design_system/browse_page.dart';
import 'package:parley_android/screens/design_system/insight_data.dart';
import 'package:parley_android/screens/design_system/insight_page.dart';
import 'package:parley_android/screens/design_system/order_placed_page.dart';
import 'package:parley_android/screens/design_system/place_data.dart';
import 'package:parley_android/screens/design_system/place_page.dart';
import 'package:parley_android/screens/design_system/profile_data.dart';
import 'package:parley_android/screens/design_system/profile_page.dart';
import 'package:parley_android/screens/home/dashboard_page.dart';
import 'package:parley_android/screens/home/library_page.dart';
import 'package:parley_android/screens/library_detail_page.dart';
import 'package:parley_android/screens/onboarding_page.dart';
import 'package:parley_android/screens/paywall_page.dart';
import 'package:parley_android/screens/settings_page.dart';
import 'package:parley_android/providers/purchases_provider.dart';
import 'package:parley_android/services/auth/auth_models.dart';
import 'package:parley_android/services/purchases/purchase_models.dart';
import 'package:parley_android/services/purchases/purchases_service.dart';
import 'package:parley_android/services/auth/token_store.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The demo screens are built on the eight archetypes, and these are the
/// claims a golden cannot make.
///
/// A baseline proves that a screen still *looks* the way it looked. It cannot
/// say that the bento has two tile sizes rather than six of one, that the
/// search field filters in place, that the swipe has a discoverable twin, or
/// that the primary action does not scroll away — and those are the properties
/// that make a screen an archetype rather than an arrangement that currently
/// resembles one.
///
/// So the goldens catch appearance drift and this file catches structural
/// drift, which is the kind that arrives one reasonable edit at a time.
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
    LibraryItem(
      id: 'b',
      title: 'Wiring a feature slice',
      subtitle: 'Four chapters',
      detail: 'Model, client, state, screen, route, test.',
      iconName: 'rocket',
      category: 'Guides',
    ),
    LibraryItem(
      id: 'c',
      title: 'Subscriptions end to end',
      subtitle: 'Three chapters',
      detail: 'Offerings, purchase, entitlement.',
      iconName: 'lock',
      category: 'Modules',
    ),
  ];

  List<Override> overrides({List<LibraryItem>? library}) => <Override>[
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
    libraryItemsProvider.overrideWith((Ref ref) => library ?? items),
    // Fixed, so the dashboard's summary is the same three figures on every
    // run. Left to the mock backend it arrives 900ms late and the structural
    // assertions below would be racing a delay.
    dashboardSummaryProvider.overrideWith(
      (Ref ref) => const DashboardSummary(
        itemCount: 6,
        categoryCount: 3,
        completedCount: 2,
      ),
    ),
  ];

  /// Pumps [child] on the app's own theme at a fixed phone size, so a width
  /// assertion means the same thing on every host.
  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget child, {
    List<LibraryItem>? library,
    double height = 844,
  }) async {
    tester.view.physicalSize = Size(390 * 3, height * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(overrides: overrides(library: library));
    addTearDown(container.dispose);

    await tester.pumpWidget(
      // On the app's own identity, not the fallback. `Design` is what carries
      // the spec, and a screen mounted without it measures
      // `DesignSpec.fallback` — which agreed with the shipped identity on
      // every number this file asserts until the page gutter moved to 24, at
      // which point these tests were quietly measuring an app nobody ships.
      Design(
        spec: AppTheme.spec,
        child: UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: AppTheme.lightTheme, home: child),
        ),
      ),
    );
    // Two long frames rather than pumpAndSettle: the staggered entrance
    // schedules each item from a post-frame callback, and settling is not
    // guaranteed to terminate on a screen that carries a skeleton.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return container;
  }

  group('Focal — the dashboard', () {
    testWidgets('is one hero over a bento of exactly two tile sizes', (
      tester,
    ) async {
      // Taller than a phone on purpose. `SliverList` builds lazily, so a
      // measurement of "every tile" is really a measurement of every tile
      // above the fold — and this assertion is about the whole bento. The
      // widths it compares are unaffected by the viewport's height.
      await pump(
        tester,
        Scaffold(body: DashboardPage(onOpenDrawer: () {})),
        height: 1600,
      );

      final cards = find.byType(DSCard);
      final gradients = tester
          .widgetList<DSCard>(cards)
          .where((card) => card.style?.fillGradient != null);
      // One hero, and one only. Two gradients on a screen is two heroes,
      // which is none.
      expect(gradients, hasLength(1));

      // The bento is what sits under the section header, not every card on
      // the screen: the hero is above it and so is the summary, and both are
      // full width without being wide *tiles*. Measuring by position rather
      // than by index because an index is a claim about ordering that breaks
      // the next time anything is inserted — which is exactly what happened.
      final bentoTop = tester
          .getRect(find.byType(DSSectionHeader).first)
          .bottom;

      // The tiles below it, by width. The defect this replaces was six of
      // them at identical weight; the archetype asks for a wide one and pairs
      // of narrow ones, which is exactly two widths and no more.
      final widths = <double>[
        for (final card in cards.evaluate())
          if (tester.getRect(find.byWidget(card.widget)).top >= bentoTop)
            tester.getSize(find.byWidget(card.widget)).width,
      ];
      final distinct = widths.map((w) => w.round()).toSet();
      expect(
        distinct,
        hasLength(2),
        reason:
            'the bento has ${distinct.length} tile widths — one wide tile '
            'and pairs of narrow ones is two',
      );
      expect(
        widths.where(
          (w) => w.round() == distinct.reduce((a, b) => a > b ? a : b).round(),
        ),
        hasLength(1),
        reason: 'more than one wide tile means neither is the wide one',
      );
    });

    testWidgets('carries one primary action, not two of equal weight', (
      tester,
    ) async {
      await pump(tester, Scaffold(body: DashboardPage(onOpenDrawer: () {})));

      // The hero's "Get started" is the one primary action on the page —
      // but not the *primary variant*: the hero card now carries the brand
      // gradient itself, and a primary-variant button on it would paint
      // the same gradient as its own background and disappear. It is
      // `DSButtonVariant.secondary` instead, so "one primary action, not
      // two of equal weight" is now asserted on `fullWidth` — the visual
      // signal that still marks the one thing this screen is for — rather
      // than on the variant.
      final heroButtons = tester
          .widgetList<DSButton>(find.byType(DSButton))
          .where((button) => button.fullWidth);
      expect(heroButtons, hasLength(1));
    });
  });

  group('Collection — the library', () {
    Future<void> type(WidgetTester tester, String query) async {
      await tester.enterText(find.byType(TextField).first, query);
      // The search bar debounces; without waiting it out the list is still
      // showing the previous query and the assertion passes for last frame's
      // reason.
      await tester.pump(DesignSpec.halo().motion.normal);
      await tester.pump();
    }

    testWidgets('search filters the list in place', (tester) async {
      await pump(tester, const Scaffold(body: LibraryPage()));
      expect(find.byType(DSListTile), findsNWidgets(3));

      await type(tester, 'platform');
      expect(find.text('Designing for the platform'), findsOneWidget);
      expect(find.byType(DSListTile), findsOneWidget);
    });

    testWidgets('a filter chip narrows it, and the strip shows which is on', (
      tester,
    ) async {
      await pump(tester, const Scaffold(body: LibraryPage()));
      // Derived from the data: All plus the three categories present.
      expect(find.byType(DSChip), findsNWidgets(4));

      await tester.tap(find.widgetWithText(DSChip, 'Guides'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(DSListTile), findsOneWidget);
      expect(find.text('Wiring a feature slice'), findsOneWidget);
      final chip = tester.widget<DSChip>(find.widgetWithText(DSChip, 'Guides'));
      expect(chip.selected, isTrue);
    });

    testWidgets('nothing matched is a different screen from nothing exists', (
      tester,
    ) async {
      await pump(tester, const Scaffold(body: LibraryPage()));
      await type(tester, 'zzzz');

      // The one that can be fixed from here offers the fix.
      expect(find.byType(DSEmptyState), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(DSListTile), findsNWidgets(3));
    });

    testWidgets('an empty collection says so without offering a filter reset', (
      tester,
    ) async {
      await pump(
        tester,
        const Scaffold(body: LibraryPage()),
        library: const <LibraryItem>[],
      );

      expect(find.text('Nothing in the library yet.'), findsOneWidget);
      expect(find.text('Clear filters'), findsNothing);
    });

    testWidgets('swipe removes a row, and the undo puts it back', (
      tester,
    ) async {
      await pump(tester, const Scaffold(body: LibraryPage()));

      await tester.drag(
        find.text('Wiring a feature slice'),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Wiring a feature slice'), findsNothing);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Wiring a feature slice'), findsOneWidget);
    });

    testWidgets('the row leads somewhere, and says so with a chevron', (
      tester,
    ) async {
      // The per-row overflow this replaces held two items, one of which was
      // the row's own tap target. A button in every row, for one action.
      await pump(tester, const Scaffold(body: LibraryPage()));
      expect(find.byType(DSMenu), findsNothing);
      expect(find.byType(DSChevron), findsNWidgets(3));
    });

    testWidgets('the swipe keeps a twin that is not a gesture', (tester) async {
      // A swipe is invisible to a reader using a screen reader or a switch
      // control, so the destructive action also has to be reachable without
      // one. Two ways survive the row's menu going: the custom semantics
      // action every row registers, asserted here, and "Remove from library"
      // on the page the chevron opens, asserted below.
      await pump(tester, const Scaffold(body: LibraryPage()));

      final registered = tester
          .widgetList<Semantics>(
            find.descendant(
              of: find.byType(DSDismissibleTile).first,
              matching: find.byType(Semantics),
            ),
          )
          .expand(
            (s) =>
                s.properties.customSemanticsActions?.keys ??
                const <CustomSemanticsAction>[],
          )
          .map((action) => action.label);
      expect(registered, contains('Remove'));
    });

    testWidgets('the twin removes the row, and offers the same undo', (
      tester,
    ) async {
      final container = await pump(
        tester,
        LibraryDetailPage(item: items.first),
      );

      await tester.tap(find.byType(DSMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from library'));
      await tester.pumpAndSettle();

      expect(
        container.read(removedLibraryItemsProvider),
        contains(items.first.id),
      );
      expect(find.text('Undo'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(container.read(removedLibraryItemsProvider), isEmpty);
    });

    testWidgets('pull-to-refresh works even when the list fits', (
      tester,
    ) async {
      await pump(tester, const Scaffold(body: LibraryPage()));
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);

      final scrollable = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      expect(scrollable.physics, isA<AlwaysScrollableScrollPhysics>());
    });

    testWidgets('the search field lines up with the list it filters', (
      tester,
    ) async {
      // The page owns the gutter. `DSSearchBar` used to add a second one, so
      // the pill sat at 32 while the chips and the rows beside it sat at 16 —
      // a control visibly not part of the list under it.
      await pump(tester, const Scaffold(body: LibraryPage()));

      final field = tester.getRect(find.byType(DSSearchBar)).left;
      expect(field, tester.getRect(find.byType(DSChip).first).left);
      expect(field, DesignSpec.halo().space.pageGutter);
    });

    testWidgets('the chip strip is the height of its chips', (tester) async {
      // A horizontal `ListView` has to be told a height, and the formula that
      // told this one added a chip's own padding a second time: 60 points
      // reserved for a 36-point chip, 24 of them dead, at every text size.
      await pump(tester, const Scaffold(body: LibraryPage()));

      final chip = tester.getRect(find.byType(DSChip).first);
      final strip = tester.getRect(
        find.ancestor(
          of: find.byType(DSChip).first,
          matching: find.byType(SingleChildScrollView),
        ),
      );
      expect(strip.height, chip.height);
    });

    testWidgets('the filter stays visible while the list scrolls', (
      tester,
    ) async {
      // Scrolling a filtered list and losing sight of what filtered it is the
      // failure both the field and the strip exist to prevent, so both are
      // pinned and neither moves.
      // A list long enough to scroll: the three-item fixture fits the phone,
      // and a page that cannot scroll cannot show what pinning does.
      await pump(
        tester,
        const Scaffold(body: LibraryPage()),
        library: <LibraryItem>[
          for (var i = 0; i < 20; i++)
            LibraryItem(
              id: 'i$i',
              title: 'Chapter $i',
              subtitle: 'Two chapters',
              detail: 'Long enough to scroll.',
              iconName: 'palette',
              category: 'Design',
            ),
        ],
      );
      final strip = tester.getRect(find.byType(DSChip).first);
      final field = tester.getRect(find.byType(DSSearchBar));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(DSChip), findsWidgets);
      expect(
        tester.getRect(find.byType(DSChip).first).top,
        strip.top,
        reason: 'the strip is pinned under the field and does not move',
      );
      expect(
        find.byType(DSSearchBar),
        findsOneWidget,
        reason: 'the field is pinned — the query stays reachable mid-list',
      );
      expect(
        tester.getRect(find.byType(DSSearchBar)).top,
        field.top,
        reason: 'and it stays on the line it started on',
      );
    });
  });

  group('Shelf — browse', () {
    testWidgets('one hero, and it is above every rail', (tester) async {
      await pump(tester, const BrowsePage());

      // One hero. Two heroes is a grid whose cells are too big, which is the
      // archetype's own words for what a shelf stops being.
      expect(find.byType(DSMediaHero), findsOneWidget);

      final hero = tester.getRect(find.byType(DSMediaHero));
      final firstRailTitle = tester.getRect(
        find.text(demoBrowseRails.first.title),
      );
      expect(hero.bottom, lessThanOrEqualTo(firstRailTitle.top));
    });

    testWidgets('every rail names why it is there', (tester) async {
      await pump(tester, const BrowsePage());
      // Not a genre between them: each title is a reason — what the reader
      // was doing, what it is near, what is happening now. Scrolled to
      // rather than asserted in place: a shelf is taller than a screenful,
      // which is the point of it.
      for (final rail in demoBrowseRails) {
        await tester.scrollUntilVisible(
          find.text(rail.title),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.text(rail.title),
          findsOneWidget,
          reason: 'the rail ${rail.title} lost its reason',
        );
      }
    });

    testWidgets('a rail past four tiles carries a route out', (tester) async {
      await pump(tester, const BrowsePage());
      for (final rail in demoBrowseRails) {
        if (rail.items.length > 4) {
          expect(
            rail.seeAllLabel,
            isNotNull,
            reason:
                '${rail.title} holds ${rail.items.length} and hides the '
                'ones past the swipe',
          );
        }
      }
      // And the one that has it draws it.
      await tester.scrollUntilVisible(
        find.text('See all'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('See all'), findsOneWidget);
    });

    testWidgets('the next tile peeks past the right edge', (tester) async {
      await pump(tester, const BrowsePage());

      final screen = tester.getSize(find.byType(Scaffold)).width;
      final tiles = tester.widgetList(find.byType(DSMediaTile)).length;
      expect(tiles, greaterThan(0));

      // The first rail runs past the frame: partial visibility is the
      // signifier that a row scrolls, and a rail that fits entirely reads as
      // a row that stops there.
      final first = demoBrowseRails.first;
      final lastTile = tester.getRect(find.text(first.items.last.title));
      expect(
        lastTile.right,
        greaterThan(screen),
        reason: 'the whole rail fits, so nothing signals that it scrolls',
      );
    });

    testWidgets('the title is text, not only artwork', (tester) async {
      await pump(tester, const BrowsePage());
      // A personalised picture is a guess about the reader; the name is not
      // negotiable, and it is under the tile in text.
      for (final item in demoBrowseRails.first.items) {
        expect(find.text(item.title), findsOneWidget);
      }
    });
  });

  group('Confirmation — the order', () {
    testWidgets('the outcome is past tense, and it is not a dialog', (
      tester,
    ) async {
      await pump(tester, const OrderPlacedPage());
      expect(find.text('Your order is placed'), findsOneWidget);
      // A confirmation is a screen. The end of four screens of work does not
      // get dismissed by a tap outside it.
      expect(find.byType(DSDialog), findsNothing);
      expect(find.byType(DSMessage), findsOneWidget);
    });

    testWidgets('the identifier is selectable', (tester) async {
      await pump(tester, const OrderPlacedPage());
      final selectable = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      expect(selectable.data, contains('RS-4821'));
    });

    testWidgets('the summary is on the screen, not only in the email', (
      tester,
    ) async {
      await pump(tester, const OrderPlacedPage());
      expect(find.text('Rocketship Notebook'), findsOneWidget);
      expect(find.text('Ink refill'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('£34.98'), findsOneWidget);
    });

    testWidgets('what happens next carries a date', (tester) async {
      await pump(tester, const OrderPlacedPage());
      final next = find.textContaining('Arrives Thursday 12 March');
      expect(next, findsOneWidget);
      // "Soon" is the word this assertion exists to keep off the screen.
      expect(find.textContaining('soon'), findsNothing);
    });

    testWidgets('one way onward, pinned', (tester) async {
      await pump(tester, const OrderPlacedPage());
      expect(find.byType(DSPinnedActionBar), findsOneWidget);
      final before = tester.getRect(find.byType(DSPinnedActionBar));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Track order'), findsOneWidget);
      expect(tester.getRect(find.byType(DSPinnedActionBar)), before);
    });
  });

  group('Canvas — the map', () {
    testWidgets('two or three detents, named', (tester) async {
      await pump(tester, const PlacePage());

      // A sheet that settles anywhere is a sheet the reader has to aim.
      // Three is the ceiling `tool/feature_plan.dart` validates a plan
      // against, as `maxCanvasDetents`. Peek, half, full.
      expect(PlacePage.detents, hasLength(lessThanOrEqualTo(3)));
      expect(PlacePage.detents.length, PlacePage.detentNames.length);

      final sheet = tester.widget<DSBottomSheet>(find.byType(DSBottomSheet));
      expect(sheet.snapPoints, PlacePage.detents);
      expect(sheet.snapLabels, PlacePage.detentNames);
    });

    testWidgets('the ground stays interactive under the sheet', (tester) async {
      await pump(tester, const PlacePage());

      // A sheet that blocks the map it describes is a dialog wearing a
      // sheet's shape. The ground is pannable and its pins are tappable with
      // the sheet up — proved by tapping one and watching the sheet follow.
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('Rocketship Studio'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('The Kit Room'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('The Kit Room'), findsOneWidget);
      expect(find.text('2 Founders Yard'), findsOneWidget);
    });

    testWidgets('the smallest detent leaves the subject visible', (
      tester,
    ) async {
      await pump(tester, const PlacePage());

      // Peek exists so the reader can see the pin they just tapped. The pin
      // sits above the sheet's top edge at the opening detent.
      // The surface, not the widget: a snapping sheet's `DSBottomSheet` is a
      // `DraggableScrollableSheet` filling the stack, and what the reader
      // sees is the surface inside it.
      final sheet = tester.getRect(find.byType(DSOverlaySurface));
      final pin = tester.getRect(
        find.ancestor(
          of: find.bySemanticsLabel(demoPlaces.first.name),
          matching: find.byType(DSPressable),
        ),
      );
      expect(pin.bottom, lessThan(sheet.top));
    });

    testWidgets('the floating control rides above the sheet', (tester) async {
      await pump(tester, const PlacePage());

      final button = tester.getRect(
        find.widgetWithIcon(DSIconButton, Icons.my_location),
      );
      final sheet = tester.getRect(find.byType(DSOverlaySurface));
      // A recentre button the sheet covers at half is a control that exists
      // at one detent only.
      expect(button.bottom, lessThanOrEqualTo(sheet.top));
    });

    testWidgets('the handle cycles the detents rather than popping', (
      tester,
    ) async {
      await pump(tester, const PlacePage());

      // The default handle dismisses the route, which over a ground the
      // reader is still using takes the ground away with the sheet.
      final handle = tester.widget<DSDragHandle>(find.byType(DSDragHandle));
      expect(handle.onTap, isNotNull);
      expect(handle.semanticLabel, contains('Expand'));

      final before = tester.getRect(find.byType(DSOverlaySurface)).top;
      await tester.tap(find.byType(DSDragHandle));
      await tester.pumpAndSettle();
      // Still on the screen, and the sheet moved up a detent.
      expect(find.byType(PlacePage), findsOneWidget);
      expect(
        tester.getRect(find.byType(DSOverlaySurface)).top,
        lessThan(before),
      );
    });

    testWidgets('the ground is never the only statement of the state', (
      tester,
    ) async {
      await pump(tester, const PlacePage());

      // A map is silent. The name, the address, the distance and the hours
      // are text, where a screen reader can reach them.
      final place = demoPlaces.first;
      expect(find.text(place.name), findsOneWidget);
      expect(find.text(place.address), findsOneWidget);
      expect(find.text(place.open), findsOneWidget);
      expect(find.textContaining(place.distance), findsOneWidget);
    });
  });

  group('Detail — the library item', () {
    testWidgets('the primary action is pinned and does not scroll away', (
      tester,
    ) async {
      await pump(tester, LibraryDetailPage(item: items.first));

      final before = tester.getRect(find.byType(DSPinnedActionBar));
      expect(find.text('Continue'), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Continue'), findsOneWidget);
      expect(tester.getRect(find.byType(DSPinnedActionBar)), before);
      // Pinned to the bottom edge, not floating somewhere near it.
      expect(before.bottom, tester.getSize(find.byType(Scaffold)).height);
    });

    testWidgets('the content is in titled sections, not one wall of text', (
      tester,
    ) async {
      await pump(tester, LibraryDetailPage(item: items.first));
      expect(find.byType(DSSection), findsNWidgets(3));
      expect(find.text('Where you are'), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Related'), findsOneWidget);
    });

    testWidgets('secondary actions are in the overflow, not in a row of them', (
      tester,
    ) async {
      await pump(tester, LibraryDetailPage(item: items.first));
      // One menu in the bar; the bar carries no other buttons of its own.
      expect(find.byType(DSMenu), findsOneWidget);
    });
  });

  group('Profile — the reader\'s own page', () {
    testWidgets('the primary is pinned and does not scroll away', (
      tester,
    ) async {
      await pump(tester, const ProfilePage(), height: 1200);

      final before = tester.getRect(find.byType(DSPinnedActionBar));
      expect(find.widgetWithText(DSButton, 'Edit profile'), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.widgetWithText(DSButton, 'Edit profile'), findsOneWidget);
      expect(tester.getRect(find.byType(DSPinnedActionBar)), before);
    });

    testWidgets('secondary actions are in the overflow, not loose buttons', (
      tester,
    ) async {
      await pump(tester, const ProfilePage(), height: 1200);
      // One menu in the bar; the bar's own buttons are the pinned primary
      // only. Two overflow menus, or a second free-floating button, is the
      // "five buttons in a row" failure the archetype's rule is about.
      expect(find.byType(DSMenu), findsOneWidget);
    });

    testWidgets('the reader is themself — the name comes from the session', (
      tester,
    ) async {
      await pump(tester, const ProfilePage(), height: 1200);
      // `currentUserProvider` reads the signed-in session `pump` wires up
      // above, not a fixture — this is the reader's own page.
      expect(find.text('Ada Lovelace'), findsOneWidget);
    });

    testWidgets('the stats are a grid, not a wall of numbers', (tester) async {
      await pump(tester, const ProfilePage(), height: 1200);
      expect(find.byType(DSAvatar), findsOneWidget);
      expect(find.byType(DSStatTile), findsNWidgets(2));
    });

    testWidgets('a badge is read, never toggled', (tester) async {
      await pump(
        tester,
        const ProfilePage(initialSection: ProfileSection.badges),
        height: 1400,
      );
      final chips = tester.widgetList<DSChip>(find.byType(DSChip));
      expect(chips, isNotEmpty);
      // `tag`, not `filter` — the same chip the Library uses to filter would
      // be wrong the moment it grew an `onSelected`.
      expect(chips.every((c) => c.role == DSChipRole.tag), isTrue);
      expect(chips.every((c) => c.onSelected == null), isTrue);
    });

    testWidgets('the segmented control swaps the whole body', (tester) async {
      await pump(tester, const ProfilePage(), height: 1400);
      expect(find.byType(DSListTile), findsWidgets);
      expect(find.byType(DSChip), findsNothing);

      await tester.tap(find.text('Badges'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(DSChip), findsWidgets);
      expect(find.text('How badges work'), findsOneWidget);
    });
  });

  group('Form — sign in and sign up', () {
    testWidgets(
      'the primary is in the pinned bar, not at the end of a scroll',
      (tester) async {
        await pump(tester, const LoginPage());

        expect(
          find.descendant(
            of: find.byType(DSPinnedActionBar),
            matching: find.widgetWithText(DSButton, 'Sign in'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.widgetWithText(DSButton, 'Sign in'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets('sign-up puts its primary in the same place', (tester) async {
      // Two forms in one app with their submit buttons in two different
      // places is the difference nobody decides and everybody notices.
      await pump(tester, const SignupPage());
      expect(
        find.descendant(
          of: find.byType(DSPinnedActionBar),
          matching: find.widgetWithText(DSButton, 'Create account'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the form is one column', (tester) async {
      await pump(tester, const LoginPage());
      final fields = find.byType(DSTextField);
      final lefts = <double>[
        for (var i = 0; i < fields.evaluate().length; i++)
          tester.getTopLeft(fields.at(i)).dx,
      ];
      expect(lefts.toSet(), hasLength(1));
    });
  });

  group('Settings — grouped, with the destructive action set apart', () {
    testWidgets('sign out has left the Account group', (tester) async {
      await pump(tester, const Scaffold(body: SettingsPage()));

      // Account is on screen and the destructive action is not one row away
      // from "Upgrade to Pro". The eyebrow renders uppercased, which is the
      // widget's own doing.
      //
      // Asserted as group membership rather than as "Sign out is off the
      // first screenful", which is what this used to say. That was a fact
      // about how much air the rows had, not about where the action sits: the
      // moment `flutter-085` gave rows the height the spec declares instead
      // of Material's, nine rows fitted where eight had and the assertion
      // failed on a screen whose grouping had not moved. The separation is
      // the rule; the scroll position was a side effect of the spacing.
      expect(find.text('ACCOUNT'), findsOneWidget);

      final account = find.ancestor(
        of: find.text('ACCOUNT'),
        matching: find.byType(DSSettingsSection),
      );
      expect(account, findsOneWidget);
      expect(
        find.descendant(of: account, matching: find.text('Sign out')),
        findsNothing,
      );
    });

    testWidgets('it is the last group on the screen', (tester) async {
      await pump(tester, const Scaffold(body: SettingsPage()));

      await tester.scrollUntilVisible(find.text('Sign out'), 300);
      await tester.pump();

      final sections = tester.widgetList<DSSettingsSection>(
        find.byType(DSSettingsSection),
      );
      expect(sections.last.eyebrow, 'Session');
      expect(find.text('SESSION'), findsOneWidget);
    });

    testWidgets('the confirm names the account, and cancelling keeps it', (
      tester,
    ) async {
      final container = await pump(
        tester,
        const Scaffold(body: SettingsPage()),
      );

      await tester.scrollUntilVisible(find.text('Sign out'), 300);
      // Centred rather than merely "visible": at the larger type scale the
      // row lands past the bottom edge, inside the viewport but under the
      // screen, and the tap hits nothing.
      await Scrollable.ensureVisible(
        tester.element(find.text('Sign out')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      // The email, in the sentence. "Are you sure?" asks the user to remember
      // which account they are signed in to, which is the question they
      // opened this screen because they could not answer.
      expect(
        find.textContaining('sign in as ada@rocketship.dev'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(container.read(authProvider).isAuthenticated, isTrue);
    });
  });

  group('Sequence — the first-run tour', () {
    Future<void> pumpTour(WidgetTester tester, {int stop = 0}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: Design(
            spec: AppTheme.spec,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              // Keyed by the stop: `initialStop` is read in initState, so
              // pumping a second stop without a new key would re-render the
              // first one and the walk below would prove nothing.
              home: OnboardingPage(key: ValueKey<int>(stop), initialStop: stop),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('progress carries one mark per stop', (tester) async {
      // "How far in am I" is the question a sequence owes an answer to, and
      // a flow that answers it with nothing is a corridor with no end.
      await pumpTour(tester);
      final dots = tester.widget<DSTourDots>(find.byType(DSTourDots));
      expect(dots.count, onboardingStops.length);
    });

    testWidgets('each stop puts exactly one headline in front of the user', (
      tester,
    ) async {
      // One decision per screen. Two headlines on one page is two steps
      // wearing one step's clothes.
      for (var i = 0; i < onboardingStops.length; i++) {
        await pumpTour(tester, stop: i);
        final showing = onboardingStops
            .where((s) => find.text(s.headline).evaluate().isNotEmpty)
            .map((s) => s.headline)
            .toList();
        expect(showing, [onboardingStops[i].headline]);
      }
    });

    testWidgets('the last stop hands over rather than looping', (tester) async {
      await pumpTour(tester, stop: onboardingStops.length - 1);
      final finish = find.byType(DSButton).last;
      await tester.tap(finish);
      await tester.pump(const Duration(milliseconds: 400));
      // Handing over is the whole difference between a tour and a carousel.
      expect(prefs.getBool('onboarding_complete'), isTrue);
    });
  });

  group('Offer — the paywall', () {
    Future<void> pumpPaywall(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            // The shipped mock answers after 700ms, which is longer than any
            // gate pumps. The shape under test is the screen's, not the
            // store's latency.
            purchasesServiceProvider.overrideWithValue(
              const _InstantPurchasesService(),
            ),
          ],
          child: Design(
            spec: AppTheme.spec,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const PaywallPage(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('the primary names the purchase', (tester) async {
      await pumpPaywall(tester);
      // "Continue" names no purchase, and an action that could equally be a
      // next step is one people tap by accident.
      expect(find.text('Continue'), findsNothing);
      expect(find.textContaining(r'$29.99'), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(DSPinnedActionBar),
          matching: find.textContaining('Subscribe'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the renewal line is in the same bar as the button', (
      tester,
    ) async {
      await pumpPaywall(tester);
      // The rule the archetype turns on: a disclosure the pinned chrome
      // covers is one the user meets at the charge instead of at the tap.
      expect(
        find.descendant(
          of: find.byType(DSPinnedActionBar),
          matching: find.textContaining('Renews at'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('restore, terms and privacy are all reachable', (tester) async {
      await pumpPaywall(tester);
      // Restore is what App Review looks for; terms and privacy are what the
      // archetype requires. All three were missing before it named its shape.
      for (final label in const ['Restore purchases', 'Terms', 'Privacy']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('the button describes the plan that is ticked', (tester) async {
      await pumpPaywall(tester);
      // Highlighted by default, so the bar opens on the annual plan.
      expect(find.textContaining(r'Subscribe — $29.99/year'), findsOneWidget);

      await tester.tap(find.text('Monthly').first);
      await tester.pump();
      // And it follows the tick rather than describing a plan nobody chose.
      expect(find.textContaining(r'Subscribe — $4.99/month'), findsOneWidget);
      expect(
        find.textContaining(r'Renews at $4.99 every month'),
        findsOneWidget,
      );
    });
  });

  group('Insight — the reading recap', () {
    testWidgets('one figure, one plot, and the delta beside the figure', (
      tester,
    ) async {
      await pump(tester, const InsightPage(), height: 1200);

      // One headline, one plot. A second of either is the dashboard this
      // archetype exists to refuse.
      expect(find.byType(DSStatTile), findsOneWidget);
      expect(find.byType(DSChart), findsOneWidget);

      // In the reader's units, not the fixture's. `252` is the number the
      // data holds and `4h 12m` is the number a person was given.
      expect(find.text('4h 12m'), findsOneWidget);
      expect(find.text('252'), findsNothing);

      // The comparison is in the headline card, not a caption further down
      // the page: the chip carries the direction and the size, and the line
      // under it carries the baseline and the span in words. A delta that has
      // drifted away from the figure it modifies has become a second number.
      final headline = find.ancestor(
        of: find.byType(DSStatTile),
        matching: find.byType(DSCard),
      );
      expect(
        find.descendant(of: headline, matching: find.text('+18%')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: headline,
          matching: find.textContaining('18% more than last week'),
        ),
        findsOneWidget,
      );
      // And so is the span, so the figure's denominator is never a guess.
      expect(
        find.descendant(
          of: headline,
          matching: find.textContaining('Mon 25 – Sun 31 August'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the sentence is under the plot, not somewhere near it', (
      tester,
    ) async {
      await pump(tester, const InsightPage(), height: 1200);

      final chart = tester.getRect(find.byType(DSChart));
      final sentence = tester.getRect(
        find.textContaining('Tuesday carried the week'),
      );
      expect(sentence.top, greaterThan(chart.bottom - 1));
      // Directly under it: one gap, not a section boundary. The number this
      // guards is the card's own inner gap, and a sentence a section away
      // from the plot is a sentence about a different subject.
      expect(sentence.top - chart.bottom, lessThan(32));
    });

    testWidgets('nothing pins — an insight is read, not submitted', (
      tester,
    ) async {
      await pump(tester, const InsightPage(), height: 1200);
      expect(find.byType(DSPinnedActionBar), findsNothing);
    });

    testWidgets('the finding survives the chart being silent', (tester) async {
      // A chart is a picture. Everything it says is said again in text — the
      // headline, the written sentence and every breakdown row — so a reader
      // who cannot see the plot still has the finding.
      await pump(tester, const InsightPage(), height: 1200);

      for (final row in const ['Guides', 'Design', 'Modules']) {
        expect(find.text(row), findsOneWidget, reason: row);
      }
      expect(find.text('1h 58m'), findsOneWidget, reason: 'Guides, in words');
      expect(find.byType(DSMetricBar), findsNWidgets(3));
    });

    testWidgets('switching the period moves every number, not just the plot', (
      tester,
    ) async {
      // The defect this is the gate for: a control that redraws the chart and
      // leaves the headline, the span and the sentence describing the period
      // the reader just left. One of those disagreeing with the others is
      // what makes a reader stop believing the screen.
      await pump(tester, const InsightPage(), height: 1200);

      await tester.tap(find.text('This month'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('15h 46m'), findsOneWidget);
      expect(find.textContaining('1 – 31 August'), findsOneWidget);
      expect(find.textContaining('less than July'), findsOneWidget);
      expect(find.textContaining('August fell behind July'), findsOneWidget);
      expect(find.text('4h 12m'), findsNothing);
    });

    testWidgets('a fall is a fall, not an up arrow on a smaller number', (
      tester,
    ) async {
      await pump(
        tester,
        const InsightPage(initialPeriod: InsightPeriod.month),
        height: 1200,
      );
      final tile = tester.widget<DSStatTile>(find.byType(DSStatTile));
      expect(tile.trend, DSTrend.down);
      expect(tile.deltaLabel, '\u221214%');
      expect(find.textContaining('14% less than July'), findsOneWidget);
    });

    testWidgets('it hands over rather than ending on itself', (tester) async {
      await pump(tester, const InsightPage(), height: 1200);
      // The last control on the page is the way onward. A recap whose final
      // element is a summary of what was just read is one the reader closes.
      expect(
        find.widgetWithText(DSButton, 'Read something new'),
        findsOneWidget,
      );
    });
  });
}

/// The shipped mock with its latency removed. Everything else about it is the
/// same offering the app ships, so the labels these tests assert are the
/// labels a reader sees.
class _InstantPurchasesService implements PurchasesService {
  const _InstantPurchasesService();

  static const _offering = Offering(
    id: 'default',
    packages: [
      PurchasePackage(
        id: 'monthly',
        priceString: r'$4.99',
        title: 'Monthly',
        description: 'Billed every month. Cancel anytime.',
        period: 'month',
      ),
      PurchasePackage(
        id: 'annual',
        priceString: r'$29.99',
        title: 'Annual',
        description: 'Billed yearly — best value, ~50% off.',
        period: 'year',
        highlighted: true,
      ),
      PurchasePackage(
        id: 'lifetime',
        priceString: r'$79.99',
        title: 'Lifetime',
        description: 'One-time purchase. Yours forever.',
        period: 'lifetime',
      ),
    ],
  );

  @override
  Future<List<Offering>> offerings() async => const [_offering];
  @override
  Future<Set<String>> activeEntitlements() async => const {};
  @override
  Future<Set<String>> purchase(PurchasePackage package) async => const {
    kProEntitlement,
  };
  @override
  Future<Set<String>> restore() async => const {};
  @override
  Future<void> setUserId(String? userId) async {}
}
