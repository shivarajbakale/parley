// ds-tier: 1 — atom

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/theme/app_typography.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// [DSFieldGroup]'s appearance, as data.
///
/// The group had no style object at all: its gutter, its eyebrow inset, the
/// gap between fields and the footer's type were computed inside `build` from
/// the spec, so the only way to change a form's rhythm was to edit this file.
/// A screen with two groups that wanted different spacing had no way to say
/// so, and neither did an identity.
///
/// Obeys the four rules in [DSComponentStyle]: every field nullable, defaults
/// read from the spec inside [resolve] and nowhere else, a real [lerp], and no
/// behaviour.
@immutable
class DSFieldGroupStyle extends DSComponentStyle<DSFieldGroupStyle> {
  const DSFieldGroupStyle({
    this.padding,
    this.eyebrowPadding,
    this.eyebrowStyle,
    this.itemSpacing,
    this.footerPadding,
    this.footerStyle,
  });

  /// The inset around the whole group. Defaults to the page gutter, which is
  /// why a group is dropped straight onto a page rather than inside a gutter
  /// of someone else's.
  final EdgeInsetsGeometry? padding;

  /// The eyebrow's own inset, measured from inside [padding].
  final EdgeInsetsGeometry? eyebrowPadding;

  final TextStyle? eyebrowStyle;

  /// The gap between one field and the next.
  final double? itemSpacing;

  final EdgeInsetsGeometry? footerPadding;
  final TextStyle? footerStyle;

  @override
  DSFieldGroupStyle merge(DSFieldGroupStyle? other) => other == null
      ? this
      : copyWith(
          padding: other.padding,
          eyebrowPadding: other.eyebrowPadding,
          eyebrowStyle: other.eyebrowStyle,
          itemSpacing: other.itemSpacing,
          footerPadding: other.footerPadding,
          footerStyle: other.footerStyle,
        );

  @override
  DSFieldGroupStyle copyWith({
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? eyebrowPadding,
    TextStyle? eyebrowStyle,
    double? itemSpacing,
    EdgeInsetsGeometry? footerPadding,
    TextStyle? footerStyle,
  }) => DSFieldGroupStyle(
    padding: padding ?? this.padding,
    eyebrowPadding: eyebrowPadding ?? this.eyebrowPadding,
    eyebrowStyle: eyebrowStyle ?? this.eyebrowStyle,
    itemSpacing: itemSpacing ?? this.itemSpacing,
    footerPadding: footerPadding ?? this.footerPadding,
    footerStyle: footerStyle ?? this.footerStyle,
  );

  @override
  DSFieldGroupStyle lerp(DSFieldGroupStyle? other, double t) {
    if (other == null) return this;
    return DSFieldGroupStyle(
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t),
      eyebrowPadding: EdgeInsetsGeometry.lerp(
        eyebrowPadding,
        other.eyebrowPadding,
        t,
      ),
      eyebrowStyle: TextStyle.lerp(eyebrowStyle, other.eyebrowStyle, t),
      itemSpacing: lerpDouble(itemSpacing, other.itemSpacing, t),
      footerPadding: EdgeInsetsGeometry.lerp(
        footerPadding,
        other.footerPadding,
        t,
      ),
      footerStyle: TextStyle.lerp(footerStyle, other.footerStyle, t),
    );
  }

  /// The four layers, in order, and the only place a group's defaults are
  /// read.
  ///
  /// Layer 3's contribution is [DSScope.density]: a group inside a compact
  /// container closes the gap between its fields by one step on the space
  /// scale, without the screen repeating itself at every group.
  static DSFieldGroupStyle resolve(
    BuildContext context, [
    DSFieldGroupStyle? own,
  ]) {
    final space = context.design.space;

    final specDefaults = DSFieldGroupStyle(
      padding: EdgeInsets.symmetric(horizontal: space.pageGutter),
      // The same optical inset a settings eyebrow takes, measured from the
      // gutter this group is already inside.
      eyebrowPadding: EdgeInsetsDirectional.only(
        start: space.xs,
        bottom: space.sm,
      ),
      eyebrowStyle: AppTypography.eyebrow(context),
      itemSpacing: space.lg,
      footerPadding: EdgeInsets.fromLTRB(space.xs, space.sm, space.xs, 0),
      footerStyle: DSTextRole.bodyDetail.styleOf(context),
    );

    final scope = DSScope.densityOf(context) == DSDensity.compact
        ? DSFieldGroupStyle(itemSpacing: space.md)
        : null;

    return resolveStyle(
      context: context,
      specDefaults: specDefaults,
      scope: scope,
      own: own,
    );
  }
}

/// A group of form controls under an optional eyebrow.
///
/// Deliberately not a `DSSettingsSection`. That section paints
/// `palette.card`, and a field paints `palette.fieldFill` — the lighter of
/// the page and the card — so a field dropped inside one is an outline ring on
/// a ground that either matches the section or floats a rung off it, inset
/// twice, with the section's row divider running between two controls that are
/// not rows. A settings section holds rows; a form holds fields, on the page
/// background.
///
/// The two compose on one screen: the fields in a [DSFieldGroup], the rows
/// that navigate or report in a `DSSettingsSection` below them.
///
/// **An eyebrow is not free.** It costs its own line plus the gap under it,
/// and over a group of one it is chrome standing in for a label the control
/// already carries. Reach for a second group when the two hold decisions a
/// reader would answer separately — not to caption every field on the page.
///
/// **Instead:** `DSSettingsSection` when the children are rows that navigate,
/// report or toggle rather than fields you type into.
class DSFieldGroup extends StatelessWidget {
  const DSFieldGroup({
    super.key,
    required this.children,
    this.eyebrow,
    this.footer,
    this.style,
  });

  /// The uppercase label above the group, in the same type a settings
  /// section's eyebrow takes — so the two kinds of group read as one screen.
  final String? eyebrow;

  final List<Widget> children;

  /// The caption below the group.
  ///
  /// This is where a sentence too long for a field's helper line belongs: the
  /// helper slot is one fixed line by design, so that a form does not jump
  /// when an error replaces it, and anything longer is silently ellipsised.
  /// A footer wraps.
  final String? footer;

  final DSFieldGroupStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = DSFieldGroupStyle.resolve(context, style);

    return Padding(
      padding: resolved.padding!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (eyebrow != null)
            Padding(
              padding: resolved.eyebrowPadding!,
              child: Text(
                AppTypography.eyebrowCase(context, eyebrow!),
                style: resolved.eyebrowStyle,
              ),
            ),
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: resolved.itemSpacing),
            children[i],
          ],
          if (footer != null)
            Padding(
              padding: resolved.footerPadding!,
              child: Text(footer!, style: resolved.footerStyle),
            ),
        ],
      ),
    );
  }
}
