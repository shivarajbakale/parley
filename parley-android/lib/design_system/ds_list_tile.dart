// ds-tier: 2 — molecule

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_divider.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_skeleton.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/app_platform.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// What a row's selection means to a screen reader.
///
/// Three values rather than a `selected` boolean alone, because the modes
/// differ in their semantics contract and not in their paint: a row in a
/// single-select group is announced "2 of 5" only if it declares itself part
/// of a mutually exclusive group, and nothing about the fill can say that.
enum DSSelectionMode {
  /// The row is not part of a selection. It may still navigate.
  none,

  /// One row of the group is chosen at a time — `inMutuallyExclusiveGroup`.
  single,

  /// Any number of rows may be chosen.
  multiple,
}

/// [DSListTile]'s appearance, as data.
///
/// Every default in [resolve] comes from [ComponentSpec] rather than from a
/// constant, and that is the whole point of this class: the identity layer
/// already declared `leadingStyle`, `wellSize`, `wellShape`, `dividerPolicy`
/// and `rowChevron`, and the widget was not reading any of them. A seam no
/// widget reads is decoration.
///
/// There is deliberately no `horizontalPadding` and no `minHeight`. The first
/// would make the row a second owner of the page gutter, which is
/// `SpaceSpec.listItemPadding`'s job; the second would let a call site lower
/// the row under [ListTile]'s own minimum, which is the trap [DSListTile]'s
/// class comment describes.
@immutable
class DSListTileStyle extends DSComponentStyle<DSListTileStyle> {
  const DSListTileStyle({
    this.leadingStyle,
    this.leadingSize,
    this.leadingShape,
    this.leadingGap,
    this.titleStyle,
    this.subtitleStyle,
    this.subtitleMaxLines,
    this.verticalPadding,
    this.dividerPolicy,
    this.dividerColor,
    this.selectedColor,
    this.chevron,
    this.chevronIcon,
  }) : assert(
         subtitleMaxLines == null ||
             (subtitleMaxLines > 0 && subtitleMaxLines <= 2),
         'subtitleMaxLines must be 1 or 2. Supporting text is capped at two '
         'lines in both Material 3 and the Apple HIG because the third line '
         'is where a row stops being scannable — a list whose rows are five '
         'lines tall is a list nobody reads to the bottom of. Copy that '
         'genuinely needs more room belongs in the destination, or in the '
         '`meta` slot as a summary.',
       );

  /// Whether the leading slot gets a tinted well, the glyph alone, or nothing.
  final LeadingStyle? leadingStyle;

  final double? leadingSize;

  /// The shape role the well takes. The default is [ComponentSpec.wellShape],
  /// so an identity that squares its controls off gets square wells for free —
  /// which the hardcoded `CircleAvatar` this replaces made impossible.
  final AppShape? leadingShape;

  final double? leadingGap;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  /// Capped at 2 by the constructor assertion above.
  final int? subtitleMaxLines;

  final double? verticalPadding;

  /// Whether a row draws a separator, and how far it is inset.
  /// [DSListTileGroup] is what applies it to every row but the last.
  final DividerPolicy? dividerPolicy;

  final Color? dividerColor;

  /// The fill behind a selected row. Never the only signal — see §7 of
  /// `docs/plans/12-ds-list-tile.plan.md` and the check drawn beside it.
  final Color? selectedColor;

  final bool? chevron;
  final IconData? chevronIcon;

  @override
  DSListTileStyle merge(DSListTileStyle? other) {
    if (other == null) return this;
    return DSListTileStyle(
      leadingStyle: other.leadingStyle ?? leadingStyle,
      leadingSize: other.leadingSize ?? leadingSize,
      leadingShape: other.leadingShape ?? leadingShape,
      leadingGap: other.leadingGap ?? leadingGap,
      titleStyle: other.titleStyle ?? titleStyle,
      subtitleStyle: other.subtitleStyle ?? subtitleStyle,
      subtitleMaxLines: other.subtitleMaxLines ?? subtitleMaxLines,
      verticalPadding: other.verticalPadding ?? verticalPadding,
      dividerPolicy: other.dividerPolicy ?? dividerPolicy,
      dividerColor: other.dividerColor ?? dividerColor,
      selectedColor: other.selectedColor ?? selectedColor,
      chevron: other.chevron ?? chevron,
      chevronIcon: other.chevronIcon ?? chevronIcon,
    );
  }

  @override
  DSListTileStyle copyWith({
    LeadingStyle? leadingStyle,
    double? leadingSize,
    AppShape? leadingShape,
    double? leadingGap,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
    int? subtitleMaxLines,
    double? verticalPadding,
    DividerPolicy? dividerPolicy,
    Color? dividerColor,
    Color? selectedColor,
    bool? chevron,
    IconData? chevronIcon,
  }) => DSListTileStyle(
    leadingStyle: leadingStyle ?? this.leadingStyle,
    leadingSize: leadingSize ?? this.leadingSize,
    leadingShape: leadingShape ?? this.leadingShape,
    leadingGap: leadingGap ?? this.leadingGap,
    titleStyle: titleStyle ?? this.titleStyle,
    subtitleStyle: subtitleStyle ?? this.subtitleStyle,
    subtitleMaxLines: subtitleMaxLines ?? this.subtitleMaxLines,
    verticalPadding: verticalPadding ?? this.verticalPadding,
    dividerPolicy: dividerPolicy ?? this.dividerPolicy,
    dividerColor: dividerColor ?? this.dividerColor,
    selectedColor: selectedColor ?? this.selectedColor,
    chevron: chevron ?? this.chevron,
    chevronIcon: chevronIcon ?? this.chevronIcon,
  );

  @override
  DSListTileStyle lerp(DSListTileStyle? other, double t) {
    if (other == null) return this;
    return DSListTileStyle(
      // Five enum-or-flag fields with no midpoint. They switch at the halfway
      // mark rather than pretending to interpolate.
      leadingStyle: t < 0.5 ? leadingStyle : other.leadingStyle,
      leadingShape: t < 0.5 ? leadingShape : other.leadingShape,
      subtitleMaxLines: t < 0.5 ? subtitleMaxLines : other.subtitleMaxLines,
      dividerPolicy: t < 0.5 ? dividerPolicy : other.dividerPolicy,
      chevron: t < 0.5 ? chevron : other.chevron,
      chevronIcon: t < 0.5 ? chevronIcon : other.chevronIcon,
      leadingSize: lerpDouble(leadingSize, other.leadingSize, t),
      leadingGap: lerpDouble(leadingGap, other.leadingGap, t),
      titleStyle: TextStyle.lerp(titleStyle, other.titleStyle, t),
      subtitleStyle: TextStyle.lerp(subtitleStyle, other.subtitleStyle, t),
      verticalPadding: lerpDouble(verticalPadding, other.verticalPadding, t),
      dividerColor: Color.lerp(dividerColor, other.dividerColor, t),
      selectedColor: Color.lerp(selectedColor, other.selectedColor, t),
    );
  }

  /// The four layers, with the spec as layer 1.
  ///
  /// [tone] reaches the title because a tone that moved only the glyph would
  /// be colour standing alone on the one element the user reads.
  static DSListTileStyle resolve(
    BuildContext context,
    DSTone tone, [
    DSListTileStyle? own,
  ]) {
    final design = context.design;
    final component = design.component;
    final space = design.space;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    // `swatch.color` is the palette's graphical grade: gate K4 holds it at
    // 3:1 against `surface`, and it measures 4.58–5.13:1 there in both
    // themes, so it is legible as text on a row. On `canvas` the lightest of
    // the four (success, light) measures 3.82:1, under the 4.5 body floor —
    // raising it is plan 00's business, not this widget's, and the widget
    // test asserts both figures so the debt is visible rather than assumed.
    final titleColor = switch (tone) {
      DSTone.neutral => palette.foreground,
      DSTone.info => palette.primary,
      DSTone.success => palette.success,
      DSTone.warning => palette.warning,
      DSTone.error => palette.destructive,
    };

    return resolveStyle(
      context: context,
      specDefaults: DSListTileStyle(
        leadingStyle: component.leadingStyle,
        leadingSize: component.listRowMinHeight * component.rowWellRatio,
        leadingShape: component.wellShape,
        leadingGap: space.lg,
        titleStyle: text.bodyLarge?.copyWith(color: titleColor),
        subtitleStyle: DSTextRole.itemSubtitle.styleOf(context),
        subtitleMaxLines: 2,
        verticalPadding: space.md,
        dividerPolicy: component.dividerPolicy,
        dividerColor: palette.borderSoft,
        selectedColor: palette.secondary,
        chevron: component.rowChevron,
        chevronIcon: chevronIconFor(context),
      ),
      scope: null,
      own: own,
    );
  }

  /// The fill and the glyph colour a [tone] gives the leading well.
  ///
  /// A record rather than two style fields: the pair is only ever read
  /// together, and splitting it lets a consumer set one half and end up with
  /// an error glyph on a success well.
  static (Color fill, Color glyph) wellColors(
    BuildContext context,
    DSTone tone,
  ) {
    final palette = context.palette;
    return switch (tone) {
      DSTone.neutral => (palette.secondary, palette.secondaryForeground),
      DSTone.info => (palette.tint(palette.primary), palette.primary),
      DSTone.success => (palette.tint(palette.success), palette.success),
      DSTone.warning => (palette.tint(palette.warning), palette.warning),
      DSTone.error => (palette.tint(palette.destructive), palette.destructive),
    };
  }
}

/// The app's standard list row — a themed [ListTile].
///
/// See `docs/plans/12-ds-list-tile.plan.md`. Deliberately thin: [ListTile]
/// already handles the touch target, the ink splash, text-scale growth, and
/// the semantics. What this adds is the app's list rhythm:
///
///   * full-bleed rows insetting only to the page gutter, so a list reads as
///     one column of content rather than a stack of floating boxes;
///   * a tinted well behind a bare [Icon] leading widget, in the shape the
///     identity chose — not a hardcoded circle;
///   * single-line title and a two-line cap on the subtitle — a row that
///     wraps doubles the height of every screen it appears on;
///   * the platform's press feedback: an ink splash on Android, a highlight on
///     Apple, where a splash spreading out from the finger is a Material
///     gesture nothing on iOS does.
///
/// The `minTileHeight` this row passes is `ComponentSpec.listRowMinHeight`,
/// less the whole vertical padding [ListTile] adds on top of its own minimum
/// — see the two owners of it in `build`. It used to pass nothing, on the
/// reasoning that Material's minimum already
/// clears either platform's tap floor and that handing it
/// `ComponentSpec.minTapTarget` would *lower* every row by eight points in
/// the name of accessibility. That is true of the tap floor, and the tap
/// floor is the wrong number: the kit already declares what a row *is*, and
/// no row read it. So Material's `_defaultTileHeight` owned the height — 56
/// for one line, 72 for two — with the kit's padding added on top, and the
/// probe measured settings rows at 64pt around a 19pt line while
/// [DSListTileSkeleton], built from the same tokens by hand, drew 56. The
/// spec's number is the rendered height now, and `row-air` fails the
/// difference.
///
/// Rows deliberately do **not** take the press dip that `DSPressable` gives
/// buttons and cards. A full-bleed row shrinking away from its neighbours
/// detaches it from the column it belongs to; a row is pressed by lighting up,
/// which is what both platforms do.
///
/// **Use when** the row is text-led. **Instead:** an image-led row is a
/// `DSMediaRow` — a 64dp picture is a different vertical rhythm. A row
/// that is a figure is a `DSStatTile`. A row that is a setting is
/// `DSSettings`, which owns the grouping and the dividers.
class DSListTile extends StatefulWidget implements DSLeadingRow {
  const DSListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.meta,
    this.background,
    this.onTap,
    this.onLongPress,
    this.tone = DSTone.neutral,
    this.selected = false,
    this.selectionMode = DSSelectionMode.none,
    this.enabled = true,
    this.loading = false,
    this.wrap = false,
    this.divider = false,
    this.style,
    this.titleSlot,
    this.subtitleSlot,
    @Deprecated(
      'destructive is now tone: DSTone.error — the same value, expressible '
      'alongside four others. Removed in the next release.',
    )
    this.destructive = false,
  });

  /// Leading widget. A bare [Icon] is wrapped in a [DSListTileWell]; anything
  /// else (an avatar, a checkbox, a flag, a drag handle) is used as given.
  final Widget? leading;

  final String title;
  final String? subtitle;

  /// A switch, a badge, a value, a menu. Replaces the chevron.
  final Widget? trailing;

  /// Below the subtitle, in the text column — a chip row, a small bar, a
  /// timestamp. Without it, callers put this in `subtitle` and lose the
  /// two-line cap that keeps a list scannable.
  final Widget? meta;

  /// Painted behind the row, clipped to its bounds, under the press feedback
  /// — a per-row tint, a progress fill for a downloading row.
  final Widget? background;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Meaning, not colour. Replaces the old `destructive` boolean, which was
  /// the one tone in the kit hardcoded into a widget and could not express a
  /// warning row or a success row.
  final DSTone tone;

  final bool selected;

  /// What the selection means to a screen reader. [DSSelectionMode.single]
  /// adds `inMutuallyExclusiveGroup`, so both platforms announce "2 of 5".
  final DSSelectionMode selectionMode;

  final bool enabled;

  /// Draws the row's shape in [DSSkeleton] bones instead of its content.
  final bool loading;

  /// Allow the title and subtitle to wrap. Off by default — reach for it only
  /// when the copy genuinely can't be shortened.
  final bool wrap;

  /// Whether this row draws a separator under itself, in the inset the
  /// identity's [DividerPolicy] chose.
  ///
  /// Off by default and set by [DSListTileGroup] rather than by the row,
  /// because only the list knows which row is last, and a hairline hanging
  /// under the final row of a group is the classic hand-rolled-list tell.
  final bool divider;

  final DSListTileStyle? style;
  final Widget? titleSlot;
  final Widget? subtitleSlot;

  @Deprecated('Use tone: DSTone.error.')
  final bool destructive;

  /// The tone this row actually paints, honouring the deprecated boolean and
  /// the scope a container may have set.
  DSTone effectiveTone(BuildContext context) {
    // ignore: deprecated_member_use_from_same_package
    if (destructive) return DSTone.error;
    if (tone != DSTone.neutral) return tone;
    return DSScope.toneOf(context) ?? DSTone.neutral;
  }

  /// Where a row's text starts: the gutter it still owes, plus the well and
  /// its gap only when the row has a leading glyph.
  static double textInset(
    BuildContext context, {
    required bool leading,
    DSListTileStyle? style,
  }) {
    final gutter = DSGutterScope.applied(context)
        ? 0.0
        : context.design.space.pageGutter;
    if (!leading) return gutter;
    final resolved = DSListTileStyle.resolve(context, DSTone.neutral, style);
    return gutter + resolved.leadingSize! + resolved.leadingGap!;
  }

  @override
  bool leadsWith(BuildContext context) =>
      leading != null &&
      DSListTileStyle.resolve(
            context,
            effectiveTone(context),
            style,
          ).leadingStyle !=
          LeadingStyle.none;

  @override
  State<DSListTile> createState() => _DSListTileState();
}

class _DSListTileState extends State<DSListTile> {
  @override
  void didUpdateWidget(covariant DSListTile old) {
    super.didUpdateWidget(old);
    // The selection changed under the user's finger, so it gets the selection
    // haptic. A navigation tap gets none: the route transition is already the
    // feedback, and a buzz on every row of a settings screen is noise.
    if (old.selected != widget.selected &&
        widget.selectionMode != DSSelectionMode.none) {
      AppHaptics.selection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = widget.effectiveTone(context);
    final resolved = DSListTileStyle.resolve(context, tone, widget.style);
    final design = context.design;
    final space = design.space;
    final enabled =
        widget.enabled &&
        (DSScope.enabledOf(context) ?? true) &&
        !widget.loading;

    if (widget.loading) {
      return DSListTileSkeleton(
        showLeading: widget.leading != null,
        showSubtitle: widget.subtitle != null || widget.subtitleSlot != null,
        showTrailing: widget.trailing != null,
        style: widget.style,
      );
    }

    // Above 1.6× the trailing moves under the text and the chevron is
    // dropped: a chevron beside 2× type is four per cent of the row's area,
    // and a switch beside it leaves the title two characters wide.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.6;
    final selectable = widget.selectionMode != DSSelectionMode.none;
    final trailing = _trailing(context, resolved, stacked, selectable);

    // The row's own padding, and the floor that has to account for it.
    //
    // `ListTile` has two vertical padding owners — `contentPadding` and
    // `minVerticalPadding` — and adds both *on top of* whichever is larger of
    // its minimum and its content. So a floor handed to it straight renders
    // that much taller than the number says. Splitting `verticalPadding`
    // across the two and subtracting the whole of it here is what makes
    // `listRowMinHeight` mean the height that is drawn, and it leaves the row
    // with exactly one padding budget rather than two.
    final double padding = resolved.verticalPadding! * 2;
    final double floor = design.component.listRowMinHeight;

    final tile = ListTile(
      // The gutter still owing, not the gutter itself.
      //
      // A row has to work as the direct child of a scroll view with no gutter
      // above it, so it applies the page's inset itself. Put the same row
      // inside a `DSPageSection` and both insets applied: on a 390pt phone the
      // icons drew at 40pt and the switches stopped at 350pt while the
      // section's own label sat at 20pt and the paragraph under it ran to
      // 370pt, so every row on the page looked narrower than the page it was
      // on. `DSGutter.pending` is zero when a container above has already
      // done this.
      contentPadding: EdgeInsets.symmetric(
        horizontal: (DSGutterScope.applied(context) ? 0.0 : space.pageGutter),
        vertical: resolved.verticalPadding! - space.xs,
      ),
      // The kit's number, not Material's. `_defaultTileHeight` is 56 for one
      // line and 72 for two, and with the padding above it rendered rows at
      // 64 and 80 — around 19pt of text. `listRowMinHeight` had said 56 since
      // the spec was written and no row had ever read it, which is why
      // `DSListTileSkeleton` and the row it stands in for were eight points
      // apart. Clamped at zero so an identity that sets a floor smaller than
      // its own padding gets a row sized by its content rather than an
      // assertion.
      minTileHeight: math.max(0, floor - padding),
      // The other half of the budget above, named rather than inherited:
      // Material's default here is 4, and a row whose height is derived from
      // a number the kit cannot see is the defect this whole change is about.
      // Zeroing it is not the answer — the tap targets inside a row collapse
      // with it, which the probe reports as 44pt controls under a 48pt floor.
      minVerticalPadding: space.xs,
      horizontalTitleGap: resolved.leadingGap,
      enabled: enabled,
      leading: _leading(context, resolved, tone),
      title: widget.titleSlot ?? _title(resolved),
      subtitle: _subtitle(context, resolved, stacked, trailing),
      trailing: stacked ? null : trailing,
      selected: widget.selected,
      // ListTile recolours its title and icons when `selected`; the tone
      // already decided that colour, so it is pinned rather than overridden.
      selectedColor: resolved.titleStyle?.color,
      onTap: enabled ? widget.onTap : null,
      onLongPress: enabled ? widget.onLongPress : null,
    );

    return Semantics(
      selected: selectable ? widget.selected : null,
      inMutuallyExclusiveGroup: widget.selectionMode == DSSelectionMode.single
          ? true
          : null,
      child: _decorate(context, resolved, _platformPress(context, tile)),
    );
  }

  /// An ink splash radiating from the touch point is a Material signature. On
  /// Apple the row highlights and releases, so the splash is switched off and
  /// the highlight the theme already sets does the work.
  Widget _platformPress(BuildContext context, Widget tile) {
    if (!AppPlatform.isApple(context)) return tile;
    return Theme(
      data: Theme.of(context).copyWith(splashFactory: NoSplash.splashFactory),
      child: tile,
    );
  }

  /// The selected fill, the background slot and the divider, outermost last.
  Widget _decorate(
    BuildContext context,
    DSListTileStyle resolved,
    Widget tile,
  ) {
    final motion = context.design.motion;
    final reduced = MediaQuery.disableAnimationsOf(context);

    // A [Material] rather than a coloured box: ListTile paints its ink on the
    // nearest Material ancestor, and a DecoratedBox between the two hides the
    // splash — Flutter asserts on exactly that. Material also cross-fades its
    // own colour over `animationDuration`, which is the selection transition
    // the plan asks for, for free.
    Widget row = Material(
      color: widget.selected ? resolved.selectedColor! : Colors.transparent,
      animationDuration: reduced ? Duration.zero : motion.scaled(motion.fast),
      child: tile,
    );

    if (widget.background != null) {
      // Under the press feedback, which lives in the ListTile's own Material.
      row = Stack(
        children: [
          Positioned.fill(child: ClipRect(child: widget.background!)),
          row,
        ],
      );
    }

    final policy = resolved.dividerPolicy!;
    if (!widget.divider || policy == DividerPolicy.none) return row;

    final space = context.design.space;
    // Inset to where the text starts, so the leading element reads as
    // belonging to its row rather than to the list — and only past a well
    // when there is one. The rule used to add the well and its gap
    // unconditionally, so a row with no glyph started its hairline a whole
    // well to the right of its own first letter.
    final gutter = DSListTile.textInset(context, leading: false);
    final indent = policy == DividerPolicy.inset
        ? DSListTile.textInset(
            context,
            leading: widget.leadsWith(context),
            style: widget.style,
          )
        : gutter;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        DSDivider(
          indent: indent,
          endIndent: gutter,
          style: DSDividerStyle(
            thickness: space.hairline,
            color: resolved.dividerColor,
          ),
        ),
      ],
    );
  }

  Widget _title(DSListTileStyle resolved) => Text(
    widget.title,
    style: resolved.titleStyle,
    // Two, not one. A row title is content, and the probe's `clipped-text`
    // rule is right about it: a label may be truncated, the words the reader
    // came for may not. One line cut "Sign out of every device" and "Notify me
    // about replies" at 320pt and a 1.3x text scale, which is a phone somebody
    // owns. Two is still a cap — `wrap` remains the way to say a title has no
    // cap at all — so a row grows by one line at the narrow end rather than
    // becoming unbounded.
    maxLines: widget.wrap ? null : 2,
    overflow: widget.wrap ? null : TextOverflow.ellipsis,
  );

  Widget? _leading(
    BuildContext context,
    DSListTileStyle resolved,
    DSTone tone,
  ) {
    final child = widget.leading;
    if (child == null || resolved.leadingStyle == LeadingStyle.none) {
      return null;
    }
    if (child is! Icon || resolved.leadingStyle == LeadingStyle.bare) {
      // A DSWell placed here sizes to the row, like the built-in well does.
      return DSRowLeadingScope(extent: resolved.leadingSize!, child: child);
    }
    return DSListTileWell(tone: tone, style: widget.style, child: child);
  }

  /// The text column below the title: the subtitle, then `meta`, then — only
  /// at large text scales — the trailing control.
  Widget? _subtitle(
    BuildContext context,
    DSListTileStyle resolved,
    bool stacked,
    Widget? trailing,
  ) {
    final space = context.design.space;
    final text =
        widget.subtitleSlot ??
        (widget.subtitle == null
            ? null
            : Text(
                widget.subtitle!,
                style: resolved.subtitleStyle,
                maxLines: widget.wrap ? null : resolved.subtitleMaxLines,
                overflow: widget.wrap ? null : TextOverflow.ellipsis,
              ));
    final below = <Widget>[
      if (text != null) text,
      if (widget.meta != null) ...[SizedBox(height: space.xs), widget.meta!],
      if (stacked && trailing != null) ...[
        SizedBox(height: space.sm),
        Align(alignment: AlignmentDirectional.centerStart, child: trailing),
      ],
    ];
    if (below.isEmpty) return null;
    if (below.length == 1) return below.single;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: below,
    );
  }

  /// The caller's control, the selection indicator, or the chevron — in that
  /// order, and never two of them.
  Widget? _trailing(
    BuildContext context,
    DSListTileStyle resolved,
    bool stacked,
    bool selectable,
  ) {
    if (widget.trailing != null) return widget.trailing;
    if (selectable) return _selectionIndicator(context, resolved);
    if (widget.onTap == null || !(resolved.chevron ?? true) || stacked) {
      return null;
    }
    // The row states the colour rather than leaving it to the ambient icon
    // theme: inside a Material row that theme is the framework's default, and
    // a chevron at full text colour reads as a control rather than as a mark.
    return DSChevron(
      icon: resolved.chevronIcon,
      color: context.palette.mutedForeground,
    );
  }

  /// Fill *and* check — a fill alone would be colour standing on its own,
  /// which SC 1.4.1 forbids and which no greyscale screenshot survives.
  Widget _selectionIndicator(BuildContext context, DSListTileStyle resolved) {
    final design = context.design;
    final motion = design.motion;
    final palette = context.palette;
    final single = widget.selectionMode == DSSelectionMode.single;
    final icon = widget.selected
        ? (single ? Icons.radio_button_checked : Icons.check_circle)
        : (single ? Icons.radio_button_unchecked : Icons.circle_outlined);

    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : motion.scaled(motion.fast),
      switchInCurve: motion.emphasize,
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: Icon(
        icon,
        key: ValueKey(icon),
        size: design.component.iconSize,
        color: widget.selected ? palette.primary : palette.border,
      ),
    );
  }
}

/// The tinted frame behind a list row's leading glyph.
///
/// A component rather than a private helper, because the frame is what
/// connects three [ComponentSpec] fields — `wellSize`, `wellShape` and
/// `leadingStyle` — that the `CircleAvatar` this replaces read none of. An
/// identity that sets `wellShape: AppShape.card` used to get a circle anyway.
// ds-tier: 1 — atom — The row's leading disc. A shape and a glyph.
class DSListTileWell extends StatelessWidget {
  const DSListTileWell({
    super.key,
    required this.child,
    this.color,
    this.tone = DSTone.neutral,
    this.style,
  });

  final Widget child;

  /// Overrides the tone's fill. The glyph colour follows the fill's `on`
  /// pair, so this is the one knob rather than two that can disagree.
  final Color? color;

  final DSTone tone;
  final DSListTileStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = DSListTileStyle.resolve(context, tone, style);
    final (fill, glyph) = DSListTileStyle.wellColors(context, tone);
    final size = resolved.leadingSize!;

    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: color ?? fill,
          shape: context.shapeOf(resolved.leadingShape!),
        ),
        child: Center(
          child: IconTheme.merge(
            data: IconThemeData(
              color: glyph,
              size: size * context.design.component.rowWellGlyphRatio,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The intended occupant of [DSListTile.meta] — a timestamp, a count, a
/// status word, small and quiet under the subtitle.
// ds-tier: 1 — atom — A trailing value and its caption. Two lines of text.
class DSListTileMeta extends StatelessWidget {
  const DSListTileMeta({
    super.key,
    this.label,
    this.icon,
    this.labelSlot,
    this.tone = DSTone.neutral,
  }) : assert(
         label != null || labelSlot != null,
         'DSListTileMeta needs a label or a labelSlot; an icon on its own is '
         'a glyph with no accessible name.',
       );

  final String? label;
  final IconData? icon;
  final Widget? labelSlot;
  final DSTone tone;

  @override
  Widget build(BuildContext context) {
    final space = context.design.space;
    final palette = context.palette;
    final color = tone == DSTone.neutral
        ? palette.mutedForeground
        : DSListTileStyle.resolve(context, tone).titleStyle?.color;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: context.design.component.iconSizeSmall,
            color: color,
          ),
          SizedBox(width: space.xs),
        ],
        labelSlot ??
            Text(
              label!,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: color),
            ),
      ],
    );
  }
}

/// The loading shape of a row, derived from the slots it would have had.
///
/// A skeleton that does not match the row it becomes is a layout jump, which
/// is the defect a skeleton exists to prevent — so it is built from the same
/// spec values and the same padding as [DSListTile].
class DSListTileSkeleton extends StatelessWidget {
  const DSListTileSkeleton({
    super.key,
    this.showLeading = true,
    this.showSubtitle = true,
    this.showTrailing = false,
    this.style,
  });

  final bool showLeading;
  final bool showSubtitle;
  final bool showTrailing;
  final DSListTileStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = DSListTileStyle.resolve(context, DSTone.neutral, style);
    final design = context.design;
    final space = design.space;
    final palette = context.palette;

    Widget bone(double width, double height) => DecoratedBox(
      decoration: ShapeDecoration(
        color: palette.muted,
        shape: context.shapeOf(AppShape.control),
      ),
      child: SizedBox(width: width, height: height),
    );

    return DSSkeleton(
      child: ExcludeSemantics(
        child: Padding(
          // The same pending gutter the row itself reads, so the skeleton and
          // the row it stands in for start at one edge.
          padding: EdgeInsets.symmetric(
            horizontal: (DSGutterScope.applied(context)
                ? 0.0
                : space.pageGutter),
            vertical: resolved.verticalPadding! + space.xs,
          ),
          child: Row(
            children: [
              if (showLeading) ...[
                bone(resolved.leadingSize!, resolved.leadingSize!),
                SizedBox(width: resolved.leadingGap!),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    bone(double.infinity, space.md),
                    if (showSubtitle) ...[
                      SizedBox(height: space.sm),
                      FractionallySizedBox(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: 0.6,
                        child: bone(double.infinity, space.md - space.hairline),
                      ),
                    ],
                  ],
                ),
              ),
              if (showTrailing) ...[
                SizedBox(width: space.md),
                bone(design.component.iconSize, design.component.iconSize),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A run of rows separated by the identity's [DividerPolicy].
///
/// The row cannot decide this for itself: only the list knows which row is
/// last, and a hairline hanging under the final row is what makes a
/// hand-rolled list look hand-rolled. This is also the only place the policy
/// can be honoured without every call site repeating it.
///
/// Not a [ListView]. A group is a fixed set of rows inside a scrollable that
/// already exists — a settings block, a section of a detail page. A long list
/// is a `ListView.builder` of [DSListTile]s, where the same effect is a
/// `separatorBuilder`.
class DSListTileGroup extends StatelessWidget {
  const DSListTileGroup({super.key, required this.children, this.style});

  final List<DSListTile> children;
  final DSListTileStyle? style;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < children.length; i++)
        _withDivider(children[i], i < children.length - 1),
    ],
  );

  DSListTile _withDivider(DSListTile row, bool divider) => DSListTile(
    key: row.key,
    leading: row.leading,
    title: row.title,
    subtitle: row.subtitle,
    trailing: row.trailing,
    meta: row.meta,
    background: row.background,
    onTap: row.onTap,
    onLongPress: row.onLongPress,
    tone: row.tone,
    selected: row.selected,
    selectionMode: row.selectionMode,
    enabled: row.enabled,
    loading: row.loading,
    wrap: row.wrap,
    divider: divider,
    style: row.style ?? style,
    titleSlot: row.titleSlot,
    subtitleSlot: row.subtitleSlot,
  );
}

/// The trailing mark on a row that goes somewhere.
///
/// Trivial, and it ships because four components drew one at four sizes
/// (`docs/plans/31-ds-compositions.plan.md`). It takes no `Color`: the colour
/// comes from the ambient [IconTheme] when there is one and from the row's own
/// tertiary text otherwise, so a chevron in a destructive row is red because
/// the row said so, not because the call site typed it.
///
/// It is excluded from semantics. "Button" already implies a destination;
/// announcing "chevron" on every row of a settings screen is noise.
// ds-tier: 1 — atom — A glyph that says the row leads somewhere. It draws an icon and nothing else.
class DSChevron extends StatelessWidget {
  const DSChevron({super.key, this.icon, this.size, this.color});

  final IconData? icon;
  final double? size;

  /// Overrides the inherited colour, for a chevron drawn outside a row.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final inherited = IconTheme.of(context).color;
    final glyph = icon ?? chevronIconFor(context);
    final extent = size ?? context.design.component.iconSizeSmall;
    // Outward, by the empty space the glyph carries inside its box, so the
    // chevron's point lines up with the switches and values in the same
    // column. Paint-only: the row's layout and tap target do not move.
    final bearing = switch (glyph) {
      Icons.chevron_right => extent * _chevronSideBearing,
      Icons.chevron_left => -extent * _chevronSideBearing,
      _ => 0.0,
    };
    return ExcludeSemantics(
      child: Transform.translate(
        offset: Offset(bearing, 0),
        child: Icon(
          glyph,
          size: extent,
          color: color ?? inherited ?? context.palette.mutedForeground,
        ),
      ),
    );
  }
}

/// `chevron_right`'s path ends at x=16 of its 24-unit box.
const double _chevronSideBearing = 8 / 24;

/// A row a group separates. It says whether it opens with a leading glyph, so
/// the group can start its rule where the row's text starts.
abstract interface class DSLeadingRow {
  bool leadsWith(BuildContext context);
}

/// The chevron that points the way a row opens.
///
/// A chevron is one of the few glyphs that carries a direction rather than
/// depicting a thing, so it is the one that has to flip: under RTL a
/// `chevron_right` at the end of a row points back the way the reader came.
/// See `docs/principles/direction.md`.
IconData chevronIconFor(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl
    ? Icons.chevron_left
    : Icons.chevron_right;

/// A ready-made skeleton for list screens: [itemCount] rows in the same
/// [DSListTile] shape the loaded list uses. The default drop-in for
/// `AsyncValue.loading` on list screens.
class DSSkeletonList extends StatelessWidget {
  final int itemCount;

  /// Null takes the spec's `sm` step on the vertical axis. A `const` default
  /// could only be a hand-typed number, which is the one thing a padding on
  /// this layer may not be.
  final EdgeInsetsGeometry? padding;

  /// Set true when hosting inside another scroll view (e.g. a
  /// `SliverToBoxAdapter`), so the list sizes to its rows instead of expanding.
  final bool shrinkWrap;

  const DSSkeletonList({
    super.key,
    this.itemCount = 6,
    this.padding,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    // `DSListTileSkeleton` rather than a `DSListTile` full of placeholder
    // copy: the bones are built from the same spec values as the real row, so
    // the list does not jump when the data lands — which is the whole reason
    // a skeleton is drawn instead of a spinner.
    return ListView.builder(
      padding:
          padding ?? EdgeInsets.symmetric(vertical: context.design.space.sm),
      shrinkWrap: shrinkWrap,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => const DSListTileSkeleton(),
    );
  }
}
