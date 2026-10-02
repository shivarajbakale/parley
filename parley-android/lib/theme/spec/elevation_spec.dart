import 'package:flutter/material.dart';

/// How far above the page a surface sits, as a role rather than a number.
///
/// A caller who can pass `elevation: 7.3` has left the ladder, and the ladder
/// is the only reason two surfaces on one screen agree about which is nearer.
enum DSElevation { none, low, medium, high, highest }

/// The shadow contract, as a recipe rather than a table.
///
/// Every level is two layers: a tight contact shadow that says the surface is
/// touching the one under it, and a wide ambient one that says how far above
/// it sits. One layer at every level is a large part of what reads flat, and
/// it is what the previous single-layer ramp did.
///
/// [intensity] is the knob. At `0` the app has no shadows at all — a
/// legitimate identity, and the one a flat or brutalist direction wants —
/// without any widget learning about it.
@immutable
class ElevationSpec {
  /// Elevation values the app uses, low to high. Widgets name a level; the
  /// spec decides what a level looks like.
  final List<double> levels;

  /// Blur of the contact layer per level, and its vertical offset.
  final double contactBlur;
  final double contactOffset;

  /// Blur of the ambient layer per level, and its vertical offset. Both scale
  /// with the level, which is what makes a raised surface read as further away
  /// rather than merely darker.
  final double ambientBlur;
  final double ambientOffset;

  /// Opacity of each layer at level 1, on light and on dark. Dark needs more:
  /// a shadow is the absence of light, and there is less light to remove.
  ///
  /// The light pair is deliberately quiet. It was raised to .070/.065 while
  /// the light card was white on a light page — a tone step small enough to
  /// vanish on a dim display, so the shadow had to carry the separation
  /// alone. The card steps *down* from a white page again, which puts a
  /// 1.20:1 edge back under it, so the shadow is the second signal rather
  /// than the only one and does not need the weight.
  final double contactAlphaLight;
  final double ambientAlphaLight;
  final double contactAlphaDark;
  final double ambientAlphaDark;

  /// Multiplies every alpha. 0 disables shadows entirely.
  final double intensity;

  const ElevationSpec({
    this.levels = const [0, 1, 2, 4, 8],
    this.contactBlur = 1,
    this.contactOffset = 1,
    this.ambientBlur = 5,
    this.ambientOffset = 1.7,
    this.contactAlphaLight = 0.075,
    this.ambientAlphaLight = 0.055,
    this.contactAlphaDark = 0.250,
    this.ambientAlphaDark = 0.150,
    this.intensity = 1,
  });

  /// The number a role resolves to in this identity.
  double levelOf(DSElevation level) => switch (level) {
    DSElevation.none => levels[0],
    DSElevation.low => levels[1],
    DSElevation.medium => levels[2],
    DSElevation.high => levels[3],
    DSElevation.highest => levels[4],
  };

  /// One step nearer the page. `none` has nowhere to go.
  static DSElevation lower(DSElevation level) => switch (level) {
    DSElevation.none => DSElevation.none,
    DSElevation.low => DSElevation.none,
    DSElevation.medium => DSElevation.low,
    DSElevation.high => DSElevation.medium,
    DSElevation.highest => DSElevation.high,
  };

  double get none => levels[0];
  double get low => levels[1];
  double get medium => levels[2];
  double get high => levels[3];
  double get highest => levels[4];

  /// The two layers for an elevation.
  ///
  /// [shadowColor] comes from the palette rather than being black: a warm
  /// canvas wants a warm shadow, and a pure black one over it reads as dirt.
  List<BoxShadow> resolve({
    required double elevation,
    required Brightness brightness,
    required Color shadowColor,
  }) {
    if (elevation <= 0 || intensity <= 0) return const [];
    final isLight = brightness == Brightness.light;
    // Rank rather than raw value, so the ramp stays even when an identity
    // changes the numbers in `levels`.
    var rank = 1;
    for (var i = 1; i < levels.length; i++) {
      if (elevation <= levels[i]) {
        rank = i;
        break;
      }
      rank = i;
    }
    final growth = rank.toDouble();
    final ca =
        (isLight ? contactAlphaLight : contactAlphaDark) *
        intensity *
        (1 + (growth - 1) * 0.22);
    final aa =
        (isLight ? ambientAlphaLight : ambientAlphaDark) *
        intensity *
        (1 + (growth - 1) * 0.18);
    return [
      BoxShadow(
        color: shadowColor.withValues(alpha: ca.clamp(0.0, 1.0)),
        blurRadius: contactBlur * growth,
        offset: Offset(0, contactOffset * growth * 0.6),
      ),
      BoxShadow(
        color: shadowColor.withValues(alpha: aa.clamp(0.0, 1.0)),
        blurRadius: ambientBlur * growth * 1.25,
        offset: Offset(0, ambientOffset * growth * 1.05),
      ),
    ];
  }

  /// A sheet's shadow points up, because a sheet arrives from the bottom and
  /// the edge a reader sees is its top one.
  List<BoxShadow> sheet({
    required Brightness brightness,
    required Color shadowColor,
  }) =>
      resolve(elevation: high, brightness: brightness, shadowColor: shadowColor)
          .map(
            (s) => BoxShadow(
              color: s.color,
              blurRadius: s.blurRadius,
              offset: Offset(0, -s.offset.dy),
            ),
          )
          .toList();

  ElevationSpec copyWith({List<double>? levels, double? intensity}) =>
      ElevationSpec(
        levels: levels ?? this.levels,
        contactBlur: contactBlur,
        contactOffset: contactOffset,
        ambientBlur: ambientBlur,
        ambientOffset: ambientOffset,
        contactAlphaLight: contactAlphaLight,
        ambientAlphaLight: ambientAlphaLight,
        contactAlphaDark: contactAlphaDark,
        ambientAlphaDark: ambientAlphaDark,
        intensity: intensity ?? this.intensity,
      );
}
