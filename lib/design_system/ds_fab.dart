// ds-tier: 1 — atom

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:parley_android/design_system/_tap_target.dart';
import 'package:parley_android/design_system/ds_bottom_insets.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_pressable.dart';
import 'package:parley_android/theme/app_materials.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// How a floating action button looks, at every layer of the chain.
///
/// There is one size. `DSFabSize { sm, md, lg }` is gone along with
/// `DSFabVariant { standard, extended }` before it: a button that comes in
/// three sizes invites two of them on one screen arguing about which is
/// primary, and the kit's answer to that argument is to not offer the
/// choice.
@immutable
class DSFabStyle extends DSComponentStyle<DSFabStyle> {
  const DSFabStyle({
    this.size,
    this.extendedHeight,
    this.iconSize,
    this.shape,
    this.fill,
    this.foreground,
    this.margin,
    this.hideOnScroll,
  });

  final double? size;
  final double? extendedHeight;
  final double? iconSize;
  final AppShape? shape;
  final Color? fill;
  final Color? foreground;

  /// How far the button keeps from the edges it floats over.
  final double? margin;

  /// Whether the button steps out of the way while the content scrolls
  /// forward. An extended button collapses to its glyph instead of leaving,
  /// which is the softer form and the one both platforms ship.
  final bool? hideOnScroll;

  @override
  DSFabStyle merge(DSFabStyle? other) {
    if (other == null) return this;
    return DSFabStyle(
      size: other.size ?? size,
      extendedHeight: other.extendedHeight ?? extendedHeight,
      iconSize: other.iconSize ?? iconSize,
      shape: other.shape ?? shape,
      fill: other.fill ?? fill,
      foreground: other.foreground ?? foreground,
      margin: other.margin ?? margin,
      hideOnScroll: other.hideOnScroll ?? hideOnScroll,
    );
  }

  @override
  DSFabStyle copyWith({
    double? size,
    double? extendedHeight,
    double? iconSize,
    AppShape? shape,
    Color? fill,
    Color? foreground,
    double? margin,
    bool? hideOnScroll,
  }) => DSFabStyle(
    size: size ?? this.size,
    extendedHeight: extendedHeight ?? this.extendedHeight,
    iconSize: iconSize ?? this.iconSize,
    shape: shape ?? this.shape,
    fill: fill ?? this.fill,
    foreground: foreground ?? this.foreground,
    margin: margin ?? this.margin,
    hideOnScroll: hideOnScroll ?? this.hideOnScroll,
  );

  @override
  DSFabStyle lerp(DSFabStyle? other, double t) {
    if (other == null) return this;
    return DSFabStyle(
      size: lerpDouble(size, other.size, t),
      extendedHeight: lerpDouble(extendedHeight, other.extendedHeight, t),
      iconSize: lerpDouble(iconSize, other.iconSize, t),
      shape: t < 0.5 ? shape : other.shape,
      fill: Color.lerp(fill, other.fill, t),
      foreground: Color.lerp(foreground, other.foreground, t),
      margin: lerpDouble(margin, other.margin, t),
      hideOnScroll: t < 0.5 ? hideOnScroll : other.hideOnScroll,
    );
  }

  static DSFabStyle resolve(BuildContext context, {DSFabStyle? own}) {
    final design = context.design;
    final component = design.component;
    final palette = context.palette;

    return resolveStyle(
      context: context,
      specDefaults: DSFabStyle(
        size: component.fabSize,
        extendedHeight: component.fabSize,
        iconSize: component.iconSize,
        shape: AppShape.pill,
        fill: palette.primary,
        foreground: palette.primaryForeground,
        margin: design.space.md,
        hideOnScroll: true,
      ),
      own: own,
    );
  }
}

/// The one action a screen exists for, floating over its content.
///
/// See `docs/plans/30-ds-snackbar-fab-action-bar.plan.md`. Both platforms
/// agree that two of these on a screen is a design error, so the component
/// does not make a second one easy — there is no row form and no mini-FAB
/// cluster.
///
/// It is chrome: it floats over content by definition, so on Apple it is
/// tinted glass — the accent still reads, and what is behind it still moves
/// through — while on Android it is the opaque accent a Material button
/// already was. [AppShape.pill] rather than a hand-typed radius, and the
/// surface carries the lift, so the button itself is elevation zero.
///
/// The presence of [label] is what makes it extended. With a label it
/// collapses to its glyph while the content scrolls forward and extends again
/// when it stops; without one it scales away and returns. The label stays in
/// the semantics tree either way, because a collapsed button is still the same
/// button.
class DSFab extends StatefulWidget {
  const DSFab({
    super.key,
    required this.icon,
    this.label,
    this.onPressed,
    this.semanticLabel,
    this.hideOnScroll = true,
    this.loading = false,
    this.tooltip,
    this.iconSlot,
    this.labelSlot,
    this.badgeSlot,
    this.style,
  }) : assert(
         label != null || semanticLabel != null,
         'a floating action button with no visible label needs a '
         'semanticLabel: it is the largest icon button on the screen and the '
         'one with no neighbour to borrow a name from',
       );

  final IconData icon;

  /// Present makes the button extended.
  final String? label;

  /// Null is disabled.
  final VoidCallback? onPressed;

  /// The action this button performs, as a verb.
  ///
  /// Required when there is no [label], and not defaulted from the icon: an
  /// icon has no text in it. `tooltip` is not a substitute — it is a desktop
  /// affordance that reaches semantics through a different field.
  final String? semanticLabel;

  /// Whether the button steps out of the way while the content scrolls
  /// forward. Reads [DSScrollRetreat], so it needs a [DSBottomInsetsHost]
  /// above the screen; with no host the button simply stays put.
  final bool hideOnScroll;

  /// Swaps the glyph for a spinner and refuses the tap, without changing the
  /// button's size — a button that resizes while working loses the thumb that
  /// was aiming at it.
  final bool loading;

  final String? tooltip;

  final Widget? iconSlot;
  final Widget? labelSlot;

  /// A [DSDot] — a floating button on a messages screen.
  final Widget? badgeSlot;

  final DSFabStyle? style;

  @override
  State<DSFab> createState() => _DSFabState();
}

class _DSFabState extends State<DSFab> {
  @override
  Widget build(BuildContext context) {
    final resolved = DSFabStyle.resolve(context, own: widget.style);
    final design = context.design;
    final motion = design.motion;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final hides = widget.hideOnScroll && resolved.hideOnScroll!;
    final retreating = hides && DSScrollRetreat.of(context);
    final enabled = widget.onPressed != null && !widget.loading;
    final extended = widget.label != null || widget.labelSlot != null;
    final showLabel = extended && !retreating;

    Widget glyph = widget.loading
        ? SizedBox(
            width: resolved.iconSize,
            height: resolved.iconSize,
            child: CircularProgressIndicator.adaptive(
              strokeWidth: design.component.hairlineWidth * 2,
              valueColor: AlwaysStoppedAnimation<Color>(resolved.foreground!),
            ),
          )
        : widget.iconSlot ?? Icon(widget.icon, size: resolved.iconSize);

    if (widget.badgeSlot != null) {
      glyph = Stack(
        clipBehavior: Clip.none,
        children: [
          glyph,
          PositionedDirectional(top: 0, end: 0, child: widget.badgeSlot!),
        ],
      );
    }

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        glyph,
        // The label reveals with a width animation and the glyph does not
        // move, which is the difference between a button that extends and one
        // that jumps to a new place on the screen.
        AnimatedSize(
          duration: reduced ? Duration.zero : motion.normal,
          curve: motion.emphasize,
          child: showLabel
              ? Padding(
                  padding: EdgeInsetsDirectional.only(start: design.space.sm),
                  child: widget.labelSlot ?? Text(widget.label!),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );

    final box = extended
        ? ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: resolved.extendedHeight!,
              minHeight: resolved.extendedHeight!,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: showLabel ? design.space.lg : 0,
              ),
              child: Center(widthFactor: 1, child: content),
            ),
          )
        : SizedBox(
            width: resolved.size,
            height: resolved.size,
            child: Center(child: content),
          );

    Widget button = AppChromeSurface(
      shape: resolved.shape!,
      material: AppMaterials.accent(context, resolved.fill!),
      child: DSPressable(
        enabled: enabled,
        focusShape: context.shapeOf(resolved.shape!),
        child: DSInkSurface(
          // The ink is what gives the glass surface a touch ripple; the dip
          // above it is the parent's.
          onTap: enabled ? widget.onPressed : null,
          shape: context.shapeOf(resolved.shape!),
          // The FAB paints its own diameter, 40, by deliberate decision — see
          // below. A floor inside the ink would reopen it to 48.
          minTapTarget: false,
          child: IconTheme.merge(
            data: IconThemeData(
              color: resolved.foreground,
              size: resolved.iconSize,
            ),
            child: DefaultTextStyle.merge(
              style: DSTextRole.control
                  .styleOf(context)
                  .copyWith(color: resolved.foreground),
              child: box,
            ),
          ),
        ),
      ),
    );

    // The FAB paints 40 across, deliberately — it reads as secondary rather
    // than the loudest thing on the screen. What it may not be is a
    // 40-point target, so the box it lays out in is the floor and the
    // circle is centred in it.
    button = DSTapTarget(child: button);

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }

    // The annotation is the outermost thing this widget builds, and it
    // replaces what is under it rather than adding to it — the same shape
    // `DSIconButton` uses. A screen reader walks downward and answers to the
    // first node that names itself; a label buried under the chrome surface is
    // a label the walk never reaches. A collapsed extended button keeps its
    // full name here, which is the whole reason the name is declared and not
    // read off the visible label.
    final annotated = Semantics(
      container: true,
      button: true,
      enabled: enabled,
      onTap: enabled ? widget.onPressed : null,
      label: widget.semanticLabel ?? widget.label,
      excludeSemantics: true,
      child: button,
    );

    final hidden = hides && retreating && !extended;

    return DSBottomSlotReporter(
      slot: DSBottomSlot.fab,
      extra: resolved.margin!,
      child: AnimatedScale(
        scale: hidden ? 0.8 : 1,
        duration: reduced ? Duration.zero : motion.fast,
        curve: motion.exit,
        child: AnimatedOpacity(
          opacity: hidden ? 0 : 1,
          duration: reduced ? Duration.zero : motion.fast,
          child: IgnorePointer(ignoring: hidden, child: annotated),
        ),
      ),
    );
  }
}
