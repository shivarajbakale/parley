import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:parley_android/theme/app_platform.dart';
import 'package:parley_android/theme/spec/chrome_spec.dart';
import 'package:parley_android/theme/spec/component_spec.dart';
import 'package:parley_android/theme/spec/elevation_spec.dart';
import 'package:parley_android/theme/spec/motion_spec.dart';
import 'package:parley_android/theme/spec/palette_spec.dart';
import 'package:parley_android/theme/spec/shape_spec.dart';
import 'package:parley_android/theme/spec/space_spec.dart';
import 'package:parley_android/theme/spec/type_spec.dart';

export 'package:parley_android/theme/spec/chrome_spec.dart';
export 'package:parley_android/theme/spec/component_spec.dart';
export 'package:parley_android/theme/spec/elevation_spec.dart';
export 'package:parley_android/theme/spec/motion_spec.dart';
export 'package:parley_android/theme/spec/oklch.dart';
export 'package:parley_android/theme/spec/palette_spec.dart';
export 'package:parley_android/theme/spec/shape_spec.dart';
export 'package:parley_android/theme/spec/space_spec.dart';
export 'package:parley_android/theme/spec/type_spec.dart';

/// The entire design, as one value.
///
/// Everything a widget could ask about how the app looks lives here: colour,
/// type, shape, spacing, elevation, motion, chrome material and the component
/// idioms that are none of those. A widget reads `context.design`; it never
/// holds a number of its own.
///
/// The point is the swap. Changing which [DesignSpec] the app is wrapped in
/// changes the app, and nothing downstream is edited:
///
/// ```dart
/// Design(
///   spec: DesignSpec.halo(),     // ← the only line that decides the look
///   child: child,
/// )
/// ```
///
/// Before this existed the design was 239 static constants across thirteen
/// namespaces, read directly by seventy files. A `static const` cannot be
/// swapped, themed, or varied — so "change the theme" meant editing nine files
/// and hoping every literal had been found. There was no one place because
/// there were 239.
@immutable
class DesignSpec {
  /// A name, for evidence and for the golden that renders one spec per file.
  final String name;

  final PaletteSpec palette;
  final TypeSpec type;
  final SpaceSpec space;
  final ShapeSpec shape;
  final ElevationSpec elevation;
  final MotionSpec motion;
  final ChromeSpec chrome;
  final ComponentSpec component;

  const DesignSpec({
    required this.name,
    required this.palette,
    this.type = const TypeSpec(),
    this.space = const SpaceSpec(),
    this.shape = const ShapeSpec(),
    this.elevation = const ElevationSpec(),
    this.motion = const MotionSpec(),
    this.chrome = const ChromeSpec(),
    this.component = const ComponentSpec(),
  });

  DesignSpec copyWith({
    String? name,
    PaletteSpec? palette,
    TypeSpec? type,
    SpaceSpec? space,
    ShapeSpec? shape,
    ElevationSpec? elevation,
    MotionSpec? motion,
    ChromeSpec? chrome,
    ComponentSpec? component,
  }) => DesignSpec(
    name: name ?? this.name,
    palette: palette ?? this.palette,
    type: type ?? this.type,
    space: space ?? this.space,
    shape: shape ?? this.shape,
    elevation: elevation ?? this.elevation,
    motion: motion ?? this.motion,
    chrome: chrome ?? this.chrome,
    component: component ?? this.component,
  );

  /// **Halo** — the identity this app ships.
  ///
  /// Three numbers are typed by a person and everything else is arithmetic.
  /// The accent is `oklch(.542 .209 172)`, which is `#008368` to the byte;
  /// the ground is that same hue at a chroma low enough to read as grey and
  /// high enough to read as a material. The surface ladder, the text ladder,
  /// the outlines, six category hues at two tones each and four semantic
  /// swatches are all grown from those.
  ///
  /// A brand colour is a brand decision and belongs to a person. A ladder is
  /// arithmetic, and arithmetic that a person types drifts — which is what
  /// the identity this replaces demonstrated, with five surface steps whose
  /// adjacent contrast ran 1.06 to 1.19.
  ///
  /// The hue was 286.3 — a violet-indigo — until an audit pointed out that
  /// the violet-to-blue band is the single most recognisable signature of an
  /// interface nobody chose the colours for, and that this file's own comment
  /// said a brand colour belongs to a person while shipping the default. 172
  /// is a deep teal: far from the semantic red and amber it has to sit beside,
  /// and far from the hue every other scaffolded app opens in.
  ///
  /// Now **Porcelain** (user decision, 2026-09-14): cool near-white grounds and
  /// one quiet blue at hue 265, used for actions, with Archivo type. The
  /// teal history above is why the hue is a person's choice, not a default.
  ///
  /// Every pair this produces is asserted by `test/theme/palette_lint_test`,
  /// K1 through K7. Change a seed and the gate tells you what it cost.
  factory DesignSpec.halo() => DesignSpec(
    name: 'halo',
    // 24, not the 16 the spec defaults to. Sixteen is Material's minimum for
    // a phone and it reads as a margin the layout ran out of room for: the
    // first character of every headline sat four points from the bezel while
    // the large title above it — which reads `space.lg` — sat at 24, so the
    // page had two left edges eight points apart. One number, on the wider of
    // the two, and the title, the section headers, the rows and the body all
    // start on the same line.
    // Porcelain: Archivo for text, Archivo Black for display and headline.
    // Archivo Black ships one face, bundled at w900, so both loud families
    // ask for 900 rather than letting the engine pick a neighbour.
    type: const TypeSpec(
      family: 'Archivo',
      displayFamily: 'Archivo Black',
      displayWeight: FontWeight.w900,
      headlineWeight: FontWeight.w900,
      // Archivo Black is wide. At Satoshi's anchor and tracking a two-line
      // page title at 1.3x lost its last word; a smaller anchor and tighter
      // large-type tracking give it the room back.
      displayBase: 16.5,
      trackingTightening: 0.9,
    ),
    space: const SpaceSpec(gutter: 20),
    // Above the default 1, because the light ladder is flat. A card and the
    // page are the same white and the nav bar is that white again, so the
    // shadow is not a second signal reinforcing a tonal edge any more — it is
    // the only one there is, and at the stock alphas a floating bar on a white
    // page read as a bar drawn on it. Dark is unaffected in practice: the
    // shadows there fall on a ground that already separates by tone.
    elevation: const ElevationSpec(intensity: 1.3),
    palette: PaletteSpec.fromSeeds(
      // Light: a grey page, a white card, and a ramp underneath them with
      // room in it. The lift is carried by tone *and* by shadow rather than
      // by shadow alone.
      light: const PaletteSeeds(
        brightness: Brightness.light,
        canvasHue: 265.0,
        // Near-neutral. The page is the largest flat area in the app, so it
        // is the one place a tint reads as a colour rather than as a
        // material: a teal-grey ground at .009 looked green rather than
        // looking like paper. The hue stays, so the greys still belong to the
        // accent's family; only the amount drops.
        canvasChroma: 0.004,
        // Page, card, recess.
        //
        // The release before this spent the tone step down to zero — page and
        // card both at 1.000, the whole lift on `AppShadows`' contact/ambient
        // pair. It read as one plane: a shadow says "raised" only where the
        // eye is already looking for an edge, and on a list of cards it is
        // four hairlines of grey doing the work a ground should do.
        //
        // So the page steps back to .949 and the card keeps the white. The
        // shadow now reinforces a boundary instead of being the whole of it.
        //
        // The recess follows the page down, from .910 to .856, rather than
        // staying where it was: it has to read as *into* the page and not
        // only into the card, and at .910 under a .949 page it would be a
        // rung that only existed while the page was white.
        //
        // These three values are not a preference, they are the only window
        // left once four things are true at once. K8 asks 3:1 of the accent
        // against the recess it can sit on, which puts a floor under the
        // recess at L .849 — the accent is `#008368` and it does not move.
        // K6 asks 1.15:1 of the card against the page, which puts a ceiling
        // over the page at L .951. K10 asks .045 of OKLCH lightness between
        // each neighbouring ground, and there are four of them: card, page,
        // `inert`, recess. Three gaps into a .151 window leaves .016 of
        // slack, and this ladder spends it evenly. Moving any rung more than
        // a hundredth turns one of those four red — `make palette-lint` will
        // say which.
        // Porcelain without the wash: a light cool-grey page under white
        // cards. .949 is K6's ceiling for card-over-page separation.
        canvasLadder: [0.949, 1.000, 0.875],
        // Unchanged in shape; the third step trims from .606 to .598, which
        // is what `ds_chip_test`'s 2.5:1 floor for a disabled label needs now
        // that the recess it sits on has moved down with the page.
        //
        // The pair that was actually broken here was tertiary against
        // `outline` — .606 and .590, which K10 reads as 0.016 of lightness
        // and a reader reads as one grey. It is fixed on the hairline's side
        // rather than this one: a text ladder is a hierarchy people read, and
        // a hairline is not.
        textLadder: [0.215, 0.458],
        // Down from .590, which sat 0.016 of OKLCH lightness from
        // `textTertiary` — a hairline and a tertiary label that a reader
        // cannot rank, and the second of the two collisions K10 was written
        // for. Darkening the hairline rather than the label is the cheaper
        // side of that pair to move, and it only loosens the constraint it
        // was originally tuned against: `ds_text_field_test`'s C-5 floor of
        // 2.7:1 for a rest outline on the field it draws around.
        outlineLightness: 0.900,
        // Up from .842, and it moves two things at once: the soft hairline
        // itself, and `inert` — the track-and-skeleton rung — which is grown
        // from it. This is the seed that positions `inert` in the ground
        // ladder, so it is tuned to land it midway between the page and the
        // recess rather than for its own sake.
        accentHue: 265.0,
        accentChroma: 0.165,
        // Down from .553 with the page: on the light grey ground the accent
        // as link text measured 4.25:1, under the 4.5 floor.
        accentLightness: 0.520,
        accentWellLightness: 0.955,
        accentWellChroma: 0.018,
        categoryStartHue: 265.0,
        arcLightness: 0.600,
        arcChroma: 0.20,
        // .503 put the first category's glyph at 4.47:1 on its own well —
        // three hundredths under the floor, on the pair that actually ships
        // (initials in a `DSAvatar`, a label on a category chip). K5 only ever
        // checked the glyph against the *surface*, so nothing said so until
        // the probe read the drawn pair. K5b checks it now.
        glyphLightness: 0.494,
        glyphChroma: 0.20,
        // One hue, no drift into violet: Porcelain is flat.
        gradientHueShift: 0,
      ),
      // Dark: the accent is re-fitted rather than reused. `#008368` on the
      // dark card is unreadable at this lightness. Same hue, same requested
      // chroma, lifted to L .700 and gamut-mapped from there.
      dark: const PaletteSeeds(
        brightness: Brightness.dark,
        canvasHue: 265.0,
        canvasChroma: 0.006,
        canvasLadder: [0.190, 0.277, 0.140],
        textLadder: [0.965, 0.760],
        outlineLightness: 0.367,
        accentHue: 265.0,
        accentChroma: 0.120,
        accentLightness: 0.720,
        accentWellLightness: 0.330,
        accentWellChroma: 0.050,
        categoryStartHue: 265.0,
        // Lifted from .562 when the identity moved to hue 172. The dark
        // category arcs are the tightest thing in the palette — the worst of
        // the six landed at 2.99:1 against the dark card, missing the 3.0
        // floor for a non-text graphical object by a hundredth. Raising the
        // whole rung rather than nudging one hue is the point of a ladder: six
        // arcs at one lightness read as one family, and five at one lightness
        // plus one exception read as a mistake.
        arcLightness: 0.572,
        arcChroma: 0.20,
        glyphLightness: 0.666,
        glyphChroma: 0.20,
        // One hue, no drift into violet: Porcelain is flat.
        gradientHueShift: 0,
      ),
    ),
  );

  /// **Ledger** — ink on paper, and the shortest proof that this is data.
  ///
  /// Nothing below is a widget. Every visible difference between this app and
  /// the one [DesignSpec.halo] draws — square corners instead of squircles, a
  /// page that is warm paper instead of white, chrome that is the same plane
  /// as the content, no shadow anywhere, a tighter grid and a brisker clock —
  /// is a number in this constructor. That is the claim the spec layer was
  /// built to make, and until a second identity existed it was only a claim.
  ///
  /// The direction is a printed page: the ground carries warmth rather than
  /// the accent's own hue, the corner radius is small enough to read as a
  /// registration mark rather than as a pill, and [ElevationSpec.intensity]
  /// is zero — a card here is found by its edge and its tone, never by a
  /// shadow. That is what makes it a real test of the kit rather than a
  /// recolour: `DSCard`, `DSSheet` and the chrome layer all have to hold up
  /// with the lift taken away.
  factory DesignSpec.ledger() => DesignSpec(
    name: 'ledger',
    palette: PaletteSpec.fromSeeds(
      // Light: warm paper, and a card that steps *up* off it. The opposite
      // direction from halo, whose page is white and whose card steps down —
      // which is the second thing this identity exists to exercise.
      light: const PaletteSeeds(
        brightness: Brightness.light,
        canvasHue: 85.0,
        canvasChroma: 0.004,
        canvasLadder: [0.972, 0.905, 0.845],
        textLadder: [0.200, 0.450],
        outlineLightness: 0.805,
        accentHue: 330.0,
        accentChroma: 0.220,
        accentLightness: 0.495,
        accentWellLightness: 0.925,
        accentWellChroma: 0.035,
        categoryStartHue: 330.0,
        arcLightness: 0.585,
        arcChroma: 0.20,
        glyphLightness: 0.480,
        glyphChroma: 0.20,
      ),
      // Dark: the same paper read under a lamp. The ladder inverts, and the
      // accent is re-fitted rather than reused, exactly as halo's is.
      dark: const PaletteSeeds(
        brightness: Brightness.dark,
        canvasHue: 85.0,
        canvasChroma: 0.010,
        canvasLadder: [0.205, 0.285, 0.155],
        textLadder: [0.965, 0.760],
        outlineLightness: 0.375,
        accentHue: 330.0,
        accentChroma: 0.200,
        accentLightness: 0.740,
        accentWellLightness: 0.325,
        accentWellChroma: 0.080,
        categoryStartHue: 330.0,
        arcLightness: 0.600,
        arcChroma: 0.20,
        glyphLightness: 0.690,
        glyphChroma: 0.20,
      ),
    ),
    // A wider interval on a smaller base: fewer, larger steps is what a
    // printed hierarchy does, and it is the opposite trade from halo's
    // narrow 1.10 on a 12.8pt base. Ledger keeps Black for both display and
    // headline — it names no headlineWeight, so both families follow
    // displayWeight, which is the arrangement every identity had before the
    // default one split them.
    type: const TypeSpec(
      baseSize: 13.2,
      displayBase: 16.5,
      ratio: 1.20,
      displayWeight: FontWeight.w900,
      titleWeight: FontWeight.w700,
      labelWeight: FontWeight.w700,
      tracking: -0.1,
      labelTracking: 0.35,
      bodyHeight: 1.52,
      displayHeight: 1.05,
      eyebrowTracking: 1.8,
    ),
    space: const SpaceSpec(density: 0.92, gutter: 20),
    // Near-square, and the same on both platforms. `CornerStyle.rounded`
    // rather than `platform` is an identity refusing to adapt, which is a
    // decision the spec has to be able to express.
    shape: const ShapeSpec(style: CornerStyle.rounded, scale: 0.32),
    elevation: const ElevationSpec(intensity: 0),
    motion: const MotionSpec(speed: 0.85, springiness: 1.25),
    chrome: const ChromeSpec(
      apple: ChromeMaterial.flat,
      material: ChromeMaterial.flat,
    ),
  );

  /// **Signal** — the same app with the volume up.
  ///
  /// Where [DesignSpec.ledger] takes everything away, this adds it back at a
  /// different setting: large radii on both platforms, a spacing scale whose
  /// upper steps grow faster than its lower ones, glass chrome even on
  /// Android, a heavier shadow ramp and a looser spring. The type scale runs
  /// the other way from ledger's — a large base and a narrow interval, so
  /// running text is comfortable and the headings stay close to it.
  ///
  /// It exists to move the axes ledger leaves alone. Two identities that
  /// differ only in hue would prove the palette is derived and nothing else;
  /// between them these two move colour, type, spacing, corner geometry,
  /// elevation, motion and chrome material, which is every field
  /// [DesignSpec] has.
  factory DesignSpec.signal() => DesignSpec(
    name: 'signal',
    palette: PaletteSpec.fromSeeds(
      light: const PaletteSeeds(
        brightness: Brightness.light,
        canvasHue: 210.0,
        canvasChroma: 0.010,
        canvasLadder: [0.990, 0.930, 0.872],
        textLadder: [0.230, 0.470],
        outlineLightness: 0.830,
        // A green accent, not the cyan this was drafted at. 210 sat 38° from
        // halo's 172, and two identities whose brand colours are both a
        // blue-green demonstrate a hue slider rather than a second identity.
        // The light accent has to be dark — K8 asks 3:1 of it against the
        // recess it can sit on, and green is luminous — so it lands as a deep
        // emerald rather than the bright one the name suggests.
        accentHue: 135.0,
        successHue: 170.0,
        accentChroma: 0.170,
        accentLightness: 0.505,
        accentWellLightness: 0.930,
        accentWellChroma: 0.032,
        categoryStartHue: 135.0,
        arcLightness: 0.590,
        arcChroma: 0.19,
        glyphLightness: 0.500,
        glyphChroma: 0.19,
      ),
      dark: const PaletteSeeds(
        brightness: Brightness.dark,
        canvasHue: 210.0,
        canvasChroma: 0.020,
        canvasLadder: [0.155, 0.265, 0.105],
        textLadder: [0.970, 0.775],
        outlineLightness: 0.355,
        accentHue: 135.0,
        successHue: 170.0,
        accentChroma: 0.170,
        accentLightness: 0.740,
        accentWellLightness: 0.310,
        accentWellChroma: 0.075,
        categoryStartHue: 135.0,
        arcLightness: 0.610,
        arcChroma: 0.19,
        glyphLightness: 0.700,
        glyphChroma: 0.19,
      ),
    ),
    type: const TypeSpec(
      baseSize: 14.96,
      displayBase: 18.7,
      ratio: 1.12,
      displayWeight: FontWeight.w500,
      titleWeight: FontWeight.w700,
      labelWeight: FontWeight.w700,
      emphasisWeight: FontWeight.w900,
      tracking: 0.1,
      trackingTightening: 0.9,
      labelTracking: 0.05,
      bodyHeight: 1.40,
      displayHeight: 1.00,
      eyebrowUppercase: false,
      eyebrowTracking: 0.2,
    ),
    // The upper steps grow faster than the lower ones, so small gaps stay
    // tight while the space between sections opens up.
    space: const SpaceSpec(
      steps: [0.5, 1, 2, 3, 5, 7, 10, 14],
      density: 1.08,
      gutter: 22,
    ),
    shape: const ShapeSpec(
      style: CornerStyle.rounded,
      radii: {
        AppShape.card: (28, 28),
        AppShape.control: (22, 22),
        AppShape.tile: (24, 24),
        AppShape.dialog: (32, 32),
        AppShape.sheet: (36, 36),
        AppShape.pill: (999, 999),
        AppShape.bar: (0, 0),
      },
    ),
    elevation: const ElevationSpec(
      levels: [0, 2, 4, 8, 16],
      ambientBlur: 8,
      ambientOffset: 2.4,
      intensity: 1.4,
    ),
    motion: const MotionSpec(speed: 1.15, springiness: 0.8),
    chrome: const ChromeSpec(
      apple: ChromeMaterial.glass,
      material: ChromeMaterial.glass,
      barBlur: 24,
      saturation: 1.9,
    ),
  );

  /// Every identity this app ships.
  ///
  /// The list the switchability gates iterate. A new identity joins here and
  /// is immediately held to the same palette gates halo is held to, and to
  /// the golden that fails when two identities render the same pixels —
  /// which is the only check that can tell a live derivation from a dead one.
  ///
  /// Built once. A `DesignSpec` grows two palettes in OKLCH at construction,
  /// and a getter here would re-grow them on every read.
  static final List<DesignSpec> shipped = <DesignSpec>[
    DesignSpec.halo(),
    DesignSpec.ledger(),
    DesignSpec.signal(),
  ];

  /// The spec used when nothing has been wrapped.
  ///
  /// Deliberately neutral and seed-grown rather than a copy of any shipped
  /// identity: if a widget ever renders against this in the running app, it
  /// should look wrong enough to notice rather than nearly right.
  static final DesignSpec fallback = DesignSpec(
    name: 'fallback',
    palette: PaletteSpec.fromSeeds(
      light: const PaletteSeeds(
        brightness: Brightness.light,
        canvasHue: 55,
        canvasChroma: 0.006,
        canvasLadder: [0.985, 0.962, 0.895],
        textLadder: [0.22, 0.44],
        outlineLightness: 0.862,
        accentHue: 55,
        accentChroma: 0.09,
        accentLightness: 0.55,
        accentWellLightness: 0.90,
        accentWellChroma: 0.032,
        categoryStartHue: 25,
        arcLightness: 0.63,
        arcChroma: 0.10,
        glyphLightness: 0.53,
        glyphChroma: 0.10,
      ),
      dark: const PaletteSeeds(
        brightness: Brightness.dark,
        canvasHue: 55,
        canvasChroma: 0.006,
        canvasLadder: [0.13, 0.175, 0.10],
        textLadder: [0.97, 0.755],
        outlineLightness: 0.265,
        accentHue: 55,
        accentChroma: 0.09,
        accentLightness: 0.80,
        accentWellLightness: 0.30,
        accentWellChroma: 0.032,
        categoryStartHue: 25,
        arcLightness: 0.66,
        arcChroma: 0.10,
        glyphLightness: 0.755,
        glyphChroma: 0.10,
      ),
    ),
  );

  /// The [ThemeData] this spec implies, for one brightness.
  ///
  /// The Material widgets underneath the design system read from `ThemeData`,
  /// so the spec has to own it rather than sit beside it: a `Switch` that
  /// ignores the scheme is a switch drawn in the previous theme's colours.
  ///
  /// Every geometry here takes the platform-neutral column of [ShapeSpec] and
  /// a plain rounded rectangle. `ThemeData` is built once per brightness with
  /// no context, so it cannot adapt; the design-system widgets apply the
  /// platform shape themselves, over the top of this.
  ThemeData themeFor(Brightness brightness) {
    final p = palette.resolve(brightness);
    final scheme = p.toColorScheme();

    // Primary text takes the full-contrast colour; supporting text drops to
    // the variant so the eye ranks content above chrome.
    final base = type.build().apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final textTheme = base.copyWith(
      bodySmall: base.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      labelMedium: base.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
      labelSmall: base.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
    );

    double radius(AppShape role) => shape.radiusOf(role, isApple: true);
    RoundedRectangleBorder box(AppShape role) => RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius(role)),
    );
    // A text field is a card-sized container rather than a control-sized one,
    // which is why its corner matches the card's and not the chip's.
    final fieldRadius = BorderRadius.circular(radius(AppShape.card));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: type.family,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: elevation.none,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        margin: space.cardMargin,
        shape: box(AppShape.card),
        color: scheme.surfaceContainerLow,
      ),

      // Square by default: list rows run edge to edge, and a rounded ink
      // splash inside a full-bleed row reads as a stray floating card.
      // Grouped surfaces clip their own corners.
      listTileTheme: ListTileThemeData(
        contentPadding: space.listItemPadding,
        shape: const RoundedRectangleBorder(),
        iconColor: scheme.onSurfaceVariant,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: elevation.medium,
        highlightElevation: elevation.high,
        shape: const StadiumBorder(),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radius(AppShape.sheet)),
          ),
        ),
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),

      dialogTheme: DialogThemeData(
        shape: box(AppShape.dialog),
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          color: scheme.onSurface,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        // Attached, like [DSSnackBar]: a floating bar has to inset itself from
        // whatever is already at the bottom edge, and the gap it leaves under
        // itself belongs to nobody. Fixed, the Scaffold does the arithmetic and
        // the bar lands directly on the bottom bar or the safe area.
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radius(AppShape.card)),
          ),
        ),
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),

      chipTheme: ChipThemeData(
        shape: box(AppShape.control),
        padding: EdgeInsets.symmetric(horizontal: space.sm, vertical: space.xs),
      ),

      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelMedium?.copyWith(
              color: scheme.primary,
              fontWeight: type.emphasisWeight,
            );
          }
          return textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: scheme.primary,
              size: component.iconSize,
            );
          }
          return IconThemeData(
            color: scheme.onSurfaceVariant,
            size: component.iconSize,
          );
        }),
      ),

      navigationDrawerTheme: NavigationDrawerThemeData(
        elevation: 1,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelLarge?.copyWith(
              color: scheme.primary,
              fontWeight: type.emphasisWeight,
            );
          }
          return textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: scheme.primary,
              size: component.iconSize,
            );
          }
          return IconThemeData(
            color: scheme.onSurfaceVariant,
            size: component.iconSize,
          );
        }),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // A field is a recess, in both themes. Filling it with a card
        // colour is what makes an input read as a raised block.
        fillColor: p.muted,
        border: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(
            color: scheme.outlineVariant,
            width: component.hairlineWidth,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(
            color: scheme.primary,
            width: component.hairlineWidth * 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(
            color: scheme.error,
            width: component.hairlineWidth,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(
            color: scheme.error,
            width: component.hairlineWidth * 1.5,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: space.lg,
          vertical: space.md,
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: component.hairlineWidth,
        space: 0,
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(shape: WidgetStateProperty.all(box(AppShape.card))),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
      ),

      // The most visible platform branch in the app, and the one a user
      // notices without being able to name: on Apple the page slides in from
      // the right and the edge-swipe back gesture comes with the builder, so
      // swiping back works because this line is here. On Android it is
      // Material 3 Expressive's fade-forwards.
      //
      // Every non-Apple target takes the Material side. Leaving one out does
      // not fall back to the theme — it falls back to Flutter's default
      // builder for that platform, which is a different transition nobody
      // chose.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

class Design extends InheritedWidget {
  final DesignSpec spec;

  const Design({super.key, required this.spec, required super.child});

  /// The spec in scope.
  ///
  /// Falls back to [DesignSpec.fallback] rather than throwing when no [Design]
  /// is above: a design-system widget has to render inside a bare
  /// `testWidgets` harness that never opted in, and an exception there fails
  /// a test for a reason that is not the reason it is checking. A widget that
  /// silently reads the fallback in the *app* is caught instead by the
  /// completeness gate, which is the right place for it.
  static DesignSpec of(BuildContext context) =>
      maybeOf(context) ?? DesignSpec.fallback;

  static DesignSpec? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Design>()?.spec;

  @override
  bool updateShouldNotify(Design oldWidget) => oldWidget.spec != spec;
}

/// Reading the design from a widget.
extension DesignContext on BuildContext {
  /// Every design decision in scope.
  DesignSpec get design => Design.of(this);

  /// The palette for the ambient brightness. The overwhelmingly common read,
  /// so it gets its own name rather than
  /// `design.palette.resolve(Theme.of(context).brightness)` at every call.
  Palette get palette =>
      Design.of(this).palette.resolve(Theme.of(this).brightness);

  /// Which side of the platform divide this build is drawing for.
  ///
  /// [ShapeSpec] takes `isApple` rather than a `BuildContext` because it is
  /// data and has none; every widget that asks it for a shape would otherwise
  /// repeat the same lookup. Reads [ThemeData.platform], so a
  /// `TargetPlatform` override in a test or a golden moves it — which is the
  /// seam both use to render the two sides on one machine.
  bool get isApplePlatform => AppPlatform.isApple(this);

  /// Whether this build should drive state changes with springs.
  ///
  /// False on Apple, where the platform's own animations are curve-based and
  /// a bouncing tab bar looks like a bug rather than a flourish. False when
  /// the user has asked for reduced motion, where a spring's overshoot is
  /// exactly the movement they switched off.
  ///
  /// A caller that gets `false` falls back to the spec's curves; it does not
  /// fall back to no animation.
  bool get springsAvailable =>
      !AppPlatform.isApple(this) && !MediaQuery.disableAnimationsOf(this);

  /// The border for [role] on this platform, from the spec.
  ///
  /// The spec-reading counterpart of `AppShapes.border`: the static table
  /// there predates [ShapeSpec] and cannot be swapped with the identity, and
  /// it is missing [AppShape.tile] outright.
  OutlinedBorder shapeOf(AppShape role) =>
      Design.of(this).shape.border(role, isApple: isApplePlatform);

  /// The radius [role] is drawn at on this platform, for a caller that needs
  /// the number rather than the border.
  double radiusOf(AppShape role) =>
      Design.of(this).shape.radiusOf(role, isApple: isApplePlatform);
}
