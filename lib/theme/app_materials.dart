import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:parley_android/theme/app_platform.dart';

/// A material: what a chrome surface is made of.
///
/// Every field is a number or a colour, so a widget test can assert what the
/// layer decided without rendering anything. That is the whole reason this is
/// a value rather than a widget with the decisions inlined in `build`.
@immutable
class AppMaterial {
  const AppMaterial({
    required this.tint,
    required this.shadow,
    this.blurSigma = 0,
    this.saturation = 1,
    this.specular,
  });

  /// The fill painted over the blur — or the entire fill, when opaque.
  final Color tint;

  /// The lift under the surface.
  final List<BoxShadow> shadow;

  /// Blur radius applied to what is behind the surface. Zero means opaque,
  /// and an opaque material draws no `BackdropFilter` at all.
  final double blurSigma;

  /// Saturation multiplier applied to what is behind the surface. Glass that
  /// only blurs looks like frosted plastic; the colour bleeding through is
  /// most of what reads as glass.
  final double saturation;

  /// The hairline highlight along the top edge, or null for no highlight.
  ///
  /// This is the specular line where a real pane of glass catches the light,
  /// and its absence is why a plain `BackdropFilter` looks like a smudge
  /// rather than a surface.
  final Color? specular;

  /// Whether this material blurs what is behind it.
  bool get isGlass => blurSigma > 0;
}

/// The materials the chrome layer is built from.
///
/// See `docs/principles/depth-and-materials.md`. The rule this class exists to
/// serve, and it is Apple's own: **glass belongs to the navigation and control
/// layer that floats above content; content stays opaque.** Glass on every
/// card is the 2026 version of a gradient on every card — it destroys the
/// depth cue by spending it everywhere.
///
/// That rule is enforced, not just written down: `tool/ui_lint.dart`'s
/// `glass-off-chrome` rule fails a screen or a content widget that reaches for
/// anything in this file.
///
/// **Why this is built here rather than taken from a package.** Flutter has no
/// official Liquid Glass API — the Cupertino rebuild is roadmapped for late
/// 2026 and closed to contributions. The community shader packages work, but
/// they are a dependency and a shader-compatibility risk in a project whose
/// entire job is to be a clean starting point. A [ui.ImageFilter.blur]
/// composed with a saturation [ColorFilter], plus a hairline gradient along
/// the top edge, gets most of the way using only the SDK.
///
/// **The cost is real, which is the second reason content stays opaque.** A
/// `BackdropFilter` reads back the layer beneath it every frame. That is fine
/// for one nav bar and one sheet. It is not fine for fifty list rows.
abstract final class AppMaterials {
  // Every number this layer used to hold — the blur, the saturation, the two
  // tint alphas and the two specular alphas — is a field of [ChromeSpec] now.
  // They were `static const` here, which meant the one part of the app whose
  // whole job is to look expensive was the one part an identity could not
  // touch.

  /// The material for a surface that floats above content: nav bar, tab bar,
  /// app bar, FAB, pinned action bar.
  ///
  /// [elevation] is the lift under it — a bar sits high, a search field that
  /// scrolls with the content sits low. It is the only thing a caller
  /// normally needs to vary.
  static AppMaterial chrome(
    BuildContext context, {
    DSElevation elevation = DSElevation.high,
  }) => _resolve(
    context,
    blur: context.design.chrome.barBlur,
    elevation: elevation,
    shadow: null,
  );

  /// Chrome carrying a colour of its own — a FAB, a pinned primary action.
  ///
  /// On Apple the seed becomes the glass tint, so the control keeps its
  /// identity while what is behind it still moves through. Everywhere else it
  /// is simply the opaque colour, which is what a Material FAB already is.
  static AppMaterial accent(
    BuildContext context,
    Color seed, {
    DSElevation elevation = DSElevation.high,
  }) {
    final base = chrome(context, elevation: elevation);
    if (!base.isGlass) return AppMaterial(tint: seed, shadow: base.shadow);
    return AppMaterial(
      tint: seed.withValues(alpha: 0.76),
      blurSigma: base.blurSigma,
      saturation: base.saturation,
      specular: base.specular,
      shadow: base.shadow,
    );
  }

  /// The material for a control the user types into.
  ///
  /// Same glass, a different colour underneath it: an input is *recessed*,
  /// and [Palette.well] is the role that says so. Chrome's own tint is the
  /// raised end of the theme — white, in light — which on a white page draws
  /// a field with no boundary at all. A search pill that can only be found by
  /// its shadow is a search pill nobody finds.
  static AppMaterial field(BuildContext context) => _resolve(
    context,
    blur: context.design.chrome.barBlur,
    elevation: DSElevation.low,
    shadow: null,
    tint: context.palette.muted,
  );

  /// The material for a surface that rises from the bottom edge.
  ///
  /// Opaque, unlike the rest of the chrome layer, and deliberately so. Glass
  /// composites [Palette.chrome] at 0.72 over whatever is behind it, and a
  /// sheet is always opened over a scrimmed page — so the raised end of the
  /// ladder arrived on screen as a grey, and every sheet took a slightly
  /// different grey depending on the page it covered. A sheet is a surface
  /// you hand a task to, not a window onto the one underneath.
  ///
  /// The lift stays: a sheet is lit from the same place as everything else,
  /// so its shadow falls *upward* onto the content it covers.
  static AppMaterial sheet(BuildContext context) => AppMaterial(
    tint: context.palette.chrome,
    shadow: context.design.elevation.sheet(
      brightness: Theme.of(context).brightness,
      shadowColor: context.palette.overlay,
    ),
  );

  /// Whether this build may use translucency at all.
  ///
  /// Two OS settings switch it off, and both were asked for deliberately:
  ///
  /// - **High contrast.** Translucency lowers contrast by definition. A user
  ///   who turned this on is telling us they need the text edge.
  /// - **Reduced motion.** Glass is a moving effect — the content sliding
  ///   underneath is the point of it. Frozen glass is just a dim rectangle.
  ///
  /// Android takes the opaque path regardless: Material 3's chrome is a tonal
  /// surface, and glass there is an iOS costume rather than a native detail.
  static bool translucencyAllowed(BuildContext context) =>
      context.design.chrome.materialFor(
            isApple: AppPlatform.isApple(context),
          ) ==
          ChromeMaterial.glass &&
      !MediaQuery.highContrastOf(context) &&
      !MediaQuery.disableAnimationsOf(context);

  /// A saturation filter, as a [ColorFilter] that can be composed into an
  /// [ui.ImageFilter].
  static ColorFilter saturationFilter(double amount) =>
      ColorFilter.matrix(saturationMatrix(amount));

  /// The 4×5 colour matrix for a saturation of [amount]: 0 is greyscale, 1 is
  /// unchanged, above 1 boosts.
  ///
  /// The weights are the standard luminance coefficients — green carries most
  /// of perceived brightness, blue almost none — so desaturating leaves a grey
  /// of the same apparent lightness rather than a darker one.
  static List<double> saturationMatrix(double amount) {
    const lumR = 0.2126;
    const lumG = 0.7152;
    const lumB = 0.0722;
    final invert = 1 - amount;
    final r = invert * lumR;
    final g = invert * lumG;
    final b = invert * lumB;
    return <double>[
      r + amount, g, b, 0, 0, //
      r, g + amount, b, 0, 0, //
      r, g, b + amount, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }

  /// The composed filter a [BackdropFilter] applies for [material].
  ///
  /// Blur first, then saturate: saturating a blurred sample keeps the colour
  /// that survived the blur, while blurring a saturated one just averages the
  /// boost back out.
  static ui.ImageFilter filterFor(AppMaterial material) {
    final blur = ui.ImageFilter.blur(
      sigmaX: material.blurSigma,
      sigmaY: material.blurSigma,
    );
    if (material.saturation == 1) return blur;
    return ui.ImageFilter.compose(
      outer: saturationFilter(material.saturation),
      inner: blur,
    );
  }

  static AppMaterial _resolve(
    BuildContext context, {
    required double blur,
    required DSElevation elevation,
    required List<BoxShadow>? shadow,
    Color? tint,
  }) {
    final theme = Theme.of(context);
    final spec = context.design.elevation;
    final lift =
        shadow ??
        spec.resolve(
          elevation: spec.levelOf(elevation),
          brightness: theme.brightness,
          shadowColor: context.palette.overlay,
        );

    // **The tint is pinned.** Both branches take the same colour and differ
    // only in the *material*: glass composites it over a blurred backdrop,
    // opaque paints it whole. The two used to read different scheme roles —
    // `surfaceContainerHigh` here and `surface` below, which the palette maps
    // to two different colours — so the same bar was a different colour on
    // each platform and nobody had chosen the second one (plan 15, C-6). A
    // bar whose hue depends on the OS is a bar with no identity.
    //
    // [Palette.chrome], not a `ColorScheme` role: the scheme's container
    // ladder is written for a theme whose light surfaces step *up*, and this
    // palette's do not. Chrome asks for "the raised end", which is white in
    // light and the card colour in dark, and that is the one question the
    // scheme cannot answer.
    final fill = tint ?? context.palette.chrome;

    if (!translucencyAllowed(context)) {
      // Level 3 of the surface ladder, opaque. Android's own chrome is a tonal
      // container, so this is the native answer there rather than a fallback.
      return AppMaterial(tint: fill, shadow: lift);
    }

    final chrome = context.design.chrome;
    return AppMaterial(
      // Enough fill that text on the surface stays legible over whatever
      // scrolls under it, little enough that the movement still shows.
      tint: fill.withValues(alpha: chrome.tintAlphaFor(theme.brightness)),
      blurSigma: blur,
      saturation: chrome.saturation,
      // Light in the dark theme, a soft dark line in the light one: the edge
      // catches whichever is brighter than the surface behind it.
      specular: Palette.sheenInk.withValues(
        alpha: chrome.specularAlphaFor(theme.brightness),
      ),
      shadow: lift,
    );
  }
}

/// Paints an [AppMaterial] behind [child], clipped to a platform shape.
///
/// This is the widget the chrome components build on. It is deliberately not
/// exported through the design-system barrel: a component that wants glass
/// belongs on the `glass-off-chrome` allowlist in `tool/ui_lint.dart`, and
/// going through that list is the point.
class AppChromeSurface extends StatelessWidget {
  const AppChromeSurface({
    required this.child,
    super.key,
    this.shape = AppShape.sheet,
    this.material,
  });

  /// The content that sits on the surface.
  final Widget child;

  /// Which platform shape to clip and cast a shadow with.
  final AppShape shape;

  /// The material to paint. Defaults to [AppMaterials.chrome].
  final AppMaterial? material;

  @override
  Widget build(BuildContext context) {
    final resolved = material ?? AppMaterials.chrome(context);
    final border = context.shapeOf(shape);

    Widget surface = DecoratedBox(
      decoration: ShapeDecoration(color: resolved.tint, shape: border),
      child: child,
    );

    if (resolved.specular != null) {
      surface = Stack(
        fit: StackFit.passthrough,
        children: [
          surface,
          // A hairline that fades out at both ends, so it reads as a
          // highlight catching the light rather than as a drawn border.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: SizedBox(
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        resolved.specular!.withValues(alpha: 0),
                        resolved.specular!,
                        resolved.specular!.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (resolved.isGlass) {
      surface = ClipPath(
        clipper: ShapeBorderClipper(shape: border),
        child: BackdropFilter(
          filter: AppMaterials.filterFor(resolved),
          child: surface,
        ),
      );
    }

    // The shadow is drawn outside the clip: clipping a surface to its own
    // shape and then asking it to cast a shadow inside that clip is how a
    // floating bar ends up with no lift at all.
    return AppChromeOcclusion(
      child: DecoratedBox(
        decoration: ShapeDecoration(shape: border, shadows: resolved.shadow),
        child: surface,
      ),
    );
  }
}

/// Marks a subtree as chrome that hides whatever is painted behind it.
///
/// A rendering no-op. It exists so a gate can tell the difference between two
/// runs of text drawn through each other and one run of text drawn *behind a
/// surface*, which is not the same event: [AppChromeSurface] is either an
/// opaque tint or a [BackdropFilter], and both of them destroy what is under
/// them. The probe's `overlap` rule reads it the way it already reads opacity
/// — a thing the reader cannot see is not a thing drawn over something else.
///
/// Written here rather than inferred in the test, because inferring it means
/// guessing at paint order and at whether a decoration happens to be opaque,
/// and a gate that guesses is a gate that is wrong somewhere nobody looks.
class AppChromeOcclusion extends SingleChildRenderObjectWidget {
  const AppChromeOcclusion({super.key, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderAppChromeOcclusion();
}

/// The render object [AppChromeOcclusion] installs. Proxies everything.
class RenderAppChromeOcclusion extends RenderProxyBox {}
