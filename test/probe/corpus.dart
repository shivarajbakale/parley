@Tags(<String>['probe'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/data/dashboard_repository.dart';
import 'package:parley_android/data/library_repository.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/models/dashboard_summary.dart';
import 'package:parley_android/models/library_item.dart';
import 'package:parley_android/providers/auth_provider.dart';
import 'package:parley_android/providers/settings_provider.dart';
import 'package:parley_android/screens/design_system/foundations_page.dart';
import 'package:parley_android/screens/design_system/blog_data.dart';
import 'package:parley_android/screens/design_system/catalog/catalog.dart';
import 'package:parley_android/screens/design_system/component_page.dart';
import 'package:parley_android/screens/design_system/demos_page.dart';
import 'package:parley_android/screens/design_system/gallery_page.dart';
import 'package:parley_android/services/auth/auth_models.dart';
import 'package:parley_android/services/auth/token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../_screens.dart';
import '_probe.dart';

/// What the probe walks.
///
/// Derived from `designSystemCatalog` rather than listed, so a component
/// joins the probe on the same commit it joins the kit — the gallery test
/// already fails a component with no stories, and this makes that page a
/// graded surface as well as a browsable one.
///
/// A surface with no page in the catalog is invisible here. That is the same
/// bargain the gallery makes, and it is one more reason a new component needs
/// stories.

/// The three items every screen surface is built against.
///
/// Fixed data rather than the mock backend: a measurement taken against a
/// network call, however faked, measures whatever the timing happened to be.
/// Three distinct categories, because the Library derives its filter strip
/// from the values present and fixtures that share one category would render a
/// strip the real screen never shows.
const List<LibraryItem> probeItems = <LibraryItem>[
  LibraryItem(
    id: '1',
    category: 'Design',
    title: 'Designing for the platform',
    subtitle: 'Six chapters · 42 min',
    detail:
        'What "native" means on each side, and what it costs to ignore it. '
        'The chapter the rest of the kit is built on.',
    iconName: 'star',
    minutes: 42,
    progress: 0.4,
  ),
  LibraryItem(
    id: '2',
    category: 'Guides',
    title: 'Depth without decoration',
    subtitle: 'Four chapters · 26 min',
    detail:
        'A surface ladder, an elevation contract, and the one layer that is '
        'allowed to float.',
    iconName: 'book',
    minutes: 26,
    progress: 1.0,
  ),
  LibraryItem(
    id: '3',
    category: 'Modules',
    title: 'Motion that means something',
    subtitle: 'Three chapters · 18 min',
    detail:
        'Springs where a gesture continues, curves where nothing was '
        'thrown.',
    iconName: 'bolt',
    minutes: 18,
    progress: 0,
  ),
];

const DashboardSummary probeSummary = DashboardSummary(
  itemCount: 3,
  categoryCount: 3,
  completedCount: 1,
  // Uneven on purpose: three equal bars prove nothing about a chart, and the
  // longest shelf name is what the category axis has to survive.
  itemsByCategory: {'Guides': 4, 'Reference': 1, 'Case studies': 3},
);

/// Every component page in the catalog, plus the gallery that indexes them.
///
/// The subject of a component page is its first live usage: everything above
/// that — the bar, the eyebrow, the summary, the note that is identical on all
/// fifty pages — is chrome, and defect 4 is what happens when chrome is
/// allowed to grow without anything measuring it.
List<ProbeSurface> catalogSurfaces() => <ProbeSurface>[
  ProbeSurface(
    name: 'catalog/gallery',
    // Inside a Scaffold, the way the app shell mounts it. The page is a body
    // rather than a screen — it has no Scaffold of its own — and its search
    // field needs the Material that one provides.
    build: () => const Scaffold(body: ComponentGalleryPage()),
    subject: find.byType(DSSearchBar),
    subjectDescription: 'the search field the gallery is navigated by',
  ),
  ProbeSurface(
    name: 'catalog/demos',
    // Same reason as the gallery above: a body rather than a screen, mounted
    // the way the app shell mounts it.
    build: () => const Scaffold(body: DemosPage()),
    subject: find.byType(DSListTile).first,
    subjectDescription: 'the first demo tile, Blog',
  ),
  ProbeSurface(
    name: 'catalog/foundations',
    build: () => const FoundationsPage(),
    subject: find.byType(DSSection).first,
    subjectDescription: 'the colour section, the first set of tokens',
  ),
  for (final DSComponentDemo component in catalogComponents)
    ProbeSurface(
      name: 'catalog/${component.name}',
      build: () => ComponentPage(name: component.name),
      subject: find.byType(DSSection).first,
      subjectDescription: 'the first live usage of ${component.name}',
    ),
];

/// The long-content fixtures.
///
/// Every fixture in this repository was three or four words long, so every
/// layout in it was only ever proved against content of that shape. A blog
/// shipped with the headline cut on every row, and no gate had ever handed a
/// screen a headline. These are the same items with the strings real content
/// has: a 60-character title, a subtitle that does not fit beside a
/// thumbnail, a 200-character quote.
const List<LibraryItem> probeItemsLong = <LibraryItem>[
  LibraryItem(
    id: '1',
    category: 'Design',
    title: 'Designing for the platform without designing it twice over',
    subtitle: 'Six chapters · 42 min · updated this morning by Ada Lovelace',
    detail:
        'What "native" means on each side, and what it costs to ignore it. '
        'The chapter the rest of the kit is built on.',
    iconName: 'star',
  ),
  LibraryItem(
    id: '2',
    category: 'Guides',
    title: 'Depth without decoration, and the one layer allowed to float',
    subtitle: 'Four chapters · 26 min · a surface ladder and its contract',
    detail:
        'A surface ladder, an elevation contract, and the one layer that is '
        'allowed to float.',
    iconName: 'book',
  ),
  LibraryItem(
    id: '3',
    category: 'Modules',
    title: 'Motion that means something rather than motion that means motion',
    subtitle: 'Three chapters · 18 min · springs, curves and when each one',
    detail:
        'Springs where a gesture continues, curves where nothing was thrown.',
    iconName: 'bolt',
  ),
];

/// The article the probe reads a blog page with, in both content shapes.
///
/// The long one is not invented copy: it is the shape an editorial CMS
/// produces on a bad day — a headline that wraps twice in a phone-width bar
/// and a pull quote of two sentences.
BlogArticle probeArticle({required bool long}) {
  final BlogArticle base = demoBlogArticles.first;
  if (!long) return base;
  return BlogArticle(
    slug: base.slug,
    title:
        'Colour tokens that survive a rebrand, a redesign and the designer '
        'who named them',
    subtitle: base.subtitle,
    author: 'Jules Andersen-Whitworth',
    category: base.category,
    readingMinutes: base.readingMinutes,
    heroLabel: 'Tokens, roles and the names in between',
    heroHue: base.heroHue,
    heroImage: base.heroImage,
    publishedOn: base.publishedOn,
    paragraphs: base.paragraphs,
    pullQuote:
        'A token named after the colour it happens to be today is a token '
        'that has to be re-approved every six months, and a system that has '
        'to be re-approved every six months is not a system at all.',
  );
}

/// The content shapes every content-driven screen is walked in.
enum ProbeContent {
  ordinary,
  long;

  String get suffix => this == ProbeContent.long ? '@long' : '';
}

/// The demo screens by name, so the walk can make one test per screen without
/// building the list before `setUp` has run.
///
/// Derived from `test/_screens.dart` rather than typed here. The five names
/// that used to live in this file had no relationship to the screens the app
/// has, which is how two blog screens shipped that no gate ever mounted.
final List<String> screenSurfaceNames = <String>[
  for (final AppScreen screen in appScreens)
    for (final ProbeContent content in ProbeContent.values)
      if (content == ProbeContent.ordinary || screen.contentDriven)
        'screen/${screen.name}${content.suffix}',
];

/// What each screen exists to show, for the `fold` rule. Keyed by the
/// registry's name, so a screen added to the registry with no subject is
/// still walked — it simply is not graded on the fold.
final Map<String, (Finder, String)> _subjects = <String, (Finder, String)>{
  'dashboard': (
    find.byType(DSCard).first,
    'the hero card the dashboard opens on',
  ),
  'library': (find.byType(DSListTile).first, 'the first item in the library'),
  'settings': (
    find.byType(DSSettingsRow).first,
    'the first setting on the page',
  ),
  'detail': (
    find.byType(DSWell).first,
    'the artwork the item is introduced by',
  ),
  'login': (find.byType(DSTextField).first, 'the first field of the form'),
  'blog': (find.byType(DSMediaRow).first, 'the first article in the list'),
  'browse': (
    find.byType(DSMediaHero).first,
    'the featured item the shelf leads with',
  ),
  'order_placed': (
    find.byType(DSMessage).first,
    'the outcome the confirmation is about',
  ),
  'blog_article': (find.byType(DSCard).first, "the article's hero"),
  // The ground, because at the peek detent that is what the screen is: the
  // sheet is a caption on it. At `full` the sheet is what is being read, so
  // that surface's subject is its first row.
  'place': (find.byType(InteractiveViewer), 'the ground the pins are on'),
  'place_full': (
    find.byType(DSListTile).first,
    'what the sheet says about the pin, with the sheet at full',
  ),

  'tour_1': (find.byType(DSTourSlide), 'the stop the tour opens on'),
  'tour_2': (find.byType(DSTourSlide), 'the second stop'),
  'tour_3': (find.byType(DSTourSlide), 'the last stop, the one that commits'),
};

/// The demo screens, which is where the chrome, the content and the page
/// gutter actually meet.
List<ProbeSurface> screenSurfaces(SharedPreferences prefs) {
  Widget scope(Widget child, List<LibraryItem> items) => ProviderScope(
    overrides: <Override>[
      sharedPreferencesProvider.overrideWithValue(prefs),
      tokenStoreProvider.overrideWithValue(
        InMemoryTokenStore(
          const AuthSession(
            user: AuthUser(
              id: 'usr_probe',
              email: 'ada@rocketship.dev',
              displayName: 'Ada Lovelace',
            ),
            accessToken: 'probe',
          ),
        ),
      ),
      libraryItemsProvider.overrideWith((Ref ref) => items),
      dashboardSummaryProvider.overrideWith((Ref ref) => probeSummary),
    ],
    child: child,
  );

  return <ProbeSurface>[
    for (final AppScreen screen in appScreens)
      for (final ProbeContent content in ProbeContent.values)
        if (content == ProbeContent.ordinary || screen.contentDriven)
          () {
            final bool long = content == ProbeContent.long;
            final List<LibraryItem> items = long ? probeItemsLong : probeItems;
            final ScreenFixture fixture = ScreenFixture(
              items: items,
              article: probeArticle(long: long),
            );
            final (Finder, String)? subject = _subjects[screen.name];
            return ProbeSurface(
              name: 'screen/${screen.name}${content.suffix}',
              build: () => screen.build(fixture),
              scope: (Widget child) => scope(child, items),
              subject: subject?.$1,
              subjectDescription: subject?.$2,
            );
          }(),
  ];
}
