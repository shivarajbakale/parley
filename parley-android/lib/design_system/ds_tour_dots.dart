// ds-tier: 1 — atom

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// How the position indicator on a tour is drawn.
@immutable
class DSTourDotsStyle extends DSComponentStyle<DSTourDotsStyle> {
  const DSTourDotsStyle({
    this.dotSize,
    this.barWidth,
    this.gap,
    this.idleAlpha,
  });

  /// The diameter of a page you are not on.
  final double? dotSize;

  /// The width the page you *are* on grows to.
  final double? barWidth;

  /// Horizontal space either side of each mark.
  final double? gap;

  /// How present an unvisited page is.
  final double? idleAlpha;

  @override
  DSTourDotsStyle merge(DSTourDotsStyle? other) {
    if (other == null) return this;
    return DSTourDotsStyle(
      dotSize: other.dotSize ?? dotSize,
      barWidth: other.barWidth ?? barWidth,
      gap: other.gap ?? gap,
      idleAlpha: other.idleAlpha ?? idleAlpha,
    );
  }

  @override
  DSTourDotsStyle copyWith({
    double? dotSize,
    double? barWidth,
    double? gap,
    double? idleAlpha,
  }) => DSTourDotsStyle(
    dotSize: dotSize ?? this.dotSize,
    barWidth: barWidth ?? this.barWidth,
    gap: gap ?? this.gap,
    idleAlpha: idleAlpha ?? this.idleAlpha,
  );

  @override
  DSTourDotsStyle lerp(DSTourDotsStyle? other, double t) {
    if (other == null) return this;
    return DSTourDotsStyle(
      dotSize: lerpDouble(dotSize, other.dotSize, t),
      barWidth: lerpDouble(barWidth, other.barWidth, t),
      gap: lerpDouble(gap, other.gap, t),
      idleAlpha: lerpDouble(idleAlpha, other.idleAlpha, t),
    );
  }

  static DSTourDotsStyle resolve(BuildContext context, {DSTourDotsStyle? own}) {
    final space = context.design.space;
    return resolveStyle(
      context: context,
      specDefaults: DSTourDotsStyle(
        dotSize: space.xs + space.hairline,
        barWidth: space.xl,
        gap: space.xs,
        idleAlpha: 0.28,
      ),
      own: own,
    );
  }
}

/// Where you are in a [DSTour].
///
/// **Use when** a paged sequence needs to say how long it is and how far
/// through it you are.
///
/// **Instead:** [DSSegmentedProgress] for a checklist, where the segments are
/// discrete tasks that stay done. This is a position, not a score.
///
/// The current page is a bar rather than a bigger dot: at four pages, size
/// alone is hard to spot at a glance, and a bar reads as progress along a
/// track. There is no tap target — the button and the swipe are the two ways
/// forward, and a third on a 6pt dot is a mis-tap waiting to happen.
///
/// [position] is the live fractional scroll position, not the settled page, so
/// the track stretches and collapses under the finger and is already telling
/// the truth when the swipe is let go.
class DSTourDots extends StatelessWidget {
  const DSTourDots({
    super.key,
    required this.count,
    required this.position,
    this.style,
  });

  final int count;

  /// A whole number at rest, anything in between mid-drag.
  final double position;

  final DSTourDotsStyle? style;

  @override
  Widget build(BuildContext context) {
    final DSTourDotsStyle resolved = DSTourDotsStyle.resolve(
      context,
      own: style,
    );
    final Palette palette = context.palette;
    final Curve curve = context.design.motion.enter;
    final Color idle = palette.mutedForeground.withValues(
      alpha: resolved.idleAlpha,
    );
    // Rounded, not floored: the label should name the page you are arriving
    // at once you are more than half way to it. Overscroll at either end can
    // push the position outside the range, so it is clamped back into it.
    final int current = position.round().clamp(0, count - 1);

    return Semantics(
      label: 'Page ${current + 1} of $count',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (int i = 0; i < count; i++)
              () {
                // 1 on the page you are on, 0 a full page away. Eased, so the
                // two marks either side of a half-way drag are both visibly
                // short of full rather than both sitting at half a bar.
                final double t = curve.transform(
                  (1 - (position - i).abs()).clamp(0.0, 1.0),
                );
                return Container(
                  margin: EdgeInsets.symmetric(horizontal: resolved.gap!),
                  width:
                      resolved.dotSize! +
                      (resolved.barWidth! - resolved.dotSize!) * t,
                  height: resolved.dotSize,
                  decoration: BoxDecoration(
                    color: Color.lerp(idle, palette.primary, t),
                    borderRadius: BorderRadius.all(
                      Radius.circular(context.radiusOf(AppShape.pill)),
                    ),
                  ),
                );
              }(),
          ],
        ),
      ),
    );
  }
}
