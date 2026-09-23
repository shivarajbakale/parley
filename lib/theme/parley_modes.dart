import 'package:flutter/material.dart';

/// What the orb (and every dot that echoes it) is doing.
enum OrbMode { idle, dictation, edit, done, error }

/// The orb's colours and clocks — the one part of Aurora that is not grown
/// from palette seeds, because it has to match the Kotlin `OrbView` and the
/// Mac app's orb byte for byte. Mockups:
/// https://claude.ai/artifact/KHuAChbQqTC4rzpxnreHBj
///
/// Each mode is four radial stops, highlight to rim, plus the glow colour and
/// the colour a small status dot uses for the same meaning. The dot colours
/// are tuned per brightness to clear 3:1 as graphical objects on the card.
@immutable
class OrbPalette {
  const OrbPalette({
    required this.stops,
    required this.glow,
    required this.darkDot,
    required this.lightDot,
  });

  final List<Color> stops;
  final Color glow;
  final Color darkDot;
  final Color lightDot;

  Color dotFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkDot : lightDot;

  static const dictation = OrbPalette(
    stops: [
      Color(0xFFE4E4FF),
      Color(0xFF9C9CFF),
      Color(0xFF5B4FE0),
      Color(0xFF231A6E),
    ],
    glow: Color(0xFF6B6BF0),
    darkDot: Color(0xFF8B8BFF),
    lightDot: Color(0xFF4646D6),
  );

  static const edit = OrbPalette(
    stops: [
      Color(0xFFFFF4D6),
      Color(0xFFF7C35C),
      Color(0xFFD2811A),
      Color(0xFF6B3706),
    ],
    glow: Color(0xFFF4B942),
    darkDot: Color(0xFFF4B942),
    lightDot: Color(0xFFA86A00),
  );

  static const done = OrbPalette(
    stops: [
      Color(0xFFDDFBEA),
      Color(0xFF7FE3AE),
      Color(0xFF2FA86A),
      Color(0xFF0D4A2B),
    ],
    glow: Color(0xFF4CD38A),
    darkDot: Color(0xFF4CD38A),
    lightDot: Color(0xFF1E8A55),
  );

  static const error = OrbPalette(
    stops: [
      Color(0xFFFFE0E0),
      Color(0xFFFF9C9C),
      Color(0xFFD94848),
      Color(0xFF5E1414),
    ],
    glow: Color(0xFFFF6E6E),
    darkDot: Color(0xFFFF8A8A),
    lightDot: Color(0xFFC23B3B),
  );

  static const idle = OrbPalette(
    stops: [
      Color(0xFFC9C9E6),
      Color(0xFF7C7CB8),
      Color(0xFF3E3A7A),
      Color(0xFF1A1640),
    ],
    glow: Color(0xFF6B6BF0),
    darkDot: Color(0xFF9C9CB2),
    lightDot: Color(0xFF6B6B80),
  );

  /// The rim light every mode shares.
  static const sheen = Color(0xFFFFFFFF);

  static OrbPalette of(OrbMode mode) => switch (mode) {
    OrbMode.idle => idle,
    OrbMode.dictation => dictation,
    OrbMode.edit => edit,
    OrbMode.done => done,
    OrbMode.error => error,
  };
}

/// The orb's clocks. Slow enough to read as breathing rather than as a
/// loading spinner; the listening pulse is the only fast one, because it is
/// the only moment something is being done to the user's voice.
abstract final class OrbMotion {
  static const breathe = Duration(milliseconds: 4200);
  static const listenPulse = Duration(milliseconds: 1100);
  static const ring = Duration(milliseconds: 1400);

  /// How far the orb swells at the top of a breath.
  static const breatheScale = 0.05;

  /// Where the highlight sits, as an alignment inside the orb.
  static const highlight = Alignment(-0.32, -0.44);
}
