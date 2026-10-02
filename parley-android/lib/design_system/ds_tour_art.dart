// ds-tier: 1 — atom

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// How the pieces of a tour illustration are drawn and timed.
@immutable
class DSTourArtStyle extends DSComponentStyle<DSTourArtStyle> {
  const DSTourArtStyle({
    this.canvasWidth,
    this.slotHeight,
    this.placeholderAlpha,
    this.haloStrength,
  });

  /// The width every drawing is composed at before the caller scales it.
  final double? canvasWidth;

  /// The height of the blank rule inside a [DSTourFillSlot].
  final double? slotHeight;

  /// How visible the blank rule is against the sheet it sits on.
  final double? placeholderAlpha;

  /// How much of the accent shows over content as it lands, before it clears.
  final double? haloStrength;

  @override
  DSTourArtStyle merge(DSTourArtStyle? other) {
    if (other == null) return this;
    return DSTourArtStyle(
      canvasWidth: other.canvasWidth ?? canvasWidth,
      slotHeight: other.slotHeight ?? slotHeight,
      placeholderAlpha: other.placeholderAlpha ?? placeholderAlpha,
      haloStrength: other.haloStrength ?? haloStrength,
    );
  }

  @override
  DSTourArtStyle copyWith({
    double? canvasWidth,
    double? slotHeight,
    double? placeholderAlpha,
    double? haloStrength,
  }) => DSTourArtStyle(
    canvasWidth: canvasWidth ?? this.canvasWidth,
    slotHeight: slotHeight ?? this.slotHeight,
    placeholderAlpha: placeholderAlpha ?? this.placeholderAlpha,
    haloStrength: haloStrength ?? this.haloStrength,
  );

  @override
  DSTourArtStyle lerp(DSTourArtStyle? other, double t) {
    if (other == null) return this;
    return DSTourArtStyle(
      canvasWidth: lerpDouble(canvasWidth, other.canvasWidth, t),
      slotHeight: lerpDouble(slotHeight, other.slotHeight, t),
      placeholderAlpha: lerpDouble(placeholderAlpha, other.placeholderAlpha, t),
      haloStrength: lerpDouble(haloStrength, other.haloStrength, t),
    );
  }

  static DSTourArtStyle resolve(BuildContext context, {DSTourArtStyle? own}) {
    final space = context.design.space;
    return resolveStyle(
      context: context,
      // The composition width. Not a layout dimension — nothing is laid out
      // at it — so it is a number the identity can move rather than one the
      // space scale has an opinion about. 320 is the narrowest phone the
      // probe measures, which makes a drawing composed here full-bleed at
      // the smallest size and inset at every larger one.
      specDefaults: DSTourArtStyle(
        canvasWidth: 320,
        slotHeight: space.sm,
        placeholderAlpha: 0.07,
        haloStrength: 0.8,
      ),
      own: own,
    );
  }
}

/// The fixed-width board every tour illustration is composed on.
///
/// **Use when** drawing a slide's picture: put the drawing inside this, and
/// let [DSTourSlide] scale the whole board into whatever room the words leave
/// over.
///
/// **Instead:** [DSIllustration] for one of the six generic states the kit
/// already draws — empty, search, offline, done, locked, error. This is for a
/// picture of *your* product, which no kit can ship.
///
/// The board is a fixed width so a drawing never has to reflow. Everything
/// inside it is a picture of type rather than type, which is why the caller
/// strips the text scaler before drawing it — the words on the slide honour
/// the platform text scale, and the illustration keeps its proportions.
class DSTourCanvas extends StatelessWidget {
  const DSTourCanvas({super.key, required this.child, this.style});

  final Widget child;
  final DSTourArtStyle? style;

  @override
  Widget build(BuildContext context) {
    final DSTourArtStyle resolved = DSTourArtStyle.resolve(context, own: style);
    return SizedBox(width: resolved.canvasWidth, child: child);
  }
}

/// A blank ruled slot that fills with real content as its slide arrives.
///
/// **Use when** the argument for the tour is that the app *has* something
/// afterwards it does not have now — a name on an invoice, a client in a list.
/// The empty rule is the before and the content is the after, said in a
/// picture rather than in a sentence.
///
/// **Instead:** [DSSkeleton] when the content is genuinely still loading. This
/// is a drawing of a state change, not a loading state, and it never waits on
/// anything.
class DSTourFillSlot extends StatelessWidget {
  const DSTourFillSlot({
    super.key,
    required this.active,
    required this.delay,
    required this.placeholderWidth,
    required this.child,
    this.accent,
    this.style,
  });

  /// Whether the slide this sits on is the one on screen.
  final bool active;

  /// Where this slot sits in the fill order.
  final Duration delay;

  final double placeholderWidth;
  final Widget child;

  /// The halo the content lands under. Defaults to the palette's accent.
  final Color? accent;

  final DSTourArtStyle? style;

  @override
  Widget build(BuildContext context) {
    // Reduced motion has no arrival to show, so it shows the arrival's
    // outcome. A blank rule would be the one thing on the slide that is
    // simply missing.
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final DSTourArtStyle resolved = DSTourArtStyle.resolve(context, own: style);
    final Palette palette = context.palette;
    final MotionSpec motion = context.design.motion;
    final Color halo = accent ?? palette.primary;

    final Widget placeholder = Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        width: placeholderWidth,
        height: resolved.slotHeight,
        decoration: BoxDecoration(
          color: palette.foreground.withValues(
            alpha: resolved.placeholderAlpha!,
          ),
          borderRadius: BorderRadius.all(
            Radius.circular(context.radiusOf(AppShape.pill)),
          ),
        ),
      ),
    );

    return Stack(
      children: <Widget>[
        // The empty ruling, fading out under the answer as it arrives.
        Positioned.fill(
          child: Animate(
            target: active ? 1 : 0,
            effects: <Effect<dynamic>>[
              FadeEffect(delay: delay, duration: motion.fast, begin: 1, end: 0),
            ],
            child: Center(child: placeholder),
          ),
        ),
        Animate(
          target: active ? 1 : 0,
          effects: <Effect<dynamic>>[
            FadeEffect(
              delay: delay,
              duration: motion.fast,
              curve: motion.enter,
            ),
            SlideEffect(
              delay: delay,
              duration: motion.normal,
              curve: motion.enter,
              begin: const Offset(-0.05, 0),
              end: Offset.zero,
            ),
            // The halo is what makes the content read as having *landed*
            // rather than as having always been there.
            TintEffect(
              delay: delay,
              duration: motion.slow,
              color: halo,
              begin: resolved.haloStrength,
              end: 0,
            ),
          ],
          child: child,
        ),
      ],
    );
  }
}
