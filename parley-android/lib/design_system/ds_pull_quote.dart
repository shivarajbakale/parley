// ds-tier: 1 — atom

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// How a pull quote looks, at every layer of the resolution chain.
@immutable
class DSPullQuoteStyle extends DSComponentStyle<DSPullQuoteStyle> {
  const DSPullQuoteStyle({
    this.ruleWidth,
    this.ruleColor,
    this.ruleRadius,
    this.gap,
    this.padding,
    this.quoteStyle,
    this.attributionStyle,
    this.attributionGap,
  });

  /// The rule down the start edge. A rule rather than a fill: a quote is part
  /// of the article, and a filled block is a second surface competing with it.
  final double? ruleWidth;
  final Color? ruleColor;
  final BorderRadius? ruleRadius;

  /// Between the rule and the words.
  final double? gap;

  final EdgeInsetsGeometry? padding;
  final TextStyle? quoteStyle;
  final TextStyle? attributionStyle;
  final double? attributionGap;

  @override
  DSPullQuoteStyle merge(DSPullQuoteStyle? other) {
    if (other == null) return this;
    return DSPullQuoteStyle(
      ruleWidth: other.ruleWidth ?? ruleWidth,
      ruleColor: other.ruleColor ?? ruleColor,
      ruleRadius: other.ruleRadius ?? ruleRadius,
      gap: other.gap ?? gap,
      padding: other.padding ?? padding,
      quoteStyle: other.quoteStyle ?? quoteStyle,
      attributionStyle: other.attributionStyle ?? attributionStyle,
      attributionGap: other.attributionGap ?? attributionGap,
    );
  }

  @override
  DSPullQuoteStyle copyWith({
    double? ruleWidth,
    Color? ruleColor,
    BorderRadius? ruleRadius,
    double? gap,
    EdgeInsetsGeometry? padding,
    TextStyle? quoteStyle,
    TextStyle? attributionStyle,
    double? attributionGap,
  }) => DSPullQuoteStyle(
    ruleWidth: ruleWidth ?? this.ruleWidth,
    ruleColor: ruleColor ?? this.ruleColor,
    ruleRadius: ruleRadius ?? this.ruleRadius,
    gap: gap ?? this.gap,
    padding: padding ?? this.padding,
    quoteStyle: quoteStyle ?? this.quoteStyle,
    attributionStyle: attributionStyle ?? this.attributionStyle,
    attributionGap: attributionGap ?? this.attributionGap,
  );

  @override
  DSPullQuoteStyle lerp(DSPullQuoteStyle? other, double t) {
    if (other == null) return this;
    return DSPullQuoteStyle(
      ruleWidth: lerpDouble(ruleWidth, other.ruleWidth, t),
      ruleColor: Color.lerp(ruleColor, other.ruleColor, t),
      ruleRadius: BorderRadius.lerp(ruleRadius, other.ruleRadius, t),
      gap: lerpDouble(gap, other.gap, t),
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t),
      quoteStyle: TextStyle.lerp(quoteStyle, other.quoteStyle, t),
      attributionStyle: TextStyle.lerp(
        attributionStyle,
        other.attributionStyle,
        t,
      ),
      attributionGap: lerpDouble(attributionGap, other.attributionGap, t),
    );
  }

  static DSPullQuoteStyle resolve(
    BuildContext context, [
    DSPullQuoteStyle? own,
  ]) {
    final design = context.design;
    final space = design.space;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return resolveStyle(
      context: context,
      specDefaults: DSPullQuoteStyle(
        ruleWidth: space.xs,
        ruleColor: palette.primary,
        ruleRadius: BorderRadius.all(Radius.circular(space.xs / 2)),
        gap: space.md,
        padding: EdgeInsets.symmetric(vertical: space.xs),
        // A size up from the body and no italic. Italic at body weight is the
        // one thing every reader reads slower, and a quote that is harder to
        // read than the paragraph it was lifted out of is a decoration.
        quoteStyle: text.titleMedium?.copyWith(
          color: palette.foreground,
          height: 1.5,
          fontWeight: context.design.type.bodyWeight,
        ),
        attributionStyle: text.labelMedium?.copyWith(
          color: palette.mutedForeground,
        ),
        attributionGap: space.sm,
      ),
      own: own,
    );
  }
}

/// A sentence lifted out of the article it came from.
///
/// **Use when** a paragraph contains one line that carries the piece — the
/// argument in a sentence — and it is worth a reader who is skimming stopping
/// on. **Instead:** `DSMessage` when the words are the app talking to the user
/// rather than the article talking about itself, and a plain `Text` in the
/// body when the sentence is simply the next sentence.
///
/// The quote is a **rule and a size**, not a box. A filled block is a second
/// surface inside a reading column, and a reading column has one; the two
/// signals that separate a quote from the paragraph above it are the start
/// rule in the accent and one step up the type scale.
///
/// The rule spans the full height of the words rather than a fixed number of
/// points. That is the entire reason this is a component: the article page
/// that first drew a pull quote hard-coded a 48-point bar next to a
/// three-line quote, and every quote longer than two lines shipped with the
/// rule stopping a third of the way down.
class DSPullQuote extends StatelessWidget {
  const DSPullQuote({
    required this.quote,
    super.key,
    this.attribution,
    this.accentColor,
    this.style,
  });

  /// The sentence. Written as it is read — no surrounding quotation marks, no
  /// markdown: this is a `Text`, and a backtick in the string is a backtick on
  /// the screen.
  final String quote;

  /// Who said it. Rendered as `— Name`, and omitted when the article is
  /// quoting itself.
  final String? attribution;

  /// The rule's colour, for a surface that already has a category colour — a
  /// blog section, a tone. Defaults to the accent.
  final Color? accentColor;

  final DSPullQuoteStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = DSPullQuoteStyle.resolve(context, style);

    final Widget words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(quote, style: resolved.quoteStyle),
        if (attribution != null) ...[
          SizedBox(height: resolved.attributionGap),
          Text('— $attribution', style: resolved.attributionStyle),
        ],
      ],
    );

    return Semantics(
      container: true,
      label: attribution == null ? quote : '$quote, $attribution',
      child: ExcludeSemantics(
        child: Padding(
          padding: resolved.padding ?? EdgeInsets.zero,
          // The rule is as tall as the words, whatever the words are. An
          // `IntrinsicHeight` costs one extra layout pass on a widget that
          // holds one paragraph, which is the cheapest place in the kit to
          // spend one.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: resolved.ruleWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: accentColor ?? resolved.ruleColor,
                      borderRadius: resolved.ruleRadius,
                    ),
                  ),
                ),
                SizedBox(width: resolved.gap),
                Expanded(child: words),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
