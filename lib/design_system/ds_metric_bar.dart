// ds-tier: 2 — molecule

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:parley_android/design_system/_ratio_transition.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_pressable.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_skeleton.dart';
import 'package:parley_android/theme/app_typography.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The three designed bar heights.
///
/// [thin] is for a bar under a list row where the bar is secondary to the row.
/// It is the one size that does not show its value inline: at h4 with a figure
/// beside it, the bar is the smaller of the two and stops reading as the
/// primary thing on the line.
enum DSMetricBarSize { thin, md, thick }

/// One part of a whole, for [DSMetricBar.stacked].
///
/// A plain value class and not a widget: a segment has no layout of its own,
/// and typing it as a widget invites a caller to hang a gesture off something
/// two points wide.
@immutable
class DSMetricSegment {
  const DSMetricSegment({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;

  /// A category `arc` tone or a semantic colour — the same tones the legend
  /// dots take, because the legend is the only thing that says which is which.
  final Color color;
}

/// [DSMetricBar]'s appearance, as data.
@immutable
class DSMetricBarStyle extends DSComponentStyle<DSMetricBarStyle> {
  const DSMetricBarStyle({
    this.height,
    this.radius,
    this.trackColor,
    this.fillColor,
    this.segmentGap,
    this.headerGap,
    this.labelStyle,
    this.valueStyle,
    this.minFillExtent,
    this.padding,
  });

  final double? height;

  /// Full by default. A caller who wants square ends changes this rather than
  /// the widget.
  final BorderRadius? radius;

  final Color? trackColor;
  final Color? fillColor;

  /// Stacked only. Not decoration: without it two adjacent categories of
  /// similar lightness read as one segment, and the boundary is the entire
  /// point of a stack.
  final double? segmentGap;

  final double? headerGap;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  /// The narrowest a non-zero fill may be drawn, so 0.4% is visible rather
  /// than swallowed by the rounded cap. The text still says 0.4%.
  final double? minFillExtent;

  /// Zero — the parent owns the padding, the same rule the stat tile follows.
  final EdgeInsetsGeometry? padding;

  @override
  DSMetricBarStyle merge(DSMetricBarStyle? other) {
    if (other == null) return this;
    return DSMetricBarStyle(
      height: other.height ?? height,
      radius: other.radius ?? radius,
      trackColor: other.trackColor ?? trackColor,
      fillColor: other.fillColor ?? fillColor,
      segmentGap: other.segmentGap ?? segmentGap,
      headerGap: other.headerGap ?? headerGap,
      labelStyle: other.labelStyle ?? labelStyle,
      valueStyle: other.valueStyle ?? valueStyle,
      minFillExtent: other.minFillExtent ?? minFillExtent,
      padding: other.padding ?? padding,
    );
  }

  @override
  DSMetricBarStyle copyWith({
    double? height,
    BorderRadius? radius,
    Color? trackColor,
    Color? fillColor,
    double? segmentGap,
    double? headerGap,
    TextStyle? labelStyle,
    TextStyle? valueStyle,
    double? minFillExtent,
    EdgeInsetsGeometry? padding,
  }) => DSMetricBarStyle(
    height: height ?? this.height,
    radius: radius ?? this.radius,
    trackColor: trackColor ?? this.trackColor,
    fillColor: fillColor ?? this.fillColor,
    segmentGap: segmentGap ?? this.segmentGap,
    headerGap: headerGap ?? this.headerGap,
    labelStyle: labelStyle ?? this.labelStyle,
    valueStyle: valueStyle ?? this.valueStyle,
    minFillExtent: minFillExtent ?? this.minFillExtent,
    padding: padding ?? this.padding,
  );

  @override
  DSMetricBarStyle lerp(DSMetricBarStyle? other, double t) {
    if (other == null) return this;
    return DSMetricBarStyle(
      height: lerpDouble(height, other.height, t),
      radius: BorderRadius.lerp(radius, other.radius, t),
      trackColor: Color.lerp(trackColor, other.trackColor, t),
      fillColor: Color.lerp(fillColor, other.fillColor, t),
      segmentGap: lerpDouble(segmentGap, other.segmentGap, t),
      headerGap: lerpDouble(headerGap, other.headerGap, t),
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t),
      valueStyle: TextStyle.lerp(valueStyle, other.valueStyle, t),
      minFillExtent: lerpDouble(minFillExtent, other.minFillExtent, t),
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t),
    );
  }

  static DSMetricBarSize sizeOf(BuildContext context, DSMetricBarSize? size) =>
      size ??
      (DSScope.densityOf(context) == DSDensity.compact
          ? DSMetricBarSize.thin
          : DSMetricBarSize.md);

  static DSMetricBarStyle resolve(
    BuildContext context,
    DSMetricBarSize? size, [
    DSMetricBarStyle? own,
  ]) {
    final palette = context.palette;
    final space = context.design.space;
    final text = Theme.of(context).textTheme;
    final scale = sizeOf(context, size);

    // 8 rather than Material's 4: at h4 a rounded cap consumes the first 4dp
    // and a 3% value becomes invisible.
    final height = switch (scale) {
      DSMetricBarSize.thin => space.xs,
      DSMetricBarSize.md => space.sm,
      DSMetricBarSize.thick => space.md,
    };
    final headerGap = switch (scale) {
      DSMetricBarSize.thin => space.xs,
      DSMetricBarSize.md => space.xs,
      DSMetricBarSize.thick => space.sm,
    };

    return resolveStyle(
      context: context,
      specDefaults: DSMetricBarStyle(
        height: height,
        radius: BorderRadius.circular(height / 2),
        trackColor: palette.borderSoft,
        fillColor: palette.chart[0],
        segmentGap: space.hairline,
        headerGap: headerGap,
        labelStyle: DSTextRole.metricUnit.styleOf(context),
        valueStyle: text.labelMedium
            ?.copyWith(color: palette.foreground)
            .tabular,
        minFillExtent: height,
        padding: EdgeInsets.zero,
      ),
      own: own,
    );
  }
}

/// A horizontal determinate meter: one value against one ceiling, read as a
/// proportion, in one line of vertical space.
///
/// See `docs/plans/03-ds-metric-bar.plan.md`. Position along a common scale is
/// the most accurately decoded encoding there is and angle is among the least,
/// which is the measured reason a column of these beats a grid of
/// `DSProgressRing`s whenever the comparison is the point.
///
/// Like the ring it is a **meter**, not progress: settled state, no live
/// region, no indeterminate form.
///
/// There is no `.compact` variant. A bar with no header is `label: null` — a
/// flag that only hides a slot is not a variant, it is the slot being null.
///
/// ```dart
/// DSMetricBar(label: 'Storage', value: 68.4, max: 128, valueText: '68.4 / 128 GB')
/// ```
class DSMetricBar extends StatelessWidget {
  const DSMetricBar({
    super.key,
    required this.value,
    this.max = 1,
    this.label,
    this.valueText,
    this.fillColor,
    this.size,
    this.enabled = true,
    this.loading = false,
    this.style,
    this.labelSlot,
    this.valueSlot,
    this.leading,
    this.trailing,
    this.onTap,
    this.valueFormatter,
  }) : segments = const [],
       legend = null,
       stacked = false;

  /// Parts of a whole, sharing one track.
  ///
  /// A real variant rather than a size: it means something different (parts of
  /// a whole, not one value against a ceiling), it reads differently to a
  /// screen reader, and without it a caller hand-rolls a `Row` of `Flexible`
  /// fills and gets the gaps and the end caps wrong.
  const DSMetricBar.stacked({
    super.key,
    required this.segments,
    double? max,
    this.label,
    this.valueText,
    this.size,
    this.enabled = true,
    this.loading = false,
    this.style,
    this.labelSlot,
    this.valueSlot,
    this.leading,
    this.trailing,
    this.legend,
    this.onTap,
    this.valueFormatter,
  }) : value = 0,
       max = max ?? 0,
       fillColor = null,
       stacked = true;

  final double value;

  /// Zero on a stacked bar means "the sum of the segments".
  final double max;

  /// Null draws no header row at all.
  final String? label;

  final String? valueText;
  final Color? fillColor;
  final DSMetricBarSize? size;

  /// False drops the fill to `outlineSoft` and the value to `textTertiary`,
  /// and keeps the height: a meter that vanishes when disabled makes the row
  /// above it jump.
  final bool enabled;

  final bool loading;
  final DSMetricBarStyle? style;

  final Widget? labelSlot;
  final Widget? valueSlot;

  /// Before the label — a category dot, an icon, a checkbox for a filterable
  /// breakdown.
  final Widget? leading;

  /// After the value — an overflow menu, an info button.
  final Widget? trailing;

  /// Stacked only. Replaces the generated dot legend wholesale, for a caller
  /// whose legend lives somewhere else on the screen.
  final Widget? legend;

  final VoidCallback? onTap;
  final String Function(double value, double max)? valueFormatter;

  final List<DSMetricSegment> segments;
  final bool stacked;

  static String percentOf(double value, double max) =>
      max == 0 ? '0%' : '${(value / max * 100).toStringAsFixed(1)}%';

  double get _total => stacked
      ? (max > 0 ? max : segments.fold<double>(0, (sum, s) => sum + s.value))
      : max;

  String _semanticValue(String text) {
    if (loading) return 'loading';
    if (!stacked) return text;
    final buffer = StringBuffer(text);
    final total = _total;
    for (final segment in segments) {
      final percent = total == 0 ? 0 : (segment.value / total * 100).round();
      buffer.write('. ${segment.label} $percent percent');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final resolved = DSMetricBarStyle.resolve(
      context,
      size,
      const DSMetricBarStyle()
          .merge(style)
          .merge(DSMetricBarStyle(fillColor: fillColor)),
    );
    final scale = DSMetricBarStyle.sizeOf(context, size);
    final height = resolved.height ?? context.design.space.sm;
    final radius = resolved.radius ?? BorderRadius.circular(height / 2);
    final track = resolved.trackColor ?? palette.borderSoft;

    final over = !stacked && max > 0 && value > max;
    final fill = !enabled
        ? palette.borderSoft
        : over
        ? palette.warning
        : (resolved.fillColor ?? palette.chart[0]);

    final text = loading
        ? '—'
        : (valueText ??
              (valueFormatter ?? percentOf)(
                stacked ? _total : value,
                stacked ? _total : max,
              ));

    final Widget bar = ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(color: track, borderRadius: radius),
          child: stacked
              ? _StackedFill(
                  segments: segments,
                  total: _total,
                  gap: resolved.segmentGap ?? context.design.space.hairline,
                  radius: radius,
                  enabled: enabled,
                  mutedColor: palette.borderSoft,
                )
              : _Fill(
                  ratio: max <= 0
                      ? 0
                      : (value / max).clamp(0.0, 1.0).toDouble(),
                  color: fill,
                  radius: radius,
                  minExtent: resolved.minFillExtent ?? height,
                  hasValue: value > 0,
                ),
        ),
      ),
    );

    final showValue = scale != DSMetricBarSize.thin;
    final header = (label == null && labelSlot == null && leading == null)
        ? null
        : Row(
            children: [
              if (leading != null) ...[
                leading!,
                SizedBox(width: context.design.space.sm),
              ],
              Expanded(
                child:
                    labelSlot ??
                    Text(
                      label ?? '',
                      style: resolved.labelStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              ),
              if (showValue)
                valueSlot ??
                    Text(
                      text,
                      style: resolved.valueStyle?.copyWith(
                        color: enabled ? null : palette.mutedForeground,
                      ),
                      maxLines: 1,
                    ),
              if (trailing != null) ...[
                SizedBox(width: context.design.space.sm),
                trailing!,
              ],
            ],
          );

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header != null) ...[
          header,
          SizedBox(height: resolved.headerGap ?? context.design.space.xs),
        ],
        // Bones over the bar only; the label is known before the data is.
        DSSkeleton(enabled: loading, child: bar),
        if (stacked && (legend != null || segments.isNotEmpty)) ...[
          SizedBox(height: resolved.headerGap ?? context.design.space.xs),
          legend ?? DSMetricBarLegend(segments: segments, total: _total),
        ],
      ],
    );

    final padding = resolved.padding ?? EdgeInsets.zero;
    if (padding != EdgeInsets.zero) {
      content = Padding(padding: padding, child: content);
    }

    if (onTap != null) {
      final tapRadius = BorderRadius.all(
        Radius.circular(context.radiusOf(AppShape.tile)),
      );
      final tapShape = RoundedRectangleBorder(borderRadius: tapRadius);
      content = DSPressable(
        focusShape: tapShape,
        child: DSInkSurface(
          onTap: enabled ? onTap : null,
          shape: tapShape,
          child: content,
        ),
      );
    }

    return Semantics(
      container: true,
      button: onTap != null,
      enabled: enabled,
      label: label,
      value: _semanticValue(text),
      child: ExcludeSemantics(child: content),
    );
  }
}

/// One fill, animated from where it was.
class _Fill extends StatelessWidget {
  const _Fill({
    required this.ratio,
    required this.color,
    required this.radius,
    required this.minExtent,
    required this.hasValue,
  });

  final double ratio;
  final Color color;
  final BorderRadius radius;
  final double minExtent;
  final bool hasValue;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => DSRatioTransition(
        value: ratio,
        builder: (context, animated) {
          final width = constraints.maxWidth * animated;
          return Stack(
            fit: StackFit.expand,
            children: [
              PositionedDirectional(
                top: 0,
                bottom: 0,
                start: 0,
                // A non-zero value never disappears into the cap: it clamps
                // up to one bar-height, and the text still tells the truth.
                width: hasValue && width < minExtent ? minExtent : width,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: color, borderRadius: radius),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Every segment in one track, animated together as one layout.
///
/// Together and not staggered: staggering makes the boundaries slide past each
/// other and the total look wrong mid-flight.
class _StackedFill extends StatelessWidget {
  const _StackedFill({
    required this.segments,
    required this.total,
    required this.gap,
    required this.radius,
    required this.enabled,
    required this.mutedColor,
  });

  final List<DSMetricSegment> segments;
  final double total;
  final double gap;
  final BorderRadius radius;
  final bool enabled;
  final Color mutedColor;

  /// The share of the track the segments cover, capped at the whole.
  double get _filled {
    final sum = segments.fold<double>(0, (acc, s) => acc + s.value);
    return total <= 0 ? 0 : (sum / total).clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty || total <= 0) return const SizedBox.shrink();
    return DSRatioTransition(
      value: 1,
      builder: (context, animated) => Row(
        // Stretch, or every segment is a zero-height DecoratedBox: a bare
        // decoration has no intrinsic size of its own.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Flexible(
              flex: (segments[i].value / total * 1000 * animated).round().clamp(
                0,
                1000,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: enabled ? segments[i].color : mutedColor,
                  borderRadius: radius,
                ),
              ),
            ),
          ],
          // The unfilled remainder, so the segments keep their proportion of
          // the track rather than stretching to fill it.
          Flexible(
            flex: ((1 - _filled * animated) * 1000).round().clamp(0, 1000),
            child: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// The dot-per-segment legend under a stacked bar — the intended occupant of
/// [DSMetricBar.legend].
// ds-tier: 1 — atom — A row of swatches and their labels.
class DSMetricBarLegend extends StatelessWidget {
  const DSMetricBarLegend({
    super.key,
    required this.segments,
    this.total,
    this.showValues = true,
    this.valueFormatter,
  });

  final List<DSMetricSegment> segments;

  /// Null sums the segments.
  final double? total;

  final bool showValues;
  final String Function(double value, double max)? valueFormatter;

  @override
  Widget build(BuildContext context) {
    final space = context.design.space;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final sum = total ?? segments.fold<double>(0, (acc, s) => acc + s.value);
    final format = valueFormatter ?? DSMetricBar.percentOf;

    return Wrap(
      spacing: space.md,
      runSpacing: space.xs,
      children: [
        for (final segment in segments)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: space.sm,
                height: space.sm,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: segment.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              SizedBox(width: space.xs),
              Text(segment.label, style: DSTextRole.caption.styleOf(context)),
              if (showValues) ...[
                SizedBox(width: space.xs),
                Text(
                  format(segment.value, sum),
                  style: text.labelSmall?.copyWith(color: palette.foreground),
                ),
              ],
            ],
          ),
      ],
    );
  }
}
