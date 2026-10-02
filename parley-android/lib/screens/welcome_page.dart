import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/providers/settings_provider.dart';
import 'package:parley_android/screens/welcome_sheet.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:parley_android/utils/app_routes.dart';

/// Welcome — the **Sequence** archetype
/// (`docs/principles/screen-archetypes.md`), and its first step.
///
/// Its job is `brand`: it is the one screen whose whole purpose is to say what
/// this is before anything is asked. It hands over to the tour, which hands
/// over to the app — a sequence that ends on itself is one the user leaves.
///
/// Lives at `/welcome` between the splash and the existing onboarding
/// carousel. The router only lands a user here on first launch (when both
/// `welcomeSeen` and `onboardingComplete` are false); a returning user
/// skips it. The screen replaces the dead silence between splash and tour,
/// not the tour itself — onboarding still runs after the user commits.
///
/// What the page composes, in the order the user meets it:
///
///   * a `DSLargeAppBar` carrying the **headline in its subtitle** (the
///     config the `header-earns-its-height` lint protects — a tall bar with
///     no payload is graded here as it is graded everywhere else);
///   * a small drawn illustration composed inside a `DSTourCanvas`, so the
///     picture is of *the app* rather than of a generic icon;
///   * a row of three `DSStatTile`s at compact scale — the welcome is the
///     first non-Focal surface where the stat tile composes a *row* rather
///     than a hero-support or a bento pair;
///   * three `DSListTile` claims saying what those three figures mean. They
///     are the screen's payload: without them the welcome states a product
///     and never what it does, and the 235pt of white that question was
///     sitting in is what `ui-probe`'s `dead-band` rule measured;
///   * a `DSPinnedActionBar` with one full-width `DSButton` (the peak
///     moment's reward — commit to the tour) and one ghost secondary
///     (the end moment's shortcut — sign in instead).
///
/// A fourth thing sits between the stats and the bar: a small ghost
/// affordance opening the peek-driven `DSBottomSheet` in
/// `lib/screens/welcome_sheet.dart`. It is the third tier of action on this
/// screen — the primary commits to the tour, the bar's ghost skips to
/// sign-in, and this one answers "what is in there?" without costing the
/// user their place. The detents and their labels are that file's contract
/// and are asserted there, not here.
///
/// Three kit ingredients (`DSTourCanvas`, `DSStatTile` row,
/// `DSPinnedActionBar`'s primary-plus-ghost shape) meet on this screen.
/// The kit gains no new component.
class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  Future<void> _getStarted(WidgetRef ref, BuildContext context) async {
    AppHaptics.light();
    await ref.read(settingsProvider.notifier).markWelcomeSeen();
    if (!context.mounted) return;
    context.go(AppRoutes.onboarding);
  }

  Future<void> _signInInstead(WidgetRef ref, BuildContext context) async {
    AppHaptics.light();
    await ref.read(settingsProvider.notifier).markWelcomeSeen();
    if (!context.mounted) return;
    context.go(AppRoutes.login);
  }

  Future<void> _skip(WidgetRef ref, BuildContext context) async {
    AppHaptics.light();
    await ref.read(settingsProvider.notifier).markWelcomeSeen();
    if (!context.mounted) return;
    context.go(AppRoutes.onboarding);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = context.design.space;
    // The bar this screen pins reports its own height here, so a snack bar
    // does not land on it and the button does not sit on its primary control.
    // Without the host each of the three floats independently and none of them
    // knows the others exist; `DSFab.hideOnScroll` reads a DSScrollRetreat
    // that nothing publishes.

    return DSBottomInsetsHost(
      child: Scaffold(
        // The pinned bar floats, so the body runs under it; the chrome layer
        // paints over the body as the scroll lands.
        extendBody: true,
        body: CustomScrollView(
          slivers: <Widget>[
            DSLargeAppBar(
              eyebrow: 'Rocketship',
              title: '',
              titleMaxLines: 1,
              // The headline lives here, not in the body. This is what the
              // `header-earns-its-height` lint covers: a tall bar with an
              // empty title but a populated subtitle is graded as a header
              // with payload, not a header with chrome.
              subtitle: 'A faster way to track what you\u2019re building.',
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Skip the welcome',
                onPressed: () => _skip(ref, context),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  DSGutter.of(context),
                  space.lg,
                  DSGutter.of(context),
                  space.md,
                ),
                child: const WelcomeIllustration(active: true),
              ),
            ),
            SliverToBoxAdapter(
              child: DSGutter(
                child: Row(
                  children: <Widget>[
                    // Compact scale — the dashboard's md-scale tiles are
                    // wider than three fit on a 320pt phone, and the welcome
                    // has to. The three literal labels are the welcome's own
                    // copy, not a fixture; the const is on the inner tile
                    // widgets only because `space.sm` is a runtime value.
                    const Expanded(
                      child: DSStatTile(
                        value: '4',
                        label: 'screens',
                        size: DSStatTileSize.compact,
                      ),
                    ),
                    SizedBox(width: space.sm),
                    const Expanded(
                      child: DSStatTile(
                        value: '60s',
                        label: 'to commit',
                        size: DSStatTileSize.compact,
                      ),
                    ),
                    SizedBox(width: space.sm),
                    const Expanded(
                      child: DSStatTile(
                        value: 'Live',
                        label: 'offline',
                        size: DSStatTileSize.compact,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // What the three figures above actually mean, one line each.
            //
            // The screen used to go from the stat row straight to the peek
            // affordance, and `ui-probe`'s `dead-band` rule measured 235pt of
            // white between that affordance and the bar — a welcome that says
            // what the product is and never what it does. `flutter-086`.
            DSGutter.sliver(
              sliver: SliverList.list(
                children: <Widget>[
                  SizedBox(height: space.lg),
                  for (final ({IconData icon, String title, String body}) claim
                      in const <({IconData icon, String title, String body})>[
                        (
                          icon: Icons.dashboard_outlined,
                          title: 'Four screens, wired',
                          body:
                              'A focal home, a library, a detail and a form '
                              '— all of them live, none of them a mock.',
                        ),
                        (
                          icon: Icons.bolt_outlined,
                          title: 'A minute to your first commit',
                          body:
                              'Clone it, run it, and the demo surface is '
                              'already yours to edit.',
                        ),
                        (
                          icon: Icons.cloud_off_outlined,
                          title: 'Offline by default',
                          body:
                              'Reads from a local store first and syncs '
                              'when the network comes back.',
                        ),
                      ])
                    DSListTile(
                      leading: DSWell(icon: claim.icon),
                      title: claim.title,
                      subtitle: claim.body,
                      // A claim is a sentence, not a label: `wrap` gives it
                      // the lines it needs instead of the ellipsis
                      // `clipped-text` fails a row for.
                      wrap: true,
                    ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  DSGutter.of(context),
                  space.md,
                  DSGutter.of(context),
                  0,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DSButton(
                    label: 'See what’s inside',
                    icon: Icons.expand_less,
                    // Small and ghost: the third tier. Full-width or tonal
                    // here would put a third contender beside the two in the
                    // bar, and a screen with three equal actions has none.
                    variant: DSButtonVariant.ghost,
                    size: DSButtonSize.sm,
                    onPressed: () => showWelcomeSheet(context),
                  ),
                ),
              ),
            ),
            // Padding for the pinned bar so the last content row clears it.
            //
            // Measured, not guessed: `DSBottomInsets.scrollClearance` is the
            // bar's own reported height plus the button, which is exactly what
            // a row at the end of the scroll has to clear. It was a fixed
            // `space.xxxl`, and once `flutter-086`'s three claims made the
            // page scroll, the end of that scroll left the affordance under
            // the bar and untappable — the fixed number had never been the
            // bar's height, it had only been more than the page needed while
            // the page did not move. A `Builder` because the host is installed
            // above this `build`, so its own `context` cannot see it.
            //
            // The "Replace the three..." paragraph that used to live here was
            // documentation copy (a note to the developer reading this file,
            // not a sentence for the user), and at 2.0x text scale on a
            // 430pt viewport it rendered under the bar — the probe measured
            // the overlap. The note moved to the doc comment above the class.
            SliverToBoxAdapter(
              child: Builder(
                builder: (BuildContext context) => SizedBox(
                  height: DSBottomInsets.of(context).scrollClearance + space.md,
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: DSPinnedActionBar(
          layout: DSActionBarLayout.stack,
          children: <Widget>[
            DSButton(
              label: 'Get started',
              variant: DSButtonVariant.primary,
              fullWidth: true,
              onPressed: () => _getStarted(ref, context),
            ),
            DSButton(
              label: 'I already have an account',
              variant: DSButtonVariant.ghost,
              fullWidth: true,
              onPressed: () => _signInInstead(ref, context),
            ),
          ],
        ),
      ),
    );
  }
}

/// The small drawing the welcome shows in place of a stock illustration.
///
/// Four stripes — a focal, a collection, a detail, a form — drawn at a
/// fixed width inside a `DSTourCanvas`. The stripes are drawn still: nothing
/// on this screen animates in.
///
/// **Replace this with the product's own drawing.** A generic icon is
/// what every welcome screen ships with, and is the reason no welcome
/// screen is recognisable on a home screen. What matters is that the
/// screen does not hand-roll a control the kit owns.
class WelcomeIllustration extends StatelessWidget {
  const WelcomeIllustration({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final space = context.design.space;

    return DSTourCanvas(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.all(
            Radius.circular(context.radiusOf(AppShape.card)),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(space.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 0; i < 4; i++) ...<Widget>[
                if (i > 0) SizedBox(height: space.sm),
                _Stripe(space: space, emphasis: i == 0),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Stripe extends StatelessWidget {
  const _Stripe({required this.space, required this.emphasis});

  final SpaceSpec space;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasis ? palette.secondary : palette.background,
        borderRadius: BorderRadius.all(
          Radius.circular(context.radiusOf(AppShape.tile)),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(space.md),
        child: Row(
          children: <Widget>[
            Container(
              width: space.lg,
              height: space.lg,
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: emphasis ? 0.9 : 0.2),
                borderRadius: BorderRadius.all(
                  Radius.circular(context.radiusOf(AppShape.control)),
                ),
              ),
            ),
            SizedBox(width: space.sm),
            // A short line of placeholder content. The height is one stop
            // on the space ladder (`xs`) so it reads as a line of text and
            // not a stripe; the rounding uses the kit's control-corner
            // token rather than a literal so it cannot drift off-rhythm.
            Expanded(
              child: Container(
                height: space.xs,
                decoration: BoxDecoration(
                  color: palette.mutedForeground.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.all(
                    Radius.circular(context.radiusOf(AppShape.control)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
