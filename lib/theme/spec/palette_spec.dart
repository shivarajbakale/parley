import 'package:flutter/material.dart';
import 'package:parley_android/theme/spec/oklch.dart';

/// Every colour the app draws, for one brightness — fifteen roles.
///
/// A widget never names a colour; it names a role. Fifteen is the count a
/// designer can hold in their head: three grounds, two text greys, a primary
/// and a secondary with what reads on each, one border, one focus ring, three
/// statuses and the overlay. Everything else is derived below rather than
/// stored, so it cannot drift away from the role it came from.
@immutable
class Palette {
  final Brightness brightness;

  /// The page.
  final Color background;

  /// Primary reading colour.
  final Color foreground;

  /// A card, a sheet, a menu — raised off [background].
  final Color card;

  /// Recessed: an input fill, a track, a skeleton, a pressed state.
  final Color muted;

  /// Supporting copy, metadata, captions and hints.
  final Color mutedForeground;

  /// The one colour that means "this does something". Also carries info.
  final Color primary;
  final Color primaryForeground;

  /// [primary] at container weight: a selected chip, a tinted slot.
  final Color secondary;
  final Color secondaryForeground;

  /// A quiet hairline, about 1.3:1 on the card. [borderSoft] is the divider.
  final Color border;

  /// The focus indicator.
  final Color ring;

  final Color destructive;
  final Color success;
  final Color warning;

  /// The dim behind a modal, and the shadow colour. Carries alpha at use.
  final Color overlay;

  /// The brand moment: primary buttons, the hero card, the selected nav pill,
  /// a progress fill. Nowhere else.
  final LinearGradient primaryGradient;

  /// Data-visualisation only: chart series, metric bars, progress rings.
  final List<Color> chart;

  /// The only literal black and white in the app, reachable without a palette
  /// (a route's `barrierColor` has no context).
  static const Color overlayInk = Color(0xFF000000);
  static const Color sheenInk = Color(0xFFFFFFFF);

  const Palette({
    required this.brightness,
    required this.background,
    required this.foreground,
    required this.card,
    required this.muted,
    required this.mutedForeground,
    required this.primary,
    required this.primaryForeground,
    required this.secondary,
    required this.secondaryForeground,
    required this.border,
    required this.ring,
    required this.destructive,
    required this.success,
    required this.warning,
    required this.primaryGradient,
    required this.chart,
    this.overlay = overlayInk,
  });

  // ── Derived ──────────────────────────────────────────────────────────────

  static Color _readableOn(Color c) {
    const light = Color(0xFFFFFFFF);
    const dark = Color(0xFF0B0F0E);
    return contrastRatio(c, light) >= contrastRatio(c, dark) ? light : dark;
  }

  Color get onDestructive => _readableOn(destructive);
  Color get onSuccess => _readableOn(success);
  Color get onWarning => _readableOn(warning);

  /// A status or primary background: the colour at 12% over the card.
  Color tint(Color c) => Color.alphaBlend(c.withValues(alpha: 0.12), card);

  /// The divider: [border] at 55% over the card.
  Color get borderSoft =>
      Color.alphaBlend(border.withValues(alpha: 0.55), card);

  /// Snack bars and tooltips invert against the page.
  Color get inverseBackground => foreground;
  Color get inverseForeground => background;

  Color get sheen => sheenInk;

  /// The raised end of this theme, measured: floating chrome takes it.
  Color get chrome {
    if (brightness == Brightness.dark) return card;
    return card.computeLuminance() >= background.computeLuminance()
        ? card
        : background;
  }

  /// A field-shaped control's fill; see [chrome] for why it is measured.
  Color get fieldFill => chrome;

  ColorScheme toColorScheme() => ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: primaryForeground,
    primaryContainer: secondary,
    onPrimaryContainer: secondaryForeground,
    secondary: secondary,
    onSecondary: secondaryForeground,
    secondaryContainer: secondary,
    onSecondaryContainer: secondaryForeground,
    tertiary: secondary,
    onTertiary: secondaryForeground,
    tertiaryContainer: secondary,
    onTertiaryContainer: secondaryForeground,
    error: destructive,
    onError: onDestructive,
    errorContainer: tint(destructive),
    onErrorContainer: destructive,
    surface: background,
    onSurface: foreground,
    onSurfaceVariant: mutedForeground,
    surfaceContainerLowest: muted,
    surfaceContainerLow: card,
    surfaceContainer: card,
    surfaceContainerHigh: card,
    surfaceContainerHighest: muted,
    outline: border,
    outlineVariant: borderSoft,
    inverseSurface: inverseBackground,
    onInverseSurface: inverseForeground,
    inversePrimary: secondary,
    scrim: overlay,
    shadow: overlay,
    surfaceTint: primary,
  );
}

/// The numbers a palette is grown from, for one brightness.
///
/// Seeds instead of sixty hex codes. Changing [accentHue] recolours every
/// accented pixel in the app; changing [canvasHue] moves the whole ground
/// under it. That is the property this class exists for, and a test proves it
/// by rendering two specs that differ in one number.
@immutable
class PaletteSeeds {
  final Brightness brightness;

  /// The ground. A hue and a low chroma, never zero: a neutral grey ladder is
  /// most of what makes a dark app read cheap, because tinted darks are what
  /// the eye reads as a material rather than as an absence.
  final double canvasHue;
  final double canvasChroma;

  /// Three lightnesses — page, card, recess — in that order.
  final List<double> canvasLadder;

  /// Two text lightnesses — foreground, then muted foreground — most
  /// important first.
  final List<double> textLadder;

  /// The hairline. The divider is derived from it.
  final double outlineLightness;

  final double accentHue;
  final double accentChroma;
  final double accentLightness;
  final double accentWellLightness;
  final double accentWellChroma;

  /// How many hues to grow around the wheel, and where the family starts.
  /// The rest are spaced evenly from there. Only the first five feed the
  /// chart scale — the extra hues exist so chroma is fit against chroma
  /// headroom across a wider spread of the wheel than the chart alone would
  /// ask for.
  /// Starting at the accent's own hue is what ties the family to the brand
  /// rather than to a table.
  final int categoryCount;
  final double categoryStartHue;

  /// Held constant across the whole family — this is the part that makes them
  /// a family rather than a collection.
  ///
  /// Two tones, because a ring stroke is a graphical object (3:1) and the
  /// number beside it is text (4.5:1). Requesting more chroma than sRGB holds
  /// is deliberate: [Palette] fits the family to its weakest hue, so the
  /// request is "as saturated as the five-colour chart scale can be
  /// together".
  final double arcLightness;
  final double arcChroma;
  final double glyphLightness;
  final double glyphChroma;

  /// Hue per status. Lightness and chroma come from the category family's
  /// glyph tone, so a status chip and a colour on the five-colour chart
  /// scale weigh the same on the page and both clear 4.5:1.
  final double successHue;
  final double warningHue;
  final double errorHue;

  /// How far round the wheel the brand gradient's far stop sits from the
  /// accent. 28 reads as a gradient; 0 keeps one hue, a touch lighter — the
  /// minimal identity's choice.
  final double gradientHueShift;

  const PaletteSeeds({
    required this.brightness,
    required this.canvasHue,
    required this.canvasChroma,
    required this.canvasLadder,
    required this.textLadder,
    required this.outlineLightness,
    required this.accentHue,
    required this.accentChroma,
    required this.accentLightness,
    required this.accentWellLightness,
    required this.accentWellChroma,
    this.categoryCount = 6,
    required this.categoryStartHue,
    required this.arcLightness,
    required this.arcChroma,
    required this.glyphLightness,
    required this.glyphChroma,
    this.successHue = 150,
    this.warningHue = 75,
    this.errorHue = 27,
    this.gradientHueShift = 28,
  });

  PaletteSeeds copyWith({
    double? canvasHue,
    double? canvasChroma,
    List<double>? canvasLadder,
    List<double>? textLadder,
    double? outlineLightness,
    double? accentHue,
    double? accentChroma,
    double? accentLightness,
    double? accentWellLightness,
    double? accentWellChroma,
    int? categoryCount,
    double? categoryStartHue,
    double? arcLightness,
    double? arcChroma,
    double? glyphLightness,
    double? glyphChroma,
    double? gradientHueShift,
  }) => PaletteSeeds(
    brightness: brightness,
    canvasHue: canvasHue ?? this.canvasHue,
    canvasChroma: canvasChroma ?? this.canvasChroma,
    canvasLadder: canvasLadder ?? this.canvasLadder,
    textLadder: textLadder ?? this.textLadder,
    outlineLightness: outlineLightness ?? this.outlineLightness,
    accentHue: accentHue ?? this.accentHue,
    accentChroma: accentChroma ?? this.accentChroma,
    accentLightness: accentLightness ?? this.accentLightness,
    accentWellLightness: accentWellLightness ?? this.accentWellLightness,
    accentWellChroma: accentWellChroma ?? this.accentWellChroma,
    categoryCount: categoryCount ?? this.categoryCount,
    categoryStartHue: categoryStartHue ?? this.categoryStartHue,
    arcLightness: arcLightness ?? this.arcLightness,
    arcChroma: arcChroma ?? this.arcChroma,
    glyphLightness: glyphLightness ?? this.glyphLightness,
    glyphChroma: glyphChroma ?? this.glyphChroma,
    successHue: successHue,
    warningHue: warningHue,
    errorHue: errorHue,
    gradientHueShift: gradientHueShift ?? this.gradientHueShift,
  );

  bool get _isDark => brightness == Brightness.dark;

  /// Grow the palette.
  Palette build() {
    // `textLadder.length` is not const-evaluable on a runtime `List`
    // parameter, so this cannot live on the const constructor as an
    // initializer assert — this is the nearest equivalent: checked the one
    // time the seeds are actually consumed.
    assert(
      textLadder.length == 2,
      'textLadder is [foreground, mutedForeground] — exactly 2 lightnesses.',
    );
    // The recess carries a touch more chroma than the page and the card. A
    // grey recess next to a tinted card reads as a hole cut in a different
    // material.
    final ladder = [
      for (var i = 0; i < canvasLadder.length; i++)
        Oklch(canvasLadder[i], canvasChroma + i * 0.002, canvasHue).toColor(),
    ];
    final text = [
      for (final l in textLadder) Oklch(l, 0.014, canvasHue).toColor(),
    ];

    final accent = Oklch(accentLightness, accentChroma, accentHue).toColor();
    // The on-colour is measured rather than assumed. White on a light accent
    // and black on a dark one are both common defaults and both wrong half
    // the time; whichever end of the canvas separates further from the accent
    // is the one a reader can read.
    final nearLight = Oklch(0.985, 0.004, canvasHue).toColor();
    final nearDark = Oklch(0.16, 0.012, canvasHue).toColor();

    /// The colour that reads on [on], measured rather than assumed.
    ///
    /// Picking the better end of the canvas is only half of it. A colour at
    /// mid lightness — which every semantic in light mode is, because it has
    /// to clear 4.5:1 as text in its own right — has *neither* end reaching
    /// 4.5:1 against it. So the better end is then walked toward the extreme
    /// until it clears, instead of shipping a 4.39:1 button label and calling
    /// it derived.
    Color onFor(Color color) {
      final towardLight =
          contrastRatio(color, nearLight) >= contrastRatio(color, nearDark);
      final start = towardLight ? nearLight : nearDark;
      if (contrastRatio(color, start) >= 4.5) return start;
      final from = towardLight ? 0.985 : 0.16;
      final to = towardLight ? 1.0 : 0.0;
      for (var i = 1; i <= 40; i++) {
        final l = from + (to - from) * (i / 40);
        final candidate = Oklch(
          l,
          towardLight ? 0.004 : 0.012,
          canvasHue,
        ).toColor();
        if (contrastRatio(color, candidate) >= 4.5) return candidate;
      }
      return Oklch(to, 0, canvasHue).toColor();
    }

    final onAccent = onFor(accent);

    final step = 360 / categoryCount;
    final hues = [
      for (var i = 0; i < categoryCount; i++)
        (categoryStartHue + i * step) % 360,
    ];
    // Fit the family to the weakest hue in it. Uniformity is the property the
    // family exists for, and it has to hold of the colours that ship rather
    // than of the ones that were asked for — every hue clipping to its own
    // ceiling is the crayon box arriving by a different route. Cyan at
    // lightness 0.652 tops out near 0.125 while magenta goes past 0.27.
    double fit(double requested, double lightness) {
      var ceiling = requested;
      for (final h in hues) {
        final room = Oklch.maxChroma(lightness, h);
        if (room < ceiling) ceiling = room;
      }
      return ceiling;
    }

    final arcC = fit(arcChroma, arcLightness);
    final glyphC = fit(glyphChroma, glyphLightness);
    // Chart scale: the first five category hues at arc tone. Data only.
    final chart = [
      for (var i = 0; i < 5; i++)
        Oklch(arcLightness, arcC, hues[i % hues.length]).toColor(),
    ];

    // A status takes the glyph tone: it is read as text as often as seen.
    Color status(double hue) => Oklch(glyphLightness, glyphC, hue).toColor();

    // The gradient's far stop: the primary's neighbour, [gradientHueShift]
    // round the wheel and a touch lighter, fitted to what sRGB holds there.
    final endL = (accentLightness + 0.06).clamp(0.0, 1.0);
    final endH = (accentHue + gradientHueShift) % 360;
    var gradientEnd = Oklch(
      endL,
      accentChroma.clamp(0.0, Oklch.maxChroma(endL, endH)),
      endH,
    ).toColor();
    // K11: primaryForeground must read on both stops. Walk the far stop back
    // toward the primary's lightness until it does.
    for (
      var i = 1;
      i <= 12 && contrastRatio(onAccent, gradientEnd) < 4.5;
      i++
    ) {
      final l = endL - (endL - accentLightness) * (i / 12);
      gradientEnd = Oklch(
        l,
        accentChroma.clamp(0.0, Oklch.maxChroma(l, endH)),
        endH,
      ).toColor();
    }

    return Palette(
      brightness: brightness,
      background: ladder[0],
      card: ladder[1],
      muted: ladder[2],
      foreground: text[0],
      mutedForeground: text[1],
      primary: accent,
      primaryForeground: onAccent,
      secondary: Oklch(
        accentWellLightness,
        accentWellChroma,
        accentHue,
      ).toColor(),
      secondaryForeground: Oklch(
        _isDark ? 0.92 : 0.28,
        accentChroma * 0.45,
        accentHue,
      ).toColor(),
      border: Oklch(
        outlineLightness,
        canvasChroma + 0.004,
        canvasHue,
      ).toColor(),
      ring: accent,
      destructive: status(errorHue),
      success: status(successHue),
      warning: status(warningHue),
      primaryGradient: LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: [accent, gradientEnd],
      ),
      chart: chart,
    );
  }
}

/// A palette for each brightness, plus the seeds they grew from.
///
/// The seeds are kept rather than discarded so a test can ask whether the
/// shipped colours still match the numbers they were asked for — a palette
/// somebody hand-patched one hex at a time is exactly the drift this layer
/// exists to prevent.
@immutable
class PaletteSpec {
  final Palette light;
  final Palette dark;
  final PaletteSeeds? lightSeeds;
  final PaletteSeeds? darkSeeds;

  const PaletteSpec({
    required this.light,
    required this.dark,
    this.lightSeeds,
    this.darkSeeds,
  });

  /// Grow both palettes from seeds. This is the constructor an identity uses.
  factory PaletteSpec.fromSeeds({
    required PaletteSeeds light,
    required PaletteSeeds dark,
  }) => PaletteSpec(
    light: light.build(),
    dark: dark.build(),
    lightSeeds: light,
    darkSeeds: dark,
  );

  Palette resolve(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}
