import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/blog_article_page.dart';
import 'package:parley_android/screens/design_system/blog_data.dart';
import 'package:parley_android/theme/app_theme.dart';

/// The article page is the second half of the blog demo: the list proves the
/// cards, this page proves the reading view. The contracts these tests pin:
///
///   * the title, author, paragraphs, and pull-quote all render, so the
///     page is not silently dropping the data it was given;
///   * the action bar's like / save buttons flip state visibly, so a reader
///     knows the press registered;
///   * every shipped article renders without throwing under the light
///     theme, which is the same smoke test the gallery runs for the
///     catalog.
///
/// What is *not* tested here: the visual layout. The kit's own goldens cover
/// `DSCard`, `DSLargeAppBar`, `DSPinnedActionBar` and the rest of the
/// components the page composes; the article page does not introduce any
/// shape that needs a new baseline.
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

  // The first article is the one the page is wired to by the list's tap,
  // so most tests below pin behaviour against it. Tests that have to vary
  // the article (`every shipped article renders`) iterate the catalog.
  // A local variable rather than a getter: Dart does not allow local getters
  // inside a function body, and a top-level one would shadow the import.
  final BlogArticle firstArticle = demoBlogArticles.first;

  group('the article page', () {
    testWidgets('renders the title, author, paragraphs and pull-quote', (
      tester,
    ) async {
      final article = firstArticle;
      await pump(tester, BlogArticlePage(article: article));

      expect(find.text(article.title), findsOneWidget);
      expect(find.text(article.author), findsOneWidget);
      for (final paragraph in article.paragraphs) {
        expect(find.text(paragraph), findsOneWidget);
      }
      expect(find.text(article.pullQuote), findsOneWidget);
    });

    testWidgets('the header is compact and names the section', (tester) async {
      final article = firstArticle;
      await pump(tester, BlogArticlePage(article: article));

      // The bar holds the category and nothing else, so it takes the compact
      // form: an expanded bar would set an editorial headline at a display
      // size in a phone-width box and ellipsise it, and the headline is the
      // one thing on this screen that may not be cut.
      expect(find.byType(DSCompactAppBar), findsOneWidget);
      expect(find.byType(DSLargeAppBar), findsNothing);
      expect(find.text(article.title), findsOneWidget);
    });

    testWidgets('renders the category eyebrow on the app bar', (tester) async {
      final article = firstArticle;
      await pump(tester, BlogArticlePage(article: article));

      // The category label is folded into the app bar's eyebrow — the same
      // slot the gallery uses for a category badge. The test asserts the
      // text is on screen at least once; the position is the app bar's
      // responsibility, and its own tests cover it.
      expect(find.text(article.category.label), findsWidgets);
    });

    testWidgets('the action bar\'s like button toggles its icon', (
      tester,
    ) async {
      final article = firstArticle;
      await pump(tester, BlogArticlePage(article: article));

      // Start unliked.
      expect(find.byIcon(Icons.favorite_outline), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);

      // Tap the button rather than the icon: the icon is wrapped in
      // `ExcludeSemantics` and a press-aware `InkWell`, and `find.byIcon`
      // hits the inner widget without the gesture plumbing.
      await tester.tap(find.byType(DSIconButton).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.favorite_outline), findsNothing);
    });

    testWidgets('the action bar\'s save button toggles its icon', (
      tester,
    ) async {
      final article = firstArticle;
      await pump(tester, BlogArticlePage(article: article));

      expect(find.byIcon(Icons.bookmark_outline), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsNothing);

      // The action bar lays out three buttons in source order. Save is the
      // second one — like, save, share.
      await tester.tap(find.byType(DSIconButton).at(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_outline), findsNothing);
    });

    testWidgets('tapping share surfaces a snack bar', (tester) async {
      final article = firstArticle;
      await pump(tester, BlogArticlePage(article: article));

      // Share is the third button in the action bar (like, save, share).
      // Tapping the button itself, not the icon, because the icon is wrapped
      // and `find.byIcon` does not always hit the InkWell.
      await tester.tap(find.byType(DSIconButton).at(2));
      // The snack bar is mounted in an Overlay, which is created on the
      // next frame. Two pumps covers both the snack bar's enter animation
      // and the Overlay's first frame.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DSSnackBar), findsOneWidget);
    });

    testWidgets('every shipped article renders under the light theme', (
      tester,
    ) async {
      // The smoke test the gallery uses for the catalog: mount every entry
      // and assert that none of them throws. This catches the case where
      // one article's copy or date is malformed in a way that only this
      // page's rendering would surface.
      for (final article in demoBlogArticles) {
        await pump(tester, BlogArticlePage(article: article));
        expect(
          tester.takeException(),
          isNull,
          reason: '${article.slug} threw under the light theme',
        );
      }
    });
  });
}
