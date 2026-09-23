import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_page.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/data/dashboard_repository.dart';
import 'package:parley_android/design_system/ds_button.dart';
import 'package:parley_android/design_system/ds_card.dart';
import 'package:parley_android/design_system/ds_chart.dart';
import 'package:parley_android/design_system/ds_status_state.dart';
import 'package:parley_android/design_system/ds_well.dart';
import 'package:parley_android/design_system/ds_list_tile.dart';
import 'package:parley_android/design_system/ds_page_header.dart';
import 'package:parley_android/design_system/ds_refresh.dart';
import 'package:parley_android/design_system/ds_metric_bar.dart';
import 'package:parley_android/design_system/ds_section_header.dart';
import 'package:parley_android/design_system/ds_stat_tile.dart';
import 'package:parley_android/models/dashboard_summary.dart';
import 'package:parley_android/providers/auth_provider.dart';
import 'package:parley_android/utils/app_routes.dart';
import 'package:parley_android/utils/error_copy.dart';
import 'package:parley_android/design_system/ds_text.dart';

/// The Home tab — the **Focal** archetype
/// (`docs/principles/screen-archetypes.md`).
///
/// One hero at scale, then a bento of two sizes. The rule that shapes it: a
/// grid of equal tiles is not a hierarchy, it is a list wearing a grid's
/// clothes, and the eye has nowhere to land. So there is exactly one thing
/// here that is large, one tile that is wide, and pairs beneath it — three
/// weights, in descending order, which is what makes the screen readable at a
/// glance instead of scannable at length.
///
/// What to imitate when you replace it:
///
///   * the hero answers "what is this and what do I do next?" without a
///     scroll, and carries the screen's single primary action;
///   * every block spans the full content width, gutter to gutter, so nothing
///     floats in a narrow column;
///   * the bento's tiles size themselves from their own content rather than
///     from a `childAspectRatio`, which is what lets them grow when the reader
///     doubles their text size instead of overflowing;
///   * the figures under the hero are fetched, so the screen has a loading
///     state and a failure state rather than only a happy one.
///
/// That last point is the one most home screens skip. A screen watching a
/// synchronous provider has nothing that can be late and nothing that can
/// fail, so it never grows the two states it will need the first time it is
/// pointed at a real backend — and the reader copying this file inherits the
/// omission. The summary here is a real fetch against the mock backend, and
/// its three outcomes are all on screen:
///
///   * **loading** — the same tiles and meter drawn as bones, so the layout
///     cannot drift out of shape with the content it stands in for;
///   * **error** — one sentence a person can act on, from [errorCopyFor],
///     never the exception's own text, over a retry;
///   * **loaded** — the figures.
///
/// Pull-to-refresh is on the whole screen for the same reason it is on the
/// Library: it is the gesture people already try.
class DashboardPage extends ConsumerWidget {
  final VoidCallback onOpenDrawer;

  const DashboardPage({super.key, required this.onOpenDrawer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final summary = ref.watch(dashboardSummaryProvider);

    return DSRefresh(
      onRefresh: () => ref.refresh(dashboardSummaryProvider.future),
      child: CustomScrollView(
        slivers: [
          DSPageHeader.compactSliver(
            title: 'Rocketship',
            leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: onOpenDrawer,
              tooltip: 'Open navigation menu',
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              DSGutter.of(context),
              0,
              DSGutter.of(context),
              context.design.space.xs,
            ),
            sliver: SliverList.list(
              children: [
                _HeroCard(greetingName: user?.displayName),
                context.design.space.verticalMd,
                // The three outcomes, in one switch. `AsyncError` first so a
                // stale value does not keep a failed refresh off the screen.
                switch (summary) {
                  AsyncError(:final error) => _SummaryError(
                    error: error,
                    onRetry: () => ref.invalidate(dashboardSummaryProvider),
                  ),
                  AsyncValue(:final value?) => _SummaryCard(summary: value),
                  _ => const _SummaryCard(summary: null),
                },
              ],
            ),
          ),
          const SliverToBoxAdapter(child: DSSectionHeader(label: 'Explore')),
          SliverPadding(
            // The nav bar floats over this page, so the last tile has to clear
            // the pill as well as the gutter. `paddingOf` carries the bar's
            // height here because the Scaffold extends its body under it.
            padding: EdgeInsets.fromLTRB(
              DSGutter.of(context),
              context.design.space.xs,
              DSGutter.of(context),
              context.design.space.xl + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverList.list(
              children: [
                _WideTile(
                  tile: _feature,
                  onTap: () => context.push(_feature.route),
                ),
                context.design.space.verticalMd,
                // Pairs, not a grid delegate. A `SliverGrid` would have to be
                // told a height, and the only height that survives a doubled
                // text scale is the one the tile's own content asks for —
                // which is what `IntrinsicHeight` around a stretched row
                // computes, for both tiles at once, so the pair stays level.
                for (final (row, pair) in _pairs.indexed) ...[
                  _TilePair(
                    pair: pair,
                    firstIndex: 2 + row * 2,
                    onTap: (tile) => context.push(tile.route),
                  ),
                  if (row < _pairs.length - 1) context.design.space.verticalMd,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

typedef _Tile = ({String title, String caption, IconData icon, String route});

/// The one wide tile. Its weight is the point: it is the destination a new
/// reader should open first, and it looks like it.
const _feature = (
  title: 'Design system',
  caption: '60 components, one editorial theme, graded by ui_lint',
  icon: Icons.palette_outlined,
  route: '/library/detail/1',
);

/// The pairs below them — narrower, and deliberately fewer than the six that
/// were here before. Six equal tiles means none of them mattered.
const _pairs = <List<_Tile>>[
  [
    (
      title: 'Auth & paywall',
      caption: 'Pre-wired modules',
      icon: Icons.workspace_premium_outlined,
      route: AppRoutes.paywall,
    ),
    (
      title: 'Analytics',
      caption: 'One console seam',
      icon: Icons.insights_outlined,
      route: '/library/detail/3',
    ),
  ],
  [
    (
      title: 'Appearance',
      caption: 'Theme + density',
      icon: Icons.contrast,
      route: AppRoutes.appearance,
    ),
    (
      title: 'About',
      caption: 'Build + licences',
      icon: Icons.info_outline,
      route: AppRoutes.about,
    ),
  ],
];

class _HeroCard extends StatelessWidget {
  final String? greetingName;

  const _HeroCard({this.greetingName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DSCard(
      // The one hero on the screen, and the only gradient. It is built from
      // two palette roles rather than from a near-invisible blend: the one
      // this replaces sat under a 1/255 step in two of three channels.
      style: DSCardStyle(fillGradient: context.palette.primaryGradient),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: context.palette.primaryForeground),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YOUR APP',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                color: context.palette.primaryForeground,
              ),
            ),
            context.design.space.verticalSm,
            // Genuinely larger, not slightly larger. The hero is the one
            // place on the screen where the type steps up, and a title one
            // size above the tiles reads as a slightly bigger tile rather
            // than as a hero.
            Text(
              greetingName == null
                  ? 'A Flutter app that already builds'
                  : 'Welcome back, $greetingName',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: context.design.type.emphasisWeight,
                color: context.palette.primaryForeground,
              ),
            ),
            context.design.space.verticalSm,
            DSText(
              'Riverpod, Dio and a mock backend, a platform-adaptive design '
              'system, and a harness that grades its own output. Edit '
              'lib/screens/home/dashboard_page.dart to make it yours.',
              role: DSTextRole.bodySupport,
              style: DSTextStyle(color: context.palette.primaryForeground),
            ),
            context.design.space.verticalLg,
            // One primary action, full width — but not the primary
            // *variant*: that now carries the same brand gradient as the
            // card behind it and would disappear into it. Secondary still
            // reads as the one thing to do here; it just does not fight
            // the card for the gradient.
            DSButton(
              variant: DSButtonVariant.secondary,
              label: 'Get started',
              icon: Icons.rocket_launch_rounded,
              fullWidth: true,
              onPressed: () => context.push(AppRoutes.libraryDetailAt(0)),
            ),
            context.design.space.verticalSm,
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: DSButton(
                variant: DSButtonVariant.ghost,
                label: 'Read the docs',
                size: DSButtonSize.sm,
                // A ghost label is the accent, and the card behind it is the
                // accent's gradient: without this it vanishes into the card.
                style: DSButtonStyle(
                  labelColor: context.palette.primaryForeground,
                ),
                onPressed: () => context.push(AppRoutes.about),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The summary, and the bones it is drawn as while it loads.
///
/// One widget for both states rather than two, because a skeleton built
/// separately from the thing it stands in for is a skeleton that stops
/// matching it on the first edit. `summary` being null *is* the loading
/// state: every child takes `loading` and draws its own bones at its own
/// size, so the card does not change height when the figures arrive and the
/// page does not jump under the reader's thumb.
class _SummaryCard extends StatelessWidget {
  final DashboardSummary? summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final loading = summary == null;

    return DSCard(
      variant: DSCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DSStatTileGrid(
            columns: 2,
            children: [
              DSStatTile(
                label: 'In your library',
                value: loading ? '' : '${summary!.itemCount}',
                loading: loading,
                markColor: context.palette.chart[0],
              ),
              DSStatTile(
                label: 'Shelves',
                value: loading ? '' : '${summary!.categoryCount}',
                loading: loading,
                markColor: context.palette.chart[1],
              ),
            ],
          ),
          context.design.space.verticalLg,
          // A bar rather than a ring: the comparison is one value against one
          // ceiling, and position along a common scale is read more
          // accurately than angle.
          DSMetricBar(
            label: 'Finished',
            value: loading ? 0 : summary!.completedFraction,
            valueText: loading
                ? ''
                : '${summary!.completedCount} of ${summary!.itemCount}',
            loading: loading,
          ),
          if (loading || summary!.itemsByCategory.length > 1) ...[
            context.design.space.verticalLg,
            _ByShelf(counts: loading ? _shelfBones : summary!.itemsByCategory),
          ],
        ],
      ),
    );
  }
}

/// The shape the shelf chart holds while the real counts are in flight.
///
/// Bones rather than an absent chart, for the reason the whole card is one
/// widget: a section that appears when the data lands moves everything under
/// it, and the reader's thumb is already on the way to whatever was there.
const _shelfBones = <String, int>{'—': 3, '——': 2, '———': 4};

/// The collection split across its shelves.
///
/// A bar rather than a line: the axis is a set of names, not a run, and the
/// reader is comparing four quantities to each other. It is also the one
/// chart on this screen a reader can be expected to interrogate, which is why
/// the scrub is left on.
class _ByShelf extends StatelessWidget {
  final Map<String, int> counts;

  const _ByShelf({required this.counts});

  @override
  Widget build(BuildContext context) {
    final shelves = counts.keys.toList()..sort();
    return DSChart.bar(
      // The short plot: inside a summary card the chart is one of four things
      // being read, and at the full height it becomes the card.
      style: DSChartStyle(height: context.design.component.chartHeightSm),
      series: [
        DSSeries(
          name: 'Items',
          values: [for (final shelf in shelves) counts[shelf]!.toDouble()],
        ),
      ],
      labels: shelves,
    );
  }
}

/// The failure, said in a sentence rather than in an exception.
///
/// The copy comes from [errorCopyFor] rather than from this file, so the home
/// screen and the Library answer a dropped connection with the same words.
class _SummaryError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _SummaryError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final copy = errorCopyFor(error);

    return DSCard(
      variant: DSCardVariant.outlined,
      child: DSErrorState(
        icon: copy.icon,
        title: copy.message,
        actionLabel: copy.actionLabel,
        onRetry: onRetry,
      ),
    );
  }
}

/// The wide tile: a row, so it reads as a different kind of thing from the
/// square pair below rather than as a stretched one.
class _WideTile extends StatelessWidget {
  final _Tile tile;
  final VoidCallback onTap;

  const _WideTile({required this.tile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DSCard(
      variant: DSCardVariant.outlined,
      padding: EdgeInsets.all(context.design.space.lg),
      onTap: onTap,
      child: Row(
        children: [
          DSWell(icon: tile.icon, size: DSWellSize.lg),
          context.design.space.horizontalLg,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tile.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: context.design.type.emphasisWeight,
                  ),
                ),
                DSText(tile.caption, role: DSTextRole.bodyDetail),
              ],
            ),
          ),
          context.design.space.horizontalSm,
          Icon(chevronIconFor(context), color: context.palette.mutedForeground),
        ],
      ),
    );
  }
}

/// Two narrow tiles, the same height as each other whatever their text does.
class _TilePair extends StatelessWidget {
  final List<_Tile> pair;
  final int firstIndex;
  final ValueChanged<_Tile> onTap;

  const _TilePair({
    required this.pair,
    required this.firstIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (offset, tile) in pair.indexed) ...[
            if (offset > 0) context.design.space.horizontalMd,
            Expanded(
              child: _NarrowTile(tile: tile, onTap: () => onTap(tile)),
            ),
          ],
        ],
      ),
    );
  }
}

class _NarrowTile extends StatelessWidget {
  final _Tile tile;
  final VoidCallback onTap;

  const _NarrowTile({required this.tile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DSCard(
      variant: DSCardVariant.outlined,
      padding: EdgeInsets.all(context.design.space.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tile.icon, size: context.design.component.iconSize),
          context.design.space.verticalSm,
          Text(
            tile.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: context.design.type.emphasisWeight,
            ),
          ),
          DSText(tile.caption, role: DSTextRole.bodyDetail),
        ],
      ),
    );
  }
}
