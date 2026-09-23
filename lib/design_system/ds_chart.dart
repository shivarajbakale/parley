// ds-tier: 1 — atom

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// What a chart is drawing, which decides its height and its axes.
///
/// A *paired* kind, in the sense of the component contract: the plot height,
/// the axis reserves and whether there is a grid all move together, because a
/// sparkline is not a small line chart — it is a chart with no axes at all,
/// and giving it axes at a smaller size produces labels nobody can read.
enum DSChartKind {
  /// A trend beside a figure. No axes, no grid, no labels — the shape is the
  /// whole message, and the number it belongs to is already on screen.
  sparkline,

  /// A value against a continuous run: seven days, twelve months.
  line,

  /// A value against named categories, one bar per category per series.
  bar,
}

/// How several series share one category.
enum DSBarGrouping {
  /// Side by side. Comparing series to each other.
  grouped,

  /// One on top of the other. Comparing the total, with the parts visible.
  stacked,
}

/// One run of numbers with a name.
///
/// The colour is deliberately **not** a field. A caller who picks a colour
/// picks a different one on the next screen, and `ui_lint`'s `hardcoded-color`
/// rule would fail the literal anyway. The hue comes from
/// `DSChart.seriesColor(palette, colorKey ?? name)` — a stable hash into
/// `palette.chart` — so "Revenue" is one hue everywhere in the app without
/// anybody maintaining a map.
@immutable
class DSSeries {
  const DSSeries({required this.name, required this.values, this.colorKey});

  /// What the series is called, in the tooltip and in the semantics label.
  final String name;

  /// One number per category. Every series in a chart must be the same length
  /// as the chart's labels; a shorter one is a caller bug, and [DSChart]
  /// asserts it rather than silently plotting a truncated line.
  final List<double> values;

  /// Overrides which category hue this series takes. Pass it when the display
  /// name is localised — a series whose colour changes with the app's language
  /// is a series whose colour means nothing.
  final String? colorKey;
}

/// [DSChart]'s appearance, as data.
///
/// Obeys the four rules in [DSComponentStyle]: every field nullable, defaults
/// read from the spec inside [resolve] and nowhere else, a real [lerp], and no
/// behaviour. The value formatter is not here for the same reason
/// `DSStatTile`'s is not — it is a function, and a style object carrying
/// behaviour is a controller with a bad name.
@immutable
class DSChartStyle extends DSComponentStyle<DSChartStyle> {
  const DSChartStyle({
    this.height,
    this.gridColor,
    this.axisLabelStyle,
    this.lineWidth,
    this.dotRadius,
    this.areaOpacity,
    this.barWidth,
    this.barRadius,
    this.valueAxisWidth,
    this.categoryAxisHeight,
    this.scrubLineColor,
    this.scrubLineWidth,
    this.scrubBandColor,
    this.tooltipFill,
    this.tooltipTextStyle,
    this.tooltipRadius,
    this.tooltipPadding,
    this.enterDuration,
    this.enterCurve,
  });

  /// The plot's height. A chart cannot take it from its content — a line
  /// through seven points is as tall as it is told to be — so the kit decides
  /// it per kind rather than letting every call site guess.
  final double? height;

  /// The horizontal rules behind the plot. `outlineSoft`, never `outline`: a
  /// grid at edge weight competes with the data drawn on it.
  final Color? gridColor;

  /// Axis numbers and category names. `textTertiary` — an axis is scaffolding,
  /// and a chart whose labels weigh as much as its line has two subjects.
  final TextStyle? axisLabelStyle;

  /// The stroke of a plotted line.
  final double? lineWidth;

  /// The dot marking the point being read. Only that point carries one: a line
  /// with a dot on every sample is a dotted line with a line through it.
  final double? dotRadius;

  /// How much of the series colour washes the area under a single line. Zero
  /// for a multi-series chart, where two translucent fills over each other
  /// make a third colour that means nothing.
  final double? areaOpacity;

  /// One bar's width, and the corner it is cut with.
  final double? barWidth;
  final double? barRadius;

  /// The room kept for the value axis down the leading edge and the category
  /// axis along the bottom.
  ///
  /// Reserved rather than measured, which is what makes the plot rectangle
  /// predictable — and a predictable plot rectangle is what lets the scrub map
  /// a finger position to a point index without asking the chart library where
  /// it drew anything.
  final double? valueAxisWidth;
  final double? categoryAxisHeight;

  /// The rule that follows the finger during a scrub.
  final Color? scrubLineColor;
  final double? scrubLineWidth;

  /// The column drawn behind the bar being read.
  ///
  /// A bar chart cannot use the rule: `fl_chart` refuses vertical lines on a
  /// bar plot, and a rule down the middle of a bar would be drawn through the
  /// thing it is pointing at anyway. So the bar kind marks its selection with
  /// a ground behind the bar instead — same job, same token family, a shape
  /// the bar sits in rather than a line across it.
  ///
  /// `outlineSoft`, like the grid: the mark says *which*, and a mark that
  /// competes with the bar it is behind has answered a question nobody asked.
  final Color? scrubBandColor;

  /// The readout. `inverseSurface`, like a snack bar: it is a momentary thing
  /// laid over content, and a tooltip on the page's own surface disappears
  /// into the card behind it.
  final Color? tooltipFill;
  final TextStyle? tooltipTextStyle;
  final double? tooltipRadius;
  final EdgeInsetsGeometry? tooltipPadding;

  /// How the plot animates when its data changes.
  final Duration? enterDuration;
  final Curve? enterCurve;

  @override
  DSChartStyle merge(DSChartStyle? other) {
    if (other == null) return this;
    return DSChartStyle(
      height: other.height ?? height,
      gridColor: other.gridColor ?? gridColor,
      axisLabelStyle: other.axisLabelStyle ?? axisLabelStyle,
      lineWidth: other.lineWidth ?? lineWidth,
      dotRadius: other.dotRadius ?? dotRadius,
      areaOpacity: other.areaOpacity ?? areaOpacity,
      barWidth: other.barWidth ?? barWidth,
      barRadius: other.barRadius ?? barRadius,
      valueAxisWidth: other.valueAxisWidth ?? valueAxisWidth,
      categoryAxisHeight: other.categoryAxisHeight ?? categoryAxisHeight,
      scrubLineColor: other.scrubLineColor ?? scrubLineColor,
      scrubLineWidth: other.scrubLineWidth ?? scrubLineWidth,
      scrubBandColor: other.scrubBandColor ?? scrubBandColor,
      tooltipFill: other.tooltipFill ?? tooltipFill,
      tooltipTextStyle: other.tooltipTextStyle ?? tooltipTextStyle,
      tooltipRadius: other.tooltipRadius ?? tooltipRadius,
      tooltipPadding: other.tooltipPadding ?? tooltipPadding,
      enterDuration: other.enterDuration ?? enterDuration,
      enterCurve: other.enterCurve ?? enterCurve,
    );
  }

  @override
  DSChartStyle copyWith({
    double? height,
    Color? gridColor,
    TextStyle? axisLabelStyle,
    double? lineWidth,
    double? dotRadius,
    double? areaOpacity,
    double? barWidth,
    double? barRadius,
    double? valueAxisWidth,
    double? categoryAxisHeight,
    Color? scrubLineColor,
    double? scrubLineWidth,
    Color? scrubBandColor,
    Color? tooltipFill,
    TextStyle? tooltipTextStyle,
    double? tooltipRadius,
    EdgeInsetsGeometry? tooltipPadding,
    Duration? enterDuration,
    Curve? enterCurve,
  }) => DSChartStyle(
    height: height ?? this.height,
    gridColor: gridColor ?? this.gridColor,
    axisLabelStyle: axisLabelStyle ?? this.axisLabelStyle,
    lineWidth: lineWidth ?? this.lineWidth,
    dotRadius: dotRadius ?? this.dotRadius,
    areaOpacity: areaOpacity ?? this.areaOpacity,
    barWidth: barWidth ?? this.barWidth,
    barRadius: barRadius ?? this.barRadius,
    valueAxisWidth: valueAxisWidth ?? this.valueAxisWidth,
    categoryAxisHeight: categoryAxisHeight ?? this.categoryAxisHeight,
    scrubLineColor: scrubLineColor ?? this.scrubLineColor,
    scrubLineWidth: scrubLineWidth ?? this.scrubLineWidth,
    scrubBandColor: scrubBandColor ?? this.scrubBandColor,
    tooltipFill: tooltipFill ?? this.tooltipFill,
    tooltipTextStyle: tooltipTextStyle ?? this.tooltipTextStyle,
    tooltipRadius: tooltipRadius ?? this.tooltipRadius,
    tooltipPadding: tooltipPadding ?? this.tooltipPadding,
    enterDuration: enterDuration ?? this.enterDuration,
    enterCurve: enterCurve ?? this.enterCurve,
  );

  @override
  DSChartStyle lerp(DSChartStyle? other, double t) {
    if (other == null) return this;
    return DSChartStyle(
      height: lerpDouble(height, other.height, t),
      gridColor: Color.lerp(gridColor, other.gridColor, t),
      axisLabelStyle: TextStyle.lerp(axisLabelStyle, other.axisLabelStyle, t),
      lineWidth: lerpDouble(lineWidth, other.lineWidth, t),
      dotRadius: lerpDouble(dotRadius, other.dotRadius, t),
      areaOpacity: lerpDouble(areaOpacity, other.areaOpacity, t),
      barWidth: lerpDouble(barWidth, other.barWidth, t),
      barRadius: lerpDouble(barRadius, other.barRadius, t),
      valueAxisWidth: lerpDouble(valueAxisWidth, other.valueAxisWidth, t),
      categoryAxisHeight: lerpDouble(
        categoryAxisHeight,
        other.categoryAxisHeight,
        t,
      ),
      scrubLineColor: Color.lerp(scrubLineColor, other.scrubLineColor, t),
      scrubLineWidth: lerpDouble(scrubLineWidth, other.scrubLineWidth, t),
      scrubBandColor: Color.lerp(scrubBandColor, other.scrubBandColor, t),
      tooltipFill: Color.lerp(tooltipFill, other.tooltipFill, t),
      tooltipTextStyle: TextStyle.lerp(
        tooltipTextStyle,
        other.tooltipTextStyle,
        t,
      ),
      tooltipRadius: lerpDouble(tooltipRadius, other.tooltipRadius, t),
      tooltipPadding: EdgeInsetsGeometry.lerp(
        tooltipPadding,
        other.tooltipPadding,
        t,
      ),
      enterDuration: t < 0.5 ? enterDuration : other.enterDuration,
      enterCurve: t < 0.5 ? enterCurve : other.enterCurve,
    );
  }

  static DSChartStyle resolve(
    BuildContext context,
    DSChartKind kind, [
    DSChartStyle? own,
  ]) {
    final palette = context.palette;
    final design = context.design;
    final component = design.component;
    final text = Theme.of(context).textTheme;
    final sparkline = kind == DSChartKind.sparkline;

    // The axes are *reserved* space, and reserved space does not grow with the
    // reader's type size unless somebody grows it. Left alone, "50" wraps to
    // two lines inside a 36-point gutter at text scale 2 and the category
    // names are cut in half by the bottom of the box. The plot keeps its own
    // height and the component gets taller, which is the trade a chart should
    // make: shrinking the plot to fit bigger labels is how a chart becomes a
    // band of axis with a line in it.
    final labelSize = text.labelSmall?.fontSize ?? component.iconSizeMicro;
    final scale = MediaQuery.textScalerOf(context).scale(labelSize) / labelSize;
    final valueAxis = sparkline ? 0.0 : component.chartValueAxisWidth * scale;
    final categoryAxis = sparkline
        ? 0.0
        : component.chartCategoryAxisHeight * scale;

    final specDefaults = DSChartStyle(
      height: sparkline
          ? component.sparklineHeight
          : component.chartHeight +
                (categoryAxis - component.chartCategoryAxisHeight),
      gridColor: palette.borderSoft,
      axisLabelStyle: text.labelSmall?.copyWith(color: palette.mutedForeground),
      lineWidth: component.chartLineWidth,
      dotRadius: component.chartDotRadius,
      areaOpacity: sparkline ? 0.22 : 0.14,
      barWidth: component.chartBarWidth,
      barRadius: context.radiusOf(AppShape.control),
      valueAxisWidth: valueAxis,
      categoryAxisHeight: categoryAxis,
      scrubLineColor: palette.border,
      scrubLineWidth: component.chartScrubLineWidth,
      scrubBandColor: palette.borderSoft,
      tooltipFill: palette.inverseBackground,
      tooltipTextStyle: text.labelMedium?.copyWith(
        color: palette.inverseForeground,
      ),
      tooltipRadius: context.radiusOf(AppShape.control),
      tooltipPadding: EdgeInsets.symmetric(
        horizontal: design.space.sm,
        vertical: design.space.xs,
      ),
      enterDuration: design.motion.normal,
      enterCurve: design.motion.standard,
    );

    return resolveStyle(context: context, specDefaults: specDefaults, own: own);
  }
}

/// A plotted shape: a trend beside a figure, a line over a run, bars over
/// categories.
///
/// **Use when** the *shape* of a set of numbers is the point — how a value
/// moved over seven days, how four categories compare. **Instead:**
/// `DSMetricBar` when there is one value against a maximum and the shape is a
/// single proportion; `DSProgressRing` when that proportion is the screen's
/// subject; `DSStatTile` when the number itself is the message and the trend
/// is a delta beside it. A chart drawn for three numbers is three numbers made
/// harder to read.
///
/// ## Why this wraps `fl_chart` rather than painting
///
/// Axis ticks that land on round numbers, curve overshoot, label collision and
/// touch hit-testing are each a week of work and none of them is this app's
/// subject. The package is pinned to an exact version rather than a caret
/// range, because it paints the pixels a golden baseline records.
///
/// The wrap is total: `fl_chart`'s types appear in no signature here, so a
/// call site never imports it, and swapping it out is a change to one file.
///
/// ## The scrub is a long press, and the reason is the gesture arena
///
/// `fl_chart`'s own touch handling is a `PanGestureRecognizer`, and a pan does
/// not claim a gesture until the finger has travelled `kPanSlop` — twice the
/// `kTouchSlop` an axis-locked drag recogniser inside a scrollable needs. The
/// scroll therefore wins: with the library's touch left on, a drag across a
/// plot sitting in a list scrolled the list 470 points and read nothing.
///
/// That is worse than having no reading gesture. It is one that works on a
/// screen with nothing to scroll and silently stops working on the screen it
/// ships in, which is the failure nobody files a bug about.
///
/// A long press resolves the arena before any drag threshold is reached, so
/// press-hold-slide always reaches the chart. It is also what iOS Stocks and
/// Health do, and it leaves a plain drag meaning what a plain drag should
/// mean — scroll the page, turn to the next tab.
///
/// ## The plot runs left to right under RTL too
///
/// `fl_chart` cannot mirror its plot, and a half-mirrored chart — labels
/// flipped, line not — reads as a bug rather than as a translation. The axis
/// labels are still laid out by the ambient locale; only the plot's direction
/// is pinned.
class DSChart extends StatefulWidget {
  /// A trend with no axes, sized to sit beside a figure.
  const DSChart.sparkline({
    super.key,
    required List<double> values,
    String name = 'series',
    this.style,
    this.semanticsLabel,
    this.valueFormat,
    this.axisFormat,
    this.enabled = true,
  }) : kind = DSChartKind.sparkline,
       series = const [],
       _sparklineValues = values,
       _sparklineName = name,
       labels = const [],
       grouping = DSBarGrouping.grouped;

  /// A value against a continuous run — seven days, twelve months.
  const DSChart.line({
    super.key,
    required this.series,
    required this.labels,
    this.style,
    this.semanticsLabel,
    this.valueFormat,
    this.axisFormat,
    this.enabled = true,
  }) : kind = DSChartKind.line,
       _sparklineValues = const [],
       _sparklineName = '',
       grouping = DSBarGrouping.grouped;

  /// A value against named categories, one bar per category per series.
  const DSChart.bar({
    super.key,
    required this.series,
    required this.labels,
    this.grouping = DSBarGrouping.grouped,
    this.style,
    this.semanticsLabel,
    this.valueFormat,
    this.axisFormat,
    this.enabled = true,
  }) : kind = DSChartKind.bar,
       _sparklineValues = const [],
       _sparklineName = '';

  final DSChartKind kind;

  /// The plotted runs. Empty for a sparkline, which carries its numbers
  /// directly; [resolvedSeries] is the one list every path reads.
  final List<DSSeries> series;

  /// The chart-scale colour a series key lands on — the same key on the same
  /// colour every build. `String.hashCode` is not guaranteed stable across
  /// runs, so the hash is spelled out.
  static Color seriesColor(Palette palette, String key) {
    var h = 0;
    for (final unit in key.codeUnits) {
      h = (h * 31 + unit) & 0x7fffffff;
    }
    return palette.chart[h % palette.chart.length];
  }

  /// One name per category, along the bottom axis. Empty for a sparkline.
  final List<String> labels;

  final DSBarGrouping grouping;

  final DSChartStyle? style;

  /// What a screen reader hears. A chart is silent by default — it is a
  /// picture — so one is derived from the data when none is passed. Pass one
  /// when the derived sentence would be wrong: a currency, a percentage, a
  /// series whose direction is good when it falls.
  final String? semanticsLabel;

  /// How a number reads in the tooltip and on the value axis.
  final String Function(double value)? valueFormat;

  /// How a number reads on the value axis, when that is not how it reads in
  /// the readout.
  ///
  /// The two are different jobs. A readout is a number somebody asked for and
  /// wants in full — `4h 12m`, `$1,240.00`. An axis is scaffolding, and the
  /// same formatter there produces four labels the width of the plot: at a
  /// doubled type size they wrap inside their gutter and paint through each
  /// other, which is the defect this exists for. Pass the shortest label that
  /// is still unambiguous — `4h`, `$1.2k` — and leave [valueFormat] to say
  /// the whole thing when a finger is on the point.
  ///
  /// Falls back to [valueFormat], which falls back to the plain number, so a
  /// caller whose numbers are already short passes neither.
  final String Function(double value)? axisFormat;

  /// Whether the scrub responds. False leaves a chart that is purely a
  /// picture — which is the right answer inside a row that is itself
  /// pressable, where a long press already means something.
  final bool enabled;

  final List<double> _sparklineValues;
  final String _sparklineName;

  /// The series every kind plots, with the sparkline's bare numbers folded in.
  List<DSSeries> get resolvedSeries => kind == DSChartKind.sparkline
      ? [DSSeries(name: _sparklineName, values: _sparklineValues)]
      : series;

  @override
  State<DSChart> createState() => _DSChartState();
}

/// The scrub's readout, so a test can distinguish what the finger is reading
/// from what the value axis happens to be labelled.
const readoutKey = ValueKey<String>('ds-chart-readout');

class _DSChartState extends State<DSChart> {
  /// The point under the finger, or null when nobody is scrubbing.
  int? _scrubbed;

  /// The plot's geometry, recomputed every layout. The scrub reads it to turn
  /// a finger position into an index.
  double _plotStart = 0;
  double _plotWidth = 0;

  int get _count {
    final series = widget.resolvedSeries;
    return series.isEmpty ? 0 : series.first.values.length;
  }

  void _scrubTo(double dx) {
    if (_plotWidth <= 0 || _count == 0) return;
    final t = ((dx - _plotStart) / _plotWidth).clamp(0.0, 1.0);
    // A bar owns a band of the plot; a line point owns a position on it.
    final index = widget.kind == DSChartKind.bar
        ? math.min((t * _count).floor(), _count - 1)
        : (t * (_count - 1)).round();
    if (index == _scrubbed) return;
    AppHaptics.selection();
    setState(() => _scrubbed = index);
  }

  String _format(double value) => _formatWith(widget.valueFormat, value);

  /// The axis's own formatter, falling back to the readout's.
  String _formatAxis(double value) =>
      _formatWith(widget.axisFormat ?? widget.valueFormat, value);

  String _formatWith(String Function(double)? format, double value) {
    if (format != null) return format(value);
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  /// The sentence a screen reader reads instead of the picture.
  String _describe() {
    final series = widget.resolvedSeries;
    if (series.isEmpty || series.first.values.isEmpty) return 'Empty chart';
    final parts = series.map((s) {
      final values = s.values;
      final first = values.first;
      final last = values.last;
      final direction = last > first
          ? 'trending up'
          : last < first
          ? 'trending down'
          : 'flat';
      return '${s.name}, ${values.length} points, '
          '${_format(first)} to ${_format(last)}, $direction';
    });
    return parts.join('. ');
  }

  @override
  Widget build(BuildContext context) {
    final series = widget.resolvedSeries;
    final resolved = _fitValueAxis(
      context,
      DSChartStyle.resolve(context, widget.kind, widget.style),
      series,
    );

    assert(
      series.every((s) => s.values.length == _count),
      'every series in a chart plots the same number of points',
    );
    assert(
      widget.kind == DSChartKind.sparkline ||
          widget.labels.length == _count ||
          _count == 0,
      'a chart needs one label per point',
    );

    final chart = LayoutBuilder(
      builder: (context, constraints) {
        _plotStart = resolved.valueAxisWidth ?? 0;
        _plotWidth = math.max(0, constraints.maxWidth - _plotStart);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: _plot(context, resolved, series)),
            if (_scrubbed != null)
              _Readout(
                // Named so a test can tell the readout's "30" from the value
                // axis's "30". Without it the only way to assert what the
                // scrub says is to assert what the axis says.
                key: readoutKey,
                style: resolved,
                label: widget.kind == DSChartKind.sparkline
                    ? null
                    : widget.labels[_scrubbed!],
                rows: [
                  for (final s in series)
                    (
                      color: DSChart.seriesColor(
                        context.palette,
                        s.colorKey ?? s.name,
                      ),
                      name: s.name,
                      value: _format(s.values[_scrubbed!]),
                    ),
                ],
                anchor: _anchorFor(_scrubbed!),
                plotWidth: constraints.maxWidth,
              ),
          ],
        );
      },
    );

    return Semantics(
      label: widget.semanticsLabel ?? _describe(),
      container: true,
      excludeSemantics: true,
      child: SizedBox(
        height: resolved.height,
        // The plot is pinned left-to-right; see the class comment.
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: widget.enabled && _count > 0
              // ui-lint: allow pressable-floor — the scrub is a reading
              // gesture, not a control. Nothing is invoked, nothing changes,
              // and there is no target to focus: a press ring drawn around a
              // whole plot marks the plot, and the ripple DSPressable exists
              // to give would fire on every point the finger crosses. The
              // feedback this needs is the readout and the selection tick,
              // and it has both.
              ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPressStart: (d) => _scrubTo(d.localPosition.dx),
                  onLongPressMoveUpdate: (d) => _scrubTo(d.localPosition.dx),
                  onLongPressEnd: (_) => setState(() => _scrubbed = null),
                  onLongPressCancel: () => setState(() => _scrubbed = null),
                  child: chart,
                )
              : chart,
        ),
      ),
    );
  }

  /// Where the readout points, as a fraction of the plot's width.
  double _anchorFor(int index) {
    if (_count == 0) return 0;
    final within = widget.kind == DSChartKind.bar
        ? (index + 0.5) / _count
        : _count == 1
        ? 0.5
        : index / (_count - 1);
    return _plotStart + within * _plotWidth;
  }

  Widget _plot(
    BuildContext context,
    DSChartStyle style,
    List<DSSeries> series,
  ) {
    final palette = context.palette;
    final motion = context.design.motion;
    Color colorOf(DSSeries s) =>
        DSChart.seriesColor(palette, s.colorKey ?? s.name);

    final bounds = _Bounds.of(series, baselineAtZero: _isBarKind);
    final titles = _titles(context, style, bounds);

    if (_isBarKind) {
      return BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: bounds.max,
          minY: bounds.min,
          barTouchData: const BarTouchData(enabled: false),
          gridData: _grid(style, bounds),
          titlesData: titles,
          borderData: FlBorderData(show: false),
          barGroups: [
            for (var i = 0; i < _count; i++)
              BarChartGroupData(
                x: i,
                barsSpace: context.design.space.hairline,
                barRods: widget.grouping == DSBarGrouping.stacked
                    ? [_stackedRod(context, style, bounds, series, i, colorOf)]
                    : [
                        for (final s in series)
                          BarChartRodData(
                            toY: s.values[i],
                            color: colorOf(s),
                            width: style.barWidth,
                            borderRadius: _capRadius(style),
                            // The scrub's mark. The line kind draws a rule
                            // under the finger and the bar kind cannot —
                            // `fl_chart` will not paint a vertical line on a
                            // bar plot — so the bar being read stands in a
                            // ground instead. Without it the readout named a
                            // value and nothing on the plot said which bar it
                            // had come from, which is a scrub the reader has
                            // to take on trust.
                            backDrawRodData: _scrubBand(style, bounds, i),
                          ),
                      ],
              ),
          ],
        ),
        duration: style.enterDuration ?? motion.instant,
        curve: style.enterCurve ?? motion.standard,
      );
    }

    final single = series.length == 1;
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (_count - 1).toDouble(),
        minY: bounds.min,
        maxY: bounds.max,
        lineTouchData: const LineTouchData(enabled: false),
        gridData: _grid(style, bounds),
        titlesData: titles,
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          verticalLines: [
            if (_scrubbed != null)
              VerticalLine(
                x: _scrubbed!.toDouble(),
                color: style.scrubLineColor,
                strokeWidth: style.scrubLineWidth ?? 1,
              ),
          ],
        ),
        lineBarsData: [
          for (final s in series)
            LineChartBarData(
              spots: [
                for (var i = 0; i < s.values.length; i++)
                  FlSpot(i.toDouble(), s.values[i]),
              ],
              color: colorOf(s),
              barWidth: style.lineWidth ?? 2,
              isCurved: true,
              curveSmoothness: 0.25,
              preventCurveOverShooting: true,
              isStrokeCapRound: true,
              isStrokeJoinRound: true,
              dotData: FlDotData(
                show: _scrubbed != null,
                checkToShowDot: (spot, _) => spot.x == _scrubbed?.toDouble(),
                getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                  radius: style.dotRadius,
                  color: colorOf(s),
                  strokeWidth: style.scrubLineWidth ?? 1,
                  strokeColor: palette.card,
                ),
              ),
              // One line gets a wash under it. Two translucent fills over each
              // other make a third colour that stands for nothing.
              belowBarData: BarAreaData(
                show: single,
                color: colorOf(s).withValues(alpha: style.areaOpacity ?? 0),
              ),
            ),
        ],
      ),
      duration: style.enterDuration ?? motion.instant,
      curve: style.enterCurve ?? motion.standard,
    );
  }

  bool get _isBarKind => widget.kind == DSChartKind.bar;

  /// The ground behind the bar at [index], drawn only while it is the one
  /// being read.
  ///
  /// Full height on purpose: a band that stopped at the bar's own top would
  /// be invisible behind it, and the mark has to be findable by a reader
  /// whose finger is covering the bar.
  BackgroundBarChartRodData _scrubBand(
    DSChartStyle style,
    _Bounds bounds,
    int index,
  ) => BackgroundBarChartRodData(
    show: _scrubbed == index,
    fromY: bounds.min,
    toY: bounds.max,
    color: style.scrubBandColor,
  );

  /// How much of the category axis one label may take.
  ///
  /// A bar owns a band, so the axis divides by the number of bands. A line's
  /// points sit *on* the divisions, so there is one fewer gap than there are
  /// points.
  double _slotWidth(TitleMeta meta) => _isBarKind
      ? meta.parentAxisSize / math.max(1, _count)
      : meta.parentAxisSize / math.max(1, _count - 1);

  /// The style with its value gutter widened to whatever the axis's own
  /// labels turn out to need.
  ///
  /// The token is a starting width, not an answer: it was chosen for `0`,
  /// `25`, `50`, and the caller who formats an axis in hours or in thousands
  /// hands it `0.5h` and `$1.2k`. Left at the token those wrap inside the
  /// gutter and break mid-word — a defect the probe catches and the eye reads
  /// as a broken chart. Measured, the gutter grows by the few points the
  /// labels actually need and the plot gives them up.
  DSChartStyle _fitValueAxis(
    BuildContext context,
    DSChartStyle style,
    List<DSSeries> series,
  ) {
    if (widget.kind == DSChartKind.sparkline) return style;
    final bounds = _Bounds.of(series, baselineAtZero: _isBarKind);
    // A zero interval would be a loop with no end. `_Bounds` derives one from
    // the spread, and a chart of one repeated value has no spread.
    if (bounds.interval <= 0) return style;
    final scaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;
    for (var v = bounds.min; v <= bounds.max + 1e-9; v += bounds.interval) {
      final painter = TextPainter(
        text: TextSpan(text: _formatAxis(v), style: style.axisLabelStyle),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
    }
    // The gap between the gutter and the plot is drawn as the label's own
    // trailing padding, so the gutter has to hold both.
    final needed = widest + context.design.space.sm;
    final current = style.valueAxisWidth ?? 0;
    return needed <= current ? style : style.copyWith(valueAxisWidth: needed);
  }

  /// How many category slots one label needs before it stops colliding with
  /// its neighbour, as a stride: 1 draws every label, 2 draws every other one.
  ///
  /// A chart cannot narrow a word. At a doubled type size "Mon" is wider than
  /// a seventh of the plot, and the two answers available are an ellipsis —
  /// `M…`, which is not a label — or fewer labels. Every chart that survives
  /// contact with a reader who enlarges their type picks the second, so this
  /// measures the widest label the chart was given and thins the axis until
  /// that one fits.
  ///
  /// The line kind needs half a slot more than the bar kind. Its first and
  /// last points sit *on* the plot's edges, so `fitInside` pins those labels
  /// fully inside the plot, and a pinned label reaches half its own width
  /// further towards its neighbour than a centred one does. That is the
  /// overlap this measurement is really for: it was there at every text size,
  /// not only the large ones.
  int _labelStride(BuildContext context, DSChartStyle style) {
    if (_count < 2 || widget.labels.isEmpty || _plotWidth <= 0) return 1;
    final scaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;
    for (final label in widget.labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style.axisLabelStyle),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
    }
    final slot = _plotWidth / math.max(1, _isBarKind ? _count : _count - 1);
    if (slot <= 0) return 1;
    final needed =
        (widest + context.design.space.xs) * (_isBarKind ? 1.0 : 1.5);
    return math.max(1, (needed / slot).ceil());
  }

  /// A bar is cut at the top and square at the foot. Rounding the foot lifts
  /// the bar off the baseline it is read against, which is the one line in a
  /// bar chart that has to be believed.
  static BorderRadius _capRadius(DSChartStyle style) =>
      BorderRadius.vertical(top: Radius.circular(style.barRadius ?? 0));

  BarChartRodData _stackedRod(
    BuildContext context,
    DSChartStyle style,
    _Bounds bounds,
    List<DSSeries> series,
    int index,
    Color Function(DSSeries) colorOf,
  ) {
    var running = 0.0;
    final stack = <BarChartRodStackItem>[];
    for (final s in series) {
      final next = running + s.values[index];
      stack.add(BarChartRodStackItem(running, next, colorOf(s)));
      running = next;
    }
    return BarChartRodData(
      toY: running,
      width: style.barWidth,
      borderRadius: _capRadius(style),
      rodStackItems: stack,
      color: colorOf(series.first),
      // A stack is one rod, so it takes the same ground a grouped bar does.
      backDrawRodData: _scrubBand(style, bounds, index),
    );
  }

  FlGridData _grid(DSChartStyle style, _Bounds bounds) => FlGridData(
    show: widget.kind != DSChartKind.sparkline,
    drawVerticalLine: false,
    horizontalInterval: bounds.interval,
    getDrawingHorizontalLine: (_) => FlLine(
      color: style.gridColor,
      strokeWidth: context.design.component.hairlineWidth,
    ),
  );

  FlTitlesData _titles(
    BuildContext context,
    DSChartStyle style,
    _Bounds bounds,
  ) {
    if (widget.kind == DSChartKind.sparkline) {
      return const FlTitlesData(show: false);
    }
    final stride = _labelStride(context, style);
    return FlTitlesData(
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: style.valueAxisWidth ?? 0,
          interval: bounds.interval,
          getTitlesWidget: (value, meta) => Padding(
            // `sm`, not `xs`. This is the gap between the value gutter and
            // the plot, and the plot's first category label is pinned flush
            // to its left edge — at `xs` the two boxes met, which the probe
            // reads as four points of one drawn through the other.
            padding: EdgeInsetsDirectional.only(end: context.design.space.sm),
            child: Text(
              _formatAxis(value),
              style: style.axisLabelStyle,
              textAlign: TextAlign.end,
            ),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: style.categoryAxisHeight ?? 0,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final index = value.round();
            if (index < 0 || index >= widget.labels.length) {
              return const SizedBox.shrink();
            }
            // Thinned rather than shortened. A label the axis has no room for
            // is left out; the ones that remain are whole words.
            if (index % stride != 0) return const SizedBox.shrink();
            // Two separate things a category label does wrong when it is
            // left alone. It is given whatever names the data has, so
            // "Case studies" on a three-shelf chart is wider than a third of
            // the plot and paints through its neighbour — hence the slot and
            // the ellipsis. And the label for the first point is centred on
            // the plot's own left edge, so half of it hangs over the value
            // axis and paints through the axis number — hence `fitInside`,
            // which pins a label that would leave the plot back inside it.
            return SideTitleWidget(
              meta: meta,
              space: context.design.space.xs,
              // Only a line needs pinning. Its points sit *on* the plot's
              // edges, so the first label is centred on the boundary and half
              // of it hangs over the value axis. A bar's label is centred in
              // its band, which is already inside the plot — pinning it there
              // only shoves it into its neighbour.
              fitInside: _isBarKind && stride == 1
                  ? SideTitleFitInsideData.disable()
                  : SideTitleFitInsideData.fromTitleMeta(meta),
              child: ConstrainedBox(
                // A cap, not a width. Sized to the slot outright, a one-letter
                // weekday becomes a 55-point box that its neighbour's box
                // runs into the moment `fitInside` nudges either of them.
                constraints: BoxConstraints(
                  maxWidth: _slotWidth(meta) * stride - context.design.space.xs,
                ),
                child: Text(
                  widget.labels[index],
                  style: style.axisLabelStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The vertical extent a chart plots over, and the gap between its grid lines.
///
/// Round numbers, deliberately: an axis whose labels read 0, 25, 50 is read at
/// a glance, and one that reads 0, 23.4, 46.8 is read twice.
@immutable
class _Bounds {
  const _Bounds(this.min, this.max, this.interval);

  final double min;
  final double max;
  final double interval;

  static _Bounds of(List<DSSeries> series, {required bool baselineAtZero}) {
    final values = [for (final s in series) ...s.values];
    if (values.isEmpty) return const _Bounds(0, 1, 1);

    var low = values.reduce(math.min);
    var high = values.reduce(math.max);
    // A bar is read by its area, so its axis starts at zero or it lies about
    // the ratio between two bars.
    if (baselineAtZero) low = math.min(0, low);
    if (high == low) high = low + 1;

    final interval = _niceStep((high - low) / 3);
    final flooredLow = (low / interval).floorToDouble() * interval;
    final ceiledHigh = (high / interval).ceilToDouble() * interval;
    return _Bounds(flooredLow, ceiledHigh, interval);
  }

  /// The nearest 1, 2 or 5 times a power of ten — the steps a reader counts in.
  static double _niceStep(double raw) {
    if (raw <= 0) return 1;
    final magnitude = math
        .pow(10, (math.log(raw) / math.ln10).floor())
        .toDouble();
    final normalised = raw / magnitude;
    final step = normalised <= 1
        ? 1.0
        : normalised <= 2
        ? 2.0
        : normalised <= 5
        ? 5.0
        : 10.0;
    return step * magnitude;
  }
}

/// The tooltip the scrub drags along the plot.
///
/// Its own widget rather than the chart library's: the library's tooltip takes
/// a `TextStyle` and a colour per call and knows nothing about the resolution
/// chain, so a themed app would have had one surface that ignored its theme.
class _Readout extends StatelessWidget {
  const _Readout({
    super.key,
    required this.style,
    required this.label,
    required this.rows,
    required this.anchor,
    required this.plotWidth,
  });

  final DSChartStyle style;
  final String? label;
  final List<({Color color, String name, String value})> rows;
  final double anchor;
  final double plotWidth;

  @override
  Widget build(BuildContext context) {
    final space = context.design.space;
    final dot = context.design.component.chartDotRadius * 2;

    final card = Container(
      padding: style.tooltipPadding,
      decoration: BoxDecoration(
        color: style.tooltipFill,
        borderRadius: BorderRadius.circular(style.tooltipRadius ?? 0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Text(
              label!,
              style: style.tooltipTextStyle?.copyWith(
                fontWeight: context.design.type.emphasisWeight,
              ),
            ),
          for (final row in rows)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (rows.length > 1) ...[
                  Container(
                    width: dot,
                    height: dot,
                    decoration: BoxDecoration(
                      color: row.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: space.xs),
                ],
                Text(
                  rows.length > 1 ? '${row.name} ${row.value}' : row.value,
                  style: style.tooltipTextStyle,
                ),
              ],
            ),
        ],
      ),
    );

    // Measured against the plot rather than the screen: a readout that runs
    // off its own chart is the one state a tooltip must not have.
    final maxShift = math.max(0.0, plotWidth - _estimatedWidth(context));
    final start = (anchor - _estimatedWidth(context) / 2).clamp(0.0, maxShift);

    return PositionedDirectional(top: 0, start: start, child: card);
  }

  /// A tooltip cannot know its own width before it is laid out, and the clamp
  /// has to happen before that. An estimate from the text is the honest
  /// version of a guess: it is wrong by a few points, and a few points is
  /// inside the padding.
  double _estimatedWidth(BuildContext context) {
    final longest = rows
        .map((r) => rows.length > 1 ? '${r.name} ${r.value}' : r.value)
        .followedBy([label ?? ''])
        .map((s) => s.length)
        .reduce(math.max);
    final size = style.tooltipTextStyle?.fontSize ?? context.design.space.md;
    return longest * size * 0.62 + context.design.space.lg;
  }
}
