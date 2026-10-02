import 'package:flutter/material.dart';

/// What a surface is for. Widgets ask for a role, never a number, so one spec
/// can make every dialog a squircle and every chip a cut corner at once.
enum AppShape { card, control, tile, dialog, sheet, pill, bar }

/// How a corner is drawn.
///
/// This is the single knob that most changes what an app *is*: the same
/// layout in [cut] corners and in [squircle] corners are not the same design.
/// [platform] is the adaptive default — a superellipse on Apple, a circular
/// arc on Android — and is the only value that differs by device.
enum CornerStyle { platform, rounded, squircle, cut }

/// Corner geometry, as data.
@immutable
class ShapeSpec {
  final CornerStyle style;

  /// Radius per role on Apple, then on Material. Two values because the
  /// platforms genuinely disagree about how round a control is, and an
  /// identity that wants one answer sets both the same.
  final Map<AppShape, (double apple, double material)> radii;

  /// Multiplies every radius. `0` squares the whole app off; `1.6` rounds it.
  final double scale;

  const ShapeSpec({
    this.style = CornerStyle.platform,
    this.radii = const {
      AppShape.card: (20, 20),
      AppShape.control: (14, 14),
      AppShape.tile: (16, 16),
      AppShape.dialog: (20, 20),
      AppShape.sheet: (28, 28),
      AppShape.pill: (999, 999),
      AppShape.bar: (0, 0),
    },
    this.scale = 1,
  });

  double radiusOf(AppShape shape, {required bool isApple}) {
    final pair = radii[shape]!;
    final raw = isApple ? pair.$1 : pair.$2;
    // The pill is a stadium, not a large radius — scaling it would turn a
    // capsule into an arbitrary rounded rectangle at scale < 1.
    return shape == AppShape.pill ? raw : raw * scale;
  }

  /// The border for a role.
  ///
  /// A sheet rounds only its top: the bottom is off-screen, and rounding it
  /// leaves two visible notches against the device edge.
  OutlinedBorder border(AppShape shape, {required bool isApple}) {
    if (shape == AppShape.pill) return const StadiumBorder();
    final r = radiusOf(shape, isApple: isApple);
    final geometry = shape == AppShape.sheet
        ? BorderRadius.vertical(top: Radius.circular(r))
        : BorderRadius.circular(r);

    final resolved = style == CornerStyle.platform
        ? (isApple ? CornerStyle.squircle : CornerStyle.rounded)
        : style;

    switch (resolved) {
      case CornerStyle.squircle:
        return RoundedSuperellipseBorder(borderRadius: geometry);
      case CornerStyle.cut:
        return BeveledRectangleBorder(borderRadius: geometry);
      case CornerStyle.rounded:
      case CornerStyle.platform:
        return RoundedRectangleBorder(borderRadius: geometry);
    }
  }

  /// The border for a set of corners the caller has already decided.
  ///
  /// [border] answers for a *role*, whose four corners are equal. A chat
  /// bubble's are not: the corner nearest the speaker is tightened, and the
  /// tightening is what makes a run of turns read as one utterance. Without
  /// this, the only way to draw that was a `BoxDecoration.borderRadius`,
  /// which is a circular arc — so every bubble in the app opted out of the
  /// identity's corner style, and on Apple the squircle the rest of the
  /// screen is drawn in stopped at the transcript.
  ShapeBorder borderFor(
    BorderRadiusGeometry radius, {
    required bool isApple,
    BorderSide side = BorderSide.none,
  }) {
    final resolved = style == CornerStyle.platform
        ? (isApple ? CornerStyle.squircle : CornerStyle.rounded)
        : style;

    switch (resolved) {
      case CornerStyle.squircle:
        return RoundedSuperellipseBorder(borderRadius: radius, side: side);
      case CornerStyle.cut:
        return BeveledRectangleBorder(borderRadius: radius, side: side);
      case CornerStyle.rounded:
      case CornerStyle.platform:
        return RoundedRectangleBorder(borderRadius: radius, side: side);
    }
  }

  ShapeSpec copyWith({
    CornerStyle? style,
    Map<AppShape, (double, double)>? radii,
    double? scale,
  }) => ShapeSpec(
    style: style ?? this.style,
    radii: radii ?? this.radii,
    scale: scale ?? this.scale,
  );
}
