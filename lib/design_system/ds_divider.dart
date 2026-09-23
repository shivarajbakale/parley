// ds-tier: 1 — atom

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// How a rule looks, at every layer of the resolution chain.
@immutable
class DSDividerStyle extends DSComponentStyle<DSDividerStyle> {
  const DSDividerStyle({
    this.thickness,
    this.color,
    this.indent,
    this.endIndent,
  });

  /// One hairline. Not a design decision per call site: the kit had two tokens
  /// for this — `space.hairline` and `component.hairlineWidth` — being used
  /// interchangeably in nine places, which is how two rules on one screen end
  /// up different weights.
  final double? thickness;

  /// The soft outline, not the hard one. A rule between rows is a separation,
  /// not an edge; at `outline` weight a list reads as a table.
  final Color? color;

  /// The inset at the leading edge, for a rule that starts where the row's
  /// text starts rather than at the screen edge.
  final double? indent;
  final double? endIndent;

  @override
  DSDividerStyle merge(DSDividerStyle? other) {
    if (other == null) return this;
    return DSDividerStyle(
      thickness: other.thickness ?? thickness,
      color: other.color ?? color,
      indent: other.indent ?? indent,
      endIndent: other.endIndent ?? endIndent,
    );
  }

  @override
  DSDividerStyle copyWith({
    double? thickness,
    Color? color,
    double? indent,
    double? endIndent,
  }) => DSDividerStyle(
    thickness: thickness ?? this.thickness,
    color: color ?? this.color,
    indent: indent ?? this.indent,
    endIndent: endIndent ?? this.endIndent,
  );

  @override
  DSDividerStyle lerp(DSDividerStyle? other, double t) {
    if (other == null) return this;
    return DSDividerStyle(
      thickness: lerpDouble(thickness, other.thickness, t),
      color: Color.lerp(color, other.color, t),
      indent: lerpDouble(indent, other.indent, t),
      endIndent: lerpDouble(endIndent, other.endIndent, t),
    );
  }

  static DSDividerStyle resolve(BuildContext context, [DSDividerStyle? own]) {
    return resolveStyle(
      context: context,
      specDefaults: DSDividerStyle(
        thickness: context.design.component.hairlineWidth,
        color: context.palette.borderSoft,
        indent: 0,
        endIndent: 0,
      ),
      own: own,
    );
  }
}

/// One hairline, in the kit's weight and the kit's grey.
///
/// **Use when** two blocks of content are adjacent and neither is a card — a
/// run of rows, a menu, a stat strip. **Instead:** whitespace first. A rule is
/// the second-cheapest separator and space is the cheapest; a screen that
/// draws a line between every pair of things has decided none of them group.
/// `DSCard` when the block is a surface rather than a neighbour.
///
/// The reason this is a component and not a `Divider`: Material's `Divider`
/// has *two* size knobs — `height` (the box it occupies) and `thickness` (the
/// line inside it) — and defaults `height` to 16, so a stock divider silently
/// adds 16 points of vertical space wherever it lands. Every one of the nine
/// call sites in this kit passed `height: thickness` to undo that, and two of
/// them read the thickness from a different token than the other seven.
///
/// Here the rule occupies exactly its own thickness. Space around it is the
/// caller's, taken from `context.design.space`, where the rest of the screen's
/// rhythm comes from.
class DSDivider extends StatelessWidget {
  const DSDivider({super.key, this.indent, this.endIndent, this.style})
    : axis = Axis.horizontal;

  /// A rule between two things side by side — the split between a pair of
  /// stat tiles, a toolbar's groups. It fills the height it is given, so it
  /// belongs in a `Row` with a bounded cross axis (an `IntrinsicHeight`, or a
  /// `SizedBox`), never in an unbounded one.
  const DSDivider.vertical({super.key, this.indent, this.endIndent, this.style})
    : axis = Axis.vertical;

  final Axis axis;

  /// Overrides the resolved inset at the leading edge. Directional: under RTL
  /// this is the right-hand end, which is what a row's text inset does too.
  final double? indent;
  final double? endIndent;

  final DSDividerStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = DSDividerStyle.resolve(context, style);
    final thickness = resolved.thickness ?? 1;
    final start = indent ?? resolved.indent ?? 0;
    final end = endIndent ?? resolved.endIndent ?? 0;

    final line = DecoratedBox(
      decoration: BoxDecoration(color: resolved.color),
      child: axis == Axis.horizontal
          ? SizedBox(height: thickness, width: double.infinity)
          : SizedBox(width: thickness, height: double.infinity),
    );

    final padded = Padding(
      padding: axis == Axis.horizontal
          ? EdgeInsetsDirectional.only(start: start, end: end)
          : EdgeInsets.only(top: start, bottom: end),
      child: line,
    );

    // A rule is not content. A screen reader that stops on it is reading the
    // furniture, and a list of twenty rows has twenty of them.
    return ExcludeSemantics(child: padded);
  }
}
