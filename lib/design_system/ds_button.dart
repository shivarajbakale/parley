// ds-tier: 1 — atom

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/_tap_target.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_pressable.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The five things a button can *mean*.
///
/// Not five colours: colour is layer 2 of the resolution chain, and a green
/// "Retry" is still a secondary action. The fourteen this replaces included
/// `success`, `warning`, `info`, `tertiary`, `tertiaryTonal`, `tonal`,
/// `surfaceElevated`, `surfaceFilled` and `link` — nine of which were the same
/// filled button in a different colour, and none of which changed what
/// pressing it did.
enum DSButtonVariant {
  /// The one action this screen is for. At most one per view.
  primary,

  /// A real action, not the main one. Tonal, so it reads as a control rather
  /// than as the destination.
  secondary,

  /// Equal weight to [secondary], where a fill would compete with the content
  /// behind it — over media, inside a card.
  outlined,

  /// An action that must be available and must not draw the eye: Cancel,
  /// Skip, Show more.
  ghost,

  /// An action that removes something the user cannot get back. It changes
  /// the confirm idiom and the haptic as well as the fill, which is why it is
  /// a variant and `success` is not.
  destructive,
}

enum DSButtonSize { sm, md, lg }

/// [DSButton]'s appearance, as data — and the place the nine deleted variants
/// now live.
///
/// `success` used to be an enum case and a switch arm. It is now
/// `DSButtonStyle(fillColor: palette.success, labelColor:
/// palette.onSuccess)`, reachable at any of the four layers.
@immutable
class DSButtonStyle extends DSComponentStyle<DSButtonStyle> {
  const DSButtonStyle({
    this.height,
    this.padding,
    this.radius,
    this.fillColor,
    this.fillGradient,
    this.labelColor,
    this.outlineColor,
    this.outlineWidth,
    this.disabledFill,
    this.disabledLabel,
    this.pressedOverlay,
    this.labelStyle,
    this.iconSize,
    this.iconGap,
    this.elevation,
  });

  final double? height;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? radius;
  final Color? fillColor;

  /// Paints the *background* only. The `ShaderMask` this replaces modulated
  /// the whole subtree, which cost a `saveLayer` per button and could tint the
  /// label into unreadability.
  final Gradient? fillGradient;

  final Color? labelColor;
  final Color? outlineColor;
  final double? outlineWidth;

  /// Disabled is not the fill at 38% alpha. That measured 1.18:1 in the
  /// identity this replaces; WCAG exempts disabled controls from the ratio,
  /// and users do not.
  final Color? disabledFill;
  final Color? disabledLabel;

  final double? pressedOverlay;
  final TextStyle? labelStyle;
  final double? iconSize;
  final double? iconGap;
  final double? elevation;

  @override
  DSButtonStyle merge(DSButtonStyle? other) {
    if (other == null) return this;
    return DSButtonStyle(
      height: other.height ?? height,
      padding: other.padding ?? padding,
      radius: other.radius ?? radius,
      fillColor: other.fillColor ?? fillColor,
      fillGradient: other.fillGradient ?? fillGradient,
      labelColor: other.labelColor ?? labelColor,
      outlineColor: other.outlineColor ?? outlineColor,
      outlineWidth: other.outlineWidth ?? outlineWidth,
      disabledFill: other.disabledFill ?? disabledFill,
      disabledLabel: other.disabledLabel ?? disabledLabel,
      pressedOverlay: other.pressedOverlay ?? pressedOverlay,
      labelStyle: other.labelStyle ?? labelStyle,
      iconSize: other.iconSize ?? iconSize,
      iconGap: other.iconGap ?? iconGap,
      elevation: other.elevation ?? elevation,
    );
  }

  @override
  DSButtonStyle copyWith({
    double? height,
    EdgeInsetsGeometry? padding,
    BorderRadius? radius,
    Color? fillColor,
    Gradient? fillGradient,
    Color? labelColor,
    Color? outlineColor,
    double? outlineWidth,
    Color? disabledFill,
    Color? disabledLabel,
    double? pressedOverlay,
    TextStyle? labelStyle,
    double? iconSize,
    double? iconGap,
    double? elevation,
  }) => DSButtonStyle(
    height: height ?? this.height,
    padding: padding ?? this.padding,
    radius: radius ?? this.radius,
    fillColor: fillColor ?? this.fillColor,
    fillGradient: fillGradient ?? this.fillGradient,
    labelColor: labelColor ?? this.labelColor,
    outlineColor: outlineColor ?? this.outlineColor,
    outlineWidth: outlineWidth ?? this.outlineWidth,
    disabledFill: disabledFill ?? this.disabledFill,
    disabledLabel: disabledLabel ?? this.disabledLabel,
    pressedOverlay: pressedOverlay ?? this.pressedOverlay,
    labelStyle: labelStyle ?? this.labelStyle,
    iconSize: iconSize ?? this.iconSize,
    iconGap: iconGap ?? this.iconGap,
    elevation: elevation ?? this.elevation,
  );

  @override
  DSButtonStyle lerp(DSButtonStyle? other, double t) {
    if (other == null) return this;
    return DSButtonStyle(
      height: lerpDouble(height, other.height, t),
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t),
      radius: BorderRadius.lerp(radius, other.radius, t),
      fillColor: Color.lerp(fillColor, other.fillColor, t),
      fillGradient: Gradient.lerp(fillGradient, other.fillGradient, t),
      labelColor: Color.lerp(labelColor, other.labelColor, t),
      outlineColor: Color.lerp(outlineColor, other.outlineColor, t),
      outlineWidth: lerpDouble(outlineWidth, other.outlineWidth, t),
      disabledFill: Color.lerp(disabledFill, other.disabledFill, t),
      disabledLabel: Color.lerp(disabledLabel, other.disabledLabel, t),
      pressedOverlay: lerpDouble(pressedOverlay, other.pressedOverlay, t),
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t),
      iconSize: lerpDouble(iconSize, other.iconSize, t),
      iconGap: lerpDouble(iconGap, other.iconGap, t),
      elevation: lerpDouble(elevation, other.elevation, t),
    );
  }

  /// Which scale applies. An explicit size wins; a null one takes the ambient
  /// [DSScope.size] — which is how [DSButtonGroup] sizes its children without
  /// forcing them.
  static DSButtonSize sizeOf(BuildContext context, DSButtonSize? size) {
    if (size != null) return size;
    return switch (DSScope.sizeOf(context)) {
      DSSize.sm => DSButtonSize.sm,
      DSSize.lg => DSButtonSize.lg,
      DSSize.md || null => DSButtonSize.md,
    };
  }

  static DSButtonStyle resolve(
    BuildContext context,
    DSButtonVariant variant,
    DSButtonSize? size, [
    DSButtonStyle? own,
  ]) {
    final palette = context.palette;
    final design = context.design;
    final space = design.space;
    final text = Theme.of(context).textTheme;
    final scale = sizeOf(context, size);

    // The ramp is monotonic in all three of size, weight and tracking. The
    // one this replaces ran w500 → w700 → w500, which is why a medium button
    // beside a large one read as a different component rather than a smaller
    // one.
    final (height, padding, label, icon) = switch (scale) {
      DSButtonSize.sm => (
        design.component.buttonHeightSm,
        space.md,
        text.labelMedium,
        design.component.iconSizeSmall,
      ),
      DSButtonSize.md => (
        design.component.buttonHeight,
        space.xl - space.xs,
        text.labelLarge,
        design.component.iconSize - space.xs,
      ),
      DSButtonSize.lg => (
        design.component.buttonHeightLg,
        space.xl,
        text.titleMedium,
        design.component.iconSize - space.xs,
      ),
    };

    final (fill, labelColor, outline) = switch (variant) {
      DSButtonVariant.primary => (
        palette.primary,
        palette.primaryForeground,
        null,
      ),
      DSButtonVariant.secondary => (
        palette.secondary,
        palette.secondaryForeground,
        null,
      ),
      DSButtonVariant.outlined => (null, palette.foreground, palette.border),
      DSButtonVariant.ghost => (null, palette.primary, null),
      DSButtonVariant.destructive => (
        palette.destructive,
        palette.onDestructive,
        null,
      ),
    };

    return resolveStyle(
      context: context,
      specDefaults: DSButtonStyle(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: padding),
        radius: BorderRadius.all(
          Radius.circular(context.radiusOf(AppShape.control)),
        ),
        fillColor: fill,
        // The brand moment. Painted only while enabled — the build already
        // passes `gradient: _enabled ? resolved.fillGradient : null` — so a
        // disabled primary falls back to `disabledFill` on its own.
        fillGradient: variant == DSButtonVariant.primary
            ? palette.primaryGradient
            : null,
        labelColor: labelColor,
        outlineColor: outline,
        outlineWidth: design.component.hairlineWidth,
        disabledFill: variant == DSButtonVariant.ghost ? null : palette.muted,
        // Reachable but clearly unavailable. `textSecondary` rather than
        // `textTertiary` because gate K2 holds it to 4.5:1 on all three
        // surface roles including `well`, and a disabled label a reader
        // cannot find is a defect rather than an affordance.
        disabledLabel: palette.mutedForeground,
        pressedOverlay: 0.08,
        labelStyle: label?.copyWith(
          fontWeight: context.design.type.emphasisWeight,
        ),
        iconSize: icon,
        iconGap: space.sm,
        // A filled button sits one step off whatever it is on — the contact
        // shadow says it can be pressed. Outlined and ghost buttons stay flat:
        // they have no fill to lift, and a shadow under a hairline reads as a
        // smudge.
        elevation: switch (variant) {
          DSButtonVariant.primary ||
          DSButtonVariant.secondary ||
          DSButtonVariant.destructive => context.design.elevation.low,
          DSButtonVariant.outlined || DSButtonVariant.ghost => 0,
        },
      ),
      own: own,
    );
  }
}

/// The primary action control.
///
/// See `docs/plans/08-ds-button.plan.md`. One class, five variants, and every
/// other appearance reached through [DSButtonStyle] rather than through the
/// enum.
///
/// There is no `enabled`. A button's only purpose is to be pressed, so
/// `onPressed: null` already says disabled and says nothing else — Flutter's
/// own convention.
///
/// There is no `isIconOnly`: an icon with no label is a `DSIconButton`, which
/// owns the tooltip and the required semantic label a label-less button
/// silently skipped. There is no `useBrandGradient`: a gradient is
/// [DSButtonStyle.fillGradient], which paints the background instead of
/// modulating the subtree. There is no `loadingType`: the button keeps its
/// label and gains a leading spinner, because a button that becomes a spinner
/// loses the user's place and reflows the layout. When the button has an
/// [icon] the spinner takes its place and the width does not move at all; a
/// button with no icon widens by the spinner, because reserving a slot for one
/// in every button in the kit to hold one case still is the worse trade.
class DSButton extends StatefulWidget {
  const DSButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = DSButtonVariant.primary,
    this.size,
    this.icon,
    this.loading = false,
    this.fullWidth = false,
    this.autofocus = false,
    this.focusNode,
    this.style,
    this.labelSlot,
    this.iconSlot,
    this.trailing,
    this.loadingIndicator,
  });

  final String label;

  /// Null is disabled.
  final VoidCallback? onPressed;

  final DSButtonVariant variant;

  /// Null takes the ambient [DSScope.size] — see [DSButtonGroup].
  final DSButtonSize? size;

  /// Stays `IconData` in the convenience: the button tints it, sizes it and
  /// mirrors it for RTL, and a `Widget` here would lose all three silently.
  /// [iconSlot] is the hatch.
  final IconData? icon;

  final bool loading;

  /// Layout, not appearance — the alternative is every caller wrapping in a
  /// `SizedBox(width: double.infinity)`.
  final bool fullWidth;

  /// Whether this button takes focus when its surface opens.
  ///
  /// A dialog's default action is the one Return activates, and which action
  /// that is, is a decision about consequences: `showDSConfirm` focuses the
  /// confirming action, except on a destructive confirm, where it focuses
  /// cancel. That rule needs somewhere to land, and this is it.
  final bool autofocus;

  final FocusNode? focusNode;

  final DSButtonStyle? style;

  final Widget? labelSlot;
  final Widget? iconSlot;

  /// A chevron, a badge, a keyboard hint.
  final Widget? trailing;

  /// A consumer with a branded loader replaces it and keeps everything else.
  final Widget? loadingIndicator;

  @override
  State<DSButton> createState() => _DSButtonState();
}

class _DSButtonState extends State<DSButton> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scopeEnabled = DSScope.enabledOf(context) ?? true;
  }

  /// A container may disable a whole group of buttons at once — the pinned
  /// action bar does exactly that while it is submitting — so the scope is
  /// part of the answer, not just this button's own two fields.
  bool _scopeEnabled = true;

  bool get _enabled =>
      widget.onPressed != null && !widget.loading && _scopeEnabled;

  void _press() {
    switch (widget.variant) {
      case DSButtonVariant.destructive:
        AppHaptics.warning();
      case DSButtonVariant.primary:
      case DSButtonVariant.secondary:
      case DSButtonVariant.outlined:
        AppHaptics.selection();
      case DSButtonVariant.ghost:
      // A Cancel that buzzes is a Cancel that feels consequential.
    }
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final resolved = DSButtonStyle.resolve(
      context,
      widget.variant,
      widget.size,
      widget.style,
    );
    final height = resolved.height ?? context.design.component.buttonHeight;
    final gap = resolved.iconGap ?? context.design.space.sm;
    final iconSize = resolved.iconSize ?? context.design.component.iconSize;

    final Color? fill = _enabled
        ? resolved.fillColor
        : (resolved.fillColor == null ? null : resolved.disabledFill);
    final Color labelColor = _enabled
        ? (resolved.labelColor ?? palette.foreground)
        : (resolved.disabledLabel ?? palette.mutedForeground);

    final Widget? leadingGlyph = widget.loading
        ? (widget.loadingIndicator ??
              SizedBox.square(
                dimension: iconSize,
                child: CircularProgressIndicator(
                  strokeWidth: context.design.component.hairlineWidth * 2,
                  color: labelColor,
                ),
              ))
        : (widget.iconSlot ??
              (widget.icon == null
                  ? null
                  : ExcludeSemantics(
                      child: Icon(
                        widget.icon,
                        size: iconSize,
                        color: labelColor,
                      ),
                    )));

    final content = Row(
      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leadingGlyph != null) ...[leadingGlyph, SizedBox(width: gap)],
        Flexible(
          child:
              widget.labelSlot ??
              Text(
                widget.label,
                style: resolved.labelStyle?.copyWith(
                  // The label dims rather than disappearing while loading;
                  // it is what tells the user which button they pressed.
                  color: widget.loading
                      ? labelColor.withValues(alpha: 0.7)
                      : labelColor,
                ),
                textAlign: TextAlign.center,
                // Never ellipsised: a truncated action label is an unknown
                // action, so the button grows instead.
                softWrap: true,
              ),
        ),
        if (widget.trailing != null) ...[
          SizedBox(width: gap),
          widget.trailing!,
        ],
      ],
    );

    // The shape comes from the spec rather than from a radius, so an Apple
    // build gets the continuous curve the platform draws and not a circular
    // arc that is nearly it.
    final OutlinedBorder shape = context
        .shapeOf(AppShape.control)
        .copyWith(
          side: resolved.outlineColor == null
              ? BorderSide.none
              : BorderSide(
                  color: _enabled ? resolved.outlineColor! : palette.borderSoft,
                  width: resolved.outlineWidth ?? 1,
                ),
        );

    Widget button = DecoratedBox(
      decoration: ShapeDecoration(
        color: (resolved.fillGradient == null || !_enabled) ? fill : null,
        gradient: _enabled ? resolved.fillGradient : null,
        shape: shape,
        shadows: _enabled
            ? context.design.elevation.resolve(
                elevation: resolved.elevation ?? 0,
                brightness: palette.brightness,
                shadowColor: palette.overlay,
              )
            : const [],
      ),
      child: DSInkSurface(
        onTap: _enabled ? _press : null,
        autofocus: widget.autofocus && _enabled,
        focusNode: widget.focusNode,
        shape: shape,
        highlightColor: labelColor.withValues(
          alpha: resolved.pressedOverlay ?? 0.08,
        ),
        // The button sets its own floor on both axes just below, and its
        // `height` is the identity's, which a `sm` button holds under the tap
        // floor deliberately — the box around it is a `DSTapTarget`.
        minTapTarget: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: height,
            // The painted pill is never narrower than the floor either — a
            // 48-point-wide fill under a two-letter label, rather than a
            // pill pinched around the text with the target floating around
            // it.
            minWidth: context.design.component.minTapTarget,
          ),
          child: Padding(
            padding:
                resolved.padding ??
                EdgeInsets.symmetric(horizontal: context.design.space.lg),
            // heightFactor as well as widthFactor: a Center with only one
            // of the two expands in the other direction, which is a button
            // as tall as the screen it is on.
            child: Center(
              widthFactor: widget.fullWidth ? null : 1,
              heightFactor: 1,
              child: content,
            ),
          ),
        ),
      ),
    );

    // The focus ring comes from DSPressable, like every other control's. The
    // button used to grow its own: a Container with a border and a point of
    // padding, which added eight points to the button the moment it was
    // focused — a keyboard user tabbing down a form watched the layout move
    // under them. DSFocusRing paints outside the bounds and costs no layout.
    button = DSPressable(enabled: _enabled, focusShape: shape, child: button);

    // The visual may be shorter than the floor; the target is not. A small
    // button paints 36 and a medium one 40 on Apple, both deliberately — and
    // both measured what they painted, because the only floor the button
    // carried was on its width. `DSTapTarget` centres the pill in a box the
    // full 48 and forwards a hit in the margin to it, which is what makes the
    // twelve points that are not painted still belong to the button.
    button = DSTapTarget(child: button);

    if (widget.fullWidth) {
      button = SizedBox(width: double.infinity, child: button);
    }

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.loading ? '${widget.label}, loading' : widget.label,
      // Declared here because `excludeSemantics` removes the one the control
      // publishes for itself. Without it the node says "button", says what the
      // button is for, and offers nothing to activate — VoiceOver's double-tap
      // and TalkBack's click both arrive as this action.
      onTap: _enabled ? _press : null,
      excludeSemantics: true,
      child: button,
    );
  }
}

/// The intended occupant of [DSButton.iconSlot], for a caller who needs a
/// glyph the button did not size.
class DSButtonIcon extends StatelessWidget {
  const DSButtonIcon({super.key, required this.icon, this.size});

  final IconData icon;
  final double? size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Icon(
      icon,
      size: size ?? context.design.component.iconSize - context.design.space.xs,
    ),
  );
}

/// A count beside a label — the intended occupant of [DSButton.trailing].
class DSButtonCount extends StatelessWidget {
  const DSButtonCount({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final space = context.design.space;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.palette.sheen.withValues(alpha: 0.16),
        borderRadius: BorderRadius.all(
          Radius.circular(context.radiusOf(AppShape.pill)),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: space.xs),
        child: Text('$count', style: Theme.of(context).textTheme.labelSmall),
      ),
    );
  }
}

/// How a [DSButtonGroup] arranges its children.
enum DSButtonGroupLayout {
  /// Side by side.
  row,

  /// Stacked, most important first.
  column,

  /// The last child pinned to the trailing edge, the rest to the leading one —
  /// the Cancel / Confirm idiom.
  split,
}

/// Several buttons that belong together.
///
/// Takes `List<Widget>`, never `List<DSButton>`: typing a container to a
/// concrete child class forbids every composed button — one behind a
/// `Consumer`, one wrapped in a `Tooltip`, a caller's own control that
/// satisfies the same contract.
///
/// The size is *installed* as a [DSScope] rather than forced on each child, so
/// a button that asked for its own size still gets it.
class DSButtonGroup extends StatelessWidget {
  const DSButtonGroup({
    super.key,
    required this.children,
    this.size,
    this.layout = DSButtonGroupLayout.row,
    this.fullWidth = false,
  });

  final List<Widget> children;
  final DSSize? size;
  final DSButtonGroupLayout layout;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final gap = context.design.space.sm;

    Widget group = switch (layout) {
      DSButtonGroupLayout.column => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            children[i],
          ],
        ],
      ),
      DSButtonGroupLayout.split => Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i == children.length - 1 && children.length > 1) const Spacer(),
            if (i > 0 && i != children.length - 1) SizedBox(width: gap),
            children[i],
          ],
        ],
      ),
      DSButtonGroupLayout.row => Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            if (fullWidth) Expanded(child: children[i]) else children[i],
          ],
        ],
      ),
    };

    if (size != null) {
      // Captured before the reassignment: a closure that read `group` would
      // read the Builder being assigned to it and rebuild itself forever.
      final inner = group;
      group = Builder(
        builder: (context) => DSScope.merge(context, size: size, child: inner),
      );
    }
    return group;
  }
}
