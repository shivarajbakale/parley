import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/catalog/catalog.dart';
import 'package:parley_android/screens/design_system/component_page.dart';
import 'package:parley_android/screens/design_system/demos_page.dart';
import 'package:parley_android/screens/design_system/gallery_page.dart';
import 'package:parley_android/theme/app_theme.dart';

/// The Components tab exists so the kit is findable. That claim only holds
/// while the gallery and the kit hold the same set of components, and a
/// hand-written catalog drifts the moment somebody adds a widget — which is
/// exactly when the gallery is most worth having.
///
/// So the coverage is a test rather than a convention, checked against the
/// generated reference (itself gated by `make check`, so it cannot drift from
/// `lib/design_system/` either). Adding a component now fails here until it
/// has stories, in the same way it already fails
/// `design_system_reference --check` until it has selection guidance.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Every component the kit ships, read from the generated reference.
  Set<String> shippedComponents() {
    final file = File('docs/references/design-system-reference-llms.txt');
    expect(
      file.existsSync(),
      isTrue,
      reason:
          'the generated reference is missing — run '
          '`make design-system-reference-update`',
    );
    return RegExp(r'^### `(DS\w+)`$', multiLine: true)
        .allMatches(file.readAsStringSync())
        .map((match) => match.group(1)!)
        .toSet();
  }

  group('the catalog covers the kit', () {
    test('exactly the shipped components have a page', () {
      final shipped = shippedComponents();
      final gallery = catalogComponents.map((c) => c.name).toSet();

      expect(shipped, isNotEmpty);
      expect(
        shipped.difference(gallery),
        isEmpty,
        reason:
            'shipped but not in the gallery — add stories in '
            'lib/screens/design_system/catalog/',
      );
      expect(
        gallery.difference(shipped),
        isEmpty,
        reason: 'the gallery names a component the kit no longer ships',
      );
    });

    test('every component has at least one usage, distinctly titled', () {
      for (final component in catalogComponents) {
        expect(
          component.stories,
          isNotEmpty,
          reason: '${component.name} has no stories',
        );
        final titles = component.stories.map((s) => s.title).toList();
        expect(
          titles.toSet(),
          hasLength(titles.length),
          reason: '${component.name} repeats a story title',
        );
        for (final story in component.stories) {
          expect(
            story.note,
            isNotEmpty,
            reason:
                '${component.name} / ${story.title} has no note — the '
                'note is the half that says when to reach for this usage',
          );
        }
      }
    });

    test('the catalog is grouped the way the reference is', () {
      final file = File('docs/references/design-system-reference-llms.txt');
      final referenceGroups = RegExp(r'^## (.+) \(\d+\)$', multiLine: true)
          .allMatches(file.readAsStringSync())
          .map((match) => match.group(1)!)
          .toList();
      expect(
        designSystemCatalog.map((c) => c.name).toList(),
        referenceGroups,
        reason:
            'a component should sit in the same category in both, or the '
            'gallery and the reference are two maps of one kit',
      );
    });
  });

  /// A story that throws, overflows or asserts on build is a story that would
  /// have done the same inside a screen.
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: child),
    );
    // Long frames rather than pumpAndSettle: several stories carry a shimmer
    // or a staggered entrance, and settling is not guaranteed to terminate on
    // an animation that repeats.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  group('every usage builds', () {
    for (final component in catalogComponents) {
      testWidgets(component.name, (tester) async {
        await pump(
          tester,
          Scaffold(
            body: ListView(
              children: [
                for (final story in component.stories)
                  Builder(builder: story.builder),
              ],
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('the gallery page', () {
    testWidgets('lists every component under its category', (tester) async {
      await pump(tester, const Scaffold(body: ComponentGalleryPage()));

      for (final category in designSystemCatalog) {
        expect(
          find.textContaining(category.name),
          findsWidgets,
          reason: '${category.name} has no section header',
        );
      }
      // The list is lazy, so this checks the first category's rows rather
      // than all 44 — the coverage claim is the test above, this one is that
      // the rows render at all.
      expect(find.text(catalogComponents.first.name), findsOneWidget);
    });

    testWidgets('search narrows to what matches', (tester) async {
      await pump(tester, const Scaffold(body: ComponentGalleryPage()));

      await tester.enterText(find.byType(DSSearchBar), 'skeleton');
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('DSSkeleton'), findsOneWidget);
      expect(find.text('DSButton'), findsNothing);
    });

    testWidgets('a filter that matches nothing offers the way back', (
      tester,
    ) async {
      await pump(tester, const Scaffold(body: ComponentGalleryPage()));

      await tester.enterText(find.byType(DSSearchBar), 'zzzz');
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(DSEmptyState), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);
    });
  });

  group('the Demos tab', () {
    /// `demos_page.dart` is one row per demo screen, each pushing a route
    /// the reader can preview. The router-level gates and the `appScreens`
    /// registry already prevent a screen from being *born invisible*; this
    /// group is the other half — a screen that ships must be reachable from
    /// here, and a tile whose route this tab no longer mentions has drifted
    /// from the demo surface it is part of.
    ///
    /// The tiles are the six scaffolding demos: Blog (a list and an
    /// article, Catalog-driven), Inbox (two tab-bar components sharing
    /// one screen), Form (the Form archetype as a four-step flow),
    /// Welcome (the moment the app introduces itself, flutter-048), Recap
    /// (the Insight archetype — one figure, one plot, one sentence), Browse
    /// (the Shelf archetype — one hero over rails that name their reason),
    /// Order placed (the Confirmation archetype — an identifier and a dated
    /// next step), Note (the Editor archetype — one document under a
    /// toolbar), Player (the Session archetype — a running state), Places
    /// (the Canvas archetype — a ground under a sheet with detents) and
    /// Profile (the Detail archetype against a person — DSAvatar, a stat
    /// grid, DSChip as a badge) and Data explorer (the native chart and the
    /// Svelte web module on one screen, drawing the same numbers from the
    /// same tokens).
    /// Adding a `lib/screens/design_system/*.dart` demo here is what makes
    /// it discoverable to a reader exploring this tab.
    testWidgets('surfaces the nine demo tiles, in this order', (
      tester,
    ) async {
      await pump(tester, const Scaffold(body: DemosPage()));
      // Taller than a phone, after the pump that fixes the phone size: the
      // list is lazy, and a tile below the cache extent is never built — so
      // at 844 points this asserted the order of whichever nine happened to
      // be mounted, and a tenth tile could be added anywhere with nothing
      // failing.
      tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
      await tester.pump();

      final tiles = tester
          .widgetList<DSListTile>(
            find.descendant(
              of: find.byType(DemosPage),
              matching: find.byType(DSListTile),
            ),
          )
          .map((t) => t.title)
          .where((title) => title.isNotEmpty)
          .toList();

      const expectedTitles = <String>[
        'Blog',
        'Inbox',
        'Form',
        'Welcome',
        'Recap',
        'Browse',
        'Order placed',
        'Places',
        'Profile',
      ];
      expect(
        tiles,
        expectedTitles,
        reason:
            'the Demos tab lists, in order: ${expectedTitles.join(', ')}. '
            'Adding a new demo means adding its tile here and to the '
            'expectedTitles above.',
      );
    });
  });

  group('a component page', () {
    testWidgets('shows every usage of the component it names', (tester) async {
      await pump(tester, const ComponentPage(name: 'DSButton'));

      // The list is lazy, so the later stories are reached the way a reader
      // reaches them: by scrolling.
      final button = componentDemoNamed('DSButton')!;
      for (final story in button.stories) {
        await tester.scrollUntilVisible(
          find.text(story.title),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(story.title), findsOneWidget);
      }
    });

    testWidgets('an unknown name is a state, not a blank screen', (
      tester,
    ) async {
      await pump(tester, const ComponentPage(name: 'DSNotAThing'));

      expect(find.byType(DSEmptyState), findsOneWidget);
    });

    testWidgets('the component is above the fold, not the chrome', (
      tester,
    ) async {
      // `docs/principles/premium.md`, "The fold". The page's own header used
      // to spend 348 of a phone's 844 points before the first story — a title
      // bar, an eyebrow, a summary, and a bordered note identical on all
      // fifty pages. A page whose subject starts below the fold is a page
      // about its own chrome.
      await pump(tester, const ComponentPage(name: 'DSButton'));

      final first = tester.getRect(find.byType(DSSection).first);
      expect(
        first.top,
        lessThan(844 / 2),
        reason: 'the first story starts at ${first.top} of 844',
      );
    });

    testWidgets('every story body sits inside the page gutter', (tester) async {
      // The catalog owns the gutter. A story whose body touches the screen
      // edge is the defect this whole feature exists to prevent — the lint
      // rule keeps the source from regressing, and this test keeps the
      // rendered output from doing so.
      await pump(tester, const ComponentPage(name: 'DSButton'));

      // DSSection's outer Column fills the screen width (the SliverList is
      // its parent). What sits inside the gutter is the body Column — the
      // Column that's a child of DSSection's body Padding. Width is the
      // discriminator: the outer Column is 390 wide, the body Column is 358
      // (390 minus a 16-point gutter on each side).
      const gutter = 16.0;
      const tolerance = 0.5;
      const screenWidth = 390.0;
      for (final section in tester.widgetList(find.byType(DSSection))) {
        final columns = tester.widgetList(
          find.descendant(
            of: find.byWidget(section),
            matching: find.byType(Column),
          ),
        );
        for (final column in columns) {
          final rect = tester.getRect(find.byWidget(column));
          // The outer Column fills the screen; the body Column does not.
          if (rect.width >= screenWidth - tolerance) continue;
          expect(
            rect.left,
            greaterThanOrEqualTo(gutter - tolerance),
            reason:
                'a story body starts at left=${rect.left.toStringAsFixed(1)}, '
                'expected ≥ $gutter (the page gutter)',
          );
          expect(
            rect.right,
            lessThanOrEqualTo(screenWidth - gutter + tolerance),
            reason:
                'a story body ends at right=${rect.right.toStringAsFixed(1)}, '
                'expected ≤ ${screenWidth - gutter}',
          );
        }
      }
    });
  });
}
