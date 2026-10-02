import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/insight_data.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:parley_android/utils/app_routes.dart';

/// The reading recap — the **Insight** archetype
/// (`docs/principles/screen-archetypes.md`).
///
/// One number, one picture, one sentence that says what the number means. In
/// that order, because the order *is* the archetype: an Insight is not a Focal
/// screen with a chart on it. A Focal screen asks the reader to do the next
/// thing; an Insight asks them to understand something, and the moment it
/// grows a second subject it has become a dashboard — a screen that gets
/// opened once.
///
/// What to imitate when you replace it:
///
///   * the **headline** is in the reader's units (`4h 12m`, not `252`) and its
///     **comparison** sits inside the same tile, not in a caption two blocks
///     below it. A delta that wraps away from the figure it modifies has
///     become a second number;
///   * the **period** is written out — `Mon 25 – Sun 31 August`, not "this
///     week". A figure whose denominator is a guess is one the reader quietly
///     distrusts;
///   * there is exactly **one plot**. Two is a dashboard;
///   * the **sentence** under the chart is the part every analytics screen
///     skips and the only part a person repeats to somebody else. It is
///     written, not generated — a template with a number substituted into it
///     is the chart read aloud rather than a reading of it;
///   * **nothing pins.** There is no `DSPinnedActionBar` here on purpose: an
///     Insight is read, not submitted, and a pinned bar over a recap steals
///     the height the chart needs while implying a decision the screen is not
///     asking for. The handover is an ordinary control at the end of the
///     scroll;
///   * the finding is in **text as well as in the plot**. A chart is silent to
///     a screen reader and invisible in a screenshot description, so the
///     headline, the sentence and the breakdown rows each carry it. `DSChart`
///     derives a semantics label, and that is the floor rather than the
///     answer.
///
/// The period control is the one piece of state, and it moves everything: the
/// headline, the comparison, the plot, the sentence and the breakdown are all
/// derived from the selected [InsightRecap]. A recap whose chart changes while
/// its headline does not is the defect that makes a reader stop believing the
/// screen, and deriving all five from one object is what makes it
/// unrepresentable.
///
/// Delete this file and `insight_data.dart` with the rest of the
/// design-system demo surface when the app ships a real recap.
class InsightPage extends StatefulWidget {
  const InsightPage({super.key, this.initialPeriod = InsightPeriod.week});

  /// Which period the screen opens on. Exists for the gates: `test/_screens.dart`
  /// registers one entry per period, because a screen the probe only ever
  /// sees one state of is a screen whose other state is measured by nothing.
  final InsightPeriod initialPeriod;

  @override
  State<InsightPage> createState() => _InsightPageState();
}

class _InsightPageState extends State<InsightPage> {
  late InsightPeriod _period = widget.initialPeriod;

  void _setPeriod(InsightPeriod next) {
    if (_period == next) return;
    setState(() => _period = next);
  }

  @override
  Widget build(BuildContext context) {
    final recap = recapFor(_period);
    final space = context.design.space;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const DSLargeAppBar(
            title: 'Your reading',
            subtitle:
                'One figure, one plot and one sentence about what they mean.',
          ),
          // Pinned for the same reason the Library's filter strip is: the
          // period is the denominator of every number below it, and a reader
          // who has scrolled to the breakdown cannot check what it is a
          // breakdown *of* if the control has gone.
          DSPinnedHeader(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                DSGutter.of(context),
                0,
                DSGutter.of(context),
                space.md,
              ),
              child: DSSegmentedButton<InsightPeriod>(
                sizing: DSSegmentedSizing.fill,
                segments: [
                  for (final p in InsightPeriod.values)
                    DSSegment<InsightPeriod>(value: p, label: periodLabel(p)),
                ],
                selected: _period,
                onChanged: _setPeriod,
              ),
            ),
          ),
          DSGutter.sliver(
            sliver: SliverList.list(
              children: [
                _Headline(recap: recap),
                SizedBox(height: space.md),
                _PlotAndReading(recap: recap),
                SizedBox(height: space.lg),
                _Breakdown(recap: recap),
                SizedBox(height: space.lg),
                // The handover. Named in the archetype's last rule: a recap
                // that ends on itself is a screen the reader closes, so the
                // last thing on it is the way onward rather than a summary of
                // what they have just read.
                DSButton(
                  label: 'Read something new',
                  variant: DSButtonVariant.secondary,
                  fullWidth: true,
                  icon: Icons.auto_stories_outlined,
                  onPressed: () => context.push(AppRoutes.blog),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: space.xl + MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }
}

/// The figure, its comparison and its span, in one tile.
///
/// One widget rather than three stacked ones because the adjacency is the
/// rule: `DSStatTile` keeps the value, the delta and the note inside a single
/// block at every text scale, and a layout that composed them by hand would
/// let the delta wrap to a line of its own on the first reader who doubles
/// their type.
class _Headline extends StatelessWidget {
  const _Headline({required this.recap});

  final InsightRecap recap;

  @override
  Widget build(BuildContext context) {
    final space = context.design.space;

    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DSStatTile(
            label: 'Time read',
            value: formatMinutes(recap.minutes),
            // The chip carries the direction and the size of the change, and
            // nothing else. `DSStatTile` draws its delta on one line beside
            // the value, so a label long enough to be a sentence is a label
            // that ellipsises away at the first larger type size.
            deltaLabel: recap.deltaBadge,
            trend: recap.deltaPercent >= 0 ? DSTrend.up : DSTrend.down,
          ),
          SizedBox(height: space.sm),
          // The words of the comparison and the dates it covers, in a line
          // that wraps. This is the adjacency the archetype's rule is about:
          // the baseline and the span are what a reader checks before they
          // believe the percentage, and both survive a doubled text size here
          // in a way neither would inside the tile's own single-line row.
          DSText(supportingLine(recap), role: DSTextRole.bodySupport),
        ],
      ),
    );
  }
}

/// The one plot, and the one sentence directly beneath it.
///
/// They share a card on purpose. "Directly under the chart" is the rule, and
/// a sentence in a section of its own two gaps below the plot is a sentence
/// about a different subject as far as the eye is concerned.
class _PlotAndReading extends StatelessWidget {
  const _PlotAndReading({required this.recap});

  final InsightRecap recap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final space = context.design.space;

    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DSChart.line(
            series: [
              DSSeries(
                name: 'Time read',
                // Plotted in hours, held in minutes. The axis picks round
                // steps from the numbers it is given, and round steps of
                // minutes are 20 and 40 — which read `0h`, `0h`, `1h`, `1h`
                // once they are labelled in the unit the headline uses. In
                // hours the same steps land on halves, and every label on the
                // axis is a different number again.
                values: [for (final v in recap.values) v / 60],
                // Pinned to the series name rather than to the period, so the
                // plot does not change colour when the control is switched.
                colorKey: 'reading',
              ),
            ],
            labels: recap.labels,
            // The derived sentence would read "Time read, 7 points, 12 to 71"
            // — true, and in the wrong unit. Minutes are what the fixture
            // holds; hours and minutes are what the reader was given at the
            // top of the screen, and a chart that disagrees with the headline
            // about its own units is worse than a silent one.
            // The axis and the readout are different jobs. `1.5h` is the
            // shortest label that is still unambiguous on a value axis; `1h
            // 11m` is what a finger on the point asked for, and four of those
            // down the gutter is a chart with a paragraph beside it.
            axisFormat: (value) => value == value.roundToDouble()
                ? '${value.toStringAsFixed(0)}h'
                : '${value.toStringAsFixed(1)}h',
            valueFormat: (value) => formatMinutes((value * 60).round()),
            semanticsLabel:
                'Time read per ${recap.period == InsightPeriod.week ? 'day' : 'week'}, '
                '${recap.labels.length} points, '
                'from ${formatMinutes(recap.values.reduce((a, b) => a < b ? a : b).round())} '
                'to ${formatMinutes(recap.values.reduce((a, b) => a > b ? a : b).round())}.',
          ),
          SizedBox(height: space.md),
          Text(
            recap.reading,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: palette.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

/// The same total, split and ranked.
///
/// A bar per row rather than three numbers in a column: the ranking is the
/// content, and a reader should not have to compare three strings to find it.
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.recap});

  final InsightRecap recap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final space = context.design.space;
    final largest = recap.leadingSlice.minutes.toDouble();

    return DSSection(
      label: 'Where it went',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final slice in recap.slices) ...[
            DSMetricBar(
              label: slice.label,
              value: slice.minutes.toDouble(),
              // Against the largest row rather than the total, so the shortest
              // bar is still a bar. Scaled to the total, a 55-minute row in a
              // 946-minute month is four pixels of colour, which is a row with
              // no bar on it and a column of numbers again.
              max: largest,
              valueText: formatMinutes(slice.minutes),
              fillColor: palette
                  .chart[recap.slices.indexOf(slice) % palette.chart.length],
            ),
            SizedBox(height: space.md),
          ],
        ],
      ),
    );
  }
}
