// ds-tier: 1 — atom

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_overlay.dart';
import 'package:parley_android/design_system/ds_text_field.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// [DSSelect]'s appearance, as data.
@immutable
class DSSelectStyle extends DSComponentStyle<DSSelectStyle> {
  const DSSelectStyle({
    this.fieldStyle,
    this.chevronIcon,
    this.chevronSize,
    this.optionHeight,
    this.optionPadding,
    this.optionGap,
    this.checkIcon,
    this.listPadding,
    this.maxVisibleOptions,
    this.sectionHeaderStyle,
    this.separatorColor,
    this.triggerChipLimit,
    this.presentation,
    this.searchThreshold,
  });

  /// The trigger's skin. Null inherits [DSTextField]'s, which is the point:
  /// a select and a text field in one form are one control with two ways of
  /// changing a value.
  final DSTextFieldStyle? fieldStyle;

  final IconData? chevronIcon;
  final double? chevronSize;
  final double? optionHeight;
  final EdgeInsetsGeometry? optionPadding;
  final double? optionGap;
  final IconData? checkIcon;
  final EdgeInsetsGeometry? listPadding;

  /// How many rows are visible before the list scrolls. Resolved against the
  /// row's *actual* height, so the surface does not clip a row in half at
  /// text scale 2.0 — which the `240`-point ceiling this replaces did.
  final int? maxVisibleOptions;

  final TextStyle? sectionHeaderStyle;
  final Color? separatorColor;

  /// How many chips a multi-select's trigger shows before it counts.
  final int? triggerChipLimit;

  final DSOverlayPresentation? presentation;

  /// The option count above which a search field appears without being asked
  /// for. A default, not a rule: `showSearch` overrides it in both
  /// directions.
  final int? searchThreshold;

  @override
  DSSelectStyle merge(DSSelectStyle? other) {
    if (other == null) return this;
    return DSSelectStyle(
      fieldStyle: other.fieldStyle ?? fieldStyle,
      chevronIcon: other.chevronIcon ?? chevronIcon,
      chevronSize: other.chevronSize ?? chevronSize,
      optionHeight: other.optionHeight ?? optionHeight,
      optionPadding: other.optionPadding ?? optionPadding,
      optionGap: other.optionGap ?? optionGap,
      checkIcon: other.checkIcon ?? checkIcon,
      listPadding: other.listPadding ?? listPadding,
      maxVisibleOptions: other.maxVisibleOptions ?? maxVisibleOptions,
      sectionHeaderStyle: other.sectionHeaderStyle ?? sectionHeaderStyle,
      separatorColor: other.separatorColor ?? separatorColor,
      triggerChipLimit: other.triggerChipLimit ?? triggerChipLimit,
      presentation: other.presentation ?? presentation,
      searchThreshold: other.searchThreshold ?? searchThreshold,
    );
  }

  @override
  DSSelectStyle copyWith({
    DSTextFieldStyle? fieldStyle,
    IconData? chevronIcon,
    double? chevronSize,
    double? optionHeight,
    EdgeInsetsGeometry? optionPadding,
    double? optionGap,
    IconData? checkIcon,
    EdgeInsetsGeometry? listPadding,
    int? maxVisibleOptions,
    TextStyle? sectionHeaderStyle,
    Color? separatorColor,
    int? triggerChipLimit,
    DSOverlayPresentation? presentation,
    int? searchThreshold,
  }) => DSSelectStyle(
    fieldStyle: fieldStyle ?? this.fieldStyle,
    chevronIcon: chevronIcon ?? this.chevronIcon,
    chevronSize: chevronSize ?? this.chevronSize,
    optionHeight: optionHeight ?? this.optionHeight,
    optionPadding: optionPadding ?? this.optionPadding,
    optionGap: optionGap ?? this.optionGap,
    checkIcon: checkIcon ?? this.checkIcon,
    listPadding: listPadding ?? this.listPadding,
    maxVisibleOptions: maxVisibleOptions ?? this.maxVisibleOptions,
    sectionHeaderStyle: sectionHeaderStyle ?? this.sectionHeaderStyle,
    separatorColor: separatorColor ?? this.separatorColor,
    triggerChipLimit: triggerChipLimit ?? this.triggerChipLimit,
    presentation: presentation ?? this.presentation,
    searchThreshold: searchThreshold ?? this.searchThreshold,
  );

  @override
  DSSelectStyle lerp(DSSelectStyle? other, double t) {
    if (other == null) return this;
    return DSSelectStyle(
      fieldStyle: fieldStyle?.lerp(other.fieldStyle, t) ?? other.fieldStyle,
      chevronIcon: t < 0.5 ? chevronIcon : other.chevronIcon,
      chevronSize: lerpDouble(chevronSize, other.chevronSize, t),
      optionHeight: lerpDouble(optionHeight, other.optionHeight, t),
      optionPadding: EdgeInsetsGeometry.lerp(
        optionPadding,
        other.optionPadding,
        t,
      ),
      optionGap: lerpDouble(optionGap, other.optionGap, t),
      checkIcon: t < 0.5 ? checkIcon : other.checkIcon,
      listPadding: EdgeInsetsGeometry.lerp(listPadding, other.listPadding, t),
      maxVisibleOptions: t < 0.5 ? maxVisibleOptions : other.maxVisibleOptions,
      sectionHeaderStyle: TextStyle.lerp(
        sectionHeaderStyle,
        other.sectionHeaderStyle,
        t,
      ),
      separatorColor: Color.lerp(separatorColor, other.separatorColor, t),
      triggerChipLimit: t < 0.5 ? triggerChipLimit : other.triggerChipLimit,
      presentation: t < 0.5 ? presentation : other.presentation,
      searchThreshold: t < 0.5 ? searchThreshold : other.searchThreshold,
    );
  }

  static DSSelectStyle resolve(BuildContext context, [DSSelectStyle? own]) {
    final design = context.design;
    final palette = context.palette;
    final type = Theme.of(context).textTheme;

    final specDefaults = DSSelectStyle(
      chevronIcon: Icons.keyboard_arrow_down,
      chevronSize: design.component.iconSizeInline,
      optionHeight: design.component.minTapTarget,
      // The page gutter, which is the token `DSOverlayHeader` pads on.
      //
      // These rows sit under that header, and at `space.md` they sat 4 points
      // proud of their own title — the select was the one surface in the kit
      // whose header did not line up with its own content. The pairing is
      // the point, not the number: whatever the header insets on, these rows
      // inset on the same thing. `ds_select_test` asserts the two edges
      // rather than either value, so moving one without the other fails
      // there rather than in a screenshot.
      //
      // Both moved from `lg` to the gutter together when the first screen
      // mounted a sheet *on* the page rather than over it: `ui-probe`'s
      // `gutter` rule reads a screen's reading edge, and at `lg` a sheet's
      // title started four points inside every other run of text on the page.
      optionPadding: EdgeInsets.symmetric(
        horizontal: design.space.pageGutter,
        vertical: design.space.sm,
      ),
      optionGap: design.space.sm,
      checkIcon: Icons.check,
      // Zero, now that the rows carry their own vertical padding.
      //
      // It was `space.xs`, and it stacked on top of the header's own bottom
      // padding: the first option sat 28 points below the title while the
      // rows below it were flush against each other, which is the rhythm
      // inverted. The list's edges are the rows' business.
      listPadding: EdgeInsets.zero,
      maxVisibleOptions: 6,
      sectionHeaderStyle: type.labelSmall?.copyWith(
        color: palette.mutedForeground,
      ),
      separatorColor: palette.borderSoft,
      triggerChipLimit: 2,
      presentation: DSOverlayPresentation.menu,
      searchThreshold: 15,
    );

    return resolveStyle<DSSelectStyle>(
      context: context,
      specDefaults: specDefaults,
      own: own,
    );
  }
}
