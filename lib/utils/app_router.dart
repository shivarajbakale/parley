import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/models/library_item.dart';
import 'package:parley_android/providers/auth_provider.dart';
import 'package:parley_android/providers/settings_provider.dart';
import 'package:parley_android/screens/auth/forgot_password_page.dart';
import 'package:parley_android/screens/auth/login_page.dart';
import 'package:parley_android/screens/auth/reset_password_page.dart';
import 'package:parley_android/screens/auth/signup_page.dart';
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
import 'package:parley_android/screens/onboarding_page.dart';
import 'package:parley_android/screens/paywall_page.dart';
import 'package:parley_android/screens/settings/about_page.dart';
import 'package:parley_android/screens/settings/license_detail_page.dart';
import 'package:parley_android/screens/settings/licenses_page.dart';
import 'package:parley_android/screens/settings/appearance_page.dart';
import 'package:parley_android/screens/splash_page.dart';
import 'package:parley_android/screens/welcome_page.dart';
import 'package:parley_android/theme/app_platform.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:parley_android/utils/app_transitions.dart';
import 'package:parley_android/utils/app_routes.dart';

/// Routes the user may visit while signed out. `/reset` is here so a
/// password-reset deep link works without a session. (`/welcome` and
/// `/onboarding` are gated by shared-preferences flags, not by auth, so
/// they're handled separately.)
const _publicRoutes = {
  AppRoutes.login,
  AppRoutes.signup,
  AppRoutes.forgot,
  AppRoutes.reset,
};

/// The app's [GoRouter]. Auth gating lives entirely in [redirect]; deep links
/// (e.g. `/paywall`, `/reset?token=…`) survive the cold-start splash because
/// the intended location is stashed in `?from=` and replayed once the session
/// resolves.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = ref.read(authProvider).status;
      final onboardingDone = ref.read(settingsProvider).onboardingComplete;
      final uri = state.uri;
      final loc = uri.path;

      // 1. Boot: we don't yet know if there's a session. Park on the splash,
      //    remembering where the user was headed.
      if (status == AuthStatus.unknown) {
        if (loc == AppRoutes.splash) return null;
        final from = Uri.encodeComponent(uri.toString());
        return '${AppRoutes.splash}?from=$from';
      }

      // 2. Deliberate replay — the Components tab's Welcome tile pushes
      //    `/welcome?demo=1`, and Settings' "Replay the tour" row pushes
      //    `/onboarding?demo=1`. The query parameter is the opt-in: someone
      //    who asked for the screen wants it regardless of their history,
      //    and these are the two surfaces that ask.
      //
      //    The flags stay untouched. Resetting `onboardingComplete` to show
      //    the tour again would make the *router* the thing that decides,
      //    and a user who then killed the app would be back in first-run.
      //    The replay is a push over the app, and it pops back.
      //
      //    Placed at the *top* of the resolve logic (above the welcome
      //    / onboarding flag branches) so that a long-time reader of the
      //    demo — `welcomeSeen=true` *and* `onboardingComplete=true` — still
      //    reaches the welcome screen when they tap the tile. Without the
      //    lift, the post-onboarding branch below sends `/welcome` straight
      //    back to `/home`, which is the bug flutter-048 fixed after the
      //    first commit. The cold-launch flow is unchanged: this opt-in
      //    is local to the request, and no other arrival at /welcome carries
      //    `?demo=1`.
      if ((loc == AppRoutes.welcome || loc == AppRoutes.onboarding) &&
          uri.queryParameters['demo'] == '1') {
        return null;
      }

      // 3. First run: welcome precedes onboarding precedes auth.
      if (!onboardingDone) {
        final welcomeSeen = ref.read(settingsProvider).welcomeSeen;
        // Welcome is shown *before* onboarding on a cold launch, and a
        // returning user who finished onboarding never sees it again.
        if (!welcomeSeen) {
          return loc == AppRoutes.welcome ? null : AppRoutes.welcome;
        }
        // Welcome seen, onboarding not yet — go to the tour.
        if (loc == AppRoutes.onboarding) return null;
        if (loc == AppRoutes.welcome) {
          // A user mid-tour who taps back falls here. The welcome is past,
          // so send them on to onboarding (their last step) rather than to
          // a welcome screen they already saw.
          return AppRoutes.onboarding;
        }
        return AppRoutes.onboarding;
      }
      // Onboarding finished — don't let anyone sit on welcome or onboarding.
      if (loc == AppRoutes.onboarding || loc == AppRoutes.welcome) {
        return status == AuthStatus.authenticated
            ? AppRoutes.home
            : AppRoutes.login;
      }

      // 4. Resolved while on the splash → replay the intended destination,
      //    re-checked against the auth rules below.
      if (loc == AppRoutes.splash) {
        final from = uri.queryParameters['from'];
        final dest = (from != null && from.isNotEmpty)
            ? Uri.decodeComponent(from)
            : AppRoutes.home;
        final destPath = Uri.parse(dest).path;
        // `/welcome` is not in `_publicRoutes` because a signed-out user
        // does not have a session to "introduce" — send them to sign in
        // instead of to the welcome.
        if (status == AuthStatus.unauthenticated) {
          return destPath == AppRoutes.welcome
              ? AppRoutes.login
              : (_publicRoutes.contains(destPath) ? dest : AppRoutes.login);
        }
        return destPath == AppRoutes.welcome
            ? AppRoutes.welcome
            : (_publicRoutes.contains(destPath) ? AppRoutes.home : dest);
      }

      // 5. Normal auth gating.
      final onPublicRoute = _publicRoutes.contains(loc);
      if (status == AuthStatus.unauthenticated) {
        return onPublicRoute ? null : AppRoutes.login;
      }
      // Authenticated: keep signed-in users out of the auth screens.
      return onPublicRoute ? AppRoutes.home : null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashPage()),
      GoRoute(path: AppRoutes.welcome, builder: (_, __) => const WelcomePage()),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingPage(),
      ),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginPage()),
      GoRoute(path: AppRoutes.signup, builder: (_, __) => const SignupPage()),
      GoRoute(
        path: AppRoutes.forgot,
        builder: (_, __) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.reset,
        builder: (_, state) =>
            ResetPasswordPage(token: state.uri.queryParameters['token']),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, __) => const HomeScreen(),
        routes: [
          // Children stack on top of home, so Back from a deep-linked page
          // returns to the app rather than exiting it.
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

/// Bridges Riverpod to go_router's `refreshListenable`, so the router re-runs
/// [GoRouter.redirect] whenever auth status or the onboarding flag changes.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen<AuthStatus>(
      authProvider.select((s) => s.status),
      (_, __) => notifyListeners(),
    );
    ref.listen<bool>(
      settingsProvider.select((s) => s.onboardingComplete),
      (_, __) => notifyListeners(),
    );
  }
}
