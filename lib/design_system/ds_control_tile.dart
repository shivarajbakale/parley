// ds-tier: 2 — molecule

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:parley_android/design_system/ds_checkbox.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_list_tile.dart';
import 'package:parley_android/design_system/ds_radio.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_switch.dart';
import 'package:parley_android/theme/app_platform.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Which edge of the row the control sits on.
///
/// A property with a platform default rather than a convention baked in: Apple
/// puts a radio on the trailing edge of a settings row and Material puts it on
/// the leading edge, and a kit that picks one is wrong on the other half of
/// its installs.
enum DSControlPosition { leading, trailing }

/// How a labelled control row looks, at every layer of the chain.
///
/// The geometry fields are deliberately *read from* [DSListTileStyle] in
/// [resolve] rather than restated here. That is what plan 22 means by "shares
/// its geometry by construction, not by copying": a settings row and a list
/// row cannot drift, because there is one set of numbers and this reads it.
@immutable
class DSControlTileStyle extends DSComponentStyle<DSControlTileStyle> {
  const DSControlTileStyle({
    this.labelStyle,
    this.subtitleStyle,
    this.helperStyle,
    this.errorStyle,
    this.gap,
    this.verticalPadding,
    this.controlPosition,
    this.dividerVisible,
    this.highlightColor,
  });

  final TextStyle? labelStyle;
  final TextStyle? subtitleStyle;

  /// The line under the row. Two styles because an error is not a helper in a
  /// different colour — it is the one line the user has to read.
  final TextStyle? helperStyle;
  final TextStyle? errorStyle;

  /// Control to label, and the row's vertical padding. Both come from the list
  /// row's own tokens.
  final double? gap;
  final double? verticalPadding;

  final DSControlPosition? controlPosition;
  final bool? dividerVisible;

  /// The fill while the row is held. A row highlights rather than dips —
  /// [DSListTile]'s rule, for the same reason: a full-bleed row that shrinks
  /// detaches from the column it belongs to.
  final Color? highlightColor;

  @override
  DSControlTileStyle merge(DSControlTileStyle? other) {
    if (other == null) return this;
    return DSControlTileStyle(
      labelStyle: other.labelStyle ?? labelStyle,
      subtitleStyle: other.subtitleStyle ?? subtitleStyle,
      helperStyle: other.helperStyle ?? helperStyle,
      errorStyle: other.errorStyle ?? errorStyle,
      gap: other.gap ?? gap,
      verticalPadding: other.verticalPadding ?? verticalPadding,
      controlPosition: other.controlPosition ?? controlPosition,
      dividerVisible: other.dividerVisible ?? dividerVisible,
      highlightColor: other.highlightColor ?? highlightColor,
    );
  }

  @override
  DSControlTileStyle copyWith({
    TextStyle? labelStyle,
    TextStyle? subtitleStyle,
    TextStyle? helperStyle,
    TextStyle? errorStyle,
    double? gap,
    double? verticalPadding,
    DSControlPosition? controlPosition,
    bool? dividerVisible,
    Color? highlightColor,
  }) => DSControlTileStyle(
    labelStyle: labelStyle ?? this.labelStyle,
    subtitleStyle: subtitleStyle ?? this.subtitleStyle,
    helperStyle: helperStyle ?? this.helperStyle,
    errorStyle: errorStyle ?? this.errorStyle,
    gap: gap ?? this.gap,
    verticalPadding: verticalPadding ?? this.verticalPadding,
    controlPosition: controlPosition ?? this.controlPosition,
    dividerVisible: dividerVisible ?? this.dividerVisible,
    highlightColor: highlightColor ?? this.highlightColor,
  );

  @override
  DSControlTileStyle lerp(DSControlTileStyle? other, double t) {
    if (other == null) return this;
    return DSControlTileStyle(
      // Two enum-or-flag fields with no midpoint.
      controlPosition: t < 0.5 ? controlPosition : other.controlPosition,
      dividerVisible: t < 0.5 ? dividerVisible : other.dividerVisible,
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t),
      subtitleStyle: TextStyle.lerp(subtitleStyle, other.subtitleStyle, t),
      helperStyle: TextStyle.lerp(helperStyle, other.helperStyle, t),
      errorStyle: TextStyle.lerp(errorStyle, other.errorStyle, t),
      gap: lerpDouble(gap, other.gap, t),
      verticalPadding: lerpDouble(verticalPadding, other.verticalPadding, t),
      highlightColor: Color.lerp(highlightColor, other.highlightColor, t),
    );
  }

  static DSControlTileStyle resolve(
    BuildContext context, [
    DSControlTileStyle? own,
  ]) {
    final palette = context.palette;
    // Layer 1 for the shared half of this style *is* the list row's layer 1.
    // Restating `space.sm` and `space.lg` here is exactly the copy that put
    // two row heights on one settings screen.
    final row = DSListTileStyle.resolve(context, DSTone.neutral);
    return resolveStyle(
      context: context,
      specDefaults: DSControlTileStyle(
        labelStyle: row.titleStyle,
        subtitleStyle: row.subtitleStyle,
        helperStyle: DSTextRole.fieldHelper.styleOf(context),
        errorStyle: DSTextRole.fieldError.styleOf(context),
        gap: row.leadingGap,
        verticalPadding: row.verticalPadding,
        controlPosition: AppPlatform.isApple(context)
            ? DSControlPosition.trailing
            : DSControlPosition.leading,
        dividerVisible: false,
        highlightColor: palette.muted,
      ),
      own: own,
    );
  }
}

/// The labelled control row — one implementation, where there were four.
///
/// See `docs/plans/22-ds-selection-controls.plan.md` Section 1. `DSSwitch`,
/// `DSSlider` and `DSSettingsRow` each built this row by hand, character for
/// character, and two of them disagreed about the vertical padding — so a
/// settings screen with a switch above a slider had rows of two heights. It is
/// built on [DSListTile] rather than beside it, which is what makes the two
/// impossible to drift apart.
///
/// **The row is the control.** The whole row is the tap target and one
/// semantics node, so a screen reader hears "Sync over cellular, uses your
/// data plan, switch, on" rather than four nodes of which only the unnamed one
/// can be operated.
///
/// **Use when** a control needs a name beside it. **Instead:** [DSListTile]
/// when the row navigates somewhere.
class DSControlTile extends StatelessWidget implements DSLeadingRow {
  const DSControlTile({
    super.key,
    required this.label,
    this.subtitle,
    this.control,
    this.leading,
    this.trailing,
    this.labelSlot,
    this.subtitleSlot,
    this.helper,
    this.icon,
    this.helperText,
    this.errorText,
    this.onTap,
    this.controlPosition,
    this.enabled = true,
    this.loading = false,
    this.divider,
    this.checked,
    this.toggled,
    this.mixed,
    this.exclusive,
    this.style,
  }) : assert(
         icon == null ||
             control == null ||
             controlPosition != DSControlPosition.leading,
         'a leading control and a leading icon are competing for one slot — '
         'put the control on the trailing edge, or drop the icon',
       );

  final String label;
  final String? subtitle;

  /// The control this row is named for. It goes to whichever edge
  /// [controlPosition] names.
  final Widget? control;

  final Widget? leading;
  final Widget? trailing;
  final Widget? labelSlot;
  final Widget? subtitleSlot;

  /// Replaces the line under the row — a link, a chip, a field.
  final Widget? helper;

  /// The row's glyph, in the identity's leading well. Only legal when the
  /// control is on the trailing edge.
  final IconData? icon;

  final String? helperText;

  /// When set, the row is in error: the line under it takes the error style
  /// and is announced with the control rather than beside it.
  final String? errorText;

  /// Defaults to operating the control, which is what makes the whole row the
  /// target. A caller that wants the row inert passes a no-op.
  final VoidCallback? onTap;

  final DSControlPosition? controlPosition;
  final bool enabled;
  final bool loading;

  /// Whether this row draws a separator under it. Null takes the style's
  /// [DSControlTileStyle.dividerVisible].
  final bool? divider;

  /// The state the row reports to a screen reader, set by the three
  /// convenience tiles below. A caller placing their own control sets whichever
  /// of these describes it, because the control inside is excluded from the
  /// semantics tree so the row can be a single node.
  final bool? checked;
  final bool? toggled;
  final bool? mixed;
  final bool? exclusive;

  final DSControlTileStyle? style;

  @override
  bool leadsWith(BuildContext context) {
    if (icon != null || leading != null) return true;
    if (control == null) return false;
    final position =
        controlPosition ??
        DSControlTileStyle.resolve(context, style).controlPosition!;
    return position == DSControlPosition.leading;
  }

  @override
  Widget build(BuildContext context) {
    final resolved = DSControlTileStyle.resolve(context, style);
    final space = context.design.space;
    final position = controlPosition ?? resolved.controlPosition!;
    final on = enabled && (DSScope.enabledOf(context) ?? true) && !loading;

    final leadingControl = position == DSControlPosition.leading
        ? control
        : null;
    final trailingControl = position == DSControlPosition.trailing
        ? control
        : null;

    final tile = DSListTile(
      title: label,
      titleSlot: labelSlot,
      subtitle: subtitle,
      subtitleSlot: subtitleSlot,
      leading: leadingControl ?? (icon == null ? leading : Icon(icon)),
      trailing: trailingControl ?? trailing,
      onTap: on ? (onTap ?? () => _operate()) : null,
      enabled: on,
      loading: loading,
      divider: divider ?? resolved.dividerVisible!,
      style: DSListTileStyle(
        titleStyle: resolved.labelStyle,
        subtitleStyle: resolved.subtitleStyle,
        leadingGap: resolved.gap,
        verticalPadding: resolved.verticalPadding,
        // A control row never shows a chevron: the control is what the row
        // does, and a chevron beside it promises a destination there is none of.
        chevron: false,
      ),
    );

    final message = errorText ?? helperText;
    final Widget row = (helper == null && message == null)
        ? tile
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              tile,
              Padding(
                padding: EdgeInsets.fromLTRB(
                  (DSGutterScope.applied(context) ? 0.0 : space.pageGutter),
                  0,
                  (DSGutterScope.applied(context) ? 0.0 : space.pageGutter),
                  resolved.verticalPadding!,
                ),
                child:
                    helper ??
                    Text(
                      message!,
                      style: errorText != null
                          ? resolved.errorStyle
                          : resolved.helperStyle,
                    ),
              ),
            ],
          );

    // One node for the whole row. The controls inside set `inTile`, which
    // makes them draw and stay out of the semantics tree.
    return MergeSemantics(
      child: Semantics(
        checked: checked,
        toggled: toggled,
        mixed: mixed,
        inMutuallyExclusiveGroup: exclusive,
        enabled: on,
        // The error line is part of the control's announcement, not a
        // paragraph the user has to find further down the screen.
        value: errorText,
        child: row,
      ),
    );
  }

  /// Operate whatever control the row was given.
  ///
  /// The three convenience tiles below override [onTap] with their own
  /// closure, so this is only reached by a caller who passed a bare `control:`
  /// and no `onTap` — where doing nothing quietly is the wrong answer.
  void _operate() {
    assert(
      control == null,
      'a DSControlTile with a control and no onTap — the row is the target, '
      'so it has to know what operating the control means. Use '
      'DSCheckboxTile, DSSwitchTile or DSRadioTile, or pass onTap',
    );
  }
}

/// A row whose control is a checkbox.
class DSCheckboxTile extends StatelessWidget implements DSLeadingRow {
  const DSCheckboxTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.tristate = false,
    this.icon,
    this.trailing,
    this.labelSlot,
    this.subtitleSlot,
    this.helper,
    this.helperText,
    this.errorText,
    this.controlPosition,
    this.enabled = true,
    this.loading = false,
    this.divider,
    this.style,
    this.checkboxStyle,
  });

  final String label;
  final String? subtitle;
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final bool tristate;
  final IconData? icon;
  final Widget? trailing;
  final Widget? labelSlot;
  final Widget? subtitleSlot;
  final Widget? helper;
  final String? helperText;
  final String? errorText;
  final DSControlPosition? controlPosition;
  final bool enabled;
  final bool loading;
  final bool? divider;
  final DSControlTileStyle? style;
  final DSCheckboxStyle? checkboxStyle;

  @override
  bool leadsWith(BuildContext context) =>
      icon != null ||
      (controlPosition ??
              DSControlTileStyle.resolve(context, style).controlPosition!) ==
          DSControlPosition.leading;

  bool? get _next => switch (value) {
    false => true,
    true => tristate ? null : false,
    _ => false,
  };

  @override
  Widget build(BuildContext context) => DSControlTile(
    label: label,
    subtitle: subtitle,
    icon: icon,
    trailing: trailing,
    labelSlot: labelSlot,
    subtitleSlot: subtitleSlot,
    helper: helper,
    helperText: helperText,
    errorText: errorText,
    controlPosition: controlPosition,
    enabled: enabled,
    loading: loading,
    divider: divider,
    style: style,
    checked: value ?? false,
    mixed: tristate ? value == null : null,
    onTap: onChanged == null ? null : () => onChanged!(_next),
    control: DSCheckbox(
      value: value,
      tristate: tristate,
      error: errorText != null,
      onChanged: onChanged,
      style: checkboxStyle,
      inTile: true,
    ),
  );
}

/// A row whose control is a switch. The switch is always on the trailing edge:
/// a switch is the row's outcome, and both platforms put it at the end.
class DSSwitchTile extends StatelessWidget implements DSLeadingRow {
  const DSSwitchTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.labelSlot,
    this.subtitleSlot,
    this.helper,
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.loading = false,
    this.divider,
    this.style,
    this.switchStyle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData? icon;
  final Widget? labelSlot;
  final Widget? subtitleSlot;
  final Widget? helper;
  final String? helperText;
  final String? errorText;
  final bool enabled;
  final bool loading;
  final bool? divider;
  final DSControlTileStyle? style;
  final DSSwitchStyle? switchStyle;

  @override
  bool leadsWith(BuildContext context) => icon != null;

  @override
  Widget build(BuildContext context) => DSControlTile(
    label: label,
    subtitle: subtitle,
    icon: icon,
    labelSlot: labelSlot,
    subtitleSlot: subtitleSlot,
    helper: helper,
    helperText: helperText,
    errorText: errorText,
    controlPosition: DSControlPosition.trailing,
    enabled: enabled,
    loading: loading,
    divider: divider,
    style: style,
    toggled: value,
    onTap: onChanged == null ? null : () => onChanged!(!value),
    control: DSSwitch(
      value: value,
      onChanged: onChanged,
      style: switchStyle,
      inTile: true,
      compact: true,
    ),
  );
}

/// A row whose control is a radio. It reads its group from the enclosing
/// [DSRadioGroup], exactly as a bare [DSRadio] does.
class DSRadioTile<T> extends StatelessWidget implements DSLeadingRow {
  const DSRadioTile({
    super.key,
    required this.label,
    required this.value,
    this.groupValue,
    this.onChanged,
    this.subtitle,
    this.labelSlot,
    this.subtitleSlot,
    this.helper,
    this.helperText,
    this.errorText,
    this.controlPosition,
    this.enabled = true,
    this.loading = false,
    this.divider,
    this.style,
    this.radioStyle,
  });

  final String label;
  final String? subtitle;
  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;
  final Widget? labelSlot;
  final Widget? subtitleSlot;
  final Widget? helper;
  final String? helperText;
  final String? errorText;
  final DSControlPosition? controlPosition;
  final bool enabled;
  final bool loading;
  final bool? divider;
  final DSControlTileStyle? style;
  final DSRadioStyle? radioStyle;

  @override
  bool leadsWith(BuildContext context) =>
      (controlPosition ??
          DSControlTileStyle.resolve(context, style).controlPosition!) ==
      DSControlPosition.leading;

  @override
  Widget build(BuildContext context) {
    final group = DSRadioGroupBinding.of<T>(context);
    final selected = (groupValue ?? group?.value) == value;
    final change = onChanged ?? group?.onChanged;
    return DSControlTile(
      label: label,
      subtitle: subtitle,
      labelSlot: labelSlot,
      subtitleSlot: subtitleSlot,
      helper: helper,
      helperText: helperText,
      errorText: errorText,
      controlPosition: controlPosition,
      enabled: enabled,
      loading: loading,
      divider: divider,
      style: style,
      checked: selected,
      exclusive: group != null ? true : null,
      onTap: change == null ? null : () => change(value),
      control: DSRadio<T>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        enabled: enabled,
        style: radioStyle,
        inTile: true,
      ),
    );
  }
}
