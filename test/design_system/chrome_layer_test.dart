import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';

/// The chrome layer floats; content stays opaque.
///
/// A `BackdropFilter` in the tree is the observable form of "this is glass",
/// so these tests read as the rule itself: the seven chrome components have
/// one on Apple and none on Android, and the content components have none
/// anywhere. The second half is the one that matters over time — glass
/// spreading to cards is how the depth cue gets spent everywhere and stops
/// meaning anything.
void main() {
  Future<void> pumpUnder(
    WidgetTester tester,
    TargetPlatform platform,
    Widget child, {
    bool highContrast = false,
    bool disableAnimations = false,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme.copyWith(platform: platform),
        // Inside the app, not around it: MaterialApp installs its own
        // MediaQuery from the test window, so a wrapper outside it never
        // reaches the widget under test.
        builder: (context, inner) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            highContrast: highContrast,
            disableAnimations: disableAnimations,
          ),
          child: inner!,
        ),
        home: Scaffold(body: child),
      ),
    );
    await tester.pump();
  }

  final navItems = [
    const DSBottomNavItem(label: 'Home', icon: Icons.home_outlined),
    const DSBottomNavItem(label: 'Library', icon: Icons.book_outlined),
    const DSBottomNavItem(label: 'Settings', icon: Icons.settings_outlined),
  ];

  final chrome = <String, Widget>{
    'DSBottomNavBar': DSBottomNavBar(
      currentIndex: 0,
      onTap: (_) {},
      items: navItems,
    ),
    'DSFab': const DSFab(icon: Icons.add, semanticLabel: 'Add'),
  };

  /// `DSSearchBar` is not in the map either, and no longer can be: plan 26
  /// moved it onto `DSTextField`'s field skin. A search field is an input —
  /// recessed into the page — rather than a bar floating above it, and it was
  /// the third hand-built field skin in the kit while it pretended otherwise.
  ///
  /// A sheet is chrome by shape and shadow but not by material, so it is not
  /// in the map above. See `a sheet is opaque on both platforms`.
  const sheet = DSBottomSheet(child: Text('sheet'));

  /// The large bar is not in the map above: its material is a function of how
  /// far it has closed, so "is it glass" has two answers and the map only asks
  /// once. See `the large bar earns its material`.
  const largeBar = CustomScrollView(
    slivers: [
      DSLargeAppBar(title: 'Library'),
      SliverToBoxAdapter(child: SizedBox(height: 800)),
    ],
  );

  final content = <String, Widget>{
    'DSCard': const DSCard(child: Text('card')),
    'DSListTile': const DSListTile(title: 'row'),
    // DSStatTile draws no surface of its own, so what is being checked here
    // is the grid it sits in — the one card four tiles share.
    'DSStatTile': const DSStatTileGrid(
      children: [
        DSStatTile(label: 'Revenue', value: '12,400'),
        DSStatTile(label: 'Sessions', value: '1,208'),
      ],
    ),
    'DSEmptyState': const DSEmptyState(title: 'Nothing here yet.'),
  };

  group('the chrome layer is glass on Apple', () {
    chrome.forEach((name, widget) {
      testWidgets('$name blurs what is behind it', (tester) async {
        await pumpUnder(tester, TargetPlatform.iOS, widget);
        expect(
          find.byType(BackdropFilter),
          findsWidgets,
          reason: '$name should be glass on Apple',
        );
      });
    });
  });

  testWidgets('a sheet is opaque on both platforms', (tester) async {
    // Every other chrome surface sits over the page and lets it move
    // underneath. A sheet arrives over a scrim, so glass composited its tint
    // against a dimmed page and the raised end of the ladder landed grey —
    // a different grey per page. Opaque is the whole point of a sheet.
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      await pumpUnder(tester, platform, sheet);
      expect(
        find.byType(BackdropFilter),
        findsNothing,
        reason: 'DSBottomSheet should be opaque on $platform',
      );
    }
  });

  group('the same components are tonal on Android', () {
    chrome.forEach((name, widget) {
      testWidgets('$name draws no BackdropFilter', (tester) async {
        await pumpUnder(tester, TargetPlatform.android, widget);
        // Not cosmetic: a BackdropFilter reads back the layer under it every
        // frame, and Material's chrome is a tonal container, not glass.
        expect(
          find.byType(BackdropFilter),
          findsNothing,
          reason: '$name should be tonal on Android',
        );
      });
    });
  });

  group('content stays opaque, on both platforms', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      content.forEach((name, widget) {
        testWidgets('$name is not glass on $platform', (tester) async {
          await pumpUnder(tester, platform, widget);
          expect(
            find.byType(BackdropFilter),
            findsNothing,
            reason: 'glass on $name spends the depth cue on everything',
          );
        });
      });
    }
  });

  group('the large bar earns its material', () {
    // A bar that paints its chrome at rest draws a band across the top of a
    // page nobody has scrolled — a header's worth of tinted surface holding one
    // word. The material belongs to the moment content goes under it, which is
    // also the only moment glass has anything to composite.
    testWidgets('no glass on Apple until something is under it', (
      tester,
    ) async {
      await pumpUnder(tester, TargetPlatform.iOS, largeBar);
      expect(find.byType(BackdropFilter), findsNothing);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();
      expect(find.byType(BackdropFilter), findsWidgets);
    });

    testWidgets('Material resolves its fill against scrolledUnder', (
      tester,
    ) async {
      await pumpUnder(tester, TargetPlatform.android, largeBar);
      final bar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      final fill = bar.backgroundColor! as WidgetStateColor;

      expect(fill.resolve(const <WidgetState>{}), Colors.transparent);
      expect(
        fill.resolve(const <WidgetState>{WidgetState.scrolledUnder}).a,
        1.0,
      );
      // Tonal, not glass, in either state.
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  group('the OS settings that switch translucency off', () {
    testWidgets('high contrast makes the chrome opaque', (tester) async {
      // A user who turned this on is telling us they need the text edge, and
      // translucency lowers contrast by definition.
      await pumpUnder(
        tester,
        TargetPlatform.iOS,
        DSBottomNavBar(currentIndex: 0, onTap: (_) {}, items: navItems),
        highContrast: true,
      );
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('reduced motion makes the chrome opaque', (tester) async {
      // Glass is a moving effect: the content sliding underneath is the point
      // of it, and frozen glass is a dim rectangle.
      await pumpUnder(
        tester,
        TargetPlatform.iOS,
        DSBottomNavBar(currentIndex: 0, onTap: (_) {}, items: navItems),
        disableAnimations: true,
      );
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  group('the bar still behaves like a bar', () {
    testWidgets('the nav bar keeps its destinations and selection', (
      tester,
    ) async {
      var tapped = -1;
      await pumpUnder(
        tester,
        TargetPlatform.iOS,
        DSBottomNavBar(
          currentIndex: 0,
          onTap: (i) => tapped = i,
          items: navItems,
        ),
      );
      // On Apple the bar is the kit's own row of destinations — no Material
      // NavigationBar and no indicator pill, which is the platform tell this
      // bar shipped wrong for a year. What has to survive the branch is the
      // behaviour: every destination is on screen, and tapping one selects
      // it.
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Library'), findsOneWidget);
      await tester.tap(find.text('Library'));
      expect(tapped, 1);
    });

    testWidgets('the large app bar collapses on both platforms', (
      tester,
    ) async {
      // Two different builders, one contract: a pinned sliver with the title.
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        await pumpUnder(tester, platform, largeBar);
        expect(
          find.byType(SliverAppBar),
          findsOneWidget,
          reason: '$platform lost the sliver',
        );
        expect(find.text('Library'), findsWidgets);
      }
    });
  });

  group('the collapsed title clears the leading button', () {
    // Found by running on a simulator. `FlexibleSpaceBar` has one
    // `titlePadding`, and the glass branch sets it to the page gutter so the
    // large title lines up with the content — which puts the *collapsed*
    // title at x=16, straight through the back button. Material's own large
    // bar renders two titles and cross-fades them, so only the Apple branch
    // has the problem, and only once the bar has scrolled.
    // Apple only, and deliberately: `SliverAppBar.large` builds two titles and
    // cross-fades them, so its expanded copy is still in the tree at zero
    // opacity over the back button when collapsed. That copy is the
    // framework's business and is invisible; asserting about it here would be
    // asserting about Material's implementation rather than about this widget.
    testWidgets('on Apple, once the bar has collapsed', (tester) async {
      {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme.copyWith(platform: TargetPlatform.iOS),
            home: const Scaffold(
              body: CustomScrollView(
                slivers: [
                  DSLargeAppBar(title: 'Library', leading: BackButton()),
                  SliverToBoxAdapter(child: SizedBox(height: 2000)),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        // Past the bar's whole travel, so it is fully collapsed.
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
        await tester.pump();

        final back = tester.getRect(find.byType(BackButton));
        final titles = find.text('Library');
        expect(titles, findsWidgets);
        for (var i = 0; i < titles.evaluate().length; i++) {
          expect(
            tester.getRect(titles.at(i)).overlaps(back),
            isFalse,
            reason: 'the collapsed title is drawn over the back button',
          );
        }
      }
    });

    // The same failure, one step earlier: a pushed screen that passes no
    // leading still gets a back button, because [SliverAppBar] implies one on
    // any route that can be popped. Reading `leading != null` said there was
    // nothing to clear, so the title stayed at the gutter and was drawn
    // through a button this widget did not know about. Found on a device, on
    // the Components tab's detail page.
    testWidgets('on Apple, with a back button it was never passed', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme.copyWith(platform: TargetPlatform.iOS),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(
                        body: CustomScrollView(
                          slivers: [
                            // No leading: the route supplies one.
                            DSLargeAppBar(title: 'Library'),
                            SliverToBoxAdapter(child: SizedBox(height: 2000)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  child: const Text('push'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();

      final back = tester.getRect(find.byType(BackButton));
      final titles = find.text('Library');
      expect(titles, findsWidgets);
      for (var i = 0; i < titles.evaluate().length; i++) {
        expect(
          tester.getRect(titles.at(i)).overlaps(back),
          isFalse,
          reason: 'the collapsed title is drawn over the implied back button',
        );
      }
    });

    // The same failure again, on a top-level tab: a [Scaffold] with a drawer
    // makes [SliverAppBar] imply a [DrawerButton], and nothing about that is
    // visible in `leading` or in the route — the screen passes no leading and
    // there is nothing to pop, so both earlier checks said the start of the
    // bar was free. Found on a device, on the Components tab.
    testWidgets('on Apple, with a drawer button it was never passed', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme.copyWith(platform: TargetPlatform.iOS),
          home: const Scaffold(
            drawer: Drawer(),
            body: CustomScrollView(
              slivers: [
                // No leading: the Scaffold's drawer supplies one.
                DSLargeAppBar(title: 'Library'),
                SliverToBoxAdapter(child: SizedBox(height: 2000)),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();

      final menu = tester.getRect(find.byType(DrawerButton));
      final titles = find.text('Library');
      expect(titles, findsWidgets);
      for (var i = 0; i < titles.evaluate().length; i++) {
        expect(
          tester.getRect(titles.at(i)).overlaps(menu),
          isFalse,
          reason: 'the collapsed title is drawn over the implied drawer button',
        );
      }
    });
  });
}
