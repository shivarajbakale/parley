import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/blog_data.dart';
import 'package:parley_android/screens/design_system/demo_photo.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// One demo blog article, rendered as a reading view.
///
/// Lives next to `blog_page.dart` in `screens/design_system/` because both
/// files are part of the same demo: the list page proves the cards, this
/// page proves the article. A reader who deletes one should delete both.
///
/// What the page composes, in the order it composes it:
///
///   * a large collapsing [DSLargeAppBar] carrying the *category*, because a
///     headline set at display size in a phone-width bar is ellipsised before
///     it is read;
///   * the headline itself, in the content, where it wraps;
///   * a hero [DSCard] whose media is the same photograph the list
///     page uses for the article row — the colour that names the category
///     is the colour that frames the reading view;
///   * body paragraphs that read `theme.textTheme.bodyLarge` without a
///     colour override — the colour is the role's;
///   * a [DSPullQuote] carrying the sentence the piece turns on;
///   * an author row: an [DSAvatar] from the author's name and a timestamp;
///   * a [DSPinnedActionBar] with three [DSIconButton]s — share, save, like
///     — so the reading view has the pinned chrome it would have on a real
///     blog.
///
/// The body paragraphs are deliberately not given their own component: they
/// are paragraphs of text, and wrapping them would add a name without adding
/// behaviour. The quote is the opposite case and was got wrong here first —
/// a hand-rolled row with a 48-point accent bar beside a three-line quote, so
/// the rule stopped a third of the way down. Anything with a layout rule of
/// its own belongs in the kit, and [DSPullQuote] is where that one lives.
class BlogArticlePage extends StatefulWidget {
  const BlogArticlePage({required this.article, super.key});

  final BlogArticle article;

  @override
  State<BlogArticlePage> createState() => _BlogArticlePageState();
}

class _BlogArticlePageState extends State<BlogArticlePage> {
  /// Local toggles for the like / save buttons. Stateful so the press has a
  /// visible consequence; the action bar is the place the user notices the
  /// state change.
  bool _saved = false;
  bool _liked = false;

  void _toggleSaved() {
    AppHaptics.medium();
    setState(() => _saved = !_saved);
  }

  void _toggleLiked() {
    AppHaptics.medium();
    setState(() => _liked = !_liked);
  }

  void _share() {
    AppHaptics.light();
    showDSSnackBar(
      context,
      message: 'Share link copied to clipboard.',
      tone: DSTone.success,
      icon: Icons.link,
    );
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final theme = Theme.of(context);
    final palette = context.palette;
    final space = context.design.space;
    // The bar this screen pins reports its own height here, so a snack bar
    // does not land on it and the button does not sit on its primary control.
    // Without the host each of the three floats independently and none of them
    // knows the others exist; `DSFab.hideOnScroll` reads a DSScrollRetreat
    // that nothing publishes.

    return DSBottomInsetsHost(
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            // The bar names the section, not the article, and it is compact.
            // A large-title bar sets its title at a display size in a box the
            // width of a phone, so an editorial headline in it is ellipsised at
            // 320 points — the probe reads a four-line CMS headline as cut
            // content — and growing the bar until one fits pushes the article
            // under the fold. The headline is content, so it is in the content,
            // where it wraps as far as it needs to; and the bar, holding one
            // word, is the compact form `header-earns-its-height` asks for.
            DSPageHeader.compactSliver(title: article.category.label),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  DSGutter.of(context),
                  space.sm,
                  DSGutter.of(context),
                  space.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: context.design.type.emphasisWeight,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: space.md),
                    _HeroCard(article: article),
                    SizedBox(height: space.lg),
                    _MetaRow(article: article),
                    SizedBox(height: space.lg),
                    for (var i = 0; i < article.paragraphs.length; i++) ...[
                      Text(
                        article.paragraphs[i],
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.55,
                        ),
                      ),
                      // One blank line between paragraphs. Two would be a
                      // section break, and there are no section breaks in a
                      // five-paragraph demo article.
                      if (i < article.paragraphs.length - 1)
                        SizedBox(height: space.md),
                    ],
                    SizedBox(height: space.lg),
                    DSPullQuote(
                      quote: article.pullQuote,
                      attribution: article.author,
                      accentColor: palette.primary,
                    ),
                    SizedBox(height: space.lg),
                    _AuthorRow(article: article),
                    SizedBox(height: space.xl),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: DSPinnedActionBar(
          children: [
            DSIconButton(
              icon: _liked ? Icons.favorite : Icons.favorite_outline,
              selectedIcon: Icons.favorite,
              selected: _liked,
              semanticLabel: _liked ? 'Unlike article' : 'Like article',
              onPressed: _toggleLiked,
            ),
            DSIconButton(
              icon: _saved ? Icons.bookmark : Icons.bookmark_outline,
              selectedIcon: Icons.bookmark,
              selected: _saved,
              semanticLabel: _saved ? 'Remove from saved' : 'Save article',
              onPressed: _toggleSaved,
            ),
            DSIconButton(
              icon: Icons.share_outlined,
              semanticLabel: 'Share article',
              onPressed: _share,
            ),
          ],
        ),
      ),
    );
  }
}

/// The hero — a [DSCard] whose media is the article's photograph.
///
/// The word the swatch used to carry is now the swatch's own fallback and
/// nothing else. Set over a photograph it had no contrast ratio anything
/// could guarantee, and it repeated a headline that is already two lines
/// below it.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.article});

  final BlogArticle article;

  @override
  Widget build(BuildContext context) => DSCard(
    media: DSCardMedia(
      aspectRatio: 16 / 9,
      child: DemoPhoto(
        asset: article.heroImage,
        fallbackHue: article.heroHue,
        fallbackLabel: article.heroLabel,
      ),
    ),
  );
}

/// The byline row: category dot, reading time, publication date. One row,
/// not three, because the same three facts on three rows is metadata, and
/// metadata wants to be scannable.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.article});

  final BlogArticle article;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Wrap(
      spacing: context.design.space.md,
      runSpacing: context.design.space.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DSChip(
          label: article.category.label,
          markColor: palette.mutedForeground,
        ),
        Text(
          '${article.readingMinutes} min read',
          style: theme.textTheme.labelMedium?.copyWith(
            color: palette.mutedForeground,
          ),
        ),
        // The separator is text, and text is graded as text: at `textTertiary`
        // it rendered 3.82:1 on the card, which is the floor for a graphical
        // object and not for a character. It reads as a dot either way, so it
        // takes the colour of the facts it separates.
        Text(
          '·',
          style: theme.textTheme.labelMedium?.copyWith(
            color: palette.mutedForeground,
          ),
        ),
        Text(
          _formatPublishedOn(article.publishedOn),
          style: theme.textTheme.labelMedium?.copyWith(
            color: palette.mutedForeground,
          ),
        ),
      ],
    );
  }
}

/// The author row, anchored to the bottom of the article. Avatar + name +
/// role; the same shape a reader expects on a blog footer.
class _AuthorRow extends StatelessWidget {
  const _AuthorRow({required this.article});

  final BlogArticle article;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Row(
      children: [
        DSAvatar.fromName(name: article.author, size: DSAvatarSize.md),
        SizedBox(width: context.design.space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(article.author, style: theme.textTheme.titleSmall),
              Text(
                'Author',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ----- helpers ------------------------------------------------------------

/// The article's publication date, written the way a blog footer writes it:
/// "Aug 21, 2026". UTC dates avoid the timezone drift that `DateTime.now()`
/// would introduce if the demo ever ran on a build farm in another region.
String _formatPublishedOn(DateTime when) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[when.month - 1]} ${when.day}, ${when.year}';
}
