import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/screens/design_system/blog_data.dart';
import 'package:parley_android/screens/design_system/blog_page.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/utils/app_routes.dart';

/// The blog list page is the entry into the blog demo. These tests pin the
/// claims a reader makes about it:
///
///   * every shipped article renders, so the list is not silently dropping
///     entries — the catalog lives in `blog_data.dart` and the page is its
///     only renderer;
///   * each section header reads its name from the enum, so the page does
///     not have a separate string registry to drift against;
///   * tapping an article tile pushes the article route, not a different
///     one — the demo is reachable from the gallery, and a wrong route is a
///     wrong demo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: child),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  /// Scrolls the list until [finder] has something to match.
  ///
  /// A headline takes as many lines as it needs, so the rows are as tall as
  /// their titles and a five-article list is two screenfuls. `SliverList`
  /// builds lazily, so a title further down has not been built yet — which is
  /// a fact about the list, not about the page.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 20 && finder.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();
    }
  }

  group('the blog list', () {
    testWidgets('the page has exactly one headline', (tester) async {
      await pump(tester, const BlogPage());

      // The header carries the page's headline. The word "Blog" used to sit
      // above it in the bar, so the screen opened on two competing titles
      // and neither of them was the page's name.
      expect(find.text('Rocketship Design Notes'), findsOneWidget);
      expect(find.text('Blog'), findsNothing);
    });

    testWidgets('renders every shipped article', (tester) async {
      await pump(tester, const BlogPage());

      // Scrolled to, not asserted in place. `DSMediaRow` gives a headline
      // two lines by default and needs no override, and a five-article list
      // still does not fit on one screenful.
      for (final article in demoBlogArticles) {
        await scrollTo(tester, find.text(article.title));
        expect(
          find.text(article.title),
          findsOneWidget,
          reason: '${article.slug} did not render its title',
        );
      }
    });

    testWidgets('renders one section header per category that has articles', (
      tester,
    ) async {
      await pump(tester, const BlogPage());

      for (final category in blogCategoriesWithArticles) {
        await scrollTo(tester, find.text(category.label));
        expect(
          find.text(category.label),
          findsWidgets,
          reason: '${category.label} has no section header',
        );
      }
    });

    testWidgets('tapping an article pushes the article route', (tester) async {
      // The route is `/blog/article/:slug`, which the test asserts against
      // rather than `/blog` (the list) — the demo would be unreachable
      // without the article route, but a wrong route is a wrong demo.
      // Absolute paths mirror the production router, which mounts both
      // `/blog` and `/blog/article/:slug` at the root.
      final router = GoRouter(
        initialLocation: AppRoutes.blog,
        routes: [
          GoRoute(path: AppRoutes.blog, builder: (_, __) => const BlogPage()),
          GoRoute(
            path: '/blog/article/:slug',
            builder: (_, state) => Scaffold(
              body: Center(
                child: Text('article: ${state.pathParameters['slug']}'),
              ),
            ),
          ),
        ],
      );

      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final first = demoBlogArticles.first;
      await tester.tap(find.text(first.title));
      await tester.pumpAndSettle();

      expect(
        find.text('article: ${first.slug}'),
        findsOneWidget,
        reason: 'tapping the first article did not navigate to its slug',
      );
    });
  });

  // Smoke test: the page does not throw when mounted under the full theme
  // tree, the same way the gallery tests do for the catalog. This is the
  // check that catches a forgotten import before any of the targeted tests
  // above would.
  testWidgets('the page builds under the light theme without exception', (
    tester,
  ) async {
    await pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) {
            return const BlogPage();
          },
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}

// `_BlogArticleTile` and `_ArticleHero` are private to `blog_page.dart`.
// They are not tested directly: their behaviour is observable through the
// list test above (titles render, taps navigate), and testing private widgets
// is a refactor trap that pins the implementation rather than the contract.
//
// `DSMediaRow` (the row the tile wraps) has its own golden suite and the
// lint rule that catches a hand-rolled row, which together cover the visual
// surface area this demo would otherwise re-test.
