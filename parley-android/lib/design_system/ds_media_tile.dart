// ds-tier: 2 — molecule

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_media.dart';
import 'package:parley_android/design_system/ds_media_row.dart';
import 'package:parley_android/design_system/ds_pressable.dart';
import 'package:parley_android/design_system/ds_skeleton.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// [DSMediaTile]'s appearance, as data.
///
/// There is deliberately no gutter or padding field. The tile draws no page
/// gutter of its own — see the class doc — so nothing here decides one.
@immutable
class DSMediaTileStyle extends DSComponentStyle<DSMediaTileStyle> {
  const DSMediaTileStyle({
    this.titleStyle,
    this.subtitleStyle,
    this.titleMaxLines,
    this.subtitleMaxLines,
    this.textGap,
    this.metaGap,
  });

  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  /// The row's budget exactly: a grid and a list of the same content read
  /// the same. See `DSMediaRowStyle.titleMaxLines` for why the ceiling is
  /// where it is.
  final int? titleMaxLines;
  final int? subtitleMaxLines;

  final double? textGap;
  final double? metaGap;

  @override
  DSMediaTileStyle merge(DSMediaTileStyle? other) {
    if (other == null) return this;
    return DSMediaTileStyle(
      titleStyle: other.titleStyle ?? titleStyle,
      subtitleStyle: other.subtitleStyle ?? subtitleStyle,
      titleMaxLines: other.titleMaxLines ?? titleMaxLines,
      subtitleMaxLines: other.subtitleMaxLines ?? subtitleMaxLines,
      textGap: other.textGap ?? textGap,
      metaGap: other.metaGap ?? metaGap,
    );
  }

  @override
  DSMediaTileStyle copyWith({
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
    int? titleMaxLines,
    int? subtitleMaxLines,
    double? textGap,
    double? metaGap,
  }) => DSMediaTileStyle(
    titleStyle: titleStyle ?? this.titleStyle,
    subtitleStyle: subtitleStyle ?? this.subtitleStyle,
    titleMaxLines: titleMaxLines ?? this.titleMaxLines,
    subtitleMaxLines: subtitleMaxLines ?? this.subtitleMaxLines,
    textGap: textGap ?? this.textGap,
    metaGap: metaGap ?? this.metaGap,
  );

  @override
  DSMediaTileStyle lerp(DSMediaTileStyle? other, double t) {
    if (other == null) return this;
    return DSMediaTileStyle(
      titleStyle: TextStyle.lerp(titleStyle, other.titleStyle, t),
      subtitleStyle: TextStyle.lerp(subtitleStyle, other.subtitleStyle, t),
      titleMaxLines: t < 0.5 ? titleMaxLines : other.titleMaxLines,
      subtitleMaxLines: t < 0.5 ? subtitleMaxLines : other.subtitleMaxLines,
      textGap: lerpDouble(textGap, other.textGap, t),
      metaGap: lerpDouble(metaGap, other.metaGap, t),
    );
  }

  static DSMediaTileStyle resolve(
    BuildContext context, [
    DSMediaTileStyle? own,
  ]) {
    final palette = context.palette;
    final space = context.design.space;
    final text = Theme.of(context).textTheme;

    return resolveStyle(
      context: context,
      specDefaults: DSMediaTileStyle(
        // Same size and weight as the row's title — a title is a title
        // whichever shape carries it.
        titleStyle: text.bodyMedium?.copyWith(
          color: palette.foreground,
          fontWeight: context.design.type.emphasisWeight,
        ),
        subtitleStyle: DSTextRole.itemSubtitle.styleOf(context),
        titleMaxLines: 2,
        subtitleMaxLines: 1,
        textGap: space.xs,
        metaGap: space.sm,
      ),
      own: own,
    );
  }
}

/// One item as a picture with its name under it — a poster in a grid, a card
/// in a carousel, an album in a shelf.
///
/// **Use when** the picture is how the reader recognises the item and the
/// layout is two-dimensional or horizontal: a grid (`width: null`, so the tile
/// fills its column) or a carousel (a token width, so a `Row` of tiles is the
/// whole carousel). **Instead:** `DSMediaRow` when the layout is a vertical
/// list — a row gives the text three times the width and is what a long list
/// is scanned in. `DSMediaHero` for the one featured item at the top of a
/// page. `DSCard` when there is no picture, and `DSStatTile` when the content
/// is a figure.
class DSMediaTile extends StatelessWidget {
  const DSMediaTile({
    super.key,
    required this.source,
    required this.title,
    this.aspect = DSMediaAspect.square,
    this.width,
    this.subtitle,
    this.meta = const [],
    this.status = const DSMediaStatus(),
    this.overlay,
    this.onTap,
    this.selected = false,
    this.enabled = true,
    this.loading = false,
    this.style,
    this.mediaStyle,
    this.titleSlot,
    this.subtitleSlot,
  });

  final DSMediaSource source;
  final DSMediaAspect aspect;

  /// Null fills the column — the grid case. A token width sizes the tile and
  /// the picture's height follows — the carousel case, whose token is
  /// `space.xxxl * 3`.
  final double? width;

  final String title;
  final String? subtitle;

  /// The fact row, laid out with [DSMediaMeta] — see that widget rather than
  /// writing a second one.
  final List<Widget> meta;

  final DSMediaStatus status;

  /// Painted over the picture box and clipped to its radius. Passed straight
  /// through to [DSMediaSurface].
  final Widget? overlay;

  final VoidCallback? onTap;

  /// State, and therefore a property rather than a constructor — see
  /// `DSMediaRow.selected`.
  final bool selected;

  final bool enabled;
  final bool loading;

  final DSMediaTileStyle? style;
  final DSMediaSurfaceStyle? mediaStyle;

  final Widget? titleSlot;
  final Widget? subtitleSlot;

  String _sentence() {
    final buffer = StringBuffer(title);
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
    final palette = context.palette;
    final space = context.design.space;
    final resolved = DSMediaTileStyle.resolve(context, style);
    final double scale = MediaQuery.textScalerOf(context).scale(1);
    // Past this the text block goes intrinsic rather than clipping — a name
    // that no longer fits two lines is a name the reader still needs to read.
    final int? titleMaxLines = scale > 1.6
        ? null
        : (resolved.titleMaxLines ?? 2);
    final int? subtitleMaxLines = scale > 1.6
        ? null
        : (resolved.subtitleMaxLines ?? 1);

    final Widget media = DSMediaSurface(
      source: source,
      aspect: aspect,
      width: width,
      status: status,
      showRank: true,
      selected: selected,
      enabled: enabled,
      overlay: overlay,
      style: mediaStyle,
    );

    Widget column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        media,
        SizedBox(height: resolved.textGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child:
                  titleSlot ??
                  Text(
                    title,
                    style: resolved.titleStyle?.copyWith(
                      color: enabled ? null : palette.mutedForeground,
                    ),
                    maxLines: titleMaxLines,
                    overflow: titleMaxLines == null
                        ? null
                        : TextOverflow.ellipsis,
                  ),
            ),
            if (status.unread) ...[
              SizedBox(width: space.sm),
              dsMediaUnreadDot(context, enabled: enabled),
            ],
          ],
        ),
        if (subtitleSlot != null || subtitle != null) ...[
          SizedBox(height: space.hairline),
          subtitleSlot ??
              Text(
                subtitle!,
                style: resolved.subtitleStyle?.copyWith(
                  color: enabled ? null : palette.mutedForeground,
                ),
                maxLines: subtitleMaxLines,
                overflow: subtitleMaxLines == null
                    ? null
                    : TextOverflow.ellipsis,
              ),
        ],
        if (meta.isNotEmpty) ...[
          SizedBox(height: resolved.metaGap ?? space.sm),
          Wrap(spacing: space.sm, runSpacing: space.xs, children: meta),
        ],
      ],
    );

    if (width != null) {
      column = SizedBox(width: width, child: column);
    }

    Widget content = column;

    if (onTap != null && enabled && !loading) {
      content = DSPressable(
        focusShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.radiusOf(AppShape.tile)),
        ),
        child: GestureDetector(onTap: onTap, child: content),
      );
    }

    final Widget node = Semantics(
      container: true,
      button: onTap != null,
      selected: selected,
      enabled: enabled,
      label: _sentence(),
      onTap: enabled && !loading ? onTap : null,
      child: ExcludeSemantics(child: content),
    );

    return DSSkeleton(enabled: loading, child: node);
  }
}

/// A tile-shaped skeleton, built from the slots the real tile will have.
class DSMediaTileSkeleton extends StatelessWidget {
  const DSMediaTileSkeleton({
    super.key,
    this.aspect = DSMediaAspect.square,
    this.width,
    this.showSubtitle = true,
  });

  final DSMediaAspect aspect;
  final double? width;
  final bool showSubtitle;

  @override
  Widget build(BuildContext context) => DSMediaTile(
    source: const DSMediaSource.widget(SizedBox.expand(), semanticLabel: ''),
    aspect: aspect,
    width: width,
    title: 'Placeholder headline',
    subtitle: showSubtitle ? 'Secondary line' : null,
    loading: true,
  );
}
