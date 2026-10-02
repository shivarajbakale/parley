import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/models/library_item.dart';
import 'package:parley_android/providers/settings_provider.dart';
import 'package:parley_android/screens/design_system/blog_article_page.dart';
import 'package:parley_android/screens/design_system/blog_data.dart';
import 'package:parley_android/screens/design_system/blog_page.dart';
import 'package:parley_android/screens/design_system/component_page.dart';
import 'package:parley_android/screens/design_system/foundations_page.dart';
import 'package:parley_android/screens/design_system/inbox_page.dart';
import 'package:parley_android/screens/design_system/form_page.dart';
import 'package:parley_android/screens/design_system/browse_page.dart';
import 'package:parley_android/screens/design_system/place_page.dart';
import 'package:parley_android/screens/design_system/insight_page.dart';
import 'package:parley_android/screens/design_system/order_placed_page.dart';
import 'package:parley_android/screens/design_system/profile_page.dart';
import 'package:parley_android/screens/home_screen.dart';
import 'package:parley_android/screens/library_detail_page.dart';
import 'package:parley_android/screens/parley/api_keys_page.dart';
import 'package:parley_android/screens/parley/history_detail_page.dart';
import 'package:parley_android/screens/parley/setup_page.dart';
import 'package:parley_android/screens/paywall_page.dart';
import 'package:parley_android/screens/settings/about_page.dart';
import 'package:parley_android/screens/settings/license_detail_page.dart';
import 'package:parley_android/screens/settings/licenses_page.dart';
import 'package:parley_android/screens/settings/appearance_page.dart';
import 'package:parley_android/theme/app_platform.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:parley_android/utils/app_transitions.dart';
import 'package:parley_android/utils/app_routes.dart';

/// The app's [GoRouter].
///
/// One gate: until setup has been finished once (`onboardingComplete`), every
/// location lands on `/setup`. After that `/setup` is only reachable as
/// Settings' "Run setup again" (`?again=1`). Parley has no accounts, so there
/// is no auth gate; the template's auth screens stay in the tree unrouted.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SetupRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final setupDone = ref.read(settingsProvider).onboardingComplete;
      final loc = state.uri.path;
      if (!setupDone) return loc == AppRoutes.setup ? null : AppRoutes.setup;
      if (loc == AppRoutes.setup && state.uri.queryParameters['again'] != '1') {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.setup,
        builder: (_, state) => SetupPage(
          initialStep: state.uri.queryParameters['again'] == '1' ? 0 : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, __) => const HomeScreen(),
        routes: [
          // Children stack on top of home, so Back from a deep-linked page
          // returns to the app rather than exiting it.
          GoRoute(
            path: 'history/:id',
            pageBuilder: (context, state) => _sharedAxisPage(
              key: state.pageKey,
              context: context,
              child: HistoryDetailPage(
                id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
          ),
          GoRoute(
            path: 'settings/keys',
            pageBuilder: (context, state) => _sharedAxisPage(
              key: state.pageKey,
              context: context,
              child: const ApiKeysPage(),
            ),
          ),
          GoRoute(
            path: 'paywall',
            pageBuilder: (_, __) => const MaterialPage(
              fullscreenDialog: true,
              child: PaywallPage(),
            ),
          ),
          GoRoute(
            path: 'settings/appearance',
            builder: (_, __) => const AppearancePage(),
          ),
          GoRoute(
            path: 'settings/about',
            builder: (_, __) => const AboutPage(),
          ),
          GoRoute(
            path: 'settings/licenses',
            builder: (_, __) => const LicensesPage(),
          ),
          GoRoute(
            path: 'settings/licenses/detail',
            builder: (_, state) =>
                LicenseDetailPage(license: state.extra! as PackageLicense),
          ),
          GoRoute(
            // The gallery's detail route. Deep-link safe: an unknown name
            // renders the "not part of the design system" state rather than
            // a blank screen.
            path: 'components/:name',
            builder: (context, state) =>
                ComponentPage(name: state.pathParameters['name'] ?? ''),
          ),
          GoRoute(
            path: 'foundations',
            builder: (_, __) => const FoundationsPage(),
          ),
          GoRoute(
            // The blog demo list. Pushed from the Demos tab's first tile;
            // deep-link safe in the sense that the page itself has no
            // inputs that could be wrong.
            path: 'blog',
            pageBuilder: (context, state) => _sharedAxisPage(
              key: state.pageKey,
              context: context,
              child: const BlogPage(),
            ),
          ),
          GoRoute(
            // The blog demo article. Deep-link safe: an unknown slug routes
            // back to the blog list rather than rendering a blank screen,
            // so a typo'd URL or a stale link fails gracefully.
            path: 'blog/article/:slug',
            pageBuilder: (context, state) {
              final slug = state.pathParameters['slug'] ?? '';
              final article = blogArticleBySlug(slug);
              if (article == null) {
                return const MaterialPage(child: BlogPage());
              }
              return _sharedAxisPage(
                key: state.pageKey,
                context: context,
                child: BlogArticlePage(article: article),
              );
            },
          ),
          GoRoute(
            // The inbox demo. The page has no inputs that could be wrong, so
            // the route is deep-link safe in the trivial sense; it still goes
            // through the shared-axis helper so the iOS back gesture attaches
            // and the other platforms get the page transition the rest of the
            // demo surface uses.
            path: 'inbox',
            pageBuilder: (context, state) => _sharedAxisPage(
              key: state.pageKey,
              context: context,
              child: const InboxPage(),
            ),
          ),
          GoRoute(
            // The booking-form demo. Like the inbox it takes no parameters,
            // so the route is deep-link safe in the trivial sense; it goes
            // through the shared-axis helper for the same reason, so the
            // back gesture and the page transition match the rest of the
            // demo surface.
            path: 'form',
            pageBuilder: (context, state) => _sharedAxisPage(
              key: state.pageKey,
              context: context,
              child: const FormPage(),
            ),
          ),
          GoRoute(
            // The reading-recap demo. Opens on the week, which is the period
            // the page defaults to — the month is a control away rather than
            // a second route, because the archetype's point is that one
            // switch moves the headline, the plot, the sentence and the
            // breakdown together.
            path: 'insight',
            pageBuilder: (context, state) => _sharedAxisPage(
              key: state.pageKey,
              context: context,
              child: const InsightPage(),
            ),
          ),
          GoRoute(
            // The browse demo. A Shelf takes no parameters: the rails are
            // what the app ranked, so there is nothing for a caller to say.
            path: 'browse',
            pageBuilder: (context, state) => _sharedAxisPage(
              key: state.pageKey,
              context: context,
              child: const BrowsePage(),
            ),
          ),
          GoRoute(
            // The confirmation demo. Pushed rather than replaced, because in
            // the demo surface it is a screen a reader visits rather than the
            // end of a checkout they completed — the archetype's own rule
            // about handing over still holds inside the page.
            path: 'order-placed',
            pageBuilder: (context, state) => _sharedAxisPage(
              key: state.pageKey,
              context: context,
              child: const OrderPlacedPage(),
            ),
          ),
          GoRoute(
            // The canvas demo. Opens at the peek detent, which is the one
            // that has to leave the pin the reader tapped visible.
            path: 'place',
            pageBuilder: (context, state) => _sharedAxisPage(
              key: state.pageKey,
              context: context,
              child: const PlacePage(),
            ),
          ),
          GoRoute(
            // The profile demo. Like the others it takes no parameters, so
            // the route is deep-link safe in the trivial sense; the shared
            // axis helper matches the transition the rest of the demo
            // surface uses.
            path: 'profile',
            pageBuilder: (context, state) => _sharedAxisPage(
              key: state.pageKey,
              context: context,
              child: const ProfilePage(),
            ),
          ),
          GoRoute(
            // Deep-link safe: resolves the item by index into demoLibraryItems,
            // so a cold-start / refresh on this URL still renders.
            path: 'library/detail/:index',
            pageBuilder: (context, state) {
              final index = int.tryParse(state.pathParameters['index'] ?? '');
              if (index == null ||
                  index < 0 ||
                  index >= demoLibraryItems.length) {
                return const MaterialPage(child: HomeScreen());
              }
              return _sharedAxisPage(
                key: state.pageKey,
                context: context,
                // The route pair, not the general scale: a push and its
                // matching pop are the one place where two durations have to
                // be chosen together, and the shorter return is what stops a
                // back gesture feeling slower than the step that opened it.
                child: LibraryDetailPage(item: demoLibraryItems[index]),
              );
            },
          ),
        ],
      ),
    ],
  );
});

/// A list→detail page that uses [AppTransitions.sharedAxis] on every
/// platform except Apple's.
///
/// Why the split: [Navigator] only attaches the iOS edge-swipe-to-go-back
/// gesture to routes whose transition delegate is the Cupertino one.
/// [CustomTransitionPage] produces a vanilla [ModalRoute] and gets no
/// gesture — which is why the three routes using it lost the back swipe
/// after the shared-axis transition landed. Falling back to [CupertinoPage]
/// on Apple gives those routes the platform's own slide-from-right visual
/// *and* the gesture, at the cost of the shared-axis animation on those two
/// targets. Android, web and desktop keep the shared-axis visual, where the
/// gesture attaches differently (predictive back, none) and a list→detail
/// step along an axis still reads as one continuous gesture.
Page<T> _sharedAxisPage<T>({
  required LocalKey key,
  required BuildContext context,
  required Widget child,
}) {
  if (AppPlatform.sideOf(context) == AppPlatformSide.apple) {
    return CupertinoPage<T>(key: key, child: child);
  }
  final motion = context.design.motion;
  return CustomTransitionPage<T>(
    key: key,
    transitionDuration: motion.scaled(motion.routeEnter),
    reverseTransitionDuration: motion.scaled(motion.routeExit),
    transitionsBuilder: AppTransitions.sharedAxis,
    child: child,
  );
}

/// Re-runs [GoRouter.redirect] when setup completes.
class _SetupRefresh extends ChangeNotifier {
  _SetupRefresh(Ref ref) {
    ref.listen<bool>(
      settingsProvider.select((s) => s.onboardingComplete),
      (_, __) => notifyListeners(),
    );
  }
}
