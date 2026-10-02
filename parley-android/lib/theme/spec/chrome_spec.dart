import 'package:flutter/widgets.dart';

/// What the floating layer is made of.
///
/// Glass belongs to navigation and controls that float above content; content
/// itself stays opaque (`docs/principles/depth-and-materials.md`). This enum
/// decides which of the three the chrome uses — it does not license content to
/// use any of them.
enum ChromeMaterial {
  /// Blur, saturate, and a specular top edge. The Apple default.
  glass,

  /// An opaque tonal surface a step off the canvas. The Material default.
  tonal,

  /// No lift and no blur — the chrome is the same plane as the page, separated
  /// by a hairline only. A legitimate identity, and the cheapest to render.
  flat,
}

/// The chrome layer, as data.
@immutable
class ChromeSpec {
  /// Which material the chrome uses on Apple, and on Material. Two fields
  /// rather than one so an identity can refuse to adapt: setting both to
  /// [ChromeMaterial.flat] gives one app on both platforms, deliberately.
  final ChromeMaterial apple;
  final ChromeMaterial material;

  /// Blur radius for a chrome surface, in logical pixels. Wide enough that
  /// text behind it becomes texture rather than words — anything less and the
  /// reader tries to read what is underneath.
  ///
  /// There is no second radius for sheets: a sheet is opaque on purpose (see
  /// `AppMaterials.sheet`), and a blur nothing applies is a knob that lies.
  final double barBlur;

  /// How much colour the blur pulls out of what is behind it. Above 1 the
  /// content behind glass keeps its life; at 1 a blurred photo turns grey,
  /// which is what makes cheap glass look like frosted plastic.
  final double saturation;

  /// Alpha of the tint over the blur, per brightness. Dark takes less: the
  /// same alpha over a dark backdrop hides the movement that is the whole
  /// point of the material.
  final double tintAlpha;
  final double tintAlphaDark;

  /// Alpha of the specular hairline along the top edge, per brightness. The
  /// hairline is most of what sells the material — it is the edge catching
  /// whichever light is brighter than the surface behind it, so in light it
  /// is a soft dark line and in dark it is a bright one, and the two need
  /// very different amounts.
  final double specularAlpha;
  final double specularAlphaDark;

  /// Elevation the chrome sits at, indexed into [ElevationSpec.levels].
  final double elevation;

  /// The soft wash at the top of every page, per brightness, fading into the
  /// palette background at [groundWashExtent] of the page's height. Empty is
  /// a flat ground.
  final List<Color> groundWash;
  final List<Color> groundWashDark;
  final double groundWashExtent;

  const ChromeSpec({
    this.apple = ChromeMaterial.glass,
    this.material = ChromeMaterial.tonal,
    this.barBlur = 24,
    this.saturation = 1.6,
    this.tintAlpha = 0.72,
    this.tintAlphaDark = 0.64,
    this.specularAlpha = 0.65,
    this.specularAlphaDark = 0.22,
    this.elevation = 2,
    this.groundWash = const <Color>[],
    this.groundWashDark = const <Color>[],
    this.groundWashExtent = 0.55,
  });

  List<Color> groundWashFor(Brightness brightness) =>
      brightness == Brightness.light ? groundWash : groundWashDark;

  ChromeMaterial materialFor({required bool isApple}) =>
      isApple ? apple : material;

  /// The tint's alpha for a brightness.
  double tintAlphaFor(Brightness brightness) =>
      brightness == Brightness.light ? tintAlpha : tintAlphaDark;

  /// The specular hairline's alpha for a brightness.
  double specularAlphaFor(Brightness brightness) =>
      brightness == Brightness.light ? specularAlpha : specularAlphaDark;

  ChromeSpec copyWith({
    ChromeMaterial? apple,
    ChromeMaterial? material,
    double? barBlur,
    double? saturation,
    double? tintAlpha,
    double? tintAlphaDark,
    double? specularAlpha,
    double? specularAlphaDark,
    List<Color>? groundWash,
    List<Color>? groundWashDark,
    double? groundWashExtent,
  }) => ChromeSpec(
    apple: apple ?? this.apple,
    material: material ?? this.material,
    barBlur: barBlur ?? this.barBlur,
    saturation: saturation ?? this.saturation,
    tintAlpha: tintAlpha ?? this.tintAlpha,
    tintAlphaDark: tintAlphaDark ?? this.tintAlphaDark,
    specularAlpha: specularAlpha ?? this.specularAlpha,
    specularAlphaDark: specularAlphaDark ?? this.specularAlphaDark,
    elevation: elevation,
    groundWash: groundWash ?? this.groundWash,
    groundWashDark: groundWashDark ?? this.groundWashDark,
    groundWashExtent: groundWashExtent ?? this.groundWashExtent,
  );
}
