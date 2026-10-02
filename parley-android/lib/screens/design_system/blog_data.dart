import 'package:flutter/material.dart';
import 'package:parley_android/screens/design_system/demo_photo.dart';

/// The category a blog article sits under — used as both the section label on
/// the list page and the chip in each card's `meta` row.
///
/// An enum, not a `String`, because the list page renders one section per
/// distinct value. A string would force the page to compute that itself;
/// this way the enum is the single source of truth, and adding a category
/// adds a section header for free.
enum BlogCategory {
  engineering(label: 'Engineering', icon: Icons.terminal_outlined, hue: 1),
  design(label: 'Design', icon: Icons.palette_outlined, hue: 2),
  product(label: 'Product', icon: Icons.rocket_launch_outlined, hue: 0);

  const BlogCategory({
    required this.label,
    required this.icon,
    required this.hue,
  });

  final String label;
  final IconData icon;

  /// A category index. It no longer picks a colour (the palette has no
  /// category ramp); kept so demo data stays stable. The list page
  /// uses this to colour the chip dot and the hero swatch on the article
  /// page — both read the same identity, so the colour that names a
  /// category is the colour that paints it.
  final int hue;
}

/// One demo blog article. Hand-written rather than freezed on purpose: this
/// file is demo content, and a generator would not survive a reader editing
/// the copy in place.
///
/// Not a `const` constructor: `DateTime` is a runtime value in this Dart
/// version, and a `const` constructor that took a `DateTime` would refuse
/// to compile. The list below is `final` for the same reason. Suppressing
/// `prefer_const_constructors_in_immutables` is the documented escape
/// hatch for exactly this case.
@immutable
class BlogArticle {
  // ignore: prefer_const_constructors_in_immutables
  BlogArticle({
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.author,
    required this.category,
    required this.readingMinutes,
    required this.publishedOn,
    required this.heroHue,
    required this.heroLabel,
    required this.heroImage,
    required this.paragraphs,
    required this.pullQuote,
  });

  /// The route segment. Lower-kebab, deep-link safe; the article route
  /// resolves slug → entry by lookup, so an unknown slug renders an empty
  /// state rather than a blank screen.
  final String slug;

  final String title;
  final String subtitle;

  /// The author's display name. The article page renders it beside the
  /// avatar and folds it into the card's accessible name.
  final String author;
  final BlogCategory category;

  /// Whole minutes. The meta chip renders it as `"4 min"`; a single source
  /// keeps the chip and any future "X min read" badge in sync.
  final int readingMinutes;

  /// When the article was published. Shown on the article page only — the
  /// list card has too little room for both author and date without losing
  /// the scan.
  final DateTime publishedOn;

  /// Demo index for the hero swatch. It no longer picks a colour: the
  /// fallback fill is `palette.muted`. Decoupled from `category.hue` so an article can pick a
  /// category-unrelated hue when the category colour would compete with the
  /// title.
  final int heroHue;

  /// A short word rendered on the hero swatch — the fallback the photograph
  /// leaves behind if [heroImage] is missing, so a coloured box never sits on
  /// the page without a label to read. It is never drawn over the photograph
  /// itself; the article's own title is right beside it.
  final String heroLabel;

  /// The article's photograph, as a bundled asset path from [DemoPhotos].
  ///
  /// One image serves both surfaces — cropped square in the list row, 16:9 on
  /// the article page — because a reader who taps a row expects to arrive at
  /// the picture they tapped.
  final String heroImage;

  /// The body copy, already broken into paragraphs. Three to four, by hand,
  /// so the article reads like a real post rather than a wireframe.
  final List<String> paragraphs;

  /// A line pulled out as a callout. Rendered in its own [DSCard] (filled
  /// variant) so it reads as a distinct voice from the body paragraphs.
  final String pullQuote;
}

/// Every demo article in the catalog, in the order they appear on the list
/// page. The order is deliberate: most recent first by category, so the
/// sections read in a sensible rhythm without sorting at build time.
///
/// Add an article here and it appears in the list, on the route, and in any
/// test that asserts on the full set — there is no other registry.
final demoBlogArticles = <BlogArticle>[
  BlogArticle(
    slug: 'color-tokens-rebrand',
    title: 'Color tokens that survive a rebrand',
    subtitle:
        'Naming colours by what they mean, not what they look like, is the '
        'only thing that scales.',
    author: 'Jules Andersen',
    category: BlogCategory.engineering,
    readingMinutes: 7,
    publishedOn: _aug28_2026,
    heroHue: 1,
    heroLabel: 'Tokens',
    heroImage: DemoPhotos.paletteWall,
    paragraphs: const [
      'The first colour palette we shipped had forty-seven tokens, all named '
          'after the colours they described — brand-blue-500, accent-coral, '
          'neutral-warm-grey-700. It was a perfectly reasonable palette, and '
          'it lasted eleven months.',
      'The rebrands came twice a year. Each one touched a different subset of '
          'tokens, and each subset had drifted from the others — the "warm grey" '
          'in the navigation was not the same warm grey as the one in the '
          'settings sheet, because neither had been touched since the design '
          'system had a name.',
      'The new palette has seventeen tokens. None of them are colours. They '
          'are roles — surface, surface-raised, accent, on-accent, '
          'text-primary, text-secondary, outline-soft, outline-strong, '
          'and so on. Each role is a contract: it is what the screen needs to '
          'do, not what it looks like.',
      'A rebrand is now a one-line change to a single map. The screens do '
          'not know they have been rebranded, which is the only correct outcome '
          'for a system that survived its second rebrand in twelve months.',
    ],
    pullQuote:
        'A token called brand-blue-500 is a token that needs to be '
        're-approved every six months.',
  ),
  BlogArticle(
    slug: 'designing-for-motion',
    title: 'Designing for motion: how we made transitions feel native',
    subtitle: 'Why a 120ms shared-axis slide beat every easing curve we tried.',
    author: 'Ada Quintero',
    category: BlogCategory.engineering,
    readingMinutes: 6,
    publishedOn: _aug21_2026,
    heroHue: 1,
    heroLabel: 'Motion',
    heroImage: DemoPhotos.crossing,
    paragraphs: const [
      'We tried five transition curves before we shipped one. The first four '
          'were technically correct — they eased in, they eased out, they had '
          'plausible durations between 180 and 240 milliseconds. They also felt, '
          'in a way none of us could name at first, wrong.',
      'The problem was not the curves themselves. It was that the curve and '
          'the gesture were two different stories: the curve said "this page is '
          'arriving", and the gesture said "I am pushing this page away". A '
          'screen-reader user heard one; a sighted user felt the other; the two '
          'never lined up.',
      'The transition that finally shipped is a shared-axis slide on X — the '
          'incoming page comes in from the trailing edge, the outgoing page '
          'drifts the other way, and both fade through the same interval. '
          'Crucially, the slide is a fraction of the page width, not a number '
          'of points: a 30-point slide on a 390-point phone reads as a twitch; '
          'a 7.5% slide on any width reads as a step.',
      '120 milliseconds is the duration. It is shorter than it sounds, and '
          'shorter than every curve that came before it. The shorter transition '
          'works because the fade does the work the slide used to do: the slide '
          'now only has to commit to the destination, not cross the distance '
          'between them.',
    ],
    pullQuote:
        'A transition is the only moment the app is both what it was and '
        'what it is becoming.',
  ),
  BlogArticle(
    slug: 'typography-drives-type-system',
    title: 'Why typography drives our type system',
    subtitle:
        'The five roles that decided everything else, from spacing to chrome.',
    author: 'Mira Okafor',
    category: BlogCategory.design,
    readingMinutes: 5,
    publishedOn: _aug14_2026,
    heroHue: 2,
    heroLabel: 'Type',
    heroImage: DemoPhotos.openBook,
    paragraphs: const [
      'There are five type roles in the system: display, title, body, label, '
          'and code. That is the entire vocabulary. Every text style on every '
          'screen in the kit maps to one of them, and the mapping is the only '
          'thing the design system has to defend.',
      'The reason there are five and not four, and not six, is that a type '
          'system with too few roles forces copy to take positions it did not '
          'ask for — a body paragraph ends up styled as a label because there '
          'is no body. A system with too many roles forces a reader to '
          'distinguish between roles that read identically on screen — title '
          'and heading are the same letterforms with different names, and the '
          'distinction only matters in source.',
      'Spacing, colour, and chrome all fell out of those five roles once '
          'they were settled. A body paragraph has the line-height it needs '
          'because that is what a body paragraph is for. A label has the '
          'tracking it needs because that is what a label is for. None of these '
          'are independently chosen — they are downstream of the role.',
      'The hardest call was whether "caption" is its own role. It is not. '
          'Captions are labels with a smaller scale, and the only thing the '
          'role added was a second name for the same letterform.',
    ],
    pullQuote:
        'Type is the only design choice the user reads on every screen, so '
        "it's the only one we cannot afford to vary.",
  ),
  BlogArticle(
    slug: 'one-card-per-screen',
    title: 'The case for one card per screen',
    subtitle:
        'Mixing elevated, filled, and outlined cards is mixing three systems.',
    author: 'Ravi Mehta',
    category: BlogCategory.design,
    readingMinutes: 4,
    publishedOn: _aug7_2026,
    heroHue: 2,
    heroLabel: 'Cards',
    heroImage: DemoPhotos.flatLay,
    paragraphs: const [
      'There are three card variants in the kit: elevated, filled, and '
          'outlined. They are not interchangeable. They are three different '
          'decisions about what the card is sitting on, and mixing them on one '
          'screen is not a design choice — it is three design choices that '
          'each disagree with the other two.',
      'An elevated card sits on top of a flat page. It is the default, and '
          'it is what a screen uses when it does not have a reason to choose '
          'otherwise. A filled card is recessed into a tonal group, the way a '
          'button sits in a toolbar. An outlined card is a hairline division, '
          'nothing more.',
      'The screens that mixed them were always screens with two ideas: '
          'the elevated card was the "primary" content and the filled card was '
          'the "supporting" content. The fix was never to pick a different '
          'card. It was to put the supporting content on a separate surface '
          'and stop asking one screen to do two jobs.',
      'The lint rule catches the case where a single screen declares all '
          'three variants. It is a small rule, and it is the rule that has '
          'prevented the most regressions in the last six months.',
    ],
    pullQuote:
        'Three weights of card on one screen is not a hierarchy — it is a '
        'list wearing three costumes.',
  ),
  BlogArticle(
    slug: 'boilerplate-to-product',
    title: 'From boilerplate to product in twelve minutes',
    subtitle: 'What the scaffolder leaves behind, and what it leaves to you.',
    author: 'Lin Park',
    category: BlogCategory.product,
    readingMinutes: 3,
    publishedOn: _jul31_2026,
    heroHue: 0,
    heroLabel: 'Ship',
    heroImage: DemoPhotos.explodedView,
    paragraphs: const [
      'The scaffolder runs for about twelve minutes on a clean machine. '
          'Three of those minutes are the dependencies. The rest is the app '
          'itself: pub get, the build runner, the first cold build. After '
          'that, the app is running on the simulator, and you have not written '
          'a line.',
      'What it leaves behind is the design system, the navigation shell, '
          'the auth gating, the paywall route, and the four destinations that '
          'every generated app starts with. What it leaves to you is the third '
          'tab — the Components tab is explicitly framed as a demo surface the '
          'reader is expected to delete once they ship their own third '
          'destination.',
      'The first hour is boring on purpose. There are no decisions to '
          'make, no defaults to second-guess, no chrome to redesign. The '
          'interesting part is what comes after: which feature is the third '
          'tab, what its archetype is, and how it composes with the two '
          'destinations the scaffolder already shipped.',
      'A scaffolder that demands an opinion in the first hour is a '
          'scaffolder that punishes the people who most needed the boring part.',
    ],
    pullQuote:
        "A scaffolder's job is to make the first hour boring, so the next "
        'hundred hours can be interesting.',
  ),
];

/// Resolves a route slug to its article, or null when the slug names an
/// article the demo does not ship. The article page routes the null case to
/// an empty state rather than a blank screen, so a typo'd deep link fails
/// gracefully.
BlogArticle? blogArticleBySlug(String slug) {
  for (final article in demoBlogArticles) {
    if (article.slug == slug) return article;
  }
  return null;
}

/// All articles in `category`, in list order. Used by the blog list page to
/// render one section per distinct category.
List<BlogArticle> blogArticlesIn(BlogCategory category) {
  return [
    for (final article in demoBlogArticles)
      if (article.category == category) article,
  ];
}

/// Every distinct category that has at least one article, in enum order. The
/// blog list page iterates this rather than `BlogCategory.values`, so a
/// category without an article does not render an empty section header.
List<BlogCategory> get blogCategoriesWithArticles => [
  for (final category in BlogCategory.values)
    if (blogArticlesIn(category).isNotEmpty) category,
];

// ----- date helpers -------------------------------------------------------
//
// `DateTime.utc` is a runtime constructor in this Dart version, so the
// article's `publishedOn` field is a runtime value and the BlogArticle
// constructor cannot itself be const. These named finals are the only
// thing keeping the call sites above from being a sea of
// `DateTime.utc(2026, 8, 21)`.

final _jul31_2026 = DateTime.utc(2026, 7, 31);
final _aug7_2026 = DateTime.utc(2026, 8, 7);
final _aug14_2026 = DateTime.utc(2026, 8, 14);
final _aug21_2026 = DateTime.utc(2026, 8, 21);
final _aug28_2026 = DateTime.utc(2026, 8, 28);
