// ds-tier: 1 — atom

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_text_style.dart';
import 'package:parley_android/theme/app_typography.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// How a hero plate is drawn, at every layer of the resolution chain.
///
/// Every colour here is read from the palette in [resolve], and none of the
/// plate is a raster. That is the whole reason the drawing is a painter: a
/// shipped PNG would be one identity's plate in one theme, and this kit has
/// four identities and two themes, which is eight plates nobody would keep in
/// sync.
@immutable
class DSHeroStyle extends DSComponentStyle<DSHeroStyle> {
  const DSHeroStyle({
    this.minHeight,
    this.padding,
    this.sheetRadius,
    this.sheetColor,
    this.hairlineColor,
    this.markSize,
    this.markColor,
    this.markGroundColor,
    this.plateTopColor,
    this.plateBottomColor,
    this.bloomColor,
    this.arcColor,
    this.arcStroke,
    this.eyebrowStyle,
    this.titleStyle,
    this.subtitleStyle,
  });

  /// A floor, not a height. The plate is as tall as its own content and grows
  /// with the text-scale setting; this stops it collapsing to the height of
  /// two words on the one screen where it is the first thing a user ever sees.
  final double? minHeight;

  final EdgeInsetsGeometry? padding;

  /// The corner the page's own surface turns as it rises over the plate — and
  /// the height of the lip that turn is painted into.
  final double? sheetRadius;

  /// The ground the content below the hero sits on. The plate paints the lip
  /// itself rather than leaving the page to overlap it, because the overlap is
  /// the fiddly half and repeating it on four auth screens is how three of
  /// them end up a point out.
  final Color? sheetColor;

  /// The hairline that closes the lip's top edge.
  ///
  /// Not decoration. [DesignSpec.ledger] and [DesignSpec.signal] set canvas
  /// and surface close enough together that the lip has no edge of its own,
  /// and without this line the plate simply stops in the middle of nothing.
  final Color? hairlineColor;

  /// The tile the brand mark sits in, and the two colours it is drawn with.
  final double? markSize;
  final Color? markColor;
  final Color? markGroundColor;

  /// The plate's vertical wash — a tinted top falling to the page's own step,
  /// so the brand colour arrives as light rather than as a block of paint.
  final Color? plateTopColor;
  final Color? plateBottomColor;

  /// The soft radial glow, and the concentric arcs struck through it.
  ///
  /// Both are the accent at a low alpha, and both are drawn around one centre
  /// on the trailing edge — mirrored in a right-to-left layout, because a
  /// plate lit from the wrong side reads as a different design rather than as
  /// the same one translated.
  final Color? bloomColor;
  final Color? arcColor;
  final double? arcStroke;

  final TextStyle? eyebrowStyle;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  @override
  DSHeroStyle merge(DSHeroStyle? other) {
    if (other == null) return this;
    return DSHeroStyle(
      minHeight: other.minHeight ?? minHeight,
      padding: other.padding ?? padding,
      sheetRadius: other.sheetRadius ?? sheetRadius,
      sheetColor: other.sheetColor ?? sheetColor,
      hairlineColor: other.hairlineColor ?? hairlineColor,
      markSize: other.markSize ?? markSize,
      markColor: other.markColor ?? markColor,
      markGroundColor: other.markGroundColor ?? markGroundColor,
      plateTopColor: other.plateTopColor ?? plateTopColor,
      plateBottomColor: other.plateBottomColor ?? plateBottomColor,
      bloomColor: other.bloomColor ?? bloomColor,
      arcColor: other.arcColor ?? arcColor,
      arcStroke: other.arcStroke ?? arcStroke,
      eyebrowStyle: other.eyebrowStyle ?? eyebrowStyle,
      titleStyle: other.titleStyle ?? titleStyle,
      subtitleStyle: other.subtitleStyle ?? subtitleStyle,
    );
  }

  @override
  DSHeroStyle copyWith({
    double? minHeight,
    EdgeInsetsGeometry? padding,
    double? sheetRadius,
    Color? sheetColor,
    Color? hairlineColor,
    double? markSize,
    Color? markColor,
    Color? markGroundColor,
    Color? plateTopColor,
    Color? plateBottomColor,
    Color? bloomColor,
    Color? arcColor,
    double? arcStroke,
    TextStyle? eyebrowStyle,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
  }) => DSHeroStyle(
    minHeight: minHeight ?? this.minHeight,
    padding: padding ?? this.padding,
    sheetRadius: sheetRadius ?? this.sheetRadius,
    sheetColor: sheetColor ?? this.sheetColor,
    hairlineColor: hairlineColor ?? this.hairlineColor,
    markSize: markSize ?? this.markSize,
    markColor: markColor ?? this.markColor,
    markGroundColor: markGroundColor ?? this.markGroundColor,
    plateTopColor: plateTopColor ?? this.plateTopColor,
    plateBottomColor: plateBottomColor ?? this.plateBottomColor,
    bloomColor: bloomColor ?? this.bloomColor,
    arcColor: arcColor ?? this.arcColor,
    arcStroke: arcStroke ?? this.arcStroke,
    eyebrowStyle: eyebrowStyle ?? this.eyebrowStyle,
    titleStyle: titleStyle ?? this.titleStyle,
    subtitleStyle: subtitleStyle ?? this.subtitleStyle,
  );

  @override
  DSHeroStyle lerp(DSHeroStyle? other, double t) {
    if (other == null) return this;
    return DSHeroStyle(
      minHeight: lerpDouble(minHeight, other.minHeight, t),
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t),
      sheetRadius: lerpDouble(sheetRadius, other.sheetRadius, t),
      sheetColor: Color.lerp(sheetColor, other.sheetColor, t),
      hairlineColor: Color.lerp(hairlineColor, other.hairlineColor, t),
      markSize: lerpDouble(markSize, other.markSize, t),
      markColor: Color.lerp(markColor, other.markColor, t),
      markGroundColor: Color.lerp(markGroundColor, other.markGroundColor, t),
      plateTopColor: Color.lerp(plateTopColor, other.plateTopColor, t),
      plateBottomColor: Color.lerp(plateBottomColor, other.plateBottomColor, t),
      bloomColor: Color.lerp(bloomColor, other.bloomColor, t),
      arcColor: Color.lerp(arcColor, other.arcColor, t),
      arcStroke: lerpDouble(arcStroke, other.arcStroke, t),
      eyebrowStyle: TextStyle.lerp(eyebrowStyle, other.eyebrowStyle, t),
      titleStyle: TextStyle.lerp(titleStyle, other.titleStyle, t),
      subtitleStyle: TextStyle.lerp(subtitleStyle, other.subtitleStyle, t),
    );
  }

  static DSHeroStyle resolve(BuildContext context, [DSHeroStyle? own]) {
    final design = context.design;
    final component = design.component;
    final space = design.space;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return resolveStyle(
      context: context,
      specDefaults: DSHeroStyle(
        minHeight: component.heroMinHeight,
        padding: EdgeInsets.fromLTRB(
          space.pageGutter,
          space.md,
          space.pageGutter,
          space.lg,
        ),
        sheetRadius: context.radiusOf(AppShape.sheet),
        // The page's own ground, not `surface`: the hero does not introduce a
        // third step: it paints the one the content below it already stands on.
        sheetColor: palette.background,
        hairlineColor: palette.borderSoft,
        markSize: component.heroMarkSize,
        markColor: palette.primaryForeground,
        markGroundColor: palette.primary,
        plateTopColor: palette.secondary,
        plateBottomColor: palette.card,
        bloomColor: palette.primary,
        arcColor: palette.primary,
        arcStroke: component.heroPlateStroke,
        eyebrowStyle: AppTypography.eyebrow(context),
        // One step above the page header's title, and no more. `displaySmall`
        // was the first try: two words of it at a 1.3x text scale ate enough
        // of a 320-point screen that the form underneath went behind the
        // pinned bar, which `make ui-probe` caught. A hero is distinguished by
        // its plate, not by out-typing every other screen.
        titleStyle: text.headlineLarge?.copyWith(
          fontWeight: context.design.type.emphasisWeight,
          color: palette.foreground,
        ),
        subtitleStyle: DSTextRole.bodySupport.styleOf(context),
      ),
      own: own,
    );
  }
}

/// The plate that heads the first screen of a flow.
///
/// A sign-in screen built out of [DSPageHeader] is a form with a title on it.
/// That is correct for the twentieth screen of an app and wrong for the first
/// one, which is the only screen a user meets before they have any reason to
/// trust it — and the screenshot of the old login page is the argument: two
/// words of chrome over a column of grey rectangles, on a ground with no
/// colour, no depth and no mark.
///
/// So this component is doing one job the rest of the kit deliberately does
/// not: it is the app's face. The plate carries a brand mark, a wash of the
/// accent, a soft bloom and three struck arcs; the page's own ground then
/// rises over the bottom of it on [DSHeroStyle.sheetRadius], which is the
/// overlap that makes a flat screen read as two planes.
///
/// **Every mark of it is painted from the palette.** No asset, no gradient
/// literal, no second copy for dark. An app that changes its brand hue
/// changes its hero with it, exactly as [DSIllustration] does — and the four
/// identities the kit ships get four plates for free rather than one plate
/// that only looks right under [DesignSpec.halo].
///
/// The plate does not animate. An entrance on the screen a user sees while
/// waiting for a keyboard is a delay dressed as polish, and a moving plate is
/// a golden baseline that records a different frame every run.
///
/// **Use when** the screen is the entry point to a flow and has to say what
/// app this is — sign-in, sign-up, a paywall, a first-run welcome.
/// **Instead:** [DSPageHeader] for every screen after the first, where the
/// question is "where am I" rather than "what is this"; [DSLargeAppBar] when
/// the title must collapse as content scrolls under it, which a hero never
/// does.
class DSHero extends StatelessWidget {
  const DSHero({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.mark,
    this.leading,
    this.style,
  });

  final String title;

  /// The editorial line over the title — the same device [DSPageHeader] uses,
  /// and the same rule: not a breadcrumb and not a status.
  final String? eyebrow;

  /// One supporting line under the title.
  final String? subtitle;

  /// The brand mark. The kit's default is a glyph on an accent tile, which is
  /// a placeholder that looks deliberate; an app with a real logo passes it
  /// here and never touches the plate.
  ///
  /// It is decorative to a screen reader. The mark says the same thing the
  /// title says, and hearing the app's name twice before the first field is
  /// not an accessibility feature.
  final Widget? mark;

  /// A back affordance, at the top of the plate. Sign-in has none; every
  /// screen pushed from it does.
  final Widget? leading;

  final DSHeroStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = DSHeroStyle.resolve(context, style);
    final space = context.design.space;
    final component = context.design.component;

    return ClipRect(
      child: CustomPaint(
        painter: _DSHeroPlatePainter(
          style: resolved,
          textDirection: Directionality.of(context),
        ),
        child: SafeArea(
          bottom: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: resolved.minHeight!),
            // Bottom-aligned, so a long title at the largest text size grows
            // the plate upward and the title stays a fixed distance above the
            // first field rather than drifting away from it.
            child: Align(
              alignment: AlignmentDirectional.bottomStart,
              child: Padding(
                padding: resolved.padding!,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (leading != null) ...[
                      SizedBox(
                        height: component.minTapTarget,
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: leading,
                        ),
                      ),
                      space.verticalMd,
                    ],
                    ExcludeSemantics(
                      child: mark ?? _DSHeroMark(style: resolved),
                    ),
                    space.verticalMd,
                    MergeSemantics(
                      child: Semantics(
                        header: true,
                        namesRoute: true,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (eyebrow != null) ...[
                              Text(
                                AppTypography.eyebrowCase(context, eyebrow!),
                                style: resolved.eyebrowStyle,
                              ),
                              space.verticalXs,
                            ],
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: resolved.titleStyle,
                            ),
                            if (subtitle != null) ...[
                              space.verticalXs,
                              Text(
                                subtitle!,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: resolved.subtitleStyle,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // The room the lip needs. Content that ran under the turn
                    // would be clipped by a corner nobody can see coming.
                    SizedBox(height: resolved.sheetRadius! + space.sm),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The kit's placeholder mark: the glyph on its accent tile.
class _DSHeroMark extends StatelessWidget {
  const _DSHeroMark({required this.style});

  final DSHeroStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: style.markSize,
      height: style.markSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: style.markGroundColor,
        borderRadius: BorderRadius.circular(context.radiusOf(AppShape.card)),
      ),
      child: Icon(
        Icons.rocket_launch_rounded,
        size: context.design.component.iconSizeLarge,
        color: style.markColor,
      ),
    );
  }
}

/// The plate itself: a wash, a bloom, three arcs and the lip.
///
/// One painter rather than a stack of decorated boxes, and the lip is in here
/// with the rest of it. A `Positioned` lip would have to name a physical edge,
/// which `tool/ui_lint.dart` bans for exactly the reason this painter takes a
/// [textDirection]: the plate is lit from the trailing side, and the trailing
/// side moves.
class _DSHeroPlatePainter extends CustomPainter {
  const _DSHeroPlatePainter({required this.style, required this.textDirection});

  final DSHeroStyle style;
  final TextDirection textDirection;

  /// Where the light comes from, as a fraction of the plate. Off the trailing
  /// edge and above the top one, so the plate shows the falling edge of the
  /// glow rather than the hot centre of it.
  static const double _bloomAcross = 0.86;
  static const double _bloomDown = 0.06;

  /// The arcs, as fractions of the bloom's radius, with the alpha each is
  /// struck at. Three is the count: two reads as an accident, four reads as a
  /// target.
  static const List<(double, double)> _arcs = [
    (0.42, 0.20),
    (0.66, 0.13),
    (0.94, 0.08),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [style.plateTopColor!, style.plateBottomColor!],
        ).createShader(rect),
    );

    final across = textDirection == TextDirection.rtl
        ? 1 - _bloomAcross
        : _bloomAcross;
    final centre = Offset(size.width * across, size.height * _bloomDown);
    final radius = size.width * 0.9;

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            style.bloomColor!.withValues(alpha: 0.30),
            style.bloomColor!.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: centre, radius: radius)),
    );

    for (final (scale, alpha) in _arcs) {
      canvas.drawCircle(
        centre,
        radius * scale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = style.arcStroke!
          ..color = style.arcColor!.withValues(alpha: alpha),
      );
    }

    // The lip. Drawn twice its own height so only the turn shows: the bottom
    // half falls off the plate and meets the page's ground exactly.
    final corner = Radius.circular(style.sheetRadius!);
    final lip = RRect.fromRectAndCorners(
      Rect.fromLTWH(
        0,
        size.height - style.sheetRadius!,
        size.width,
        style.sheetRadius! * 2,
      ),
      topLeft: corner,
      topRight: corner,
    );
    canvas.drawRRect(lip, Paint()..color = style.sheetColor!);
    canvas.drawRRect(
      lip,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.arcStroke!
        ..color = style.hairlineColor!,
    );
  }

  /// The fields this painter reads, rather than the style object: a resolved
  /// style is a fresh instance on every build and carries no equality, so
  /// comparing the objects would repaint the plate on every frame of any
  /// animation running anywhere above it.
  @override
  bool shouldRepaint(_DSHeroPlatePainter old) =>
      old.textDirection != textDirection ||
      old.style.plateTopColor != style.plateTopColor ||
      old.style.plateBottomColor != style.plateBottomColor ||
      old.style.bloomColor != style.bloomColor ||
      old.style.arcColor != style.arcColor ||
      old.style.arcStroke != style.arcStroke ||
      old.style.sheetColor != style.sheetColor ||
      old.style.sheetRadius != style.sheetRadius ||
      old.style.hairlineColor != style.hairlineColor;
}
