// ds-tier: 2 — molecule

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_button.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_divider.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_skeleton.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// A section label, or the smaller one a group inside a section takes.
enum DSSectionHeaderSize { sm, md }

/// How a section header looks, at every layer of the resolution chain.
@immutable
class DSSectionHeaderStyle extends DSComponentStyle<DSSectionHeaderStyle> {
  const DSSectionHeaderStyle({
    this.padding,
    this.labelStyle,
    this.labelColor,
    this.trailingGap,
    this.showDivider,
    this.dividerColor,
  });

  final EdgeInsetsGeometry? padding;
  final TextStyle? labelStyle;

  /// The label's colour. Muted, not the accent.
  ///
  /// Every section label on every screen used to be in the brand accent.
  /// Accent is the colour of the thing the user should act on, so spending it
  /// on the word "Recent" above a list leaves the actual action on that screen
  /// with nothing louder to be. The accent moves to the trailing action, where
  /// it earns its emphasis.
  final Color? labelColor;

  final double? trailingGap;
  final bool? showDivider;
  final Color? dividerColor;

  @override
  DSSectionHeaderStyle merge(DSSectionHeaderStyle? other) {
    if (other == null) return this;
    return DSSectionHeaderStyle(
      padding: other.padding ?? padding,
      labelStyle: other.labelStyle ?? labelStyle,
      labelColor: other.labelColor ?? labelColor,
      trailingGap: other.trailingGap ?? trailingGap,
      showDivider: other.showDivider ?? showDivider,
      dividerColor: other.dividerColor ?? dividerColor,
    );
  }

  @override
  DSSectionHeaderStyle copyWith({
    EdgeInsetsGeometry? padding,
    TextStyle? labelStyle,
    Color? labelColor,
    double? trailingGap,
    bool? showDivider,
    Color? dividerColor,
  }) => DSSectionHeaderStyle(
    padding: padding ?? this.padding,
    labelStyle: labelStyle ?? this.labelStyle,
    labelColor: labelColor ?? this.labelColor,
    trailingGap: trailingGap ?? this.trailingGap,
    showDivider: showDivider ?? this.showDivider,
    dividerColor: dividerColor ?? this.dividerColor,
  );

  @override
  DSSectionHeaderStyle lerp(DSSectionHeaderStyle? other, double t) {
    if (other == null) return this;
    return DSSectionHeaderStyle(
      showDivider: t < 0.5 ? showDivider : other.showDivider,
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t),
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t),
      labelColor: Color.lerp(labelColor, other.labelColor, t),
      trailingGap: lerpDouble(trailingGap, other.trailingGap, t),
      dividerColor: Color.lerp(dividerColor, other.dividerColor, t),
    );
  }

  static DSSectionHeaderStyle resolve(
    BuildContext context, [
    DSSectionHeaderSize size = DSSectionHeaderSize.md,
    DSSectionHeaderStyle? own,
  ]) {
    final design = context.design;
    final space = design.space;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    final (EdgeInsetsGeometry padding, TextStyle? label) = switch (size) {
      DSSectionHeaderSize.md => (
        EdgeInsets.fromLTRB(
          space.pageGutter,
          space.lg,
          space.pageGutter,
          space.xs,
        ),
        text.labelLarge?.copyWith(fontWeight: context.design.type.labelWeight),
      ),
      DSSectionHeaderSize.sm => (
        EdgeInsets.fromLTRB(
          space.pageGutter,
          space.sm,
          space.pageGutter,
          space.hairline,
        ),
        text.labelMedium?.copyWith(fontWeight: context.design.type.labelWeight),
      ),
    };

    return resolveStyle(
      context: context,
      specDefaults: DSSectionHeaderStyle(
        padding: padding,
        labelStyle: label,
        labelColor: palette.mutedForeground,
        trailingGap: space.sm,
        showDivider: false,
        dividerColor: palette.borderSoft,
      ),
      own: own,
    );
  }
}

/// The label above a section of content, and the one action that belongs to
/// it.
///
/// See `docs/plans/27-ds-headers.plan.md`. **Use when** a run of content needs
/// naming. **Instead:** `DSPageHeader` for the screen's own title, `DSMessage`
/// for something that needs attention.
///
/// It reports `header: true`, so a screen reader can jump between sections —
/// which none of the four header components in the kit used to do.
class DSSectionHeader extends StatelessWidget {
  const DSSectionHeader({
    super.key,
    required this.label,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.leading,
    this.trailing,
    this.labelSlot,
    this.size = DSSectionHeaderSize.md,
    this.loading = false,
    this.style,
  });

  /// The section's name. Called `label` rather than `title` because that is
  /// what it is — calling it a title is how it came to be styled as one.
  final String label;

  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final Widget? labelSlot;
  final DSSectionHeaderSize size;
  final bool loading;
  final DSSectionHeaderStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = DSSectionHeaderStyle.resolve(context, size, style);
    if (loading) return DSSectionHeaderSkeleton(size: size, style: style);

    final Widget? action =
        trailing ??
        (actionLabel == null || onAction == null
            ? null
            : DSSectionAction(label: actionLabel!, onPressed: onAction!));

    // Past this, the action stops sharing the row with the label.
    //
    // A `See all` at a raised text scale is a wide control, and the label is
    // what gives it up: on a 320-point phone at 1.3x, "Because you read about
    // colour" was cut to 150 points and ellipsised on both of its two lines,
    // which is the `clipped-text` probe rule and, worse, the reason the
    // section exists. Below the threshold nothing moves; above it the action
    // drops under the label and each gets the full width.
    const reflowScale = 1.2;
    final scale = MediaQuery.textScalerOf(context).scale(1);

    final Widget labelWidget =
        labelSlot ??
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: resolved.labelStyle?.copyWith(color: resolved.labelColor),
        );

    if (action != null && scale > reflowScale) {
      final stacked = Padding(
        padding: resolved.padding!,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  SizedBox(width: resolved.trailingGap),
                ] else if (icon != null) ...[
                  Icon(
                    icon,
                    size: context.design.component.iconSizeInline,
                    color: resolved.labelColor,
                  ),
                  SizedBox(width: resolved.trailingGap),
                ],
                Expanded(child: labelWidget),
              ],
            ),
            SizedBox(height: resolved.trailingGap),
            action,
          ],
        ),
      );
      final wrapped = (resolved.showDivider ?? false)
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DSDivider(style: DSDividerStyle(color: resolved.dividerColor)),
                stacked,
              ],
            )
          : stacked;
      return Semantics(header: true, child: wrapped);
    }

    Widget row = Padding(
      padding: resolved.padding!,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            SizedBox(width: resolved.trailingGap),
          ] else if (icon != null) ...[
            Icon(
              icon,
              size: context.design.component.iconSizeInline,
              color: resolved.labelColor,
            ),
            SizedBox(width: resolved.trailingGap),
          ],
          // Expanded, not bare: a header long enough to fill the row overflowed
          // it — 31 points on 'Icon, title, body, actions' at 358 wide, with
          // the striped bar over the end of the title. A section header takes
          // the width that is left and ellipsises inside it.
          Expanded(child: labelWidget),
          if (action != null) ...[
            SizedBox(width: resolved.trailingGap),
            action,
          ],
        ],
      ),
    );

    if (resolved.showDivider ?? false) {
      row = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DSDivider(style: DSDividerStyle(color: resolved.dividerColor)),
          row,
        ],
      );
    }

    return Semantics(header: true, child: row);
  }
}

/// The one action a section may carry, in the accent the label gave up.
class DSSectionAction extends StatelessWidget {
  const DSSectionAction({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => DSScope.merge(
    context,
    size: DSSize.sm,
    child: DSButton(
      label: label,
      variant: DSButtonVariant.ghost,
      onPressed: onPressed,
    ),
  );
}

/// A section label at a plausible width, for a title that arrives from the
/// network after the content it names.
class DSSectionHeaderSkeleton extends StatelessWidget {
  const DSSectionHeaderSkeleton({
    super.key,
    this.size = DSSectionHeaderSize.md,
    this.style,
  });

  final DSSectionHeaderSize size;
  final DSSectionHeaderStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = DSSectionHeaderStyle.resolve(context, size, style);
    return Padding(
      padding: resolved.padding!,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: DSSkeleton(
          child: Text('Section label', style: resolved.labelStyle),
        ),
      ),
    );
  }
}
