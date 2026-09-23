import 'dart:math' as math;
import 'dart:ui' show Color;

/// OKLCH, so a palette can be *derived* rather than typed.
///
/// The reason this exists rather than a table of hex codes: at a fixed HSL
/// lightness, yellow is far brighter than blue. Sample six hues that way and
/// they read as a crayon box, because the eye sorts them by weight before it
/// sorts them by hue. OKLCH is perceptually uniform, so six hues at one
/// lightness and one chroma read as one family — which is the whole premise
/// of a colour-per-category list.
///
/// The maths is Björn Ottosson's, and it is the same conversion a browser runs
/// for the CSS `oklch()` function. No package: this is forty lines of matrix
/// multiplication, and a dependency here would be a dependency in every app
/// this boilerplate produces.
///
/// ```dart
/// const espresso = Oklch(0.13, 0.014, 55);
/// final color = espresso.toColor();
/// ```
class Oklch {
  /// Perceptual lightness, 0 (black) to 1 (white).
  final double l;

  /// Chroma — colourfulness. 0 is grey; sRGB runs out somewhere around 0.37
  /// at the most saturated hues and much sooner elsewhere.
  final double c;

  /// Hue angle in degrees.
  final double h;

  const Oklch(this.l, this.c, this.h);

  Oklch copyWith({double? l, double? c, double? h}) =>
      Oklch(l ?? this.l, c ?? this.c, h ?? this.h);

  /// This colour with its lightness moved to [l], hue and chroma held.
  Oklch atL(double l) => Oklch(l, c, h);

  /// The sRGB colour, gamut-mapped.
  ///
  /// When the requested chroma does not fit sRGB, chroma is what gives:
  /// lightness is how heavy a colour reads next to its neighbours and hue is
  /// which colour it *is*, so bending either to keep saturation would break
  /// the two properties the family depends on.
  Color toColor([double opacity = 1]) {
    final rad = h * math.pi / 180;
    final cosH = math.cos(rad), sinH = math.sin(rad);

    double chroma = c;
    if (!_inGamut(_linearSrgb(l, c * cosH, c * sinH))) {
      double lo = 0, hi = c;
      // 24 halvings resolve chroma to well under a 1/255 step.
      for (var i = 0; i < 24; i++) {
        final mid = (lo + hi) / 2;
        if (_inGamut(_linearSrgb(l, mid * cosH, mid * sinH))) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      chroma = lo;
    }

    final rgb = _linearSrgb(l, chroma * cosH, chroma * sinH);
    return Color.from(
      alpha: opacity,
      red: _gamma(rgb[0]),
      green: _gamma(rgb[1]),
      blue: _gamma(rgb[2]),
    );
  }

  /// The most chroma sRGB can hold at [l] and [h].
  ///
  /// A family sampled at one chroma is only uniform if every hue in it can
  /// actually reach that chroma. Cyan at lightness 0.755 tops out near 0.129
  /// while orange at the same lightness goes far past it — so asking all six
  /// for 0.135 delivers five saturated colours and one washed one, which is
  /// the crayon box arriving by a different route.
  static double maxChroma(double l, double h) {
    final rad = h * math.pi / 180;
    final cosH = math.cos(rad), sinH = math.sin(rad);
    double lo = 0, hi = 0.5;
    for (var i = 0; i < 24; i++) {
      final mid = (lo + hi) / 2;
      if (_inGamut(_linearSrgb(l, mid * cosH, mid * sinH))) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// Round-trip a shipped colour back into OKLCH.
  ///
  /// This is what lets a test assert things about a palette that already
  /// exists — that its surface ladder rises monotonically, that its category
  /// hues really do share a lightness — rather than only about the seeds it
  /// was asked for.
  factory Oklch.fromColor(Color color) {
    final r = _degamma(color.r);
    final g = _degamma(color.g);
    final b = _degamma(color.b);

    final l = math
        .pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1 / 3)
        .toDouble();
    final m = math
        .pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1 / 3)
        .toDouble();
    final s = math
        .pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1 / 3)
        .toDouble();

    final lightness = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
    final aa = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
    final bb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;

    final hue = math.atan2(bb, aa) * 180 / math.pi;
    return Oklch(
      lightness,
      math.sqrt(aa * aa + bb * bb),
      hue < 0 ? hue + 360 : hue,
    );
  }

  /// Shortest angular distance between two hues, in degrees, 0..180.
  ///
  /// Plain subtraction says hue 350 and hue 10 are 340 apart when they are
  /// twenty — which would make an evenly spaced family look uneven to any
  /// test that checked it.
  static double hueDistance(double a, double b) {
    final d = (a - b).abs() % 360;
    return d > 180 ? 360 - d : d;
  }

  @override
  String toString() =>
      'oklch(${l.toStringAsFixed(3)} ${c.toStringAsFixed(3)} ${h.toStringAsFixed(1)})';

  @override
  bool operator ==(Object other) =>
      other is Oklch && other.l == l && other.c == c && other.h == h;

  @override
  int get hashCode => Object.hash(l, c, h);
}

List<double> _linearSrgb(double lightness, double a, double b) {
  final lp = lightness + 0.3963377774 * a + 0.2158037573 * b;
  final mp = lightness - 0.1055613458 * a - 0.0638541728 * b;
  final sp = lightness - 0.0894841775 * a - 1.2914855480 * b;
  final l = lp * lp * lp, m = mp * mp * mp, s = sp * sp * sp;
  return [
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
  ];
}

bool _inGamut(List<double> rgb) {
  const e = 1e-4;
  for (final c in rgb) {
    if (c < -e || c > 1 + e) return false;
  }
  return true;
}

double _gamma(double c) {
  final v = c <= 0.0031308 ? 12.92 * c : 1.055 * math.pow(c, 1 / 2.4) - 0.055;
  return v.clamp(0.0, 1.0).toDouble();
}

double _degamma(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

/// WCAG relative luminance of a shipped colour.
double relativeLuminance(Color color) =>
    0.2126 * _degamma(color.r) +
    0.7152 * _degamma(color.g) +
    0.0722 * _degamma(color.b);

/// WCAG contrast ratio, 1:1 to 21:1.
///
/// Measured on the sRGB the app actually draws, not on the OKLCH it was asked
/// for, because gamut mapping can move a colour after the seeds are chosen.
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a), lb = relativeLuminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
