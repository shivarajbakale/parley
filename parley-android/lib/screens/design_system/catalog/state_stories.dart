import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/catalog/story.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Empty, loading and in-flight — the three screens that get written last and
/// are seen first.
final stateCategory = DSCatalogCategory(
  name: 'State',
  icon: Icons.hourglass_empty,
  components: [
    DSComponentDemo(
      name: 'DSEmptyState',
      summary:
          'Nothing to show, which kind of nothing it is, and what to do '
          'when the content failed.',
      stories: [
        DSStory(
          title: 'Nothing yet',
          note:
              'Say what belongs here, then offer exactly one way to create '
              'it. A title and a message, not one long centred paragraph.',
          builder: (context) => DSEmptyState(
            icon: Icons.folder_open_outlined,
            title: 'No documents yet',
            message: 'Anything you create shows up here.',
            actionLabel: 'New document',
            onAction: () => showDSSnackBar(context, message: 'Created'),
          ),
        ),
        DSStory(
          title: 'Nothing found',
          note:
              'A different state from empty: the filter excluded '
              'everything, so the action clears the filter rather than '
              'creating a record the user already has.',
          builder: (context) => DSEmptyState.noResults(
            query: 'budget 2019',
            onAction: () => showDSSnackBar(context, message: 'Filters cleared'),
          ),
        ),
        DSStory(
          title: 'Nothing left',
          note:
              'A finished queue is a positive, not a failure, and it is '
              'drawn as one.',
          builder: (context) => const DSEmptyState.done(
            message: 'Every item in the queue has been handled.',
          ),
        ),
        DSStory(
          title: 'What failed, and the retry',
          note:
              'The retry is the content. A message a user cannot act on is '
              'a dead end.',
          builder: (context) => DSErrorState(
            title: 'Couldn’t load your library',
            message: 'Check your connection and try again.',
            onRetry: () => showDSSnackBar(context, message: 'Retrying…'),
          ),
        ),
        DSStory(
          title: 'With the technical detail behind a disclosure',
          note:
              'A support conversation needs the real error and a user does '
              'not. It is collapsed, expands in place, and is selectable.',
          builder: (context) => DSErrorState(
            title: 'Couldn’t load your library',
            message: 'Check your connection and try again.',
            detailsText: 'SocketException: Failed host lookup (errno = 8)',
            onRetry: () => showDSSnackBar(context, message: 'Retrying…'),
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSIllustration',
      summary:
          'A drawn scene for the screens that happen once — and the seam a '
          'designer\'s art drops into.',
      stories: [
        DSStory(
          title: 'The six kinds',
          note:
              'Six, not sixteen: the states a generic app reaches. A state '
              'that maps onto none of them wants its own delegate, not a '
              'seventh drawing in the kit.',
          builder: (context) => Wrap(
            spacing: context.design.space.lg,
            runSpacing: context.design.space.lg,
            children: const [
              DSIllustration(
                kind: DSIllustrationKind.empty,
                size: DSIllustrationSize.small,
              ),
              DSIllustration(
                kind: DSIllustrationKind.search,
                size: DSIllustrationSize.small,
              ),
              DSIllustration(
                kind: DSIllustrationKind.offline,
                size: DSIllustrationSize.small,
              ),
              DSIllustration(
                kind: DSIllustrationKind.done,
                size: DSIllustrationSize.small,
                tone: DSTone.success,
              ),
              DSIllustration(
                kind: DSIllustrationKind.locked,
                size: DSIllustrationSize.small,
                tone: DSTone.warning,
              ),
              DSIllustration(
                kind: DSIllustrationKind.error,
                size: DSIllustrationSize.small,
                tone: DSTone.error,
              ),
            ],
          ),
        ),
        DSStory(
          title: 'Three boxes',
          note:
              'The box is reserved at its final size before the drawing '
              'arrives, so a title underneath never gets pushed down.',
          builder: (context) => Wrap(
            spacing: context.design.space.lg,
            runSpacing: context.design.space.lg,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: const [
              DSIllustration(
                kind: DSIllustrationKind.empty,
                size: DSIllustrationSize.small,
              ),
              DSIllustration(kind: DSIllustrationKind.empty),
              DSIllustration(
                kind: DSIllustrationKind.empty,
                size: DSIllustrationSize.large,
              ),
            ],
          ),
        ),
        DSStory(
          title: 'The tier an empty state opts into',
          note:
              'Passing illustration: replaces the glyph in its well. Reach '
              'for it on first run and on a full-screen failure, not above '
              'every filtered list.',
          builder: (context) => DSEmptyState(
            illustration: DSIllustrationKind.empty,
            title: 'No documents yet',
            message: 'Anything you create shows up here.',
            actionLabel: 'New document',
            onAction: () => showDSSnackBar(context, message: 'Created'),
          ),
        ),
        DSStory(
          title: 'A designer\'s art, through a delegate',
          note:
              'One DSIllustrationScope above the app replaces all six '
              'drawings with a Lottie or a Rive file, without the kit '
              'depending on either package and without touching a call site.',
          builder: (context) => DSIllustrationScope(
            delegate: const _GlyphIllustrationDelegate(),
            child: Wrap(
              spacing: context.design.space.lg,
              runSpacing: context.design.space.lg,
              children: const [
                DSIllustration(
                  kind: DSIllustrationKind.offline,
                  size: DSIllustrationSize.small,
                ),
                DSIllustration(
                  kind: DSIllustrationKind.done,
                  size: DSIllustrationSize.small,
                  tone: DSTone.success,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSSkeleton',
      summary: 'Loading, when the shape of what is coming is known.',
      stories: [
        DSStory(
          title: 'Derived from the real widget',
          note:
              'The same tree, bones or content. It cannot drift out of shape '
              'with what it stands for, because it *is* what it stands for.',
          builder: (context) => const _SkeletonDemo(),
        ),
        DSStory(
          title: 'A list of rows',
          note:
              'DSSkeletonList when the rows have not arrived and the row '
              'shape is the only thing known.',
          builder: (context) =>
              const DSSkeletonList(itemCount: 3, shrinkWrap: true),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSRefresh',
      summary: 'The pull that asks for the data again.',
      stories: [
        DSStory(
          title: 'On a list too short to scroll',
          note:
              'Two rows in a box that fits them. A raw RefreshIndicator is '
              'dead here — nothing overscrolls — which is why this one '
              'forces the physics for the subtree. Pull it.',
          builder: (context) => const _RefreshDemo(),
        ),
        DSStory(
          title: 'Off',
          note:
              'enabled: false returns the child untouched. For data that is '
              'local and cannot go stale: better no gesture than one that '
              'resolves instantly and teaches the user it does nothing.',
          builder: (context) => const _RefreshDemo(enabled: false),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSProgressIndicator',
      summary: 'An operation in flight.',
      stories: [
        DSStory(
          title: 'Linear',
          note:
              'Determinate whenever the total is known — an indeterminate '
              'bar on a known-length job is a decision not to measure it.',
          builder: (context) => Column(
            children: [
              const DSProgressIndicator.linear(),
              context.design.space.verticalMd,
              const DSProgressIndicator.linear(value: 0.62),
            ],
          ),
        ),
        DSStory(
          title: 'Circular',
          note:
              'Inside a button or beside a row — a full-screen spinner is a '
              'DSLoadingState instead.',
          builder: (context) => Row(
            children: [
              const DSProgressIndicator.circular(),
              context.design.space.horizontalLg,
              const DSProgressIndicator.circular(value: 0.35),
            ],
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSProgressRing',
      summary: 'One value against a known ceiling, round.',
      stories: [
        DSStory(
          title: 'Three sizes',
          note:
              'Stroke is not proportional to diameter. Three designed pairs '
              'keep the compact and the hero recognisably the same object.',
          builder: (context) => Wrap(
            spacing: context.design.space.lg,
            runSpacing: context.design.space.lg,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: const [
              DSProgressRing(
                label: 'Storage',
                value: 68.4,
                max: 128,
                valueText: '68.4 GB',
                caption: 'of 128 GB',
                size: DSProgressRingSize.compact,
              ),
              DSProgressRing(
                label: 'Storage',
                value: 68.4,
                max: 128,
                valueText: '68.4 GB',
                caption: 'of 128 GB',
              ),
            ],
          ),
        ),
        DSStory(
          title: 'The hero, stacked',
          note:
              'Value inside the ring, label below. One per screen — at Ø56 a '
              'number inside the ring is 11pt and dies at text scale 2.',
          builder: (context) => const DSProgressRing.stacked(
            label: 'Weekly goal',
            value: 0.72,
            valueText: '72%',
          ),
        ),
        DSStory(
          title: 'Over target',
          note:
              'The arc caps at full and changes colour rather than wrapping a '
              'second lap. The number tells the truth at 114%.',
          builder: (context) => const DSProgressRing(
            label: 'Budget',
            value: 1.14,
            valueText: '114%',
            caption: 'of the monthly cap',
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSChart',
      summary:
          'The shape of a run of numbers \u2014 a trend beside a figure, a line '
          'over a run, bars across categories. Press and hold to scrub.',
      stories: [
        DSStory(
          title: 'Sparklines in a column',
          note:
              'One row of tiles is what a sparkline is for: the figure carries '
              'the value and the strip carries the direction, so four of them '
              'read as a comparison rather than as four charts.',
          builder: (context) => Column(
            children: [
              for (final row in const [
                (
                  'Revenue',
                  '\u00a348.2k',
                  <double>[31, 34, 30, 38, 42, 40, 48],
                ),
                ('Sessions', '12,904', <double>[64, 61, 66, 59, 57, 52, 49]),
                ('Signups', '318', <double>[12, 18, 15, 22, 27, 25, 31]),
              ])
                Padding(
                  padding: EdgeInsets.only(bottom: context.design.space.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: DSStatTile(
                          label: row.$1,
                          value: row.$2,
                          size: DSStatTileSize.compact,
                        ),
                      ),
                      SizedBox(
                        width: 96,
                        child: DSChart.sparkline(values: row.$3, name: row.$1),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        DSStory(
          title: 'One line',
          note:
              'The wash under the line is on for a single series and off for '
              'more than one: two translucent fills over each other make a '
              'third colour that stands for nothing.',
          builder: (context) => const DSChart.line(
            series: [
              DSSeries(name: 'Revenue', values: [31, 34, 30, 38, 42, 40, 48]),
            ],
            labels: ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
          ),
        ),
        DSStory(
          title: 'Two lines',
          note:
              'Reach for a second series only when the reader is comparing '
              'them. The hues come from the identity by series name, so '
              '\u201cRevenue\u201d is the same colour here as on the dashboard.',
          builder: (context) => const DSChart.line(
            series: [
              DSSeries(name: 'Revenue', values: [31, 34, 30, 38, 42, 40, 48]),
              DSSeries(name: 'Costs', values: [22, 26, 25, 24, 29, 27, 30]),
            ],
            labels: ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
          ),
        ),
        DSStory(
          title: 'Grouped bars',
          note:
              'Categories rather than a run, and the axis starts at zero \u2014 a '
              'bar is read by its area, so a cropped baseline lies about the '
              'ratio between two bars.',
          builder: (context) => const DSChart.bar(
            series: [
              DSSeries(name: 'Revenue', values: [31, 42, 38, 48]),
              DSSeries(name: 'Costs', values: [22, 25, 29, 30]),
            ],
            labels: ['Q1', 'Q2', 'Q3', 'Q4'],
          ),
        ),
        DSStory(
          title: 'Stacked bars',
          note:
              'Stack when the total is the subject and the split is the '
              'detail. Group when the reader is comparing the parts to each '
              'other rather than to the whole.',
          builder: (context) => const DSChart.bar(
            grouping: DSBarGrouping.stacked,
            series: [
              DSSeries(name: 'Revenue', values: [31, 42, 38, 48]),
              DSSeries(name: 'Costs', values: [22, 25, 29, 30]),
            ],
            labels: ['Q1', 'Q2', 'Q3', 'Q4'],
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSMetricBar',
      summary: 'One value against a known ceiling, linear — and stacked.',
      stories: [
        DSStory(
          title: 'A column of four',
          note:
              'Bars stacked in a column share a baseline, which is the entire '
              'reason to reach for one instead of four rings.',
          builder: (context) {
            final chart = context.palette.chart;
            return Column(
              children: [
                DSMetricBar(
                  label: 'Documents',
                  value: 42,
                  max: 128,
                  fillColor: chart[0],
                ),
                context.design.space.verticalMd,
                DSMetricBar(
                  label: 'Media',
                  value: 31,
                  max: 128,
                  fillColor: chart[1],
                ),
                context.design.space.verticalMd,
                DSMetricBar(
                  label: 'Cache',
                  value: 0.5,
                  max: 128,
                  fillColor: chart[2],
                ),
                context.design.space.verticalMd,
                const DSMetricBar(
                  label: 'Backups',
                  value: 146,
                  max: 128,
                  valueText: '114%',
                ),
              ],
            );
          },
        ),
        DSStory(
          title: 'Stacked, with a legend',
          note:
              'Parts of a whole. The 2dp gap is not decoration — without it '
              'two adjacent categories read as one segment.',
          builder: (context) {
            final chart = context.palette.chart;
            return DSMetricBar.stacked(
              label: 'Storage',
              valueText: '128 GB',
              segments: [
                DSMetricSegment(label: 'Docs', value: 42, color: chart[0]),
                DSMetricSegment(label: 'Media', value: 31, color: chart[1]),
                DSMetricSegment(label: 'Other', value: 27, color: chart[2]),
              ],
            );
          },
        ),
        DSStory(
          title: 'Thin, loading and disabled',
          note:
              'Thin drops the inline value: at h4 a figure beside the bar is '
              'the larger of the two and the bar stops reading as primary.',
          builder: (context) => Column(
            children: [
              const DSMetricBar(
                label: 'Secondary',
                value: 0.34,
                size: DSMetricBarSize.thin,
              ),
              context.design.space.verticalMd,
              const DSMetricBar(label: 'Syncing', value: 0.4, loading: true),
              context.design.space.verticalMd,
              const DSMetricBar(label: 'Archived', value: 0.6, enabled: false),
            ],
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSSegmentedProgress',
      summary: 'Where the user is in a countable sequence.',
      stories: [
        DSStory(
          title: 'The bar, at three of five',
          note:
              'The current segment is wider as well as a different tone. The '
              'width is the point — colour alone would fail 1.4.1 on a six '
              'point bar.',
          builder: (context) => const DSSegmentedProgress(
            label: 'Payment',
            currentStep: 3,
            totalSteps: 5,
          ),
        ),
        DSStory(
          title: 'An error and a skipped step',
          note:
              'A skipped step stays in the track, dashed. Dropping it would '
              'make the count dishonest, and the count is the whole reason '
              'this is not a bar.',
          builder: (context) => const DSSegmentedProgress(
            label: 'Checkout',
            currentStep: 4,
            totalSteps: 5,
            errorSteps: {2},
            skippedSteps: {3},
          ),
        ),
        DSStory(
          title: 'Dots',
          note:
              'For a carousel or a sequence whose steps have no names. Never '
              'for a form — a form\u2019s steps have names.',
          builder: (context) =>
              const DSSegmentedProgress.dots(currentStep: 3, totalSteps: 5),
        ),
        DSStory(
          title: 'Labelled, and tappable',
          note:
              'Reached steps accept a tap only when onStepTap is given; '
              'upcoming ones never do, so the component never implies a tap '
              'it will not honour.',
          builder: (context) => DSSegmentedProgress.labelled(
            currentStep: 3,
            stepLabels: const ['Cart', 'Ship', 'Pay', 'Review', 'Done'],
            onStepTap: (step) =>
                showDSSnackBar(context, message: 'Back to step $step'),
          ),
        ),
      ],
    ),
  ],
);

class _SkeletonDemo extends StatefulWidget {
  const _SkeletonDemo();

  @override
  State<_SkeletonDemo> createState() => _SkeletonDemoState();
}

class _SkeletonDemoState extends State<_SkeletonDemo> {
  bool _loading = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DSSkeleton(
          enabled: _loading,
          child: DSCard(
            child: Row(
              children: [
                DSAvatar.fromName(name: 'Ada Lovelace'),
                context.design.space.horizontalMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ada Lovelace',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Edited the roadmap · 2h ago',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        context.design.space.verticalSm,
        DSButton(
          label: _loading ? 'Show the content' : 'Show the bones',
          variant: DSButtonVariant.ghost,
          size: DSButtonSize.sm,
          onPressed: () => setState(() => _loading = !_loading),
        ),
      ],
    );
  }
}

/// What an app's own delegate looks like, without a dependency to demonstrate
/// it: one glyph per kind, drawn at the box the style resolved.
///
/// A real one returns `Lottie.asset(...)` or a `RiveAnimation` and reads
/// `progress` rather than ignoring it — the value is already 1 under reduced
/// motion, so a delegate never has to ask about `MediaQuery`.
class _GlyphIllustrationDelegate extends DSIllustrationDelegate {
  const _GlyphIllustrationDelegate();

  @override
  Widget build(
    BuildContext context,
    DSIllustrationKind kind,
    double progress,
    DSIllustrationStyle style,
  ) => Opacity(
    opacity: progress,
    child: Icon(
      switch (kind) {
        DSIllustrationKind.empty => Icons.inbox_outlined,
        DSIllustrationKind.search => Icons.travel_explore_outlined,
        DSIllustrationKind.offline => Icons.cloud_off_outlined,
        DSIllustrationKind.done => Icons.verified_outlined,
        DSIllustrationKind.locked => Icons.lock_outline,
        DSIllustrationKind.error => Icons.report_gmailerrorred_outlined,
      },
      size: style.size,
      color: style.accentColor,
    ),
  );
}

/// A short list inside a bounded box, so the pull is demonstrable on a stage
/// that is not itself a scrollable.
///
/// The refresh counts rather than reloading anything: what the story is about
/// is that the gesture fires at all on content this short.
class _RefreshDemo extends StatefulWidget {
  const _RefreshDemo({this.enabled = true});

  final bool enabled;

  @override
  State<_RefreshDemo> createState() => _RefreshDemoState();
}

class _RefreshDemoState extends State<_RefreshDemo> {
  int _refreshes = 0;

  @override
  Widget build(BuildContext context) {
    final space = context.design.space;

    return SizedBox(
      height: 168,
      child: DSRefresh(
        enabled: widget.enabled,
        onRefresh: () async {
          await Future<void>.delayed(context.design.motion.slow);
          if (mounted) setState(() => _refreshes++);
        },
        child: ListView(
          padding: EdgeInsets.symmetric(vertical: space.sm),
          children: [
            DSListTile(
              title: widget.enabled ? 'Pull me down' : 'Nothing to pull',
              subtitle: 'Refreshed $_refreshes times',
              leading: const Icon(Icons.sync),
            ),
            const DSListTile(
              title: 'Second row',
              subtitle: 'The two together still fit the box',
              leading: Icon(Icons.short_text),
            ),
          ],
        ),
      ),
    );
  }
}
