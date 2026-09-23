// ds-tier: 2 — molecule

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_divider.dart';
import 'package:parley_android/design_system/ds_list_tile.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_text_style.dart';
import 'package:parley_android/theme/app_typography.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// [DSSettingsSection]'s appearance, as data.
///
/// The section had no style object: its fill, its corner, the hairline between
/// rows and all four insets were computed inside `build`, so a screen that
/// wanted its groups flat, or an identity that wanted them square, had to edit
/// this file. It was the last painting component in the kit outside the
/// contract, alongside [DSFieldGroup].
///
/// Obeys the four rules in [DSComponentStyle]: every field nullable, defaults
/// read from the spec inside [resolve] and nowhere else, a real [lerp], and no
/// behaviour.
@immutable
class DSSettingsSectionStyle extends DSComponentStyle<DSSettingsSectionStyle> {
  const DSSettingsSectionStyle({
    this.fillColor,
    this.radius,
    this.margin,
    this.outlineColor,
    this.outlineWidth,
    this.elevation,
    this.eyebrowPadding,
    this.eyebrowStyle,
    this.dividerColor,
    this.dividerThickness,
    this.dividerIndent,
    this.footerPadding,
    this.footerStyle,
  });

  /// The container's ground. `palette.card` by default — a section is a
  /// card that happens to hold rows.
  final Color? fillColor;

  final BorderRadius? radius;

  /// The hairline around the card. `DSCard`'s `elevated` variant carries the
  /// same pair for the same reason: on the identity's flat light ladder the
  /// card and the page are the same white, so there is no tonal edge left for
  /// a shadow to reinforce, and a shadow on its own reads as a plane down the
  /// list rather than as a card. The edge is put back on the card instead of
  /// taken out of the page, so it is found rather than drawn.
  final Color? outlineColor;
  final double? outlineWidth;

  /// The lift off the page. Paired with [outlineColor] for the same reason —
  /// see its doc comment.
  final DSElevation? elevation;

  /// The inset around the container. Defaults to the page gutter.
  final EdgeInsetsGeometry? margin;

  final EdgeInsetsGeometry? eyebrowPadding;
  final TextStyle? eyebrowStyle;

  /// The hairline between two rows. Null [dividerColor] does not mean "no
  /// divider" — it means "not specified here"; a section that wants none sets
  /// [dividerThickness] to zero.
  final Color? dividerColor;
  final double? dividerThickness;

  /// How far the hairline is held off the leading edge, so it starts under the
  /// row's text rather than under its glyph.
  final double? dividerIndent;

  final EdgeInsetsGeometry? footerPadding;
  final TextStyle? footerStyle;

  @override
  DSSettingsSectionStyle merge(DSSettingsSectionStyle? other) => other == null
      ? this
      : copyWith(
          fillColor: other.fillColor,
          radius: other.radius,
          margin: other.margin,
          outlineColor: other.outlineColor,
          outlineWidth: other.outlineWidth,
          elevation: other.elevation,
          eyebrowPadding: other.eyebrowPadding,
          eyebrowStyle: other.eyebrowStyle,
          dividerColor: other.dividerColor,
          dividerThickness: other.dividerThickness,
          dividerIndent: other.dividerIndent,
          footerPadding: other.footerPadding,
          footerStyle: other.footerStyle,
        );

  @override
  DSSettingsSectionStyle copyWith({
    Color? fillColor,
    BorderRadius? radius,
    EdgeInsetsGeometry? margin,
    Color? outlineColor,
    double? outlineWidth,
    DSElevation? elevation,
    EdgeInsetsGeometry? eyebrowPadding,
    TextStyle? eyebrowStyle,
    Color? dividerColor,
    double? dividerThickness,
    double? dividerIndent,
    EdgeInsetsGeometry? footerPadding,
    TextStyle? footerStyle,
  }) => DSSettingsSectionStyle(
    fillColor: fillColor ?? this.fillColor,
    radius: radius ?? this.radius,
    margin: margin ?? this.margin,
    outlineColor: outlineColor ?? this.outlineColor,
    outlineWidth: outlineWidth ?? this.outlineWidth,
    elevation: elevation ?? this.elevation,
    eyebrowPadding: eyebrowPadding ?? this.eyebrowPadding,
    eyebrowStyle: eyebrowStyle ?? this.eyebrowStyle,
    dividerColor: dividerColor ?? this.dividerColor,
    dividerThickness: dividerThickness ?? this.dividerThickness,
    dividerIndent: dividerIndent ?? this.dividerIndent,
    footerPadding: footerPadding ?? this.footerPadding,
    footerStyle: footerStyle ?? this.footerStyle,
  );

  @override
  DSSettingsSectionStyle lerp(DSSettingsSectionStyle? other, double t) {
    if (other == null) return this;
    return DSSettingsSectionStyle(
      fillColor: Color.lerp(fillColor, other.fillColor, t),
      radius: BorderRadius.lerp(radius, other.radius, t),
      margin: EdgeInsetsGeometry.lerp(margin, other.margin, t),
      outlineColor: Color.lerp(outlineColor, other.outlineColor, t),
      outlineWidth: lerpDouble(outlineWidth, other.outlineWidth, t),
      // No midpoint for an enum step — it switches at the halfway mark.
      elevation: t < 0.5 ? elevation : other.elevation,
      eyebrowPadding: EdgeInsetsGeometry.lerp(
        eyebrowPadding,
        other.eyebrowPadding,
        t,
      ),
      eyebrowStyle: TextStyle.lerp(eyebrowStyle, other.eyebrowStyle, t),
      dividerColor: Color.lerp(dividerColor, other.dividerColor, t),
      dividerThickness: lerpDouble(dividerThickness, other.dividerThickness, t),
      dividerIndent: lerpDouble(dividerIndent, other.dividerIndent, t),
      footerPadding: EdgeInsetsGeometry.lerp(
        footerPadding,
        other.footerPadding,
        t,
      ),
      footerStyle: TextStyle.lerp(footerStyle, other.footerStyle, t),
    );
  }

  /// The four layers, in order, and the only place a section's defaults are
  /// read.
  ///
  /// Layer 3's contribution is [DSScope.density]: a compact container flattens
  /// the section's corner to the tighter shape role, which is the one visible
  /// thing a denser list of rows should change.
  static DSSettingsSectionStyle resolve(
    BuildContext context, [
    DSSettingsSectionStyle? own,
  ]) {
    final palette = context.palette;
    final design = context.design;
    final space = design.space;

    final specDefaults = DSSettingsSectionStyle(
      fillColor: palette.card,
      radius: BorderRadius.circular(context.radiusOf(AppShape.tile)),
      margin: EdgeInsets.symmetric(horizontal: space.pageGutter),
      // See the field doc comments: on the identity's flat light ladder the
      // card and the page are the same white, so the hairline and the shadow
      // are what find the card — the tonal fill alone does not.
      outlineColor: palette.borderSoft,
      outlineWidth: design.component.surfaceOutlineWidth,
      elevation: DSElevation.medium,
      // Two gutters, because the rows under it are inside two: the card's
      // margin and the row's own inset. A label at one gutter over rows at two
      // is the ragged left edge the settings page shipped with.
      eyebrowPadding: EdgeInsets.fromLTRB(
        space.pageGutter * 2,
        0,
        space.pageGutter * 2,
        space.sm,
      ),
      eyebrowStyle: AppTypography.eyebrow(context),
      dividerColor: palette.borderSoft,
      dividerThickness: design.component.hairlineWidth,
      // No dividerIndent default: each rule starts at its own row's text.
      footerPadding: EdgeInsets.fromLTRB(
        space.pageGutter * 2,
        space.sm,
        space.pageGutter * 2,
        0,
      ),
      footerStyle: DSTextRole.bodyDetail.styleOf(context),
    );

    final scope = DSScope.densityOf(context) == DSDensity.compact
        ? DSSettingsSectionStyle(
            radius: BorderRadius.circular(context.radiusOf(AppShape.control)),
          )
        : null;

    return resolveStyle(
      context: context,
      specDefaults: specDefaults,
      scope: scope,
      own: own,
    );
  }
}

/// Editorial settings section: an optional uppercase eyebrow, a tinted
/// rounded container holding rows separated by hairlines, and an optional
/// muted footer caption below.
///
/// **This section holds rows, not fields.** Its container is `palette.card`
/// and a `DSTextField` or `DSSelect` paints its own fill in the same role, so
/// a field placed inside one is an outline ring on identical grey, inset
/// twice, with the row divider running between two controls that are not
/// rows. Form fields belong on the page background under their own eyebrow;
/// the two group kinds compose on one screen, fields above, rows below.
///
/// ```dart
/// DSSettingsSection(
///   eyebrow: 'APPEARANCE',
///   children: [
///     DSSettingsRow(label: 'Theme', value: 'System', onTap: ...),
///     DSSwitchTile(label: 'Haptic', value: true, onChanged: ...),
///   ],
/// )
/// ```
class DSSettingsSection extends StatelessWidget {
  final String? eyebrow;
  final List<Widget> children;
  final String? footer;
  final DSSettingsSectionStyle? style;

  const DSSettingsSection({
    super.key,
    this.eyebrow,
    required this.children,
    this.footer,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = DSSettingsSectionStyle.resolve(context, style);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null)
          Padding(
            padding: resolved.eyebrowPadding!,
            child: Text(
              AppTypography.eyebrowCase(context, eyebrow!),
              style: resolved.eyebrowStyle,
            ),
          ),
        Container(
          margin: resolved.margin,
          decoration: ShapeDecoration(
            color: resolved.fillColor,
            shape: RoundedRectangleBorder(
              borderRadius: resolved.radius!,
              side: BorderSide(
                color: resolved.outlineColor!,
                width: resolved.outlineWidth!,
              ),
            ),
            shadows: context.design.elevation.resolve(
              elevation: context.design.elevation.levelOf(resolved.elevation!),
              brightness: Theme.of(context).brightness,
              shadowColor: context.palette.overlay,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1 &&
                    context.design.component.dividerPolicy !=
                        DividerPolicy.none)
                  DSDivider(
                    // The identity's divider rule, the one every list in the
                    // kit reads: gutter to gutter under `full`, from the
                    // row's text under `inset`.
                    indent:
                        resolved.dividerIndent ??
                        switch (context.design.component.dividerPolicy) {
                          DividerPolicy.inset => DSListTile.textInset(
                            context,
                            leading: switch (children[i]) {
                              DSLeadingRow row => row.leadsWith(context),
                              _ => false,
                            },
                          ),
                          _ => DSListTile.textInset(context, leading: false),
                        },
                    endIndent: DSListTile.textInset(context, leading: false),
                    style: DSDividerStyle(
                      thickness: resolved.dividerThickness,
                      color: resolved.dividerColor,
                    ),
                  ),
              ],
            ],
          ),
        ),
        if (footer != null)
          Padding(
            padding: resolved.footerPadding!,
            child: Text(footer!, style: resolved.footerStyle),
          ),
      ],
    );
  }
}

/// A single settings row.
///
/// One constructor, not five (`docs/plans/31-ds-compositions.plan.md`). The
/// five named constructors were driven by a private `enum _RowKind` and three
/// private fields that each constructor initialised to placeholders it did not
/// use — `.toggle` even shadowed `value` with a parameter of the same name and
/// then set the field to null, which compiled and was a trap.
///
/// Underneath, all five were a row with a label, a description, an optional
/// leading glyph and something on the trailing edge, which is [DSControlTile]
/// — the row `DSSwitchTile` and `DSSlider` are also built on. The five kinds
/// are now what goes in [trailing]:
///
///   * navigates — `trailing: const DSChevron()`, plus [onTap];
///   * toggles — a [DSSwitchTile], which this row does not need to wrap;
///   * reports a value — [value], rendered as secondary text;
///   * acts — [tone] plus [onTap];
///   * anything else — [trailing].
///
/// `Color? labelColor` is deleted for [tone], the same open-hole fix plans 14,
/// 28 and 30 make: a colour with no meaning behind it cannot be checked for
/// contrast and does not move with the theme.
class DSSettingsRow extends StatelessWidget implements DSLeadingRow {
  const DSSettingsRow({
    super.key,
    required this.label,
    this.description,
    this.value,
    this.icon,
    this.leading,
    this.trailing,
    this.onTap,
    this.tone = DSTone.neutral,
    this.enabled = true,
  });

  final String label;
  final String? description;

  /// Read-only text on the trailing edge — "2.4.1", "System". Ignored when
  /// [trailing] is given, because two answers on one edge is one too many.
  ///
  /// Short, and breakable. `ListTile` lays the trailing slot out before the
  /// title and gives the title what is left, so a long value takes the row and
  /// the label it answers ellipsises to nothing. Anything longer than a word or
  /// two — an email address, a file path — goes in [description], under the
  /// label rather than beside it.
  final String? value;

  final IconData? icon;

  /// Replaces the leading glyph.
  final Widget? leading;

  /// A [DSChevron], a [Text], a control, anything.
  final Widget? trailing;

  final VoidCallback? onTap;

  /// What the row means. `DSTone.error` is the destructive row — Sign out,
  /// Delete account.
  final DSTone tone;

  final bool enabled;

  @override
  bool leadsWith(BuildContext context) => icon != null || leading != null;

  @override
  Widget build(BuildContext context) {
    final trailingWidget =
        trailing ??
        (value == null
            ? null
            : Text(
                value!,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: DSTextRole.bodySupport.styleOf(context),
              ));

    return DSListTile(
      title: label,
      subtitle: description,
      leading: leading ?? (icon == null ? null : Icon(icon)),
      trailing: trailingWidget,
      tone: tone,
      onTap: enabled ? onTap : null,
      // Only a row that goes somewhere gets the chevron, and only when it has
      // nothing else on that edge. A read-only row with one is a promise of a
      // destination that does not exist.
      style: DSListTileStyle(chevron: trailingWidget == null && onTap != null),
    );
  }
}
