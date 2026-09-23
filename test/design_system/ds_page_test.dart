import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// flutter-067 — the page as a component, and the gutter's single owner.
///
/// Three separate places in this repo said the page gutter belonged to
/// `DSPage`, `DSFormPage` or `DSGutter` — `ui_probe`'s `ruleGutter` doc
/// comment, `ui_lint`'s catalog rule, and the `add-component` skill — while
/// the kit shipped none of the three and twenty-seven screens spelled the
/// gutter by hand. These tests are the part of that claim a machine can hold:
/// the page pads nothing, the section is what pads, and the page is what makes
/// the bottom of the screen add up.
void main() {
  late BuildContext ctx;

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    DSPageStyle? extension,
  }) async {
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: extension == null
              ? AppTheme.lightTheme
              : AppTheme.lightTheme.copyWith(extensions: [extension]),
          home: Builder(
            builder: (context) {
              ctx = context;
              return child;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the page', () {
    testWidgets('opens on the compact header by default', (tester) async {
      // Which header is still a decision — `header-earns-its-height` is the
      // rule that makes it — and the page does not re-litigate it. It picks
      // one per constructor, so the decision is visible at the call site.
      await pump(tester, const DSPage(title: 'Library', slivers: []));
      final header = tester.widget<DSPageHeader>(find.byType(DSPageHeader));
      expect(header.title, 'Library');
      expect(find.text('Library'), findsOneWidget);
    });

    testWidgets('and on the editorial one when asked', (tester) async {
      await pump(
        tester,
        const DSPage.headline(
          title: 'Designing for motion',
          eyebrow: 'CRAFT',
          subtitle: 'What a transition is actually for.',
          slivers: [],
        ),
      );
      final header = tester.widget<DSPageHeader>(find.byType(DSPageHeader));
      expect(header.eyebrow, 'CRAFT');
      expect(header.subtitle, 'What a transition is actually for.');
    });

    testWidgets('installs the bottom-inset host', (tester) async {
      // The defect this closes: ten screens carried a floating action button
      // or a pinned action bar with no host above them, so the bar could not
      // report its height, nothing cleared it, and `DSFab.hideOnScroll` read
      // a DSScrollRetreat that nothing published.
      await pump(tester, const DSPage(title: 'Library', slivers: []));
      expect(find.byType(DSBottomInsetsHost), findsOneWidget);
    });

    testWidgets('pads none of its slivers', (tester) async {
      // The page deliberately offers no padding parameter. A list and a card
      // want different things from the same number — the row insets its
      // content while its divider runs to the edge — and one EdgeInsets at
      // the page level cannot be both.
      await pump(
        tester,
        const DSPage(
          title: 'Library',
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: 40, key: Key('box'))),
          ],
        ),
      );
      expect(tester.getTopLeft(find.byKey(const Key('box'))).dx, 0);
    });

    testWidgets('ends the scroll clear of what is pinned under it', (
      tester,
    ) async {
      await pump(
        tester,
        DSPage(
          title: 'Checkout',
          footer: DSPinnedActionBar(
            children: [DSButton(label: 'Place order', onPressed: () {})],
          ),
          slivers: const [SliverToBoxAdapter(child: SizedBox(height: 40))],
        ),
      );
      // The bar has reported by now, so the trailing box is the bar's height
      // plus the page's own trailing gap rather than the gap alone.
      final barHeight = tester.getSize(find.byType(DSPinnedActionBar)).height;
      final trailing = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .where((b) => (b.height ?? 0) >= barHeight)
          .toList();
      expect(
        trailing,
        isNotEmpty,
        reason: 'the last sliver has to clear the bar the page is holding',
      );
    });

    testWidgets('a surface page has a header and no scroll of its own', (
      tester,
    ) async {
      // The body manages its own space — a map, a canvas. A CustomScrollView
      // around it would give it an unbounded height to fill.
      await pump(
        tester,
        const DSPage.surface(
          title: 'Route',
          child: ColoredBox(color: Color(0xFF112233)),
        ),
      );
      expect(find.byType(CustomScrollView), findsNothing);
      expect(find.text('Route'), findsOneWidget);
    });
  });

  group('the section is what applies the gutter', () {
    testWidgets('a section puts its child on the reading edge', (tester) async {
      await pump(
        tester,
        const DSPage(
          title: 'Library',
          slivers: [
            DSPageSection(child: SizedBox(height: 40, key: Key('box'))),
          ],
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('box'))).dx,
        ctx.design.space.pageGutter,
      );
    });

    testWidgets('and the first one opens on a smaller gap', (tester) async {
      // At the full section gap the page opens on a hole: the header above it
      // has already provided the break a gap provides between two sections.
      Future<double> topOf({required bool first}) async {
        await pump(
          tester,
          DSPage(
            title: 'Library',
            slivers: [
              DSPageSection(
                first: first,
                child: const SizedBox(height: 40, key: Key('box')),
              ),
            ],
          ),
        );
        return tester.getTopLeft(find.byKey(const Key('box'))).dy;
      }

      final firstTop = await topOf(first: true);
      final laterTop = await topOf(first: false);
      expect(firstTop, lessThan(laterTop));
      expect(
        laterTop - firstTop,
        moreOrLessEquals(
          ctx.design.space.xl - ctx.design.space.xs,
          epsilon: 0.5,
        ),
      );
    });

    testWidgets('a titled section labels its content', (tester) async {
      await pump(
        tester,
        const DSPage(
          title: 'Library',
          slivers: [
            DSPageSection(title: 'This week', child: SizedBox(height: 40)),
          ],
        ),
      );
      expect(find.byType(DSSectionHeader), findsOneWidget);
      expect(find.text('This week'), findsOneWidget);
    });

    testWidgets('a section header stands alone for a list', (tester) async {
      // A SliverList inside a DSPageSection would need a SliverToBoxAdapter,
      // which builds every row in one pass — so the label gets its own sliver
      // and the list stays lazy.
      await pump(
        tester,
        const DSPage(
          title: 'Library',
          slivers: [
            DSPageSectionHeader(title: 'Recent'),
            SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      );
      expect(
        tester.getTopLeft(find.byType(DSSectionHeader)).dx,
        ctx.design.space.pageGutter,
      );
    });

    testWidgets('the gutter on its own insets a box', (tester) async {
      await pump(
        tester,
        const Scaffold(
          body: DSGutter(child: SizedBox(height: 40, key: Key('box'))),
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('box'))).dx,
        ctx.design.space.pageGutter,
      );
    });

    testWidgets('and a sliver, without unwrapping it', (tester) async {
      await pump(
        tester,
        const DSPage(
          title: 'Library',
          slivers: [
            DSGutter.sliver(
              sliver: SliverToBoxAdapter(
                child: SizedBox(height: 40, key: Key('box')),
              ),
            ),
          ],
        ),
      );
      expect(find.byType(SliverPadding), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('box'))).dx,
        ctx.design.space.pageGutter,
      );
    });
  });

  group('the rhythm resolves through the chain', () {
    testWidgets('layer 1 is the spec', (tester) async {
      await pump(tester, const DSPage(title: 'Library', slivers: []));
      final resolved = DSPageStyle.resolve(ctx);
      expect(resolved.gutter, ctx.design.space.pageGutter);
      expect(resolved.sectionGap, ctx.design.space.xl);
      expect(resolved.firstSectionGap, ctx.design.space.xs);
    });

    testWidgets('layer 2 is a theme extension, and it moves every section', (
      tester,
    ) async {
      // The point of resolving the gutter rather than reading it straight
      // from the spec: one override widens the page, instead of an edit at
      // every section on it.
      await pump(
        tester,
        const DSPage(
          title: 'Library',
          slivers: [
            DSPageSection(child: SizedBox(height: 40, key: Key('box'))),
          ],
        ),
        extension: const DSPageStyle(gutter: 48),
      );
      expect(tester.getTopLeft(find.byKey(const Key('box'))).dx, 48);
    });

    testWidgets('layer 4 is the instance, and it wins', (tester) async {
      await pump(
        tester,
        const DSPage(
          title: 'Library',
          slivers: [
            DSPageSection(
              style: DSPageStyle(gutter: 64),
              child: SizedBox(height: 40, key: Key('box')),
            ),
          ],
        ),
        extension: const DSPageStyle(gutter: 48),
      );
      expect(tester.getTopLeft(find.byKey(const Key('box'))).dx, 64);
    });
  });
}
