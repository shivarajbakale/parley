// ds-tier: 1 — atom

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Which corner a [DSDot] sits on.
enum DSDotPlacement { topStart, topEnd, bottomStart, bottomEnd }

/// How a badge looks, at every layer of the resolution chain.
@immutable
class DSBadgeStyle extends DSComponentStyle<DSBadgeStyle> {
  const DSBadgeStyle({
    this.height,
    this.padding,
    this.labelStyle,
    this.fill,
    this.foreground,
    this.markColor,
    this.leadingDotSize,
  });

  final double? height;
  final EdgeInsetsGeometry? padding;
  final TextStyle? labelStyle;
  final Color? fill;

  /// The label's colour. Text on a tint is always the foreground.
  final Color? foreground;

  /// The icon and the leading dot: the tone's own colour, a graphical object.
  final Color? markColor;
  final double? leadingDotSize;

  @override
  DSBadgeStyle merge(DSBadgeStyle? other) {
    if (other == null) return this;
    return DSBadgeStyle(
      height: other.height ?? height,
      padding: other.padding ?? padding,
      labelStyle: other.labelStyle ?? labelStyle,
      fill: other.fill ?? fill,
      foreground: other.foreground ?? foreground,
      markColor: other.markColor ?? markColor,
      leadingDotSize: other.leadingDotSize ?? leadingDotSize,
    );
  }

  @override
  DSBadgeStyle copyWith({
    double? height,
    EdgeInsetsGeometry? padding,
    TextStyle? labelStyle,
    Color? fill,
    Color? foreground,
    Color? markColor,
    double? leadingDotSize,
  }) => DSBadgeStyle(
    height: height ?? this.height,
    padding: padding ?? this.padding,
    labelStyle: labelStyle ?? this.labelStyle,
    fill: fill ?? this.fill,
    foreground: foreground ?? this.foreground,
    markColor: markColor ?? this.markColor,
    leadingDotSize: leadingDotSize ?? this.leadingDotSize,
  );

  @override
  DSBadgeStyle lerp(DSBadgeStyle? other, double t) {
    if (other == null) return this;
    return DSBadgeStyle(
      height: lerpDouble(height, other.height, t),
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t),
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t),
      fill: Color.lerp(fill, other.fill, t),
      foreground: Color.lerp(foreground, other.foreground, t),
      markColor: Color.lerp(markColor, other.markColor, t),
      leadingDotSize: lerpDouble(leadingDotSize, other.leadingDotSize, t),
    );
  }

  static DSBadgeStyle resolve(
    BuildContext context, [
    DSTone tone = DSTone.neutral,
    DSBadgeStyle? own,
  ]) {
    final design = context.design;
    final space = design.space;
    final text = Theme.of(context).textTheme;
    final (fill, foreground) = toneColors(context, tone);
    final markColor = markColorFor(context, tone);
    return resolveStyle(
      context: context,
      specDefaults: DSBadgeStyle(
        height: design.component.badgeHeight,
        padding: EdgeInsets.symmetric(horizontal: space.sm),
        labelStyle: text.labelSmall?.copyWith(
          fontWeight: context.design.type.emphasisWeight,
        ),
        fill: fill,
        foreground: foreground,
        markColor: markColor,
        leadingDotSize: space.sm - space.hairline,
      ),
      own: own,
    );
  }

  /// The identity's derived container and on-container for a tone.
  ///
  /// One mapping for the badge, the dot and the well: `DSBadge.color` and
  /// `.backgroundColor` used to be two unconstrained `Color?` fields — the
  /// exact hole plan 14 deleted from `DSChip`, with the same consequence, that
  /// a lint cannot check what a call site passes and call sites pass
  /// `Colors.*`.
  /// The tone's colour for a badge's icon and dot. A graphical object on the
  /// tint, which gate K1 holds at 3:1; the label is text and stays on
  /// [toneColors]' foreground.
  static Color markColorFor(BuildContext context, DSTone tone) {
    final palette = context.palette;
    return switch (tone) {
      DSTone.neutral => palette.secondaryForeground,
      DSTone.info => palette.primary,
      DSTone.success => palette.success,
      DSTone.warning => palette.warning,
      DSTone.error => palette.destructive,
    };
  }

  static (Color fill, Color foreground) toneColors(
    BuildContext context,
    DSTone tone,
  ) {
    final palette = context.palette;
    return switch (tone) {
      DSTone.neutral => (palette.secondary, palette.secondaryForeground),
      DSTone.info => (palette.tint(palette.primary), palette.foreground),
      DSTone.success => (palette.tint(palette.success), palette.foreground),
      DSTone.warning => (palette.tint(palette.warning), palette.foreground),
      DSTone.error => (palette.tint(palette.destructive), palette.foreground),
    };
  }
}

/// Read-only status, as a pill.
///
/// A badge is the one shape in the kit that is identical on both platforms: at
/// [AppShape.pill] a continuous curve and a circular arc converge, so this
/// takes the token for consistency rather than for difference.
///
/// **Use when** the state is not something the user can change here.
/// **Instead:** `DSChip` when it can be tapped, selected or removed — that is
/// the distinction, not the size, and "small pill with a label" describes both.
/// [DSDot] for an unread count on an icon.
class DSBadge extends StatelessWidget {
  const DSBadge({
    super.key,
    required this.label,
    this.tone = DSTone.neutral,
    this.icon,
    this.showDot = false,
    this.leading,
    this.labelSlot,
    this.style,
  });

  final String label;
  final DSTone tone;
  final IconData? icon;

  /// A leading dot in the tone's foreground — the "● Live" idiom.
  final bool showDot;

  final Widget? leading;
  final Widget? labelSlot;
  final DSBadgeStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = DSBadgeStyle.resolve(context, tone, style);
    final space = context.design.space;

    return Container(
      height: resolved.height,
      padding: resolved.padding,
      decoration: ShapeDecoration(
        color: resolved.fill,
        shape: context.shapeOf(AppShape.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            leading!,
            SizedBox(width: space.xs),
          ] else if (showDot) ...[
            DSBadgeDot(tone: tone),
            SizedBox(width: space.xs),
          ] else if (icon != null) ...[
            Icon(
              icon,
              size: context.design.component.iconSizeMicro,
              color: resolved.markColor,
            ),
            SizedBox(width: space.xs),
          ],
          labelSlot ??
              Text(
                label,
                style: resolved.labelStyle?.copyWith(
                  color: resolved.foreground,
                ),
              ),
        ],
      ),
    );
  }
}

/// The small filled circle a badge can carry before its label.
class DSBadgeDot extends StatelessWidget {
  const DSBadgeDot({super.key, this.tone});

  final DSTone? tone;

  @override
  Widget build(BuildContext context) {
    final resolved = DSBadgeStyle.resolve(
      context,
      tone ?? DSScope.toneOf(context) ?? DSTone.neutral,
    );
    return SizedBox(
      width: resolved.leadingDotSize,
      height: resolved.leadingDotSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: resolved.markColor,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// How a notification dot looks, at every layer of the resolution chain.
@immutable
class DSDotStyle extends DSComponentStyle<DSDotStyle> {
  const DSDotStyle({
    this.size,
    this.countHeight,
    this.maxWidth,
    this.offset,
    this.ringWidth,
    this.ringColor,
    this.fill,
    this.foreground,
    this.labelStyle,
    this.maxCount,
  });

  final double? size;
  final double? countHeight;
  final double? maxWidth;
  final Offset? offset;
  final double? ringWidth;
  final Color? ringColor;
  final Color? fill;
  final Color? foreground;
  final TextStyle? labelStyle;
  final int? maxCount;

  @override
  DSDotStyle merge(DSDotStyle? other) {
    if (other == null) return this;
    return DSDotStyle(
      size: other.size ?? size,
      countHeight: other.countHeight ?? countHeight,
      maxWidth: other.maxWidth ?? maxWidth,
      offset: other.offset ?? offset,
      ringWidth: other.ringWidth ?? ringWidth,
      ringColor: other.ringColor ?? ringColor,
      fill: other.fill ?? fill,
      foreground: other.foreground ?? foreground,
      labelStyle: other.labelStyle ?? labelStyle,
      maxCount: other.maxCount ?? maxCount,
    );
  }

  @override
  DSDotStyle copyWith({
    double? size,
    double? countHeight,
    double? maxWidth,
    Offset? offset,
    double? ringWidth,
    Color? ringColor,
    Color? fill,
    Color? foreground,
    TextStyle? labelStyle,
    int? maxCount,
  }) => DSDotStyle(
    size: size ?? this.size,
    countHeight: countHeight ?? this.countHeight,
    maxWidth: maxWidth ?? this.maxWidth,
    offset: offset ?? this.offset,
    ringWidth: ringWidth ?? this.ringWidth,
    ringColor: ringColor ?? this.ringColor,
    fill: fill ?? this.fill,
    foreground: foreground ?? this.foreground,
    labelStyle: labelStyle ?? this.labelStyle,
    maxCount: maxCount ?? this.maxCount,
  );

  @override
  DSDotStyle lerp(DSDotStyle? other, double t) {
    if (other == null) return this;
    return DSDotStyle(
      maxCount: t < 0.5 ? maxCount : other.maxCount,
      size: lerpDouble(size, other.size, t),
      countHeight: lerpDouble(countHeight, other.countHeight, t),
      maxWidth: lerpDouble(maxWidth, other.maxWidth, t),
      offset: Offset.lerp(offset, other.offset, t),
      ringWidth: lerpDouble(ringWidth, other.ringWidth, t),
      ringColor: Color.lerp(ringColor, other.ringColor, t),
      fill: Color.lerp(fill, other.fill, t),
      foreground: Color.lerp(foreground, other.foreground, t),
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t),
    );
  }

  static DSDotStyle resolve(
    BuildContext context, [
    DSTone tone = DSTone.error,
    DSDotStyle? own,
  ]) {
    final design = context.design;
    final component = design.component;
    final palette = context.palette;
    final swatch = switch (tone) {
      DSTone.neutral => (palette.primary, palette.primaryForeground),
      DSTone.info => (palette.primary, palette.primaryForeground),
      DSTone.success => (palette.success, palette.onSuccess),
      DSTone.warning => (palette.warning, palette.onWarning),
      DSTone.error => (palette.destructive, palette.onDestructive),
    };
    return resolveStyle(
      context: context,
      specDefaults: DSDotStyle(
        size: component.dotSize,
        countHeight: component.dotCountHeight,
        maxWidth: component.dotMaxWidth,
        offset: Offset(-design.space.hairline, -design.space.hairline),
        ringWidth: component.avatarRing,
        ringColor: palette.card,
        fill: swatch.$1,
        foreground: swatch.$2,
        labelStyle: DSTextRole.count.styleOf(context),
        maxCount: 99,
      ),
      own: own,
    );
  }
}

/// A notification dot, or the count it becomes.
///
/// New in plan 28. Plan 13 named a `badgeSlot` on the icon button and plan 15
/// collapsed a badge pair on the navigation bar; both needed this component
/// and neither had one.
///
/// **Zero renders nothing.** A badge reading "0" is the most common
/// notification bug in any kit, and `DSDot(count: 0)` is absent rather than
/// zero-sized-and-present.
///
/// It is positioned on its parent and never changes the parent's layout, so
/// an icon with an unread count is the same size as one without.
class DSDot extends StatelessWidget {
  const DSDot({
    super.key,
    this.count,
    this.child,
    this.tone = DSTone.error,
    this.maxCount,
    this.placement = DSDotPlacement.topEnd,
    this.style,
  });

  /// Null is a bare dot; zero renders nothing at all.
  final int? count;

  /// A glyph instead of a number — a "new" star.
  final Widget? child;

  final DSTone tone;
  final int? maxCount;
  final DSDotPlacement placement;
  final DSDotStyle? style;

  /// Whether this dot draws anything, which is the question a parent asks
  /// before making room for it.
  bool get visible => child != null || count == null || count! > 0;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final resolved = DSDotStyle.resolve(context, tone, style);
    final cap = maxCount ?? resolved.maxCount!;
    final label = count == null ? null : (count! > cap ? '$cap+' : '$count');

    final Widget body = Container(
      height: label == null || child != null
          ? (child == null ? resolved.size : resolved.countHeight)
          : resolved.countHeight,
      constraints: BoxConstraints(
        minWidth: label == null && child == null
            ? resolved.size!
            : resolved.countHeight!,
        // Never wider than the cap: a dot that grows with its number pushes
        // whatever is beside it off the row.
        maxWidth: resolved.maxWidth!,
      ),
      padding: label == null
          ? EdgeInsets.zero
          : EdgeInsets.symmetric(horizontal: context.design.space.xs),
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: resolved.fill,
        shape: StadiumBorder(
          side: BorderSide(
            color: resolved.ringColor!,
            width: resolved.ringWidth!,
          ),
        ),
      ),
      child:
          child ??
          (label == null
              ? null
              : Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: resolved.labelStyle?.copyWith(
                    color: resolved.foreground,
                  ),
                )),
    );

    // The dot is not its own node: it belongs to whatever it is placed on, so
    // that control reads as one thing — the pattern plan 15 settled for the
    // navigation bar.
    return ExcludeSemantics(child: body);
  }

  /// The dot's announcement, for the parent that carries it.
  String? announcement(String noun) {
    if (!visible || count == null) return null;
    return '$count $noun';
  }

  /// [child] with this dot on the corner [placement] names.
  Widget over(Widget target, {required BuildContext context}) {
    if (!visible) return target;
    final resolved = DSDotStyle.resolve(context, tone, style);
    final offset = resolved.offset!;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        target,
        PositionedDirectional(
          top:
              placement == DSDotPlacement.topStart ||
                  placement == DSDotPlacement.topEnd
              ? offset.dy
              : null,
          bottom:
              placement == DSDotPlacement.bottomStart ||
                  placement == DSDotPlacement.bottomEnd
              ? offset.dy
              : null,
          start:
              placement == DSDotPlacement.topStart ||
                  placement == DSDotPlacement.bottomStart
              ? offset.dx
              : null,
          end:
              placement == DSDotPlacement.topEnd ||
                  placement == DSDotPlacement.bottomEnd
              ? offset.dx
              : null,
          child: this,
        ),
      ],
    );
  }
}
