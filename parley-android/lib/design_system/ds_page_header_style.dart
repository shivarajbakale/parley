// ds-tier: 0 — foundation

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_text_style.dart';
import 'package:parley_android/theme/app_platform.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// How a page header looks, at every layer of the resolution chain.
@immutable
class DSPageHeaderStyle extends DSComponentStyle<DSPageHeaderStyle> {
  const DSPageHeaderStyle({
    this.expandedHeight,
    this.collapsedTitleStart,
    this.toolbarHeight,
    this.padding,
    this.eyebrowStyle,
    this.titleStyle,
    this.compactTitleStyle,
    this.titleColor,
    this.surface,
    this.compactHeight,
    this.subtitleStyle,
  });

  final double? expandedHeight;
  final double? collapsedTitleStart;
  final double? toolbarHeight;
  final EdgeInsetsGeometry? padding;
  final TextStyle? eyebrowStyle;

  /// The page title, on the two headers that carry one: the large bar's
  /// editorial title and the fixed header's. Not the compact bar's — see
  /// [compactTitleStyle].
  final TextStyle? titleStyle;

  /// The toolbar title, which is a smaller number and always has been.
  ///
  /// It exists because [titleStyle] does not fit here. A bar that has
  /// collapsed to one toolbar row is not the place for a 24pt headline, and
  /// the catalog's own titles are the proof: "DSSegmentedProgress" is one
  /// unbreakable nineteen-character word, so at a raised text scale a step up
  /// does not wrap, it truncates — which `make ui-probe` fails.
  ///
  /// The compact bar used to have no number at all: its title was a bare
  /// `Text` taking `AppBarTheme.titleTextStyle`, so the only way to move it
  /// was to restyle Material's bar for the whole app. The default here is the
  /// step it already drew.
  final TextStyle? compactTitleStyle;

  final Color? titleColor;
  final Color? surface;
  final double? compactHeight;
  final TextStyle? subtitleStyle;

  @override
  DSPageHeaderStyle merge(DSPageHeaderStyle? other) {
    if (other == null) return this;
    return DSPageHeaderStyle(
      expandedHeight: other.expandedHeight ?? expandedHeight,
      collapsedTitleStart: other.collapsedTitleStart ?? collapsedTitleStart,
      toolbarHeight: other.toolbarHeight ?? toolbarHeight,
      padding: other.padding ?? padding,
      eyebrowStyle: other.eyebrowStyle ?? eyebrowStyle,
      titleStyle: other.titleStyle ?? titleStyle,
      compactTitleStyle: other.compactTitleStyle ?? compactTitleStyle,
      titleColor: other.titleColor ?? titleColor,
      surface: other.surface ?? surface,
      compactHeight: other.compactHeight ?? compactHeight,
      subtitleStyle: other.subtitleStyle ?? subtitleStyle,
    );
  }

  @override
  DSPageHeaderStyle copyWith({
    double? expandedHeight,
    double? collapsedTitleStart,
    double? toolbarHeight,
    EdgeInsetsGeometry? padding,
    TextStyle? eyebrowStyle,
    TextStyle? titleStyle,
    TextStyle? compactTitleStyle,
    Color? titleColor,
    Color? surface,
    double? compactHeight,
    TextStyle? subtitleStyle,
  }) => DSPageHeaderStyle(
    expandedHeight: expandedHeight ?? this.expandedHeight,
    collapsedTitleStart: collapsedTitleStart ?? this.collapsedTitleStart,
    toolbarHeight: toolbarHeight ?? this.toolbarHeight,
    padding: padding ?? this.padding,
    eyebrowStyle: eyebrowStyle ?? this.eyebrowStyle,
    titleStyle: titleStyle ?? this.titleStyle,
    compactTitleStyle: compactTitleStyle ?? this.compactTitleStyle,
    titleColor: titleColor ?? this.titleColor,
    surface: surface ?? this.surface,
    compactHeight: compactHeight ?? this.compactHeight,
    subtitleStyle: subtitleStyle ?? this.subtitleStyle,
  );

  @override
  DSPageHeaderStyle lerp(DSPageHeaderStyle? other, double t) {
    if (other == null) return this;
    return DSPageHeaderStyle(
      expandedHeight: lerpDouble(expandedHeight, other.expandedHeight, t),
      collapsedTitleStart: lerpDouble(
        collapsedTitleStart,
        other.collapsedTitleStart,
        t,
      ),
      toolbarHeight: lerpDouble(toolbarHeight, other.toolbarHeight, t),
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t),
      eyebrowStyle: TextStyle.lerp(eyebrowStyle, other.eyebrowStyle, t),
      titleStyle: TextStyle.lerp(titleStyle, other.titleStyle, t),
      compactTitleStyle: TextStyle.lerp(
        compactTitleStyle,
        other.compactTitleStyle,
        t,
      ),
      titleColor: Color.lerp(titleColor, other.titleColor, t),
      surface: Color.lerp(surface, other.surface, t),
      compactHeight: lerpDouble(compactHeight, other.compactHeight, t),
      subtitleStyle: TextStyle.lerp(subtitleStyle, other.subtitleStyle, t),
    );
  }

  static DSPageHeaderStyle resolve(
    BuildContext context, [
    DSPageHeaderStyle? own,
  ]) {
    final design = context.design;
    final component = design.component;
    final space = design.space;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    return resolveStyle(
      context: context,
      specDefaults: DSPageHeaderStyle(
        expandedHeight: component.headerExpandedHeight,
        collapsedTitleStart: component.headerCollapsedTitleStart,
        toolbarHeight: kToolbarHeight,
        padding: EdgeInsets.fromLTRB(
          space.pageGutter,
          space.xs,
          space.pageGutter,
          space.md,
        ),
        eyebrowStyle: DSTextRole.eyebrow.styleOf(context),
        // The one step this file still names by hand, and [compactTitleStyle]
        // says why: `screenTitle` is a step above it, and a compact bar drawn
        // at that step truncates the catalog's own longest title under `make
        // ui-probe`. Either the role or the bar is wrong and finding out which
        // is a decision about every dialog and sheet as well, so it is not
        // made as a side effect of this file's conversion.
        compactTitleStyle: text.titleLarge,
        titleStyle: DSTextRole.pageTitle.styleOf(context, emphasis: true),
        titleColor: palette.foreground,
        surface: palette.card,
        compactHeight: AppPlatform.isApple(context)
            ? component.headerCompactHeightApple
            : component.headerCompactHeight,
        // bodySmall, not bodyMedium. The expanded title block is painted at
        // `_expandedTitleScale` (1.25), so a subtitle specified at the body
        // size renders a step *above* the body copy it introduces.
        subtitleStyle: DSTextRole.bodyDetail.styleOf(context),
      ),
      own: own,
    );
  }
}
