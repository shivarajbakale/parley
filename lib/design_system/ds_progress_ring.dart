// ds-tier: 1 — atom

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/_ratio_transition.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_skeleton.dart';
import 'package:parley_android/design_system/ds_text_style.dart';
import 'package:parley_android/theme/app_typography.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The three designed ring scales.
///
/// Stroke is deliberately *not* proportional to diameter: a ring that scales
/// its stroke with its size loses its identity between the compact and hero
/// forms, so the three pairs are designed together and picked as pairs.
enum DSProgressRingSize { compact, md, hero }

/// [DSProgressRing]'s appearance, as data.
///
/// [startAngle], [clockwise] and [trackGap] are here for one reason: the
/// alternative is a caller who needs a counter-clockwise ring forking the
/// painter. None of the three changes what a ring *means*, so none of them is
/// a variant.
@immutable
class DSProgressRingStyle extends DSComponentStyle<DSProgressRingStyle> {
  const DSProgressRingStyle({
    this.diameter,
    this.strokeWidth,
    this.trackColor,
    this.arcColor,
    this.cap,
    this.startAngle,
    this.clockwise,
    this.trackGap,
    this.valueStyle,
    this.labelStyle,
    this.captionStyle,
    this.gap,
  });

  final double? diameter;
  final double? strokeWidth;

  /// Carries no meaning on its own, which is why it may sit below the 3:1
  /// graphical floor the arc has to clear.
  final Color? trackColor;

  final Color? arcColor;

  /// Round on the arc; the track is always butt, because a capped track has
  /// two visible nubs at 12 o'clock.
  final StrokeCap? cap;

  /// Where the sweep begins, in radians. `-pi/2` is 12 o'clock.
  final double? startAngle;

  final bool? clockwise;

  /// The Material 3 Expressive gap between track and arc, in radians. Off by
  /// default — at Ø56 with a 6 stroke it closes to noise — and reachable
  /// without editing the painter.
  final double? trackGap;

  final TextStyle? valueStyle;
  final TextStyle? labelStyle;
  final TextStyle? captionStyle;

  /// Ring to text.
  final double? gap;

  @override
  DSProgressRingStyle merge(DSProgressRingStyle? other) {
    if (other == null) return this;
    return DSProgressRingStyle(
      diameter: other.diameter ?? diameter,
      strokeWidth: other.strokeWidth ?? strokeWidth,
      trackColor: other.trackColor ?? trackColor,
      arcColor: other.arcColor ?? arcColor,
      cap: other.cap ?? cap,
      startAngle: other.startAngle ?? startAngle,
      clockwise: other.clockwise ?? clockwise,
      trackGap: other.trackGap ?? trackGap,
      valueStyle: other.valueStyle ?? valueStyle,
      labelStyle: other.labelStyle ?? labelStyle,
      captionStyle: other.captionStyle ?? captionStyle,
      gap: other.gap ?? gap,
    );
  }

  @override
  DSProgressRingStyle copyWith({
    double? diameter,
    double? strokeWidth,
    Color? trackColor,
    Color? arcColor,
    StrokeCap? cap,
    double? startAngle,
    bool? clockwise,
    double? trackGap,
    TextStyle? valueStyle,
    TextStyle? labelStyle,
    TextStyle? captionStyle,
    double? gap,
  }) => DSProgressRingStyle(
    diameter: diameter ?? this.diameter,
    strokeWidth: strokeWidth ?? this.strokeWidth,
    trackColor: trackColor ?? this.trackColor,
    arcColor: arcColor ?? this.arcColor,
    cap: cap ?? this.cap,
    startAngle: startAngle ?? this.startAngle,
    clockwise: clockwise ?? this.clockwise,
    trackGap: trackGap ?? this.trackGap,
    valueStyle: valueStyle ?? this.valueStyle,
    labelStyle: labelStyle ?? this.labelStyle,
    captionStyle: captionStyle ?? this.captionStyle,
    gap: gap ?? this.gap,
  );

  @override
  DSProgressRingStyle lerp(DSProgressRingStyle? other, double t) {
    if (other == null) return this;
    return DSProgressRingStyle(
      diameter: lerpDouble(diameter, other.diameter, t),
      strokeWidth: lerpDouble(strokeWidth, other.strokeWidth, t),
      trackColor: Color.lerp(trackColor, other.trackColor, t),
      arcColor: Color.lerp(arcColor, other.arcColor, t),
      cap: t < 0.5 ? cap : other.cap,
      startAngle: lerpDouble(startAngle, other.startAngle, t),
      clockwise: t < 0.5 ? clockwise : other.clockwise,
      trackGap: lerpDouble(trackGap, other.trackGap, t),
      valueStyle: TextStyle.lerp(valueStyle, other.valueStyle, t),
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t),
      captionStyle: TextStyle.lerp(captionStyle, other.captionStyle, t),
      gap: lerpDouble(gap, other.gap, t),
    );
  }

  /// Which scale applies. An explicit [size] wins; a null one takes the
  /// ambient [DSScope.density] as a default.
  static DSProgressRingSize sizeOf(
    BuildContext context,
    DSProgressRingSize? size,
  ) =>
      size ??
      (DSScope.densityOf(context) == DSDensity.compact
          ? DSProgressRingSize.compact
          : DSProgressRingSize.md);

  static DSProgressRingStyle resolve(
    BuildContext context,
    DSProgressRingSize? size, [
    DSProgressRingStyle? own,
  ]) {
    final palette = context.palette;
    final design = context.design;
    final text = Theme.of(context).textTheme;
    final scale = sizeOf(context, size);

    // Diameter and stroke are the two numbers in the kit that are deliberately
    // not on the space scale: they are a designed pair per size, and rounding
    // them onto the 4pt grid is what turns three recognisable rings into three
    // arbitrary ones.
    final (diameter, stroke) = switch (scale) {
      DSProgressRingSize.compact => (40.0, 5.0),
      DSProgressRingSize.md => (56.0, 6.0),
      DSProgressRingSize.hero => (88.0, 8.0),
    };
    final value = switch (scale) {
      DSProgressRingSize.compact => text.titleMedium,
      DSProgressRingSize.md => text.titleLarge,
      DSProgressRingSize.hero => text.displaySmall,
    };
    final label = switch (scale) {
      DSProgressRingSize.hero => text.bodyLarge,
      _ => text.labelMedium,
    };

    return resolveStyle(
      context: context,
      specDefaults: DSProgressRingStyle(
        diameter: diameter,
        strokeWidth: stroke,
        trackColor: palette.borderSoft,
        arcColor: palette.chart[0],
        cap: StrokeCap.round,
        startAngle: -math.pi / 2,
        clockwise: true,
        trackGap: 0,
        valueStyle: value
            ?.copyWith(
              color: palette.foreground,
              fontWeight: context.design.type.emphasisWeight,
            )
            .tabular,
        labelStyle: label?.copyWith(color: palette.mutedForeground),
        // `textSecondary`, not `textTertiary`. The caption is body-sized, and
        // gate K3 holds the tertiary role at 3:1 against the surface on the
        // reasoning that it carries hairlines and large text — which is the
        // right floor for what it is for and the wrong one for a 16-point
        // sentence. The ring's caption measured 3.82:1.
        captionStyle: DSTextRole.bodySupport.styleOf(context),
        gap: scale == DSProgressRingSize.compact
            ? design.space.sm
            : design.space.md,
      ),
      own: own,
    );
  }
}

/// A circular determinate meter: one value against one target, with the value
/// legible without reading the ring.
///
/// See `docs/plans/01-ds-progress-ring.plan.md`. It is a **meter**, not
/// progress: it shows settled state, so it publishes no live region and has no
/// indeterminate form. For a task in flight, `DSProgressIndicator`.
///
/// The value is always rendered as text, so the ring is redundant rather than
/// the only channel — colour never carries meaning alone here.
///
/// ```dart
/// DSProgressRing(
///   label: 'Storage',
///   value: 68.4,
///   max: 128,
///   valueText: '68.4 GB',
///   caption: 'of 128 GB',
/// )
/// ```
class DSProgressRing extends StatelessWidget {
  const DSProgressRing({
    super.key,
    required this.value,
    required this.label,
    this.max = 1,
    this.valueText,
    this.caption,
    this.size,
    this.enabled = true,
    this.loading = false,
    this.arcColor,
    this.style,
    this.labelSlot,
    this.captionSlot,
    this.valueFormatter,
    this.showValue = true,
  }) : center = null,
       stacked = false;

  /// The hero form: the value sits inside the ring and the label below it.
  ///
  /// Two layouts of one component, not two components — same semantics node,
  /// same states, same over-target rule.
  const DSProgressRing.stacked({
    super.key,
    required this.value,
    required this.label,
    this.max = 1,
    this.valueText,
    this.caption,
    this.size = DSProgressRingSize.hero,
    this.enabled = true,
    this.loading = false,
    this.arcColor,
    this.style,
    this.labelSlot,
    this.captionSlot,
    this.center,
    this.valueFormatter,
    this.showValue = true,
  }) : stacked = true;

  /// Not clamped for the label — a user over target sees 110%. Only the arc
  /// stops at full.
  final double value;
  final double max;

  final String label;

  /// Rendered as-is. Defaults to [valueFormatter] applied to [value].
  final String? valueText;

  /// 'of 128 GB'.
  final String? caption;

  final DSProgressRingSize? size;
  final bool enabled;
  final bool loading;

  /// Shorthand for `style: DSProgressRingStyle(arcColor: …)`.
  final Color? arcColor;

  final DSProgressRingStyle? style;

  final Widget? labelSlot;
  final Widget? captionSlot;

  /// Stacked only. Replaces the value-and-caption stack inside the ring
  /// wholesale — the hatch for a ring that has to hold an icon, an avatar or
  /// a second ring.
  final Widget? center;

  final String Function(double value, double max)? valueFormatter;

  /// False draws the ring with no figure beside it — for a caller whose value
  /// is already on screen a few pixels away.
  final bool showValue;

  final bool stacked;

  /// Percent, rounded. The reason this is injectable is that `68.4 GB`,
  /// `53%` and `1 284 / 2 500` are all the same widget with a different
  /// function, and none of them is a branch inside it.
  static String percentOf(double value, double max) =>
      max == 0 ? '—' : '${(value / max * 100).round()}%';

  /// The fraction of the ring the arc fills, clamped: the arc caps at 360°
  /// and changes colour rather than wrapping a second lap, because two laps
  /// at a glance is indistinguishable from ten percent.
  double get _target => max <= 0 ? 0 : (value / max).clamp(0.0, 1.0).toDouble();

  String _semanticValue(String valueText) {
    final buffer = StringBuffer(valueText);
    if (caption != null) buffer.write(' $caption');
    if (max > 0) buffer.write(', ${(value / max * 100).round()} percent');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final resolved = DSProgressRingStyle.resolve(
      context,
      size,
      const DSProgressRingStyle()
          .merge(style)
          .merge(DSProgressRingStyle(arcColor: arcColor)),
    );

    final over = max > 0 && value > max;
    final Color arc = !enabled
        ? palette.borderSoft
        : over
        ? palette.warning
        : (resolved.arcColor ?? palette.chart[0]);

    final text =
        valueText ?? (valueFormatter ?? DSProgressRing.percentOf)(value, max);

    final ring = ExcludeSemantics(
      child: DSRatioTransition(
        value: loading ? 0 : _target,
        builder: (context, ratio) => CustomPaint(
          size: Size.square(resolved.diameter ?? 56),
          painter: DSProgressRingPainter(
            sweep: ratio,
            strokeWidth: resolved.strokeWidth ?? 6,
            trackColor: resolved.trackColor ?? palette.borderSoft,
            arcColor: arc,
            cap: resolved.cap ?? StrokeCap.round,
            startAngle: resolved.startAngle ?? -math.pi / 2,
            clockwise: resolved.clockwise ?? true,
            trackGap: resolved.trackGap ?? 0,
          ),
        ),
      ),
    );

    final labelWidget =
        labelSlot ?? Text(label, style: resolved.labelStyle, maxLines: 2);
    final captionWidget =
        captionSlot ??
        (caption == null ? null : Text(caption!, style: resolved.captionStyle));
    final valueWidget = Text(
      loading ? '—' : text,
      style: resolved.valueStyle?.copyWith(
        color: enabled ? null : palette.mutedForeground,
      ),
      maxLines: 1,
      softWrap: false,
    );

    final gap = resolved.gap ?? context.design.space.md;

    final Widget content = stacked
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  ring,
                  if (showValue)
                    DSSkeleton(
                      enabled: loading,
                      child:
                          center ??
                          DSProgressRingCenter(
                            value: loading ? '—' : text,
                            caption: caption,
                            style: resolved,
                          ),
                    ),
                ],
              ),
              SizedBox(height: gap),
              labelWidget,
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ring,
              SizedBox(width: gap),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    labelWidget,
                    if (showValue)
                      DSSkeleton(enabled: loading, child: valueWidget),
                    if (captionWidget != null) captionWidget,
                  ],
                ),
              ),
            ],
          );

    // One node for the ring, the number and the label — they are one thing to
    // a reader, not three. No live region: this is settled state, and a live
    // region here makes VoiceOver interrupt on every rebuild.
    return Semantics(
      container: true,
      label: label,
      value: loading ? 'loading' : _semanticValue(text),
      child: ExcludeSemantics(child: content),
    );
  }
}

/// The value-and-caption stack that sits inside a stacked ring — the intended
/// occupant of [DSProgressRing.center], and a widget of its own so a caller
/// composing one by hand gets the same type treatment.
class DSProgressRingCenter extends StatelessWidget {
  const DSProgressRingCenter({
    super.key,
    required this.value,
    this.caption,
    this.valueSlot,
    this.style,
  });

  final String value;
  final String? caption;
  final Widget? valueSlot;
  final DSProgressRingStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved =
        style ?? DSProgressRingStyle.resolve(context, DSProgressRingSize.hero);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        valueSlot ??
            Text(
              value,
              style: resolved.valueStyle,
              maxLines: 1,
              softWrap: false,
            ),
        if (caption != null)
          Text(caption!, style: resolved.captionStyle, maxLines: 1),
      ],
    );
  }
}

/// The arc and its track.
///
/// Public so a test can assert the sweep it was handed rather than comparing
/// pixels: a golden tells you the ring changed, and this tells you which
/// number changed it.
class DSProgressRingPainter extends CustomPainter {
  const DSProgressRingPainter({
    required this.sweep,
    required this.strokeWidth,
    required this.trackColor,
    required this.arcColor,
    required this.cap,
    required this.startAngle,
    required this.clockwise,
    required this.trackGap,
  });

  /// In turns, already clamped to 0..1 by the caller.
  final double sweep;
  final double strokeWidth;
  final Color trackColor;
  final Color arcColor;
  final StrokeCap cap;
  final double startAngle;
  final bool clockwise;
  final double trackGap;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      // Butt, always: a capped track puts two visible nubs at the seam.
      ..strokeCap = StrokeCap.butt
      ..color = trackColor;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    if (sweep <= 0) return;
    final radians = math.pi * 2 * sweep.clamp(0.0, 1.0);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = cap
      ..color = arcColor;
    canvas.drawArc(
      rect,
      startAngle + (clockwise ? trackGap : -trackGap),
      clockwise ? radians : -radians,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(DSProgressRingPainter old) =>
      old.sweep != sweep ||
      old.strokeWidth != strokeWidth ||
      old.trackColor != trackColor ||
      old.arcColor != arcColor ||
      old.cap != cap ||
      old.startAngle != startAngle ||
      old.clockwise != clockwise ||
      old.trackGap != trackGap;
}
