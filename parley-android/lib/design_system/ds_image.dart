// ds-tier: 1 — atom

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_skeleton.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// How a remote picture looks while it is arriving, and when it never does.
@immutable
class DSImageStyle extends DSComponentStyle<DSImageStyle> {
  const DSImageStyle({
    this.background,
    this.radius,
    this.failureColor,
    this.failureIconSize,
    this.fadeDuration,
    this.fadeCurve,
  });

  /// What is painted under the bytes.
  ///
  /// A picture that has not arrived is a hole, and a hole the colour of the
  /// surface behind it reads as a layout bug. The well is the kit's answer to
  /// "something belongs here": the same fill a [DSWell] uses for a glyph.
  final Color? background;

  final BorderRadius? radius;

  /// The failed glyph, and its size. One glyph rather than a message: a row of
  /// twelve broken thumbnails with twelve copies of "Couldn't load" is a
  /// screen about the failure rather than about the content.
  final Color? failureColor;
  final double? failureIconSize;

  /// The first frame fades rather than snapping in. Skipped entirely under
  /// reduced motion — see `docs/principles/motion.md`.
  final Duration? fadeDuration;
  final Curve? fadeCurve;

  @override
  DSImageStyle merge(DSImageStyle? other) {
    if (other == null) return this;
    return DSImageStyle(
      background: other.background ?? background,
      radius: other.radius ?? radius,
      failureColor: other.failureColor ?? failureColor,
      failureIconSize: other.failureIconSize ?? failureIconSize,
      fadeDuration: other.fadeDuration ?? fadeDuration,
      fadeCurve: other.fadeCurve ?? fadeCurve,
    );
  }

  @override
  DSImageStyle copyWith({
    Color? background,
    BorderRadius? radius,
    Color? failureColor,
    double? failureIconSize,
    Duration? fadeDuration,
    Curve? fadeCurve,
  }) => DSImageStyle(
    background: background ?? this.background,
    radius: radius ?? this.radius,
    failureColor: failureColor ?? this.failureColor,
    failureIconSize: failureIconSize ?? this.failureIconSize,
    fadeDuration: fadeDuration ?? this.fadeDuration,
    fadeCurve: fadeCurve ?? this.fadeCurve,
  );

  @override
  DSImageStyle lerp(DSImageStyle? other, double t) {
    if (other == null) return this;
    return DSImageStyle(
      background: Color.lerp(background, other.background, t),
      radius: BorderRadius.lerp(radius, other.radius, t),
      failureColor: Color.lerp(failureColor, other.failureColor, t),
      failureIconSize: lerpDouble(failureIconSize, other.failureIconSize, t),
      fadeDuration: t < 0.5 ? fadeDuration : other.fadeDuration,
      fadeCurve: t < 0.5 ? fadeCurve : other.fadeCurve,
    );
  }

  static DSImageStyle resolve(
    BuildContext context,
    AppShape shape, [
    DSImageStyle? own,
  ]) {
    final design = context.design;
    final palette = context.palette;
    final motion = design.motion;

    return resolveStyle(
      context: context,
      specDefaults: DSImageStyle(
        background: palette.muted,
        radius: BorderRadius.all(Radius.circular(context.radiusOf(shape))),
        failureColor: palette.mutedForeground,
        failureIconSize: design.component.iconSize,
        fadeDuration: motion.scaled(motion.fast),
        fadeCurve: motion.enter,
      ),
      own: own,
    );
  }
}

/// A picture the app did not ship in its bundle.
///
/// The kit had this four times before it had it once: `Image.network` in the
/// avatar with an `errorBuilder` and no placeholder, `Image.network` in the
/// media row with all three states, and whatever a screen wrote next. The
/// three that matter are the three a remote image actually has, and every one
/// of them is a defect when it is left out:
///
///   * **arriving** — the box is drawn at its final size before a byte lands,
///     shimmering, so nothing under it moves when the bytes do. A picture
///     with no placeholder reflows the list it is in, which is the scroll
///     jump users read as jank.
///   * **arrived** — the first frame fades in over [DSImageStyle.fadeDuration],
///     and does not fade when the frame was already in the cache (a cached
///     image that fades makes a revisited screen feel slower than a cold one)
///     or when the device asks for reduced motion.
///   * **failed** — one glyph on the well, at the same size. Not an empty
///     box, which reads as a layout bug, and not a sentence, which turns a
///     grid of thumbnails into a wall of apologies.
///
/// It carries no cache of its own. Flutter's [ImageCache] is already
/// process-wide and already keyed on the provider; a component that added a
/// second one would be a second thing to invalidate. For disk persistence
/// across launches, hand [DSImage.provider] whichever package the app has
/// chosen — the states above are the part the kit owns, not the transport.
///
/// **Accessibility.** Every picture is either content or decoration, and the
/// constructor makes you say which: pass a [semanticLabel], or pass
/// `decorative: true` and the image is dropped from the semantics tree
/// entirely. A screen reader that announces "image" twelve times on a list is
/// the failure this assertion prevents.
class DSImage extends StatelessWidget {
  /// A picture fetched over the network.
  const DSImage.network(
    String this.url, {
    super.key,
    this.width,
    this.height,
    this.aspectRatio,
    this.fit = BoxFit.cover,
    this.shape = AppShape.tile,
    this.semanticLabel,
    this.decorative = false,
    this.placeholder,
    this.failure,
    this.style,
  }) : assetPath = null,
       imageProvider = null,
       assert(
         decorative || semanticLabel != null,
         'a DSImage is content or decoration: pass a semanticLabel, or pass '
         'decorative: true so it leaves the semantics tree',
       );

  /// A picture shipped in the bundle. Same three states, because an asset can
  /// still be missing from a build.
  const DSImage.asset(
    String this.assetPath, {
    super.key,
    this.width,
    this.height,
    this.aspectRatio,
    this.fit = BoxFit.cover,
    this.shape = AppShape.tile,
    this.semanticLabel,
    this.decorative = false,
    this.placeholder,
    this.failure,
    this.style,
  }) : url = null,
       imageProvider = null,
       assert(
         decorative || semanticLabel != null,
         'a DSImage is content or decoration: pass a semanticLabel, or pass '
         'decorative: true so it leaves the semantics tree',
       );

  /// Any other source — a file, a memory buffer, or the caching provider from
  /// whichever package the app has chosen. The escape hatch that means a
  /// caller never has to drop back to a raw [Image] to change the transport.
  const DSImage.provider(
    ImageProvider this.imageProvider, {
    super.key,
    this.width,
    this.height,
    this.aspectRatio,
    this.fit = BoxFit.cover,
    this.shape = AppShape.tile,
    this.semanticLabel,
    this.decorative = false,
    this.placeholder,
    this.failure,
    this.style,
  }) : url = null,
       assetPath = null,
       assert(
         decorative || semanticLabel != null,
         'a DSImage is content or decoration: pass a semanticLabel, or pass '
         'decorative: true so it leaves the semantics tree',
       );

  final String? url;
  final String? assetPath;
  final ImageProvider? imageProvider;

  /// The box. Give it a size, an aspect ratio, or neither and let it fill the
  /// space it was handed — but give it *something* before the bytes arrive,
  /// or the placeholder has no shape to hold open.
  final double? width;
  final double? height;
  final double? aspectRatio;

  final BoxFit fit;

  /// Which radius step the corners take. [AppShape.pill] is how an avatar is
  /// drawn; [AppShape.card] matches the surface a hero image sits at the top
  /// of.
  final AppShape shape;

  /// What a screen reader says. Required unless [decorative].
  final String? semanticLabel;

  /// Whether this picture carries no information — a texture, a backdrop, a
  /// duplicate of the label beside it.
  final bool decorative;

  /// The arriving state. Defaults to a [DSSkeleton] at the final box size.
  final Widget? placeholder;

  /// The failed state. Defaults to one glyph, centred.
  final Widget? failure;

  final DSImageStyle? style;

  ImageProvider _provider() {
    if (imageProvider != null) return imageProvider!;
    if (assetPath != null) return AssetImage(assetPath!);
    return NetworkImage(url!);
  }

  @override
  Widget build(BuildContext context) {
    final resolved = DSImageStyle.resolve(context, shape, style);

    Widget picture = Image(
      image: _provider(),
      fit: fit,
      // The node is the one this component makes below. Two nodes over one
      // picture is how a list of thumbnails starts announcing "image, image,
      // image" between the rows that mean something.
      excludeFromSemantics: true,
      errorBuilder: (context, _, _) => failure ?? _failure(context, resolved),
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        // Already in the cache. Fading it would make the second visit to a
        // screen look slower than the first.
        if (wasSynchronouslyLoaded) return child;
        if (frame == null) return placeholder ?? _placeholder();
        return _fadeIn(context, resolved, child);
      },
    );

    picture = DecoratedBox(
      decoration: BoxDecoration(color: resolved.background),
      child: picture,
    );

    picture = ClipRRect(borderRadius: resolved.radius!, child: picture);

    if (aspectRatio != null) {
      picture = AspectRatio(aspectRatio: aspectRatio!, child: picture);
    }
    if (width != null || height != null) {
      picture = SizedBox(width: width, height: height, child: picture);
    }

    if (decorative) return ExcludeSemantics(child: picture);
    return Semantics(
      container: true,
      image: true,
      label: semanticLabel,
      child: picture,
    );
  }

  Widget _fadeIn(BuildContext context, DSImageStyle resolved, Widget child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: resolved.fadeDuration!,
      curve: resolved.fadeCurve!,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: child,
    );
  }

  /// The exact final box, shimmering. Nothing reflows when the bytes land.
  Widget _placeholder() => const DSSkeleton(child: SizedBox.expand());

  Widget _failure(BuildContext context, DSImageStyle resolved) => Center(
    child: Icon(
      Icons.broken_image_outlined,
      color: resolved.failureColor,
      size: resolved.failureIconSize,
    ),
  );
}
