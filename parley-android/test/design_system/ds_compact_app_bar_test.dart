import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/ds_compact_app_bar.dart';
import 'package:parley_android/design_system/ds_page_header_style.dart';
import 'package:parley_android/theme/app_materials.dart';
import 'package:parley_android/theme/app_theme.dart';

/// The compact header is a navigation bar, not a shrunken large one.
///
/// It has no collapse, so it cannot signal "there is content behind me" the
/// way the large bar does by closing — which is exactly why the scrolled-under
/// treatment is the test that matters here.
void main() {
  Future<void> pump(
    WidgetTester tester,
    TargetPlatform platform, {
    Widget? leading,
    List<Widget>? actions,
    ScrollController? controller,
  }) async {
    // Widget tests that switch TargetPlatform between pumps must reset the
    // tree first, or Flutter reuses the element tree and silently keeps
    // reading the first platform's value.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme.copyWith(platform: platform),
        home: Scaffold(
          body: CustomScrollView(
            controller: controller,
            slivers: [
              DSCompactAppBar(
                title: 'Display',
                leading: leading,
                actions: actions,
              ),
              SliverList.list(
                children: List.generate(
                  30,
                  (i) => SizedBox(height: 80, child: Text('row $i')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Reads the fade the Apple branch's `_GlassWhenScrolledUnder` drives,
  /// straight from the tree. `_GlassWhenScrolledUnder` itself is file-private
  /// and unreachable from a test, but `AnimatedOpacity` and `AppChromeSurface`
  /// — the public widgets it composes — are enough to prove the sliver's
  /// scroll geometry actually reaches the render tree, rather than asserting
  /// against the private widget that carries it.
  double glassOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byType(AppChromeSurface),
          matching: find.byType(AnimatedOpacity),
        ),
      )
      .opacity;

  testWidgets('is the platform navigation-bar height', (tester) async {
    await pump(tester, TargetPlatform.iOS);
    // SliverAppBar resolves to a RenderSliver, not a RenderBox, so
    // tester.getSize on it throws. SliverAppBar builds an AppBar that fills
    // the sliver's extent, so measure that instead.
    expect(tester.getRect(find.byType(AppBar)).height, 44);

    await pump(tester, TargetPlatform.android);
    expect(tester.getRect(find.byType(AppBar)).height, kToolbarHeight);
  });

  testWidgets('the title clears the leading button', (tester) async {
    await pump(tester, TargetPlatform.iOS, leading: const BackButton());

    // Not just "to the right of" the leading button — the widget's own
    // contract is that with a leading button the title lands exactly on
    // `collapsedTitleStart`, the same line the large bar's collapsed title
    // uses. Asserting the derived token, not a >= relation, is what catches a
    // regression that collapses the gap to near-zero.
    final context = tester.element(find.byType(DSCompactAppBar));
    final expectedStart = DSPageHeaderStyle.resolve(
      context,
    ).collapsedTitleStart!;

    final title = tester.getTopLeft(find.text('Display'));
    expect(title.dx, expectedStart);
  });

  testWidgets('transparent at rest, chrome once scrolled under', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await pump(tester, TargetPlatform.android, controller: controller);

    AppBar bar() => tester.widget<AppBar>(find.byType(AppBar));
    // AppBar.backgroundColor is typed Color?, so .resolve isn't on it
    // directly — cast to the WidgetStateColor the component actually hands
    // it.
    final color = bar().backgroundColor! as WidgetStateColor;
    expect(color.resolve(const <WidgetState>{}), Colors.transparent);
    expect(
      color.resolve(const {WidgetState.scrolledUnder}),
      isNot(Colors.transparent),
    );
  });

  testWidgets('on Apple the glass fades in once scrolled under, and back out', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await pump(tester, TargetPlatform.iOS, controller: controller);

    // At rest: no content behind the bar, so no glass.
    expect(glassOpacity(tester), 0);

    controller.jumpTo(400);
    await tester.pumpAndSettle();
    expect(glassOpacity(tester), 1);

    // Scrolling back to the top must drop the glass again — this is the
    // half a one-shot "reveal on first scroll" flag would miss.
    controller.jumpTo(0);
    await tester.pumpAndSettle();
    expect(glassOpacity(tester), 0);
  });

  testWidgets('takes its glass from geometry, with no Scaffold above it', (
    tester,
  ) async {
    // A Scaffold is what installs the ScrollNotificationObserver Material's
    // own AppBar reads. This bar does not use it, and this is the test that
    // says so: with no Scaffold anywhere above it, the glass still arrives
    // when content does.
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme.copyWith(platform: TargetPlatform.iOS),
        home: CustomScrollView(
          controller: controller,
          slivers: [
            const DSCompactAppBar(title: 'Display'),
            SliverList.list(
              children: List.generate(
                30,
                (i) => SizedBox(height: 80, child: Text('row $i')),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(glassOpacity(tester), 0);

    controller.jumpTo(400);
    await tester.pumpAndSettle();
    expect(glassOpacity(tester), 1);
  });

  testWidgets(
    'the glass arrives inside a PageView, as the app shell nests it',
    (tester) async {
      // The regression this mechanism exists for. The app shell is one Scaffold
      // whose body is a PageView of destinations, so a destination's own scroll
      // notification bubbles through the PageView's viewport and reaches the
      // Scaffold's ScrollNotificationObserver at a nonzero depth, where
      // `defaultScrollNotificationPredicate` discards it. Driven by that
      // observer, every top-level destination kept a transparent header with
      // the content sliding through its title.
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme.copyWith(platform: TargetPlatform.iOS),
          home: Scaffold(
            body: PageView(
              children: [
                CustomScrollView(
                  controller: controller,
                  slivers: [
                    const DSCompactAppBar(title: 'Display'),
                    SliverList.list(
                      children: List.generate(
                        30,
                        (i) => SizedBox(height: 80, child: Text('row $i')),
                      ),
                    ),
                  ],
                ),
                const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(glassOpacity(tester), 0);

      controller.jumpTo(400);
      await tester.pumpAndSettle();
      expect(glassOpacity(tester), 1);
    },
  );

  testWidgets('a nested horizontal scrollable does not trigger the glass', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    final chipController = ScrollController();
    addTearDown(chipController.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme.copyWith(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              const DSCompactAppBar(title: 'Display'),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 80,
                  child: ListView(
                    controller: chipController,
                    scrollDirection: Axis.horizontal,
                    children: List.generate(
                      20,
                      (i) => SizedBox(width: 120, child: Text('chip $i')),
                    ),
                  ),
                ),
              ),
              SliverList.list(
                children: List.generate(
                  10,
                  (i) => SizedBox(height: 80, child: Text('row $i')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(glassOpacity(tester), 0);

    // A horizontal chip strip inside the page scrolling must not decide
    // whether the page's own header has content behind it. Geometry answers
    // that by construction — the inner list moves nothing about the outer
    // sliver's scroll offset — and this test is what pins the property
    // through any later change of mechanism.
    chipController.jumpTo(300);
    await tester.pumpAndSettle();
    expect(glassOpacity(tester), 0);
  });

  testWidgets('stays put while the content scrolls', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await pump(tester, TargetPlatform.iOS, controller: controller);

    final before = tester.getTopLeft(find.text('Display'));
    controller.jumpTo(400);
    await tester.pumpAndSettle();

    expect(find.text('Display'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Display')), before);
  });

  testWidgets('renders actions', (tester) async {
    await pump(
      tester,
      TargetPlatform.iOS,
      actions: [IconButton(icon: const Icon(Icons.share), onPressed: () {})],
    );
    expect(find.byIcon(Icons.share), findsOneWidget);
  });
}
