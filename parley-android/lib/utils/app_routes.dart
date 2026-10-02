/// Every route path in one place, so the whole navigation surface is
/// greppable from a single file. The router that wires these to screens lives
/// in [app_router.dart]; navigate with `context.go(...)` / `context.push(...)`.
///
/// Add a feature route here, then register it in `app_router.dart`.
abstract final class AppRoutes {
  AppRoutes._();

  // Boot + auth (public — reachable while signed out)
  static const splash = '/splash';

  /// First-run welcome screen. Shown on cold launch until the user has
  /// *been introduced* to the app (`welcomeSeen`). Distinct from
  /// [onboarding], which is the *orientation* tour that runs after.
  static const welcome = '/welcome';

  /// First-run onboarding carousel. Shown until onboarding is complete.
  static const onboarding = '/onboarding';

  static const login = '/login';
  static const signup = '/signup';
  static const forgot = '/forgot';

  /// Password-reset landing for the email deep link: `/reset?token=…`.
  static const reset = '/reset';

  // Parley
  static const home = '/';

  /// First-run sequence: keys, microphone, accessibility, battery, practice.
  /// `?again=1` is Settings' "Run setup again", which the router lets through
  /// after setup is complete.
  static const setup = '/setup';

  /// One history entry. `:id` is the native store's row id.
  static const historyEntry = '/history';
  static String historyEntryAt(int id) => '/history/$id';

  /// Choose Groq or Deepgram for transcription; replace or remove the keys.
  static const apiKeys = '/settings/keys';

  /// Subscription paywall. Deep-linkable; pushed as a full-screen dialog.
  static const paywall = '/paywall';

  static const appearance = '/settings/appearance';
  static const about = '/settings/about';

  /// Open-source acknowledgements, grouped by package. [licenseDetail] is
  /// reached only from a row here, with the tapped [PackageLicense] carried
  /// as the route's `extra` — its text is already in memory from the list
  /// screen's own load, so the detail route has nothing of its own to fetch.
  static const licenses = '/settings/licenses';
  static const licenseDetail = '/settings/licenses/detail';

  /// Library item detail. `:index` indexes into `demoLibraryItems`, so the
  /// route is deep-link safe without serialising the item.
  static const libraryDetail = '/library/detail';

  /// Builds the concrete path for [libraryDetail] at [index].
  static String libraryDetailAt(int index) => '/library/detail/$index';

  /// One design-system component's stories. `:name` is the class name, so the
  /// route is deep-linkable and greppable: `/components/DSButton`.
  static const component = '/components';

  /// Builds the concrete path for [component] named [name].
  static String componentAt(String name) => '/components/$name';

  /// The design tokens drawn as a designer's reference: colour pairs,
  /// elevation, corners and strokes, the type scale and spacing.
  static const foundations = '/foundations';

  /// The demo blog list. Lives in the Demos tab as another demo of how the
  /// kit composes; the comment on [BlogPage] explains the
  /// delete-with-the-rest-of-`screens/design_system` contract.
  static const blog = '/blog';

  /// One demo blog article. `:slug` indexes into `demoBlogArticles`, so the
  /// route is deep-link safe without serialising the article.
  static const blogArticle = '/blog/article';

  /// Builds the concrete path for [blogArticle] at [slug].
  static String blogArticleAt(String slug) => '/blog/article/$slug';

  /// The demo inbox. Pushed from the Demos tab's second tile to show the
  /// two tab-bar components ([DSTabBar] and [DSSegmentedButton])
  /// solving different problems on the same screen.
  static const inbox = '/inbox';

  /// The demo booking form. Pushed from the Demos tab's third tile to show
  /// the Form archetype end to end — six kinds of input, a
  /// validation pass, a submit in flight and the state after it succeeds.
  static const form = '/form';

  /// The demo reading recap. Pushed from the Demos tab's fifth tile to show
  /// the Insight archetype end to end — one figure with
  /// its comparison, one plot, one written sentence about what they mean, a
  /// ranked breakdown, and nothing pinned.
  static const insight = '/insight';

  /// The demo browse screen. Pushed from the Demos tab to show the Shelf
  /// archetype end to end — one hero, then rails whose titles say why they
  /// are there, each tile a `DSMediaTile` and each rail cut at the frame so
  /// the next one peeks.
  static const browse = '/browse';

  /// The demo order confirmation. Pushed from the Demos tab to show the
  /// Confirmation archetype — what happened, a selectable identifier, the
  /// receipt, and a dated next step.
  static const orderPlaced = '/order-placed';

  /// The demo map. Pushed from the Demos tab to show the Canvas archetype —
  /// a ground that stays interactive under a sheet with three named detents.
  static const place = '/place';

  /// The demo profile. Pushed from the Demos tab's sixth tile to show the
  /// Detail archetype against a person rather than a book —
  /// `DSAvatar`, a two-column `DSStatTileGrid` and `DSChip` in its `tag`
  /// role, none of which any other demo screen needed.
  static const profile = '/profile';
}
