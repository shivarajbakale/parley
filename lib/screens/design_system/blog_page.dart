import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/blog_data.dart';
import 'package:parley_android/screens/design_system/demo_photo.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:parley_android/utils/app_routes.dart';

/// The blog demo list — a Collection archetype
/// (`docs/principles/screen-archetypes.md`) applied to a single content
/// shape.
///
/// Lives in `screens/design_system/` because it is a demo: it proves that a
/// real-feeling screen — sectioned list, category-coloured media, chip-row
/// meta, tap-through navigation — can be built from `DS*` components
/// without ever opening `Theme.of(context)` for a colour or a number.
///
/// Delete this file, `blog_data.dart` and `blog_article_page.dart` with the
/// rest of the design-system demo surface when the app ships a real blog.
class BlogPage extends StatelessWidget {
  const BlogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = blogCategoriesWithArticles;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          DSLargeAppBar(
            // The page's headline is the page's headline. It used to live in
            // `_BlogIntro` directly under a bar that said "Blog", so the
            // screen opened on two titles and neither was the page's name.
            title: 'Rocketship Design Notes',
            titleMaxLines: 2,
            subtitle:
                '${demoBlogArticles.length} short essays on the kit behind '
                'this app.',
          ),
          for (final category in categories) ...[
            SliverToBoxAdapter(
              child: DSSectionHeader(
                label: category.label,
                // One count, not one per section. The list is short enough
                // that an overall total reads as a single inventory; per-
                // section counts read as a tally.
              ),
            ),
            SliverList.builder(
              itemCount: blogArticlesIn(category).length,
              itemBuilder: (context, index) {
                final article = blogArticlesIn(category)[index];
                return _BlogArticleTile(article: article);
              },
            ),
          ],
          SliverToBoxAdapter(
            // Clears the floating nav bar, same as every other in-app list.
            child: SizedBox(
              height:
                  context.design.space.xl +
                  MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }
}

/// One article as a row in the list. Pure presentational: the data is
/// passed in, the tap is the navigation, and nothing here knows where the
/// detail page lives.
class _BlogArticleTile extends StatelessWidget {
  const _BlogArticleTile({required this.article});

  final BlogArticle article;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final category = article.category;

    return DSMediaRow(
      source: DSMediaSource.widget(
        DemoPhoto(
          asset: article.heroImage,
          fallbackHue: article.heroHue,
          fallbackLabel: article.heroLabel,
        ),
        semanticLabel: '${article.heroLabel} illustration',
      ),
      title: article.title,
      subtitle: article.subtitle,
      // A headline is content, not a label. Two lines ellipsised "Designing
      // for motion: how we made transi…", which is a row the reader cannot
      // use — and the `clipped-text` probe rule fails it. Four is the row's
      // ceiling and the longest headline in the set needs all four on a
      // 320-point phone at the 1.3x text scale real people use.
      style: const DSMediaRowStyle(titleMaxLines: 4),
      meta: [
        DSMediaMeta(markColor: palette.muted, label: category.label),
        DSMediaMeta(
          icon: Icons.schedule,
          label: '${article.readingMinutes} min',
        ),
      ],
      onTap: () {
        AppHaptics.selection();
        context.push(AppRoutes.blogArticleAt(article.slug));
      },
    );
  }
}
