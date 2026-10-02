// ds-tier: 2 — molecule

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_divider.dart';
import 'package:parley_android/design_system/ds_pressable.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_skeleton.dart';
import 'package:parley_android/theme/app_typography.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Which way a figure moved. There is no `flat`: a 0% delta rendered in grey
/// is a row of pixels that says nothing, so a tile with no movement worth
/// reporting passes no trend at all.
enum DSTrend { up, down }

/// The two designed scales of [DSStatTile].
///
/// A *paired* scale, in the sense of `docs/plans/00a-component-contract.plan.md`
/// section 6: the type step, the gaps, the mark diameter and the well all move
/// together, because a tile with a headline value and a 32dp well is not a
/// smaller tile, it is a differently proportioned one.
enum DSStatTileSize { md, compact }

/// [DSStatTile]'s appearance, as data.
///
/// Obeys the four rules in [DSComponentStyle]: every field nullable, defaults
/// read from the spec inside [resolve] and nowhere else, a real [lerp], and no
/// behaviour. The number formatter is deliberately *not* here — it is a
/// function, and a style object that carries behaviour is a second place for a
/// component's logic to live.
@immutable
class DSStatTileStyle extends DSComponentStyle<DSStatTileStyle> {
  const DSStatTileStyle({
    this.labelStyle,
    this.valueStyle,
    this.deltaStyle,
    this.noteStyle,
    this.markSize,
    this.wellSize,
    this.wellShape,
    this.iconSize,
    this.labelGap,
    this.valueGap,
    this.padding,
    this.alignment,
  });

  /// The caption above the figure. `textSecondary`, never the category tone —
  /// the mark is what carries the category.
  final TextStyle? labelStyle;

  /// The figure. Tabular by default, and `text` rather than a trend colour:
  /// colouring the value by its trend makes the value unreadable and the trend
  /// invisible.
  final TextStyle? valueStyle;

  /// The delta chip's text. Its *colour* is decided by the trend at paint
  /// time, so setting one here is overridden per direction by design.
  final TextStyle? deltaStyle;

  /// The 'vs last week' tail beside the delta.
  final TextStyle? noteStyle;

  /// Diameter of the category dot drawn by `markColor`.
  final double? markSize;

  /// The tinted tile behind the glyph in [DSStatTile.icon].
  final double? wellSize;
  final AppShape? wellShape;
  final double? iconSize;

  /// Label to value, and value to delta.
  final double? labelGap;
  final double? valueGap;

  /// Zero by default and reachable anyway — see the class docs on [DSStatTile]
  /// for why those are two different statements.
  final EdgeInsetsGeometry? padding;

  final CrossAxisAlignment? alignment;

  @override
  DSStatTileStyle merge(DSStatTileStyle? other) {
    if (other == null) return this;
    return DSStatTileStyle(
      labelStyle: other.labelStyle ?? labelStyle,
      valueStyle: other.valueStyle ?? valueStyle,
      deltaStyle: other.deltaStyle ?? deltaStyle,
      noteStyle: other.noteStyle ?? noteStyle,
      markSize: other.markSize ?? markSize,
      wellSize: other.wellSize ?? wellSize,
      wellShape: other.wellShape ?? wellShape,
      iconSize: other.iconSize ?? iconSize,
      labelGap: other.labelGap ?? labelGap,
      valueGap: other.valueGap ?? valueGap,
      padding: other.padding ?? padding,
      alignment: other.alignment ?? alignment,
    );
  }

  @override
  DSStatTileStyle copyWith({
    TextStyle? labelStyle,
    TextStyle? valueStyle,
    TextStyle? deltaStyle,
    TextStyle? noteStyle,
    double? markSize,
    double? wellSize,
    AppShape? wellShape,
    double? iconSize,
    double? labelGap,
    double? valueGap,
    EdgeInsetsGeometry? padding,
    CrossAxisAlignment? alignment,
  }) => DSStatTileStyle(
    labelStyle: labelStyle ?? this.labelStyle,
    valueStyle: valueStyle ?? this.valueStyle,
    deltaStyle: deltaStyle ?? this.deltaStyle,
    noteStyle: noteStyle ?? this.noteStyle,
    markSize: markSize ?? this.markSize,
    wellSize: wellSize ?? this.wellSize,
    wellShape: wellShape ?? this.wellShape,
    iconSize: iconSize ?? this.iconSize,
    labelGap: labelGap ?? this.labelGap,
    valueGap: valueGap ?? this.valueGap,
    padding: padding ?? this.padding,
    alignment: alignment ?? this.alignment,
  );

  @override
  DSStatTileStyle lerp(DSStatTileStyle? other, double t) {
    if (other == null) return this;
    return DSStatTileStyle(
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t),
      valueStyle: TextStyle.lerp(valueStyle, other.valueStyle, t),
      deltaStyle: TextStyle.lerp(deltaStyle, other.deltaStyle, t),
      noteStyle: TextStyle.lerp(noteStyle, other.noteStyle, t),
      markSize: lerpDouble(markSize, other.markSize, t),
      wellSize: lerpDouble(wellSize, other.wellSize, t),
      wellShape: t < 0.5 ? wellShape : other.wellShape,
      iconSize: lerpDouble(iconSize, other.iconSize, t),
      labelGap: lerpDouble(labelGap, other.labelGap, t),
      valueGap: lerpDouble(valueGap, other.valueGap, t),
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t),
      alignment: t < 0.5 ? alignment : other.alignment,
    );
  }

  /// Which scale applies, given what the call site asked for.
  ///
  /// An explicit [size] always wins; a null one takes the ambient
  /// [DSScope.density] as its *default*, which is the whole difference between
  /// a scope and cloning a child.
  static DSStatTileSize sizeOf(BuildContext context, DSStatTileSize? size) =>
      size ??
      (DSScope.densityOf(context) == DSDensity.compact
          ? DSStatTileSize.compact
          : DSStatTileSize.md);

  /// The four layers, in order, and the only place a tile's defaults are read.
  static DSStatTileStyle resolve(
    BuildContext context,
    DSStatTileSize? size, [
    DSStatTileStyle? own,
  ]) {
    final palette = context.palette;
    final design = context.design;
    final space = design.space;
    final component = design.component;
    final text = Theme.of(context).textTheme;
    final compact = sizeOf(context, size) == DSStatTileSize.compact;

    final specDefaults = DSStatTileStyle(
      labelStyle: (compact ? text.labelSmall : text.labelMedium)?.copyWith(
        color: palette.mutedForeground,
      ),
      valueStyle: (compact ? text.titleLarge : text.headlineMedium)
          ?.copyWith(
            color: palette.foreground,
            fontWeight: context.design.type.emphasisWeight,
          )
          .tabular,
      deltaStyle: text.labelSmall?.copyWith(
        fontWeight: context.design.type.emphasisWeight,
      ),
      noteStyle: text.labelSmall?.copyWith(color: palette.mutedForeground),
      markSize: compact ? space.sm - space.hairline : space.sm,
      // The compact well is one space step in from the designed one rather
      // than a fraction of it, so it stays on the grid when an identity
      // changes either number.
      wellSize: compact ? component.wellSize - space.sm : component.wellSize,
      wellShape: component.wellShape,
      iconSize: compact ? component.iconSizeSmall : component.iconSize,
      labelGap: compact ? space.xs : space.sm,
      valueGap: compact ? space.xs : space.sm,
      padding: EdgeInsets.zero,
      alignment: CrossAxisAlignment.start,
    );

    return resolveStyle(context: context, specDefaults: specDefaults, own: own);
  }
}

/// One number, its label, and an optional mark of which category it belongs to.
///
/// The smallest unit a dashboard is built from. See
/// `docs/plans/02-ds-stat-tile.plan.md`.
///
/// **It is not a card.** It draws no surface, no margin and no padding of its
/// own: a component that pads itself cannot sit in a grid cell, and one that
/// margins itself double-spaces against the parent that already spaced it. A
/// caller who wants a surface wraps it in a `DSCard`; a caller who wants many
/// puts them in a [DSStatTileGrid], which owns exactly one card between them.
///
/// `padding` is still reachable through [DSStatTileStyle], which is the
/// difference between "this component refuses to pad itself" (a rule) and
/// "this component cannot be padded" (a defect).
///
/// ```dart
/// DSStatTileGrid(
///   columns: 2,
///   children: [
///     DSStatTile(
///       label: 'Active users',
///       value: '1,284',
///       markColor: context.palette.chart[0],
///       deltaLabel: '12.4%',
///       trend: DSTrend.up,
///       note: 'vs last week',
///     ),
///     DSStatTile.count(label: 'Errors', count: 37),
///   ],
/// )
/// ```
class DSStatTile extends StatelessWidget {
  const DSStatTile({
    super.key,
    required this.label,
    required this.value,
    this.markColor,
    this.deltaLabel,
    this.trend,
    this.note,
    this.loading = false,
    this.onTap,
    this.size,
    this.style,
    this.labelSlot,
    this.leading,
    this.trailing,
    this.deltaSlot,
    this.footer,
  }) : icon = null;

  /// The tile with a tinted well and a glyph in it, for one or two figures
  /// that need to be identifiable at a glance.
  ///
  /// The dot and the icon are alternatives, never both: the dot is for a grid
  /// of six where an icon each would be noise.
  const DSStatTile.icon({
    super.key,
    required this.label,
    required this.value,
    required IconData this.icon,
    this.markColor,
    this.deltaLabel,
    this.trend,
    this.note,
    this.loading = false,
    this.onTap,
    this.size,
    this.style,
    this.labelSlot,
    this.leading,
    this.trailing,
    this.deltaSlot,
    this.footer,
  });

  /// The tile for a figure that arrives as a number.
  ///
  /// Formatting an integer is the caller's job in every other component here;
  /// this constructor exists so callers stop writing `'$count'` and losing the
  /// grouping. [valueFormatter] is injectable because the default groups with
  /// a comma, and a comma is wrong in about half the world — a caller with
  /// `intl` passes `NumberFormat.decimalPattern(locale).format`.
  DSStatTile.count({
    super.key,
    required this.label,
    required num count,
    String Function(num)? valueFormatter,
    this.markColor,
    this.deltaLabel,
    this.trend,
    this.note,
    this.loading = false,
    this.onTap,
    this.size,
    this.style,
    this.labelSlot,
    this.leading,
    this.trailing,
    this.deltaSlot,
    this.footer,
  }) : icon = null,
       value = (valueFormatter ?? groupedNumber)(count);

  /// The caption. Above the value, because a dashboard is scanned for figures
  /// and the eye should land on the figure.
  final String label;

  /// The figure, already formatted. A `String` and not a `Widget` on purpose:
  /// the widget owns tabular figures and the shrink-rather-than-wrap rule, and
  /// a `Widget` here loses both silently while the column jitters.
  ///
  /// Empty means *no data* — rendered as an em-dash in `textTertiary`, because
  /// `0` is a fact and missing is not.
  final String value;

  /// Draws the category dot. A category `arc` tone or a semantic colour; null
  /// draws no mark, which is the most common right answer.
  final Color? markColor;

  /// '12.4%'. Paired with [trend]; neither alone renders a delta.
  final String? deltaLabel;
  final DSTrend? trend;

  /// 'vs last week'. Renders beside the delta, or alone under the value.
  final String? note;

  /// Bones over the value and the delta only. The label is known before the
  /// data arrives, so shimmering it says the app knows less than it does.
  final bool loading;

  final VoidCallback? onTap;

  /// Null takes [DSScope.density] as a default; an explicit value beats it.
  final DSStatTileSize? size;

  final DSStatTileStyle? style;

  /// Replaces the label text — a label with a trailing help icon or a beta
  /// badge, without a fork.
  final Widget? labelSlot;

  /// Replaces the icon well outright, and beats [markColor]. An avatar, a
  /// sparkline, a flag.
  final Widget? leading;

  /// Reserved space at the trailing edge. A chevron, an overflow menu. The
  /// component owns neither the widget nor its gesture.
  final Widget? trailing;

  /// Replaces the delta chip, and beats [deltaLabel] + [trend].
  final Widget? deltaSlot;

  /// Below everything. The unanticipated-content hatch.
  final Widget? footer;

  /// Set by [DSStatTile.icon] only.
  final IconData? icon;

  /// Groups by thousands with a comma. The default, and the reason
  /// [DSStatTile.count] takes a formatter at all.
  static String groupedNumber(num value) {
    final text = value.toString();
    final dot = text.indexOf('.');
    final whole = dot == -1 ? text : text.substring(0, dot);
    final tail = dot == -1 ? '' : text.substring(dot);
    final negative = whole.startsWith('-');
    final digits = negative ? whole.substring(1) : whole;
    final grouped = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
      grouped.write(digits[i]);
    }
    return '${negative ? '-' : ''}$grouped$tail';
  }

  /// What a screen reader says for the whole tile, as one sentence.
  String _semanticValue() {
    if (loading) return 'loading';
    final buffer = StringBuffer(value.isEmpty ? 'no data' : value);
    if (deltaLabel != null && trend != null) {
      buffer.write(trend == DSTrend.up ? ', up ' : ', down ');
      buffer.write(deltaLabel);
    }
    if (note != null) buffer.write(' $note');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final space = context.design.space;
    final resolved = DSStatTileStyle.resolve(context, size, style);
    final labelGap = resolved.labelGap ?? space.xs;
    final valueGap = resolved.valueGap ?? space.xs;

    final labelWidget =
        labelSlot ??
        Text(
          label,
          style: resolved.labelStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );

    final valueWidget = _AnimatedValue(
      value: value,
      style: resolved.valueStyle?.copyWith(
        color: value.isEmpty ? palette.mutedForeground : null,
      ),
    );

    final Widget? delta =
        deltaSlot ??
        (deltaLabel != null && trend != null
            ? DSStatTileDelta(label: deltaLabel!, trend: trend!, note: note)
            : (note != null
                  ? Text(note!, style: resolved.noteStyle, maxLines: 1)
                  : null));

    // Only the parts that are unknown before the data arrives wear bones.
    final body = Column(
      crossAxisAlignment: resolved.alignment ?? CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DefaultTextStyle.merge(
          style: resolved.labelStyle,
          child: markColor == null
              ? labelWidget
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DSStatTileMark(color: markColor!, size: resolved.markSize),
                    SizedBox(width: space.sm),
                    Flexible(child: labelWidget),
                  ],
                ),
        ),
        SizedBox(height: labelGap),
        DSSkeleton(
          enabled: loading,
          child: Column(
            crossAxisAlignment: resolved.alignment ?? CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              valueWidget,
              if (delta != null) ...[SizedBox(height: valueGap), delta],
            ],
          ),
        ),
        if (footer != null) ...[SizedBox(height: valueGap), footer!],
      ],
    );

    final Widget? region =
        leading ?? (icon == null ? null : _iconWell(context, resolved));

    Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (region != null) ...[region, SizedBox(width: space.md)],
        Flexible(child: body),
        if (trailing != null) ...[SizedBox(width: space.md), trailing!],
      ],
    );

    final padding = resolved.padding ?? EdgeInsets.zero;
    if (padding != EdgeInsets.zero) {
      content = Padding(padding: padding, child: content);
    }

    if (onTap != null) {
      final radius = BorderRadius.circular(
        context.design.shape.radiusOf(
          AppShape.tile,
          isApple: context.isApplePlatform,
        ),
      );
      final shape = RoundedRectangleBorder(borderRadius: radius);
      content = DSPressable(
        focusShape: shape,
        child: DSInkSurface(onTap: onTap, shape: shape, child: content),
      );
    }

    // One node for the whole tile: the label, the figure and the movement are
    // one reading, and a screen reader that stops on each of them three times
    // has turned a glance into a paragraph.
    return Semantics(
      container: true,
      button: onTap != null,
      label: label,
      value: _semanticValue(),
      child: ExcludeSemantics(child: content),
    );
  }

  Widget _iconWell(BuildContext context, DSStatTileStyle resolved) {
    final palette = context.palette;
    final side = resolved.wellSize ?? context.design.component.wellSize;
    final tone = markColor ?? palette.primary;
    return SizedBox(
      width: side,
      height: side,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: palette.muted,
          shape: context.design.shape.border(
            resolved.wellShape ?? context.design.component.wellShape,
            isApple: context.isApplePlatform,
          ),
        ),
        child: Center(
          child: Icon(icon, size: resolved.iconSize, color: tone),
        ),
      ),
    );
  }
}

/// The Ø8 category dot. Its own widget so a caller can put one in a legend,
/// and so the tile has one implementation of it rather than an inline
/// `Container` nobody can reach.
// ds-tier: 1 — atom — The tile's category dot.
class DSStatTileMark extends StatelessWidget {
  const DSStatTileMark({super.key, required this.color, this.size});

  final Color color;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final diameter = size ?? DSStatTileStyle.resolve(context, null).markSize!;
    // A colour is never the only channel: whatever the dot means is also in
    // the label beside it, so the dot itself says nothing to a screen reader.
    return ExcludeSemantics(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// The arrow-and-percentage chip under a figure — the intended occupant of
/// [DSStatTile.deltaSlot], and a widget in its own right so a caller can put
/// one somewhere else.
///
/// Direction is the arrow and colour is the reinforcement, never colour alone.
// ds-tier: 1 — atom — The up-or-down figure beside a metric.
class DSStatTileDelta extends StatelessWidget {
  const DSStatTileDelta({
    super.key,
    required this.label,
    required this.trend,
    this.note,
    this.style,
  });

  final String label;
  final DSTrend trend;
  final String? note;
  final DSStatTileStyle? style;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final resolved = DSStatTileStyle.resolve(context, null, style);
    // `.color` is the family's glyph tone by construction — the same
    // lightness and chroma K5 holds every colour on the five-colour chart
    // scale to — so a delta reads as text rather than merely registering as
    // a graphical object.
    final tone = trend == DSTrend.up ? palette.success : palette.destructive;
    final arrow = trend == DSTrend.up
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
    final size = resolved.deltaStyle?.fontSize ?? context.design.space.md;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Decorative: the direction is already in the semantic value the tile
        // publishes, and an unlabelled arrow read aloud is noise.
        ExcludeSemantics(
          child: Icon(arrow, size: size, color: tone),
        ),
        SizedBox(width: context.design.space.hairline),
        Text(label, style: resolved.deltaStyle?.copyWith(color: tone)),
        if (note != null) ...[
          SizedBox(width: context.design.space.sm),
          Flexible(
            child: Text(
              note!,
              style: resolved.noteStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

/// [DSStatTileGrid]'s appearance, as data.
@immutable
class DSStatTileGridStyle extends DSComponentStyle<DSStatTileGridStyle> {
  const DSStatTileGridStyle({
    this.dividerColor,
    this.dividerThickness,
    this.cellPadding,
    this.collapseAtTextScale,
  });

  final Color? dividerColor;
  final double? dividerThickness;

  /// The breathing room inside each cell. The *grid* pads its cells; the tile
  /// still pads nothing.
  final EdgeInsetsGeometry? cellPadding;

  /// Above this text scale the grid drops to one column. A number rather than
  /// a flag, so an identity with a wider type ramp can move it.
  final double? collapseAtTextScale;

  @override
  DSStatTileGridStyle merge(DSStatTileGridStyle? other) {
    if (other == null) return this;
    return DSStatTileGridStyle(
      dividerColor: other.dividerColor ?? dividerColor,
      dividerThickness: other.dividerThickness ?? dividerThickness,
      cellPadding: other.cellPadding ?? cellPadding,
      collapseAtTextScale: other.collapseAtTextScale ?? collapseAtTextScale,
    );
  }

  @override
  DSStatTileGridStyle copyWith({
    Color? dividerColor,
    double? dividerThickness,
    EdgeInsetsGeometry? cellPadding,
    double? collapseAtTextScale,
  }) => DSStatTileGridStyle(
    dividerColor: dividerColor ?? this.dividerColor,
    dividerThickness: dividerThickness ?? this.dividerThickness,
    cellPadding: cellPadding ?? this.cellPadding,
    collapseAtTextScale: collapseAtTextScale ?? this.collapseAtTextScale,
  );

  @override
  DSStatTileGridStyle lerp(DSStatTileGridStyle? other, double t) {
    if (other == null) return this;
    return DSStatTileGridStyle(
      dividerColor: Color.lerp(dividerColor, other.dividerColor, t),
      dividerThickness: lerpDouble(dividerThickness, other.dividerThickness, t),
      cellPadding: EdgeInsetsGeometry.lerp(cellPadding, other.cellPadding, t),
      collapseAtTextScale: lerpDouble(
        collapseAtTextScale,
        other.collapseAtTextScale,
        t,
      ),
    );
  }

  static DSStatTileGridStyle resolve(
    BuildContext context, [
    DSStatTileGridStyle? own,
  ]) {
    final design = context.design;
    return resolveStyle(
      context: context,
      specDefaults: DSStatTileGridStyle(
        dividerColor: context.palette.borderSoft,
        dividerThickness: design.component.hairlineWidth,
        cellPadding: EdgeInsets.all(design.space.md),
        collapseAtTextScale: 1.3,
      ),
      own: own,
    );
  }
}

/// N tiles in one card, with hairline dividers and no per-cell surface.
///
/// A grid of figures with no per-item action is not four cards, it is one card
/// of four cells — which is also why this widget draws the dividers and the
/// tiles draw nothing.
///
/// Takes `List<Widget>`, deliberately, and never `List<DSStatTile>`. Typing a
/// container to a concrete child class forbids every composed tile — one
/// wrapped in a `Tooltip`, one behind a `Consumer`, a caller's own tile that
/// satisfies the same contract — which is Liskov failing at the container
/// rather than at the subclass. The grid contributes layout, dividers and the
/// text-scale collapse; it never inspects its children.
class DSStatTileGrid extends StatelessWidget {
  const DSStatTileGrid({
    super.key,
    required this.children,
    this.columns = 2,
    this.style,
  });

  final List<Widget> children;

  /// Collapses to one at large text scales — see
  /// [DSStatTileGridStyle.collapseAtTextScale].
  final int columns;

  final DSStatTileGridStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = DSStatTileGridStyle.resolve(context, style);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final collapse = scale > (resolved.collapseAtTextScale ?? 1.3);
    final perRow = collapse ? 1 : (columns < 1 ? 1 : columns);
    final thickness = resolved.dividerThickness ?? 1;
    final color = resolved.dividerColor ?? context.palette.borderSoft;
    final padding = resolved.cellPadding ?? EdgeInsets.zero;

    final rows = <List<Widget>>[];
    for (var i = 0; i < children.length; i += perRow) {
      rows.add(
        children.sublist(
          i,
          i + perRow > children.length ? children.length : i + perRow,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0)
            DSDivider(
              style: DSDividerStyle(thickness: thickness, color: color),
            ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < perRow; c++) ...[
                  if (c > 0)
                    DSDivider.vertical(
                      style: DSDividerStyle(thickness: thickness, color: color),
                    ),
                  Expanded(
                    child: c < rows[r].length
                        // Every cell keeps its box even when the last row is
                        // short, so a three-tile grid does not stretch its
                        // last tile across two columns.
                        ? Padding(padding: padding, child: rows[r][c])
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The figure, cross-faded when it changes.
///
/// Fade only, and never a count-up: an interpolated figure is a number that
/// was never true, on screen, for 400ms.
class _AnimatedValue extends StatelessWidget {
  const _AnimatedValue({required this.value, this.style});

  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final motion = context.design.motion;
    return AnimatedSwitcher(
      duration: motion.scaled(motion.fast),
      switchInCurve: motion.enter,
      switchOutCurve: motion.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [...previous, if (current != null) current],
      ),
      child: FittedBox(
        // Shrink rather than wrap or ellipsise: a truncated number is a wrong
        // number, and a wrapped one is two numbers.
        key: ValueKey<String>(value),
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          value.isEmpty ? '—' : value,
          style: style,
          maxLines: 1,
          softWrap: false,
        ),
      ),
    );
  }
}
