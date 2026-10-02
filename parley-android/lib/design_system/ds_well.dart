// ds-tier: 1 — atom

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The three sizes a well comes in.
enum DSWellSize { sm, md, lg }

/// How a well looks, at every layer of the resolution chain.
@immutable
class DSWellStyle extends DSComponentStyle<DSWellStyle> {
  const DSWellStyle({
    this.size,
    this.shape,
    this.fill,
    this.foreground,
    this.iconColor,
    this.iconSize,
  });

  final double? size;
  final AppShape? shape;

  /// The identity's derived container for this tone — not an alpha over an
  /// arbitrary colour.
  final Color? fill;

  /// A text child (an emoji, a two-letter code). Text on a tint is the
  /// foreground.
  final Color? foreground;

  /// The glyph: the tone's own colour, a graphical object held at 3:1.
  final Color? iconColor;
  final double? iconSize;

  @override
  DSWellStyle merge(DSWellStyle? other) {
    if (other == null) return this;
    return DSWellStyle(
      size: other.size ?? size,
      shape: other.shape ?? shape,
      fill: other.fill ?? fill,
      foreground: other.foreground ?? foreground,
      iconColor: other.iconColor ?? iconColor,
      iconSize: other.iconSize ?? iconSize,
    );
  }

  @override
  DSWellStyle copyWith({
    double? size,
    AppShape? shape,
    Color? fill,
    Color? foreground,
    Color? iconColor,
    double? iconSize,
  }) => DSWellStyle(
    size: size ?? this.size,
    shape: shape ?? this.shape,
    fill: fill ?? this.fill,
    foreground: foreground ?? this.foreground,
    iconColor: iconColor ?? this.iconColor,
    iconSize: iconSize ?? this.iconSize,
  );

  @override
  DSWellStyle lerp(DSWellStyle? other, double t) {
    if (other == null) return this;
    return DSWellStyle(
      shape: t < 0.5 ? shape : other.shape,
      size: lerpDouble(size, other.size, t),
      fill: Color.lerp(fill, other.fill, t),
      foreground: Color.lerp(foreground, other.foreground, t),
      iconColor: Color.lerp(iconColor, other.iconColor, t),
      iconSize: lerpDouble(iconSize, other.iconSize, t),
    );
  }

  static DSWellStyle resolve(
    BuildContext context, {
    DSTone tone = DSTone.neutral,
    DSWellSize size = DSWellSize.md,
    DSWellStyle? own,
  }) {
    final design = context.design;
    final component = design.component;
    final palette = context.palette;

    // A default-size well in a list row takes the row's extent, and its glyph
    // the same share of it every row well gets.
    final rowExtent = size == DSWellSize.md
        ? DSRowLeadingScope.extentOf(context)
        : null;
    final (double box, double glyph) = switch (size) {
      DSWellSize.sm => (component.wellSizeSm, component.iconSizeMicro),
      DSWellSize.md when rowExtent != null => (
        rowExtent,
        rowExtent * component.rowWellGlyphRatio,
      ),
      DSWellSize.md => (component.wellSize, component.iconSizeInline),
      DSWellSize.lg => (component.wellSizeLg, component.iconSizeLarge),
    };

    // The identity's derived pair, per theme. A fixed alpha over an arbitrary
    // colour derives nothing and checks nothing: at 10% over a light surface
    // an accent reads as a whisper, and the same 10% over a dark surface reads
    // as almost nothing, because the tint is composited against grounds of
    // opposite luminance. Four call sites computed exactly that, at three
    // different alphas.
    final (Color fill, Color foreground, Color iconColor) = switch (tone) {
      DSTone.neutral => (
        palette.secondary,
        palette.secondaryForeground,
        palette.secondaryForeground,
      ),
      DSTone.info => (
        palette.tint(palette.primary),
        palette.foreground,
        palette.primary,
      ),
      DSTone.success => (
        palette.tint(palette.success),
        palette.foreground,
        palette.success,
      ),
      DSTone.warning => (
        palette.tint(palette.warning),
        palette.foreground,
        palette.warning,
      ),
      DSTone.error => (
        palette.tint(palette.destructive),
        palette.foreground,
        palette.destructive,
      ),
    };

    return resolveStyle(
      context: context,
      specDefaults: DSWellStyle(
        size: box,
        shape: component.wellShape,
        fill: fill,
        foreground: foreground,
        iconColor: iconColor,
        iconSize: glyph,
      ),
      own: own,
    );
  }
}

/// The tinted container behind a glyph.
///
/// See `docs/plans/28-ds-avatar-badge-well.plan.md`. The kit painted this
/// shape in four places — the icon container, the badge, the dialog's icon and
/// the list row's leading slot — at three different alphas and one container
/// token, for one visual idea. This is the implementation; the others are
/// wrappers around it.
///
/// Renamed from `DSIconContainer`, whose `required Color color` obliged every
/// call site to name a raw colour because there was no correct default to fall
/// back to. It takes a [tone] and reads the identity's
/// derived pair instead.
///
/// It is decorative: the meaning of what is inside it is carried by whatever
/// names the row or the dialog it sits in, so the well itself is excluded from
/// the semantics tree.
class DSWell extends StatelessWidget {
  const DSWell({
    super.key,
    this.icon,
    this.child,
    this.tone = DSTone.neutral,
    this.size = DSWellSize.md,
    this.style,
  }) : assert(
         icon != null || child != null,
         'a well with nothing in it is a coloured circle — pass an icon or a '
         'child',
       );

  final IconData? icon;

  /// A glyph, an emoji, a two-letter code. The reason this is a well and not
  /// an icon container.
  final Widget? child;

  final DSTone tone;

  final DSWellSize size;
  final DSWellStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = DSWellStyle.resolve(
      context,
      tone: tone,
      size: size,
      own: style,
    );
    return ExcludeSemantics(
      child: Container(
        width: resolved.size,
        height: resolved.size,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: resolved.fill,
          shape: context.shapeOf(resolved.shape!),
        ),
        child: IconTheme.merge(
          data: IconThemeData(
            color: resolved.iconColor,
            size: resolved.iconSize,
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: resolved.foreground),
            child: child ?? Icon(icon),
          ),
        ),
      ),
    );
  }
}
