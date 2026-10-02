// ds-tier: 2 — molecule

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_media.dart';
import 'package:parley_android/design_system/ds_pressable.dart';
import 'package:parley_android/design_system/ds_skeleton.dart';
import 'package:parley_android/design_system/ds_text_style.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Where a hero's text sits relative to its picture.
enum DSMediaHeroPlacement {
  /// The text follows the picture in a column. Works with any picture, and
  /// cannot fail a contrast check — the default.
  below,

  /// The text is drawn on the picture, over a bottom-anchored scrim. Opt-in,
  /// and degrades back to [below] past 1.6x text scale — see the class doc.
  overlay,
}

/// [DSMediaHero]'s appearance, as data.
///
/// There is deliberately no gutter field, exactly as `DSMediaTileStyle` has
/// none: the hero reads `space.pageGutter` itself, so nothing here decides a
/// second answer to the same question.
@immutable
class DSMediaHeroStyle extends DSComponentStyle<DSMediaHeroStyle> {
  const DSMediaHeroStyle({
    this.eyebrowStyle,
    this.titleStyle,
    this.subtitleStyle,
    this.titleMaxLines,
    this.subtitleMaxLines,
    this.textGap,
    this.overlayScrimColor,
    this.overlayTextColor,
  });

  final TextStyle? eyebrowStyle;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  /// The row's and tile's budget, widened by one: a hero's title is read
  /// first and largest, so it earns the extra line the other two do not.
  final int? titleMaxLines;
  final int? subtitleMaxLines;

  final double? textGap;

  /// The scrim an overlaid hero's text sits on, bottom-anchored and faded to
  /// nothing at the top edge so it reads as light falling off rather than a
  /// panel laid over the picture.
  final Color? overlayScrimColor;

  /// What the title, eyebrow and subtitle are drawn in over that scrim.
  final Color? overlayTextColor;

  @override
  DSMediaHeroStyle merge(DSMediaHeroStyle? other) {
    if (other == null) return this;
    return DSMediaHeroStyle(
      eyebrowStyle: other.eyebrowStyle ?? eyebrowStyle,
      titleStyle: other.titleStyle ?? titleStyle,
      subtitleStyle: other.subtitleStyle ?? subtitleStyle,
      titleMaxLines: other.titleMaxLines ?? titleMaxLines,
      subtitleMaxLines: other.subtitleMaxLines ?? subtitleMaxLines,
      textGap: other.textGap ?? textGap,
      overlayScrimColor: other.overlayScrimColor ?? overlayScrimColor,
      overlayTextColor: other.overlayTextColor ?? overlayTextColor,
    );
  }

  @override
  DSMediaHeroStyle copyWith({
    TextStyle? eyebrowStyle,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
    int? titleMaxLines,
    int? subtitleMaxLines,
    double? textGap,
    Color? overlayScrimColor,
    Color? overlayTextColor,
  }) => DSMediaHeroStyle(
    eyebrowStyle: eyebrowStyle ?? this.eyebrowStyle,
    titleStyle: titleStyle ?? this.titleStyle,
    subtitleStyle: subtitleStyle ?? this.subtitleStyle,
    titleMaxLines: titleMaxLines ?? this.titleMaxLines,
    subtitleMaxLines: subtitleMaxLines ?? this.subtitleMaxLines,
    textGap: textGap ?? this.textGap,
    overlayScrimColor: overlayScrimColor ?? this.overlayScrimColor,
    overlayTextColor: overlayTextColor ?? this.overlayTextColor,
  );

  @override
  DSMediaHeroStyle lerp(DSMediaHeroStyle? other, double t) {
    if (other == null) return this;
    return DSMediaHeroStyle(
      eyebrowStyle: TextStyle.lerp(eyebrowStyle, other.eyebrowStyle, t),
      titleStyle: TextStyle.lerp(titleStyle, other.titleStyle, t),
      subtitleStyle: TextStyle.lerp(subtitleStyle, other.subtitleStyle, t),
      titleMaxLines: t < 0.5 ? titleMaxLines : other.titleMaxLines,
      subtitleMaxLines: t < 0.5 ? subtitleMaxLines : other.subtitleMaxLines,
      textGap: lerpDouble(textGap, other.textGap, t),
      overlayScrimColor: Color.lerp(
        overlayScrimColor,
        other.overlayScrimColor,
        t,
      ),
      overlayTextColor: Color.lerp(overlayTextColor, other.overlayTextColor, t),
    );
  }

  static DSMediaHeroStyle resolve(
    BuildContext context, [
    DSMediaHeroStyle? own,
  ]) {
    final palette = context.palette;
    final space = context.design.space;
    final text = Theme.of(context).textTheme;

    return resolveStyle(
      context: context,
      specDefaults: DSMediaHeroStyle(
        eyebrowStyle: text.labelSmall?.copyWith(
          color: palette.primary,
          fontWeight: context.design.type.emphasisWeight,
        ),
        // `titleLarge`, the same style `DSLargeAppBar` gives its own title —
        // a hero is the page's subject exactly as that app bar is, and the
        // two should not disagree about how big that is.
        titleStyle: text.titleLarge?.copyWith(
          color: palette.foreground,
          fontWeight: context.design.type.emphasisWeight,
        ),
        subtitleStyle: DSTextRole.bodySupport.styleOf(context),
        titleMaxLines: 2,
        subtitleMaxLines: 2,
        textGap: space.xs,
        overlayScrimColor: palette.overlay,
        overlayTextColor: palette.sheen,
      ),
      own: own,
    );
  }
}

/// The one item a page leads with, at the size that says so.
///
/// **Use when** a surface has a single featured item above everything else —
/// a top story, the album a screen is about, the video a tab opens on.
/// **Instead:** `DSMediaTile` the moment there are two of them; two heroes is
/// a grid whose cells are too big. `DSCard` when the feature is text rather
/// than a picture, and `DSLargeAppBar` when it is the page's title rather than
/// one of its items.
class DSMediaHero extends StatelessWidget {
  const DSMediaHero({
    super.key,
    required this.source,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.meta = const [],
    this.aspect = DSMediaAspect.wide,
    this.placement = DSMediaHeroPlacement.below,
    this.fullBleed = false,
    this.status = const DSMediaStatus(),
    this.overlay,
    this.onTap,
    this.enabled = true,
    this.loading = false,
    this.style,
    this.mediaStyle,
    this.titleSlot,
    this.subtitleSlot,
  });

  final DSMediaSource source;

  /// `wide`, the shape a featured item is laid out at — a hero fills its
  /// column, never a token width, so there is no `width` parameter here the
  /// way `DSMediaTile.width` gives a carousel item one.
  final DSMediaAspect aspect;

  final String title;

  /// Read first, before [title] — a section kicker, a category, a date.
  final String? eyebrow;
  final String? subtitle;

  /// The fact row, laid out with `DSMediaMeta` — see that widget rather than
  /// writing a third one.
  final List<Widget> meta;

  /// [DSMediaHeroPlacement.below] is the default: it works with any picture
  /// and cannot fail a contrast check. [DSMediaHeroPlacement.overlay] is
  /// opt-in and degrades back to [DSMediaHeroPlacement.below] past 1.6x text
  /// scale — see the class doc.
  final DSMediaHeroPlacement placement;

  /// Drops both the page gutter and the picture's radius, reaching the edge
  /// of the screen. The only member of the family permitted to: a hero is the
  /// page's subject rather than a row within it.
  final bool fullBleed;

  final DSMediaStatus status;

  /// Painted over the picture box and clipped to its radius. Passed straight
  /// through to [DSMediaSurface].
  final Widget? overlay;

  final VoidCallback? onTap;

  final bool enabled;
  final bool loading;

  final DSMediaHeroStyle? style;
  final DSMediaSurfaceStyle? mediaStyle;

  final Widget? titleSlot;
  final Widget? subtitleSlot;

  String _sentence() {
    final buffer = StringBuffer(eyebrow != null ? '$eyebrow, $title' : title);
    if (subtitle != null) buffer.write(', $subtitle');
    if (source.semanticLabel.isNotEmpty) {
      buffer.write(', ${source.semanticLabel}');
    }
    for (final phrase in status.semanticPhrases()) {
      buffer.write(', $phrase');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    // Not a constructor assert: `source.isEmpty` dispatches through the
    // abstract getter `DSMediaSource` declares, and the CFE cannot fold that
    // dispatch in a const constructor's initializer list for *any* subtype —
    // confirmed directly (`const Probe(DSMediaSource.none())` against a
    // one-getter probe class fails the same way: "The property 'isEmpty'
    // can't be accessed ... in a constant expression"). That is a stronger
    // case than `DSMediaRow`'s `List.isEmpty`, which fails for the same
    // reason but only ever affected one call site; keeping the assert in this
    // constructor's initializer list would break every `const DSMediaHero(
    // source: ...)` in this very test file. The check moves to first build
    // instead, exactly as `DSMediaRow` moves its own to first build, so the
    // constructor keeps `const`.
    assert(
      placement == DSMediaHeroPlacement.below || !source.isEmpty,
      'Text drawn over nothing is text on the page background at the wrong '
      'contrast. A hero with no picture is placement: below.',
    );
    final palette = context.palette;
    final space = context.design.space;
    final resolved = DSMediaHeroStyle.resolve(context, style);
    final double scale = MediaQuery.textScalerOf(context).scale(1);
    // Text over a photograph stops being legible at this size at any scrim,
    // so overlay is a real fallback rather than a preference.
    final bool over = placement == DSMediaHeroPlacement.overlay && scale <= 1.6;
    // Past 1.6x the text block goes intrinsic rather than clipping — the same
    // rule `DSMediaTile` and `DSMediaRow` use.
    final int? titleMaxLines = scale > 1.6
        ? null
        : (resolved.titleMaxLines ?? 2);
    final int? subtitleMaxLines = scale > 1.6
        ? null
        : (resolved.subtitleMaxLines ?? 2);

    final DSMediaSurfaceStyle? effectiveMediaStyle = fullBleed
        ? (mediaStyle ?? const DSMediaSurfaceStyle()).merge(
            const DSMediaSurfaceStyle(radius: BorderRadius.zero),
          )
        : mediaStyle;

    final Widget media = DSMediaSurface(
      source: source,
      aspect: aspect,
      status: status,
      showRank: false,
      enabled: enabled,
      overlay: overlay,
      style: effectiveMediaStyle,
    );

    Widget textColumn({Color? colorOverride}) {
      final Color? tone =
          colorOverride ?? (enabled ? null : palette.mutedForeground);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (eyebrow != null) ...[
            Text(eyebrow!, style: resolved.eyebrowStyle?.copyWith(color: tone)),
            SizedBox(height: space.hairline),
          ],
          titleSlot ??
              Text(
                title,
                style: resolved.titleStyle?.copyWith(color: tone),
                maxLines: titleMaxLines,
                overflow: titleMaxLines == null ? null : TextOverflow.ellipsis,
              ),
          if (subtitleSlot != null || subtitle != null) ...[
            SizedBox(height: space.hairline),
            subtitleSlot ??
                Text(
                  subtitle!,
                  style: resolved.subtitleStyle?.copyWith(color: tone),
                  maxLines: subtitleMaxLines,
                  overflow: subtitleMaxLines == null
                      ? null
                      : TextOverflow.ellipsis,
                ),
          ],
          if (meta.isNotEmpty) ...[
            SizedBox(height: space.sm),
            Wrap(spacing: space.sm, runSpacing: space.xs, children: meta),
          ],
        ],
      );
    }

    Widget content;
    if (over) {
      content = Stack(
        children: [
          media,
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    resolved.overlayScrimColor!.withValues(alpha: 0),
                    resolved.overlayScrimColor!,
                  ],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(space.md),
                child: textColumn(colorOverride: resolved.overlayTextColor),
              ),
            ),
          ),
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          media,
          SizedBox(height: resolved.textGap),
          textColumn(),
        ],
      );
    }

    if (onTap != null && enabled && !loading) {
      // A hero is a bounded surface, exactly as a tile is — not full-bleed
      // like the row — so it presses through `DSPressable` the tile's way,
      // dipping within its own box rather than lighting up edge to edge.
      content = DSPressable(
        focusShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.radiusOf(AppShape.tile)),
        ),
        child: GestureDetector(onTap: onTap, child: content),
      );
    }

    if (!fullBleed) {
      content = Padding(
        padding: EdgeInsetsDirectional.only(
          start: space.pageGutter,
          end: space.pageGutter,
        ),
        child: content,
      );
    }

    final Widget node = Semantics(
      container: true,
      button: onTap != null,
      enabled: enabled,
      label: _sentence(),
      onTap: enabled && !loading ? onTap : null,
      child: ExcludeSemantics(child: content),
    );

    return DSSkeleton(enabled: loading, child: node);
  }
}

/// A hero-shaped skeleton, built from the slots the real hero will have.
class DSMediaHeroSkeleton extends StatelessWidget {
  const DSMediaHeroSkeleton({
    super.key,
    this.placement = DSMediaHeroPlacement.below,
    this.fullBleed = false,
  });

  final DSMediaHeroPlacement placement;
  final bool fullBleed;

  @override
  Widget build(BuildContext context) => DSMediaHero(
    source: const DSMediaSource.widget(SizedBox.expand(), semanticLabel: ''),
    title: 'Placeholder headline',
    subtitle: 'Secondary line of placeholder copy',
    placement: placement,
    fullBleed: fullBleed,
    loading: true,
  );
}
