// ds-tier: 1 — atom

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// How a skeleton looks, at every layer of the resolution chain.
@immutable
class DSSkeletonStyle extends DSComponentStyle<DSSkeletonStyle> {
  const DSSkeletonStyle({
    this.boneColor,
    this.highlightColor,
    this.textBoneRadius,
    this.shimmerDuration,
  });

  /// [Palette.muted], the recess. A skeleton used to be drawn in
  /// `surfaceContainerHighest`, which is a *surface*: bones inside a raised
  /// card were the card's own colour and therefore invisible, which is exactly
  /// where skeletons are most used. The same defect as the slider's inactive
  /// track, from the same cause.
  final Color? boneColor;

  final Color? highlightColor;
  final BorderRadius? textBoneRadius;
  final Duration? shimmerDuration;

  @override
  DSSkeletonStyle merge(DSSkeletonStyle? other) {
    if (other == null) return this;
    return DSSkeletonStyle(
      boneColor: other.boneColor ?? boneColor,
      highlightColor: other.highlightColor ?? highlightColor,
      textBoneRadius: other.textBoneRadius ?? textBoneRadius,
      shimmerDuration: other.shimmerDuration ?? shimmerDuration,
    );
  }

  @override
  DSSkeletonStyle copyWith({
    Color? boneColor,
    Color? highlightColor,
    BorderRadius? textBoneRadius,
    Duration? shimmerDuration,
  }) => DSSkeletonStyle(
    boneColor: boneColor ?? this.boneColor,
    highlightColor: highlightColor ?? this.highlightColor,
    textBoneRadius: textBoneRadius ?? this.textBoneRadius,
    shimmerDuration: shimmerDuration ?? this.shimmerDuration,
  );

  @override
  DSSkeletonStyle lerp(DSSkeletonStyle? other, double t) {
    if (other == null) return this;
    return DSSkeletonStyle(
      shimmerDuration: t < 0.5 ? shimmerDuration : other.shimmerDuration,
      boneColor: Color.lerp(boneColor, other.boneColor, t),
      highlightColor: Color.lerp(highlightColor, other.highlightColor, t),
      textBoneRadius: BorderRadius.lerp(
        textBoneRadius,
        other.textBoneRadius,
        t,
      ),
    );
  }

  static DSSkeletonStyle resolve(BuildContext context, [DSSkeletonStyle? own]) {
    final palette = context.palette;
    final motion = context.design.motion;
    return resolveStyle(
      context: context,
      specDefaults: DSSkeletonStyle(
        boneColor: palette.muted,
        highlightColor: Color.alphaBlend(
          palette.sheen.withValues(alpha: 0.10),
          palette.muted,
        ),
        textBoneRadius: BorderRadius.circular(context.radiusOf(AppShape.pill)),
        shimmerDuration: motion.scaled(motion.shimmer),
      ),
      own: own,
    );
  }
}

/// Loading skeletons, built on the `skeletonizer` package.
///
/// The idea worth keeping: a skeleton mirrors the *shape* of the content that
/// is about to load, instead of a spinner in the middle of an empty screen.
/// The idea worth dropping: hand-drawn placeholder boxes that silently drift
/// out of shape as the real UI changes.
///
/// [DSSkeleton] wraps a real widget subtree and paints it as bones — the same
/// widgets the loaded state uses, so the two can never diverge. Feed it
/// plausible fake data and let the layout do the rest.
///
/// ```dart
/// switch (asyncValue) {
///   AsyncValue(:final value?) => LibraryList(items: value),
///   AsyncError(:final error) => DSErrorState(detailsText: '$error'),
///   _ => DSSkeleton(child: LibraryList(items: LibraryItem.placeholders)),
/// }
/// ```
class DSSkeleton extends StatelessWidget {
  /// The real widget tree, rendered as bones while [enabled] is true.
  final Widget child;

  /// When false the child renders normally — handy for wiring a single
  /// `Skeletonizer(enabled: isLoading)` around a whole page.
  final bool enabled;

  final DSSkeletonStyle? style;

  const DSSkeleton({
    super.key,
    required this.child,
    this.enabled = true,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = DSSkeletonStyle.resolve(context, style);

    final skeleton = Skeletonizer(
      enabled: enabled,
      // Themed to the identity's inert token rather than skeletonizer's default
      // grey, so loading states stay in the app's colour language.
      //
      // Under reduced motion the sweep stops and the bones become flat
      // colour, which `docs/principles/motion.md` names directly: the user
      // asked for less movement, not for less information, so the placeholder
      // stays and only the animation goes.
      effect: MediaQuery.disableAnimationsOf(context)
          ? SolidColorEffect(color: resolved.boneColor!)
          : ShimmerEffect(
              baseColor: resolved.boneColor!,
              highlightColor: resolved.highlightColor!,
              duration: resolved.shimmerDuration!,
            ),
      textBoneBorderRadius: TextBoneBorderRadius(resolved.textBoneRadius!),
      containersColor: resolved.boneColor,
      child: child,
    );

    if (!enabled) return skeleton;

    // The placeholder copy is fake, and a screen reader that reads it aloud is
    // reading the user a paragraph that will not be there in a second.
    // `Skeletonizer` leaves the real strings in the tree, so the whole subtree
    // is excluded and one word is published in its place.
    return Semantics(
      label: 'Loading',
      liveRegion: true,
      child: ExcludeSemantics(child: skeleton),
    );
  }
}
