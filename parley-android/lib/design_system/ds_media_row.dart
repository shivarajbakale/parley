// ds-tier: 2 — molecule

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:flutter/semantics.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_media.dart';
import 'package:parley_android/design_system/ds_menu.dart';
import 'package:parley_android/design_system/ds_pressable.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_skeleton.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The two designed row scales.
enum DSMediaSize { compact, md }

/// [DSMediaRow]'s appearance, as data.
///
/// There is deliberately no `horizontalPadding`. The row reads
/// `space.pageGutter` itself, exactly as [DSListTile] does, so a list of media
/// rows has the same left edge as a list of tiles and as the section headers
/// above them. The comment that used to sit here named `DSPage`, `DSFormPage`
/// and `DSGutter` as the gutter's owners while none of the three had been
/// written, so what it actually said was "somebody else insets this row", and
/// nobody did — the demo blog's thumbnails sat flush against the edge of the
/// screen while its own section headers were 16 points in. `DSPageSection` and
/// `DSGutter` ship now, and they inset the *boxes* on a page; a row is the
/// other half of that split and still insets itself.
@immutable
class DSMediaRowStyle extends DSComponentStyle<DSMediaRowStyle> {
  const DSMediaRowStyle({
    this.mediaExtent,
    this.mediaGap,
    this.titleStyle,
    this.subtitleStyle,
    this.titleMaxLines,
    this.subtitleMaxLines,
    this.metaGap,
    this.verticalPadding,
    this.minHeight,
    this.selectedColor,
    this.pressedColor,
  }) : assert(
         titleMaxLines == null || titleMaxLines <= 4,
         'A list whose rows are different heights cannot be scanned, and '
         'ListView cannot cheaply extent-cache it. An extension point with a '
         'documented bound is still an extension point; an unbounded one here '
         'is an invitation. The bound moved from 2 to 4 when the probe '
         'measured a real headline: a 68-character title beside a 64-point '
         'thumbnail takes four lines on a 320-point phone at the 1.3x text '
         'scale, and a headline cut with an ellipsis is a row the reader '
         'cannot use. Past four a row is a card.',
       ),
       // One, not two. The bound said 2 from the era when the row's
       // supporting line could take a second line; the resolved defaults have
       // been 1 at `md` and 0 at `compact` since the family was rebuilt, and
       // a bound nothing enforces is a bound a later caller reads as
       // permission. A supporting line that needs two lines is a title.
       assert(subtitleMaxLines == null || subtitleMaxLines <= 1);

  /// The height of the media box. Its width is [mediaExtent] × the aspect.
  final double? mediaExtent;
  final double? mediaGap;

  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  /// Bounded at 4 by the constructor — see the assertion message.
  ///
  /// The default is 1, which is right for a row whose title names an object
  /// ("Designing for the platform"). A row whose title is a *headline* — an
  /// article, a post, an email subject — passes more: truncating content is
  /// not the same decision as truncating a label, and the `clipped-text`
  /// probe rule fails the first one.
  final int? titleMaxLines;
  final int? subtitleMaxLines;

  final double? metaGap;
  final double? verticalPadding;
  final double? minHeight;
  final Color? selectedColor;
  final Color? pressedColor;

  @override
  DSMediaRowStyle merge(DSMediaRowStyle? other) {
    if (other == null) return this;
    return DSMediaRowStyle(
      mediaExtent: other.mediaExtent ?? mediaExtent,
      mediaGap: other.mediaGap ?? mediaGap,
      titleStyle: other.titleStyle ?? titleStyle,
      subtitleStyle: other.subtitleStyle ?? subtitleStyle,
      titleMaxLines: other.titleMaxLines ?? titleMaxLines,
      subtitleMaxLines: other.subtitleMaxLines ?? subtitleMaxLines,
      metaGap: other.metaGap ?? metaGap,
      verticalPadding: other.verticalPadding ?? verticalPadding,
      minHeight: other.minHeight ?? minHeight,
      selectedColor: other.selectedColor ?? selectedColor,
      pressedColor: other.pressedColor ?? pressedColor,
    );
  }

  @override
  DSMediaRowStyle copyWith({
    double? mediaExtent,
    double? mediaGap,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
    int? titleMaxLines,
    int? subtitleMaxLines,
    double? metaGap,
    double? verticalPadding,
    double? minHeight,
    Color? selectedColor,
    Color? pressedColor,
  }) => DSMediaRowStyle(
    mediaExtent: mediaExtent ?? this.mediaExtent,
    mediaGap: mediaGap ?? this.mediaGap,
    titleStyle: titleStyle ?? this.titleStyle,
    subtitleStyle: subtitleStyle ?? this.subtitleStyle,
    titleMaxLines: titleMaxLines ?? this.titleMaxLines,
    subtitleMaxLines: subtitleMaxLines ?? this.subtitleMaxLines,
    metaGap: metaGap ?? this.metaGap,
    verticalPadding: verticalPadding ?? this.verticalPadding,
    minHeight: minHeight ?? this.minHeight,
    selectedColor: selectedColor ?? this.selectedColor,
    pressedColor: pressedColor ?? this.pressedColor,
  );

  @override
  DSMediaRowStyle lerp(DSMediaRowStyle? other, double t) {
    if (other == null) return this;
    return DSMediaRowStyle(
      mediaExtent: lerpDouble(mediaExtent, other.mediaExtent, t),
      mediaGap: lerpDouble(mediaGap, other.mediaGap, t),
      titleStyle: TextStyle.lerp(titleStyle, other.titleStyle, t),
      subtitleStyle: TextStyle.lerp(subtitleStyle, other.subtitleStyle, t),
      titleMaxLines: t < 0.5 ? titleMaxLines : other.titleMaxLines,
      subtitleMaxLines: t < 0.5 ? subtitleMaxLines : other.subtitleMaxLines,
      metaGap: lerpDouble(metaGap, other.metaGap, t),
      verticalPadding: lerpDouble(verticalPadding, other.verticalPadding, t),
      minHeight: lerpDouble(minHeight, other.minHeight, t),
      selectedColor: Color.lerp(selectedColor, other.selectedColor, t),
      pressedColor: Color.lerp(pressedColor, other.pressedColor, t),
    );
  }

  static DSMediaSize sizeOf(BuildContext context, DSMediaSize? size) =>
      size ??
      (DSScope.densityOf(context) == DSDensity.compact
          ? DSMediaSize.compact
          : DSMediaSize.md);

  static DSMediaRowStyle resolve(
    BuildContext context,
    DSMediaSize? size, [
    DSMediaRowStyle? own,
  ]) {
    final palette = context.palette;
    final space = context.design.space;
    final text = Theme.of(context).textTheme;
    final compact = sizeOf(context, size) == DSMediaSize.compact;

    // The row's vertical padding, and the number [minHeight] is derived from:
    // a row's floor is its picture plus its padding, so the two cannot drift
    // apart and leave a list whose rows are taller than anything in them.
    final double padding = compact ? space.sm : space.md;
    final double extent = compact ? space.xxxl : space.xxxl + space.lg;

    return resolveStyle(
      context: context,
      specDefaults: DSMediaRowStyle(
        // 64, down from 72. A thumbnail is the row's *second* element — it
        // says which article this is once the reader is already reading the
        // headline — and at 72 it pushed the text column 84 points off the
        // page gutter, which is a quarter of a 320-point screen spent before
        // the first word. 64 keeps the picture legible and gives the column
        // back eight points at every width.
        mediaExtent: extent,
        mediaGap: space.md,
        // A row title is a row title, at one size for both densities. This
        // was `titleMedium` (18.3pt) at `md`, which set it *above*
        // `DSListTile`'s own title and two points under the page's headline —
        // so a list of five articles read as five headings, each wrapping to
        // two or three lines.
        //
        // `bodyMedium` is the scale's pivot: the size the platform standards
        // put running text at, and the floor the `clipped-text` probe rule
        // uses to tell content from a caption. A row title should be the
        // smallest thing that still reads as content, and this is exactly
        // that number. Density is spent on the picture and the padding — the
        // two sizes differ by 16 points of thumbnail and 4 of padding —
        // rather than on the type, because a title that changes size with
        // the density of its list is a second type scale nobody declared.
        titleStyle: text.bodyMedium?.copyWith(
          color: palette.foreground,
          fontWeight: context.design.type.emphasisWeight,
        ),
        subtitleStyle: DSTextRole.itemSubtitle.styleOf(context),
        // Two, for the same reason `DSListTile`'s title takes two: the row's
        // title is the thing the reader came for, and one line cut "Quarterly
        // report" beside a picture and a menu at 320 points. The subtitle
        // drops to one line at `md` and disappears entirely at `compact` —
        // see the class doc for why.
        titleMaxLines: 2,
        subtitleMaxLines: compact ? 0 : 1,
        metaGap: space.sm,
        verticalPadding: padding,
        minHeight: extent + padding * 2,
        selectedColor: palette.secondary,
        pressedColor: palette.muted,
      ),
      own: own,
    );
  }
}

/// A list row led by a picture: thumbnail, title, a supporting line, a row of
/// small facts, and one optional action.
///
/// See `docs/plans/05-ds-media-list-card.plan.md`. It is not `DSListTile` with
/// a bigger leading widget: a picture changes the row's whole vertical rhythm
/// and brings its own radius, placeholder, error state and status overlay, and
/// needs a metadata row `DSListTile` has no slot for. Bolting all of that onto
/// the row component would give it four reasons to change.
///
/// The picture box is laid out **before any byte is fetched**, so a list
/// never reflows as pictures arrive — which is the single largest contributor
/// to whether a scrolling list feels stable.
///
/// Only the picture box changes between aspect ratios. The text column, the
/// gaps and the paddings are constant, so a list mixing 1:1 and 16:9 rows
/// still has one left edge for its titles.
class DSMediaRow extends StatefulWidget {
  const DSMediaRow({
    super.key,
    required this.title,
    this.source = const DSMediaSource.none(),
    this.aspect = DSMediaAspect.square,
    this.subtitle,
    this.meta = const [],
    this.trailing,
    this.overlay,
    this.footer,
    this.status = const DSMediaStatus(),
    this.menuItems = const [],
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.enabled = true,
    this.loading = false,
    this.size,
    this.style,
    this.mediaStyle,
    this.titleSlot,
    this.subtitleSlot,
  });

  final DSMediaSource source;
  final DSMediaAspect aspect;

  final String title;
  final String? subtitle;

  /// The fact row. `List<Widget>` and not `List<String>`, because these are a
  /// chip, a dot-and-label, a small bar and a timestamp in roughly equal
  /// measure — typing it to strings would force a `metaStyle` enum inside a
  /// month.
  final List<Widget> meta;

  /// One action, with its own target. Two actions in a row is the maximum;
  /// more than that is an overflow menu.
  final Widget? trailing;

  /// Painted over the picture box and clipped to its radius — a duration
  /// badge, a play glyph, a selection tick. Without it, every video list
  /// forks the component. Passed straight through to [DSMediaSurface].
  final Widget? overlay;

  /// Full width, below the row. The unanticipated-content hatch.
  final Widget? footer;

  final DSMediaStatus status;

  /// A long press opens this menu instead of calling [onLongPress]. See the
  /// constructor assertion.
  final List<DSMenuItem> menuItems;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// State, and therefore a property rather than a constructor: a component
  /// with a `.selected` constructor cannot animate into or out of selection.
  final bool selected;

  final bool enabled;
  final bool loading;
  final DSMediaSize? size;
  final DSMediaRowStyle? style;
  final DSMediaSurfaceStyle? mediaStyle;

  final Widget? titleSlot;
  final Widget? subtitleSlot;

  @override
  State<DSMediaRow> createState() => _DSMediaRowState();
}

class _DSMediaRowState extends State<DSMediaRow> {
  /// What the menu anchors to. The reason the row is a [StatefulWidget]
  /// where the old one was stateless.
  final GlobalKey _anchor = GlobalKey();

  // Not a constructor assert: `menuItems.isEmpty` is a `List` getter, and
  // Dart's constant evaluator cannot fold any `List` getter — not even
  // `.isEmpty` on a literal empty list — so a constructor assert here would
  // force `DSMediaRow` to give up `const`. Every other widget constructor in
  // this kit is const-constructible; this check moves to first build instead
  // of costing the row that.
  @override
  void initState() {
    super.initState();
    assert(
      widget.menuItems.isEmpty || widget.onLongPress == null,
      'An item cannot both open a menu and enter selection mode on one '
      'gesture. Pick the one the long press means.',
    );
  }

  String _sentence() {
    final buffer = StringBuffer(widget.title);
    if (widget.subtitle != null) buffer.write(', ${widget.subtitle}');
    if (widget.source.semanticLabel.isNotEmpty) {
      buffer.write(', ${widget.source.semanticLabel}');
    }
    for (final phrase in widget.status.semanticPhrases()) {
      buffer.write(', $phrase');
    }
    return buffer.toString();
  }

  Future<void> _openMenu(BuildContext context) async {
    AppHaptics.selection();
    await showDSMenu<void>(
      context: context,
      anchor: _anchor,
      items: widget.menuItems,
      semanticLabel: 'Actions for ${widget.title}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final space = context.design.space;
    final resolved = DSMediaRowStyle.resolve(
      context,
      widget.size,
      widget.style,
    );
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final mediaBox = widget.source.isEmpty
        ? null
        : DSMediaSurface(
            source: widget.source,
            aspect: widget.aspect,
            height: resolved.mediaExtent,
            status: widget.status,
            showRank: false,
            selected: widget.selected,
            enabled: widget.enabled,
            overlay: widget.overlay,
            style: widget.mediaStyle,
          );

    // How wide the text column will be, so the row can decide *before* laying
    // out whether the facts still fit beside the picture.
    final double mediaWidth = mediaBox == null
        ? 0
        : resolved.mediaExtent! * widget.aspect.ratio + resolved.mediaGap!;
    // The narrowest a title and a supporting line stay readable. Below it the
    // facts stop being a row of facts and start being three words each on
    // their own line — and at a raised text scale they overflowed the row
    // outright, which is what the probe measured on a 16:9 row at 320 points.
    final double readableColumn = space.xxxl * 3;

    // The column is at least as tall as the picture and centres itself in
    // that box, which is the whole of the row's cross-axis alignment:
    //
    //   * a short row — one title, one supporting line — is *shorter* than the
    //     picture, so the constraint holds the column open and the
    //     text sits on the picture's centre line, exactly as a centred `Row`
    //     used to put it;
    //   * a tall row — a headline over three lines — is taller, the
    //     constraint is already satisfied, and the picture stays at the top
    //     where the headline starts.
    //
    // A centred `Row` could only do the first. The blog's rows are 120 points
    // of text beside a 64-point picture, and centring floated the thumbnail
    // in the middle of the row with nothing beside its top or its bottom —
    // which is what reads as a row that has come apart. `IntrinsicHeight`
    // would answer the same question by laying the row out twice, on every
    // row of a list, which is the cost this component exists to avoid.
    Widget buildTextColumn({required bool showMeta}) => ConstrainedBox(
      constraints: BoxConstraints(minHeight: resolved.mediaExtent ?? 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child:
                    widget.titleSlot ??
                    Text(
                      widget.title,
                      style: resolved.titleStyle?.copyWith(
                        color: widget.enabled ? null : palette.mutedForeground,
                      ),
                      maxLines: resolved.titleMaxLines ?? 2,
                      overflow: TextOverflow.ellipsis,
                    ),
              ),
              // Unread is the one status that belongs to the item rather than
              // to its picture: it survives a thumbnail that never loads, so
              // it is drawn beside the title and spoken with it.
              if (widget.status.unread) ...[
                SizedBox(width: space.sm),
                dsMediaUnreadDot(context, enabled: widget.enabled),
              ],
            ],
          ),
          if ((resolved.subtitleMaxLines ?? 1) > 0 &&
              (widget.subtitleSlot != null || widget.subtitle != null)) ...[
            SizedBox(height: space.hairline),
            widget.subtitleSlot ??
                Text(
                  widget.subtitle!,
                  style: resolved.subtitleStyle?.copyWith(
                    color: widget.enabled ? null : palette.mutedForeground,
                  ),
                  maxLines: resolved.subtitleMaxLines ?? 1,
                  overflow: TextOverflow.ellipsis,
                ),
          ],
          if (widget.meta.isNotEmpty && showMeta) ...[
            SizedBox(height: resolved.metaGap ?? space.sm),
            Wrap(
              spacing: space.sm,
              runSpacing: space.xs,
              children: widget.meta,
            ),
          ],
        ],
      ),
    );

    Widget body = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Past this the meta facts have nowhere to go beside a fixed-width
        // picture, so they take the full width under the row instead of being
        // squeezed: at a raised text scale, or on a column too narrow to read
        // them in.
        final bool metaBelow =
            widget.meta.isNotEmpty &&
            (scale > 1.6 || constraints.maxWidth - mediaWidth < readableColumn);

        final Widget row = Row(
          // `start`, and the text column's own `minHeight` does the centring
          // — see `buildTextColumn`. A `center` here would put the picture on
          // the centre line of a column three times its height.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mediaBox != null) ...[
              mediaBox,
              SizedBox(width: resolved.mediaGap ?? space.md),
            ],
            Expanded(child: buildTextColumn(showMeta: !metaBelow)),
          ],
        );

        if (!metaBelow) return row;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            row,
            SizedBox(height: resolved.metaGap ?? space.sm),
            Wrap(
              spacing: space.sm,
              runSpacing: space.xs,
              children: widget.meta,
            ),
          ],
        );
      },
    );

    final padding = resolved.verticalPadding ?? space.sm;
    Widget row = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: (resolved.minHeight ?? context.design.component.minTapTarget)
            .clamp(context.design.component.minTapTarget, double.infinity),
      ),
      child: Padding(
        // The gutter is read here rather than left to the call site, the same
        // way `DSListTile` reads it: a row is full-bleed so its press and its
        // selection fill reach the edge of the screen, and its *content* is
        // still on the page's left edge. A caller that insets the row instead
        // gets a press target that stops short of the edge and a list that
        // does not line up with the tiles above it.
        padding: EdgeInsetsDirectional.only(
          start: space.pageGutter,
          end: space.pageGutter,
          top: padding,
          bottom: padding,
        ),
        child: body,
      ),
    );

    row = KeyedSubtree(key: _anchor, child: row);

    if (widget.onTap != null && widget.enabled && !widget.loading) {
      // A full-bleed row deliberately does not dip. A row that shrinks away
      // from its neighbours detaches from the column it belongs to; a row is
      // pressed by lighting up, which is the same call `DSListTile` documents.
      // The ring is not part of that trade: `enabled: false` drops the scale
      // and keeps it, where skipping `DSPressable` dropped both.
      row = DSPressable(
        enabled: false,
        focusShape: const RoundedRectangleBorder(),
        child: DSInkSurface(
          onTap: widget.onTap,
          onLongPress: widget.menuItems.isNotEmpty
              ? () => _openMenu(context)
              : widget.onLongPress,
          highlightColor: resolved.pressedColor ?? palette.muted,
          minTapTarget: false,
          child: row,
        ),
      );
    }

    if (widget.selected) {
      row = DecoratedBox(
        decoration: BoxDecoration(
          color: resolved.selectedColor ?? palette.secondary,
        ),
        child: row,
      );
    }

    final Widget node = Semantics(
      container: true,
      button: widget.onTap != null,
      selected: widget.selected,
      enabled: widget.enabled,
      label: _sentence(),
      // Declared here because the subtree below is excluded from semantics,
      // and a node that says "button" with no action is announced and cannot
      // be pressed.
      onTap: widget.enabled && !widget.loading ? widget.onTap : null,
      // So the menu is reachable without a long press.
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        for (final DSMenuItem item in widget.menuItems)
          if (item.onPressed != null)
            CustomSemanticsAction(label: item.label): item.onPressed!,
      },
      // The subtree stays excluded, which is now correct: nothing inside it
      // carries a label the sentence above has not already said — the media
      // box's own label is folded into `_sentence()` rather than discarded.
      child: ExcludeSemantics(child: row),
    );

    // The trailing action is a second node with its own target, separated so
    // a finger aiming at the row does not land on it. Selection paints on the
    // media and the fill, so this is `trailing` alone.
    final Widget? action = widget.trailing;

    Widget content = action == null
        ? node
        : Row(
            // Top-right, not middle-right. The action belongs to the row, and
            // the row's identity is its first line — a menu floating beside
            // the third line of a headline reads as belonging to that line.
            // The target is a `minTapTarget` box drawn from the row's top
            // edge, so its glyph centre lands within a point of the title's
            // first baseline at every size the kit ships.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: node),
              SizedBox(width: space.sm),
              ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: context.design.component.minTapTarget,
                  minHeight: context.design.component.minTapTarget,
                ),
                child: Center(child: action),
              ),
            ],
          );

    if (widget.footer != null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [content, widget.footer!],
      );
    }

    return DSSkeleton(enabled: widget.loading, child: content);
  }
}

/// One fact in the meta row — the intended occupant of [DSMediaRow.meta], and
/// a widget of its own so a caller composing one by hand gets the same
/// treatment.
// ds-tier: 1 — atom — A row's duration and its dot separators.
class DSMediaMeta extends StatelessWidget {
  const DSMediaMeta({
    super.key,
    this.label,
    this.icon,
    this.markColor,
    this.labelSlot,
  }) : assert(label != null || labelSlot != null || icon != null);

  final String? label;
  final IconData? icon;

  /// A category or semantic tone for the leading dot.
  final Color? markColor;

  final Widget? labelSlot;

  @override
  Widget build(BuildContext context) {
    final space = context.design.space;
    final palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (markColor != null) ...[
          SizedBox(
            width: space.sm - space.hairline,
            height: space.sm - space.hairline,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: markColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: space.xs),
        ],
        if (icon != null) ...[
          Icon(
            icon,
            size: context.design.component.iconSizeSmall,
            color: palette.mutedForeground,
          ),
          SizedBox(width: space.xs),
        ],
        if (labelSlot != null)
          labelSlot!
        else if (label != null)
          Text(label!, style: DSTextRole.caption.styleOf(context)),
      ],
    );
  }
}

/// A row-shaped skeleton, built from the slots the real row will have.
///
/// Shaped by what was passed rather than a fixed silhouette: a list of rows
/// with no subtitle should not shimmer a subtitle it is never going to show.
class DSMediaRowSkeleton extends StatelessWidget {
  const DSMediaRowSkeleton({
    super.key,
    this.showMedia = true,
    this.showSubtitle = true,
    this.metaCount = 0,
    this.size,
  });

  final bool showMedia;
  final bool showSubtitle;
  final int metaCount;
  final DSMediaSize? size;

  @override
  Widget build(BuildContext context) => DSMediaRow(
    source: showMedia
        ? const DSMediaSource.widget(SizedBox.expand(), semanticLabel: '')
        : const DSMediaSource.none(),
    title: 'Placeholder headline',
    subtitle: showSubtitle ? 'Secondary line of placeholder copy' : null,
    meta: [
      for (var i = 0; i < metaCount; i++) const DSMediaMeta(label: 'Fact'),
    ],
    size: size,
    loading: true,
  );
}
