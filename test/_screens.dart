import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parley_android/providers/parley_providers.dart';
import 'package:parley_android/screens/parley/api_keys_page.dart';
import 'package:parley_android/screens/parley/history_detail_page.dart';
import 'package:parley_android/screens/parley/history_page.dart';
import 'package:parley_android/screens/parley/overview_page.dart';
import 'package:parley_android/screens/parley/parley_settings_page.dart';
import 'package:parley_android/screens/parley/setup_page.dart';
import 'package:parley_android/services/parley/fake_parley_bridge.dart';
import 'package:parley_android/models/library_item.dart';
import 'package:parley_android/screens/auth/login_page.dart';
import 'package:parley_android/screens/design_system/blog_article_page.dart';
import 'package:parley_android/screens/design_system/blog_data.dart';
import 'package:parley_android/screens/design_system/blog_page.dart';
import 'package:parley_android/screens/design_system/browse_page.dart';
import 'package:parley_android/screens/design_system/form_page.dart';
import 'package:parley_android/screens/design_system/inbox_page.dart';
import 'package:parley_android/screens/design_system/insight_data.dart';
import 'package:parley_android/screens/design_system/insight_page.dart';
import 'package:parley_android/screens/design_system/order_placed_page.dart';
import 'package:parley_android/screens/design_system/place_page.dart';
import 'package:parley_android/screens/design_system/profile_data.dart';
import 'package:parley_android/screens/design_system/profile_page.dart';
import 'package:parley_android/screens/home/dashboard_page.dart';
import 'package:parley_android/screens/home/library_page.dart';
import 'package:parley_android/screens/library_detail_page.dart';
import 'package:parley_android/screens/onboarding_page.dart';
import 'package:parley_android/screens/settings_page.dart';
import 'package:parley_android/screens/welcome_page.dart';

/// The screens the graded surfaces are built from, in one list.
///
/// **This file exists because a screen used to be born invisible.** The probe
/// walked a list of five names typed into `test/probe/corpus.dart` and the
/// goldens a map of five names typed into `test/golden/screens_golden_test.dart`,
/// and neither list had any relationship to the screens the app actually has.
/// A demo blog shipped with a truncated headline in every row, a back button
/// drawn through its eyebrow and an empty band of card under its hero, with
/// `analyze`, `ui_lint`, `test`, `ui-probe` and `golden` all green — because
/// the two lists did not mention it and nothing said they had to.
///
/// Now the probe and the goldens both read this, and
/// `test/screens_registry_test.dart` fails when a `*_page.dart` under
/// `lib/screens/` appears in neither this list nor the documented-gap list
/// beside it. Adding a screen and adding it to a gate are one act.
///
/// The fixtures are still each consumer's own — the probe measures against
/// data chosen to stress a layout, the goldens against data chosen to be
/// recognisable — so this holds the *inventory* and the *composition*, not the
/// content.
@immutable
class AppScreen {
  const AppScreen({
    required this.name,
    required this.source,
    required this.build,
    this.contentDriven = false,
  });

  /// `blog`. The probe walks it as `screen/blog`, the goldens record it as
  /// `screen_blog`, and both spellings are derived rather than typed.
  final String name;

  /// The file this screen is, relative to the project root. What the registry
  /// test matches the tree against.
  final String source;

  /// The screen, composed against a consumer's fixtures.
  final Widget Function(ScreenFixture fixture) build;

  /// Whether what this screen renders is the fixture rather than the app.
  ///
  /// The probe walks these twice: once with ordinary content and once with
  /// the long kind — a 60-character headline, a 200-character quote — because
  /// every fixture in the repository was three or four words long, and a
  /// layout is only ever proved against content of the shape it was given.
  /// The blog's headline was cut on every row and nothing failed, because
  /// nothing had ever handed it a headline.
  final bool contentDriven;
}

/// The data one consumer measures a screen against.
///
/// Passed in rather than owned here: the probe's items exist to stress a
/// layout and the goldens' items exist to be recognisable in a picture, and
/// merging them would rewrite every baseline in the repository to prove a
/// point about lists.
@immutable
class ScreenFixture {
  const ScreenFixture({required this.items, required this.article});

  final List<LibraryItem> items;
  final BlogArticle article;
}

/// Every screen a gate can mount, in the order a reader meets them.
const List<AppScreen> appScreens = <AppScreen>[
  // Parley's own screens first: these are the app. Each is mounted over a
  // `FakeParleyBridge` pinned to [parleyFixtureNow], so "Today", the clock
  // times and the figures are the same in every run.
  AppScreen(
    name: 'parley_overview',
    source: 'lib/screens/parley/overview_page.dart',
    build: _parleyOverview,
  ),
  AppScreen(
    name: 'parley_history',
    source: 'lib/screens/parley/history_page.dart',
    build: _parleyHistory,
  ),
  AppScreen(
    name: 'parley_history_detail',
    source: 'lib/screens/parley/history_detail_page.dart',
    build: _parleyHistoryDetail,
  ),
  AppScreen(
    name: 'parley_history_edit',
    source: 'lib/screens/parley/history_detail_page.dart',
    build: _parleyHistoryEdit,
  ),
  AppScreen(
    name: 'parley_settings',
    source: 'lib/screens/parley/parley_settings_page.dart',
    build: _parleySettings,
  ),
  AppScreen(
    name: 'parley_api_keys',
    source: 'lib/screens/parley/api_keys_page.dart',
    build: _parleyApiKeys,
  ),
  AppScreen(
    name: 'parley_setup_welcome',
    source: 'lib/screens/parley/setup_page.dart',
    build: _parleySetupWelcome,
  ),
  AppScreen(
    name: 'parley_setup_key',
    source: 'lib/screens/parley/setup_page.dart',
    build: _parleySetupKey,
  ),
  AppScreen(
    name: 'parley_setup_accessibility',
    source: 'lib/screens/parley/setup_page.dart',
    build: _parleySetupAccessibility,
  ),
  AppScreen(
    name: 'parley_setup_practice',
    source: 'lib/screens/parley/setup_page.dart',
    build: _parleySetupPractice,
  ),
  AppScreen(
    name: 'dashboard',
    source: 'lib/screens/home/dashboard_page.dart',
    build: _dashboard,
  ),
  AppScreen(
    name: 'library',
    source: 'lib/screens/home/library_page.dart',
    build: _library,
    contentDriven: true,
  ),
  AppScreen(
    name: 'settings',
    source: 'lib/screens/settings_page.dart',
    build: _settings,
  ),
  AppScreen(
    name: 'detail',
    source: 'lib/screens/library_detail_page.dart',
    build: _detail,
    contentDriven: true,
  ),
  AppScreen(
    name: 'login',
    source: 'lib/screens/auth/login_page.dart',
    build: _login,
  ),
  AppScreen(
    name: 'blog',
    source: 'lib/screens/design_system/blog_page.dart',
    build: _blog,
    contentDriven: true,
  ),
  AppScreen(
    name: 'blog_article',
    source: 'lib/screens/design_system/blog_article_page.dart',
    build: _blogArticle,
    contentDriven: true,
  ),
  AppScreen(
    name: 'inbox',
    source: 'lib/screens/design_system/inbox_page.dart',
    build: _inbox,
    contentDriven: true,
  ),
  // One entry per step. A paged flow needs a fixture per page — a flow the
  // gates only ever see the first page of is a flow whose other three pages
  // are measured by nothing and pictured by nothing.
  AppScreen(
    name: 'form_who',
    source: 'lib/screens/design_system/form_page.dart',
    build: _formWho,
  ),
  AppScreen(
    name: 'form_when',
    source: 'lib/screens/design_system/form_page.dart',
    build: _formWhen,
  ),
  AppScreen(
    name: 'form_desk',
    source: 'lib/screens/design_system/form_page.dart',
    build: _formDesk,
  ),
  AppScreen(
    name: 'form_review',
    source: 'lib/screens/design_system/form_page.dart',
    build: _formReview,
  ),
  // One entry per stop, for the same reason the form has one per step. The
  // gap this replaces said it out loud: "a paged flow needs a fixture per
  // page, and the probe mounts one state."
  AppScreen(
    name: 'tour_1',
    source: 'lib/screens/onboarding_page.dart',
    build: _tour1,
  ),
  AppScreen(
    name: 'tour_2',
    source: 'lib/screens/onboarding_page.dart',
    build: _tour2,
  ),
  AppScreen(
    name: 'tour_3',
    source: 'lib/screens/onboarding_page.dart',
    build: _tour3,
  ),
  // The moment a new user meets the app. Not `contentDriven` for the same
  // reason `tour_*` isn't: the welcome's three figures and its headline are
  // copy this page owns, not a fixture, and the long-content pass would
  // measure the same screen twice.
  AppScreen(
    name: 'welcome',
    source: 'lib/screens/welcome_page.dart',
    build: _welcome,
  ),
  // One entry per period, for the same reason the form has one per step: the
  // period control moves every number on the screen, so a gate that only ever
  // mounts the week has never seen the month's five-point plot, its longer
  // span line or its negative delta.
  AppScreen(
    name: 'browse',
    source: 'lib/screens/design_system/browse_page.dart',
    build: _browse,
  ),
  AppScreen(
    name: 'order_placed',
    source: 'lib/screens/design_system/order_placed_page.dart',
    build: _orderPlaced,
  ),
  AppScreen(
    name: 'insight_week',
    source: 'lib/screens/design_system/insight_page.dart',
    build: _insightWeek,
  ),
  AppScreen(
    name: 'insight_month',
    source: 'lib/screens/design_system/insight_page.dart',
    build: _insightMonth,
  ),
  // Two entries, one per detent that changes the screen: peek is the state
  // the archetype's rule is about — the pin the reader tapped is still
  // visible — and full is where the sheet is the thing being read.
  AppScreen(
    name: 'place',
    source: 'lib/screens/design_system/place_page.dart',
    build: _place,
  ),
  AppScreen(
    name: 'place_full',
    source: 'lib/screens/design_system/place_page.dart',
    build: _placeFull,
  ),
  AppScreen(
    name: 'profile_activity',
    source: 'lib/screens/design_system/profile_page.dart',
    build: _profileActivity,
  ),
  AppScreen(
    name: 'profile_badges',
    source: 'lib/screens/design_system/profile_page.dart',
    build: _profileBadges,
  ),
];

Widget _dashboard(ScreenFixture f) =>
    const Scaffold(body: DashboardPage(onOpenDrawer: _noop));
Widget _library(ScreenFixture f) => const Scaffold(body: LibraryPage());
Widget _settings(ScreenFixture f) => const Scaffold(body: SettingsPage());
Widget _detail(ScreenFixture f) => LibraryDetailPage(item: f.items.first);
Widget _login(ScreenFixture f) => const LoginPage();
Widget _blog(ScreenFixture f) => const Scaffold(body: BlogPage());
Widget _blogArticle(ScreenFixture f) => BlogArticlePage(article: f.article);
Widget _inbox(ScreenFixture f) => const Scaffold(body: InboxPage());
// Not `contentDriven`: what the form renders is its own labels and helper
// text, not a fixture, so the long-content pass would measure the same screen
// twice.
Widget _formWho(ScreenFixture f) => const FormPage();
Widget _formWhen(ScreenFixture f) => const FormPage(initialStep: 1);
Widget _formDesk(ScreenFixture f) => const FormPage(initialStep: 2);
Widget _formReview(ScreenFixture f) => const FormPage(initialStep: 3);
// Not `contentDriven`: a tour renders its own copy, so a long-content pass
// would measure the same three screens twice.
Widget _tour1(ScreenFixture f) => const OnboardingPage();
Widget _tour2(ScreenFixture f) => const OnboardingPage(initialStop: 1);
Widget _tour3(ScreenFixture f) => const OnboardingPage(initialStop: 2);
Widget _welcome(ScreenFixture f) => const Scaffold(body: WelcomePage());
// Not `contentDriven`: a recap renders the figures it was given and its own
// written sentence, and the long-content pass would measure the same two
// screens twice.
Widget _browse(ScreenFixture f) => const BrowsePage();

Widget _orderPlaced(ScreenFixture f) => const OrderPlacedPage();


Widget _place(ScreenFixture f) => const PlacePage();
Widget _placeFull(ScreenFixture f) =>
    const PlacePage(initialSnap: PlacePage.full);

Widget _insightWeek(ScreenFixture f) => const InsightPage();
Widget _insightMonth(ScreenFixture f) =>
    const InsightPage(initialPeriod: InsightPeriod.month);
// Not `contentDriven`: a profile renders the signed-in reader's own name and
// email plus its own demo activity/badges, not a fixture, so the long-content
// pass would measure the same two screens twice.
Widget _profileActivity(ScreenFixture f) =>
    const ProfilePage(initialSection: ProfileSection.activity);
Widget _profileBadges(ScreenFixture f) =>
    const ProfilePage(initialSection: ProfileSection.badges);

void _noop() {}

/// The clock every Parley fixture is read against.
final DateTime parleyFixtureNow = DateTime(2026, 9, 24, 10, 1);

Widget _parley(Widget child, {FakeParleyBridge? bridge}) => ProviderScope(
  overrides: [
    parleyBridgeProvider.overrideWithValue(
      bridge ?? FakeParleyBridge.ready(now: parleyFixtureNow),
    ),
  ],
  child: child,
);

Widget _parleyOverview(ScreenFixture f) =>
    _parley(const Scaffold(body: OverviewPage()));
Widget _parleyHistory(ScreenFixture f) =>
    _parley(Scaffold(body: HistoryPage(now: parleyFixtureNow)));
Widget _parleyHistoryDetail(ScreenFixture f) =>
    _parley(HistoryDetailPage(id: 12, now: parleyFixtureNow));
Widget _parleyHistoryEdit(ScreenFixture f) =>
    _parley(HistoryDetailPage(id: 11, now: parleyFixtureNow));
Widget _parleySettings(ScreenFixture f) =>
    _parley(const Scaffold(body: ParleySettingsPage()));
Widget _parleyApiKeys(ScreenFixture f) => _parley(const ApiKeysPage());
Widget _parleySetupWelcome(ScreenFixture f) => _parley(
  const SetupPage(initialStep: 0),
  bridge: FakeParleyBridge(now: parleyFixtureNow),
);
Widget _parleySetupKey(ScreenFixture f) => _parley(
  const SetupPage(initialStep: 1),
  bridge: FakeParleyBridge(now: parleyFixtureNow),
);
Widget _parleySetupAccessibility(ScreenFixture f) => _parley(
  const SetupPage(initialStep: 3),
  bridge: FakeParleyBridge(now: parleyFixtureNow),
);
Widget _parleySetupPractice(ScreenFixture f) => _parley(
  const SetupPage(initialStep: 5),
  bridge: FakeParleyBridge(now: parleyFixtureNow),
);

/// The screens no gate mounts yet, and why.
///
/// A gap is a line somebody has to write, which is the point: the registry
/// test fails on a screen that is in neither list, so the cost of leaving a
/// screen ungraded is saying so here rather than saying nothing anywhere.
const Map<String, String> ungradedScreens = <String, String>{
  'lib/screens/home_screen.dart':
      'the shell, not a screen — it mounts the destinations the probe walks '
      'individually, and measuring it would measure them twice.',
  'lib/screens/design_system/gallery_page.dart':
      'walked by the probe as `catalog/gallery`, which is derived from the '
      'catalog rather than from this list.',
  'lib/screens/design_system/demos_page.dart':
      'walked by the probe as `catalog/demos`, next to `catalog/gallery`, '
      'for the same reason.',
  'lib/screens/design_system/foundations_page.dart':
      'walked by the probe as `catalog/foundations`, beside the gallery '
      'that links to it.',
  'lib/screens/design_system/component_page.dart':
      'walked by the probe once per component as `catalog/<component>`.',
  'lib/screens/splash_page.dart':
      'a frame of a launch animation; there is no settled state to measure.',
  'lib/screens/paywall_page.dart':
      'the probe pumps a fixed 250ms and the mock store takes 700ms to '
      'answer, so every frame it could capture is the spinner. Grading it '
      'needs a provider override this registry has no slot for; its shape is '
      'held by the Offer group in `test/screens/archetypes_test.dart` '
      'instead.',
  'lib/screens/auth/signup_page.dart':
      'not yet graded — the same form archetype as `login`, which is walked.',
  'lib/screens/auth/forgot_password_page.dart': 'not yet graded.',
  'lib/screens/auth/reset_password_page.dart': 'not yet graded.',
  'lib/screens/settings/about_page.dart': 'not yet graded.',
  'lib/screens/settings/appearance_page.dart': 'not yet graded.',
  'lib/screens/settings/licenses_page.dart': 'not yet graded.',
  'lib/screens/settings/license_detail_page.dart':
      'not yet graded — its content is whatever `LicenseRegistry` reports at '
      'build time, so a fixture here would grade this build\'s dependency '
      'tree rather than the layout.',
};
